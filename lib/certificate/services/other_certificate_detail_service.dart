import 'package:cloud_firestore/cloud_firestore.dart';

import 'certificate_detail_service.dart';
import 'certificate_search_service.dart';
import 'technical_certificate_service.dart';
import 'certificate_category_content_service.dart';

class OtherCertificateDetailService {
  OtherCertificateDetailService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _certifications =>
      _firestore.collection('certifications');

  Future<Certification> getCertificate(String certificationId) async {
    try {
      final document = await _certifications.doc(certificationId).get();
      if (!document.exists || document.data() == null) {
        throw const CertificateDetailException('자격증 정보를 찾을 수 없습니다.');
      }

      final certificate = Certification.fromFirestore(document);
      if (!certificate.hasSource) {
        throw const CertificateDetailException('그 외 자격증 정보가 아닙니다.');
      }
      return certificate;
    } on CertificateDetailException {
      rethrow;
    } on FirebaseException catch (error) {
      throw CertificateDetailException(error.message ?? '자격증 정보를 불러오지 못했습니다.');
    }
  }

  Future<List<TechnicalCertificateSchedule>> getSchedules(
    String certificationId,
  ) async {
    try {
      final snapshot = await _certifications
          .doc(certificationId)
          .collection('schedules')
          .orderBy('sortdate')
          .get();
      final schedules =
          snapshot.docs.map(TechnicalCertificateSchedule.fromFirestore).toList()
            ..sort(TechnicalCertificateSchedule.compareForDisplay);
      return schedules;
    } on FirebaseException catch (error) {
      throw CertificateDetailException(error.message ?? '시험 일정을 불러오지 못했습니다.');
    }
  }

  Future<OtherCertificateExamDetails> getExamDetails(
    String certificationId,
  ) async {
    try {
      final details = _certifications
          .doc(certificationId)
          .collection('details');
      final documents = await Future.wait([
        details.doc('examFee').get(),
        details.doc('examTrends').get(),
        details.doc('howToObtain').get(),
        details.doc('scheduleLinks').get(),
      ]);
      return OtherCertificateExamDetails(
        writtenFee:
            _readFee(documents[0].data(), 'feeRound1') ??
            _readFee(documents[0].data(), 'writtenFee'),
        practicalFee:
            _readFee(documents[0].data(), 'feeRound2') ??
            _readFee(documents[0].data(), 'practicalFee'),
        examFeeLinks: _readLinks(documents[0].data()),
        examTrends: _readString(documents[1].data()?['contents']),
        examTrendsLinks: _readLinks(documents[1].data()),
        howToObtain: _readString(documents[2].data()?['contents']),
        howToObtainLinks: _readLinks(documents[2].data()),
        scheduleLinks: _readLinks(documents[3].data()),
      );
    } on FirebaseException catch (error) {
      throw CertificateDetailException(error.message ?? '자격 정보를 불러오지 못했습니다.');
    }
  }

  Future<OtherCertificateStatistics> getStatistics(
    String certificationId,
  ) async {
    try {
      final snapshot = await _certifications
          .doc(certificationId)
          .collection('statistics')
          .get();
      final documents = {
        for (final document in snapshot.docs) document.id: document,
      };
      return OtherCertificateStatistics(
        writtenStatistics: _readStatistics(documents['written']?.data()),
        practicalStatistics: _readStatistics(documents['practical']?.data()),
        integratedStatistics: _readStatistics(documents['integrated']?.data()),
        hasWrittenDocument: documents.containsKey('written'),
        hasPracticalDocument: documents.containsKey('practical'),
        hasIntegratedDocument: documents.containsKey('integrated'),
      );
    } on FirebaseException catch (error) {
      throw CertificateDetailException(error.message ?? '통계 정보를 불러오지 못했습니다.');
    }
  }

  static int? _readFee(Map<String, dynamic>? data, String key) {
    final value = data?[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static List<CertificateExamStatistic> _readStatistics(
    Map<String, dynamic>? data,
  ) {
    final value = data?['yearlyStatistics'] ?? data?['statistics'];
    if (value is! List) return const [];
    final statistics =
        value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .map(
              (item) => CertificateExamStatistic(
                year: _readInt(item['year']),
                registrationCount: _readInt(item['registrationCount']),
                examineeCount: _readInt(item['examineeCount']),
                passerCount: _readInt(item['passerCount']),
              ),
            )
            .where((item) => item.year > 0 && item.hasData)
            .toList()
          ..sort((first, second) => second.year.compareTo(first.year));
    return statistics.take(5).toList();
  }

  static int _readInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ??
        0;
  }

  static String _readString(dynamic value) => value is List
      ? value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .join('\n')
      : value?.toString().trim() ?? '';

  static List<CertificateContentLink> _readLinks(Map<String, dynamic>? data) {
    final links = (data?['links'] as List? ?? const [])
        .map(CertificateContentLink.fromMap)
        .where((link) => link.label.isNotEmpty && link.url.isNotEmpty)
        .toList();
    return links;
  }
}

class OtherCertificateExamDetails {
  final int? writtenFee;
  final int? practicalFee;
  final String examTrends;
  final String howToObtain;
  final List<CertificateContentLink> examFeeLinks;
  final List<CertificateContentLink> examTrendsLinks;
  final List<CertificateContentLink> howToObtainLinks;
  final List<CertificateContentLink> scheduleLinks;

  const OtherCertificateExamDetails({
    required this.writtenFee,
    required this.practicalFee,
    required this.examTrends,
    required this.howToObtain,
    this.examFeeLinks = const [],
    this.examTrendsLinks = const [],
    this.howToObtainLinks = const [],
    this.scheduleLinks = const [],
  });
}

class OtherCertificateStatistics {
  const OtherCertificateStatistics({
    required this.writtenStatistics,
    required this.practicalStatistics,
    required this.integratedStatistics,
    required this.hasWrittenDocument,
    required this.hasPracticalDocument,
    required this.hasIntegratedDocument,
  });

  const OtherCertificateStatistics.empty()
    : writtenStatistics = const [],
      practicalStatistics = const [],
      integratedStatistics = const [],
      hasWrittenDocument = false,
      hasPracticalDocument = false,
      hasIntegratedDocument = false;

  final List<CertificateExamStatistic> writtenStatistics;
  final List<CertificateExamStatistic> practicalStatistics;
  final List<CertificateExamStatistic> integratedStatistics;
  final bool hasWrittenDocument;
  final bool hasPracticalDocument;
  final bool hasIntegratedDocument;

  bool get hasDocuments =>
      hasWrittenDocument || hasPracticalDocument || hasIntegratedDocument;

  int get baseYear {
    final years = [
      ...writtenStatistics,
      ...practicalStatistics,
      ...integratedStatistics,
    ].map((item) => item.year);
    if (years.isEmpty) return DateTime.now().year - 1;
    return years.reduce((first, second) => first > second ? first : second);
  }
}
