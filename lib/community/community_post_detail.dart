import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// 댓글 좋아요·수정·삭제 적용본
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_report_bottom_sheet.dart';
import '../widgets/app_state_views.dart';
import '../widgets/app_top_bar.dart';
import 'community_comment_models.dart';
import 'community_models.dart';
import 'community_post_edit.dart';
import 'community_service.dart';

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

class _CommunityPostDetailPageState extends State<CommunityPostDetailPage> {
  late final CommunityService _service;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final Dio _dio = Dio();
  final Map<String, Future<Map<String, dynamic>>> _profileFutures = {};

  int _streamVersion = 0;
  bool _viewCountIncreased = false;
  bool _isDeleting = false;
  bool _isReporting = false;
  bool _isSubmittingComment = false;
  bool _isTogglingLike = false;
  bool _isTogglingBookmark = false;
  bool _isUpdatingRecruitStatus = false;
  final Set<String> _togglingCommentLikeIds = {};
  final Set<String> _processingCommentIds = {};
  final Set<String> _openingFilePaths = {};
  final Set<String> _downloadingAttachmentKeys = {};
  final Map<String, double> _downloadProgress = {};
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
    _dio.close(force: true);
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
          return CommunityPostEditPage(post: post, service: _service);
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
        const SnackBar(content: Text('게시글을 삭제하지 못했어요. 다시 시도해 주세요.')),
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

    if (user == null || user.uid == targetUid || _isReporting) {
      return;
    }

    const Map<String, String> reasons = {
      'SPAM': '스팸',
      'ABUSE': '욕설 또는 괴롭힘',
      'INAPPROPRIATE': '부적절한 콘텐츠',
      'FRAUD': '사기 또는 허위 정보',
      'ETC': '기타',
    };
    final result = await AppReportBottomSheet.show(
      context,
      title: comment == null ? '게시글 신고' : '댓글 신고',
      reasons: reasons,
    );

    if (result == null || !mounted) {
      return;
    }

    final selectedReason = result.reasonType;
    final description = result.description;

    setState(() {
      _isReporting = true;
    });

    try {
      Map<String, dynamic> reporterProfile = await _loadWriterProfile(user);
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('신고가 접수되었어요. 확인 후 처리할게요.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고를 접수하지 못했어요. 다시 시도해 주세요.')),
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

