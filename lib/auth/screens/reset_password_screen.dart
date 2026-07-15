import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/loading_overlay.dart';
import 'reset_password_otp_screen.dart';

/// 조건이 true가 될 때 자식 위젯을 슬라이드+페이드로 부드럽게 등장시키는 위젯.
/// login/signup 화면과 동일한 패턴.
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

class ResetPasswordScreen extends StatefulWidget {
  ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  bool _isLoading = false;
  String? _emailServerError;

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

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
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
    _emailController.dispose();
    _emailFocus.dispose();
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

  bool get _showButtonStep =>
      _emailController.text.trim().isNotEmpty && _emailFormatError == null;

  bool get _isFormValid => _showButtonStep;

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    setState(() {
      _isLoading = true;
      _emailServerError = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendPasswordResetOtp');
      await callable.call({'email': email});

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordOtpScreen(email: email),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('SEND_RESET_OTP ERROR CODE: ${e.code}');
      debugPrint('SEND_RESET_OTP ERROR MESSAGE: ${e.message}');
      if (!mounted) return;

      String modalMessage = '인증코드 발송에 실패했습니다.';
      switch (e.code) {
        case 'not-found':
          modalMessage = e.message ?? '가입 이력이 없는 이메일입니다.';
          break;
        case 'invalid-argument':
          modalMessage = e.message ?? '이메일 형식을 다시 확인해주세요.';
          break;
        case 'resource-exhausted':
          modalMessage = e.message ?? '잠시 후 다시 시도해주세요.';
          break;
        default:
          modalMessage = '인증코드 발송에 실패했습니다. 잠시 후 다시 시도해주세요.';
      }

      setState(() {
        if (e.code == 'not-found' || e.code == 'invalid-argument') {
          _emailServerError = modalMessage;
        }
      });
      _showFailedModal(modalMessage);
    } catch (e, st) {
      debugPrint('SEND_RESET_OTP UNEXPECTED ERROR: $e');
      debugPrint('$st');
      if (!mounted) return;
      _showFailedModal('인증코드 발송에 실패했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFailedModal(String message) {
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
                '요청 실패',
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
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                                'assets/images/textLogo.png',
                                height: 22,
                              ),
                              SizedBox(height: 20),
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
                                '가입하신 이메일로 인증코드를 보내드릴게요',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: colors.textSecondary),
                              ),
                              SizedBox(height: 36),

                              // ── 이메일 ──────────────────────
                              TextField(
                                controller: _emailController,
                                focusNode: _emailFocus,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  if (_isFormValid && !_isLoading) _sendCode();
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
                                    style: TextStyle(color: errorColor, fontSize: 12),
                                  ),
                                ),
                              ] else if (_showButtonStep) ...[
                                SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, size: 14, color: colors.pinkStart),
                                      SizedBox(width: 4),
                                      Text(
                                        '좋은 이메일이에요',
                                        style: TextStyle(color: colors.pinkStart, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // ── 인증코드 보내기 버튼 (항상 표시, 유효할 때만 활성화) ──
                              Padding(
                                padding: EdgeInsets.only(top: 18),
                                child: AnimatedBuilder(
                                  animation: _buttonPulseController,
                                  builder: (context, child) {
                                    final t = _buttonPulseController.value;
                                    final scale = 1.0 +
                                        (Curves.easeOutBack.transform(t) *
                                            (t < 1 ? 0.06 : 0.0));
                                    return Transform.scale(scale: scale, child: child);
                                  },
                                  child: AppButton(
                                    text: '인증코드 받기',
                                    type: _isFormValid
                                        ? AppButtonType.primaryPink
                                        : AppButtonType.gray,
                                    onPressed:
                                    (_isFormValid && !_isLoading) ? _sendCode : null,
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