import 'package:cloud_firestore/cloud_firestore.dart';

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
}

class CertificateDetailException implements Exception {
  final String message;

  const CertificateDetailException(this.message);

  @override
  String toString() {
    return message;
  }
}