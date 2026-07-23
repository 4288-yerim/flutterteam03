import 'package:cloud_firestore/cloud_firestore.dart';

import 'community_comment_models.dart';
import 'community_models.dart';

class CommunityService {
  final FirebaseFirestore _firestore;

  CommunityService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<CommunityPost>> watchPosts() {
    return _firestore
        .collection('posts')
        .where('postStatus', isEqualTo: 'NORMAL')
        .where('visibility', isEqualTo: 'PUBLIC')
        .snapshots()
        .map((snapshot) {
      List<CommunityPost> posts = [];

      for (QueryDocumentSnapshot<Map<String, dynamic>> document
      in snapshot.docs) {
        CommunityPost post =
        CommunityPost.fromDocument(document);

        posts.add(post);
      }

      posts.sort((a, b) {
        int aTime =
            a.createdAt?.millisecondsSinceEpoch ?? 0;
        int bTime =
            b.createdAt?.millisecondsSinceEpoch ?? 0;

        return bTime.compareTo(aTime);
      });

      return posts;
    });
  }

  Stream<CommunityPost?> watchPost(String postId) {
    return _firestore
        .collection('posts')
        .where(
      FieldPath.documentId,
      isEqualTo: postId,
    )
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }

      CommunityPost post =
      CommunityPost.fromDocument(
        snapshot.docs.first,
      );

      if (post.postStatus != 'NORMAL' ||
          post.visibility != 'PUBLIC') {
        return null;
      }

