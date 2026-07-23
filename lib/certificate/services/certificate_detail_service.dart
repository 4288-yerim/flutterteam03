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

  /// 상세페이지에서 사용할 자격증 한 건 조회
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

  /// 국가기술자격 시험 일정 조회
  ///
  /// certifications/{certificationId}/schedules
  /// 컬렉션의 모든 문서를 sortdate 오름차순으로 조회한다.
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

  /// 국가기술자격 시험 정보 조회
  ///
  /// details 하위 컬렉션에서 고정 문서 ID를 사용한다.
  ///
  /// - examfee
  /// - examTrends
  /// - howToObtain
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


  Future<String> addCertificateGoal({
    required String certificateId,
    required String scheduleId,
    required String certificateName,
    required String qualificationType,
    required DateTime targetExamDate,
    required String targetRound,
    required String targetExamType,
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

    if (normalizedCertificateId.isEmpty ||
        normalizedScheduleId.isEmpty ||
        normalizedCertificateName.isEmpty ||
        normalizedQualificationType.isEmpty ||
        normalizedTargetRound.isEmpty) {
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
          final examTypeName =
              normalizedTargetExamType == 'WRITTEN' ? '필기' : '실기';

          throw CertificateGoalException(
            '이미 같은 회차의 $examTypeName 시험이 목표로 등록되어 있습니다.',
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

      final goalDocument = await goalsCollection.add({
        'certificateId': normalizedCertificateId,
        'scheduleId': normalizedScheduleId,
        'certificateName': normalizedCertificateName,
        'qualificationType': normalizedQualificationType,
        'targetExamDate': Timestamp.fromDate(targetExamDate),
        'targetRound': normalizedTargetRound,
        'targetExamType': normalizedTargetExamType,
        'targetPassAnnouncementDate':
            targetPassAnnouncementDate == null
                ? null
                : Timestamp.fromDate(targetPassAnnouncementDate),
        'targetPassAnnouncementEndDate':
            targetPassAnnouncementEndDate == null
                ? null
                : Timestamp.fromDate(targetPassAnnouncementEndDate),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'goalStatus': 'ACTIVE',
        'isMainGoal': false,
        'calendarLinked': false,
      });

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
