import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../main_page.dart';
import '../../theme.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  // 서버(Firebase)에서 내려온 에러는 필드별로 따로 보관해두고,
  // 사용자가 해당 필드를 다시 수정하면 자동으로 지워집니다.
  String? _emailServerError;
  String? _passwordServerError;

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  static final _emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_onPasswordChanged);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

    _entryController.forward();
  }

  void _onEmailChanged() {
    if (_emailServerError != null) _emailServerError = null;
    setState(() {});
  }

  void _onPasswordChanged() {
    if (_passwordServerError != null) _passwordServerError = null;
    setState(() {});
  }

  String? get _emailFormatError {
    final text = _emailController.text.trim();
    if (text.isEmpty) return null;
    return _emailRegex.hasMatch(text) ? null : '이메일 형식에 맞게 입력해주세요.';
  }

  String? get _passwordFormatError {
    final text = _passwordController.text;
    if (text.isEmpty) return null;
    return text.length >= 8 ? null : '8자 이상 입력해주세요.';
  }

  String? get _emailDisplayError => _emailServerError ?? _emailFormatError;
  String? get _passwordDisplayError => _passwordServerError ?? _passwordFormatError;

  bool get _isFormValid =>
      _emailController.text.trim().isNotEmpty &&
          _passwordController.text.isNotEmpty &&
          _emailFormatError == null &&
          _passwordFormatError == null;

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _passwordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 추가: 마지막 로그인 시각 갱신
      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .update({'updatedAt': FieldValue.serverTimestamp()});

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String modalMessage = e.message ?? '이메일 또는 비밀번호를 확인해주세요.';
      switch (e.code) {
        case 'user-not-found':
          modalMessage = '가입 이력이 없습니다.';
          break;
        case 'wrong-password':
          modalMessage = '비밀번호가 옳지 않습니다.';
          break;
        case 'invalid-email':
          modalMessage = '이메일 형식에 맞게 입력해주세요.';
          break;
        case 'invalid-credential':
          modalMessage = '이메일 또는 비밀번호가 올바르지 않습니다.';
          break;
      }
      setState(() {
        if (e.code == 'user-not-found') _emailServerError = modalMessage;
        if (e.code == 'invalid-email') _emailServerError = modalMessage;
        if (e.code == 'wrong-password') _passwordServerError = modalMessage;
      });
      _showLoginFailedModal(modalMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLoginFailedModal(String message) {
    final colors = Theme.of(context).extension<AppColors>()!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 28, 24, 32),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '로그인 실패',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: 10),
              Text(
                message,
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
              SizedBox(height: 24),
              AppButton(
                text: '확인',
                type: AppButtonType.primaryPink,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        );
      },
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
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          AppBackground(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '로그인',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '따자에 오신 걸 환영해요!',
                                style: TextStyle(fontSize: 14, color: colors.textSecondary),
                              ),
                              SizedBox(height: 40),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: '이메일',
                                  hintText: 'example@gmail.com',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(16)),
                                  ),
                                  suffixIcon: _emailController.text.isEmpty
                                      ? null
                                      : IconButton(
                                    icon: Icon(Icons.close, color: colors.textSecondary),
                                    onPressed: () => _emailController.clear(),
                                  ),
                                ),
                              ),
                              if (_emailDisplayError != null) ...[
                                SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _emailDisplayError!,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox(height: 14),
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                obscuringCharacter: '●',
                                decoration: InputDecoration(
                                  labelText: '비밀번호',
                                  hintText: '8자 이상 비밀번호',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(16)),
                                  ),
                                  suffixIcon: _passwordController.text.isEmpty
                                      ? null
                                      : IconButton(
                                    icon: Icon(Icons.close, color: colors.textSecondary),
                                    onPressed: () => _passwordController.clear(),
                                  ),
                                ),
                              ),
                              if (_passwordDisplayError != null) ...[
                                SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _passwordDisplayError!,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox(height: 28),
                              AppButton(
                                text: '로그인',
                                type: _isFormValid
                                    ? AppButtonType.primaryPink
                                    : AppButtonType.gray,
                                onPressed: (_isFormValid && !_isLoading) ? _login : null,
                              ),
                              SizedBox(height: 20),
                              Center(
                                child: GestureDetector(
                                  onTap: _isLoading
                                      ? null
                                      : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ResetPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    '비밀번호를 잊으셨나요?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 60),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: colors.textPrimary.withOpacity(0.12),
                child: Center(
                  child: CircularProgressIndicator(color: colors.pinkStart),
                ),
              ),
            ),
        ],
      ),
    );
  }
}