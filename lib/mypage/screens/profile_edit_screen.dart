import 'package:flutter/material.dart';

import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() =>
      _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  final TextEditingController _loginIdController =
  TextEditingController(
    text: 'user_id',
  );

  final TextEditingController _nicknameController =
  TextEditingController(
    text: '사용자 닉네임',
  );

  final TextEditingController _phoneController =
  TextEditingController(
    text: '01012345678',
  );

  final TextEditingController _introductionController =
  TextEditingController(
    text: '자격증 공부 중입니다.',
  );

  bool _isSaving = false;

  @override
  void dispose() {
    _loginIdController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    _introductionController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppTopBar(
        title: '내 정보 관리',
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              100,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                _buildProfileImageSection(),
                const SizedBox(height: 20),

                _buildAccountInfoCard(),
                const SizedBox(height: 20),

                _buildIntroductionCard(),
                const SizedBox(height: 28),

                AppButton(
                  text: _isSaving
                      ? '저장 중...'
                      : '변경사항 저장',
                  type: _isSaving
                      ? AppButtonType.gray
                      : AppButtonType.primaryPink,
                  onPressed:
                  _isSaving ? null : _saveProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFCE1E8),
                ),
                child: const Icon(
                  Icons.person,
                  size: 56,
                  color: Color(0xFFF0788F),
                ),
              ),

              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _changeProfileImage,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF0788F),
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _changeProfileImage,
            child: const Text(
              '프로필 사진 변경',
              style: TextStyle(
                color: Color(0xFFF0788F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            '계정 정보',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 20),

          _buildLabel('아이디'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _loginIdController,
            readOnly: true,
            decoration: _inputDecoration(
              hintText: '아이디',
              prefixIcon: Icons.person_outline,
              isReadOnly: true,
            ),
          ),
          const SizedBox(height: 18),

          _buildLabel('닉네임'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nicknameController,
            maxLength: 12,
            decoration: _inputDecoration(
              hintText: '닉네임을 입력해 주세요.',
              prefixIcon: Icons.badge_outlined,
            ),
            validator: (value) {
              final String nickname =
                  value?.trim() ?? '';

              if (nickname.isEmpty) {
                return '닉네임을 입력해 주세요.';
              }

              if (nickname.length < 2) {
                return '닉네임은 2자 이상 입력해 주세요.';
              }

              return null;
            },
          ),
          const SizedBox(height: 18),

          _buildLabel('전화번호'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            keyboardType:
            TextInputType.phone,
            decoration: _inputDecoration(
              hintText: '전화번호를 입력해 주세요.',
              prefixIcon: Icons.phone_outlined,
              suffixIcon: TextButton(
                onPressed: () {
                  _showTemporaryMessage(
                    '전화번호 인증 기능은 추후 연결합니다.',
                  );
                },
                child: const Text(
                  '인증',
                  style: TextStyle(
                    color: Color(0xFFF0788F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            validator: (value) {
              final String phone =
                  value?.replaceAll('-', '') ?? '';

              if (phone.isEmpty) {
                return '전화번호를 입력해 주세요.';
              }

              if (phone.length < 10) {
                return '올바른 전화번호를 입력해 주세요.';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIntroductionCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            '자기소개',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '다른 사용자에게 표시될 간단한 소개를 작성해 주세요.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9AA0AC),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller:
            _introductionController,
            minLines: 4,
            maxLines: 6,
            maxLength: 100,
            keyboardType:
            TextInputType.multiline,
            decoration: _inputDecoration(
              hintText: '자기소개를 입력해 주세요.',
              prefixIcon: null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF4A4A4A),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool isReadOnly = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: isReadOnly
          ? const Color(0xFFF5F5F7)
          : Colors.white,
      prefixIcon: prefixIcon == null
          ? null
          : Icon(
        prefixIcon,
        color: const Color(0xFF9AA0AC),
      ),
      suffixIcon: suffixIcon,
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE8E8EC),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE8E8EC),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFF0788F),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
      focusedErrorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }

  void _changeProfileImage() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.all(20),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                    const Color(0xFFE2E2E6),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),

                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFFF0788F),
                  ),
                  title: const Text(
                    '앨범에서 선택',
                  ),
                  onTap: () {
                    Navigator.pop(
                      bottomSheetContext,
                    );

                    _showTemporaryMessage(
                      '이미지 선택 기능은 추후 연결합니다.',
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  title: const Text(
                    '기본 이미지로 변경',
                  ),
                  onTap: () {
                    Navigator.pop(
                      bottomSheetContext,
                    );

                    _showTemporaryMessage(
                      '기본 이미지로 변경했습니다.',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    final bool isValid =
        _formKey.currentState?.validate() ??
            false;

    if (!isValid) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await Future<void>.delayed(
        const Duration(seconds: 1),
      );

      // 나중에 Firestore 연결
      //
      // final uid =
      //     FirebaseAuth.instance.currentUser!.uid;
      //
      // await FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(uid)
      //     .update({
      //   'nickname':
      //       _nicknameController.text.trim(),
      //   'phone':
      //       _phoneController.text.trim(),
      //   'introduction':
      //       _introductionController.text.trim(),
      //   'updatedAt':
      //       FieldValue.serverTimestamp(),
      // });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '회원 정보가 저장되었습니다.',
          ),
        ),
      );

      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showTemporaryMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}