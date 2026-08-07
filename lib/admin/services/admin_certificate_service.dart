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

  Future<AdminCertificateCategoryOptions> getTechnicalCategoryOptions() async {
    try {
      final snapshot = await _firestore.collection('certifications').get();
      final categoriesByField = <String, Set<String>>{};
      for (final document in snapshot.docs) {
        final data = document.data();
        final field = _readString(data['obligfldnm']);
        final category = _readString(data['mdobligfldnm']);
        if (field.isEmpty) continue;
        categoriesByField.putIfAbsent(field, () => <String>{});
        if (category.isNotEmpty) categoriesByField[field]!.add(category);
      }
      final fields = categoriesByField.keys.toList()..sort();
      return AdminCertificateCategoryOptions(
        fields: fields,
        categoriesByField: {
          for (final entry in categoriesByField.entries)
            entry.key: entry.value.toList()..sort(),
        },
      );
    } on FirebaseException catch (error) {
      throw AdminCertificateException(
        error.message ?? '기존 자격증 분류를 불러오지 못했습니다.',
      );
    }
  }

  Future<AdminCertificateCategoryOptions> getOtherCategoryOptions(
    String qualificationCode,
  ) async {
    final collectionName = _otherCategoryCollectionName(qualificationCode);
    if (collectionName == null) {
      return const AdminCertificateCategoryOptions(
        fields: [],
        categoriesByField: {},
      );
    }
    try {
      final snapshot = await _firestore
          .collection('certificate_category_content')
          .doc('other')
          .collection(collectionName)
          .get();
      final categoriesByField = <String, Set<String>>{};
      for (final document in snapshot.docs) {
        final data = document.data();
        final field = _readString(data['obligfldnm']);
        final category = _readString(data['mdobligfldnm']);
        if (field.isEmpty) continue;
        categoriesByField.putIfAbsent(field, () => <String>{});
        if (category.isNotEmpty) categoriesByField[field]!.add(category);
      }
      final fields = categoriesByField.keys.toList()..sort();
      return AdminCertificateCategoryOptions(
        fields: fields,
        categoriesByField: {
          for (final entry in categoriesByField.entries)
            entry.key: entry.value.toList()..sort(),
        },
      );
    } on FirebaseException catch (error) {
      throw AdminCertificateException(
        error.message ?? '기존 자격증 분류를 불러오지 못했습니다.',
      );
    }
  }

  Future<List<String>> getProfessionalSeriesOptions() async {
    try {
      final snapshot = await _firestore
          .collection('certificate_category_content')
          .doc('professional')
          .collection('category')
          .get();
      final seriesNames = snapshot.docs
          .map((document) => _readString(document.data()['seriesnm']))
          .where((seriesName) => seriesName.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return seriesNames;
    } on FirebaseException catch (error) {
      throw AdminCertificateException(
        error.message ?? '기존 계열을 불러오지 못했습니다.',
      );
    }
  }

  Future<void> addCertificate(AdminCertificateDraft draft) async {
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw const AdminCertificateException('자격증 이름을 입력해주세요.');
    }
    if (draft.qualificationCode.trim().isEmpty) {
      throw const AdminCertificateException('자격 구분을 선택해 주세요.');
    }
    if (draft.technicalFieldName.trim().isEmpty &&
        draft.professionalSeriesName.trim().isEmpty) {
      throw const AdminCertificateException('직무 분야 또는 계열을 입력해 주세요.');
    }
    if (name.contains('/')) {
      throw const AdminCertificateException('자격증 이름에는 / 문자를 사용할 수 없습니다.');
    }

    final duplicate = await _firestore
        .collection('certifications')
        .where('jmfldnm', isEqualTo: name)
        .limit(1)
        .get();
    if (duplicate.docs.isNotEmpty) {
      throw const AdminCertificateException('같은 이름의 자격증이 이미 등록되어 있습니다.');
    }

    final reference = _firestore.collection('certifications').doc('ADMIN$name');
    final itemCode = reference.id;

    final batch = _firestore.batch();
    batch.set(reference, {
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
      if (draft.source != null) 'source': draft.source,
      'isEnabled': false,
      'scheduleConfirmed': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final otherCollectionName = draft.source == null
        ? null
        : _otherCategoryCollectionName(draft.qualificationCode);
    if (otherCollectionName != null) {
      final fieldName = draft.technicalFieldName.trim();
      final categoryName = draft.categoryName.trim();
      final categoryDocumentId = [
        fieldName,
        if (categoryName.isNotEmpty) categoryName,
      ].join('_').replaceAll('/', '_');
      final categoryReference = _firestore
          .collection('certificate_category_content')
          .doc('other')
          .collection(otherCollectionName)
          .doc(categoryDocumentId);
      batch.set(
        categoryReference,
        {
          'obligfldnm': fieldName,
          'mdobligfldnm': categoryName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  static String? _otherCategoryCollectionName(String qualificationCode) =>
      switch (qualificationCode.trim()) {
        'S' => 'professional_category',
        'T' => 'technical_category',
        'P' => 'private_category',
        'L' => 'language_other_category',
        _ => null,
      };

  Future<AdminCertificate> getCertificate(String certificationId) async {
    final document = await _firestore
        .collection('certifications')
        .doc(certificationId)
        .get();
    if (!document.exists) {
      throw const AdminCertificateException('자격증 정보를 찾을 수 없습니다.');
    }
    return AdminCertificate.fromFirestore(document);
  }

  Future<AdminCertificateEditorData> getEditorData(
    String certificationId,
  ) async {
    final certificate = await getCertificate(certificationId);
    final reference = _firestore.collection('certifications').doc(certificationId);
    final results = await Future.wait([
      reference.collection('details').get(),
      reference.collection('schedules').orderBy('sortdate').get(),
    ]);
    final details = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final schedules = results[1] as QuerySnapshot<Map<String, dynamic>>;
    return AdminCertificateEditorData(
      certificate: certificate,
      details: {for (final document in details.docs) document.id: document.data()},
      schedules: schedules.docs.map((document) => AdminCertificateScheduleDraft.fromMap(document.id, document.data())).toList(),
    );
  }

  Future<void> setCertificateEnabled({
    required String certificationId,
    required bool isEnabled,
  }) => _firestore.collection('certifications').doc(certificationId).update({
        'isEnabled': isEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> saveEditorData(AdminCertificateEditorData data) async {
    final reference = _firestore
        .collection('certifications')
        .doc(data.certificate.id);
    final batch = _firestore.batch();
    batch.update(reference, {
      'jmfldnm': data.certificate.name.trim(),
      'qualgbcd': data.certificate.qualificationCode,
      'qualgbnm': data.certificate.qualificationName,
      'obligfldnm': data.certificate.fieldName.trim(),
      'mdobligfldnm': data.certificate.categoryName.trim(),
      'seriesnm': data.certificate.seriesName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      reference.collection('details').doc('overview'),
      {'contents': data.overview},
      SetOptions(merge: true),
    );
    batch.set(reference.collection('details').doc('examFee'), data.examFeeMap);
    batch.set(reference.collection('details').doc('examTrends'), {
      'infogb': '출제경향',
      'contents': _splitLines(data.examTrends),
      'links': data.examTrendsLinks,
    });
    batch.set(reference.collection('details').doc('howToObtain'), {
      'infogb': '취득방법',
      'contents': _splitLines(data.howToObtain),
      'links': data.howToObtainLinks,
    });
    batch.set(reference.collection('details').doc('scheduleLinks'), {
      'links': data.scheduleLinks,
    });
    final existingSchedules = await reference.collection('schedules').get();
    for (final document in existingSchedules.docs) {
      batch.delete(document.reference);
    }
    for (final schedule in data.schedules) {
      batch.set(reference.collection('schedules').doc(schedule.id), schedule.toMap());
    }
    await batch.commit();
  }

  Future<void> deleteCertificate(String certificationId) async {
    final reference = _firestore.collection('certifications').doc(certificationId);
    final results = await Future.wait([
      reference.collection('details').get(),
      reference.collection('schedules').get(),
    ]);
    final batch = _firestore.batch();
    for (final result in results) {
      for (final document in (result as QuerySnapshot<Map<String, dynamic>>).docs) {
        batch.delete(document.reference);
      }
    }
    batch.delete(reference);
    await batch.commit();
  }


  static List<String> _splitLines(String value) => value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  static String _readString(dynamic value) => value?.toString().trim() ?? '';
}

class AdminCertificateCategoryOptions {
  const AdminCertificateCategoryOptions({
    required this.fields,
    required this.categoriesByField,
  });

  final List<String> fields;
  final Map<String, List<String>> categoriesByField;
}

class AdminCertificateDraft {
  const AdminCertificateDraft({
    required this.name,
    required this.qualificationCode,
    required this.qualificationName,
    required this.technicalFieldName,
    required this.categoryName,
    required this.professionalSeriesName,
    this.source = 'ADMIN',
  });

  final String name;
  final String qualificationCode;
  final String qualificationName;
  final String technicalFieldName;
  final String categoryName;
  final String professionalSeriesName;
  final String? source;
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
    required this.isEnabled,
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
  final bool isEnabled;

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
      isEnabled: data['isEnabled'] is bool ? data['isEnabled'] as bool : true,
    );
  }

  static String _readString(dynamic value) => value?.toString().trim() ?? '';
}

class AdminCertificateEditorData {
  const AdminCertificateEditorData({
    required this.certificate,
    required this.details,
    required this.schedules,
  });

  final AdminCertificate certificate;
  final Map<String, Map<String, dynamic>> details;
  final List<AdminCertificateScheduleDraft> schedules;

  Map<String, dynamic> get examFeeMap {
    final fee1 = _toFee(details['examFee']?['feeRound1']);
    final fee2 = _toFee(details['examFee']?['feeRound2']);
    final contents = <String>[
      if (fee1 != null) '1차 : $fee1',
      if (fee2 != null) '2차 : $fee2',
    ].join(', ');
    return {
      'infogb': '응시수수료',
      'contents': contents,
      'feeRound1': fee1,
      'feeRound2': fee2,
      'links': _readLinks(details['examFee']),
    };
  }

  String get examTrends => _readText(details['examTrends']?['contents']);
  String get howToObtain => _readText(details['howToObtain']?['contents']);
  String get overview => _readText(details['overview']?['contents']);
  List<Map<String, String>> get examTrendsLinks => _readLinks(details['examTrends']);
  List<Map<String, String>> get howToObtainLinks => _readLinks(details['howToObtain']);
  List<Map<String, String>> get scheduleLinks => _readLinks(details['scheduleLinks']);

  static String _readText(dynamic value) => value is List
      ? value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).join('\n')
      : value?.toString().trim() ?? '';
  static List<String> _splitLines(String value) => value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  static List<Map<String, String>> _readLinks(Map<String, dynamic>? detail) {
    final links = (detail?['links'] as List? ?? const [])
        .whereType<Map>()
        .map((link) => {'label': _readText(link['label']), 'url': _readText(link['url'])})
        .where((link) => link['label']!.isNotEmpty && link['url']!.isNotEmpty)
        .toList();
    return links;
  }
  static int? _toFee(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().replaceAll(',', '').trim() ?? '');
  }
}

class AdminCertificateScheduleDraft {
  const AdminCertificateScheduleDraft({
    required this.id,
    required this.title,
    this.writtenRegistrationStartAt,
    this.writtenRegistrationEndAt,
    this.writtenExamStartAt,
    this.writtenExamEndAt,
    this.writtenPassStartAt,
    this.writtenPassEndAt,
    this.practicalRegistrationStartAt,
    this.practicalRegistrationEndAt,
    this.practicalExamStartAt,
    this.practicalExamEndAt,
    this.practicalPassStartAt,
    this.practicalPassEndAt,
    this.documentSubmitStartAt,
    this.documentSubmitEndAt,
    this.links = const [],
  });

  final String id;
  final String title;
  final DateTime? writtenRegistrationStartAt;
  final DateTime? writtenRegistrationEndAt;
  final DateTime? writtenExamStartAt;
  final DateTime? writtenExamEndAt;
  final DateTime? writtenPassStartAt;
  final DateTime? writtenPassEndAt;
  final DateTime? practicalRegistrationStartAt;
  final DateTime? practicalRegistrationEndAt;
  final DateTime? practicalExamStartAt;
  final DateTime? practicalExamEndAt;
  final DateTime? practicalPassStartAt;
  final DateTime? practicalPassEndAt;
  final DateTime? documentSubmitStartAt;
  final DateTime? documentSubmitEndAt;
  final List<Map<String, String>> links;

  factory AdminCertificateScheduleDraft.fromMap(String id, Map<String, dynamic> data) {
    DateTime? date(dynamic value) => value is Timestamp ? value.toDate() : value is String ? DateTime.tryParse(value) : null;
    return AdminCertificateScheduleDraft(
      id: id,
      title: data['implplannm']?.toString().trim() ?? '',
      writtenRegistrationStartAt: date(data['docregstartat']), writtenRegistrationEndAt: date(data['docregendat']),
      writtenExamStartAt: date(data['docexamstartat']), writtenExamEndAt: date(data['docexamendat']),
      writtenPassStartAt: date(data['docpassstartat']) ?? date(data['docpassat']),
      writtenPassEndAt: date(data['docpassendat']) ?? date(data['docpassat']),
      practicalRegistrationStartAt: date(data['pracregstartat']), practicalRegistrationEndAt: date(data['pracregendat']),
      practicalExamStartAt: date(data['pracexamstartat']), practicalExamEndAt: date(data['pracexamendat']),
      practicalPassStartAt: date(data['pracpassstartat']), practicalPassEndAt: date(data['pracpassendat']),
      documentSubmitStartAt: date(data['docsubmitstartat']), documentSubmitEndAt: date(data['docsubmitendat']),
      links: (data['links'] as List? ?? const []).whereType<Map>().map((link) => {'label': link['label']?.toString().trim() ?? '', 'url': link['url']?.toString().trim() ?? ''}).where((link) => link['label']!.isNotEmpty && link['url']!.isNotEmpty).toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'implplannm': title.trim(),
    'docregstartat': writtenRegistrationStartAt,
    'docregendat': writtenRegistrationEndAt,
    'docexamstartat': writtenExamStartAt,
    'docexamendat': writtenExamEndAt,
    'docpassstartat': writtenPassStartAt,
    'docpassendat': writtenPassEndAt,
    'docpassat': writtenPassEndAt ?? writtenPassStartAt,
    'pracregstartat': practicalRegistrationStartAt,
    'pracregendat': practicalRegistrationEndAt,
    'pracexamstartat': practicalExamStartAt,
    'pracexamendat': practicalExamEndAt,
    'pracpassstartat': practicalPassStartAt,
    'pracpassendat': practicalPassEndAt,
    'docsubmitstartat': documentSubmitStartAt,
    'docsubmitendat': documentSubmitEndAt,
    'sortdate': writtenExamStartAt ?? practicalExamStartAt ?? writtenRegistrationStartAt,
    'links': links,
  };
}
