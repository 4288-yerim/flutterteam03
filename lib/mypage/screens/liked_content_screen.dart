import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../services/user_profile_cache_service.dart';

import '../../community/community_post_detail.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_state_views.dart';
import '../../widgets/app_top_bar.dart';

class LikedContentScreen extends StatefulWidget {
  const LikedContentScreen({super.key});

  @override
  State<LikedContentScreen> createState() => _LikedContentScreenState();
}

class _LikedContentScreenState extends State<LikedContentScreen> {
  String _selectedTab = 'POST';
  late Future<List<_LikedPostItem>> _postFuture;
  late Future<List<_LikedCommentItem>> _commentFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload({bool forceRefresh = false}) {
    _postFuture = _loadLikedPosts(forceRefresh: forceRefresh);
    _commentFuture = _loadLikedComments(forceRefresh: forceRefresh);
  }

  Future<List<_LikedPostItem>> _loadLikedPosts({
    bool forceRefresh = false,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return [];
    }

    final QuerySnapshot<Map<String, dynamic>> likeSnapshot =
        await FirebaseFirestore.instance
            .collection('postLikes')
            .doc(user.uid)
            .collection('items')
            .get();

    final List<_LikedPostItem> items = [];
    final Set<String> refreshedWriterUids = <String>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> likeDocument
        in likeSnapshot.docs) {
      final String postId =
          likeDocument.data()['postId']?.toString().trim().isNotEmpty == true
          ? likeDocument.data()['postId'].toString()
          : likeDocument.id;

      final DocumentSnapshot<Map<String, dynamic>> postDocument =
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .get();
      final Map<String, dynamic>? postData = postDocument.data();

      if (!postDocument.exists || postData == null) {
        continue;
      }

      if ((postData['postStatus']?.toString() ?? 'NORMAL') != 'NORMAL' ||
          (postData['visibility']?.toString() ?? 'PUBLIC') != 'PUBLIC' ||
          postData['deletedAt'] != null) {
        continue;
      }

      final String writerUid = postData['writerUid']?.toString() ?? '';
      final String writerNickname = await UserProfileCacheService.instance
          .resolveNickname(
            uid: writerUid,
            fallback: postData['writerNickname']?.toString() ?? '사용자',
            forceRefresh: forceRefresh && refreshedWriterUids.add(writerUid),
          );

      items.add(
        _LikedPostItem(
          postId: postId,
          title: postData['title']?.toString() ?? '제목 없는 게시글',
          content: postData['content']?.toString() ?? '',
          boardName: _boardLabel(postData['boardType']?.toString() ?? 'FREE'),
          writerNickname: writerNickname,
          likeCount: (postData['likeCount'] as num?)?.toInt() ?? 0,
          commentCount: (postData['commentCount'] as num?)?.toInt() ?? 0,
          likedAt: likeDocument.data()['createdAt'],
        ),
      );
    }

