import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';
import '../main_navigation_shell.dart';

enum _PasswordStrength { none, weak, medium, strong }

class SignupScreen extends StatefulWidget {
  SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isLoading = false;

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
    _passwordConfirmController.addListener(() => setState(() {}));

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

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _passwordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _entryController.dispose();
    super.dispose();
  }


  String? get _emailFormatError {
    final text = _emailController.text.trim();
    if (text.isEmpty) return null;
    return _emailRegex.hasMatch(text) ? null : '이메일 형식에 맞게 입력해주세요.';
  }

  String? get _emailDisplayError => _emailServerError ?? _emailFormatError;

  int get _passwordScore {
    final pw = _passwordController.text;
    if (pw.isEmpty) return 0;
    var score = 0;
    if (pw.length >= 8) score++;
    if (pw.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) score++;
    if (RegExp(r'[a-z]').hasMatch(pw)) score++;
    if (RegExp(r'[0-9]').hasMatch(pw)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=~`\[\]/;]').hasMatch(pw)) score++;
    return score;
  }

  _PasswordStrength get _passwordStrength {
    final pw = _passwordController.text;
    if (pw.isEmpty) return _PasswordStrength.none;
    if (pw.length < 8) return _PasswordStrength.weak;
    final score = _passwordScore;
    if (score >= 5) return _PasswordStrength.strong;
    if (score >= 3) return _PasswordStrength.medium;
    return _PasswordStrength.weak;
  }

  bool get _isPasswordValid => _passwordController.text.length >= 8;

  String? get _passwordLengthError {
    final pw = _passwordController.text;
    if (pw.isEmpty) return null;
    if (pw.length < 8) return '8자 이상 입력해주세요.';
    return null;
  }

  String? get _passwordDisplayError => _passwordServerError ?? _passwordLengthError;
  String? get _confirmError {
    final confirm = _passwordConfirmController.text;
    if (confirm.isEmpty) return null;
    return confirm == _passwordController.text ? null : '비밀번호가 일치하지 않습니다.';
  }

  bool get _isFormValid =>
      _emailController.text.trim().isNotEmpty &&
          _emailFormatError == null &&
          _isPasswordValid &&
          _passwordConfirmController.text.isNotEmpty &&
          _confirmError == null;


  Future<void> _signup() async {
    FirebaseFirestore fs = FirebaseFirestore.instance;
    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await fs.collection('users').add({
        'uid': credential.user?.uid,
        'email': _emailController.text.trim(),
        'loginProvider': 'PASSWORD',
        'role': 'USER',
        'status': 'ACTIVE',
        'loginFailCount': 0,
        'reportCount': 0,
        // 'termsAgreed': _termsAgreed,
        // 'privacyAgreed': _privacyAgreed,
        // 'marketingAgreed': _marketingAgreed,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainNavigationShell()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String modalMessage = '회원가입에 실패했습니다.';
      switch (e.code) {
        case 'email-already-in-use':
          modalMessage = '이미 가입된 이메일입니다.';
          break;
        case 'invalid-email':
          modalMessage = '이메일 형식에 맞게 입력해주세요.';
          break;
        case 'weak-password':
          modalMessage = '비밀번호가 너무 약합니다.';
          break;
        case 'operation-not-allowed':
          modalMessage = '이메일/비밀번호 회원가입이 아직 활성화되지 않았습니다.\nFirebase 콘솔에서 로그인 방법을 확인해주세요.';
          break;
        case 'network-request-failed':
          modalMessage = '네트워크 연결을 확인해주세요.';
          break;
      }

      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
          case 'invalid-email':
            _emailServerError = modalMessage;
            break;
          case 'weak-password':
            _passwordServerError = modalMessage;
            break;
        }
      });
      _showSignupFailedModal(modalMessage);
    } catch (_) {
      if (!mounted) return;
      _showSignupFailedModal('회원가입에 실패했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSignupFailedModal(String message) {
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
                '회원가입 실패',
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

  InputBorder _border(Color color, {double width = 1.2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  InputDecoration _decoration({
    required AppColors colors,
    required Color errorColor,
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: _border(colors.textSecondary.withOpacity(0.3)),
      enabledBorder: _border(colors.textSecondary.withOpacity(0.3)),
      focusedBorder: _border(colors.pinkStart, width: 2),
      errorBorder: _border(errorColor),
      focusedErrorBorder: _border(errorColor, width: 2),
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
        icon: Icon(Icons.close, color: colors.textSecondary),
        onPressed: () => controller.clear(),
      ),
    );
  }

  Widget _strengthMeter(AppColors colors, Color errorColor) {
    final strength = _passwordStrength;
    if (strength == _PasswordStrength.none) return const SizedBox.shrink();

    late final Color activeColor;
    late final String label;
    late final int filledBars;

    switch (strength) {
      case _PasswordStrength.weak:
        activeColor = errorColor;
        label = '약함';
        filledBars = 1;
        break;
      case _PasswordStrength.medium:
        activeColor = colors.textPrimary;
        label = '보통';
        filledBars = 2;
        break;
      case _PasswordStrength.strong:
        activeColor = colors.pinkStart;
        label = '강함';
        filledBars = 3;
        break;
      case _PasswordStrength.none:
        activeColor = colors.textSecondary;
        label = '';
        filledBars = 0;
        break;
    }

    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < filledBars ? activeColor : colors.textSecondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: activeColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final errorColor = Theme.of(context).colorScheme.error;

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
                                '회원가입',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '이메일로 계정을 만들어보세요',
                                style: TextStyle(fontSize: 14, color: colors.textSecondary),
                              ),
                              SizedBox(height: 40),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _decoration(
                                  colors: colors,
                                  errorColor: errorColor,
                                  label: '이메일',
                                  hint: 'example@gmail.com',
                                  controller: _emailController,
                                ),
                              ),
                              if (_emailDisplayError != null) ...[
                                SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _emailDisplayError!,
                                    style: TextStyle(color: errorColor, fontSize: 12),
                                  ),
                                ),
                              ],
                              SizedBox(height: 14),
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                obscuringCharacter: '●',
                                decoration: _decoration(
                                  colors: colors,
                                  errorColor: errorColor,
                                  label: '비밀번호',
                                  hint: '8자 이상 비밀번호',
                                  controller: _passwordController,
                                ),
                              ),
                              _strengthMeter(colors, errorColor),
                              if (_passwordDisplayError != null) ...[
                                SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _passwordDisplayError!,
                                    style: TextStyle(color: errorColor, fontSize: 12),
                                  ),
                                ),
                              ],
                              SizedBox(height: 14),
                              TextField(
                                controller: _passwordConfirmController,
                                obscureText: true,
                                obscuringCharacter: '●',
                                decoration: _decoration(
                                  colors: colors,
                                  errorColor: errorColor,
                                  label: '비밀번호 확인',
                                  hint: '비밀번호를 다시 입력해주세요',
                                  controller: _passwordConfirmController,
                                ),
                              ),
                              if (_confirmError != null) ...[
                                SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _confirmError!,
                                    style: TextStyle(color: errorColor, fontSize: 12),
                                  ),
                                ),
                              ],
                              SizedBox(height: 28),
                              AppButton(
                                text: '회원가입',
                                type: _isFormValid
                                    ? AppButtonType.primaryPink
                                    : AppButtonType.gray,
                                onPressed: (_isFormValid && !_isLoading) ? _signup : null,
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