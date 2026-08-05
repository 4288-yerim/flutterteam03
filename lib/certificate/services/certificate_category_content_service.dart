import 'package:cloud_firestore/cloud_firestore.dart';

enum CertificateCategory { technical, professional, other }

class CertificateContentLink {
  const CertificateContentLink({required this.label, required this.url});
  final String label;
  final String url;
  Map<String, String> toMap() => {'label': label.trim(), 'url': url.trim()};
  factory CertificateContentLink.fromMap(dynamic value) {
    final data = value is Map ? value : const <String, dynamic>{};
    return CertificateContentLink(
      label: data['label']?.toString().trim() ?? '',
      url: data['url']?.toString().trim() ?? '',
    );
  }
}

class CertificateCategoryScheduleNotice {
  CertificateCategoryScheduleNotice({
    required this.items,
    List<CertificateContentLink> links = const [],
  }) : links = links;

  final List<String> items;
  final List<CertificateContentLink> links;

  factory CertificateCategoryScheduleNotice.fromMap(Map<String, dynamic>? data) {
    return CertificateCategoryScheduleNotice(
      items: CertificateCategoryContentService.readItems(data?['items']),
      links: (data?['links'] as List? ?? const [])
          .map(CertificateContentLink.fromMap)
          .where((link) => link.label.isNotEmpty && link.url.isNotEmpty)
          .toList(),
    );
  }
}

class CertificateCategoryContentService {
  CertificateCategoryContentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _collectionName = 'certificate_category_content';
  static const _scheduleNoticesCollectionName = 'schedule_notices';
  static const _scheduleNoticeDocumentId = 'content';

  Stream<CertificateCategoryScheduleNotice> watchScheduleNotice(
    CertificateCategory category, {
    required CertificateCategoryScheduleNotice fallback,
  }) {
    return _scheduleNoticeReference(category).snapshots().map((snapshot) {
      final notice = CertificateCategoryScheduleNotice.fromMap(snapshot.data());
      return notice.items.isEmpty
          ? CertificateCategoryScheduleNotice(
              items: fallback.items,
              links: notice.links,
            )
          : notice;
    });
  }

  Future<CertificateCategoryScheduleNotice> getScheduleNotice(
    CertificateCategory category,
  ) async {
    final snapshot = await _scheduleNoticeReference(category).get();
    return CertificateCategoryScheduleNotice.fromMap(snapshot.data());
  }

  Future<void> saveScheduleNotice(
    CertificateCategory category,
    CertificateCategoryScheduleNotice notice,
  ) async {
    final batch = _firestore.batch();
    final categoryReference = _categoryReference(category);
    batch.set(categoryReference, {
      'category': category.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_scheduleNoticeReference(category), {
      'items': notice.items
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      'links': notice.links.map((link) => link.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  DocumentReference<Map<String, dynamic>> _scheduleNoticeReference(
    CertificateCategory category,
  ) {
    return _categoryReference(category)
        .collection(_scheduleNoticesCollectionName)
        .doc(_scheduleNoticeDocumentId);
  }

  DocumentReference<Map<String, dynamic>> _categoryReference(
    CertificateCategory category,
  ) => _firestore.collection(_collectionName).doc(category.name);

  static List<String> readItems(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
