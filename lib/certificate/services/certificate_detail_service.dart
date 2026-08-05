import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'technical_certificate_service.dart';

import 'certificate_search_service.dart';

class CertificateDetailService {
  CertificateDetailService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  static const int maximumActiveGoalCount = 10;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>>
  get _certificationsCollection {
    return _firestore.collection('certifications');
  }

  Future<Certification> getCertificationById(
      String certificationId,
      ) async {
    try {
      final document = await _certificationsCollection
          .doc(certificationId)
          .get();

      if (!document.exists || document.data() == null) {
        throw const CertificateDetailException(
          '자격증 정보를 찾을 수 없습니다.',
        );
      }

      return Certification.fromFirestore(document);
    } on CertificateDetailException {
      rethrow;
    } on FirebaseException catch (error) {
      throw CertificateDetailException(
        error.message ?? '자격증 정보를 불러오지 못했습니다.',
      );
    } catch (_) {
      throw const CertificateDetailException(
        '자격증 정보를 불러오는 중 오류가 발생했습니다.',
      );
    }
  }

  Future<List<TechnicalCertificateSchedule>>
  getTechnicalSchedules(
      String certificationId,
      ) async {
    try {
      final snapshot = await _certificationsCollection
          .doc(certificationId)
          .collection('schedules')
          .orderBy('sortdate')
          .get();

      return snapshot.docs
          .map(TechnicalCertificateSchedule.fromFirestore)
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

  Future<TechnicalCertificateExamDetails>
  getTechnicalExamDetails(
      String certificationId,
      ) async {
    try {
      final detailsCollection = _certificationsCollection
          .doc(certificationId)
          .collection('details');

      final documents = await Future.wait([
        detailsCollection.doc('examFee').get(),
        detailsCollection.doc('examTrends').get(),
        detailsCollection.doc('howToObtain').get(),
      ]);

      final examFeeDocument = documents[0];
      final examTrendsDocument = documents[1];
      final howToObtainDocument = documents[2];

      return TechnicalCertificateExamDetails(
        examFee: examFeeDocument.exists
            ? TechnicalCertificateExamFee.fromMap(
          examFeeDocument.data() ?? {},
        )
            : null,
        examTrends: examTrendsDocument.exists
            ? _readString(
          examTrendsDocument.data()?['contents'],
        )
            : '',
        howToObtain: howToObtainDocument.exists
            ? _readString(
          howToObtainDocument.data()?['contents'],
        )
            : '',
      );
    } on FirebaseException catch (error) {
      throw CertificateDetailException(
        error.message ?? '시험 정보를 불러오지 못했습니다.',
      );
    } catch (_) {
      throw const CertificateDetailException(
        '시험 정보를 불러오는 중 오류가 발생했습니다.',
      );
    }
  }

  Future<Set<String>> getActiveGoalScheduleKeys({
    required String certificateId,
  }) async {
    final user = _firebaseAuth.currentUser;
    final normalizedCertificateId = certificateId.trim();
    if (user == null || normalizedCertificateId.isEmpty) return <String>{};

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .where('goalStatus', isEqualTo: 'ACTIVE')
          .get();

      return snapshot.docs
          .where(
            (document) =>
                _readString(document.data()['certificateId']) ==
                normalizedCertificateId,
          )
          .map((document) {
            final data = document.data();
            return goalScheduleKey(
              scheduleId: _readString(data['scheduleId']),
              examType: _readString(data['targetExamType']),
            );
          })
          .where((key) => key != '|')
          .toSet();
    } on FirebaseException catch (error) {
      throw CertificateGoalException(
        error.message ?? '등록된 목표 시험 정보를 불러오지 못했습니다.',
      );
    }
  }

  static String goalScheduleKey({
    required String scheduleId,
    required String examType,
  }) {
    return '${scheduleId.trim()}|${examType.trim().toUpperCase()}';
  }


  Future<String> addCertificateGoal({
    required String certificateId,
    required String scheduleId,
    required String certificateName,
    required String qualificationType,
    required DateTime targetExamDate,
    required DateTime targetExamStartDate,
    required DateTime targetExamEndDate,
    required String targetRound,
    required String targetExamType,
    required String targetExamTypeName,

    required DateTime? targetRegistrationStartDate,
    required DateTime? targetRegistrationEndDate,

    required DateTime? targetPassAnnouncementDate,
    required DateTime? targetPassAnnouncementEndDate,
    required bool includeExamTypeInDuplicateCheck,
  }) async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw const CertificateGoalException(
        '로그인 후 목표 자격증을 등록할 수 있습니다.',
      );
    }

    final normalizedCertificateId = certificateId.trim();
    final normalizedScheduleId = scheduleId.trim();
    final normalizedCertificateName = certificateName.trim();
    final normalizedQualificationType = qualificationType.trim();
    final normalizedTargetRound = targetRound.trim();
    final normalizedTargetExamType = targetExamType.trim();
    final normalizedTargetExamTypeName = targetExamTypeName.trim();

