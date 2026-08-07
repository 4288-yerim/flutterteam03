import 'package:tflite_flutter/tflite_flutter.dart';

class StudyPlanDayResult {
  final int dayIndex; // 1부터 시작
  final String dayLabel;
  final String title;
  final String detail;
  final String duration;

  const StudyPlanDayResult({
    required this.dayIndex,
    required this.dayLabel,
    required this.title,
    required this.detail,
    required this.duration,
  });
}

class StudyPlanAiService {
  static const String _modelAssetPath = 'assets/models/study_plan_model_v2.tflite';
  static const int _maxDays = 90;

  static const List<String> _phaseNames = ['기초개념', '핵심이론', '문제풀이', '복습'];

  static const Map<String, ({String title, String detail})> _phaseTemplates = {
    '기초개념': (
    title: '전체 범위 확인 및 기초 개념 학습',
    detail: '출제 범위를 확인하고 핵심 개념 단원을 학습합니다.',
    ),
    '핵심이론': (
    title: '핵심 이론 학습',
    detail: '빈출 이론을 중심으로 개념 정리와 예제를 진행합니다.',
    ),
    '문제풀이': (
    title: '기출문제 풀이',
    detail: '학습한 범위의 기출문제를 풀고 오답을 표시합니다.',
    ),
    '복습': (
    title: '주간 복습 및 오답 정리',
    detail: '누적 오답과 취약 개념을 다시 확인합니다.',
    ),
  };

  Interpreter? _interpreter;

  // 텐서 순서는 변환 시 재배열될 수 있어서 이름/shape으로 찾아서 저장해둠
  int _dayFeaturesInputIdx = 0;
  int _contextFeaturesInputIdx = 1;
  int _phaseOutputIdx = 0;
  int _durationOutputIdx = 1;

  bool get isLoaded => _interpreter != null;

