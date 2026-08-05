import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminCommunityService {
  AdminCommunityService({
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

  Future<void> hidePost(AdminCommunityPost post) {
    return _moderatePost(postId: post.id, action: 'HIDE');
  }

  Future<void> restorePost(AdminCommunityPost post) {
    return _moderatePost(postId: post.id, action: 'RESTORE');
  }

  Future<void> hideComment({
    required String postId,
    required AdminCommunityComment comment,
  }) {
    return _moderateComment(
      postId: postId,
      commentId: comment.id,
      action: 'HIDE',
    );
  }

  Future<void> restoreComment({
    required String postId,
    required AdminCommunityComment comment,
  }) {
    return _moderateComment(
      postId: postId,
      commentId: comment.id,
      action: 'RESTORE',
    );
  }

  Future<void> _moderatePost({
    required String postId,
    required String action,
  }) async {
    await _callModeration({
      'targetType': 'POST',
      'postId': postId,
      'action': action,
    });
  }

  Future<void> _moderateComment({
    required String postId,
    required String commentId,
    required String action,
  }) async {
    await _callModeration({
      'targetType': 'COMMENT',
      'postId': postId,
      'commentId': commentId,
      'action': action,
    });
  }

  Future<void> _callModeration(Map<String, Object?> data) async {
    final administrator = _firebaseAuth.currentUser;
    if (administrator == null) {
      throw StateError('관리자 로그인이 필요합니다.');
    }
    await administrator.getIdToken(true);
    final operationId = _firestore.collection('adminOperations').doc().id;
    await _functions
        .httpsCallable('moderateAdminCommunityContent')
        .call<Object?>({'operationId': operationId, ...data});
  }
}

class AdminCommunityPost {
  const AdminCommunityPost({
    required this.id,
    required this.boardType,
    required this.title,
    required this.content,
    required this.writerUid,
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
      writerUid: _text(data['writerUid'] ?? data['uid']),
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
  final String writerUid;
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
    required this.writerUid,
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
      writerUid: _text(data['writerUid'] ?? data['uid']),
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
  final String writerUid;
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
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
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
