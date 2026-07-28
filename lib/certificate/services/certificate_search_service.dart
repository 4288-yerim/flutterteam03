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

class Certification {
  final String id;

  final String qualgbcd;
  final String qualgbnm;

  final String obligfldcd;
  final String obligfldnm;

  final String mdobligfldcd;
  final String mdobligfldnm;

  final String seriescd;
  final String seriesnm;

  final String name;
  final String jmcd;

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
    required this.jmcd,
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
      jmcd: _readString(data['jmcd']),
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