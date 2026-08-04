import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminCommunityService {
  AdminCommunityService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  Stream<List<AdminCommunityPost>> watchPosts() {
    return _firestore.collection('posts').snapshots().map((snapshot) {
      final posts = snapshot.docs.map(AdminCommunityPost.fromDocument).toList();
      posts.sort(
        (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
          a.createdAt ?? DateTime(1970),
        ),
      );
      return posts;
    });
  }

  Stream<List<AdminCommunityComment>> watchComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .snapshots()
        .map((snapshot) {
          final comments = snapshot.docs
              .map(AdminCommunityComment.fromDocument)
              .toList();
          comments.sort(
            (a, b) => (a.createdAt ?? DateTime(1970)).compareTo(
              b.createdAt ?? DateTime(1970),
            ),
          );
          return comments;
        });
  }

  Future<void> hidePost(AdminCommunityPost post) async {
    final adminUid = _requireAdminUid();
    if (!post.isVisible) {
      throw StateError('이미 숨김 처리된 게시글입니다.');
    }

    await post.reference.update({
      'postStatus': 'DELETED',
      'visibility': 'PRIVATE',
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'moderationStatus': 'HIDDEN',
      'moderatedBy': adminUid,
      'moderatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> restorePost(AdminCommunityPost post) async {
    final adminUid = _requireAdminUid();
    if (!post.wasHiddenByAdmin) {
      throw StateError('관리자가 숨긴 게시글만 복구할 수 있습니다.');
    }

    await post.reference.update({
      'postStatus': 'NORMAL',
      'visibility': 'PUBLIC',
      'deletedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'moderationStatus': 'RESTORED',
      'moderatedBy': adminUid,
      'moderatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> hideComment({
    required String postId,
    required AdminCommunityComment comment,
  }) async {
    final adminUid = _requireAdminUid();

    if (comment.status != 'NORMAL') {
      throw StateError('이미 숨김 처리된 댓글입니다.');
    }

    final postReference =
    _firestore.collection('posts').doc(postId);

    final batchId = postReference
        .collection('comments')
        .doc()
        .id;

    await _firestore.runTransaction((transaction) async {
      final latest =
      await transaction.get(comment.reference);

      if (!latest.exists) {
        throw StateError('댓글을 찾을 수 없습니다.');
      }

      final latestData = latest.data()!;
      final latestStatus = _text(
        latestData['commentStatus'],
        fallback: 'NORMAL',
      ).toUpperCase();

      if (latestStatus != 'NORMAL') {
        throw StateError('이미 숨김 처리된 댓글입니다.');
      }

      final isRootComment =
          _text(latestData['parentCommentId']).isEmpty;
      final wasAccepted =
          latestData['isAccepted'] == true;

      transaction.update(comment.reference, {
        'commentStatus': 'DELETED',
        'isAccepted': false,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'moderationStatus': 'HIDDEN',
        'moderationBatchId': batchId,
        'moderationReportId': null,
        'moderatedBy': adminUid,
        'moderatedAt': FieldValue.serverTimestamp(),
      });

      final postUpdates = <String, Object?>{
        'commentCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isRootComment && wasAccepted) {
        postUpdates['questionStatus'] = 'WAITING';
      }

      transaction.update(
        postReference,
        postUpdates,
      );
    });
  }

  Future<void> restoreComment({
    required String postId,
    required AdminCommunityComment comment,
  }) async {
    final adminUid = _requireAdminUid();
    if (!comment.wasHiddenByAdmin) {
      throw StateError('관리자가 숨긴 댓글만 복구할 수 있습니다.');
    }

    final postReference = _firestore.collection('posts').doc(postId);
    final commentsReference = postReference.collection('comments');
    final batchId = comment.moderationBatchId;
    final documents = <DocumentSnapshot<Map<String, dynamic>>>[];

    if (batchId.isEmpty) {
      documents.add(await comment.reference.get());
    } else {
      final snapshot = await commentsReference
          .where('moderationBatchId', isEqualTo: batchId)
          .get();
      documents.addAll(snapshot.docs);
    }

    final restorable = documents.where((document) {
      if (!document.exists) return false;
      return _text(document.data()?['moderationStatus']).toUpperCase() ==
          'HIDDEN';
    }).toList();
    if (restorable.isEmpty) {
      throw StateError('복구할 댓글을 찾을 수 없습니다.');
    }

    final batch = _firestore.batch();
    for (final document in restorable) {
      batch.update(document.reference, {
        'commentStatus': 'NORMAL',
        'deletedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'moderationStatus': 'RESTORED',
        'moderatedBy': adminUid,
        'moderatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(postReference, {
      'commentCount': FieldValue.increment(restorable.length),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  String _requireAdminUid() {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) throw StateError('관리자 로그인이 필요합니다.');
    return uid;
  }
}

class AdminCommunityPost {
  const AdminCommunityPost({
    required this.id,
    required this.boardType,
    required this.title,
    required this.content,
    required this.writerNickname,
    required this.status,
    required this.visibility,
    required this.moderationStatus,
    required this.commentCount,
    required this.viewCount,
    required this.likeCount,
    required this.createdAt,
    required this.reference,
  });

  factory AdminCommunityPost.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return AdminCommunityPost(
      id: document.id,
      boardType: _text(data['boardType'], fallback: 'FREE').toUpperCase(),
      title: _text(data['title'], fallback: '제목 없는 게시글'),
      content: _text(data['content']),
      writerNickname: _text(data['writerNickname'], fallback: '사용자'),
      status: _text(data['postStatus'], fallback: 'NORMAL').toUpperCase(),
      visibility: _text(data['visibility'], fallback: 'PUBLIC').toUpperCase(),
      moderationStatus: _text(data['moderationStatus']).toUpperCase(),
      commentCount: _integer(data['commentCount']),
      viewCount: _integer(data['viewCount']),
      likeCount: _integer(data['likeCount']),
      createdAt: _date(data['createdAt']),
      reference: document.reference,
    );
  }

  final String id;
  final String boardType;
  final String title;
  final String content;
  final String writerNickname;
  final String status;
  final String visibility;
  final String moderationStatus;
  final int commentCount;
  final int viewCount;
  final int likeCount;
  final DateTime? createdAt;
  final DocumentReference<Map<String, dynamic>> reference;

  bool get isVisible => status == 'NORMAL' && visibility == 'PUBLIC';
  bool get wasHiddenByAdmin => moderationStatus == 'HIDDEN';
}

class AdminCommunityComment {
  const AdminCommunityComment({
    required this.id,
    required this.parentCommentId,
    required this.writerNickname,
    required this.content,
    required this.status,
    required this.moderationStatus,
    required this.moderationBatchId,
    required this.createdAt,
    required this.reference,
  });

  factory AdminCommunityComment.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return AdminCommunityComment(
      id: document.id,
      parentCommentId: _text(data['parentCommentId']),
      writerNickname: _text(data['writerNickname'], fallback: '사용자'),
      content: _text(data['content'], fallback: '내용 없음'),
      status: _text(data['commentStatus'], fallback: 'NORMAL').toUpperCase(),
      moderationStatus: _text(data['moderationStatus']).toUpperCase(),
      moderationBatchId: _text(data['moderationBatchId']),
      createdAt: _date(data['createdAt']),
      reference: document.reference,
    );
  }

  final String id;
  final String parentCommentId;
  final String writerNickname;
  final String content;
  final String status;
  final String moderationStatus;
  final String moderationBatchId;
  final DateTime? createdAt;
  final DocumentReference<Map<String, dynamic>> reference;

  bool get isReply => parentCommentId.isNotEmpty;
  bool get wasHiddenByAdmin => moderationStatus == 'HIDDEN';
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
