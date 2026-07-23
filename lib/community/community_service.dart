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
    bool verifiedWriter = isCertifiedWriter;

    if (boardType == CommunityBoardType.passReview) {
      List<CommunityCertificateTag> certifiedTags =
      await getCertifiedCertificateTags(writerUid);

      bool canWritePassReview =
          certificateTags.length == 1 &&
              certifiedTags.any((certifiedTag) {
                return certifiedTag.certificateId ==
                    certificateTags.first.certificateId;
              });

      if (!canWritePassReview) {
        throw StateError(
          '합격 인증된 자격증의 합격 후기만 작성할 수 있습니다.',
        );
      }

      verifiedWriter = true;
    }

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
      'isCertifiedWriter': verifiedWriter,
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
    if (boardType == CommunityBoardType.passReview) {
      DocumentSnapshot<Map<String, dynamic>>
      postSnapshot =
      await _firestore
          .collection('posts')
          .doc(postId)
          .get();

      Map<String, dynamic> postData =
          postSnapshot.data() ?? {};

      String writerUid =
          postData['writerUid']?.toString() ?? '';

      List<CommunityCertificateTag> postTags = [];
      dynamic tagValue = postData['certificateTags'];

      if (tagValue is List) {
        for (dynamic item in tagValue) {
          if (item is Map) {
            postTags.add(
              CommunityCertificateTag.fromMap(
                Map<String, dynamic>.from(item),
              ),
            );
          }
        }
      }

      List<CommunityCertificateTag> certifiedTags =
      await getCertifiedCertificateTags(writerUid);

      bool canWritePassReview =
          postTags.length == 1 &&
              certifiedTags.any((certifiedTag) {
                return certifiedTag.certificateId ==
                    postTags.first.certificateId;
              });

      if (!canWritePassReview) {
        throw StateError(
          '합격 인증된 자격증의 합격 후기만 작성할 수 있습니다.',
        );
      }
    }

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
      'likeCount': 0,
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

  Stream<bool> watchLikeStatus({
    required String postId,
    required String userUid,
  }) {
    return _firestore
        .collection('postLikes')
        .doc(userUid)
        .collection('items')
        .doc(postId)
        .snapshots()
        .map((snapshot) {
      return snapshot.exists;
    });
  }

  Stream<bool> watchBookmarkStatus({
    required String postId,
    required String userUid,
  }) {
    return _firestore
        .collection('postBookmarks')
        .doc(userUid)
        .collection('items')
        .doc(postId)
        .snapshots()
        .map((snapshot) {
      return snapshot.exists;
    });
  }

  Future<void> toggleLike({
    required String postId,
    required String userUid,
  }) async {
    DocumentReference<Map<String, dynamic>>
    postReference =
    _firestore.collection('posts').doc(postId);

    DocumentReference<Map<String, dynamic>>
    likeReference =
    _firestore
        .collection('postLikes')
        .doc(userUid)
        .collection('items')
        .doc(postId);

    await _firestore.runTransaction(
          (transaction) async {
        DocumentSnapshot<Map<String, dynamic>>
        postSnapshot =
        await transaction.get(postReference);

        if (!postSnapshot.exists) {
          throw StateError('게시글을 찾을 수 없습니다.');
        }

        DocumentSnapshot<Map<String, dynamic>>
        likeSnapshot =
        await transaction.get(likeReference);

        int currentCount = _readCount(
          postSnapshot.data()?['likeCount'],
        );

        if (likeSnapshot.exists) {
          transaction.delete(likeReference);
          transaction.update(postReference, {
            'likeCount':
            currentCount > 0 ? currentCount - 1 : 0,
            'updatedAt':
            FieldValue.serverTimestamp(),
          });
          return;
        }

        transaction.set(likeReference, {
          'postId': postId,
          'userUid': userUid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(postReference, {
          'likeCount': currentCount + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
    );
  }

  Future<void> toggleBookmark({
    required String postId,
    required String userUid,
  }) async {
    DocumentReference<Map<String, dynamic>>
    postReference =
    _firestore.collection('posts').doc(postId);

    DocumentReference<Map<String, dynamic>>
    bookmarkReference =
    _firestore
        .collection('postBookmarks')
        .doc(userUid)
        .collection('items')
        .doc(postId);

    await _firestore.runTransaction(
          (transaction) async {
        DocumentSnapshot<Map<String, dynamic>>
        postSnapshot =
        await transaction.get(postReference);

        if (!postSnapshot.exists) {
          throw StateError('게시글을 찾을 수 없습니다.');
        }

        DocumentSnapshot<Map<String, dynamic>>
        bookmarkSnapshot =
        await transaction.get(bookmarkReference);

        int currentCount = _readCount(
          postSnapshot.data()?['bookmarkCount'],
        );

        if (bookmarkSnapshot.exists) {
          transaction.delete(bookmarkReference);
          transaction.update(postReference, {
            'bookmarkCount':
            currentCount > 0 ? currentCount - 1 : 0,
            'updatedAt':
            FieldValue.serverTimestamp(),
          });
          return;
        }

        transaction.set(bookmarkReference, {
          'postId': postId,
          'userUid': userUid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(postReference, {
          'bookmarkCount': currentCount + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
    );
  }

  Stream<bool> watchCommentLikeStatus({
    required String commentId,
    required String userUid,
  }) {
    return _firestore
        .collection('commentLikes')
        .doc(userUid)
        .collection('items')
        .doc(commentId)
        .snapshots()
        .map((snapshot) {
      return snapshot.exists;
    });
  }

  Future<void> toggleCommentLike({
    required String postId,
    required String commentId,
    required String userUid,
  }) async {
    DocumentReference<Map<String, dynamic>>
    commentReference =
    _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    DocumentReference<Map<String, dynamic>>
    likeReference =
    _firestore
        .collection('commentLikes')
        .doc(userUid)
        .collection('items')
        .doc(commentId);

    await _firestore.runTransaction(
          (transaction) async {
        DocumentSnapshot<Map<String, dynamic>>
        commentSnapshot =
        await transaction.get(commentReference);

        if (!commentSnapshot.exists) {
          throw StateError('댓글을 찾을 수 없습니다.');
        }

        DocumentSnapshot<Map<String, dynamic>>
        likeSnapshot =
        await transaction.get(likeReference);

        int currentCount = _readCount(
          commentSnapshot.data()?['likeCount'],
        );

        if (likeSnapshot.exists) {
          transaction.delete(likeReference);
          transaction.update(commentReference, {
            'likeCount':
            currentCount > 0 ? currentCount - 1 : 0,
            'updatedAt':
            FieldValue.serverTimestamp(),
          });
          return;
        }

        transaction.set(likeReference, {
          'postId': postId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(commentReference, {
          'likeCount': currentCount + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
    );
  }

  Future<bool> submitReport({
    required String reportType,
    required String postId,
    required String reporterUid,
    required String targetWriterUid,
    required String reasonCode,
    required String reasonText,
    String commentId = '',
  }) async {
    String targetId =
    commentId.isEmpty ? postId : commentId;

    String reportDocumentId =
        '${reporterUid}_${reportType}_$targetId';

    DocumentReference<Map<String, dynamic>>
    reportReference =
    _firestore
        .collection('communityReports')
        .doc(reportDocumentId);

    return _firestore.runTransaction<bool>(
          (transaction) async {
        DocumentSnapshot<Map<String, dynamic>>
        reportSnapshot =
        await transaction.get(reportReference);

        if (reportSnapshot.exists) {
          return false;
        }

        transaction.set(reportReference, {
          'reportType': reportType,
          'postId': postId,
          'commentId': commentId,
          'reporterUid': reporterUid,
          'targetWriterUid': targetWriterUid,
          'reasonCode': reasonCode,
          'reasonText': reasonText,
          'reportStatus': 'PENDING',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      },
    );
  }

  Stream<List<CommunityCertificateTag>>
  watchCertificateTagSuggestions() {
    return watchPosts().map((posts) {
      return collectCertificateTags(posts);
    });
  }

  Future<List<CommunityCertificateTag>>
  getCertifiedCertificateTags(
      String userUid,
      ) async {
    Map<String, dynamic> userData =
    await _readUserData(userUid);

    Map<String, CommunityCertificateTag> tagMap = {};

    void addTags(dynamic value) {
      if (value is! List) {
        return;
      }

      for (dynamic item in value) {
        if (item is! Map) {
          continue;
        }

        Map<String, dynamic> data =
        Map<String, dynamic>.from(item);

        String status =
            data['status']?.toString().toUpperCase() ??
                data['verificationStatus']
                    ?.toString()
                    .toUpperCase() ??
                'APPROVED';

        if (status != 'APPROVED' &&
            status != 'VERIFIED') {
          continue;
        }

        String certificateId =
            data['certificateId']?.toString() ??
                data['id']?.toString() ??
                '';

        String certificateName =
            data['certificateName']?.toString() ??
                data['name']?.toString() ??
                '';

        if (certificateId.isEmpty ||
            certificateName.isEmpty) {
          continue;
        }

        tagMap[certificateId] =
            CommunityCertificateTag(
              certificateId: certificateId,
              certificateName: certificateName,
            );
      }
    }

    addTags(userData['certifiedCertificates']);
    addTags(userData['approvedCertificates']);

    try {
      QuerySnapshot<Map<String, dynamic>>
      certificateSnapshot =
      await _firestore
          .collection('users')
          .doc(userUid)
          .collection('certificates')
          .get();

      for (QueryDocumentSnapshot<Map<String, dynamic>>
      document in certificateSnapshot.docs) {
        Map<String, dynamic> data = document.data();

        String status =
            data['status']?.toString().toUpperCase() ??
                data['verificationStatus']
                    ?.toString()
                    .toUpperCase() ??
                '';

        if (status != 'APPROVED' &&
            status != 'VERIFIED') {
          continue;
        }

        String certificateId =
            data['certificateId']?.toString() ??
                document.id;

        String certificateName =
            data['certificateName']?.toString() ??
                data['name']?.toString() ??
                '';

        if (certificateId.isEmpty ||
            certificateName.isEmpty) {
          continue;
        }

        tagMap[certificateId] =
            CommunityCertificateTag(
              certificateId: certificateId,
              certificateName: certificateName,
            );
      }
    } catch (error) {
      // 인증 자격증 하위 컬렉션이 없는 기존 회원은
      // users 문서의 인증 목록만 사용합니다.
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

  Future<Map<String, dynamic>> getUserCommunityProfile(
      String userUid,
      ) async {
    Map<String, dynamic> userData =
    await _readUserData(userUid);

    List<CommunityCertificateTag> certifiedTags =
    await getCertifiedCertificateTags(userUid);

    return {
      'nickname':
      userData['nickname']?.toString() ??
          userData['displayName']?.toString() ??
          '사용자',
      'profileImageUrl':
      userData['profileImageUrl']?.toString() ??
          userData['photoUrl']?.toString() ??
          '',
      'introduction':
      userData['introduction']?.toString() ??
          userData['bio']?.toString() ??
          '',
      'certifiedTags': certifiedTags,
    };
  }

  Future<Map<String, dynamic>> _readUserData(
      String userUid,
      ) async {
    DocumentSnapshot<Map<String, dynamic>>
    directSnapshot =
    await _firestore
        .collection('users')
        .doc(userUid)
        .get();

    if (directSnapshot.exists) {
      return directSnapshot.data() ?? {};
    }

    QuerySnapshot<Map<String, dynamic>>
    querySnapshot =
    await _firestore
        .collection('users')
        .where(
      'uid',
      isEqualTo: userUid,
    )
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return {};
    }

    return querySnapshot.docs.first.data();
  }

  int _readCount(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
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
    DateTime now = DateTime.now();

    List<CommunityPost> recentPosts =
    posts.where((post) {
      DateTime? createdAt = post.createdAt;

      if (createdAt == null) {
        return false;
      }

      Duration difference =
      now.difference(createdAt);

      return !difference.isNegative &&
          difference.inDays < 7;
    }).toList();

    List<CommunityPost> result =
    List<CommunityPost>.from(
      recentPosts.isEmpty ? posts : recentPosts,
    );

    result.sort((a, b) {
      int aScore = a.likeCount * 5 +
          a.commentCount * 3 +
          a.viewCount;

      int bScore = b.likeCount * 5 +
          b.commentCount * 3 +
          b.viewCount;

      int scoreCompare =
      bScore.compareTo(aScore);

      if (scoreCompare != 0) {
        return scoreCompare;
      }

      int aTime =
          a.createdAt?.millisecondsSinceEpoch ??
              0;
      int bTime =
          b.createdAt?.millisecondsSinceEpoch ??
              0;

      return bTime.compareTo(aTime);
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
