import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

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

enum QuizSourceType { certification, document, wrongAnswerReview }

class WrongAnswer {
  final QuizSourceType sourceType;
  final String? certificationName;
  final String? pdfFileName;
  final String examType;
  final String? subject;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String userAnswer;
  final String explanation;

  const WrongAnswer({
    required this.sourceType,
    this.certificationName,
    this.pdfFileName,
    required this.examType,
    this.subject,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.userAnswer,
    required this.explanation,
  });

  Map<String, dynamic> toMap() {
    return {
      'sourceType': sourceType.name,
      'certificationName': certificationName,
      'pdfFileName': pdfFileName,
      'examType': examType,
      'subject': subject,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'userAnswer': userAnswer,
      'explanation': explanation,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class QuizSession {
  final QuizSourceType sourceType;
  final String? certificationName;
  final String? pdfFileName;
  final String examType;
  final String? subject;
  final int totalCount;
  final int correctCount;
  final int generationDurationSeconds;
  final int solvingDurationSeconds;

  const QuizSession({
    required this.sourceType,
    this.certificationName,
    this.pdfFileName,
    required this.examType,
    this.subject,
    required this.totalCount,
    required this.correctCount,
    required this.generationDurationSeconds,
    required this.solvingDurationSeconds,
  });

  Map<String, dynamic> toMap() {
    return {
      'sourceType': sourceType.name,
      'certificationName': certificationName,
      'pdfFileName': pdfFileName,
      'examType': examType,
      'subject': subject,
      'totalCount': totalCount,
      'correctCount': correctCount,
      'generationDurationSeconds': generationDurationSeconds,
      'solvingDurationSeconds': solvingDurationSeconds,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class QuestionGenerationApiService {
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

  static Future<List<GeneratedQuestion>> generateQuestionBatch({
    required String certificationName,
    required String examType,
    String? subject,
    String generationType = 'general',
    int count = 20,
    void Function(int completed, int total)? onProgress,
  }) async {
    final callable = FirebaseFunctions.instance
        .httpsCallable('generateQuestionsForCertification');
    final result = await callable.call({
      'certificationName': certificationName,
      'examType': examType,
      'subject': subject,
      'count': count,
    });

    if (result.data['success'] == true) {
      final list = List<dynamic>.from(result.data['questions']);
      final questions = list
          .map((q) => GeneratedQuestion.fromJson(Map<String, dynamic>.from(q)))
          .toList();

      onProgress?.call(questions.length, count);
      return questions;
    }
    throw Exception(result.data['message'] ?? '문제를 생성하지 못했어요.');
  }

  static Future<String> _uploadDocument(PlatformFile file) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('로그인이 필요해요.');
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final ref = FirebaseStorage.instance.ref('material_summaries/$uid/$fileName');

    final metadata = SettableMetadata(contentType: 'application/pdf');

    if (file.bytes != null) {
      await ref.putData(file.bytes!, metadata);
    } else if (file.path != null) {
      await ref.putFile(File(file.path!), metadata);
    } else {
      throw Exception('파일을 읽을 수 없어요.');
    }

    return ref.getDownloadURL();
  }

  static Future<String> _extractDocumentText(String documentUrl) async {
    final callable =
    FirebaseFunctions.instance.httpsCallable('extractDocumentText');
    final result = await callable.call({'documentUrl': documentUrl});

    debugPrint('extractDocumentText 응답: ${result.data}');   // ← 추가

    if (result.data['success'] == true) {
      return result.data['extractedText'] as String;
    }
    throw Exception(result.data['message'] ?? '문서를 분석하지 못했어요.');
  }

  /// 추출된 텍스트로 문제 여러 개를 한 번에 생성
  static Future<List<GeneratedQuestion>> _generateQuestionsFromText({
    required String extractedText,
    int count = 20,
  }) async {
    final callable =
    FirebaseFunctions.instance.httpsCallable('generateQuestionsFromText');
    final result = await callable.call({
      'extractedText': extractedText,
      'count': count,
    });

    debugPrint('generateQuestionsFromText 응답: ${result.data}');

    if (result.data['success'] == true) {
      final list = List<dynamic>.from(result.data['questions']);
      return list
          .map((q) => GeneratedQuestion.fromJson(Map<String, dynamic>.from(q)))
          .toList();
    }
    throw Exception(result.data['message'] ?? '문제를 생성하지 못했어요.');
  }

  static Future<List<GeneratedQuestion>> generateQuestionsFromDocument({
    required PlatformFile file,
    int count = 20,
    void Function(int completed, int total)? onProgress,
  }) async {
    final documentUrl = await _uploadDocument(file);
    onProgress?.call(0, count);

    final extractedText = await _extractDocumentText(documentUrl);
    onProgress?.call(1, count);

    final questions = await _generateQuestionsFromText(
      extractedText: extractedText,
      count: count,
    );
    onProgress?.call(count, count);

    return questions;
  }

  static Future<List<GeneratedQuestion>> generateQuestionsFromWrongAnswers({
    String? certificationName,
    int count = 20,
  }) async {
    final callable = FirebaseFunctions.instance
        .httpsCallable('generateQuestionsFromWrongAnswers');
    final result = await callable.call({
      'certificationName': certificationName,
      'count': count,
    });

    if (result.data['success'] == true) {
      final list = List<dynamic>.from(result.data['questions']);
      return list
          .map((q) => GeneratedQuestion.fromJson(Map<String, dynamic>.from(q)))
          .toList();
    }
    throw Exception(result.data['message'] ?? '문제를 생성하지 못했어요.');
  }

  static Future<void> saveWrongAnswers(List<WrongAnswer> wrongAnswers) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || wrongAnswers.isEmpty) return;

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('wrong_answers');

    final batch = FirebaseFirestore.instance.batch();
    for (final wa in wrongAnswers) {
      batch.set(collection.doc(), wa.toMap());
    }
    await batch.commit();
  }

  static Future<void> saveQuizSession(QuizSession session) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('quiz_sessions')
        .add(session.toMap());
  }
}