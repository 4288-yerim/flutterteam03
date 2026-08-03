import 'package:flutter/material.dart';

import '../../theme.dart';
import '../services/admin_community_service.dart';

class CommunityManagementScreen extends StatefulWidget {
  const CommunityManagementScreen({super.key});

  @override
  State<CommunityManagementScreen> createState() =>
      _CommunityManagementScreenState();
}

class _CommunityManagementScreenState extends State<CommunityManagementScreen> {
  final AdminCommunityService _service = AdminCommunityService();
  final TextEditingController _searchController = TextEditingController();
  _PostFilter _filter = _PostFilter.all;
  String _boardType = 'ALL';
  String? _processingPostId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminCommunityPost> _visiblePosts(List<AdminCommunityPost> posts) {
    final query = _searchController.text.trim().toLowerCase();
    return posts.where((post) {
      final matchesStatus = switch (_filter) {
        _PostFilter.all => true,
        _PostFilter.visible => post.isVisible,
        _PostFilter.hidden => !post.isVisible,
      };
      final matchesBoard = _boardType == 'ALL' || post.boardType == _boardType;
      final matchesSearch =
          query.isEmpty ||
              post.title.toLowerCase().contains(query) ||
              post.content.toLowerCase().contains(query) ||
              post.writerNickname.toLowerCase().contains(query);
      return matchesStatus && matchesBoard && matchesSearch;
    }).toList();
  }

  Future<void> _changePostVisibility(AdminCommunityPost post) async {
    final restore = !post.isVisible && post.wasHiddenByAdmin;
    final action = restore ? '복구' : '숨김';
    final confirmed = await _confirm(
      title: '게시글 $action',
      description: restore
          ? '관리자가 숨긴 게시글을 다시 공개하시겠습니까?'
          : '이 게시글을 사용자 화면에서 숨기시겠습니까?',
      primaryLabel: action,
    );
    if (!confirmed || !mounted) return;

    setState(() => _processingPostId = post.id);
    try {
      if (restore) {
        await _service.restorePost(post);
      } else {
        await _service.hidePost(post);
      }
      if (!mounted) return;
      _showMessage('게시글을 $action 처리했습니다.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _processingPostId = null);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String description,
    required String primaryLabel,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(primaryLabel),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _openComments(AdminCommunityPost post) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _CommentsSheet(service: _service, post: post),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminCommunityPost>>(
      stream: _service.watchPosts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _MessageView(
            icon: Icons.error_outline_rounded,
            title: '커뮤니티 데이터를 불러오지 못했습니다.',
          );
        }
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: context.colors.lavenderAccent,
            ),
          );
        }

