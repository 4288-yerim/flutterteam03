import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'community_models.dart';
import 'community_service.dart';

extension _CommunityAddColors on BuildContext {
  AppColors get communityColors {
    return Theme.of(this).extension<AppColors>() ?? AppColors.light;
  }
}

class CommunityPostAddPage extends StatefulWidget {
  final CommunityService? service;

  const CommunityPostAddPage({
    super.key,
    this.service,
  });

  @override
  State<CommunityPostAddPage> createState() {
    return _CommunityPostAddPageState();
  }
}

class _CommunityPostAddPageState
    extends State<CommunityPostAddPage> {
  late final CommunityService _service;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  CommunityBoardType _selectedBoard = CommunityBoardType.free;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CommunityService();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _savePost() async {
    if (_isSaving) {
      return;
    }

    bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 후 게시글을 작성할 수 있어요.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    String nickname = user.displayName?.trim() ?? '';

    if (nickname.isEmpty) {
      String email = user.email?.trim() ?? '';

      if (email.contains('@')) {
        nickname = email.split('@').first;
      } else {
        nickname = '사용자';
      }
    }

    try {
      String postId = await _service.addPost(
        boardType: _selectedBoard,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        writerUid: user.uid,
        writerNickname: nickname,
        writerProfileImageUrl: user.photoURL ?? '',
        isCertifiedWriter: false,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, postId);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시글을 저장하지 못했어요. 다시 시도해 주세요.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppTopBar(
        title: '게시글 작성',
      ),
      body: AppMainBackground(
        child: Padding(
          padding: const EdgeInsets.only(top: kToolbarHeight),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
              children: [
                _buildGuideCard(),
                const SizedBox(height: 16),
                _buildPostForm(),
                const SizedBox(height: 20),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: context.communityColors.pinkSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.edit_note_rounded,
            color: context.communityColors.pinkStart,
            size: 25,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              '게시판을 선택하고 함께 나누고 싶은 내용을 작성해 주세요.',
              style: TextStyle(
                color: context.communityColors.textPrimary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostForm() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldTitle('게시판'),
          const SizedBox(height: 9),
          DropdownButtonFormField<CommunityBoardType>(
            value: _selectedBoard,
            isExpanded: true,
            decoration: _inputDecoration(
              hintText: '게시판을 선택해 주세요.',
            ),
            items: CommunityBoardType.values
                .where((board) => board != CommunityBoardType.all)
                .map((board) {
              return DropdownMenuItem<CommunityBoardType>(
                value: board,
                child: Text(board.label),
              );
            }).toList(),
            onChanged: _isSaving
                ? null
                : (board) {
              if (board == null) {
                return;
              }

              setState(() {
                _selectedBoard = board;
              });
            },
          ),
          const SizedBox(height: 20),
          _buildFieldTitle('제목'),
          const SizedBox(height: 9),
          TextFormField(
            controller: _titleController,
            enabled: !_isSaving,
            maxLength: 60,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hintText: '제목을 입력해 주세요.',
            ),
            validator: (value) {
              String title = value?.trim() ?? '';

              if (title.isEmpty) {
                return '제목을 입력해 주세요.';
              }

              if (title.length < 2) {
                return '제목을 2자 이상 입력해 주세요.';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildFieldTitle('내용'),
          const SizedBox(height: 9),
          TextFormField(
            controller: _contentController,
            enabled: !_isSaving,
            minLines: 10,
            maxLines: 16,
            maxLength: 3000,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: _inputDecoration(
              hintText: '내용을 입력해 주세요.',
            ),
            validator: (value) {
              String content = value?.trim() ?? '';

              if (content.isEmpty) {
                return '내용을 입력해 주세요.';
              }

              if (content.length < 5) {
                return '내용을 5자 이상 입력해 주세요.';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFieldTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: context.communityColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: context.communityColors.textSecondary,
        fontSize: 13,
      ),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: context.communityColors.pinkSoft,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: context.communityColors.pinkSoft,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: context.communityColors.pinkStart,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: _isSaving ? null : _savePost,
        style: FilledButton.styleFrom(
          backgroundColor: context.communityColors.pinkStart,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
          context.communityColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.3,
            color: Colors.white,
          ),
        )
            : const Text(
          '게시글 등록',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
