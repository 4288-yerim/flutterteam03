import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// 댓글 좋아요·수정·삭제 적용본
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_state_views.dart';
import '../widgets/app_top_bar.dart';
import 'community_comment_models.dart';
import 'community_models.dart';
import 'community_post_edit.dart';
import 'community_service.dart';

extension _CommunityDetailColors on BuildContext {
  AppColors get communityColors {
    return Theme.of(this).extension<AppColors>() ?? AppColors.light;
  }
}

class CommunityPostDetailPage extends StatefulWidget {
  final String postId;
  final CommunityService? service;

  const CommunityPostDetailPage({
    super.key,
    required this.postId,
    this.service,
  });

  @override
  State<CommunityPostDetailPage> createState() {
    return _CommunityPostDetailPageState();
  }
}

class _CommunityPostDetailPageState
    extends State<CommunityPostDetailPage> {
  late final CommunityService _service;
  final TextEditingController _commentController =
  TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final Map<String, Future<Map<String, dynamic>>>
  _profileFutures = {};

  int _streamVersion = 0;
  bool _viewCountIncreased = false;
  bool _isDeleting = false;
  bool _isReporting = false;
  bool _isSubmittingComment = false;
  bool _isTogglingLike = false;
  bool _isTogglingBookmark = false;
  bool _isUpdatingRecruitStatus = false;
  final Set<String> _togglingCommentLikeIds = {};
  String _replyToCommentId = '';
  String _replyToNickname = '';

  @override
  void initState() {
    super.initState();

    _service = widget.service ?? CommunityService();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _increaseViewCount();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _increaseViewCount() async {
    if (_viewCountIncreased) {
      return;
    }

    _viewCountIncreased = true;

    try {
      await _service.increaseViewCount(widget.postId);
    } catch (error) {
      // 조회수 증가에 실패해도 상세 화면은 정상적으로 표시합니다.
    }
  }

  bool _isWriter(CommunityPost post) {
    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return currentUid.isNotEmpty && currentUid == post.writerUid;
  }

  Future<void> _openEditPage(CommunityPost post) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return CommunityPostEditPage(
            post: post,
            service: _service,
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(CommunityPost post) async {
    if (_isDeleting || !_isWriter(post)) {
      return;
    }

    bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('게시글 삭제'),
          content: const Text('삭제한 게시글은 목록에서 보이지 않아요. 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await _service.deletePost(post.id);

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시글을 삭제하지 못했어요. 다시 시도해 주세요.'),
        ),
      );
    }
  }

  void _selectPostMenu(String value, CommunityPost post) {
    if (value == 'EDIT') {
      _openEditPage(post);
      return;
    }

    if (value == 'DELETE') {
      _confirmDelete(post);
    }
  }

  Future<void> _showPostReportModal(
    CommunityPost post, {
    CommunityComment? comment,
  }) async {
    User? user = FirebaseAuth.instance.currentUser;
    String targetUid = comment?.writerUid ?? post.writerUid;

    if (user == null ||
        user.uid == targetUid ||
        _isReporting) {
      return;
    }

    const Map<String, String> reasons = {
      'SPAM': '스팸',
      'ABUSE': '욕설 또는 괴롭힘',
      'INAPPROPRIATE': '부적절한 콘텐츠',
      'FRAUD': '사기 또는 허위 정보',
      'ETC': '기타',
    };
    TextEditingController descriptionController =
        TextEditingController();
    String selectedReason = 'SPAM';

    bool? shouldReport = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                22,
                14,
                22,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: AppColors.light.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.light.textSecondary
                                .withOpacity(0.25),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.light.incorrectSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.report_outlined,
                              color: AppColors.light.incorrect,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment == null ? '게시글 신고' : '댓글 신고',
                                  style: TextStyle(
                                    color: AppColors.light.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '신고 사유를 선택해 주세요.',
                                  style: TextStyle(
                                    color: AppColors.light.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ...reasons.entries.map((entry) {
                        bool isSelected =
                            selectedReason == entry.key;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setModalState(() {
                                selectedReason = entry.key;
                              });
                            },
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.light.incorrectSoft
                                    : AppColors.light.pinkSoft
                                        .withOpacity(0.35),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.light.incorrect
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: isSelected
                                        ? AppColors.light.incorrect
                                        : AppColors.light.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    entry.value,
                                    style: TextStyle(
                                      color: AppColors.light.textPrimary,
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        maxLength: 500,
                        maxLines: 4,
                        style: TextStyle(
                          color: AppColors.light.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: '상세 내용 (선택)',
                          hintText: '신고 내용을 자세히 알려주세요.',
                          labelStyle: TextStyle(
                            color: AppColors.light.textSecondary,
                          ),
                          hintStyle: TextStyle(
                            color: AppColors.light.textSecondary,
                          ),
                          counterStyle: TextStyle(
                            color: AppColors.light.textSecondary,
                          ),
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: AppColors.light.pinkSoft
                              .withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.light.incorrect,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(modalContext, true);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.light.incorrect,
                            foregroundColor: AppColors.light.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.report_outlined),
                          label: const Text(
                            '신고 접수하기',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    String description = descriptionController.text.trim();
    Future<void>.delayed(
      const Duration(milliseconds: 400),
      descriptionController.dispose,
    );

    if (shouldReport != true || !mounted) {
      return;
    }

    setState(() {
      _isReporting = true;
    });

    try {
      Map<String, dynamic> reporterProfile =
          await _loadWriterProfile(user);
      String reporterNickname =
          reporterProfile['nickname']?.toString().trim() ?? '';

      if (comment == null) {
        await _service.reportPost(
          postId: post.id,
          reporterUid: user.uid,
          reporterNickname: reporterNickname,
          targetTitle: post.title,
          targetNickname: post.writerNickname,
          targetUid: post.writerUid,
          reasonType: selectedReason,
          description: description.isEmpty ? null : description,
        );
      } else {
        await _service.reportComment(
          postId: post.id,
          commentId: comment.id,
          reporterUid: user.uid,
          reporterNickname: reporterNickname,
          targetContent: comment.content,
          targetNickname: comment.writerNickname,
          targetUid: comment.writerUid,
          reasonType: selectedReason,
          description: description.isEmpty ? null : description,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('신고가 접수되었어요. 확인 후 처리할게요.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('신고를 접수하지 못했어요. 다시 시도해 주세요.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isReporting = false;
        });
      }
    }
  }

  String _normalizedRecruitStatus(String status) {
    if (status == 'OPEN' || status.isEmpty) {
      return 'RECRUITING';
    }

    return status;
  }

  String? _nextRecruitStatus(String status) {
    switch (_normalizedRecruitStatus(status)) {
      case 'RECRUITING':
        return 'CLOSED';
      case 'CLOSED':
        return 'ACTIVE';
      case 'ACTIVE':
        return 'COMPLETED';
      default:
        return null;
    }
  }

  String _recruitActionLabel(String nextStatus) {
    switch (nextStatus) {
      case 'CLOSED':
        return '모집 마감하기';
      case 'ACTIVE':
        return '활동 시작하기';
      case 'COMPLETED':
        return '활동 종료하기';
      default:
        return '';
    }
  }

  Future<void> _changeRecruitStatus(
      CommunityPost post,
      ) async {
    User? user = FirebaseAuth.instance.currentUser;
    String? nextStatus =
    _nextRecruitStatus(post.recruitStatus);

    if (_isUpdatingRecruitStatus ||
        user == null ||
        !_isWriter(post) ||
        nextStatus == null) {
      return;
    }

    String actionLabel =
    _recruitActionLabel(nextStatus);

    bool? shouldChange = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(actionLabel),
          content: Text(
            '$actionLabel 상태로 변경할까요?\n변경 후에는 이전 상태로 되돌릴 수 없어요.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('변경'),
            ),
          ],
        );
      },
    );

    if (shouldChange != true || !mounted) {
      return;
    }

    setState(() {
      _isUpdatingRecruitStatus = true;
    });

    try {
      await _service.updateRecruitStatus(
        postId: post.id,
        writerUid: user.uid,
        nextStatus: nextStatus,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_recruitStatusLabel(nextStatus)} 상태로 변경했어요.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '모집 상태를 변경하지 못했어요. 다시 시도해 주세요.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingRecruitStatus = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _loadWriterProfile(
      User user,
      ) async {
    Map<String, dynamic> profile = {};

    try {
      profile = await _service.getUserCommunityProfile(
        user.uid,
      );
    } catch (error) {
      // 프로필 조회 실패 시 Firebase 로그인 정보를 사용합니다.
    }

    String nickname =
        profile['nickname']?.toString().trim() ?? '';

    if (nickname.isEmpty || nickname == '사용자') {
      nickname = user.displayName?.trim() ?? '';
    }

    if (nickname.isEmpty) {
      String email = user.email?.trim() ?? '';

      nickname = email.contains('@')
          ? email.split('@').first
          : '사용자';
    }

    String profileImageUrl =
        profile['profileImageUrl']?.toString().trim() ?? '';

    if (profileImageUrl.isEmpty) {
      profileImageUrl = user.photoURL ?? '';
    }

    return {
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
    };
  }

  Future<Map<String, dynamic>> _profileForUid(
      String userUid,
      ) {
    if (userUid.isEmpty) {
      return Future<Map<String, dynamic>>.value({});
    }

    return _profileFutures.putIfAbsent(
      userUid,
          () {
        return _service.getUserCommunityProfile(
          userUid,
        );
      },
    );
  }

  Future<void> _submitComment() async {
    if (_isSubmittingComment) {
      return;
    }

    String content = _commentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('댓글 내용을 입력해 주세요.'),
        ),
      );
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 후 댓글을 작성할 수 있어요.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      Map<String, dynamic> profile =
      await _loadWriterProfile(user);

      await _service.addComment(
        postId: widget.postId,
        content: content,
        writerUid: user.uid,
        writerNickname:
        profile['nickname']?.toString() ?? '사용자',
        writerProfileImageUrl:
        profile['profileImageUrl']?.toString() ?? '',
        parentCommentId: _replyToCommentId,
      );

      if (!mounted) {
        return;
      }

      _commentController.clear();

      setState(() {
        _isSubmittingComment = false;
        _replyToCommentId = '';
        _replyToNickname = '';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmittingComment = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('댓글을 등록하지 못했어요. 다시 시도해 주세요.'),
        ),
      );
    }
  }

  Future<void> _startReply(
      CommunityComment comment,
      ) async {
    String nickname =
    comment.writerNickname.trim();

    try {
      Map<String, dynamic> profile =
      await _profileForUid(
        comment.writerUid,
      );

      String profileNickname =
          profile['nickname']
              ?.toString()
              .trim() ??
              '';

      if (profileNickname.isNotEmpty &&
          profileNickname != '사용자') {
        nickname = profileNickname;
      }
    } catch (error) {
      // 프로필 조회 실패 시 댓글에 저장된 닉네임을 사용합니다.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _replyToCommentId = comment.id;
      _replyToNickname = nickname;
    });

    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = '';
      _replyToNickname = '';
    });
  }

  Future<void> _editComment(
      CommunityComment comment,
      ) async {
    String currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    if (currentUid.isEmpty ||
        currentUid != comment.writerUid) {
      return;
    }

    TextEditingController editController =
    TextEditingController(text: comment.content);

    String? editedContent = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('댓글 수정'),
          content: TextField(
            controller: editController,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: '댓글 내용을 입력해 주세요.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                String value =
                editController.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              child: const Text('수정'),
            ),
          ],
        );
      },
    );

    editController.dispose();

    if (editedContent == null ||
        editedContent == comment.content.trim() ||
        !mounted) {
      return;
    }

    try {
      await _service.updateComment(
        postId: widget.postId,
        commentId: comment.id,
        writerUid: currentUid,
        content: editedContent,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('댓글을 수정했어요.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('댓글을 수정하지 못했어요.'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteComment(
      CommunityComment comment,
      ) async {
    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (currentUid.isEmpty || currentUid != comment.writerUid) {
      return;
    }

    bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('댓글 삭제'),
          content: const Text('이 댓글을 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await _service.deleteComment(
        postId: widget.postId,
        commentId: comment.id,
        writerUid: currentUid,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('댓글을 삭제하지 못했어요.'),
        ),
      );
    }
  }

  Future<void> _toggleCommentLike(
      CommunityComment comment,
      ) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 후 댓글에 좋아요를 누를 수 있어요.'),
        ),
      );
      return;
    }

    if (_togglingCommentLikeIds.contains(comment.id)) {
      return;
    }

    setState(() {
      _togglingCommentLikeIds.add(comment.id);
    });

    try {
      await _service.toggleCommentLike(
        postId: widget.postId,
        commentId: comment.id,
        userUid: user.uid,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('댓글 좋아요를 처리하지 못했어요.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _togglingCommentLikeIds.remove(comment.id);
        });
      }
    }
  }

  Future<void> _acceptAnswer(
      CommunityPost post,
      CommunityComment comment,
      ) async {
    if (!_isWriter(post) ||
        post.boardType != CommunityBoardType.question ||
        comment.isReply) {
      return;
    }

    try {
      await _service.acceptAnswer(
        postId: post.id,
        commentId: comment.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('답변을 채택했어요. 질문이 해결 완료로 바뀌었어요.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('답변을 채택하지 못했어요.'),
        ),
      );
    }
  }

  Future<void> _toggleLike(CommunityPost post) async {
    if (_isTogglingLike) {
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 후 좋아요를 누를 수 있어요.'),
        ),
      );
      return;
    }

    setState(() {
      _isTogglingLike = true;
    });

    try {
      await _service.toggleLike(
        postId: post.id,
        userUid: user.uid,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('좋아요 처리에 실패했어요.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingLike = false;
        });
      }
    }
  }

  Future<void> _toggleBookmark(CommunityPost post) async {
    if (_isTogglingBookmark) {
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 후 게시글을 저장할 수 있어요.'),
        ),
      );
      return;
    }

    setState(() {
      _isTogglingBookmark = true;
    });

    try {
      await _service.toggleBookmark(
        postId: post.id,
        userUid: user.uid,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('게시글 저장 처리에 실패했어요.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingBookmark = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(
        title: '게시글 상세',
      ),
      body: AppMainBackground(
        child: StreamBuilder<CommunityPost?>(
          key: ValueKey(_streamVersion),
          stream: _service.watchPost(widget.postId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorView(
                message: '게시글을 불러오지 못했어요.',
                description:
                '인터넷 연결과 Firestore 규칙을 확인해 주세요.',
                onRetryPressed: () {
                  setState(() {
                    _streamVersion++;
                  });
                },
              );
            }

            if (!snapshot.hasData &&
                snapshot.connectionState ==
                    ConnectionState.waiting) {
              return const AppLoadingView(
                message: '게시글을 불러오는 중이에요.',
              );
            }

            CommunityPost? post = snapshot.data;

            if (post == null) {
              return AppEmptyView(
                message: '게시글을 찾을 수 없어요.',
                description:
                '삭제되었거나 공개되지 않은 게시글이에요.',
                buttonText: '돌아가기',
                onButtonPressed: () {
                  Navigator.pop(context);
                },
              );
            }

            return _buildContent(post);
          },
        ),
      ),
    );
  }

  Widget _buildContent(CommunityPost post) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        50,
      ),
      children: [
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBoardArea(post),
              const SizedBox(height: 16),
              Text(
                post.title,
                style: TextStyle(
                  color: context.communityColors.textPrimary,
                  fontSize: 22,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 15),
              _buildWriterArea(post),
              const SizedBox(height: 17),
              Divider(
                height: 1,
                color: context.communityColors.pinkSoft,
              ),
              const SizedBox(height: 20),
              Text(
                post.content,
                style: TextStyle(
                  color: context.communityColors.textPrimary,
                  fontSize: 15,
                  height: 1.7,
                ),
              ),
              if (post.certificateTags.isNotEmpty) ...[
                const SizedBox(height: 22),
                _buildCertificateTags(post.certificateTags),
              ],
              if (post.imageAttachments.isNotEmpty) ...[
                const SizedBox(height: 22),
                _buildImages(post.imageAttachments),
              ],
              if (post.fileAttachments.isNotEmpty) ...[
                const SizedBox(height: 22),
                _buildFiles(post.fileAttachments),
              ],
              const SizedBox(height: 22),
              Divider(
                height: 1,
                color: context.communityColors.pinkSoft,
              ),
              const SizedBox(height: 15),
              _buildPostCounts(post),
              if (post.boardType ==
                  CommunityBoardType.groupRecruit &&
                  _isWriter(post) &&
                  _nextRecruitStatus(
                    post.recruitStatus,
                  ) !=
                      null) ...[
                const SizedBox(height: 18),
                _buildRecruitStatusButton(post),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCommentsSection(post),
      ],
    );
  }

  Widget _buildRecruitStatusButton(
      CommunityPost post,
      ) {
    String? nextStatus =
    _nextRecruitStatus(post.recruitStatus);

    if (nextStatus == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton.icon(
        onPressed: _isUpdatingRecruitStatus
            ? null
            : () {
          _changeRecruitStatus(post);
        },
        style: FilledButton.styleFrom(
          backgroundColor:
          context.communityColors.pinkStart,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isUpdatingRecruitStatus
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Icon(
          Icons.sync_alt_rounded,
          size: 19,
        ),
        label: Text(
          _recruitActionLabel(nextStatus),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsSection(CommunityPost post) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: context.communityColors.pinkStart,
                size: 21,
              ),
              const SizedBox(width: 8),
              Text(
                '댓글',
                style: TextStyle(
                  color: context.communityColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${post.commentCount}',
                style: TextStyle(
                  color: context.communityColors.pinkStart,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(
            height: 1,
            color: context.communityColors.pinkSoft,
          ),
          StreamBuilder<List<CommunityComment>>(
            stream: _service.watchComments(post.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      '댓글을 불러오지 못했어요.',
                      style: TextStyle(
                        color: context.communityColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 25),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                );
              }

              return _buildCommentList(
                post,
                snapshot.data ?? [],
              );
            },
          ),
          Divider(
            height: 1,
            color: context.communityColors.pinkSoft,
          ),
          const SizedBox(height: 14),
          _buildCommentEditor(),
        ],
      ),
    );
  }

  Widget _buildCommentList(
      CommunityPost post,
      List<CommunityComment> comments,
      ) {
    List<CommunityComment> rootComments = comments.where((comment) {
      return !comment.isReply;
    }).toList();

    if (rootComments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.forum_outlined,
                size: 30,
                color: context.communityColors.textSecondary,
              ),
              const SizedBox(height: 9),
              Text(
                '아직 댓글이 없어요. 첫 댓글을 남겨보세요.',
                style: TextStyle(
                  color: context.communityColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: rootComments.map((comment) {
          List<CommunityComment> replies = comments.where((reply) {
            return reply.parentCommentId == comment.id;
          }).toList();

          return Column(
            children: [
              _buildCommentItem(
                post: post,
                comment: comment,
                isReply: false,
              ),
              ...replies.map((reply) {
                return _buildCommentItem(
                  post: post,
                  comment: reply,
                  isReply: true,
                );
              }),
              Divider(
                height: 1,
                color: context.communityColors.pinkSoft,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCommentItem({
    required CommunityPost post,
    required CommunityComment comment,
    required bool isReply,
  }) {
    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    bool canManage = currentUid.isNotEmpty &&
        currentUid == comment.writerUid;
    bool canAccept = post.boardType == CommunityBoardType.question &&
        _isWriter(post) &&
        !isReply &&
        !comment.isAccepted &&
        comment.writerUid != post.writerUid;

    return Container(
      margin: EdgeInsets.only(
        left: isReply ? 28 : 0,
        top: 13,
        bottom: 13,
      ),
      padding: isReply
          ? const EdgeInsets.fromLTRB(12, 12, 10, 11)
          : EdgeInsets.zero,
      decoration: isReply
          ? BoxDecoration(
        color: context.communityColors.pinkSoft.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
      )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentWriterHeader(
            post: post,
            comment: comment,
          ),
          const SizedBox(height: 10),
          Text(
            comment.content,
            style: TextStyle(
              color: context.communityColors.textPrimary,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildCommentLikeButton(comment),
              if (!isReply)
                _buildCompactCommentAction(
                  icon:
                  Icons.subdirectory_arrow_right_rounded,
                  label: '답글',
                  onPressed: () {
                    _startReply(comment);
                  },
                ),
              if (!canManage && currentUid.isNotEmpty)
                _buildCompactCommentAction(
                  icon: Icons.report_outlined,
                  label: '신고',
                  onPressed: () {
                    _showPostReportModal(
                      post,
                      comment: comment,
                    );
                  },
                ),
              if (canAccept)
                _buildCompactCommentAction(
                  icon:
                  Icons.check_circle_outline_rounded,
                  label: '답변 채택',
                  onPressed: () {
                    _acceptAnswer(post, comment);
                  },
                ),
              if (canManage)
                _buildCompactCommentAction(
                  icon: Icons.edit_outlined,
                  label: '수정',
                  onPressed: () {
                    _editComment(comment);
                  },
                ),
              if (canManage)
                _buildCompactCommentAction(
                  icon: Icons.delete_outline_rounded,
                  label: '삭제',
                  onPressed: () {
                    _confirmDeleteComment(comment);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCommentAction({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    Color actionColor =
        color ?? context.communityColors.textSecondary;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 1,
            vertical: 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: actionColor,
              ),
              const SizedBox(width: 3),
              Text(
                label,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: actionColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentWriterHeader({
    required CommunityPost post,
    required CommunityComment comment,
  }) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileForUid(comment.writerUid),
      builder: (context, snapshot) {
        Map<String, dynamic> profile =
            snapshot.data ?? {};

        String nickname =
            profile['nickname']?.toString().trim() ?? '';
        String profileImageUrl =
            profile['profileImageUrl']
                ?.toString()
                .trim() ??
                '';

        if (nickname.isEmpty || nickname == '사용자') {
          nickname = comment.writerNickname;
        }

        if (profileImageUrl.isEmpty) {
          profileImageUrl =
              comment.writerProfileImageUrl;
        }

        return Row(
          children: [
            _buildSmallProfileImage(profileImageUrl),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context
                                .communityColors
                                .textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (comment.writerUid ==
                          post.writerUid) ...[
                        const SizedBox(width: 6),
                        _DetailBadge(
                          label: '작성자',
                          backgroundColor: context
                              .communityColors.softBlue,
                        ),
                      ],
                      if (comment.isAccepted) ...[
                        const SizedBox(width: 6),
                        _DetailBadge(
                          label: '채택 답변',
                          backgroundColor: context
                              .communityColors.mint,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatCreatedAt(comment.createdAt),
                    style: TextStyle(
                      color: context
                          .communityColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommentLikeButton(
      CommunityComment comment,
      ) {
    String currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? '';
    bool isProcessing =
    _togglingCommentLikeIds.contains(comment.id);

    if (currentUid.isEmpty) {
      return _buildCompactCommentAction(
        icon: Icons.favorite_border_rounded,
        label: '좋아요 ${comment.likeCount}',
        onPressed: () {
          _toggleCommentLike(comment);
        },
      );
    }

    return StreamBuilder<bool>(
      stream: _service.watchCommentLikeStatus(
        commentId: comment.id,
        userUid: currentUid,
      ),
      builder: (context, snapshot) {
        bool isLiked = snapshot.data ?? false;

        return _buildCompactCommentAction(
          icon: isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: '좋아요 ${comment.likeCount}',
          onPressed: isProcessing
              ? null
              : () {
            _toggleCommentLike(comment);
          },
          color: isLiked
              ? context.communityColors.pinkStart
              : context.communityColors.textSecondary,
        );
      },
    );
  }

  Widget _buildSmallProfileImage(String imageUrl) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.communityColors.pinkSoft,
      ),
      child: imageUrl.isEmpty
          ? Icon(
        Icons.person_rounded,
        size: 20,
        color: context.communityColors.pinkStart,
      )
          : ClipOval(
        child: Image.network(
          imageUrl,
          width: 34,
          height: 34,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.person_rounded,
              size: 20,
              color: context.communityColors.pinkStart,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCommentEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_replyToCommentId.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: context.communityColors.softBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$_replyToNickname님에게 답글 작성 중',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.communityColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _cancelReply,
                  borderRadius: BorderRadius.circular(15),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      Icons.close_rounded,
                      size: 17,
                      color: context.communityColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                enabled: !_isSubmittingComment,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: _replyToCommentId.isEmpty
                      ? '댓글을 입력해 주세요.'
                      : '답글을 입력해 주세요.',
                  counterText: '',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide(
                      color: context.communityColors.pinkSoft,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide(
                      color: context.communityColors.pinkSoft,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide(
                      color: context.communityColors.pinkStart,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: FilledButton(
                onPressed:
                _isSubmittingComment ? null : _submitComment,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: context.communityColors.pinkStart,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: _isSubmittingComment
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.send_rounded,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBoardArea(CommunityPost post) {
    return Row(
      children: [
        _DetailBadge(
          label: post.boardType.label,
          backgroundColor: context.communityColors.pinkSoft,
        ),
        if (post.boardType == CommunityBoardType.question) ...[
          const SizedBox(width: 7),
          _DetailBadge(
            label: _questionStatusLabel(post.questionStatus),
            backgroundColor: context.communityColors.softBlue,
          ),
        ],
        if (post.boardType == CommunityBoardType.groupRecruit) ...[
          const SizedBox(width: 7),
          _DetailBadge(
            label: _recruitStatusLabel(post.recruitStatus),
            backgroundColor: context.communityColors.mint,
          ),
        ],
        const Spacer(),
        if (post.hasAttachment)
          Icon(
            Icons.attach_file_rounded,
            size: 19,
            color: context.communityColors.textSecondary,
          ),
        if (_isWriter(post))
          PopupMenuButton<String>(
            tooltip: '게시글 관리',
            enabled: !_isDeleting,
            onSelected: (value) {
              _selectPostMenu(value, post);
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<String>(
                  value: 'EDIT',
                  child: Text('수정'),
                ),
                PopupMenuItem<String>(
                  value: 'DELETE',
                  child: Text('삭제'),
                ),
              ];
            },
            icon: _isDeleting
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : Icon(
              Icons.more_vert_rounded,
              color: context.communityColors.textSecondary,
            ),
          ),
        if (!_isWriter(post) &&
            FirebaseAuth.instance.currentUser != null)
          IconButton(
            tooltip: '게시글 신고',
            onPressed: _isReporting
                ? null
                : () {
              _showPostReportModal(post);
            },
            icon: _isReporting
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.red,
              ),
            )
                : const Icon(
              Icons.report_outlined,
              color: Colors.red,
            ),
          ),
      ],
    );
  }

  Widget _buildWriterArea(CommunityPost post) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileForUid(post.writerUid),
      builder: (context, snapshot) {
        Map<String, dynamic> profile =
            snapshot.data ?? {};

        String nickname =
            profile['nickname']?.toString().trim() ?? '';
        String profileImageUrl =
            profile['profileImageUrl']
                ?.toString()
                .trim() ??
                '';

        if (nickname.isEmpty || nickname == '사용자') {
          nickname = post.writerNickname;
        }

        if (profileImageUrl.isEmpty) {
          profileImageUrl =
              post.writerProfileImageUrl;
        }

        return Row(
          children: [
            _buildProfileImage(profileImageUrl),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context
                                .communityColors
                                .textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (post.isCertifiedWriter) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: context
                              .communityColors.pinkStart,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCreatedAt(post.createdAt),
                    style: TextStyle(
                      color: context
                          .communityColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileImage(String imageUrl) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.communityColors.pinkSoft,
      ),
      child: imageUrl.isEmpty
          ? Icon(
        Icons.person_rounded,
        color: context.communityColors.pinkStart,
      )
          : ClipOval(
        child: Image.network(
          imageUrl,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.person_rounded,
              color: context.communityColors.pinkStart,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCertificateTags(
      List<CommunityCertificateTag> tags,
      ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: context.communityColors.lavender,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '#${tag.certificateName}',
            style: TextStyle(
              color: context.communityColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImages(
      List<CommunityImageAttachment> images,
      ) {
    return Column(
      children: images.map((image) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              image.url,
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 180,
                  alignment: Alignment.center,
                  color: context.communityColors.pinkSoft,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: context.communityColors.textSecondary,
                  ),
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFiles(
      List<CommunityFileAttachment> files,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '첨부파일',
          style: TextStyle(
            color: context.communityColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        ...files.map((file) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: context.communityColors.softBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 20,
                  color: context.communityColors.pinkStart,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.communityColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPostCounts(CommunityPost post) {
    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Row(
      children: [
        Expanded(
          child: _DetailCount(
            icon: Icons.remove_red_eye_outlined,
            label: '조회',
            value: post.viewCount,
          ),
        ),
        Expanded(
          child: _DetailCount(
            icon: Icons.chat_bubble_outline_rounded,
            label: '댓글',
            value: post.commentCount,
          ),
        ),
        Expanded(
          child: currentUid.isEmpty
              ? _DetailCount(
            icon: Icons.favorite_border_rounded,
            label: '좋아요',
            value: post.likeCount,
            onTap: () {
              _toggleLike(post);
            },
          )
              : StreamBuilder<bool>(
            stream: _service.watchLikeStatus(
              postId: post.id,
              userUid: currentUid,
            ),
            builder: (context, snapshot) {
              bool isLiked = snapshot.data ?? false;

              return _DetailCount(
                icon: isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '좋아요',
                value: post.likeCount,
                isActive: isLiked,
                enabled: !_isTogglingLike,
                onTap: () {
                  _toggleLike(post);
                },
              );
            },
          ),
        ),
        Expanded(
          child: currentUid.isEmpty
              ? _DetailCount(
            icon: Icons.bookmark_border_rounded,
            label: '저장',
            value: post.bookmarkCount,
            onTap: () {
              _toggleBookmark(post);
            },
          )
              : StreamBuilder<bool>(
            stream: _service.watchBookmarkStatus(
              postId: post.id,
              userUid: currentUid,
            ),
            builder: (context, snapshot) {
              bool isBookmarked = snapshot.data ?? false;

              return _DetailCount(
                icon: isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                label: '저장',
                value: post.bookmarkCount,
                isActive: isBookmarked,
                enabled: !_isTogglingBookmark,
                onTap: () {
                  _toggleBookmark(post);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DetailBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;

  const _DetailBadge({
    required this.label,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.communityColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailCount extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final bool isActive;
  final bool enabled;
  final VoidCallback? onTap;

  const _DetailCount({
    required this.icon,
    required this.label,
    required this.value,
    this.isActive = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color color = isActive
        ? context.communityColors.pinkStart
        : context.communityColors.textSecondary;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Icon(
              icon,
              size: 19,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              '$label $value',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight:
                isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _questionStatusLabel(String status) {
  switch (status) {
    case 'ANSWERED':
      return '답변 완료';
    case 'RESOLVED':
    case 'CLOSED':
      return '해결 완료';
    default:
      return '답변 대기';
  }
}

String _recruitStatusLabel(String status) {
  switch (status) {
    case 'CLOSED':
      return '모집 마감';
    case 'ACTIVE':
      return '활동 중';
    case 'COMPLETED':
      return '활동 종료';
    default:
      return '모집 중';
  }
}

String _formatCreatedAt(DateTime? dateTime) {
  if (dateTime == null) {
    return '';
  }

  String year = dateTime.year.toString();
  String month = dateTime.month.toString().padLeft(2, '0');
  String day = dateTime.day.toString().padLeft(2, '0');
  String hour = dateTime.hour.toString().padLeft(2, '0');
  String minute = dateTime.minute.toString().padLeft(2, '0');

  return '$year.$month.$day $hour:$minute';
}