  Future<void> _changeRecruitStatus(CommunityPost post) async {
    User? user = FirebaseAuth.instance.currentUser;
    String? nextStatus = _nextRecruitStatus(post.recruitStatus);

    if (_isUpdatingRecruitStatus ||
        user == null ||
        !_isWriter(post) ||
        nextStatus == null) {
      return;
    }

    String actionLabel = _recruitActionLabel(nextStatus);

    bool? shouldChange = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(actionLabel),
          content: Text('$actionLabel 상태로 변경할까요?\n변경 후에는 이전 상태로 되돌릴 수 없어요.'),
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
          content: Text('${_recruitStatusLabel(nextStatus)} 상태로 변경했어요.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모집 상태를 변경하지 못했어요. 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingRecruitStatus = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _loadWriterProfile(User user) async {
    Map<String, dynamic> profile = {};

    try {
      profile = await _service.getUserCommunityProfile(user.uid);
    } catch (error) {
      // 프로필 조회 실패 시 Firebase 로그인 정보를 사용합니다.
    }

    String nickname = profile['nickname']?.toString().trim() ?? '';

    if (nickname.isEmpty || nickname == '사용자') {
      nickname = user.displayName?.trim() ?? '';
    }

    if (nickname.isEmpty) {
      String email = user.email?.trim() ?? '';

      nickname = email.contains('@') ? email.split('@').first : '사용자';
    }

    String profileImageUrl =
        profile['profileImageUrl']?.toString().trim() ?? '';

    if (profileImageUrl.isEmpty) {
      profileImageUrl = user.photoURL ?? '';
    }

    return {'nickname': nickname, 'profileImageUrl': profileImageUrl};
  }

  Future<Map<String, dynamic>> _profileForUid(String userUid) {
    if (userUid.isEmpty) {
      return Future<Map<String, dynamic>>.value({});
    }

    return _profileFutures.putIfAbsent(userUid, () {
      return _service.getUserCommunityProfile(userUid);
    });
  }

  Future<void> _submitComment() async {
    if (_isSubmittingComment) {
      return;
    }

    String content = _commentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글 내용을 입력해 주세요.')));
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 후 댓글을 작성할 수 있어요.')));
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      Map<String, dynamic> profile = await _loadWriterProfile(user);

      await _service.addComment(
        postId: widget.postId,
        content: content,
        writerUid: user.uid,
        writerNickname: profile['nickname']?.toString() ?? '사용자',
        writerProfileImageUrl: profile['profileImageUrl']?.toString() ?? '',
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
        const SnackBar(content: Text('댓글을 등록하지 못했어요. 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _startReply(CommunityComment comment) async {
    String nickname = comment.writerNickname.trim();

    try {
      Map<String, dynamic> profile = await _profileForUid(comment.writerUid);

      String profileNickname = profile['nickname']?.toString().trim() ?? '';

      if (profileNickname.isNotEmpty && profileNickname != '사용자') {
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

  Future<void> _editComment(CommunityComment comment) async {
    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (currentUid.isEmpty ||
        currentUid != comment.writerUid ||
        _processingCommentIds.contains(comment.id)) {
      return;
    }

    String? editedContent = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _CommentEditDialog(
          initialContent: comment.content,
        );
      },
    );

    if (editedContent == null ||
        editedContent == comment.content.trim() ||
        !mounted) {
      return;
    }

    setState(() {
      _processingCommentIds.add(comment.id);
    });

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글을 수정했어요.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글을 수정하지 못했어요.')));
    } finally {
      if (mounted) {
        setState(() {
          _processingCommentIds.remove(comment.id);
        });
      }
    }
  }

  Future<void> _confirmDeleteComment(CommunityComment comment) async {
    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (currentUid.isEmpty ||
        currentUid != comment.writerUid ||
        _processingCommentIds.contains(comment.id)) {
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

    setState(() {
      _processingCommentIds.add(comment.id);
    });

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글을 삭제하지 못했어요.')));
    } finally {
      if (mounted) {
        setState(() {
          _processingCommentIds.remove(comment.id);
        });
      }
    }
  }

  Future<void> _toggleCommentLike(CommunityComment comment) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 후 댓글에 좋아요를 누를 수 있어요.')));
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글 좋아요를 처리하지 못했어요.')));
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
        comment.isReply ||
        _processingCommentIds.contains(comment.id)) {
      return;
    }

    setState(() {
      _processingCommentIds.add(comment.id);
    });

    try {
      await _service.acceptAnswer(postId: post.id, commentId: comment.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('답변을 채택했어요. 질문이 해결 완료로 바뀌었어요.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('답변을 채택하지 못했어요.')));
    } finally {
      if (mounted) {
        setState(() {
          _processingCommentIds.remove(comment.id);
        });
      }
    }
  }

  Future<void> _toggleLike(CommunityPost post) async {
    if (_isTogglingLike) {
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 후 좋아요를 누를 수 있어요.')));
      return;
    }

    setState(() {
      _isTogglingLike = true;
    });

    try {
      await _service.toggleLike(postId: post.id, userUid: user.uid);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('좋아요 처리에 실패했어요.')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 후 게시글을 저장할 수 있어요.')));
      return;
    }

    setState(() {
      _isTogglingBookmark = true;
    });

    try {
      await _service.toggleBookmark(postId: post.id, userUid: user.uid);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('게시글 저장 처리에 실패했어요.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingBookmark = false;
        });
      }
    }
  }

  Future<void> _openFileAttachment(CommunityFileAttachment file) async {
    String key = file.path.isNotEmpty ? file.path : file.url;

    if (key.isEmpty || _openingFilePaths.contains(key)) {
      return;
    }

    Uri? uri = Uri.tryParse(file.url);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('첨부파일 주소가 올바르지 않아요.')),
      );
      return;
    }

    setState(() {
      _openingFilePaths.add(key);
    });