    items.sort((a, b) {
      final DateTime aDate = a.likedDateTime ?? DateTime(1970);
      final DateTime bDate = b.likedDateTime ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    return items;
  }

  Future<List<_LikedCommentItem>> _loadLikedComments({
    bool forceRefresh = false,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return [];
    }

    final QuerySnapshot<Map<String, dynamic>> likeSnapshot =
        await FirebaseFirestore.instance
            .collection('commentLikes')
            .doc(user.uid)
            .collection('items')
            .get();

    final List<_LikedCommentItem> items = [];
    final Set<String> refreshedWriterUids = <String>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> likeDocument
        in likeSnapshot.docs) {
      final String commentId = likeDocument.id;
      final String postId = likeDocument.data()['postId']?.toString() ?? '';

      if (postId.isEmpty) {
        continue;
      }

      final DocumentSnapshot<Map<String, dynamic>> postDocument =
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .get();
      final Map<String, dynamic>? postData = postDocument.data();

      if (!postDocument.exists ||
          postData == null ||
          (postData['postStatus']?.toString() ?? 'NORMAL') != 'NORMAL' ||
          (postData['visibility']?.toString() ?? 'PUBLIC') != 'PUBLIC' ||
          postData['deletedAt'] != null) {
        continue;
      }

      final DocumentSnapshot<Map<String, dynamic>> commentDocument =
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .collection('comments')
              .doc(commentId)
              .get();
      final Map<String, dynamic>? commentData = commentDocument.data();

      if (!commentDocument.exists ||
          commentData == null ||
          (commentData['commentStatus']?.toString() ?? 'NORMAL') != 'NORMAL' ||
          commentData['deletedAt'] != null) {
        continue;
      }

      final String writerUid = commentData['writerUid']?.toString() ?? '';
      final String writerNickname = await UserProfileCacheService.instance
          .resolveNickname(
            uid: writerUid,
            fallback: commentData['writerNickname']?.toString() ?? '사용자',
            forceRefresh: forceRefresh && refreshedWriterUids.add(writerUid),
          );

      items.add(
        _LikedCommentItem(
          commentId: commentId,
          postId: postId,
          postTitle: postData['title']?.toString() ?? '제목 없는 게시글',
          content: commentData['content']?.toString() ?? '',
          writerNickname: writerNickname,
          parentCommentId: commentData['parentCommentId']?.toString() ?? '',
          likeCount: (commentData['likeCount'] as num?)?.toInt() ?? 0,
          likedAt: likeDocument.data()['createdAt'],
        ),
      );
    }

    items.sort((a, b) {
      final DateTime aDate = a.likedDateTime ?? DateTime(1970);
      final DateTime bDate = b.likedDateTime ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    return items;
  }

  Future<void> _refresh() async {
    setState(() => _reload(forceRefresh: true));

    if (_selectedTab == 'POST') {
      await _postFuture;
    } else {
      await _commentFuture;
    }
  }

  void _openPost(String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityPostDetailPage(postId: postId),
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppTopBar(title: '좋아요한 콘텐츠'),
      body: AppMainBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  _buildTabButton('POST', '게시글'),
                  const SizedBox(width: 10),
                  _buildTabButton('COMMENT', '댓글'),
                ],
              ),
            ),
            Expanded(
              child: _selectedTab == 'POST'
                  ? _buildPostList()
                  : _buildCommentList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String value, String label) {
    final bool isSelected = _selectedTab == value;

    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _selectedTab = value;
          });
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? context.colors.pinkSoft
              : context.colors.surface,
          foregroundColor: isSelected
              ? context.colors.pinkStart
              : context.colors.textSecondary,
          side: BorderSide(
            color: isSelected
                ? context.colors.pinkStart
                : context.colors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildPostList() {
    return FutureBuilder<List<_LikedPostItem>>(
      future: _postFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingView(message: '좋아요한 게시글을 불러오는 중입니다.');
        }

        if (snapshot.hasError) {
          return AppErrorView(
            message: '좋아요한 게시글을 불러오지 못했습니다.',
            description: '잠시 후 다시 시도해 주세요.',
            onRetryPressed: _refresh,
          );
        }

        final List<_LikedPostItem> items = snapshot.data ?? [];

        if (items.isEmpty) {
          return const AppEmptyView(
            message: '좋아요한 게시글이 없습니다.',
            description: '마음에 드는 게시글에 좋아요를 눌러보세요.',
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildLikedPostCard(items[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildCommentList() {
    return FutureBuilder<List<_LikedCommentItem>>(
      future: _commentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingView(message: '좋아요한 댓글을 불러오는 중입니다.');
        }

        if (snapshot.hasError) {
          return AppErrorView(
            message: '좋아요한 댓글을 불러오지 못했습니다.',
            description: '잠시 후 다시 시도해 주세요.',
            onRetryPressed: _refresh,
          );
        }

        final List<_LikedCommentItem> items = snapshot.data ?? [];

        if (items.isEmpty) {
          return const AppEmptyView(
            message: '좋아요한 댓글이 없습니다.',
            description: '공감하는 댓글이나 대댓글에 좋아요를 눌러보세요.',
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildLikedCommentCard(items[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildLikedPostCard(_LikedPostItem item) {
    return GestureDetector(
      onTap: () => _openPost(item.postId),
      child: AppCard(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.boardName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.colors.pinkStart,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            if (item.content.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                item.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  item.writerNickname,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
                const Spacer(),
                Icon(Icons.favorite, size: 17, color: context.colors.pinkStart),
                const SizedBox(width: 4),
                Text('${item.likeCount}'),
                const SizedBox(width: 12),
                Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: context.colors.textMuted,
                ),
                const SizedBox(width: 4),
                Text('${item.commentCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikedCommentCard(_LikedCommentItem item) {
    return GestureDetector(
      onTap: () => _openPost(item.postId),
      child: AppCard(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: item.isReply
                        ? context.colors.infoSoft
                        : context.colors.pinkSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.isReply ? '대댓글' : '댓글',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: item.isReply
                          ? context.colors.info
                          : context.colors.pinkStart,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  item.writerNickname,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              item.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 11),
            Text(
              '원문 · ${item.postTitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.favorite, size: 17, color: context.colors.pinkStart),
                const SizedBox(width: 4),
                Text('${item.likeCount}'),
                const Spacer(),
                Icon(Icons.chevron_right, color: context.colors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LikedPostItem {
  final String postId;
  final String title;
  final String content;
  final String boardName;
  final String writerNickname;
  final int likeCount;
  final int commentCount;
  final dynamic likedAt;

  const _LikedPostItem({
    required this.postId,
    required this.title,
    required this.content,
    required this.boardName,
    required this.writerNickname,
    required this.likeCount,
    required this.commentCount,
    required this.likedAt,
  });

  DateTime? get likedDateTime {
    if (likedAt is Timestamp) {
      return (likedAt as Timestamp).toDate();
    }

    if (likedAt is DateTime) {
      return likedAt as DateTime;
    }

    return null;
  }
}

class _LikedCommentItem {
  final String commentId;
  final String postId;
  final String postTitle;
  final String content;
  final String writerNickname;
  final String parentCommentId;
  final int likeCount;
  final dynamic likedAt;

  const _LikedCommentItem({
    required this.commentId,
    required this.postId,
    required this.postTitle,
    required this.content,
    required this.writerNickname,
    required this.parentCommentId,
    required this.likeCount,
    required this.likedAt,
  });

  bool get isReply => parentCommentId.isNotEmpty;

  DateTime? get likedDateTime {
    if (likedAt is Timestamp) {
      return (likedAt as Timestamp).toDate();
    }

    if (likedAt is DateTime) {
      return likedAt as DateTime;
    }

    return null;
  }
}

String _formatCommunityDate(dynamic value) {
  DateTime? dateTime;

  if (value is Timestamp) {
    dateTime = value.toDate();
  } else if (value is DateTime) {
    dateTime = value;
  }

  if (dateTime == null) {
    return '';
  }

  final String month = dateTime.month.toString().padLeft(2, '0');
  final String day = dateTime.day.toString().padLeft(2, '0');

  return '${dateTime.year}.$month.$day';
}

String _boardLabel(String code) {
  switch (code) {
    case 'QUESTION':
      return '질문';
    case 'PASS_REVIEW':
      return '합격 후기';
    case 'EXAM_REVIEW':
      return '시험 후기';
    case 'STUDY_SHARE':
      return '학습 자료';
    case 'BOOK_REVIEW':
      return '교재·인강';
    case 'TIP':
      return '학습 팁';
    case 'GROUP_RECRUIT':
      return '스터디 모집';
    case 'FREE':
    default:
      return '자유';
  }
}
