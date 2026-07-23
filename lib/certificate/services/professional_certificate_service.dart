import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'certificate_detail_service.dart';
import 'certificate_search_service.dart';

class ProfessionalCertificateService {
  ProfessionalCertificateService({
    CertificateDetailService? certificateDetailService,
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : _certificateDetailService =
      certificateDetailService ?? CertificateDetailService(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  static const int maximumActiveGoalCount = 10;

  final CertificateDetailService _certificateDetailService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

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

      return snapshot.docs
          .map(
        ProfessionalCertificateSchedule.fromFirestore,
      )
          .toList();
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

  Future<String> addProfessionalCertificateGoal({
    required String certificateId,
    required String scheduleId,
    required String certificateName,
    required ProfessionalCertificateSchedule schedule,
  }) async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw const ProfessionalCertificateGoalException(
        '로그인 후 목표 자격증을 등록할 수 있습니다.',
      );
    }

    final normalizedCertificateId = certificateId.trim();
    final normalizedScheduleId = scheduleId.trim();
    final normalizedCertificateName =
    certificateName.trim();

    if (normalizedCertificateId.isEmpty ||
        normalizedScheduleId.isEmpty ||
        normalizedCertificateName.isEmpty) {
      throw const ProfessionalCertificateGoalException(
        '목표 시험 정보가 올바르지 않습니다.',
      );
    }

    final targetExamDate =
        schedule.examStartAt ?? schedule.examEndAt;

    if (targetExamDate == null) {
      throw const ProfessionalCertificateGoalException(
        '시험일이 없는 일정은 목표로 등록할 수 없습니다.',
      );
    }

    final today = _dateOnly(DateTime.now());
    final selectedExamDate = _dateOnly(targetExamDate);

    if (selectedExamDate.isBefore(today)) {
      throw const ProfessionalCertificateGoalException(
        '이미 지난 시험은 목표로 등록할 수 없습니다.',
      );
    }

    final targetExamType =
    _resolveTargetExamType(schedule.description);

    final goalsCollection = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('goals');

    try {
      final activeGoalSnapshot = await goalsCollection
          .where(
        'goalStatus',
        isEqualTo: 'ACTIVE',
      )
          .get();

      final isDuplicate =
      activeGoalSnapshot.docs.any((document) {
        final data = document.data();

        return _readString(data['certificateId']) ==
            normalizedCertificateId &&
            _readString(data['scheduleId']) ==
                normalizedScheduleId;
      });

      if (isDuplicate) {
        throw const ProfessionalCertificateGoalException(
          '이미 같은 시험 일정이 목표로 등록되어 있습니다.',
        );
      }

      if (activeGoalSnapshot.docs.length >=
          maximumActiveGoalCount) {
        throw const ProfessionalCertificateGoalException(
          '목표 자격증은 최대 10개까지 등록할 수 있습니다.',
        );
      }

      final goalDocument = await goalsCollection.add({
        'certificateId': normalizedCertificateId,
        'scheduleId': normalizedScheduleId,
        'certificateName': normalizedCertificateName,
        'qualificationType': 'PROFESSIONAL',
        'targetExamDate':
        Timestamp.fromDate(targetExamDate),
        'targetRound': schedule.description,
        'targetExamType': targetExamType,
        'targetPassAnnouncementDate':
        schedule.passStartAt == null
            ? null
            : Timestamp.fromDate(
          schedule.passStartAt!,
        ),
        'targetPassAnnouncementEndDate':
        schedule.passEndAt == null
            ? null
            : Timestamp.fromDate(
          schedule.passEndAt!,
        ),
        'createdAt':
        FieldValue.serverTimestamp(),
        'updatedAt':
        FieldValue.serverTimestamp(),
        'goalStatus': 'ACTIVE',
        'isMainGoal': false,
        'calendarLinked': false,
      });

      return goalDocument.id;
    } on ProfessionalCertificateGoalException {
      rethrow;
    } on FirebaseException catch (error) {
      throw ProfessionalCertificateGoalException(
        error.message ?? '목표 자격증을 등록하지 못했습니다.',
      );
    } catch (_) {
      throw const ProfessionalCertificateGoalException(
        '목표 자격증을 등록하는 중 오류가 발생했습니다.',
      );
    }
  }

  static String _resolveTargetExamType(
      String description,
      ) {
    final normalized = description.trim();

    if (normalized.contains('필기')) {
      return 'WRITTEN';
    }

    return 'PRACTICAL';
  }

  static DateTime _dateOnly(DateTime date) {
    final localDate = date.toLocal();

    return DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );
  }

  static String _readString(dynamic value) {
    return value?.toString().trim() ?? '';
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

class ProfessionalCertificateGoalException
    implements Exception {
  final String message;

  const ProfessionalCertificateGoalException(
      this.message,
      );

  @override
  String toString() => message;
}