import 'package:flutter/material.dart';

import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  State<PasswordChangeScreen> createState() =>
      _PasswordChangeScreenState();
}

class _PasswordChangeScreenState
    extends State<PasswordChangeScreen> {
  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  final TextEditingController _currentPasswordController =
  TextEditingController();

  final TextEditingController _newPasswordController =
  TextEditingController();

  final TextEditingController _confirmPasswordController =
  TextEditingController();

  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppTopBar(
        title: '비밀번호 변경',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            110,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                const _PasswordGuideCard(),

                const SizedBox(height: 24),

                const Text(
                  '현재 비밀번호',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                  _currentPasswordController,
                  obscureText: _hideCurrentPassword,
                  textInputAction:
                  TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.password,
                  ],
                  decoration: _buildInputDecoration(
                    hintText: '현재 비밀번호를 입력하세요.',
                    isHidden: _hideCurrentPassword,
                    onVisibilityPressed: () {
                      setState(() {
                        _hideCurrentPassword =
                        !_hideCurrentPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    final password = value?.trim() ?? '';

                    if (password.isEmpty) {
                      return '현재 비밀번호를 입력해 주세요.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

                const Text(
                  '새 비밀번호',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _hideNewPassword,
                  textInputAction:
                  TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.newPassword,
                  ],
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: _buildInputDecoration(
                    hintText: '새 비밀번호를 입력하세요.',
                    isHidden: _hideNewPassword,
                    onVisibilityPressed: () {
                      setState(() {
                        _hideNewPassword =
                        !_hideNewPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    final password = value ?? '';

                    if (password.isEmpty) {
                      return '새 비밀번호를 입력해 주세요.';
                    }

                    if (password.length < 8) {
                      return '비밀번호는 8자 이상 입력해 주세요.';
                    }

                    if (!_containsLetter(password)) {
                      return '영문자를 1자 이상 포함해 주세요.';
                    }

                    if (!_containsNumber(password)) {
                      return '숫자를 1자 이상 포함해 주세요.';
                    }

                    if (!_containsSpecialCharacter(
                      password,
                    )) {
                      return '특수문자를 1자 이상 포함해 주세요.';
                    }

                    if (password ==
                        _currentPasswordController.text) {
                      return '현재 비밀번호와 다른 비밀번호를 입력해 주세요.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                _PasswordConditionList(
                  password:
                  _newPasswordController.text,
                ),

                const SizedBox(height: 20),

                const Text(
                  '새 비밀번호 확인',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                  _confirmPasswordController,
                  obscureText: _hideConfirmPassword,
                  textInputAction:
                  TextInputAction.done,
                  autofillHints: const [
                    AutofillHints.newPassword,
                  ],
                  decoration: _buildInputDecoration(
                    hintText: '새 비밀번호를 다시 입력하세요.',
                    isHidden: _hideConfirmPassword,
                    onVisibilityPressed: () {
                      setState(() {
                        _hideConfirmPassword =
                        !_hideConfirmPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    final confirmPassword =
                        value ?? '';

                    if (confirmPassword.isEmpty) {
                      return '새 비밀번호를 다시 입력해 주세요.';
                    }

                    if (confirmPassword !=
                        _newPasswordController.text) {
                      return '새 비밀번호가 일치하지 않습니다.';
                    }

                    return null;
                  },
                  onFieldSubmitted: (_) {
                    _changePassword();
                  },
                ),

                const SizedBox(height: 28),

                AppButton(
                  text: _isSubmitting
                      ? '변경 중...'
                      : '비밀번호 변경',
                  onPressed: _isSubmitting
                      ? null
                      : _changePassword,
                ),

                const SizedBox(height: 16),

                const Text(
                  '현재 화면은 Firebase Authentication 연결 전 테스트용입니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
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

  InputDecoration _buildInputDecoration({
    required String hintText,
    required bool isHidden,
    required VoidCallback onVisibilityPressed,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFFB4B8C2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFFE5E7EC),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFFF0788F),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFFE85D75),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFFE85D75),
          width: 1.5,
        ),
      ),
      suffixIcon: IconButton(
        tooltip: isHidden
            ? '비밀번호 표시'
            : '비밀번호 숨기기',
        onPressed: onVisibilityPressed,
        icon: Icon(
          isHidden
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: const Color(0xFF9AA0AC),
        ),
      ),
    );
  }

  bool _containsLetter(String password) {
    return RegExp(r'[A-Za-z]').hasMatch(password);
  }

  bool _containsNumber(String password) {
    return RegExp(r'[0-9]').hasMatch(password);
  }

  bool _containsSpecialCharacter(
      String password,
      ) {
    return RegExp(
      r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\];`~]',
    ).hasMatch(password);
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();

    final isValid =
        _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Firebase 연결 전 임시 처리
    await Future<void>.delayed(
      const Duration(milliseconds: 500),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '변경 완료',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            '비밀번호가 변경된 것으로 임시 처리했습니다.\n'
                'Firebase 연결 후 실제 변경 기능이 적용됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text(
                '확인',
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

class _PasswordGuideCard extends StatelessWidget {
  const _PasswordGuideCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFCEFF3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.lock_reset_outlined,
              color: Color(0xFFF0788F),
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '안전한 비밀번호를 사용해 주세요.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '기존 비밀번호와 다르게 설정하고, 다른 서비스에서 사용하는 비밀번호는 피하는 것이 좋습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF666A73),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordConditionList extends StatelessWidget {
  final String password;

  const _PasswordConditionList({
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PasswordCondition(
          text: '8자 이상',
          isSatisfied: password.length >= 8,
        ),
        const SizedBox(height: 6),
        _PasswordCondition(
          text: '영문자 포함',
          isSatisfied:
          RegExp(r'[A-Za-z]').hasMatch(password),
        ),
        const SizedBox(height: 6),
        _PasswordCondition(
          text: '숫자 포함',
          isSatisfied:
          RegExp(r'[0-9]').hasMatch(password),
        ),
        const SizedBox(height: 6),
        _PasswordCondition(
          text: '특수문자 포함',
          isSatisfied: RegExp(
            r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\];`~]',
          ).hasMatch(password),
        ),
      ],
    );
  }
}

class _PasswordCondition extends StatelessWidget {
  final String text;
  final bool isSatisfied;

  const _PasswordCondition({
    required this.text,
    required this.isSatisfied,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isSatisfied
              ? Icons.check_circle
              : Icons.radio_button_unchecked,
          size: 17,
          color: isSatisfied
              ? const Color(0xFF4C9A65)
              : const Color(0xFFB4B8C2),
        ),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isSatisfied
                ? const Color(0xFF4C9A65)
                : const Color(0xFF9AA0AC),
          ),
        ),
      ],
    );
  }
}