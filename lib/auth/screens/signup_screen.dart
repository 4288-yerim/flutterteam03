import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/app_auth_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/loading_overlay.dart';
import 'otp_verification_screen.dart';

enum _PasswordStrength { none, weak, medium, strong }

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

class SignupScreen extends StatefulWidget {
  SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _passwordConfirmFocus = FocusNode();

  bool _isLoading = false;

  String? _emailServerError;
  String? _passwordServerError;

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _logoScale;

  late final AnimationController _breatheController;

  late final AnimationController _buttonPulseController;
  bool _wasFormValid = false;

  static final _emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_onPasswordChanged);
    _passwordConfirmController.addListener(_onConfirmChanged);

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

    _passwordFocus.addListener(() {});
  }

  void _onEmailChanged() {
    if (_emailServerError != null) _emailServerError = null;
    if (!_showPasswordStep) {
      if (_passwordController.text.isNotEmpty) _passwordController.clear();
      if (_passwordConfirmController.text.isNotEmpty) {
        _passwordConfirmController.clear();
      }
    }
    setState(() {});
  }

  void _onPasswordChanged() {
    if (_passwordServerError != null) _passwordServerError = null;
    if (!_isPasswordValid && _passwordConfirmController.text.isNotEmpty) {
      _passwordConfirmController.clear();
    }
    setState(() {});
    _maybePulseButton();
  }

  void _onConfirmChanged() {
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

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _passwordController.removeListener(_onPasswordChanged);
    _passwordConfirmController.removeListener(_onConfirmChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _passwordConfirmFocus.dispose();
    _entryController.dispose();
    _breatheController.dispose();
    _buttonPulseController.dispose();
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

  String? get _passwordDisplayError =>
      _passwordServerError ?? _passwordLengthError;
  String? get _confirmError {
    final confirm = _passwordConfirmController.text;
    if (confirm.isEmpty) return null;
    return confirm == _passwordController.text ? null : '비밀번호가 일치하지 않습니다.';
  }

  bool get _showPasswordStep =>
      _emailController.text.trim().isNotEmpty && _emailFormatError == null;

  bool get _showConfirmStep => _showPasswordStep && _isPasswordValid;

  bool get _showButtonStep =>
      _showConfirmStep && _passwordConfirmController.text.isNotEmpty;

  bool get _isFormValid =>
      _emailController.text.trim().isNotEmpty &&
      _emailFormatError == null &&
      _isPasswordValid &&
      _passwordConfirmController.text.isNotEmpty &&
      _confirmError == null;

  Future<void> _signup() async {
    print('===== SIGNUP BUTTON PRESSED =====');
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendOtp');
      await callable.call({'email': email});

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              OtpVerificationScreen(email: email, password: password),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FUNCTIONS ERROR CODE: ${e.code}');
      debugPrint('FUNCTIONS ERROR MESSAGE: ${e.message}');
      debugPrint('FUNCTIONS ERROR DETAILS: ${e.details}');
      if (!mounted) return;

      String modalMessage = '회원가입에 실패했습니다.';
      switch (e.code) {
        case 'already-exists':
          modalMessage = '이미 가입된 이메일입니다.';
          break;
        case 'invalid-argument':
          modalMessage = e.message ?? '입력값을 다시 확인해주세요.';
          break;
        case 'resource-exhausted':
          modalMessage = e.message ?? '잠시 후 다시 시도해주세요.';
          break;
        default:
          modalMessage = '회원가입에 실패했습니다. 잠시 후 다시 시도해주세요.';
      }

      setState(() {
        if (e.code == 'already-exists' || e.code == 'invalid-argument') {
          _emailServerError = modalMessage;
        }
      });
      _showSignupFailedModal(modalMessage);
    } catch (e, st) {
      debugPrint('SIGNUP ERROR: $e');
      debugPrint('$st');
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < filledBars
                      ? activeColor
                      : colors.textSecondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: activeColor,
            ),
          ),
        ],
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
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 36),

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
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) {
                                        if (_showConfirmStep) {
                                          FocusScope.of(
                                            context,
                                          ).requestFocus(_passwordConfirmFocus);
                                        }
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
                                    _strengthMeter(colors, errorColor),
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

                              _StepReveal(
                                visible: _showConfirmStep,
                                child: Column(
                                  key: const ValueKey('confirm-block'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 14),
                                    TextField(
                                      controller: _passwordConfirmController,
                                      focusNode: _passwordConfirmFocus,
                                      obscureText: true,
                                      obscuringCharacter: '●',
                                      textInputAction: TextInputAction.done,
                                      decoration: _decoration(
                                        colors: colors,
                                        errorColor: errorColor,
                                        label: '비밀번호 확인',
                                        hint: '비밀번호를 다시 입력해주세요',
                                        controller: _passwordConfirmController,
                                        icon: Icons.lock_person_outlined,
                                      ),
                                    ),
                                    if (_confirmError != null) ...[
                                      SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _confirmError!,
                                          style: TextStyle(
                                            color: errorColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ] else if (_passwordConfirmController
                                        .text
                                        .isNotEmpty) ...[
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
                                              '비밀번호가 일치해요',
                                              style: TextStyle(
                                                color: colors.pinkStart,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              _StepReveal(
                                visible: _showButtonStep,
                                child: Padding(
                                  key: const ValueKey('button-block'),
                                  padding: EdgeInsets.only(top: 28),
                                  child: AnimatedBuilder(
                                    animation: _buttonPulseController,
                                    builder: (context, child) {
                                      final t = _buttonPulseController.value;
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
                                      text: '회원가입',
                                      type: _isFormValid
                                          ? AppButtonType.primaryPink
                                          : AppButtonType.gray,
                                      onPressed: (_isFormValid && !_isLoading)
                                          ? _signup
                                          : null,
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
