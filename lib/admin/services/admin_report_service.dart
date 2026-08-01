import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReportService {
  AdminReportService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AdminReport>> watchReports() {
    return _firestore.collection('reports').snapshots().map((snapshot) {
      final reports = snapshot.docs.map(AdminReport.fromDocument).toList();
      reports.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      return reports;
    });
  }
}

class AdminReport {
  const AdminReport({
    required this.id,
    required this.reporterNickname,
    required this.targetType,
    required this.targetTitle,
    required this.targetNickname,
    required this.reasonType,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory AdminReport.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return AdminReport(
      id: document.id,
      reporterNickname: _text(
        data['reporterNicname'] ?? data['reporterNickname'],
        fallback: '알 수 없음',
      ),
      targetType: _text(data['targetType'], fallback: 'UNKNOWN'),
      targetTitle: _text(data['targettitle'] ?? data['targetTitle']),
      targetNickname: _text(data['targetNickname']),
      reasonType: _text(data['reasonType'], fallback: 'OTHER'),
      description: _text(data['description']),
      status: _text(data['status'], fallback: 'PENDING'),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  final String id;
  final String reporterNickname;
  final String targetType;
  final String targetTitle;
  final String targetNickname;
  final String reasonType;
  final String description;
  final String status;
  final DateTime? createdAt;

  bool get isPending => status.toUpperCase() == 'PENDING';

  static String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
