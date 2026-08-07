import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AdminReportDecision { approve, reject }

class AdminReportService {
  AdminReportService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _firebaseAuth;

  Stream<List<AdminReport>> watchReports() {
    return _firestore.collection('reports').snapshots().map((snapshot) {
      return _sortedReports(snapshot.docs);
    });
  }

  Stream<List<AdminReport>> watchReportsForMember(String targetUid) {
    return _firestore
        .collection('reports')
        .where('targetUid', isEqualTo: targetUid)
        .snapshots()
        .map(
          (snapshot) => _sortedReports(snapshot.docs)
              .where(
                (report) =>
                    report.targetType == 'POST' ||
                    report.targetType == 'COMMENT' ||
                    report.targetType == 'STUDY_MEMBER',
              )
              .toList(),
        );
  }

  List<AdminReport> _sortedReports(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final reports = documents.map(AdminReport.fromDocument).toList();
    reports.sort((a, b) {
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });
    return reports;
  }

  Future<void> processReport({
    required AdminReport report,
    required AdminReportDecision decision,
    required bool hideContent,
  }) async {
    final administrator = _firebaseAuth.currentUser;
    if (administrator == null) {
      throw StateError('관리자 로그인이 필요합니다.');
    }
    await administrator.getIdToken(true);
    final operationId = _firestore.collection('adminOperations').doc().id;
    await _functions.httpsCallable('processAdminReport').call<Object?>({
      'operationId': operationId,
      'reportId': report.id,
      'decision': decision == AdminReportDecision.approve
          ? 'APPROVE'
          : 'REJECT',
      'hideContent': hideContent,
    });
  }

  Future<void> reopenReport(AdminReport report) async {
    final administrator = _firebaseAuth.currentUser;
    if (administrator == null) {
      throw StateError('관리자 로그인이 필요합니다.');
    }
    await administrator.getIdToken(true);
    final operationId = _firestore.collection('adminOperations').doc().id;
    await _functions.httpsCallable('reopenAdminReport').call<Object?>({
      'operationId': operationId,
      'reportId': report.id,
    });
  }
}

class AdminReport {
  const AdminReport({
    required this.id,
    required this.reporterNickname,
    required this.reporterUid,
    required this.targetType,
    required this.targetIds,
    required this.targetTitle,
    required this.targetNickname,
    required this.targetUid,
    required this.reasonType,
    required this.description,
    required this.status,
    required this.actionTypes,
    required this.processedBy,
    required this.createdAt,
    required this.processedAt,
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
      reporterUid: _text(data['reporterUid']),
      targetType: _text(data['targetType'], fallback: 'UNKNOWN').toUpperCase(),
      targetIds: _targetIds(data['targetId']),
      targetTitle: _text(data['targettitle'] ?? data['targetTitle']),
      targetNickname: _text(data['targetNickname']),
      targetUid: _text(data['targetUid']),
      reasonType: _text(data['reasonType'], fallback: 'OTHER'),
      description: _text(data['description']),
      status: _text(data['status'], fallback: 'PENDING').toUpperCase(),
      actionTypes: _stringList(data['actionType']),
      processedBy: _text(data['processedBy']),
      createdAt: _date(data['createdAt']),
      processedAt: _date(data['processedAt']),
    );
  }

  final String id;
  final String reporterNickname;
  final String reporterUid;
  final String targetType;
  final List<String> targetIds;
  final String targetTitle;
  final String targetNickname;
  final String targetUid;
  final String reasonType;
  final String description;
  final String status;
  final List<String> actionTypes;
  final String processedBy;
  final DateTime? createdAt;
  final DateTime? processedAt;

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'RESOLVED';
  bool get isRejected => status == 'REJECTED';

  bool get canHideContent {
    if (targetType == 'POST') return targetIds.isNotEmpty;
    if (targetType == 'COMMENT') return targetIds.length >= 2;
    return false;
  }

  bool get contentWasHidden => actionTypes.contains('DELETE');
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<String> _targetIds(Object? value) {
  if (value is! List) return const [];
  final result = <String>[];
  for (final item in value) {
    final id = item is Map
        ? item['id']?.toString().trim() ?? ''
        : item?.toString().trim() ?? '';
    if (id.isNotEmpty) result.add(id);
  }
  return result;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

String _text(Object? value, {String fallback = ''}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}
