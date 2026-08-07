import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../main_page.dart';
import '../../mypage/screens/withdrawal_pending_screen.dart';
import '../../mypage/services/withdrawal_status_service.dart';
import '../services/account_status_service.dart';
import '../../theme.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/loading_overlay.dart';
import 'reset_password_screen.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../admin/screens/admin.dart';

class _StepReveal extends StatelessWidget {
  final bool visible;
  final Widget child;
  final Duration sizeDuration;
  final Duration switchDuration;

  const _StepReveal({
    required this.visible,
    required this.child,
    this.sizeDuration = const Duration(milliseconds: 380),
    this.switchDuration = const Duration(milliseconds: 320),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: sizeDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: switchDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.18),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: visible
            ? KeyedSubtree(key: const ValueKey('visible'), child: child)
            : const SizedBox.shrink(key: ValueKey('hidden')),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;

  // 서버(Firebase)에서 내려온 에러는 필드별로 따로 보관해두고,
  // 사용자가 해당 필드를 다시 수정하면 자동으로 지워집니다.
  String? _emailServerError;
  String? _passwordServerError;

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _logoScale;

  late final AnimationController _breatheController;

  // 버튼이 막 활성화됐을 때 살짝 튀는 느낌을 주기 위한 컨트롤러
  late final AnimationController _buttonPulseController;
  bool _wasFormValid = false;

  static final _emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_onPasswordChanged);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
        );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _buttonPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _entryController.forward();
  }

  void _onEmailChanged() {
    if (_emailServerError != null) _emailServerError = null;
    if (!_showPasswordStep && _passwordController.text.isNotEmpty) {
      _passwordController.clear();
    }
    setState(() {});
  }

  void _onPasswordChanged() {
    if (_passwordServerError != null) _passwordServerError = null;
    setState(() {});
    _maybePulseButton();
  }

  void _maybePulseButton() {
    final isValidNow = _isFormValid;
    if (isValidNow && !_wasFormValid) {
      _buttonPulseController.forward(from: 0);
    }
    _wasFormValid = isValidNow;
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
  String? get _passwordDisplayError =>
      _passwordServerError ?? _passwordFormatError;

  // ── 단계별 공개 조건 ──────────────────────────────────────────
  bool get _showPasswordStep =>
      _emailController.text.trim().isNotEmpty && _emailFormatError == null;

  bool get _showButtonStep =>
      _showPasswordStep && _passwordController.text.isNotEmpty;
  // ─────────────────────────────────────────────────────────────

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
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _entryController.dispose();
    _breatheController.dispose();
    _buttonPulseController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid);
      await userDocRef.update({'lastLoginAt': FieldValue.serverTimestamp()});

      final check = await AccountStatusService.checkCurrentUserStatus();
      if (!mounted) return;
      if (check.result == AccountCheckResult.suspended) {
        final untilText = check.suspendedUntil != null
            ? '${check.suspendedUntil!.year}.${check.suspendedUntil!.month}.${check.suspendedUntil!.day}까지'
            : '별도 안내 시까지';
        setState(() => _isLoading = false);
        if (!mounted) return;
        AppConfirmDialog.show(
          context,
          icon: Icons.pause_circle_filled_rounded,
          title: '로그인 불가',
          description:
              '이용이 정지된 계정입니다.\n정지 기간: $untilText\n\n정지 해제 문의는 DdaiT@naver.com으로 해주세요.',
          primaryLabel: '확인',
          onPrimaryPressed: () => Navigator.of(context).pop(),
          barrierDismissible: false,
          preventBack: true,
          isDestructive: true,
        );
        return;
      }

      final userDoc = await userDocRef.get();
      final String? role = userDoc.data()?['role'] as String?;

      if (!mounted) return;

      if (role == 'ADMIN') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminPage()),
          (route) => false,
        );
        return;
      }

      final bool isWithdrawalPending =
          await WithdrawalStatusService.isCurrentUserWithdrawalPending();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => isWithdrawalPending
              ? const WithdrawalPendingScreen()
              : const MainPage(),
        ),
        (route) => false,
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
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _showLoginFailedModal('회원 상태를 확인하지 못했습니다. 잠시 후 다시 로그인해주세요.');
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
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: colors.background,
      prefixIcon: Icon(icon, color: colors.textSecondary, size: 20),
      border: _border(colors.textSecondary.withOpacity(0.25)),
      enabledBorder: _border(colors.textSecondary.withOpacity(0.25)),
      focusedBorder: _border(colors.pinkStart, width: 2),
      errorBorder: _border(errorColor),
      focusedErrorBorder: _border(errorColor, width: 2),
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
              icon: Icon(Icons.close, color: colors.textSecondary, size: 18),
              onPressed: () => controller.clear(),
            ),
    );
  }

  Widget _logoHeader(AppColors colors) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Transform.scale(scale: _logoScale.value, child: child);
      },
      child: AnimatedBuilder(
        animation: _breatheController,
        builder: (context, child) {
          final scale = 1.0 + _breatheController.value * 0.05;
          return Transform.scale(scale: scale, child: child);
        },
        child: SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.pinkStart.withOpacity(0.22),
                      colors.pinkStart.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.background,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.pinkStart.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Image.asset('assets/splash/logo.png'),
              ),
            ],
          ),
        ),
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
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              _logoHeader(colors),
                              SizedBox(height: 8),
                              Image.asset(
                                Theme.of(context).brightness == Brightness.dark
                                    ? 'assets/images/textLogo_dark.png'
                                    : 'assets/images/textLogo.png',
                                height: 22,
                              ),
                              SizedBox(height: 20),
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
                                '따iT에 오신 걸 환영해요!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 36),

                              // ── 이메일 (항상 표시) ──────────────
                              TextField(
                                controller: _emailController,
                                focusNode: _emailFocus,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) {
                                  if (_showPasswordStep) {
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(_passwordFocus);
                                  }
                                },
                                decoration: _decoration(
                                  colors: colors,
                                  errorColor: errorColor,
                                  label: '이메일',
                                  hint: 'example@gmail.com',
                                  controller: _emailController,
                                  icon: Icons.mail_outline_rounded,
                                ),
                              ),
                              if (_emailDisplayError != null) ...[
                                SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _emailDisplayError!,
                                    style: TextStyle(
                                      color: errorColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ] else if (_showPasswordStep) ...[
                                SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: colors.pinkStart,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '좋은 이메일이에요',
                                        style: TextStyle(
                                          color: colors.pinkStart,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // ── 비밀번호 (이메일 유효 시 등장) ──────
                              _StepReveal(
                                visible: _showPasswordStep,
                                child: Column(
                                  key: const ValueKey('password-block'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 14),
                                    TextField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocus,
                                      obscureText: true,
                                      obscuringCharacter: '●',
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) {
                                        if (_isFormValid && !_isLoading)
                                          _login();
                                      },
                                      decoration: _decoration(
                                        colors: colors,
                                        errorColor: errorColor,
                                        label: '비밀번호',
                                        hint: '8자 이상 비밀번호',
                                        controller: _passwordController,
                                        icon: Icons.lock_outline_rounded,
                                      ),
                                    ),
                                    if (_passwordDisplayError != null) ...[
                                      SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _passwordDisplayError!,
                                          style: TextStyle(
                                            color: errorColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // ── 로그인 버튼 (비밀번호 입력 시 등장) ──
                              _StepReveal(
                                visible: _showButtonStep,
                                child: Padding(
                                  key: const ValueKey('button-block'),
                                  padding: EdgeInsets.only(top: 18),
                                  child: AnimatedBuilder(
                                    animation: _buttonPulseController,
                                    builder: (context, child) {
                                      final t = _buttonPulseController.value;
                                      // 0 -> 1.06 -> 1.0 로 살짝 튀는 스케일
                                      final scale =
                                          1.0 +
                                          (Curves.easeOutBack.transform(t) *
                                              (t < 1 ? 0.06 : 0.0));
                                      return Transform.scale(
                                        scale: scale,
                                        child: child,
                                      );
                                    },
                                    child: AppButton(
                                      text: '로그인',
                                      type: _isFormValid
                                          ? AppButtonType.primaryPink
                                          : AppButtonType.gray,
                                      onPressed: (_isFormValid && !_isLoading)
                                          ? _login
                                          : null,
                                    ),
                                  ),
                                ),
                              ),

                              // ── 비밀번호 찾기 (이메일 입력 시 등장, 버튼 아래 고정) ──
                              _StepReveal(
                                visible: _showPasswordStep,
                                child: Align(
                                  key: const ValueKey('forgot-password-block'),
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 16),
                                    child: GestureDetector(
                                      onTap: _isLoading
                                          ? null
                                          : () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ResetPasswordScreen(),
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
          if (_isLoading) const LoadingOverlay(),
        ],
      ),
    );
  }
}
