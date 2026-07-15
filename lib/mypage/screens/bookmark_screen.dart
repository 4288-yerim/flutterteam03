import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_state_views.dart';
import '../../widgets/app_top_bar.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});

  @override
  State<BookmarkScreen> createState() =>
      _BookmarkScreenState();
}

class _BookmarkScreenState
    extends State<BookmarkScreen> {
  // Firebase 연결 전 임시 북마크 데이터
  final List<BookmarkPostItem> _bookmarkedPosts = [
    const BookmarkPostItem(
      id: 'bookmark_001',
      postId: 'post_001',
      boardName: '질문 게시판',
      title: '정보처리기사 실기 공부 순서 질문드립니다.',
      writerNickname: '합격가자',
      createdAt: '2026.07.14',
      viewCount: 124,
      commentCount: 8,
      likeCount: 15,
    ),
    const BookmarkPostItem(
      id: 'bookmark_002',
      postId: 'post_002',
      boardName: '학습 팁',
      title: 'SQLD 시험 전날 꼭 확인해야 할 내용 정리',
      writerNickname: '데이터초보',
      createdAt: '2026.07.12',
      viewCount: 356,
      commentCount: 12,
      likeCount: 41,
    ),
    const BookmarkPostItem(
      id: 'bookmark_003',
      postId: 'post_003',
      boardName: '교재 후기',
      title: '비전공자 정보처리기사 교재 사용 후기',
      writerNickname: '공부하는직장인',
      createdAt: '2026.07.10',
      viewCount: 278,
      commentCount: 5,
      likeCount: 29,
    ),
    const BookmarkPostItem(
      id: 'bookmark_004',
      postId: 'post_004',
      boardName: '스터디 모집',
      title: '정보처리기사 실기 주말 스터디 모집합니다.',
      writerNickname: '실기한번에',
      createdAt: '2026.07.08',
      viewCount: 198,
      commentCount: 17,
      likeCount: 9,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '북마크',
      ),
      body: AppMainBackground(
        child: _bookmarkedPosts.isEmpty
            ? AppEmptyView(
          message: '저장한 게시글이 없습니다.',
          description: '나중에 다시 보고 싶은 게시글을\n북마크에 저장해보세요.',
          buttonText: '커뮤니티 둘러보기',
          onButtonPressed: _openCommunity,
        )
            : _buildBookmarkList(),
      ),
    );
  }

  Widget _buildBookmarkList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        32,
      ),
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 20),

        const Text(
          '저장한 게시글',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),

        ..._bookmarkedPosts.map(
              (post) {
            return Padding(
              padding: const EdgeInsets.only(
                bottom: 12,
              ),
              child: _buildBookmarkCard(post),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFCEFF3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.bookmark_rounded,
              size: 25,
              color: Color(0xFFF0788F),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  '저장한 게시글',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666A73),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_bookmarkedPosts.length}개',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),

          const Text(
            '나중에 다시 볼 글',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9AA0AC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkCard(
      BookmarkPostItem post,
      ) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          _openPostDetail(post);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            18,
            17,
            10,
            15,
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    _buildBoardBadge(
                      post.boardName,
                    ),
                    const SizedBox(height: 10),

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

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 15,
                          color: Color(0xFF9AA0AC),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            post.writerNickname,
                            overflow:
                            TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color:
                              Color(0xFF666A73),
                            ),
                          ),
                        ),
                        Text(
                          post.createdAt,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9AA0AC),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        _buildCountItem(
                          icon: Icons
                              .visibility_outlined,
                          count: post.viewCount,
                        ),
                        const SizedBox(width: 14),
                        _buildCountItem(
                          icon: Icons
                              .chat_bubble_outline,
                          count: post.commentCount,
                        ),
                        const SizedBox(width: 14),
                        _buildCountItem(
                          icon: Icons
                              .favorite_border,
                          count: post.likeCount,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip: '북마크 해제',
                onPressed: () {
                  _showRemoveBookmarkDialog(post);
                },
                icon: const Icon(
                  Icons.bookmark_rounded,
                  color: Color(0xFFF0788F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoardBadge(
      String boardName,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEFF3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        boardName,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF0788F),
        ),
      ),
    );
  }

  Widget _buildCountItem({
    required IconData icon,
    required int count,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF9AA0AC),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9AA0AC),
          ),
        ),
      ],
    );
  }

  void _openCommunity() {
    // TODO: 커뮤니티 담당 화면 완성 후 실제 화면으로 연결
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '커뮤니티 화면이 완성되면 연결할 예정입니다.',
        ),
      ),
    );
  }

  void _openPostDetail(
      BookmarkPostItem post,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return _TemporaryPostDetailScreen(
            post: post,
          );
        },
      ),
    );
  }

  Future<void> _showRemoveBookmarkDialog(
      BookmarkPostItem post,
      ) async {
    final bool? result =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '북마크 해제',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '"${post.title}"\n게시글의 북마크를 해제하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
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
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                '해제',
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

    if (result != true) {
      return;
    }

    setState(() {
      _bookmarkedPosts.removeWhere(
            (item) => item.id == post.id,
      );
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '북마크가 해제되었습니다.',
        ),
      ),
    );
  }
}

class BookmarkPostItem {
  final String id;
  final String postId;
  final String boardName;
  final String title;
  final String writerNickname;
  final String createdAt;
  final int viewCount;
  final int commentCount;
  final int likeCount;

  const BookmarkPostItem({
    required this.id,
    required this.postId,
    required this.boardName,
    required this.title,
    required this.writerNickname,
    required this.createdAt,
    required this.viewCount,
    required this.commentCount,
    required this.likeCount,
  });
}

class _TemporaryPostDetailScreen
    extends StatelessWidget {
  final BookmarkPostItem post;

  const _TemporaryPostDetailScreen({
    required this.post,
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
            32,
          ),
          child: AppCard(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCEFF3),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: Text(
                    post.boardName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF0788F),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  '${post.writerNickname} · ${post.createdAt}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9AA0AC),
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),

                const Text(
                  '현재 커뮤니티 게시글 상세 화면이 연결되지 않아 '
                      '임시 상세 화면을 표시하고 있습니다.\n\n'
                      '커뮤니티 담당 화면이 완성되면 postId를 전달해 '
                      '실제 게시글 상세 화면으로 이동할 예정입니다.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.7,
                    color: Color(0xFF666A73),
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