import 'dart:math' as math;

import 'package:tflite_flutter/tflite_flutter.dart';

class StudyPlanDayResult {
  final int dayIndex; // 1부터 시작
  final String dayLabel; // "1일차", "복습일" 등
  final String title;
  final String detail;
  final String duration; // "2시간", "1시간 30분"

  const StudyPlanDayResult({
    required this.dayIndex,
    required this.dayLabel,
    required this.title,
    required this.detail,
    required this.duration,
  });
}

class StudyPlanAiService {
  static const String _modelAssetPath = 'assets/models/study_plan_model.tflite';

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

  bool get isLoaded => _interpreter != null;

  Future<void> loadModel() async {
    _interpreter ??= await Interpreter.fromAsset(_modelAssetPath);
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

  List<StudyPlanDayResult> generatePlan({
    required int totalDays,
    required double dailyHoursAvg, // 하루 평균 가용 시간(시간 단위)
    required double difficultyTier, // 0.0 ~ 1.0
    required bool includeReview,
  }) {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('StudyPlanAiService: loadModel()을 먼저 호출하세요.');
    }

    final results = <StudyPlanDayResult>[];
    final totalDaysNorm = (totalDays / 30.0).clamp(0.0, 1.0);
    final dailyHoursNorm = (dailyHoursAvg / 4.0).clamp(0.0, 1.0);
    final reviewFlag = includeReview ? 1.0 : 0.0;

    for (var day = 1; day <= totalDays; day++) {
      final dayProgress = totalDays <= 1 ? 1.0 : (day - 1) / (totalDays - 1);

      final input = [
        [dayProgress, totalDaysNorm, dailyHoursNorm, difficultyTier, reviewFlag]
      ];

      final phaseOutput = List.filled(1 * 4, 0.0).reshape([1, 4]);
      final durationOutput = List.filled(1 * 1, 0.0).reshape([1, 1]);

      interpreter.runForMultipleInputs(
        [input],
        {0: durationOutput, 1: phaseOutput},
      );

      final phaseProbs = (phaseOutput[0] as List).cast<double>();
      final phaseIndex = _argmax(phaseProbs);
      final phaseName = _phaseNames[phaseIndex];

      final durationRatio = (durationOutput[0] as List)[0] as double;
      final durationHours = (dailyHoursAvg * durationRatio).clamp(0.5, 4.0);

      final template = _phaseTemplates[phaseName]!;

      results.add(
        StudyPlanDayResult(
          dayIndex: day,
          dayLabel: phaseName == '복습' ? '복습일' : '$day일차',
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