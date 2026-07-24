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

class CertificateDetailInfo {
  final String? examFee;
  final String? examTrends;
  final String? howToObtain;

  const CertificateDetailInfo({this.examFee, this.examTrends, this.howToObtain});
}
enum ScheduleStageStatus { open, upcoming, closed }

class ScheduleStage {
  final DateTime? regStart;
  final DateTime? regEnd;
  final DateTime? examDate;

  const ScheduleStage({this.regStart, this.regEnd, this.examDate});

  bool get hasData => regStart != null || regEnd != null || examDate != null;

  ScheduleStageStatus get status {
    final now = DateTime.now();
    if (regEnd != null && now.isAfter(regEnd!)) return ScheduleStageStatus.closed;
    if (regStart != null && now.isBefore(regStart!)) return ScheduleStageStatus.upcoming;
    return ScheduleStageStatus.open;
  }
}

class CertificateExamRound {
  final String roundLabel;
  final ScheduleStage written;
  final ScheduleStage practical;

  const CertificateExamRound({
    required this.roundLabel,
    required this.written,
    required this.practical,
  });

  bool get hasWritten => written.hasData;
  bool get hasPractical => practical.hasData;

  String get examTypeLabel {
    if (hasWritten && hasPractical) return '필기 + 실기';
    if (hasWritten) return '필기만';
    if (hasPractical) return '실기만';
    return '정보 없음';
  }

