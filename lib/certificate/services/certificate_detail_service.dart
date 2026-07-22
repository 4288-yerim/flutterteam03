import 'package:cloud_firestore/cloud_firestore.dart';
import 'technical_certificate_service.dart';

import 'certificate_search_service.dart';

class CertificateDetailService {
  CertificateDetailService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
