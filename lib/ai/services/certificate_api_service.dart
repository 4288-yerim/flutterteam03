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

  /// 인기 직무 집계 — 실패해도 무시 (핵심 기능 아님)
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