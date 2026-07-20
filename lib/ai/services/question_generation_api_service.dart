import 'package:cloud_functions/cloud_functions.dart';

/// 자격증 시험 구조 데이터 모델
///
/// writtenSubjects: 필기 과목
/// practicalSubjects: 실기 과목
/// integratedSubjects: 필기/실기 구분이 없는 통합 시험의 과목
/// hasWritten / hasPractical: 필기·실기시험 존재 여부
/// isIntegrated: 필기/실기 구분이 없는 시험 여부
class CertificationData {
  final String name;

  final bool hasWritten;
  final bool hasPractical;
  final bool isIntegrated;

  final List<String> writtenSubjects;
  final List<String> practicalSubjects;
  final List<String> integratedSubjects;

  const CertificationData({
    required this.name,
    this.hasWritten = false,
    this.hasPractical = false,
    this.isIntegrated = false,
    this.writtenSubjects = const [],
    this.practicalSubjects = const [],
    this.integratedSubjects = const [],
  });
}

/// AI로 생성된 문제 1개를 담는 모델 (추후 실제 응답 형태에 맞춰 채워 넣을 예정)
class GeneratedQuestion {
  final String question;
  final List<String> options;
  final String answer;
  final String explanation;

  const GeneratedQuestion({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  factory GeneratedQuestion.fromJson(Map<String, dynamic> json) {
    return GeneratedQuestion(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? const []),
      answer: json['answer'] ?? '',
      explanation: json['explanation'] ?? '',
    );
  }
}

/// AI 문제 생성 페이지 전용 API 서비스.
///
/// 자격증 구조 조회, 문제 생성 등 "AI 문제 생성" 기능과 관련된 Cloud Functions 호출을
/// 이 서비스에 모아둔다. 로드맵/일정 조회는 CertificateApiService에서 계속 담당.
class QuestionGenerationApiService {
  /// 자격증 이름을 입력받아 Gemini가 필기/실기 구조와 과목을 분석해 반환.
  static Future<CertificationData> fetchCertificateStructure(
      String name,
      ) async {
    final callable = FirebaseFunctions.instance
        .httpsCallable('getCertificateStructure');
    final result = await callable.call({'name': name});

    if (result.data['success'] == true) {
      final structure =
      Map<String, dynamic>.from(result.data['structure']);

      return CertificationData(
        name: structure['name'] ?? name,
        hasWritten: structure['hasWritten'] == true,
        hasPractical: structure['hasPractical'] == true,
        isIntegrated: structure['isIntegrated'] == true,
        writtenSubjects:
        List<String>.from(structure['writtenSubjects'] ?? const []),
        practicalSubjects:
        List<String>.from(structure['practicalSubjects'] ?? const []),
        integratedSubjects:
        List<String>.from(structure['integratedSubjects'] ?? const []),
      );
    }
    throw Exception(result.data['message'] ?? '자격증 정보를 불러오지 못했어요.');
  }

  static Future<GeneratedQuestion> generateQuestion({
    required String certificationName,
    required String examType,
    String? subject,
    String generationType = 'general',
  }) async {
    final callable =
    FirebaseFunctions.instance.httpsCallable('generateQuestion');
    final result = await callable.call({
      'certificationName': certificationName,
      'examType': examType,
      'subject': subject,
      'generationType': generationType,
    });

    if (result.data['success'] == true) {
      return GeneratedQuestion.fromJson(
        Map<String, dynamic>.from(result.data['question']),
      );
    }
    throw Exception(result.data['message'] ?? '문제를 생성하지 못했어요.');
  }
}