import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';

import '../../community/community_post_detail.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_state_views.dart';
import '../../widgets/app_top_bar.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  late Future<List<_SavedPostItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadBookmarks();
  }

  Future<List<_SavedPostItem>> _loadBookmarks() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return [];
    }

    final QuerySnapshot<Map<String, dynamic>> bookmarkSnapshot =
        await FirebaseFirestore.instance
            .collection('postBookmarks')
            .doc(user.uid)
            .collection('items')
            .get();

    final List<_SavedPostItem> items = [];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> bookmarkDocument
        in bookmarkSnapshot.docs) {
      final String postId =
          bookmarkDocument.data()['postId']?.toString().trim().isNotEmpty ==
              true
          ? bookmarkDocument.data()['postId'].toString()
          : bookmarkDocument.id;

      final DocumentSnapshot<Map<String, dynamic>> postDocument =
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .get();
      final Map<String, dynamic>? postData = postDocument.data();

      if (!postDocument.exists || postData == null) {
        continue;
      }

      final String status = (postData['postStatus'] as String? ?? 'NORMAL')
          .trim()
          .toUpperCase();
      final String visibility = (postData['visibility'] as String? ?? 'PUBLIC')
          .trim()
          .toUpperCase();

      if (status != 'NORMAL' ||
          visibility != 'PUBLIC' ||
          postData['deletedAt'] != null) {
        continue;
      }

      items.add(
        _SavedPostItem(
          postId: postId,
          boardName: _boardLabel(postData['boardType']?.toString() ?? 'FREE'),
          title: postData['title']?.toString() ?? '제목 없는 게시글',
          content: postData['content']?.toString() ?? '',
          writerNickname: postData['writerNickname']?.toString() ?? '사용자',
          likeCount: (postData['likeCount'] as num?)?.toInt() ?? 0,
          commentCount: (postData['commentCount'] as num?)?.toInt() ?? 0,
          createdAt: postData['createdAt'],
          savedAt: bookmarkDocument.data()['createdAt'],
        ),
      );
    }

    items.sort((a, b) {
      final DateTime aDate = a.savedDateTime ?? DateTime(1970);
      final DateTime bDate = b.savedDateTime ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    return items;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadBookmarks();
    });

    await _future;
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
      appBar: AppTopBar(title: '북마크'),
      body: AppMainBackground(
        child: FutureBuilder<List<_SavedPostItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AppLoadingView(message: '저장한 게시글을 불러오는 중입니다.');
            }

            if (snapshot.hasError) {
              return AppErrorView(
                message: '북마크를 불러오지 못했습니다.',
                description: '잠시 후 다시 시도해 주세요.',
                onRetryPressed: _refresh,
              );
            }

            final List<_SavedPostItem> items = snapshot.data ?? [];

            if (items.isEmpty) {
              return AppEmptyView(
                message: '저장한 게시글이 없습니다.',
                description: '나중에 다시 보고 싶은 게시글을 저장해보세요.',
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 40),
                itemCount: items.length + 1,
                separatorBuilder: (_, __) => SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildSummary(items.length);
                  }

                  return _buildPostCard(items[index - 1]);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummary(int count) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.pinkSoftAlt,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(Icons.bookmark_rounded, color: context.colors.pinkStart),
          SizedBox(width: 10),
          Text(
            '저장한 게시글 $count개',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(_SavedPostItem item) {
    return GestureDetector(
      onTap: () => _openPost(item.postId),
      child: AppCard(
        padding: EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  item.boardName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.colors.pinkStart,
                  ),
                ),
                Spacer(),
                Text(
                  _formatCommunityDate(item.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
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
              SizedBox(height: 7),
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
            SizedBox(height: 12),
            Text(
              item.writerNickname,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 16,
                  color: context.colors.pinkStart,
                ),
                SizedBox(width: 4),
                Text('${item.likeCount}'),
                SizedBox(width: 14),
                Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: context.colors.textSecondary,
                ),
                SizedBox(width: 4),
                Text('${item.commentCount}'),
                Spacer(),
                Icon(Icons.chevron_right, color: context.colors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPostItem {
  final String postId;
  final String boardName;
  final String title;
  final String content;
  final String writerNickname;
  final int likeCount;
  final int commentCount;
  final dynamic createdAt;
  final dynamic savedAt;

  _SavedPostItem({
    required this.postId,
    required this.boardName,
    required this.title,
    required this.content,
    required this.writerNickname,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
    required this.savedAt,
  });

  DateTime? get savedDateTime {
    if (savedAt is Timestamp) {
      return (savedAt as Timestamp).toDate();
    }

    if (savedAt is DateTime) {
      return savedAt as DateTime;
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
