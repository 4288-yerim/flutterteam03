import 'package:cloud_firestore/cloud_firestore.dart';

import 'certificate_detail_service.dart';
import 'certificate_search_service.dart';

class ProfessionalCertificateService {
  ProfessionalCertificateService({
    CertificateDetailService? certificateDetailService,
    FirebaseFirestore? firestore,
  })  : _certificateDetailService =
      certificateDetailService ?? CertificateDetailService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final CertificateDetailService _certificateDetailService;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>>
  get _certificationsCollection {
    return _firestore.collection('certifications');
  }

  Future<Certification> getProfessionalCertificateById(
      String certificationId,
      ) async {
    final certificate = await _certificateDetailService
        .getCertificationById(certificationId);

    if (!certificate.isProfessional) {
      throw const CertificateDetailException(
        '국가전문자격 정보가 아닙니다.',
      );
    }

    return certificate;
  }

  Future<List<ProfessionalCertificateSchedule>>
  getProfessionalSchedules(
      String certificationId,
      ) async {
    try {
      final snapshot = await _certificationsCollection
          .doc(certificationId)
          .collection('schedules')
          .orderBy('sortdate')
          .get();

      final schedules = snapshot.docs
          .map(
        ProfessionalCertificateSchedule.fromFirestore,
      )
          .toList();
      schedules.sort(ProfessionalCertificateSchedule.compareForDisplay);
      return schedules;
    } on FirebaseException catch (error) {
      throw CertificateDetailException(
        error.message ?? '시험 일정을 불러오지 못했습니다.',
      );
    } catch (_) {
      throw const CertificateDetailException(
        '시험 일정을 불러오는 중 오류가 발생했습니다.',
      );
    }
  }

}

class ProfessionalCertificateSchedule {
  final String id;
  final String description;
  final String jmCd;
  final String seriesCd;
  final int? year;

  final DateTime? examRegistrationStartAt;
  final DateTime? examRegistrationEndAt;

  final DateTime? examStartAt;
  final DateTime? examEndAt;

  final DateTime? passStartAt;
  final DateTime? passEndAt;

  final DateTime? sortDate;

  const ProfessionalCertificateSchedule({
    required this.id,
    required this.description,
    required this.jmCd,
    required this.seriesCd,
    required this.year,
    required this.examRegistrationStartAt,
    required this.examRegistrationEndAt,
    required this.examStartAt,
    required this.examEndAt,
    required this.passStartAt,
    required this.passEndAt,
    required this.sortDate,
  });

  static int compareForDisplay(
    ProfessionalCertificateSchedule first,
    ProfessionalCertificateSchedule second,
  ) {
    final today = _dateOnly(DateTime.now());
    final firstFinished = first._isFinished(today);
    final secondFinished = second._isFinished(today);
    if (firstFinished != secondFinished) return firstFinished ? 1 : -1;
    return _sortDate(first).compareTo(_sortDate(second));
  }

  bool _isFinished(DateTime today) {
    final lastDate = passEndAt ?? passStartAt;
    return lastDate != null && _dateOnly(lastDate).isBefore(today);
  }

  static DateTime _sortDate(ProfessionalCertificateSchedule schedule) =>
      schedule.sortDate ??
      schedule.examStartAt ??
      schedule.examEndAt ??
      DateTime(9999);

  static DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  factory ProfessionalCertificateSchedule.fromFirestore(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    return ProfessionalCertificateSchedule(
      id: document.id,
      description:
      _readString(data['description']),
      jmCd: _readString(data['jmcd']),
      seriesCd: _readString(data['seriescd']),
      year: _readInt(data['year']),
      examRegistrationStartAt:
      _readDateTime(data['examregstartat']),
      examRegistrationEndAt:
      _readDateTime(data['examregendat']),
      examStartAt:
      _readDateTime(data['examstartat']),
      examEndAt:
      _readDateTime(data['examendat']),
      passStartAt:
      _readDateTime(data['passstartat']),
      passEndAt:
      _readDateTime(data['passendat']),
      sortDate:
      _readDateTime(data['sortdate']),
    );
  }

  bool get isPast {
    final date = examEndAt ?? examStartAt;

    if (date == null) {
      return false;
    }

    final localDate = date.toLocal();
    final today = DateTime.now();

    return DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    ).isBefore(
      DateTime(
        today.year,
        today.month,
        today.day,
      ),
    );
  }

  static String _readString(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).join('\n');
    }
    return value?.toString().trim() ?? '';
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