  // ---------------------------------------------------------------------
  // 모델 로드 (v1과 동일하게 사용)
  // ---------------------------------------------------------------------
  Future<void> loadModel() async {
    if (_interpreter != null) return;
    final interpreter = await Interpreter.fromAsset(_modelAssetPath);

    final inputs = interpreter.getInputTensors();
    final outputs = interpreter.getOutputTensors();

    _dayFeaturesInputIdx = inputs.indexWhere((t) => t.name.contains('day_features'));
    _contextFeaturesInputIdx = inputs.indexWhere((t) => t.name.contains('context_features'));
    _phaseOutputIdx = outputs.indexWhere((t) => t.shape.last == 4);
    _durationOutputIdx = outputs.indexWhere((t) => t.shape.last == 1);

    if (_dayFeaturesInputIdx == -1 || _contextFeaturesInputIdx == -1) {
      throw StateError('입력 텐서 이름 매칭 실패. 실제 이름: ${inputs.map((t) => t.name).toList()}');
    }
    if (_phaseOutputIdx == -1 || _durationOutputIdx == -1) {
      throw StateError('출력 텐서 shape 매칭 실패. 실제 shape: ${outputs.map((t) => t.shape).toList()}');
    }

    _interpreter = interpreter;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  static double difficultyForCertificate(String name) {
    const highDifficulty = ['정보처리기사', '빅데이터분석기사'];
    const midDifficulty = ['SQLD', '네트워크관리사 2급'];

    if (highDifficulty.contains(name)) return 0.85;
    if (midDifficulty.contains(name)) return 0.55;
    return 0.35;
  }

  // ---------------------------------------------------------------------
  // v2: 90일 전체를 한 번에 예측 (v1처럼 하루씩 반복 호출하지 않음)
  //
  // v1과 다르게 개인화 피처 4개가 추가로 필요합니다:
  //   userCompletionRate, userDelayNorm, numSubjectsNorm, subjectWeakRatio
  //   -> Firestore에서 사용자 통계를 조회해서 넘겨주세요.
  //   -> 아직 데이터가 없는 신규 사용자는 기본값(아래 예시값)을 넣으면 됩니다.
  // ---------------------------------------------------------------------
  List<StudyPlanDayResult> generatePlan({
    required int totalDays,
    required double dailyHoursAvg,
    required double difficultyTier, // 0.0 ~ 1.0
    required bool includeReview,
    double userCompletionRate = 0.65, // 기본값: 신규 유저 평균치
    double userDelayNorm = 0.3,
    double numSubjectsNorm = 0.3,
    double subjectWeakRatio = 0.2,
  }) {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('StudyPlanAiService: loadModel()을 먼저 호출하세요.');
    }
    if (totalDays > _maxDays) {
      throw ArgumentError('totalDays는 최대 $_maxDays일까지 지원합니다.');
    }

    // ---- context_features (전체 6개, 하루짜리 아님) ----
    final contextFeatures = <double>[
      (totalDays / _maxDays).clamp(0.0, 1.0), // total_days_norm
      (dailyHoursAvg / 4.0).clamp(0.0, 1.0), // daily_hours_norm
      difficultyTier, // difficulty_norm
      userCompletionRate, // user_avg_completion_rate
      userDelayNorm, // user_avg_delay_norm
      numSubjectsNorm, // num_subjects_norm
    ];

    // ---- day_features (90일 x 5개, 부족한 날은 0으로 패딩) ----
    final reviewDays = <int>{};
    if (includeReview) {
      // 6일마다 한 번 복습일 (파이썬 학습 스크립트의 review_days 규칙과 동일하게)
      for (var d = 5; d < totalDays; d += 6) {
        reviewDays.add(d);
      }
    }

    final dayFeatures = List.generate(_maxDays, (day) {
      if (day >= totalDays) {
        return List.filled(5, 0.0); // 패딩
      }
      final dayProgress = totalDays <= 1 ? 1.0 : day / (totalDays - 1);
      final isReview = reviewDays.contains(day) ? 1.0 : 0.0;

      // prev_phase_norm: 정확히 하려면 하루씩 순차 예측해야 하지만,
      // MVP에서는 0으로 고정 (학습 데이터의 day=0과 동일 조건)
      const prevPhaseNorm = 0.0;

      return [dayProgress, difficultyTier, isReview, prevPhaseNorm, subjectWeakRatio];
    });

    // ---- 추론 ----
    final orderedInputs = List<Object>.filled(2, dayFeatures);
    orderedInputs[_dayFeaturesInputIdx] = [dayFeatures];
    orderedInputs[_contextFeaturesInputIdx] = [contextFeatures];

    final phaseOutput = [List.generate(_maxDays, (_) => List.filled(4, 0.0))];
    final durationOutput = [List.generate(_maxDays, (_) => List.filled(1, 0.0))];

    final outputMap = <int, Object>{
      _phaseOutputIdx: phaseOutput,
      _durationOutputIdx: durationOutput,
    };

    interpreter.runForMultipleInputs(orderedInputs, outputMap);

    // ---- 결과를 v1과 동일한 StudyPlanDayResult 리스트로 변환 ----
    final results = <StudyPlanDayResult>[];
    for (var day = 0; day < totalDays; day++) {
      final phaseProbs = phaseOutput[0][day];
      final phaseIndex = _argmax(phaseProbs);
      final phaseName = _phaseNames[phaseIndex];

      final durationRatio = durationOutput[0][day][0];
      final durationHours = (dailyHoursAvg * durationRatio).clamp(0.5, 4.0);

      final template = _phaseTemplates[phaseName]!;
      final dayNumber = day + 1;

      results.add(
        StudyPlanDayResult(
          dayIndex: dayNumber,
          dayLabel: phaseName == '복습' ? '복습일' : '$dayNumber일차',
          title: template.title,
          detail: template.detail,
          duration: _formatDuration(durationHours),
        ),
      );
    }

    return results;
  }

  int _argmax(List<double> values) {
    var bestIndex = 0;
    var bestValue = values.first;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > bestValue) {
        bestValue = values[i];
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  String _formatDuration(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;

    if (h == 0) return '$m분';
    if (m == 0) return '$h시간';
    return '$h시간 $m분';
  }
}