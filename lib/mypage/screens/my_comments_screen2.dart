import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class MyCommentsScreen extends StatefulWidget {
  const MyCommentsScreen({super.key});

  @override
  State<MyCommentsScreen> createState() => _MyCommentsScreenState();
}

class _MyCommentsScreenState extends State<MyCommentsScreen> {
  // Firebase 연결 전 테스트용 임시 데이터
  final List<MyCommentItem> _comments = [
    MyCommentItem(
      id: 'comment_001',
      boardName: '질문 게시판',
      postTitle: '정보처리기사 실기 공부 순서 어떻게 잡으셨나요?',
      content: '저는 기출문제를 먼저 풀어보고 부족한 부분을 개념서로 다시 공부했어요.',
      createdAt: '2026.07.15',
      likeCount: 8,
    ),
    MyCommentItem(
      id: 'comment_002',
      boardName: '시험 후기',
      postTitle: '2026년 정보처리기사 2회 필기 후기',
      content: '저도 이번 시험에서 데이터베이스 문제가 가장 어렵게 느껴졌습니다.',
      createdAt: '2026.07.13',
      likeCount: 3,
    ),
    MyCommentItem(
      id: 'comment_003',
      boardName: '스터디 모집',
      postTitle: '정보처리기사 실기 온라인 스터디 모집합니다',
      content: '평일 저녁 시간대라면 참여 가능할 것 같습니다!',
      createdAt: '2026.07.10',
      likeCount: 1,
    ),
    MyCommentItem(
      id: 'comment_004',
      boardName: '자유 게시판',
      postTitle: '다들 하루 공부 시간 얼마나 잡으시나요?',
      content: '평일에는 2시간 정도 하고 주말에는 조금 더 길게 공부하고 있어요.',
      createdAt: '2026.07.08',
      likeCount: 5,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '내가 쓴 댓글',
      ),
      body: AppMainBackground(
        child: _comments.isEmpty
            ? _buildEmptyView()
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
              _buildCommentSummary(),
              const SizedBox(height: 18),
              _buildSectionTitle(),
              const SizedBox(height: 10),
              ..._comments.map(
                    (comment) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildCommentCard(comment),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentSummary() {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내 댓글 활동',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '작성한 댓글 ${_comments.length}개',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '댓글 목록',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '최신순',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(MyCommentItem comment) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _openPostDetail(comment);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            15,
            10,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBoardBadge(comment.boardName),
                  const Spacer(),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: Colors.grey.shade600,
                    ),
                    onSelected: (value) {
                      if (value == 'open') {
                        _openPostDetail(comment);
                      }

                      if (value == 'delete') {
                        _showDeleteDialog(comment);
                      }
                    },
                    itemBuilder: (context) {
                      return const [
                        PopupMenuItem(
                          value: 'open',
                          child: Row(
                            children: [
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Text('게시글 보기'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: Colors.redAccent,
                              ),
                              SizedBox(width: 10),
                              Text(
                                '댓글 삭제',
                                style: TextStyle(
                                  color: Colors.redAccent,
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
              const SizedBox(height: 9),
              Text(
                comment.postTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  comment.content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    comment.createdAt,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${comment.likeCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '게시글 보기',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoardBadge(String boardName) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        boardName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          30,
          30,
          30,
          110,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '작성한 댓글이 없습니다',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '커뮤니티 게시글에 댓글을 작성하면\n이곳에서 확인할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(
                Icons.forum_outlined,
              ),
              label: const Text('커뮤니티 둘러보기'),
            ),
          ],
        ),
      ),
    );
  }

  void _openPostDetail(MyCommentItem comment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TemporaryPostDetailScreen(
          comment: comment,
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(
      MyCommentItem comment,
      ) async {
    final bool? deleteResult = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('댓글 삭제'),
          content: const Text(
            '작성한 댓글을 삭제하시겠습니까?\n삭제한 댓글은 복구할 수 없습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (deleteResult != true) {
      return;
    }

    setState(() {
      _comments.removeWhere(
            (item) => item.id == comment.id,
      );
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('댓글이 삭제되었습니다.'),
      ),
    );
  }
}

class MyCommentItem {
  final String id;
  final String boardName;
  final String postTitle;
  final String content;
  final String createdAt;
  final int likeCount;

  const MyCommentItem({
    required this.id,
    required this.boardName,
    required this.postTitle,
    required this.content,
    required this.createdAt,
    required this.likeCount,
  });
}

class _TemporaryPostDetailScreen extends StatelessWidget {
  final MyCommentItem comment;

  const _TemporaryPostDetailScreen({
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '게시글 상세',
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
                Text(
                  comment.boardName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  comment.postTitle,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  comment.createdAt,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '게시글 상세 화면은 커뮤니티 담당 화면과 연결할 예정입니다.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 26),
                const Divider(),
                const SizedBox(height: 18),
                const Text(
                  '내가 작성한 댓글',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    comment.content,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
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