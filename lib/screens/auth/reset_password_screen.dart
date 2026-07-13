import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';

class ResetPasswordScreen extends StatefulWidget {
  ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isFormValid = false;
  String? _errorText;
  String? _successText;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_updateFormValid);
  }

  void _updateFormValid() {
    final isValid = _emailController.text.trim().isNotEmpty;
    if (isValid != _isFormValid) {
      setState(() => _isFormValid = isValid);
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_updateFormValid);
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
      _successText = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _successText = '비밀번호 재설정 메일을 보냈어요. 메일함을 확인해주세요.');
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = e.message ?? '비밀번호 재설정에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 60),
              Text(
                '비밀번호 재설정',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '가입하신 이메일로 재설정 링크를 보내드릴게요',
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
              SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: '이메일',
                  hintText: 'example@gmail.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              if (_errorText != null) ...[
                SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ],
              if (_successText != null) ...[
                SizedBox(height: 10),
                Text(
                  _successText!,
                  style: TextStyle(
                    color: colors.pinkStart,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              SizedBox(height: 24),
              AppButton(
                text: _isLoading ? '전송 중...' : '재설정 메일 보내기',
                type: _isFormValid
                    ? AppButtonType.primaryPink
                    : AppButtonType.gray,
                onPressed: (_isFormValid && !_isLoading) ? _resetPassword : null,
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}