    try {
      bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        opened = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('첨부파일을 열 수 없어요.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('첨부파일을 열지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingFilePaths.remove(key);
        });
      }
    }
  }

  Future<void> _downloadAttachment({
    required String url,
    required String fileName,
    required String key,
  }) async {
    if (url.isEmpty ||
        key.isEmpty ||
        _downloadingAttachmentKeys.contains(key)) {
      return;
    }

    Uri? uri = Uri.tryParse(url);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다운로드 주소가 올바르지 않아요.')),
      );
      return;
    }

    setState(() {
      _downloadingAttachmentKeys.add(key);
      _downloadProgress[key] = 0;
    });

    try {
      Response<List<int>> response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (!mounted || total <= 0) {
            return;
          }

          setState(() {
            _downloadProgress[key] = received / total;
          });
        },
      );

      List<int>? data = response.data;

      if (data == null || data.isEmpty) {
        throw StateError('다운로드한 파일이 비어 있습니다.');
      }

      String safeFileName = fileName
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();

      if (safeFileName.isEmpty) {
        safeFileName = '첨부파일';
      }

      String? savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '파일을 저장할 위치를 선택해 주세요.',
        fileName: safeFileName,
        bytes: Uint8List.fromList(data),
      );

      if (!mounted || savedPath == null) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일을 저장했어요.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일을 다운로드하지 못했어요.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingAttachmentKeys.remove(key);
          _downloadProgress.remove(key);
        });
      }
    }
  }

  String _imageDownloadName(
      CommunityImageAttachment image,
      int index,
      ) {
    String name = image.path.split('/').last.trim();

    if (name.isNotEmpty && name.contains('.')) {
      return name;
    }

    return 'community_image_${index + 1}.jpg';
  }

  Future<void> _showImageViewer(
      List<CommunityImageAttachment> images,
      int initialIndex,
      ) async {
    FocusScope.of(context).unfocus();

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (dialogContext) {
        return _CommunityImageViewer(
          images: images,
          initialIndex: initialIndex,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: '게시글 상세'),
      body: AppMainBackground(
        child: StreamBuilder<CommunityPost?>(
          key: ValueKey(_streamVersion),
          stream: _service.watchPost(widget.postId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorView(
                message: '게시글을 불러오지 못했어요.',
                description: '인터넷 연결과 Firestore 규칙을 확인해 주세요.',
                onRetryPressed: () {
                  setState(() {
                    _streamVersion++;
                  });
                },
              );
            }

            if (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingView(message: '게시글을 불러오는 중이에요.');
            }

            CommunityPost? post = snapshot.data;

            if (post == null) {
              return AppEmptyView(
                message: '게시글을 찾을 수 없어요.',
                description: '삭제되었거나 공개되지 않은 게시글이에요.',
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 50),
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
                  color: context.colors.textPrimary,
                  fontSize: 22,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 15),
              _buildWriterArea(post),
              const SizedBox(height: 17),
              Divider(height: 1, color: context.colors.pinkSoft),
              const SizedBox(height: 20),
              Text(
                post.content,
                style: TextStyle(
                  color: context.colors.textPrimary,
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
              Divider(height: 1, color: context.colors.pinkSoft),
              const SizedBox(height: 15),
              _buildPostCounts(post),
              if (post.boardType == CommunityBoardType.groupRecruit &&
                  _isWriter(post) &&
                  _nextRecruitStatus(post.recruitStatus) != null) ...[
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

  Widget _buildRecruitStatusButton(CommunityPost post) {
    String? nextStatus = _nextRecruitStatus(post.recruitStatus);

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
          backgroundColor: context.colors.pinkStart,
          foregroundColor: context.colors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isUpdatingRecruitStatus
            ? SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.colors.onPrimary,
          ),
        )
            : const Icon(Icons.sync_alt_rounded, size: 19),
        label: Text(
          _recruitActionLabel(nextStatus),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
                color: context.colors.pinkStart,
                size: 21,
              ),
              const SizedBox(width: 8),
              Text(
                '댓글',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${post.commentCount}',
                style: TextStyle(
                  color: context.colors.pinkStart,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(height: 1, color: context.colors.pinkSoft),
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
                        color: context.colors.textSecondary,
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              return _buildCommentList(post, snapshot.data ?? []);
            },
          ),
          Divider(height: 1, color: context.colors.pinkSoft),
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
                color: context.colors.textSecondary,
              ),
              const SizedBox(height: 9),
              Text(
                '아직 댓글이 없어요. 첫 댓글을 남겨보세요.',
                style: TextStyle(
                  color: context.colors.textSecondary,
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
              _buildCommentItem(post: post, comment: comment, isReply: false),
              ...replies.map((reply) {
                return _buildCommentItem(
                  post: post,
                  comment: reply,
                  isReply: true,
                );
              }),
              Divider(height: 1, color: context.colors.pinkSoft),
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
    if (comment.isModerationHidden) {
      return _buildModerationHiddenCommentItem(
        isReply: isReply,
      );
    }

    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    bool canManage = currentUid.isNotEmpty && currentUid == comment.writerUid;
    bool isProcessing = _processingCommentIds.contains(comment.id);
    bool canAccept =
        post.boardType == CommunityBoardType.question &&
            _isWriter(post) &&
            !isReply &&
            !comment.isAccepted &&
            comment.writerUid != post.writerUid;

    return Container(
      margin: EdgeInsets.only(left: isReply ? 28 : 0, top: 13, bottom: 13),
      padding: isReply
          ? const EdgeInsets.fromLTRB(12, 12, 10, 11)
          : EdgeInsets.zero,
      decoration: isReply
          ? BoxDecoration(
        color: context.colors.pinkSoft.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
      )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentWriterHeader(post: post, comment: comment),
          const SizedBox(height: 10),
          Text(
            comment.content,
            style: TextStyle(
              color: context.colors.textPrimary,
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
                  icon: Icons.subdirectory_arrow_right_rounded,
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
                    _showPostReportModal(post, comment: comment);
                  },
                ),
              if (canAccept)
                _buildCompactCommentAction(
                  icon: Icons.check_circle_outline_rounded,
                  label: '답변 채택',
                  onPressed: isProcessing
                      ? null
                      : () {
                    _acceptAnswer(post, comment);
                  },
                ),
              if (canManage)
                _buildCompactCommentAction(
                  icon: Icons.edit_outlined,
                  label: '수정',
                  onPressed: isProcessing
                      ? null
                      : () {
                    _editComment(comment);
                  },
                ),
              if (canManage)
                _buildCompactCommentAction(
                  icon: Icons.delete_outline_rounded,
                  label: '삭제',
                  onPressed: isProcessing
                      ? null
                      : () {
                    _confirmDeleteComment(comment);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModerationHiddenCommentItem({
    required bool isReply,
  }) {
    return Container(
      margin: EdgeInsets.only(
        left: isReply ? 28 : 0,
        top: 13,
        bottom: 13,
      ),
      padding: isReply
          ? const EdgeInsets.fromLTRB(12, 14, 10, 14)
          : const EdgeInsets.symmetric(vertical: 14),
      decoration: isReply
          ? BoxDecoration(
        color: context.colors.pinkSoft
            .withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
      )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 18,
            color: context.colors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '관리자에 의해 숨겨진 댓글입니다.',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
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
    Color actionColor = color ?? context.colors.textSecondary;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: actionColor),
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
        Map<String, dynamic> profile = snapshot.data ?? {};

        String nickname = profile['nickname']?.toString().trim() ?? '';
        String profileImageUrl =
            profile['profileImageUrl']?.toString().trim() ?? '';

        if (nickname.isEmpty || nickname == '사용자') {
          nickname = comment.writerNickname;
        }

        if (profileImageUrl.isEmpty) {
          profileImageUrl = comment.writerProfileImageUrl;
        }

        return Row(
          children: [
            _buildSmallProfileImage(profileImageUrl),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (comment.writerUid == post.writerUid) ...[
                        const SizedBox(width: 6),
                        _DetailBadge(
                          label: '작성자',
                          backgroundColor: context.colors.softBlue,
                        ),
                      ],
                      if (comment.isAccepted) ...[
                        const SizedBox(width: 6),
                        _DetailBadge(
                          label: '채택 답변',
                          backgroundColor: context.colors.mint,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatCreatedAt(comment.createdAt),
                    style: TextStyle(
                      color: context.colors.textSecondary,
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

  Widget _buildCommentLikeButton(CommunityComment comment) {
    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    bool isProcessing = _togglingCommentLikeIds.contains(comment.id);

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
              ? context.colors.pinkStart
              : context.colors.textSecondary,
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
        color: context.colors.pinkSoft,
      ),
      child: imageUrl.isEmpty
          ? Icon(
        Icons.person_rounded,
        size: 20,
        color: context.colors.pinkStart,
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
              color: context.colors.pinkStart,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: context.colors.softBlue,
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
                      color: context.colors.textPrimary,
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
                      color: context.colors.textSecondary,
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
              child: Stack(
                children: [
                  TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    enabled: !_isSubmittingComment,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: _replyToCommentId.isEmpty
                          ? '댓글을 입력해 주세요.'
                          : '답글을 입력해 주세요.',
                      counterText: '',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      contentPadding: const EdgeInsets.fromLTRB(13, 11, 54, 28),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(color: context.colors.pinkSoft),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(color: context.colors.pinkSoft),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(color: context.colors.pinkStart),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 11,
                    bottom: 8,
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _commentController,
                      builder: (context, value, child) {
                        return Text(
                          '${value.text.length}/500',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: FilledButton(
                onPressed: _isSubmittingComment ? null : _submitComment,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: context.colors.pinkStart,
                  foregroundColor: context.colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: _isSubmittingComment
                    ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.onPrimary,
                  ),
                )
                    : const Icon(Icons.send_rounded, size: 20),
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
          backgroundColor: context.colors.pinkSoft,
        ),
        if (post.boardType == CommunityBoardType.question) ...[
          const SizedBox(width: 7),
          _DetailBadge(
            label: _questionStatusLabel(post.questionStatus),
            backgroundColor: context.colors.softBlue,
          ),
        ],
        if (post.boardType == CommunityBoardType.groupRecruit) ...[
          const SizedBox(width: 7),
          _DetailBadge(
            label: _recruitStatusLabel(post.recruitStatus),
            backgroundColor: context.colors.mint,
          ),
        ],
        const Spacer(),
        if (post.hasAttachment)
          Icon(
            Icons.attach_file_rounded,
            size: 19,
            color: context.colors.textSecondary,
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
                PopupMenuItem<String>(value: 'EDIT', child: Text('수정')),
                PopupMenuItem<String>(value: 'DELETE', child: Text('삭제')),
              ];
            },
            icon: _isDeleting
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Icon(
              Icons.more_vert_rounded,
              color: context.colors.textSecondary,
            ),
          ),
        if (!_isWriter(post) && FirebaseAuth.instance.currentUser != null)
          IconButton(
            tooltip: '게시글 신고',
            onPressed: _isReporting
                ? null
                : () {
              _showPostReportModal(post);
            },
            icon: _isReporting
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.incorrect,
              ),
            )
                : Icon(Icons.report_outlined, color: context.colors.incorrect),
          ),
      ],
    );
  }

  Widget _buildWriterArea(CommunityPost post) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileForUid(post.writerUid),
      builder: (context, snapshot) {
        Map<String, dynamic> profile = snapshot.data ?? {};

        String nickname = profile['nickname']?.toString().trim() ?? '';
        String profileImageUrl =
            profile['profileImageUrl']?.toString().trim() ?? '';

        if (nickname.isEmpty || nickname == '사용자') {
          nickname = post.writerNickname;
        }

        if (profileImageUrl.isEmpty) {
          profileImageUrl = post.writerProfileImageUrl;
        }

        return Row(
          children: [
            _buildProfileImage(profileImageUrl),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textPrimary,
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
                          color: context.colors.pinkStart,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCreatedAt(post.createdAt),
                    style: TextStyle(
                      color: context.colors.textSecondary,
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
        color: context.colors.pinkSoft,
      ),
      child: imageUrl.isEmpty
          ? Icon(Icons.person_rounded, color: context.colors.pinkStart)
          : ClipOval(
        child: Image.network(
          imageUrl,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.person_rounded,
              color: context.colors.pinkStart,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCertificateTags(List<CommunityCertificateTag> tags) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: context.colors.lavender,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '#${tag.certificateName}',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImages(List<CommunityImageAttachment> images) {
    return Column(
      children: images.asMap().entries.map((entry) {
        int index = entry.key;
        CommunityImageAttachment image = entry.value;
        String key = image.path.isNotEmpty ? image.path : image.url;
        bool isDownloading = _downloadingAttachmentKeys.contains(key);
        double? progress = _downloadProgress[key];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: image.url.isEmpty
                      ? null
                      : () {
                    _showImageViewer(images, index);
                  },
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
                        color: context.colors.pinkSoft,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: context.colors.textSecondary,
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Row(
                    children: [
                      _buildImageOverlayButton(
                        tooltip: '이미지 다운로드',
                        icon: Icons.download_rounded,
                        isLoading: isDownloading,
                        progress: progress,
                        onPressed: image.url.isEmpty || isDownloading
                            ? null
                            : () {
                          _downloadAttachment(
                            url: image.url,
                            fileName: _imageDownloadName(image, index),
                            key: key,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildImageOverlayButton(
                        tooltip: '이미지 크게 보기',
                        icon: Icons.open_in_full_rounded,
                        onPressed: image.url.isEmpty
                            ? null
                            : () {
                          _showImageViewer(images, index);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageOverlayButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isLoading = false,
    double? progress,
  }) {
    return Material(
      color: Colors.black.withOpacity(0.58),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        padding: EdgeInsets.zero,
        icon: isLoading
            ? SizedBox(
          width: 19,
          height: 19,
          child: CircularProgressIndicator(
            value: progress != null && progress > 0 ? progress : null,
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }

  Widget _buildFiles(List<CommunityFileAttachment> files) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '첨부파일',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        ...files.map((file) {
          String key = file.path.isNotEmpty ? file.path : file.url;
          bool isOpening = _openingFilePaths.contains(key);
          bool isDownloading = _downloadingAttachmentKeys.contains(key);
          double? progress = _downloadProgress[key];

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: context.colors.softBlue,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isOpening || file.url.isEmpty
                    ? null
                    : () {
                  _openFileAttachment(file);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 8, 5, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        size: 20,
                        color: context.colors.pinkStart,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.colors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              file.url.isEmpty
                                  ? '파일 주소 없음'
                                  : '파일명을 누르면 열려요.',
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '파일 다운로드',
                        onPressed: file.url.isEmpty || isDownloading
                            ? null
                            : () {
                          _downloadAttachment(
                            url: file.url,
                            fileName: file.name,
                            key: key,
                          );
                        },
                        icon: isDownloading
                            ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            value: progress != null && progress > 0
                                ? progress
                                : null,
                            strokeWidth: 2,
                            color: context.colors.pinkStart,
                          ),
                        )
                            : const Icon(Icons.download_rounded, size: 20),
                      ),
                      IconButton(
                        tooltip: '파일 열기',
                        onPressed: file.url.isEmpty || isOpening
                            ? null
                            : () {
                          _openFileAttachment(file);
                        },
                        icon: isOpening
                            ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.pinkStart,
                          ),
                        )
                            : const Icon(Icons.open_in_new_rounded, size: 19),
                      ),
                    ],
                  ),
                ),
              ),
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

  const _DetailBadge({required this.label, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.colors.textPrimary,
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
        ? context.colors.pinkStart
        : context.colors.textSecondary;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(height: 4),
            Text(
              '$label $value',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
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

class _CommentEditDialog extends StatefulWidget {
  final String initialContent;

  const _CommentEditDialog({
    required this.initialContent,
  });

  @override
  State<_CommentEditDialog> createState() {
    return _CommentEditDialogState();
  }
}

class _CommentEditDialogState extends State<_CommentEditDialog> {
  late final TextEditingController _controller;

  static const int _maxLength = 500;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.initialContent,
    );

    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    String content = _controller.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 내용을 입력해 주세요.')),
      );
      return;
    }

    Navigator.pop(context, content);
  }

  @override
  Widget build(BuildContext context) {
    bool canSave = _controller.text.trim().isNotEmpty;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 24,
      ),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      title: Text(
        '댓글 수정',
        style: TextStyle(
          color: context.colors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 180,
        child: Stack(
          children: [
            Positioned.fill(
              child: TextField(
                controller: _controller,
                autofocus: true,
                expands: true,
                minLines: null,
                maxLines: null,
                maxLength: _maxLength,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: '댓글 내용을 입력해 주세요.',
                  hintStyle: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 14,
                  ),
                  counterText: '',
                  contentPadding: const EdgeInsets.fromLTRB(
                    15,
                    15,
                    15,
                    38,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.colors.pinkSoft,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.colors.pinkSoft,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.colors.pinkStart,
                      width: 1.4,
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),
            Positioned(
              right: 13,
              bottom: 11,
              child: Text(
                '${_controller.text.length}/$_maxLength',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: canSave ? _save : null,
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.pinkStart,
            foregroundColor: context.colors.onPrimary,
          ),
          child: const Text('수정'),
        ),
      ],
    );
  }
}

class _CommunityImageViewer extends StatefulWidget {
  final List<CommunityImageAttachment> images;
  final int initialIndex;

  const _CommunityImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_CommunityImageViewer> createState() {
    return _CommunityImageViewerState();
  }
}

class _CommunityImageViewerState extends State<_CommunityImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      widget.images[index].url,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }

                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white70,
                              size: 45,
                            ),
                            SizedBox(height: 10),
                            Text(
                              '이미지를 불러오지 못했어요.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                tooltip: '닫기',
                onPressed: () {
                  Navigator.pop(context);
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.48),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.48),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