  bool get isFullyClosed {
    final now = DateTime.now();
    final writtenClosed = !written.hasData || (written.examDate != null && now.isAfter(written.examDate!));
    final practicalClosed = !practical.hasData || (practical.examDate != null && now.isAfter(practical.examDate!));
    return writtenClosed && practicalClosed;
  }
}
class AddCertificationResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? certificate;
  const AddCertificationResult({required this.success, this.message, this.certificate});
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
      final regEnd = data['docregendat'] as Timestamp?;
      if (regEnd != null && regEnd.compareTo(now) >= 0) {
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

  static List<Map<String, dynamic>>? _allCertificationsCache;

  static Future<List<Map<String, dynamic>>> loadAllCertifications({bool forceRefresh = false}) async {
    if (!forceRefresh && _allCertificationsCache != null) {
      return _allCertificationsCache!;
    }
    final snap = await FirebaseFirestore.instance.collection('certifications').get();
    _allCertificationsCache = snap.docs.map((d) => d.data()).toList();
    return _allCertificationsCache!;
  }

  static List<Map<String, dynamic>> filterCertifications(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _allCertificationsCache == null) return [];
    final q = trimmed.toLowerCase();
    return _allCertificationsCache!
        .where((c) => (c['jmfldnm'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  static Future<AddCertificationResult> addCertificationWithAi(String name) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('addCertificationFromAi');
      final result = await callable.call({'name': name});
      final data = Map<String, dynamic>.from(result.data as Map);
      return AddCertificationResult(
        success: data['success'] == true,
        message: data['message'] as String?,
        certificate: data['certificate'] != null
            ? Map<String, dynamic>.from(data['certificate'])
            : null,
      );
    } catch (e) {
      debugPrint('AI 자격증 추가 실패: $e');
      return const AddCertificationResult(success: false, message: '자격증 추가 중 오류가 발생했어요.');
    }
  }

  static Future<CertificateDetailInfo?> fetchCertificateDetailInfo(String name) async {
    CertificateDetailInfo? dbInfo;
    try {
      final query = await FirebaseFirestore.instance
          .collection('certifications')
          .where('jmfldnm', isEqualTo: name)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final detailsRef = query.docs.first.reference.collection('details');
        final results = await Future.wait([
          detailsRef.doc('examFee').get(),
          detailsRef.doc('examTrends').get(),
          detailsRef.doc('howToObtain').get(),
        ]);

        final examFee = results[0].data()?['contents'] as String?;
        final examTrends = results[1].data()?['contents'] as String?;
        final howToObtain = results[2].data()?['contents'] as String?;

        if (examFee != null || examTrends != null || howToObtain != null) {
          dbInfo = CertificateDetailInfo(examFee: examFee, examTrends: examTrends, howToObtain: howToObtain);
        }
      }
    } catch (e) {
      debugPrint('자격증 상세정보 조회 실패: $e');
    }

    final needsAiFill =
        dbInfo?.examFee == null || dbInfo?.examTrends == null || dbInfo?.howToObtain == null;
    if (!needsAiFill) return dbInfo;

    final aiInfo = await estimateCertificateDetailInfoWithAi(name);
    if (aiInfo == null) return dbInfo;

    return CertificateDetailInfo(
      examFee: dbInfo?.examFee ?? aiInfo.examFee,
      examTrends: dbInfo?.examTrends ?? aiInfo.examTrends,
      howToObtain: dbInfo?.howToObtain ?? aiInfo.howToObtain,
    );
  }

  static Future<CertificateDetailInfo?> estimateCertificateDetailInfoWithAi(String name) async {
    try {
      final callable =
      FirebaseFunctions.instance.httpsCallable('estimateCertificateDetailInfo');
      final result = await callable.call({'name': name});
      if (result.data['success'] != true) return null;

      final detail = Map<String, dynamic>.from(result.data['detail'] ?? {});

      // 응시료 -> "1차: 19400, 2차: 20800" 형식으로 조립
      final fee = Map<String, dynamic>.from(detail['examFee'] ?? {});
      final feeParts = <String>[];
      if (fee['firstLabel'] != null && fee['firstAmount'] != null) {
        feeParts.add('${fee['firstLabel']}: ${fee['firstAmount']}');
      }
      if (fee['secondLabel'] != null && fee['secondAmount'] != null) {
        feeParts.add('${fee['secondLabel']}: ${fee['secondAmount']}');
      }
      final examFee = feeParts.isEmpty ? null : feeParts.join(', ');

      // 출제경향 -> "<header>1. topic1 2. topic2 ..." 형식으로 조립
      final trends = Map<String, dynamic>.from(detail['examTrends'] ?? {});
      final topics = (trends['topics'] as List?)
          ?.map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList() ??
          [];
      String? examTrends;
      if (topics.isNotEmpty) {
        final header = trends['header'] as String?;
        final buffer = StringBuffer();
        if (header != null && header.isNotEmpty) buffer.write('<$header>');
        for (var i = 0; i < topics.length; i++) {
          buffer.write('${i + 1}. ${topics[i]} ');
        }
        examTrends = buffer.toString().trim();
      }

      // 취득방법 -> "①시행처:...②관련학과:...③시험과목필기1....실기...④합격기준:..." 형식으로 조립
      final obtain = Map<String, dynamic>.from(detail['howToObtain'] ?? {});
      final agency = obtain['agency'] as String?;
      final department = obtain['department'] as String?;
      final writtenSubjects = (obtain['writtenSubjects'] as List?)
          ?.map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList() ??
          [];
      final practicalSubjects = obtain['practicalSubjects'] as String?;
      final passCriteria = obtain['passCriteria'] as String?;

      final obtainBuffer = StringBuffer();
      if (agency != null && agency.isNotEmpty) obtainBuffer.write('①시행처:$agency');
      if (department != null && department.isNotEmpty) obtainBuffer.write('②관련학과:$department');
      if (writtenSubjects.isNotEmpty) {
        obtainBuffer.write('③시험과목필기');
        for (var i = 0; i < writtenSubjects.length; i++) {
          obtainBuffer.write('${i + 1}.${writtenSubjects[i]}');
        }
        if (practicalSubjects != null && practicalSubjects.isNotEmpty) {
          obtainBuffer.write('실기$practicalSubjects');
        }
      }
      if (passCriteria != null && passCriteria.isNotEmpty) obtainBuffer.write('④합격기준:$passCriteria');
      final howToObtain = obtainBuffer.isEmpty ? null : obtainBuffer.toString();

      if (examFee == null && examTrends == null && howToObtain == null) return null;

      return CertificateDetailInfo(examFee: examFee, examTrends: examTrends, howToObtain: howToObtain);
    } catch (e) {
      debugPrint('AI 자격증 상세정보 보완 실패: $e');
      return null;
    }
  }

  static Future<List<CertificateExamRound>> fetchAllExamRounds(String name) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('certifications')
          .where('jmfldnm', isEqualTo: name)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return [];

      final schedulesSnap = await query.docs.first.reference
          .collection('schedules')
          .orderBy('sortdate', descending: false)
          .get();

      return schedulesSnap.docs.map((doc) {
        final data = doc.data();

        final regStart = (data['docregstartat'] as Timestamp?)?.toDate();
        final regEnd = (data['docregendat'] as Timestamp?)?.toDate();
        final examDate = (data['docexamstartat'] as Timestamp?)?.toDate();

        final pracRegStart = (data['pracregstartat'] as Timestamp?)?.toDate();
        final pracRegEnd = (data['pracregendat'] as Timestamp?)?.toDate();
        final pracExamDate = (data['pracexamstartat'] as Timestamp?)?.toDate();

        final planName = (data['implplannm'] ?? '').toString();
        final roundMatch = RegExp(r'(\d+)\s*회').firstMatch(planName);
        final roundLabel = roundMatch != null ? roundMatch.group(1)! : '';

        return CertificateExamRound(
          roundLabel: roundLabel,
          written: ScheduleStage(regStart: regStart, regEnd: regEnd, examDate: examDate),
          practical: ScheduleStage(regStart: pracRegStart, regEnd: pracRegEnd, examDate: pracExamDate),
        );
      }).toList();
    } catch (e) {
      debugPrint('회차 일정 조회 실패: $e');
      return [];
    }
  }

  static String buildApplicationUrl(String name) {
    final encoded = Uri.encodeComponent(name);
    return 'https://www.q-net.or.kr/man001.do?gSite=Q&gId=&search=$encoded';
  }

}


