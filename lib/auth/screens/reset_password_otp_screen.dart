import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/loading_overlay.dart';
import 'reset_new_password_screen.dart';

/// 이메일로 받은 6자리 인증코드만 입력받는다.
/// 코드 검증 자체는 다음 화면(ResetNewPasswordScreen)에서 새 비밀번호와 함께
/// resetPassword Cloud Function 호출 시 한 번에 처리된다.
class ResetPasswordOtpScreen extends StatefulWidget {
  final String email;

  const ResetPasswordOtpScreen({super.key, required this.email});

  @override
  State<ResetPasswordOtpScreen> createState() => _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends State<ResetPasswordOtpScreen>
    with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();

  bool _isLoading = false;
  String? _codeError;
  int _resendCooldown = 60;
  Timer? _cooldownTimer;

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _iconScale;

  late final AnimationController _pulseController;
  late final AnimationController _floatController;

  late final AnimationController _buttonPulseController;
  bool _wasFormValid = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onFieldChanged);

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
    _iconScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _buttonPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _entryController.forward();
    _startCooldown();
  }

  void _onFieldChanged() {
    if (_codeError != null) _codeError = null;
    setState(() {});
    final isValidNow = _isFormValid;
    if (isValidNow && !_wasFormValid) {
      _buttonPulseController.forward(from: 0);
    }
    _wasFormValid = isValidNow;
  }

  @override
  void dispose() {
    _codeController.removeListener(_onFieldChanged);
    _codeController.dispose();
    _codeFocus.dispose();
    _cooldownTimer?.cancel();
    _entryController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    _buttonPulseController.dispose();
    super.dispose();
  }

  bool get _isCodeComplete => _codeController.text.trim().length == 6;

  bool get _isFormValid => _isCodeComplete;

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _resendCode() async {
    setState(() => _isLoading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'sendPasswordResetOtp',
      );
      await callable.call({'email': widget.email});
      _startCooldown();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('인증코드를 다시 보냈어요.')));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      String message = '재전송에 실패했어요. 잠시 후 다시 시도해주세요.';
      if (e.code == 'resource-exhausted') {
        message = e.message ?? message;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('재전송에 실패했어요. 잠시 후 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToNewPassword() {
    if (!_isFormValid) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResetNewPasswordScreen(
          email: widget.email,
          code: _codeController.text.trim(),
        ),
      ),
    );
  }

  InputBorder _border(Color color, {double width = 1.2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _dot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _iconHeader(AppColors colors) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Transform.scale(scale: _iconScale.value, child: child);
      },
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          final dy = -4 + _floatController.value * 8;
          return Transform.translate(offset: Offset(0, dy), child: child);
        },
        child: SizedBox(
          width: 128,
          height: 128,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + _pulseController.value * 0.22;
                  final opacity = (1 - _pulseController.value) * 0.3;
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.pinkStart,
                  ),
                ),
              ),
              Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.background,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.pinkStart.withOpacity(0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: context.colors.onPrimary.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(-4, -4),
                    ),
                  ],
                ),
                child: Image.asset('assets/splash/logo.png'),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [colors.pinkStart, colors.pinkEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: colors.background, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: colors.pinkStart.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.verified_rounded,
                    color: context.colors.onPrimary,
                    size: 16,
                  ),
                ),
              ),
              Positioned(
                left: -2,
                top: 10,
                child: _dot(colors.pinkStart.withOpacity(0.5), 8),
              ),
              Positioned(
                right: -4,
                top: 2,
                child: _dot(context.colors.softBlueAccent, 10),
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
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Stack(
        children: [
          AppBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 16),
                        _iconHeader(colors),
                        SizedBox(height: 24),
                        Text(
                          '인증코드 입력',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '아래 주소로 6자리 인증코드를 보냈어요.\n5분 이내에 입력해주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colors.pinkStart.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.pinkStart.withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.mail_outline_rounded,
                                size: 16,
                                color: colors.pinkStart,
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  widget.email,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 28),

                        // ── 인증코드 ──────────────────────
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: _codeController,
                            focusNode: _codeFocus,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (_isFormValid && !_isLoading)
                                _goToNewPassword();
                            },
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 10,
                              color: colors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              labelText: '인증코드',
                              counterText: '',
                              filled: true,
                              fillColor: colors.background,
                              hintText: '000000',
                              hintStyle: TextStyle(
                                letterSpacing: 10,
                                color: colors.textSecondary.withOpacity(0.4),
                              ),
                              suffixIcon: _codeController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        color: colors.textSecondary,
                                        size: 18,
                                      ),
                                      onPressed: () => _codeController.clear(),
                                    ),
                              border: _border(
                                colors.textSecondary.withOpacity(0.25),
                              ),
                              enabledBorder: _border(
                                colors.textSecondary.withOpacity(0.25),
                              ),
                              focusedBorder: _border(
                                colors.pinkStart,
                                width: 2,
                              ),
                              errorBorder: _border(errorColor),
                              focusedErrorBorder: _border(errorColor, width: 2),
                            ),
                          ),
                        ),
                        if (_codeError != null) ...[
                          SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _codeError!,
                              style: TextStyle(color: errorColor, fontSize: 12),
                            ),
                          ),
                        ],

                        // ── 다음 버튼 (항상 표시, 6자리 입력 시 활성화) ──
                        Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: AnimatedBuilder(
                            animation: _buttonPulseController,
                            builder: (context, child) {
                              final t = _buttonPulseController.value;
                              final scale =
                                  1.0 +
                                  (Curves.easeOutBack.transform(t) *
                                      (t < 1 ? 0.05 : 0.0));
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: AppButton(
                              text: '다음',
                              type: _isFormValid
                                  ? AppButtonType.primaryPink
                                  : AppButtonType.gray,
                              onPressed: (_isFormValid && !_isLoading)
                                  ? _goToNewPassword
                                  : null,
                            ),
                          ),
                        ),
                        SizedBox(height: 20),

                        // "인증코드 다시 받기"
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '메일이 오지 않았나요? ',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                            GestureDetector(
                              onTap: (_isLoading || _resendCooldown > 0)
                                  ? null
                                  : _resendCode,
                              child: Text(
                                _resendCooldown > 0
                                    ? '재전송 (${_resendCooldown}초 후 가능)'
                                    : '재전송하기',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  decoration: _resendCooldown > 0
                                      ? TextDecoration.none
                                      : TextDecoration.underline,
                                  color: _resendCooldown > 0
                                      ? colors.textSecondary
                                      : colors.pinkStart,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading) const LoadingOverlay(),
        ],
      ),
    );
  }
}
