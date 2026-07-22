import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityComment {
  final String id;
  final String parentCommentId;
  final String writerUid;
  final String writerNickname;
  final String writerProfileImageUrl;
  final String content;
  final bool isAccepted;
  final String commentStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const CommunityComment({
    required this.id,
    required this.parentCommentId,
    required this.writerUid,
    required this.writerNickname,
    required this.writerProfileImageUrl,
    required this.content,
    required this.isAccepted,
    required this.commentStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  bool get isReply {
    return parentCommentId.isNotEmpty;
  }

  factory CommunityComment.fromDocument(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    Map<String, dynamic> data = document.data();

    return CommunityComment(
      id: document.id,
      parentCommentId:
      data['parentCommentId']?.toString() ?? '',
      writerUid: data['writerUid']?.toString() ?? '',
      writerNickname:
      data['writerNickname']?.toString() ?? '사용자',
      writerProfileImageUrl:
      data['writerProfileImageUrl']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
      isAccepted: data['isAccepted'] == true,
      commentStatus:
      data['commentStatus']?.toString() ?? 'NORMAL',
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
      deletedAt: _readDateTime(data['deletedAt']),
    );
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
