import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCertificateStatisticsService {
  AdminCertificateStatisticsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<AdminCertificateStatisticsData> getStatistics(
    String certificationId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('certifications')
          .doc(certificationId)
          .collection('statistics')
          .get();
      final documents = {
        for (final document in snapshot.docs) document.id: document.data(),
      };
      return AdminCertificateStatisticsData(
        statisticsByType: {
          for (final type in AdminCertificateStatisticsType.values)
            type: _readEntries(documents[type.documentId]),
        },
        existingTypes: {
          for (final type in AdminCertificateStatisticsType.values)
            if (documents.containsKey(type.documentId)) type,
        },
      );
    } on FirebaseException catch (error) {
      throw AdminCertificateStatisticsException(
        error.message ?? '통계 정보를 불러오지 못했습니다.',
      );
    }
  }

  Future<void> saveStatistics({
    required String certificationId,
    required Map<
      AdminCertificateStatisticsType,
      List<AdminCertificateStatisticEntry>
    >
    statisticsByType,
  }) async {
    if (statisticsByType.isEmpty) return;
    try {
      final statisticsReference = _firestore
          .collection('certifications')
          .doc(certificationId)
          .collection('statistics');
      final batch = _firestore.batch();
      for (final entry in statisticsByType.entries) {
        final statistics = [...entry.value]
          ..sort((first, second) => second.year.compareTo(first.year));
        batch.set(statisticsReference.doc(entry.key.documentId), {
          'yearlyStatistics': statistics
              .map((statistic) => statistic.toMap())
              .toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } on FirebaseException catch (error) {
      throw AdminCertificateStatisticsException(
        error.message ?? '통계 정보를 저장하지 못했습니다.',
      );
    }
  }

  static List<AdminCertificateStatisticEntry> _readEntries(
    Map<String, dynamic>? data,
  ) {
    final value = data?['yearlyStatistics'] ?? data?['statistics'];
    if (value is! List) return const [];
    final entries =
        value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .map(AdminCertificateStatisticEntry.fromMap)
            .where((entry) => entry.year > 0)
            .toList()
          ..sort((first, second) => second.year.compareTo(first.year));
    return entries;
  }
}

enum AdminCertificateStatisticsType {
  written('written', '필기'),
  practical('practical', '실기/면접'),
  integrated('integrated', '통합');

  const AdminCertificateStatisticsType(this.documentId, this.label);

  final String documentId;
  final String label;
}

class AdminCertificateStatisticsData {
  const AdminCertificateStatisticsData({
    required this.statisticsByType,
    required this.existingTypes,
  });

  final Map<
    AdminCertificateStatisticsType,
    List<AdminCertificateStatisticEntry>
  >
  statisticsByType;
  final Set<AdminCertificateStatisticsType> existingTypes;
}

class AdminCertificateStatisticEntry {
  const AdminCertificateStatisticEntry({
    required this.year,
    required this.registrationCount,
    required this.examineeCount,
    required this.passerCount,
  });

  final int year;
  final int registrationCount;
  final int examineeCount;
  final int passerCount;

  factory AdminCertificateStatisticEntry.fromMap(Map<String, dynamic> map) {
    return AdminCertificateStatisticEntry(
      year: _readInt(map['year']),
      registrationCount: _readInt(map['registrationCount']),
      examineeCount: _readInt(map['examineeCount']),
      passerCount: _readInt(map['passerCount']),
    );
  }

  Map<String, int> toMap() => {
    'year': year,
    'registrationCount': registrationCount,
    'examineeCount': examineeCount,
    'passerCount': passerCount,
  };

  static int _readInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ??
        0;
  }
}

class AdminCertificateStatisticsException implements Exception {
  const AdminCertificateStatisticsException(this.message);

  final String message;
}