    if (normalizedCertificateId.isEmpty ||
        normalizedScheduleId.isEmpty ||
        normalizedCertificateName.isEmpty ||
        normalizedQualificationType.isEmpty ||
        normalizedTargetRound.isEmpty ||
        normalizedTargetExamTypeName.isEmpty) {
      throw const CertificateGoalException(
        '목표 시험 정보가 올바르지 않습니다.',
      );
    }

    if (normalizedQualificationType != 'TECHNICAL' &&
        normalizedQualificationType != 'PROFESSIONAL') {
      throw const CertificateGoalException(
        '지원하지 않는 자격 구분입니다.',
      );
    }

    if (normalizedTargetExamType != 'WRITTEN' &&
        normalizedTargetExamType != 'PRACTICAL') {
      throw const CertificateGoalException(
        '지원하지 않는 시험 유형입니다.',
      );
    }

    if (_dateOnly(targetExamDate).isBefore(_dateOnly(DateTime.now()))) {
      throw const CertificateGoalException(
        '이미 지난 시험은 목표로 등록할 수 없습니다.',
      );
    }

    final goalsCollection = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('goals');

    try {
      final activeGoalSnapshot = await goalsCollection
          .where('goalStatus', isEqualTo: 'ACTIVE')
          .get();

      final isDuplicate = activeGoalSnapshot.docs.any((document) {
        final data = document.data();

        final sameBaseGoal =
            _readString(data['certificateId']) == normalizedCertificateId &&
            _readString(data['scheduleId']) == normalizedScheduleId;

        if (!sameBaseGoal) {
          return false;
        }

        if (!includeExamTypeInDuplicateCheck) {
          return true;
        }

        return _readString(data['targetExamType']) ==
            normalizedTargetExamType;
      });

      if (isDuplicate) {
        if (includeExamTypeInDuplicateCheck) {
          throw CertificateGoalException(
            '이미 같은 회차의 $normalizedTargetExamTypeName 시험이 '
            '목표로 등록되어 있습니다.',
          );
        }

        throw const CertificateGoalException(
          '이미 같은 시험 일정이 목표로 등록되어 있습니다.',
        );
      }

      if (activeGoalSnapshot.docs.length >= maximumActiveGoalCount) {
        throw const CertificateGoalException(
          '목표 자격증은 최대 10개까지 등록할 수 있습니다.',
        );
      }

      final userDocument = _firestore
          .collection('users')
          .doc(user.uid);

      final goalDocument = goalsCollection.doc();

      final calendarEventDocument = userDocument
          .collection('calendarEvents')
          .doc();
      final applicationStartEventDocument = userDocument
          .collection('calendarEvents')
          .doc('${goalDocument.id}_application_start');
      final applicationEndEventDocument = userDocument
          .collection('calendarEvents')
          .doc('${goalDocument.id}_application_end');
      final passAnnouncementEventDocument = userDocument
          .collection('calendarEvents')
          .doc('${goalDocument.id}_pass_announcement');

      final examTypeName = '$normalizedTargetExamTypeName 시험';

      final calendarTitle =
          '$normalizedCertificateName '
          '$normalizedTargetRound '
          '$examTypeName';

      final examDayAlertDate = _dateOnly(
        targetExamDate,
      );

      final examD7AlertDate = examDayAlertDate.subtract(
        const Duration(days: 7),
      );

      final examD1AlertDate = examDayAlertDate.subtract(
        const Duration(days: 1),
      );

      final applicationStartAlertDate =
      targetRegistrationStartDate == null
          ? null
          : _dateOnly(
        targetRegistrationStartDate,
      );

      final applicationEndD1AlertDate =
      targetRegistrationEndDate == null
          ? null
          : _dateOnly(
        targetRegistrationEndDate,
      ).subtract(
        const Duration(days: 1),
      );

      final resultAlertDate =
      targetPassAnnouncementDate == null
          ? null
          : _dateOnly(
        targetPassAnnouncementDate,
      );

      final batch = _firestore.batch();
      final calendarEventIds = <String>[calendarEventDocument.id];
      if (targetRegistrationStartDate != null) {
        calendarEventIds.add(applicationStartEventDocument.id);
      }
      if (targetRegistrationEndDate != null) {
        calendarEventIds.add(applicationEndEventDocument.id);
      }
      if (targetPassAnnouncementDate != null) {
        calendarEventIds.add(passAnnouncementEventDocument.id);
      }
      batch.set(
        goalDocument,
        {
          'certificateId': normalizedCertificateId,
          'scheduleId': normalizedScheduleId,
          'certificateName': normalizedCertificateName,
          'qualificationType': normalizedQualificationType,

          'targetExamDate': Timestamp.fromDate(
            targetExamDate,
          ),
          'targetExamStartDate': Timestamp.fromDate(targetExamStartDate),
          'targetExamEndDate': Timestamp.fromDate(targetExamEndDate),

          'examD7AlertDate': Timestamp.fromDate(
            examD7AlertDate,
          ),
          'examD1AlertDate': Timestamp.fromDate(
            examD1AlertDate,
          ),
          'examDayAlertDate': Timestamp.fromDate(
            examDayAlertDate,
          ),

          'targetRound': normalizedTargetRound,
          'targetExamType': normalizedTargetExamType,
          'targetExamTypeName': normalizedTargetExamTypeName,

          'targetRegistrationStartDate':
          targetRegistrationStartDate == null
              ? null
              : Timestamp.fromDate(
            targetRegistrationStartDate,
          ),

          'targetRegistrationEndDate':
          targetRegistrationEndDate == null
              ? null
              : Timestamp.fromDate(
            targetRegistrationEndDate,
          ),

          'applicationStartAlertDate':
          applicationStartAlertDate == null
              ? null
              : Timestamp.fromDate(
            applicationStartAlertDate,
          ),

          'applicationEndD1AlertDate':
          applicationEndD1AlertDate == null
              ? null
              : Timestamp.fromDate(
            applicationEndD1AlertDate,
          ),

          'targetPassAnnouncementDate':
          targetPassAnnouncementDate == null
              ? null
              : Timestamp.fromDate(
            targetPassAnnouncementDate,
          ),

          'targetPassAnnouncementEndDate':
          targetPassAnnouncementEndDate == null
              ? null
              : Timestamp.fromDate(
            targetPassAnnouncementEndDate,
          ),

          'resultAlertDate':
          resultAlertDate == null
              ? null
              : Timestamp.fromDate(
            resultAlertDate,
          ),

          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'goalStatus': 'ACTIVE',
          'isMainGoal': false,

          'calendarLinked': false,

          'calendarEventId': calendarEventDocument.id,
          'calendarEventIds': calendarEventIds,
        },
      );

      batch.set(
        calendarEventDocument,
        {
          'startAt': Timestamp.fromDate(targetExamDate),
          'allDay': true,
          'title': calendarTitle,
          'eventType': 'EXAM',
          'certificateName': normalizedCertificateName,
          'scheduleName': '$normalizedTargetRound $examTypeName',
        },
      );

      if (targetRegistrationStartDate != null) {
        batch.set(applicationStartEventDocument, {
          'startAt': Timestamp.fromDate(targetRegistrationStartDate),
          'allDay': true,
          'title': '$normalizedCertificateName $normalizedTargetRound '
              '$normalizedTargetExamTypeName 원서 접수 시작일',
          'eventType': 'APPLICATION',
          'certificateName': normalizedCertificateName,
          'scheduleName': '$normalizedTargetRound '
              '$normalizedTargetExamTypeName 원서 접수 시작',
        });
      }

      if (targetRegistrationEndDate != null) {
        batch.set(applicationEndEventDocument, {
          'startAt': Timestamp.fromDate(targetRegistrationEndDate),
          'allDay': true,
          'title': '$normalizedCertificateName $normalizedTargetRound '
              '$normalizedTargetExamTypeName 원서 접수 종료일',
          'eventType': 'APPLICATION',
          'certificateName': normalizedCertificateName,
          'scheduleName': '$normalizedTargetRound '
              '$normalizedTargetExamTypeName 원서 접수 마감',
        });
      }

      if (targetPassAnnouncementDate != null) {
        batch.set(passAnnouncementEventDocument, {
          'startAt': Timestamp.fromDate(targetPassAnnouncementDate),
          'allDay': true,
          'title': '$normalizedCertificateName $normalizedTargetRound '
              '$normalizedTargetExamTypeName 합격 발표일',
          'eventType': 'RESULT',
          'certificateName': normalizedCertificateName,
          'scheduleName': '$normalizedTargetRound '
              '$normalizedTargetExamTypeName 합격 발표',
        });
      }

      await batch.commit();

      return goalDocument.id;
    } on CertificateGoalException {
      rethrow;
    } on FirebaseException catch (error) {
      throw CertificateGoalException(
        error.message ?? '목표 자격증을 등록하지 못했습니다.',
      );
    } catch (_) {
      throw const CertificateGoalException(
        '목표 자격증을 등록하는 중 오류가 발생했습니다.',
      );
    }
  }

  Future<void> updateGoalCalendarLinked({
    required String goalId,
    required bool calendarLinked,
  }) async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw const CertificateGoalException(
        '로그인 후 캘린더 연동 상태를 변경할 수 있습니다.',
      );
    }

    final normalizedGoalId = goalId.trim();

    if (normalizedGoalId.isEmpty) {
      throw const CertificateGoalException(
        '목표 정보가 올바르지 않습니다.',
      );
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .doc(normalizedGoalId)
          .update({
        'calendarLinked': calendarLinked,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw CertificateGoalException(
        error.message ?? '캘린더 연동 상태를 저장하지 못했습니다.',
      );
    } catch (_) {
      throw const CertificateGoalException(
        '캘린더 연동 상태를 저장하는 중 오류가 발생했습니다.',
      );
    }
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
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }
}

class CertificateDetailException implements Exception {
  final String message;

  const CertificateDetailException(this.message);

  @override
  String toString() {
    return message;
  }
}

class CertificateGoalException implements Exception {
  final String message;

  const CertificateGoalException(this.message);

  @override
  String toString() => message;
}
