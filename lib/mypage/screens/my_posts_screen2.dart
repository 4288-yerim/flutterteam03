import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/app_state_views.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  // Firebase 연결 전 사용하는 임시 게시글 데이터
  final List<MyPostData> _posts = [
    MyPostData(
      id: 'post_001',
      boardName: '질문 게시판',
      title: '정보처리기사 실기 공부 순서 질문드립니다.',
      content: '필기 합격 후 실기를 준비하려고 하는데 어떤 순서로 공부하면 좋을까요?',
      createdAt: '2026.07.14',
      viewCount: 128,
      commentCount: 7,
      likeCount: 12,
      status: MyPostStatus.published,
    ),
    MyPostData(
      id: 'post_002',
      boardName: '자유 게시판',
      title: '오늘 공부 목표 완료했습니다!',
      content: '데이터베이스 파트를 2시간 동안 공부했습니다.',
      createdAt: '2026.07.12',
      viewCount: 54,
      commentCount: 3,
      likeCount: 9,
      status: MyPostStatus.published,
    ),
    MyPostData(
      id: 'post_003',
      boardName: '스터디 모집',
      title: '정보처리기사 실기 스터디원 모집합니다.',
      content: '주 3회 온라인으로 문제 풀이를 진행할 예정입니다.',
      createdAt: '2026.07.10',
      viewCount: 201,
      commentCount: 15,
      likeCount: 18,
      status: MyPostStatus.recruiting,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppTopBar(
        title: '내가 쓴 글',
        leading: IconButton(
          tooltip: '뒤로 가기',
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),

      body: AppMainBackground(
        child: _posts.isEmpty
            ? const AppEmptyView(
          message: '작성한 게시글이 없습니다.',
          description: '커뮤니티에서 질문이나 정보를 공유해 보세요.',
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            110,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPostSummary(),
              const SizedBox(height: 24),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '작성한 게시글',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  Text(
                    '총 ${_posts.length}개',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9AA0AC),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _posts.length,
                separatorBuilder: (_, __) {
                  return const SizedBox(height: 12);
                },
                itemBuilder: (context, index) {
                  final post = _posts[index];

                  return _MyPostCard(
                    post: post,
                    onTap: () {
                      _openPostDetail(post);
                    },
                    onEdit: () {
                      _editPost(post);
                    },
                    onDelete: () {
                      _showDeleteDialog(post);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostSummary() {
    final int totalViews = _posts.fold(
      0,
          (sum, post) => sum + post.viewCount,
    );

    final int totalComments = _posts.fold(
      0,
          (sum, post) => sum + post.commentCount,
    );

    final int totalLikes = _posts.fold(
      0,
          (sum, post) => sum + post.likeCount,
    );

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              icon: Icons.article_outlined,
              label: '작성 글',
              value: '${_posts.length}개',
            ),
          ),
          const _SummaryDivider(),
          Expanded(
            child: _SummaryItem(
              icon: Icons.visibility_outlined,
              label: '전체 조회',
              value: '$totalViews회',
            ),
          ),
          const _SummaryDivider(),
          Expanded(
            child: _SummaryItem(
              icon: Icons.chat_bubble_outline,
              label: '전체 댓글',
              value: '$totalComments개',
            ),
          ),
          const _SummaryDivider(),
          Expanded(
            child: _SummaryItem(
              icon: Icons.favorite_border,
              label: '받은 좋아요',
              value: '$totalLikes개',
            ),
          ),
        ],
      ),
    );
  }

  void _openPostDetail(MyPostData post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemporaryPostDetailScreen(
          post: post,
        ),
      ),
    );
  }

  void _editPost(MyPostData post) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${post.title}" 수정 화면은 추후 연결합니다.',
        ),
      ),
    );
  }

  void _showDeleteDialog(MyPostData post) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '게시글 삭제',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '"${post.title}" 게시글을 삭제하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF9AA0AC),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                setState(() {
                  _posts.removeWhere(
                        (item) => item.id == post.id,
                  );
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '게시글이 삭제되었습니다.',
                    ),
                  ),
                );
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Color(0xFFF0788F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MyPostCard extends StatelessWidget {
  final MyPostData post;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MyPostCard({
    required this.post,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            18,
            16,
            10,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _BoardChip(
                    text: post.boardName,
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    status: post.status,
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: '게시글 메뉴',
                    color: Colors.white,
                    icon: const Icon(
                      Icons.more_vert,
                      size: 21,
                      color: Color(0xFF9AA0AC),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      }

                      if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (_) {
                      return const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 19,
                              ),
                              SizedBox(width: 10),
                              Text('수정'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 19,
                                color: Color(0xFFF0788F),
                              ),
                              SizedBox(width: 10),
                              Text(
                                '삭제',
                                style: TextStyle(
                                  color: Color(0xFFF0788F),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),

              const SizedBox(height: 7),

              Text(
                post.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF666A73),
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Text(
                    post.createdAt,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9AA0AC),
                    ),
                  ),
                  const Spacer(),
                  _PostCount(
                    icon: Icons.visibility_outlined,
                    count: post.viewCount,
                  ),
                  const SizedBox(width: 12),
                  _PostCount(
                    icon: Icons.chat_bubble_outline,
                    count: post.commentCount,
                  ),
                  const SizedBox(width: 12),
                  _PostCount(
                    icon: Icons.favorite_border,
                    count: post.likeCount,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFFF0788F),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF9AA0AC),
          ),
        ),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      color: const Color(0xFFF0F0F2),
    );
  }
}

class _BoardChip extends StatelessWidget {
  final String text;

  const _BoardChip({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEFF3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF0788F),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final MyPostStatus status;

  const _StatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color backgroundColor;
    final Color textColor;

    switch (status) {
      case MyPostStatus.published:
        text = '게시 중';
        backgroundColor = const Color(0xFFF1F7F3);
        textColor = const Color(0xFF4C9A65);

      case MyPostStatus.recruiting:
        text = '모집 중';
        backgroundColor = const Color(0xFFF2F3FF);
        textColor = const Color(0xFF666ED8);

      case MyPostStatus.closed:
        text = '모집 완료';
        backgroundColor = const Color(0xFFF3F3F5);
        textColor = const Color(0xFF777B84);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _PostCount extends StatelessWidget {
  final IconData icon;
  final int count;

  const _PostCount({
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: const Color(0xFF9AA0AC),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9AA0AC),
          ),
        ),
      ],
    );
  }
}

enum MyPostStatus {
  published,
  recruiting,
  closed,
}

class MyPostData {
  final String id;
  final String boardName;
  final String title;
  final String content;
  final String createdAt;
  final int viewCount;
  final int commentCount;
  final int likeCount;
  final MyPostStatus status;

  const MyPostData({
    required this.id,
    required this.boardName,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.viewCount,
    required this.commentCount,
    required this.likeCount,
    required this.status,
  });
}

/// 실제 게시글 상세 화면이 완성되기 전 사용하는 임시 상세 화면
class TemporaryPostDetailScreen extends StatelessWidget {
  final MyPostData post;

  const TemporaryPostDetailScreen({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppTopBar(
        title: '게시글 상세',
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),

      body: AppMainBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            110,
          ),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BoardChip(
                  text: post.boardName,
                ),
                const SizedBox(height: 14),

                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  post.createdAt,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9AA0AC),
                  ),
                ),

                const SizedBox(height: 20),

                const Divider(
                  color: Color(0xFFF0F0F2),
                ),

                const SizedBox(height: 20),

                Text(
                  post.content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: Color(0xFF44474E),
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  '게시글 상세 기능은 커뮤니티 화면 구현 후 연결됩니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9AA0AC),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}