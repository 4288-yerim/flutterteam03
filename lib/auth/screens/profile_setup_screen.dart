import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';
import '../widgets/step_indicator.dart';

class ProfileSetupScreen extends StatefulWidget {
  final void Function(
    BuildContext context, {
    required String nickname,
    String? bio,
    File? profileImageFile,
  })
  onNext;

  const ProfileSetupScreen({super.key, required this.onNext});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  File? _pickedImage;
  String? _errorText;

  static const int _minLength = 2;
  static const int _maxLength = 10;
  static const int _bioMaxLength = 60;
  static final RegExp _nicknameRegExp = RegExp(r'^[가-힣a-zA-Z0-9]+$');

  @override
  void initState() {
    super.initState();
    // 닉네임이 바뀔 때마다 버튼 활성화 여부를 다시 계산하기 위해 리빌드
    _nicknameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _pickedImage = File(picked.path));
  }

  String? _validateNickname(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '닉네임을 입력해주세요';
    if (trimmed.length < _minLength || trimmed.length > _maxLength) {
      return '닉네임은 $_minLength~$_maxLength자로 입력해주세요';
    }
    if (!_nicknameRegExp.hasMatch(trimmed)) {
      return '한글, 영문, 숫자만 사용할 수 있어요';
    }
    return null;
  }

  // 버튼 활성화 조건: 닉네임이 유효할 때만 (에러 텍스트 표시 여부와 별개로 실시간 판단)
  bool get _canProceed => _validateNickname(_nicknameController.text) == null;

  void _handleNext() {
    final nickname = _nicknameController.text.trim();
    final error = _validateNickname(nickname);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }

    widget.onNext(
      context,
      nickname: nickname,
      bio: _bioController.text.trim().isEmpty
          ? null
          : _bioController.text.trim(),
      profileImageFile: _pickedImage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                StepIndicator(
                  currentStep: 2,
                  label: '2단계 · 프로필 설정',
                  colors: colors,
                ),
                const SizedBox(height: 20),
                Text(
                  '프로필을 설정해주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '닉네임은 필수이고, 프로필 사진은 나중에 등록할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: colors.pinkStart.withOpacity(0.10),
                        backgroundImage: _pickedImage != null
                            ? FileImage(_pickedImage!)
                            : null,
                        child: _pickedImage == null
                            ? Icon(
                                Icons.person_rounded,
                                size: 44,
                                color: colors.pinkStart,
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: colors.pinkStart,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.colors.onPrimary,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 15,
                            color: context.colors.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '닉네임',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nicknameController,
                  maxLength: _maxLength,
                  decoration: InputDecoration(
                    hintText: '2~10자, 한글/영문/숫자로 입력해주세요',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: colors.textSecondary.withOpacity(0.55),
                    ),
                    errorText: _errorText,
                    filled: true,
                    fillColor: colors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colors.textSecondary.withOpacity(0.2),
                        width: 1.2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colors.textSecondary.withOpacity(0.2),
                        width: 1.2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.pinkStart, width: 2),
                    ),
                  ),
                  onChanged: (_) {
                    if (_errorText != null) setState(() => _errorText = null);
                  },
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '자기소개',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '선택 사항이에요',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioController,
                  maxLength: _bioMaxLength,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '나를 간단히 소개해주세요 (선택)',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: colors.textSecondary.withOpacity(0.55),
                    ),
                    filled: true,
                    fillColor: colors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colors.textSecondary.withOpacity(0.2),
                        width: 1.2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colors.textSecondary.withOpacity(0.2),
                        width: 1.2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.pinkStart, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                AppButton(
                  text: '다음',
                  type: _canProceed
                      ? AppButtonType.primaryPink
                      : AppButtonType.gray,
                  onPressed: _canProceed ? _handleNext : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
