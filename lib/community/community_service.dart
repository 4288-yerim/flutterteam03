import 'package:cloud_firestore/cloud_firestore.dart';

import 'community_models.dart';

class CommunityService {
  final FirebaseFirestore _firestore;

  CommunityService({
    FirebaseFirestore? firestore,
  }) : _firestore =
      firestore ?? FirebaseFirestore.instance;

  // 게시글 목록 실시간 조회
  Stream<List<CommunityPost>> watchPosts() {
    return _firestore
        .collection('posts')
        .where(
      'postStatus',
      isEqualTo: 'NORMAL',
    )
        .where(
      'visibility',
      isEqualTo: 'PUBLIC',
    )
        .snapshots()
        .map((snapshot) {
      List<CommunityPost> posts = [];

      for (
      QueryDocumentSnapshot<Map<String, dynamic>>
      document in snapshot.docs
      ) {
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

  // 게시글 한 개 실시간 조회
  Stream<CommunityPost?> watchPost(
      String postId,
      ) {
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

  // 조회수 증가
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

  // 게시글 등록
  Future<String> addPost({
    required CommunityBoardType boardType,
    required String title,
    required String content,
    required String writerUid,
    required String writerNickname,
    required String writerProfileImageUrl,
    required bool isCertifiedWriter,
    List<CommunityCertificateTag>
    certificateTags = const [],
  }) async {
    DocumentReference<Map<String, dynamic>>
    document =
    _firestore.collection('posts').doc();

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

      'imageAttachments':
      <Map<String, dynamic>>[],

      'fileAttachments':
      <Map<String, dynamic>>[],

      'viewCount': 0,
      'commentCount': 0,
      'likeCount': 0,
      'bookmarkCount': 0,

      'questionStatus':
      boardType ==
          CommunityBoardType.question
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

      'createdAt':
      FieldValue.serverTimestamp(),

      'updatedAt':
      FieldValue.serverTimestamp(),

      'deletedAt': null,
    });

    return document.id;
  }

  // 게시글 수정
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
      boardType ==
          CommunityBoardType.question
          ? 'WAITING'
          : '',

      'recruitStatus':
      boardType ==
          CommunityBoardType.groupRecruit
          ? 'OPEN'
          : '',

      'updatedAt':
      FieldValue.serverTimestamp(),
    });
  }

  // 게시글 삭제
  // 문서를 완전히 지우지 않고 삭제 상태로 변경
  Future<void> deletePost(
      String postId,
      ) async {
    await _firestore
        .collection('posts')
        .doc(postId)
        .update({
      'postStatus': 'DELETED',
      'visibility': 'PRIVATE',

      'updatedAt':
      FieldValue.serverTimestamp(),

      'deletedAt':
      FieldValue.serverTimestamp(),
    });
  }

  // 게시글 검색, 필터, 정렬
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
        ...post.certificateTags.map(
              (tag) => tag.certificateName,
        ),
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
              a.createdAt
                  ?.millisecondsSinceEpoch ??
                  0;

          int bTime =
              b.createdAt
                  ?.millisecondsSinceEpoch ??
                  0;

          return bTime.compareTo(aTime);
      }
    });

    return result;
  }

  // 인기 게시글 최대 3개
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

  // 자격증 태그 목록 수집
  List<CommunityCertificateTag>
  collectCertificateTags(
      List<CommunityPost> posts,
      ) {
    Map<String, CommunityCertificateTag>
    tagMap = {};

    for (CommunityPost post in posts) {
      for (
      CommunityCertificateTag tag
      in post.certificateTags
      ) {
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