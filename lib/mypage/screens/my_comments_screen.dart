import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';

import '../../community/community_post_detail.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_state_views.dart';
import '../../widgets/app_top_bar.dart';

class MyCommentsScreen extends StatefulWidget {
  const MyCommentsScreen({super.key});

  @override
  State<MyCommentsScreen> createState() => _MyCommentsScreenState();
}

class _MyCommentsScreenState extends State<MyCommentsScreen> {
  String _selectedType = 'ALL';
  late Future<List<_MyCommentItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadMyComments();
  }

  Future<List<_MyCommentItem>> _loadMyComments() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return [];
    }

    final List<_MyCommentItem> items = [];

    // 삭제되지 않고 공개된 게시글만 먼저 조회합니다.
    final QuerySnapshot<Map<String, dynamic>> postSnapshot =
        await FirebaseFirestore.instance
            .collection('posts')
            .where('postStatus', isEqualTo: 'NORMAL')
            .where('visibility', isEqualTo: 'PUBLIC')
            .get();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> postDocument
        in postSnapshot.docs) {
      final Map<String, dynamic> postData = postDocument.data();

      if (postData['deletedAt'] != null) {
        continue;
      }

      // 각 게시글에서 현재 사용자가 작성한 댓글과 대댓글을 조회합니다.
      final QuerySnapshot<Map<String, dynamic>> commentSnapshot =
          await postDocument.reference
              .collection('comments')
              .where('commentStatus', isEqualTo: 'NORMAL')
              .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> commentDocument
          in commentSnapshot.docs) {
        final Map<String, dynamic> commentData = commentDocument.data();

        final String writerUid = commentData['writerUid']?.toString() ?? '';

        if (writerUid != user.uid) {
          continue;
        }

        final String commentStatus =
            (commentData['commentStatus'] as String? ?? 'NORMAL')
                .trim()
                .toUpperCase();

        if (commentStatus != 'NORMAL') {
          continue;
        }

        if (commentData['deletedAt'] != null) {
          continue;
        }

        items.add(
          _MyCommentItem(
            commentId: commentDocument.id,
            postId: postDocument.id,
            postTitle: postData['title']?.toString() ?? '제목 없는 게시글',
            boardName: _boardLabel(postData['boardType']?.toString() ?? 'FREE'),
            content: commentData['content']?.toString() ?? '',
            parentCommentId: commentData['parentCommentId']?.toString() ?? '',
            likeCount: (commentData['likeCount'] as num?)?.toInt() ?? 0,
            createdAt: commentData['createdAt'],
          ),
        );
      }
    }

    // 최신 댓글이 위에 표시되도록 정렬합니다.
    items.sort((a, b) {
      final DateTime aDate = a.dateTime ?? DateTime(1970);
      final DateTime bDate = b.dateTime ?? DateTime(1970);

      return bDate.compareTo(aDate);
    });

    return items;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadMyComments();
    });

    await _future;
  }

  void _openPost(String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityPostDetailPage(postId: postId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppTopBar(title: '내가 쓴 댓글'),
      body: AppMainBackground(
        child: FutureBuilder<List<_MyCommentItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingView(message: '작성한 댓글을 불러오는 중입니다.');
            }

            if (snapshot.hasError) {
              return AppErrorView(
                message: '작성한 댓글을 불러오지 못했습니다.',
                description: '잠시 후 다시 시도해 주세요.',
                onRetryPressed: _refresh,
              );
            }

            final List<_MyCommentItem> allItems = snapshot.data ?? [];
            final List<_MyCommentItem> visibleItems = allItems.where((item) {
              if (_selectedType == 'COMMENT') {
                return !item.isReply;
              }

              if (_selectedType == 'REPLY') {
                return item.isReply;
              }

              return true;
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    children: [
                      _buildFilterButton('ALL', '전체'),
                      const SizedBox(width: 8),
                      _buildFilterButton('COMMENT', '댓글'),
                      const SizedBox(width: 8),
                      _buildFilterButton('REPLY', '대댓글'),
                    ],
                  ),
                ),
                Expanded(
                  child: visibleItems.isEmpty
                      ? AppEmptyView(
                          message: _selectedType == 'ALL'
                              ? '작성한 댓글이 없습니다.'
                              : '해당 종류의 댓글이 없습니다.',
                          description: '커뮤니티 게시글에 의견을 남겨보세요.',
                        )
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                            itemCount: visibleItems.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildCommentCard(visibleItems[index]);
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterButton(String value, String label) {
    final bool isSelected = _selectedType == value;

    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _selectedType = value;
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

  Widget _buildCommentCard(_MyCommentItem item) {
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
                const SizedBox(width: 8),
                Text(
                  item.boardName,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatCommunityDate(item.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
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
                Icon(
                  Icons.favorite_border,
                  size: 16,
                  color: context.colors.pinkStart,
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.likeCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
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

class _MyCommentItem {
  final String commentId;
  final String postId;
  final String postTitle;
  final String boardName;
  final String content;
  final String parentCommentId;
  final int likeCount;
  final dynamic createdAt;

  const _MyCommentItem({
    required this.commentId,
    required this.postId,
    required this.postTitle,
    required this.boardName,
    required this.content,
    required this.parentCommentId,
    required this.likeCount,
    required this.createdAt,
  });

  bool get isReply => parentCommentId.isNotEmpty;

  DateTime? get dateTime {
    if (createdAt is Timestamp) {
      return (createdAt as Timestamp).toDate();
    }

    if (createdAt is DateTime) {
      return createdAt as DateTime;
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
