import 'package:cloud_firestore/cloud_firestore.dart';

class CertificateSearchService {
  CertificateSearchService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>>
  get _certificationsCollection {
    return _firestore.collection('certifications');
  }

  /// 검색페이지에서 사용할 전체 자격증 목록 조회
  Future<List<Certification>> getCertifications() async {
    try {
      final snapshot = await _certificationsCollection.get();

      return snapshot.docs
          .map(Certification.fromFirestore)
          .where((certificate) {
        return certificate.qualgbcd == 'T' ||
            certificate.qualgbcd == 'S';
      })
          .toList();
    } on FirebaseException catch (error) {
      throw CertificateSearchException(
        error.message ?? '자격증 정보를 불러오지 못했습니다.',
      );
    } catch (_) {
      throw const CertificateSearchException(
        '자격증 정보를 불러오는 중 오류가 발생했습니다.',
      );
    }
  }
}

/// 검색페이지와 상세페이지가 공통으로 사용하는 자격증 데이터 클래스
class Certification {
  final String id;

  /// T: 국가기술자격
  /// S: 국가전문자격
  final String qualgbcd;
  final String qualgbnm;

  /// 국가기술자격 직무 분야
  final String obligfldcd;
  final String obligfldnm;

  /// 국가기술자격 분류
  final String mdobligfldcd;
  final String mdobligfldnm;

  /// 국가전문자격 분야
  final String seriescd;
  final String seriesnm;

  /// 자격증 이름
  final String name;

  const Certification({
    required this.id,
    required this.qualgbcd,
    required this.qualgbnm,
    required this.obligfldcd,
    required this.obligfldnm,
    required this.mdobligfldcd,
    required this.mdobligfldnm,
    required this.seriescd,
    required this.seriesnm,
    required this.name,
  });

  bool get isTechnical {
    return qualgbcd == 'T';
  }

  bool get isProfessional {
    return qualgbcd == 'S';
  }

  String get qualificationName {
    switch (qualgbcd) {
      case 'T':
        return '국가기술자격';

      case 'S':
        return '국가전문자격';

      default:
        return qualgbnm;
    }
  }

  String get listDetailText {
    if (isProfessional) {
      return seriesnm;
    }

    final details = [
      obligfldnm,
      mdobligfldnm,
    ].where((value) => value.isNotEmpty).toList();

    return details.join(' · ');
  }

  String get searchDetailText {
    return listDetailText;
  }

  factory Certification.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data() ?? {};

    return Certification(
      id: document.id,
      qualgbcd: _readString(data['qualgbcd']),
      qualgbnm: _readString(data['qualgbnm']),
      obligfldcd: _readString(data['obligfldcd']),
      obligfldnm: _readString(data['obligfldnm']),
      mdobligfldcd: _readString(data['mdobligfldcd']),
      mdobligfldnm: _readString(data['mdobligfldnm']),
      seriescd: _readString(data['seriescd']),
      seriesnm: _readString(data['seriesnm']),
      name: _readString(data['jmfldnm']),
    );
  }

  static String _readString(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }
}

class CertificateSearchException implements Exception {
  final String message;

  const CertificateSearchException(this.message);

  @override
  String toString() {
    return message;
  }
}