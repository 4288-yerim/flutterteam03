import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCertificateService {
  AdminCertificateService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AdminCertificate>> watchCertificates() {
    return _firestore.collection('certifications').snapshots().map((snapshot) {
      final certificates = snapshot.docs
          .map(AdminCertificate.fromFirestore)
          .where((certificate) => certificate.name.isNotEmpty)
          .toList()
        ..sort((first, second) => first.name.compareTo(second.name));
      return certificates;
    });
  }

  Future<void> addCertificate(AdminCertificateDraft draft) async {
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw const AdminCertificateException('자격증 이름을 입력해주세요.');
    }

    final duplicate = await _firestore
        .collection('certifications')
        .where('jmfldnm', isEqualTo: name)
        .limit(1)
        .get();
    if (duplicate.docs.isNotEmpty) {
      throw const AdminCertificateException('같은 이름의 자격증이 이미 등록되어 있습니다.');
    }

    final reference = _firestore.collection('certifications').doc();
    final itemCode = reference.id;

    await reference.set({
      'jmcd': itemCode,
      'jmfldnm': name,
      'qualgbcd': draft.qualificationCode,
      'qualgbnm': draft.qualificationName,
      'seriescd': '',
      'seriesnm': draft.professionalSeriesName,
      'obligfldcd': '',
      'obligfldnm': draft.technicalFieldName,
      'mdobligfldcd': '',
      'mdobligfldnm': draft.categoryName,
      'source': 'ADMIN',
      'scheduleConfirmed': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class AdminCertificateDraft {
  const AdminCertificateDraft({
    required this.name,
    required this.qualificationCode,
    required this.qualificationName,
    required this.technicalFieldName,
    required this.categoryName,
    required this.professionalSeriesName,
  });

  final String name;
  final String qualificationCode;
  final String qualificationName;
  final String technicalFieldName;
  final String categoryName;
  final String professionalSeriesName;
}

class AdminCertificateException implements Exception {
  const AdminCertificateException(this.message);

  final String message;
}

class AdminCertificate {
  const AdminCertificate({
    required this.id,
    required this.name,
    required this.qualificationCode,
    required this.qualificationName,
    required this.fieldName,
    required this.categoryName,
    required this.seriesName,
    required this.itemCode,
    required this.source,
    required this.hasSource,
  });

  final String id;
  final String name;
  final String qualificationCode;
  final String qualificationName;
  final String fieldName;
  final String categoryName;
  final String seriesName;
  final String itemCode;
  final String source;
  final bool hasSource;

  bool get isTechnical => qualificationCode == 'T';
  bool get isProfessional => qualificationCode == 'S';
  bool get isOther => hasSource;
  bool get isAiAdded => source.toUpperCase() == 'AI';
  bool get isAdminAdded => source.toUpperCase() == 'ADMIN';

  String get technicalCategoryKey =>
      categoryName.isNotEmpty ? categoryName : fieldName;

  String get categoryLabel {
    if (isOther) return '그 외';
    if (isTechnical) return '국가기술자격';
    if (isProfessional) return '국가전문자격';
    if (isAiAdded) return 'AI 추가';
    if (isAdminAdded) return '관리자 추가';
    return qualificationName.isNotEmpty ? qualificationName : '그외';
  }

  String get detailText {
    final details = isProfessional
        ? [seriesName]
        : [fieldName, categoryName];
    return details.where((detail) => detail.isNotEmpty).join(' · ');
  }

  factory AdminCertificate.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};
    return AdminCertificate(
      id: document.id,
      name: _readString(data['jmfldnm']),
      qualificationCode: _readString(data['qualgbcd']),
      qualificationName: _readString(data['qualgbnm']),
      fieldName: _readString(data['obligfldnm']),
      categoryName: _readString(data['mdobligfldnm']),
      seriesName: _readString(data['seriesnm']),
      itemCode: _readString(data['jmcd']),
      source: _readString(data['source']),
      hasSource: data.containsKey('source'),
    );
  }

  static String _readString(dynamic value) => value?.toString().trim() ?? '';
}