      return post;
    });
  }

  Future<void> increaseViewCount(
      String postId,
      ) async {
    await _firestore
        .collection('posts')
        .doc(postId)
        .update({
      'viewCount': FieldValue.increment(1),
    });
  }

  String createPostId() {
    return _firestore.collection('posts').doc().id;
  }

  Future<String> addPost({
    String? postId,
    required CommunityBoardType boardType,
    required String title,
    required String content,
    required String writerUid,
    required String writerNickname,
    required String writerProfileImageUrl,
    required bool isCertifiedWriter,
    List<CommunityCertificateTag> certificateTags =
    const [],
    List<Map<String, dynamic>> imageAttachments =
    const [],
    List<Map<String, dynamic>> fileAttachments =
    const [],
  }) async {
    DocumentReference<Map<String, dynamic>>
    document =
    _firestore.collection('posts').doc(postId);

    await document.set({
      'boardType': boardType.code,
      'title': title,
      'content': content,
      'writerUid': writerUid,
      'writerNickname': writerNickname,
      'writerProfileImageUrl':
      writerProfileImageUrl,
      'isCertifiedWriter': isCertifiedWriter,
      'certificateTags':
      certificateTags.map((tag) {
        return tag.toMap();
      }).toList(),
      'imageAttachments': imageAttachments,
      'fileAttachments': fileAttachments,
      'viewCount': 0,
      'commentCount': 0,
      'likeCount': 0,
      'bookmarkCount': 0,
      'questionStatus':
      boardType == CommunityBoardType.question
          ? 'WAITING'
          : '',
      'recruitStatus':
      boardType ==
          CommunityBoardType.groupRecruit
          ? 'OPEN'
          : '',
      'postStatus': 'NORMAL',
      'visibility': 'PUBLIC',
      'studyGroupId': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'deletedAt': null,
    });

    return document.id;
  }

  Future<void> updatePost({
    required String postId,
    required CommunityBoardType boardType,
    required String title,
    required String content,
  }) async {
    await _firestore
        .collection('posts')
        .doc(postId)
        .update({
      'boardType': boardType.code,
      'title': title,
      'content': content,
      'questionStatus':
      boardType == CommunityBoardType.question
          ? 'WAITING'
          : '',
      'recruitStatus':
      boardType ==
          CommunityBoardType.groupRecruit
          ? 'OPEN'
          : '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePost(
      String postId,
      ) async {
    await _firestore
        .collection('posts')
        .doc(postId)
        .update({
      'postStatus': 'DELETED',
      'visibility': 'PRIVATE',
      'updatedAt': FieldValue.serverTimestamp(),
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<CommunityComment>> watchComments(
      String postId,
      ) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .where(
      'commentStatus',
      isEqualTo: 'NORMAL',
    )
        .snapshots()
        .map((snapshot) {
      List<CommunityComment> comments = [];

      for (QueryDocumentSnapshot<
          Map<String, dynamic>>
      document in snapshot.docs) {
        CommunityComment comment =
        CommunityComment.fromDocument(
          document,
        );

        comments.add(comment);
      }

      comments.sort((a, b) {
        int aTime =
            a.createdAt?.millisecondsSinceEpoch ?? 0;
        int bTime =
            b.createdAt?.millisecondsSinceEpoch ?? 0;

        return aTime.compareTo(bTime);
      });

      return comments;
    });
  }

  Future<String> addComment({
    required String postId,
    required String content,
    required String writerUid,
    required String writerNickname,
    required String writerProfileImageUrl,
    String parentCommentId = '',
  }) async {
    DocumentReference<Map<String, dynamic>>
    postReference =
    _firestore
        .collection('posts')
        .doc(postId);

    DocumentReference<Map<String, dynamic>>
    commentReference =
    postReference
        .collection('comments')
        .doc();

    WriteBatch batch = _firestore.batch();

    batch.set(commentReference, {
      'parentCommentId': parentCommentId,
      'writerUid': writerUid,
      'writerNickname': writerNickname,
      'writerProfileImageUrl':
      writerProfileImageUrl,
      'content': content,
      'isAccepted': false,
      'commentStatus': 'NORMAL',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'deletedAt': null,
    });

    batch.update(postReference, {
      'commentCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return commentReference.id;
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    DocumentReference<Map<String, dynamic>>
    postReference =
    _firestore
        .collection('posts')
        .doc(postId);

    CollectionReference<Map<String, dynamic>>
    commentsReference =
    postReference.collection('comments');

    DocumentReference<Map<String, dynamic>>
    commentReference =
    commentsReference.doc(commentId);

    DocumentSnapshot<Map<String, dynamic>>
    commentSnapshot =
    await commentReference.get();

    if (!commentSnapshot.exists) {
      return;
    }

    Map<String, dynamic>? commentData =
    commentSnapshot.data();

    if (commentData == null ||
        commentData['commentStatus'] != 'NORMAL') {
      return;
    }

    QuerySnapshot<Map<String, dynamic>>
    replySnapshot =
    await commentsReference
        .where(
      'parentCommentId',
      isEqualTo: commentId,
    )
        .get();

    List<QueryDocumentSnapshot<
        Map<String, dynamic>>> normalReplies = [];

    for (QueryDocumentSnapshot<
        Map<String, dynamic>>
    document in replySnapshot.docs) {
      if (document.data()['commentStatus'] ==
          'NORMAL') {
        normalReplies.add(document);
      }
    }

    bool wasAccepted =
        commentData['isAccepted'] == true;

    WriteBatch batch = _firestore.batch();

    batch.update(commentReference, {
      'commentStatus': 'DELETED',
      'isAccepted': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'deletedAt': FieldValue.serverTimestamp(),
    });

    for (QueryDocumentSnapshot<
        Map<String, dynamic>>
    reply in normalReplies) {
      batch.update(reply.reference, {
        'commentStatus': 'DELETED',
        'isAccepted': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'deletedAt':
        FieldValue.serverTimestamp(),
      });
    }

    Map<String, dynamic> postUpdateData = {
      'commentCount': FieldValue.increment(
        -(1 + normalReplies.length),
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (wasAccepted) {
      postUpdateData['questionStatus'] =
      'WAITING';
    }

    batch.update(
      postReference,
      postUpdateData,
    );

    await batch.commit();
  }

  Future<void> acceptAnswer({
    required String postId,
    required String commentId,
  }) async {
    DocumentReference<Map<String, dynamic>>
    postReference =
    _firestore
        .collection('posts')
        .doc(postId);

    CollectionReference<Map<String, dynamic>>
    commentsReference =
    postReference.collection('comments');

    QuerySnapshot<Map<String, dynamic>>
    acceptedComments =
    await commentsReference
        .where(
      'isAccepted',
      isEqualTo: true,
    )
        .get();

    WriteBatch batch = _firestore.batch();

    for (QueryDocumentSnapshot<
        Map<String, dynamic>>
    document in acceptedComments.docs) {
      batch.update(document.reference, {
        'isAccepted': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.update(
      commentsReference.doc(commentId),
      {
        'isAccepted': true,
        'updatedAt':
        FieldValue.serverTimestamp(),
      },
    );

    batch.update(postReference, {
      'questionStatus': 'RESOLVED',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  List<CommunityPost> filterAndSortPosts({
    required List<CommunityPost> posts,
    required CommunityBoardType boardType,
    required CommunityPostSort sort,
    required String keyword,
    required String certificateId,
  }) {
    String normalizedKeyword =
    keyword.trim().toLowerCase();

    List<CommunityPost> result =
    posts.where((post) {
      if (boardType != CommunityBoardType.all &&
          post.boardType != boardType) {
        return false;
      }

      if (certificateId.isNotEmpty) {
        bool hasCertificate =
        post.certificateTags.any((tag) {
          return tag.certificateId ==
              certificateId;
        });

        if (!hasCertificate) {
          return false;
        }
      }

      if (normalizedKeyword.isEmpty) {
        return true;
      }

      String searchableText = [
        post.title,
        post.content,
        post.writerNickname,
        ...post.certificateTags.map((tag) {
          return tag.certificateName;
        }),
      ].join(' ').toLowerCase();

      return searchableText.contains(
        normalizedKeyword,
      );
    }).toList();

    result.sort((a, b) {
      switch (sort) {
        case CommunityPostSort.views:
          return b.viewCount.compareTo(
            a.viewCount,
          );

        case CommunityPostSort.likes:
          return b.likeCount.compareTo(
            a.likeCount,
          );

        case CommunityPostSort.comments:
          return b.commentCount.compareTo(
            a.commentCount,
          );

        case CommunityPostSort.latest:
          int aTime =
              a.createdAt?.millisecondsSinceEpoch ??
                  0;
          int bTime =
              b.createdAt?.millisecondsSinceEpoch ??
                  0;

          return bTime.compareTo(aTime);
      }
    });

    return result;
  }

  List<CommunityPost> getPopularPosts(
      List<CommunityPost> posts,
      ) {
    List<CommunityPost> result =
    List<CommunityPost>.from(posts);

    result.sort((a, b) {
      int aScore = a.likeCount * 3 +
          a.commentCount * 2 +
          a.viewCount;

      int bScore = b.likeCount * 3 +
          b.commentCount * 2 +
          b.viewCount;

      return bScore.compareTo(aScore);
    });

    if (result.length > 3) {
      return result.sublist(0, 3);
    }

    return result;
  }

  List<CommunityCertificateTag>
  collectCertificateTags(
      List<CommunityPost> posts,
      ) {
    Map<String, CommunityCertificateTag>
    tagMap = {};

    for (CommunityPost post in posts) {
      for (CommunityCertificateTag tag
      in post.certificateTags) {
        if (tag.certificateId.isEmpty ||
            tag.certificateName.isEmpty) {
          continue;
        }

        tagMap[tag.certificateId] = tag;
      }
    }

    List<CommunityCertificateTag> result =
    tagMap.values.toList();

    result.sort((a, b) {
      return a.certificateName.compareTo(
        b.certificateName,
      );
    });

    return result;
  }
}