        final allPosts = snapshot.data!;
        final posts = _visiblePosts(allPosts);
        final hiddenCount = allPosts.where((post) => !post.isVisible).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
          children: [
            _Header(
              totalCount: allPosts.length,
              hiddenCount: hiddenCount,
              searchController: _searchController,
              filter: _filter,
              boardType: _boardType,
              onSearchChanged: (_) => setState(() {}),
              onFilterChanged: (value) => setState(() => _filter = value),
              onBoardChanged: (value) {
                if (value != null) setState(() => _boardType = value);
              },
            ),
            const SizedBox(height: 16),
            if (posts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 90),
                child: _MessageView(
                  icon: Icons.forum_outlined,
                  title: '표시할 게시글이 없습니다.',
                ),
              )
            else
              ...posts.map(
                    (post) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PostCard(
                    post: post,
                    isProcessing: _processingPostId == post.id,
                    onComments: () => _openComments(post),
                    onVisibilityChanged:
                    !post.isVisible && !post.wasHiddenByAdmin
                        ? null
                        : () => _changePostVisibility(post),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _PostFilter { all, visible, hidden }

class _Header extends StatelessWidget {
  const _Header({
    required this.totalCount,
    required this.hiddenCount,
    required this.searchController,
    required this.filter,
    required this.boardType,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onBoardChanged,
  });

  final int totalCount;
  final int hiddenCount;
  final TextEditingController searchController;
  final _PostFilter filter;
  final String boardType;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_PostFilter> onFilterChanged;
  final ValueChanged<String?> onBoardChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '커뮤니티 콘텐츠 관리',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            '전체 $totalCount개 · 숨김 $hiddenCount개',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: '제목, 내용, 작성자 닉네임 검색',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: '전체',
                selected: filter == _PostFilter.all,
                onSelected: () => onFilterChanged(_PostFilter.all),
              ),
              _FilterChip(
                label: '공개',
                selected: filter == _PostFilter.visible,
                onSelected: () => onFilterChanged(_PostFilter.visible),
              ),
              _FilterChip(
                label: '숨김',
                selected: filter == _PostFilter.hidden,
                onSelected: () => onFilterChanged(_PostFilter.hidden),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  initialValue: boardType,
                  isDense: true,
                  decoration: const InputDecoration(labelText: '게시판'),
                  items: _boardLabels.entries
                      .map(
                        (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                      .toList(),
                  onChanged: onBoardChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: context.colors.lavender,
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isProcessing,
    required this.onComments,
    required this.onVisibilityChanged,
  });

  final AdminCommunityPost post;
  final bool isProcessing;
  final VoidCallback onComments;
  final VoidCallback? onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(visible: post.isVisible),
              const SizedBox(width: 8),
              Text(
                _boardLabels[post.boardType] ?? post.boardType,
                style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(post.createdAt),
                style: TextStyle(color: context.colors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              post.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '${post.writerNickname} · 조회 ${post.viewCount} · 좋아요 ${post.likeCount} · 댓글 ${post.commentCount}',
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onComments,
                icon: const Icon(Icons.comment_outlined, size: 18),
                label: const Text('댓글 관리'),
              ),
              FilledButton.tonalIcon(
                onPressed: isProcessing ? null : onVisibilityChanged,
                icon: isProcessing
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Icon(
                  post.isVisible
                      ? Icons.visibility_off_outlined
                      : Icons.restore_rounded,
                  size: 18,
                ),
                label: Text(
                  post.isVisible
                      ? '게시글 숨김'
                      : post.wasHiddenByAdmin
                      ? '게시글 복구'
                      : '복구 불가',
                ),
              ),
            ],
          ),
          if (!post.isVisible && !post.wasHiddenByAdmin) ...[
            const SizedBox(height: 8),
            Text(
              '사용자 삭제 또는 기존 신고 처리 콘텐츠이므로 이 화면에서는 복구하지 않습니다.',
              style: TextStyle(color: context.colors.warning, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatelessWidget {
  const _CommentsSheet({required this.service, required this.post});
  final AdminCommunityService service;
  final AdminCommunityPost post;

  Future<void> _toggle(
      BuildContext context,
      AdminCommunityComment comment,
      ) async {
    final restore = comment.wasHiddenByAdmin;
    try {
      if (restore) {
        await service.restoreComment(postId: post.id, comment: comment);
      } else {
        await service.hideComment(postId: post.id, comment: comment);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(restore ? '댓글을 복구했습니다.' : '댓글을 숨겼습니다.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '댓글 관리',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<AdminCommunityComment>>(
            stream: service.watchComments(post.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _MessageView(
                  icon: Icons.error_outline,
                  title: '댓글을 불러오지 못했습니다.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final comments = snapshot.data!;
              if (comments.isEmpty) {
                return const _MessageView(
                  icon: Icons.comment_outlined,
                  title: '댓글이 없습니다.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(18),
                itemCount: comments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  final unavailable =
                      comment.status != 'NORMAL' && !comment.wasHiddenByAdmin;
                  return _Panel(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (comment.isReply)
                          Padding(
                            padding: const EdgeInsets.only(right: 8, top: 2),
                            child: Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              color: context.colors.textMuted,
                              size: 18,
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment.writerNickname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                comment.content,
                                style: TextStyle(
                                  color: comment.status == 'NORMAL'
                                      ? context.colors.textPrimary
                                      : context.colors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${_formatDate(comment.createdAt)} · ${comment.status == 'NORMAL' ? '표시 중' : '숨김'}',
                                style: TextStyle(
                                  color: context.colors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: unavailable
                              ? null
                              : () => _toggle(context, comment),
                          child: Text(comment.wasHiddenByAdmin ? '복구' : '숨김'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final color = visible ? context.colors.correct : context.colors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: visible
            ? context.colors.correctSoft
            : context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        visible ? '공개' : '숨김',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: child,
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.colors.textMuted),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

const Map<String, String> _boardLabels = {
  'ALL': '전체 게시판',
  'FREE': '자유',
  'QUESTION': '질문',
  'PASS_REVIEW': '합격 후기',
  'EXAM_REVIEW': '시험 후기',
  'STUDY_SHARE': '학습 자료',
  'BOOK_REVIEW': '교재·인강',
  'TIP': '학습 팁',
  'GROUP_RECRUIT': '스터디 모집',
};

String _formatDate(DateTime? date) {
  if (date == null) return '날짜 없음';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}.${two(date.month)}.${two(date.day)}';
}

String _errorMessage(Object error) {
  if (error is StateError) return error.message;
  if (error is ArgumentError) return error.message?.toString() ?? '$error';
  return '처리 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';
}
