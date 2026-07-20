import 'package:cloud_firestore/cloud_firestore.dart';

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
        CommunityPost post = CommunityPost.fromDocument(document);

        posts.add(post);
      }

      posts.sort((a, b) {
        int aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        int bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

      return posts;
    });
  }

  List<CommunityPost> filterAndSortPosts({
    required List<CommunityPost> posts,
    required CommunityBoardType boardType,
    required CommunityPostSort sort,
    required String keyword,
    required String certificateId,
  }) {
    String normalizedKeyword = keyword.trim().toLowerCase();

    List<CommunityPost> result = posts.where((post) {
      if (boardType != CommunityBoardType.all &&
          post.boardType != boardType) {
        return false;
      }

      if (certificateId.isNotEmpty) {
        bool hasCertificate = post.certificateTags.any((tag) {
          return tag.certificateId == certificateId;
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

      return searchableText.contains(normalizedKeyword);
    }).toList();

    result.sort((a, b) {
      switch (sort) {
        case CommunityPostSort.views:
          return b.viewCount.compareTo(a.viewCount);
        case CommunityPostSort.likes:
          return b.likeCount.compareTo(a.likeCount);
        case CommunityPostSort.comments:
          return b.commentCount.compareTo(a.commentCount);
        case CommunityPostSort.latest:
          int aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
          int bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
      }
    });

    return result;
  }

  List<CommunityPost> getPopularPosts(
      List<CommunityPost> posts,
      ) {
    List<CommunityPost> result = List<CommunityPost>.from(posts);

    result.sort((a, b) {
      int aScore =
          a.likeCount * 3 + a.commentCount * 2 + a.viewCount;
      int bScore =
          b.likeCount * 3 + b.commentCount * 2 + b.viewCount;
      return bScore.compareTo(aScore);
    });

    if (result.length > 3) {
      return result.sublist(0, 3);
    }

    return result;
  }

  List<CommunityCertificateTag> collectCertificateTags(
      List<CommunityPost> posts,
      ) {
    Map<String, CommunityCertificateTag> tagMap = {};

    for (CommunityPost post in posts) {
      for (CommunityCertificateTag tag in post.certificateTags) {
        if (tag.certificateId.isEmpty ||
            tag.certificateName.isEmpty) {
          continue;
        }

        tagMap[tag.certificateId] = tag;
      }
    }

    List<CommunityCertificateTag> result = tagMap.values.toList();
    result.sort((a, b) {
      return a.certificateName.compareTo(b.certificateName);
    });
    return result;
  }
}
