import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SuggestedCertificate {
  final String name;
  final String description;

  SuggestedCertificate({required this.name, required this.description});

  factory SuggestedCertificate.fromJson(Map<String, dynamic> json) {
    return SuggestedCertificate(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class CertificateSchedule {
  final String rawDescription;
  final String docRegPeriod;
  final String docExamDate;
  final DateTime? docExamStart;

  CertificateSchedule({
    required this.rawDescription,
    required this.docRegPeriod,
    required this.docExamDate,
    required this.docExamStart,
  });

  static String _fmt(String? d) {
    if (d == null || d.length != 8) return '-';
    return '${d.substring(0, 4)}. ${d.substring(4, 6)}. ${d.substring(6, 8)}';
  }

  static DateTime? _parseDate(String? d) {
    if (d == null || d.length != 8) return null;
    return DateTime.tryParse(
      '${d.substring(0, 4)}-${d.substring(4, 6)}-${d.substring(6, 8)}',
    );
  }

  factory CertificateSchedule.fromJson(Map<String, dynamic> json) {
    return CertificateSchedule(
      rawDescription: json['description'] ?? '',
      docRegPeriod:
      '${_fmt(json['docRegStartDt'])} ~ ${_fmt(json['docRegEndDt'])}',
      docExamDate: _fmt(json['docExamStartDt']),
      docExamStart: _parseDate(json['docExamStartDt']),
    );
  }
}

class CertificateInfo {
  final String? level;
  final String? registrationPeriod;
  final String? examDate;
  final bool fromAi;

  const CertificateInfo({
    this.level,
    this.registrationPeriod,
    this.examDate,
    this.fromAi = false,
  });
}

class CertificateApiService {
  static Future<List<SuggestedCertificate>> suggestCertificates(
      String job,
      ) async {
    final callable =
    FirebaseFunctions.instance.httpsCallable('suggestCertificatesForJob');
    final result = await callable.call({'job': job});

    if (result.data['success'] == true) {
      return (result.data['certificates'] as List)
          .map((e) =>
          SuggestedCertificate.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception(result.data['message'] ?? '추천을 불러오지 못했어요.');
  }

  /// 입력한 이름이 실제 존재하는 자격증/인증시험인지 AI로 판단.
  static Future<bool> validateCertificateName(String name) async {
    final callable =
    FirebaseFunctions.instance.httpsCallable('validateCertificateName');
    final result = await callable.call({'name': name});
    return result.data['valid'] == true;
  }

  /// 큐넷(공공데이터포털) 국가자격 시험일정 조회.
  static Future<List<CertificateSchedule>> fetchSchedule({int? year}) async {
    final callable =
    FirebaseFunctions.instance.httpsCallable('getCertificateSchedule');
    final result = await callable.call({'year': year ?? DateTime.now().year});

    if (result.data['success'] == true) {
      final items = (result.data['items'] as List)
          .map((e) =>
          CertificateSchedule.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return items;
    }
    throw Exception(result.data['message'] ?? '일정을 불러오지 못했어요.');
  }

// 변경 — findUpcoming 위에 새 메서드 두 개 추가
  /// Firestore에 미리 저장된 자격증/일정 정보를 우선 조회한다.
  /// (스케줄러가 큐넷 데이터를 주기적으로 캐시해둔 'certifications' 컬렉션)
  /// DB에 아예 없거나 다가오는 회차가 없으면 null을 반환한다.
  static Future<CertificateInfo?> fetchCertificateInfoFromFirestore(
      String name,
      ) async {
    final query = await FirebaseFirestore.instance
        .collection('certifications')
        .where('jmfldnm', isEqualTo: name)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final qualgbcd = doc.data()['qualgbcd'] as String?;
    final level = qualgbcd == 'T'
        ? '국가기술자격'
        : (qualgbcd == 'S' ? '국가전문자격' : null);

    final now = Timestamp.now();
    final schedulesSnap = await doc.reference
        .collection('schedules')
        .orderBy('sortdate', descending: false)
        .get();

    Map<String, dynamic>? upcoming;
    for (final scheduleDoc in schedulesSnap.docs) {
      final data = scheduleDoc.data();
      final examStart = (data['docexamstartat'] as Timestamp?) ??
          (data['pracexamstartat'] as Timestamp?);
      if (examStart != null && examStart.compareTo(now) >= 0) {
        upcoming = data;
        break;
      }
    }

    String? registrationPeriod;
    String? examDate;

    if (upcoming != null) {
      final regStart = (upcoming['docregstartat'] as Timestamp?)?.toDate();
      final regEnd = (upcoming['docregendat'] as Timestamp?)?.toDate();
      final exam = (upcoming['docexamstartat'] as Timestamp?)?.toDate() ??
          (upcoming['pracexamstartat'] as Timestamp?)?.toDate();

      if (regStart != null && regEnd != null) {
        registrationPeriod = '${_fmtDate(regStart)} ~ ${_fmtDate(regEnd)}';
      }
      if (exam != null) {
        examDate = _fmtDate(exam);
      }
    }

    if (level == null && registrationPeriod == null && examDate == null) {
      return null;
    }

    return CertificateInfo(
      level: level,
      registrationPeriod: registrationPeriod,
      examDate: examDate,
    );
  }

  static String _fmtDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}. $month. $day';
  }

  static Future<CertificateInfo> estimateCertificateInfoWithAi(
      String name,
      ) async {
    try {
      final callable =
      FirebaseFunctions.instance.httpsCallable('estimateCertificateInfo');
      final result = await callable.call({'name': name});

      if (result.data['success'] == true) {
        final data = Map<String, dynamic>.from(result.data['info'] ?? {});
        return CertificateInfo(
          level: data['level'] as String?,
          registrationPeriod: data['registrationPeriod'] as String?,
          examDate: data['examDate'] as String?,
          fromAi: true,
        );
      }
    } catch (e) {
      debugPrint('AI 자격증 정보 보완 실패: $e');
    }
    return const CertificateInfo(fromAi: true);
  }

  static CertificateSchedule? findUpcoming(
      List<CertificateSchedule> all,
      String certName,
      ) {
    final now = DateTime.now();
    final matched = all
        .where((e) => e.rawDescription.contains(certName))
        .where((e) => e.docExamStart != null && e.docExamStart!.isAfter(now))
        .toList()
      ..sort((a, b) => a.docExamStart!.compareTo(b.docExamStart!));

    return matched.isEmpty ? null : matched.first;
  }

  static Future<void> incrementJobPopularity(String job) async {
    try {
      final normalized =
      job.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (normalized.isEmpty || normalized.length > 30) return;

      final ref = FirebaseFirestore.instance
          .collection('job_popularity')
          .doc(normalized);
      await ref.set({
        'displayName': job.trim(),
        'count': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getPopularJobs() async {
    final snap = await FirebaseFirestore.instance
        .collection('job_popularity')
        .orderBy('count', descending: true)
        .limit(5)
        .get();
    return snap.docs
        .map((d) => {
      'name': d.data()['displayName'],
      'count': d.data()['count'],
    })
        .toList();
  }
}


