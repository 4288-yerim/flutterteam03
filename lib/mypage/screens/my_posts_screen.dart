import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../community/community_main.dart';
import '../../community/community_models.dart';
import '../../community/community_post_detail.dart';
import '../../community/community_post_edit.dart';
import '../../community/community_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_state_views.dart';
import '../../widgets/app_top_bar.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final CommunityService _communityService = CommunityService();
  final List<CommunityPost> _posts = [];

  bool _isLoading = true;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadMyPosts();
  }

  Future<void> _loadMyPosts() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _posts.clear();
        _isLoading = false;
        _errorMessage = '로그인 정보를 확인할 수 없습니다.';
      });

      return;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
      await FirebaseFirestore.instance
          .collection('posts')
          .where(
        'writerUid',
        isEqualTo: user.uid,
      )
          .get();

      final List<CommunityPost> loadedPosts = [];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
      in snapshot.docs) {
        final CommunityPost post =
        CommunityPost.fromDocument(document);

        if (post.postStatus != 'NORMAL') {
          continue;
        }

        if (post.visibility != 'PUBLIC') {
          continue;
        }

        if (post.deletedAt != null) {
          continue;
        }

        loadedPosts.add(post);
      }

      loadedPosts.sort(
            (CommunityPost first, CommunityPost second) {
          final int firstTime =
              first.createdAt?.millisecondsSinceEpoch ?? 0;

          final int secondTime =
              second.createdAt?.millisecondsSinceEpoch ?? 0;

          return secondTime.compareTo(firstTime);
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _posts
          ..clear()
          ..addAll(loadedPosts);

        _isLoading = false;
        _errorMessage = null;
      });
    } on FirebaseException catch (error) {
      debugPrint('내가 쓴 글 Firebase 조회 오류: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _posts.clear();
        _isLoading = false;

        if (error.code == 'permission-denied') {
          _errorMessage = '작성한 게시글을 조회할 권한이 없습니다.';
        } else {
          _errorMessage = '작성한 게시글을 불러오지 못했습니다.';
        }
      });
    } catch (error) {
      debugPrint('내가 쓴 글 조회 오류: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _posts.clear();
        _isLoading = false;
        _errorMessage = '작성한 게시글을 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _openCommunity() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return const CommunityMainPage();
        },
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _loadMyPosts();
  }

  Future<void> _openPostDetail(
      CommunityPost post,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return CommunityPostDetailPage(
            postId: post.id,
            service: _communityService,
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _loadMyPosts();
  }

  Future<void> _editPost(
      CommunityPost post,
      ) async {
    final bool? wasUpdated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) {
          return CommunityPostEditPage(
            post: post,
            service: _communityService,
          );
        },
      ),
    );

    if (!mounted || wasUpdated != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _loadMyPosts();

    if (!mounted) {
      return;
    }

    _showMessage('게시글을 수정했습니다.');
  }

  Future<void> _showDeleteDialog(
      CommunityPost post,
      ) async {
    if (_isDeleting) {
      return;
    }

    final bool? shouldDelete = await showDialog<bool>(
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
            '"${post.title}" 게시글을 삭제하시겠습니까?\n'
                '삭제한 게시글은 다시 표시되지 않습니다.',
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

    if (shouldDelete != true) {
      return;
    }

    await _deletePost(post);
  }

  Future<void> _deletePost(
      CommunityPost post,
      ) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('로그인 정보를 확인할 수 없습니다.');
      return;
    }

    if (user.uid != post.writerUid) {
      _showMessage('작성자만 게시글을 삭제할 수 있습니다.');
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await _communityService.deletePost(post.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _posts.removeWhere(
              (CommunityPost item) {
            return item.id == post.id;
          },
        );
      });

      _showMessage('게시글을 삭제했습니다.');
    } catch (error) {
      debugPrint('내가 쓴 글 삭제 오류: $error');

      if (!mounted) {
        return;
      }

      _showMessage('게시글을 삭제하지 못했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '날짜 정보 없음';
    }

    final String month =
    date.month.toString().padLeft(2, '0');

    final String day =
    date.day.toString().padLeft(2, '0');

    return '${date.year}.$month.$day';
  }

  String _getStatusText(CommunityPost post) {
    if (post.boardType == CommunityBoardType.groupRecruit) {
      if (post.recruitStatus == 'CLOSED') {
        return '모집 완료';
      }

      return '모집 중';
    }

    if (post.boardType == CommunityBoardType.question) {
      if (post.questionStatus == 'SOLVED' ||
          post.questionStatus == 'COMPLETED') {
        return '답변 완료';
      }

      return '답변 대기';
    }

    return '게시 중';
  }

  Color _getStatusBackgroundColor(
      CommunityPost post,
      ) {
    if (post.boardType == CommunityBoardType.groupRecruit) {
      if (post.recruitStatus == 'CLOSED') {
        return const Color(0xFFF3F3F5);
      }

      return const Color(0xFFF2F3FF);
    }

    if (post.boardType == CommunityBoardType.question) {
      if (post.questionStatus == 'SOLVED' ||
          post.questionStatus == 'COMPLETED') {
        return const Color(0xFFF1F7F3);
      }

      return const Color(0xFFFFF6DF);
    }

    return const Color(0xFFF1F7F3);
  }

  Color _getStatusTextColor(
      CommunityPost post,
      ) {
    if (post.boardType == CommunityBoardType.groupRecruit) {
      if (post.recruitStatus == 'CLOSED') {
        return const Color(0xFF777B84);
      }

      return const Color(0xFF666ED8);
    }

    if (post.boardType == CommunityBoardType.question) {
      if (post.questionStatus == 'SOLVED' ||
          post.questionStatus == 'COMPLETED') {
        return const Color(0xFF4C9A65);
      }

      return const Color(0xFFD89422);
    }

    return const Color(0xFF4C9A65);
  }

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
        child: RefreshIndicator(
          onRefresh: _loadMyPosts,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingView(
        message: '작성한 게시글을 불러오는 중입니다.',
      );
    }

    if (_errorMessage != null) {
      return AppErrorView(
        message: '게시글을 불러오지 못했습니다.',
        description: _errorMessage,
        onRetryPressed: () {
          setState(() {
            _isLoading = true;
            _errorMessage = null;
          });

          _loadMyPosts();
        },
      );
    }

    if (_posts.isEmpty) {
      return AppEmptyView(
        message: '작성한 게시글이 없습니다.',
        description: '커뮤니티에서 질문이나 정보를 공유해 보세요.',
        buttonText: '커뮤니티로 이동',
        onButtonPressed: _openCommunity,
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
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
            separatorBuilder: (_, _) {
              return const SizedBox(height: 12);
            },
            itemBuilder: (context, index) {
              final CommunityPost post = _posts[index];

              return _MyPostCard(
                post: post,
                statusText: _getStatusText(post),
                statusBackgroundColor:
                _getStatusBackgroundColor(post),
                statusTextColor:
                _getStatusTextColor(post),
                formattedDate:
                _formatDate(post.createdAt),
                isDeleting: _isDeleting,
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
    );
  }

  Widget _buildPostSummary() {
    final int totalViews = _posts.fold(
      0,
          (
          int sum,
          CommunityPost post,
          ) {
        return sum + post.viewCount;
      },
    );

    final int totalComments = _posts.fold(
      0,
          (
          int sum,
          CommunityPost post,
          ) {
        return sum + post.commentCount;
      },
    );

    final int totalLikes = _posts.fold(
      0,
          (
          int sum,
          CommunityPost post,
          ) {
        return sum + post.likeCount;
      },
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
}

class _MyPostCard extends StatelessWidget {
  final CommunityPost post;
  final String statusText;
  final Color statusBackgroundColor;
  final Color statusTextColor;
  final String formattedDate;
  final bool isDeleting;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MyPostCard({
    required this.post,
    required this.statusText,
    required this.statusBackgroundColor,
    required this.statusTextColor,
    required this.formattedDate,
    required this.isDeleting,
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
                    text: post.boardType.label,
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    text: statusText,
                    backgroundColor:
                    statusBackgroundColor,
                    textColor: statusTextColor,
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    enabled: !isDeleting,
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
                        PopupMenuItem<String>(
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
                        PopupMenuItem<String>(
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
                    formattedDate,
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
      constraints: const BoxConstraints(
        maxWidth: 110,
      ),
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
        overflow: TextOverflow.ellipsis,
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
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const _StatusChip({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
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