import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AdminReportDecision { approve, reject }

class AdminReportService {
  AdminReportService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  Stream<List<AdminReport>> watchReports() {
    return _firestore.collection('reports').snapshots().map((snapshot) {
      return _sortedReports(snapshot.docs);
    });
  }

  /// Reports whose target is [targetUid], limited to community posts/comments.
  Stream<List<AdminReport>> watchContentReportsForMember(String targetUid) {
    return _firestore
        .collection('reports')
        .where('targetUid', isEqualTo: targetUid)
        .snapshots()
        .map((snapshot) => _sortedReports(snapshot.docs)
            .where(
              (report) =>
                  report.targetType == 'POST' || report.targetType == 'COMMENT',
            )
            .toList());
  }

  List<AdminReport> _sortedReports(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final reports = documents.map(AdminReport.fromDocument).toList();
    reports.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
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
      throw StateError('관리자 로그인 정보를 확인할 수 없습니다.');
    }

    final reportReference =
    _firestore.collection('reports').doc(report.id);

    await _firestore.runTransaction((transaction) async {
      final latestReport =
      await transaction.get(reportReference);

      if (!latestReport.exists) {
        throw StateError('신고 문서를 찾을 수 없습니다.');
      }

      final latestStatus = latestReport
          .data()?['status']
          ?.toString()
          .toUpperCase() ??
          '';

      if (latestStatus != 'PENDING') {
        throw StateError('이미 처리된 신고입니다.');
      }

      final approved =
          decision == AdminReportDecision.approve;

      final shouldHideContent =
          approved &&
              hideContent &&
              report.canHideContent;

      DocumentReference<Map<String, dynamic>>?
      targetPostReference;
      DocumentReference<Map<String, dynamic>>?
      targetCommentReference;
      DocumentSnapshot<Map<String, dynamic>>?
      latestComment;

      // Firestore 트랜잭션은 읽기를 먼저 끝내야 하므로
      // 댓글 숨김에 필요한 문서를 먼저 읽습니다.
      if (shouldHideContent &&
          report.targetType.toUpperCase() == 'COMMENT') {
        targetPostReference = _firestore
            .collection('posts')
            .doc(report.targetIds[0]);

        targetCommentReference = targetPostReference
            .collection('comments')
            .doc(report.targetIds[1]);

        latestComment = await transaction.get(
          targetCommentReference,
        );

        if (!latestComment.exists) {
          throw StateError('신고 대상 댓글을 찾을 수 없습니다.');
        }

        final latestCommentStatus = latestComment
            .data()?['commentStatus']
            ?.toString()
            .toUpperCase() ??
            'NORMAL';

        if (latestCommentStatus != 'NORMAL') {
          throw StateError(
            '신고 대상 댓글이 이미 숨김 처리되었습니다.',
          );
        }
      }

      final actionTypes = <String>[];

      if (!approved) {
        actionTypes.add('NONE');
      } else {
        if (report.targetUid.isNotEmpty) {
          actionTypes.add('WARNING');
        }

        if (shouldHideContent) {
          actionTypes.add('DELETE');
        }

        if (actionTypes.isEmpty) {
          actionTypes.add('NONE');
        }
      }

      transaction.update(reportReference, {
        'status': approved ? 'RESOLVED' : 'REJECTED',
        'actionType': actionTypes,
        'processedBy': administrator.uid,
        'processedAt': FieldValue.serverTimestamp(),
      });

      if (!approved) {
        return;
      }

      if (report.targetUid.isNotEmpty) {
        final counterUpdates = <String, Object>{
          'reportCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        switch (report.targetType.toUpperCase()) {
          case 'POST':
            counterUpdates['postReportCount'] =
                FieldValue.increment(1);
            break;

          case 'COMMENT':
            counterUpdates['commentsReportCount'] =
                FieldValue.increment(1);
            break;

          case 'STUDY_MEMBER':
            counterUpdates['studyMemberReportCount'] =
                FieldValue.increment(1);
            break;
        }

        transaction.update(
          _firestore
              .collection('users')
              .doc(report.targetUid),
          counterUpdates,
        );
      }

      if (!shouldHideContent) {
        return;
      }

      switch (report.targetType.toUpperCase()) {
        case 'POST':
          transaction.update(
            _firestore
                .collection('posts')
                .doc(report.targetIds.first),
            {
              'postStatus': 'DELETED',
              'visibility': 'PRIVATE',
              'deletedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
          break;

        case 'COMMENT':
          final commentData = latestComment!.data()!;

          final isRootComment =
              (commentData['parentCommentId']
                  ?.toString()
                  .trim() ??
                  '')
                  .isEmpty;

          final wasAccepted =
              commentData['isAccepted'] == true;

          transaction.update(
            targetCommentReference!,
            {
              'commentStatus': 'DELETED',
              'isAccepted': false,
              'deletedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'moderationStatus': 'REPORT_HIDDEN',
              'moderationBatchId': null,
              'moderationReportId': report.id,
              'moderatedBy': administrator.uid,
              'moderatedAt':
              FieldValue.serverTimestamp(),
            },
          );

          final postUpdates = <String, Object?>{
            'commentCount': FieldValue.increment(-1),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (isRootComment && wasAccepted) {
            postUpdates['questionStatus'] = 'WAITING';
          }

          transaction.update(
            targetPostReference!,
            postUpdates,
          );
          break;
      }
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

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<String> _targetIds(Object? value) {
    if (value is! List) return const [];
    final result = <String>[];
    for (final item in value) {
      if (item is Map) {
        final id = item['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) result.add(id);
      } else {
        final id = item?.toString().trim() ?? '';
        if (id.isNotEmpty) result.add(id);
      }
    }
    return result;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
