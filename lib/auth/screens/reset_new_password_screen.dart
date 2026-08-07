import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/app_auth_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/loading_overlay.dart';

enum _PasswordStrength { none, weak, medium, strong }

/// 조건이 true가 될 때 자식 위젯을 슬라이드+페이드로 부드럽게 등장시키는 위젯.
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

/// 인증코드 검증 화면에서 넘어온 email + code로 새 비밀번호를 설정한다.
/// resetPassword Cloud Function 호출 시점에 코드 유효성도 함께 검증된다.
/// 코드가 만료/불일치하면 이전 화면(인증코드 입력)으로 돌려보낸다.
class ResetNewPasswordScreen extends StatefulWidget {
  final String email;
  final String code;

  const ResetNewPasswordScreen({
    super.key,
    required this.email,
    required this.code,
  });

  @override
  State<ResetNewPasswordScreen> createState() => _ResetNewPasswordScreenState();
}

class _ResetNewPasswordScreenState extends State<ResetNewPasswordScreen>
    with TickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  final _passwordFocus = FocusNode();
  final _passwordConfirmFocus = FocusNode();

  bool _isLoading = false;
  String? _passwordServerError;

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
    _passwordController.addListener(_onFieldChanged);
    _passwordConfirmController.addListener(_onFieldChanged);

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
  }

  void _onFieldChanged() {
    if (_passwordServerError != null) _passwordServerError = null;
    setState(() {});
    final isValidNow = _isFormValid;
    if (isValidNow && !_wasFormValid) {
      _buttonPulseController.forward(from: 0);
    }
    _wasFormValid = isValidNow;
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onFieldChanged);
    _passwordConfirmController.removeListener(_onFieldChanged);
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _passwordFocus.dispose();
    _passwordConfirmFocus.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    _buttonPulseController.dispose();
    super.dispose();
  }

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

  // ── 단계별 공개 조건 ──────────────────────────────────────────
  bool get _showConfirmStep => _isPasswordValid;

  bool get _showButtonStep =>
      _showConfirmStep && _passwordConfirmController.text.isNotEmpty;
  // ─────────────────────────────────────────────────────────────

  bool get _isFormValid =>
      _isPasswordValid &&
      _passwordConfirmController.text.isNotEmpty &&
      _confirmError == null;

  Future<void> _resetPassword() async {
    if (!_isFormValid) return;

    setState(() {
      _isLoading = true;
      _passwordServerError = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'resetPassword',
      );
      await callable.call({
        'email': widget.email,
        'code': widget.code,
        'newPassword': _passwordController.text.trim(),
      });

      if (!mounted) return;
      _showSuccessModal();
    } on FirebaseFunctionsException catch (e) {
      debugPrint('RESET_PASSWORD ERROR CODE: ${e.code}');
      debugPrint('RESET_PASSWORD ERROR MESSAGE: ${e.message}');
      if (!mounted) return;

      String message = '비밀번호 재설정에 실패했어요. 잠시 후 다시 시도해주세요.';
      switch (e.code) {
        case 'invalid-argument':
          message = e.message ?? '인증코드가 일치하지 않습니다.';
          _showCodeInvalidModal(message);
          return;
        case 'deadline-exceeded':
          message = '인증코드가 만료됐어요. 다시 요청해주세요.';
          _showCodeInvalidModal(message);
          return;
        case 'resource-exhausted':
          message = '시도 횟수를 초과했어요. 다시 요청해주세요.';
          _showCodeInvalidModal(message);
          return;
        case 'not-found':
          message = '인증코드를 먼저 요청해주세요.';
          _showCodeInvalidModal(message);
          return;
      }
      _showFailedModal(message);
    } catch (e, st) {
      debugPrint('RESET_PASSWORD UNEXPECTED ERROR: $e');
      debugPrint('$st');
      if (!mounted) return;
      _showFailedModal('비밀번호 재설정에 실패했어요. 잠시 후 다시 시도해주세요.');
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
                '재설정 실패',
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

  // 코드가 만료/불일치인 경우: 확인 누르면 인증코드 입력 화면으로 되돌아간다.
  void _showCodeInvalidModal(String message) {
    final colors = Theme.of(context).extension<AppColors>()!;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
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
                '인증코드 확인 필요',
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
                text: '인증코드 다시 입력',
                type: AppButtonType.primaryPink,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 재설정 성공 -> 로그인 화면까지 세 단계(이 화면, 코드 입력 화면, 이메일 입력 화면)를 닫고 돌려보낸다.
  void _showSuccessModal() {
    final colors = Theme.of(context).extension<AppColors>()!;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
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
              Row(
                children: [
                  Icon(Icons.check_circle, color: colors.pinkStart, size: 22),
                  SizedBox(width: 8),
                  Text(
                    '비밀번호 변경 완료',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                '새 비밀번호로 로그인해주세요.',
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
              SizedBox(height: 24),
              AppButton(
                text: '로그인하러 가기',
                type: AppButtonType.primaryPink,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  // 이 화면 + 코드 입력 화면 + 이메일 입력 화면을 모두 닫고 로그인 화면으로 복귀.
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
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
                right: 4,
                bottom: 8,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: colors.background,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.shadow,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.pinkStart,
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        color: context.colors.onPrimary,
                        size: 13,
                      ),
                    ),
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
              Positioned(
                left: 6,
                bottom: -4,
                child: _dot(context.colors.softBlueAccent, 6),
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
                          '새 비밀번호 설정',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '새로 사용할 비밀번호를 입력해주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 28),

                        // ── 새 비밀번호 (항상 표시) ──────────
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextField(
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
                              label: '새 비밀번호',
                              hint: '8자 이상 비밀번호',
                              controller: _passwordController,
                              icon: Icons.lock_outline_rounded,
                            ),
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

                        // ── 새 비밀번호 확인 (비밀번호 유효 시 등장) ──
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
                                onSubmitted: (_) {
                                  if (_isFormValid && !_isLoading)
                                    _resetPassword();
                                },
                                decoration: _decoration(
                                  colors: colors,
                                  errorColor: errorColor,
                                  label: '새 비밀번호 확인',
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

                        // ── 비밀번호 변경 버튼 (비밀번호 확인 입력 시 등장) ──
                        _StepReveal(
                          visible: _showButtonStep,
                          child: Padding(
                            key: const ValueKey('button-block'),
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
                                text: '비밀번호 변경하기',
                                type: _isFormValid
                                    ? AppButtonType.primaryPink
                                    : AppButtonType.gray,
                                onPressed: (_isFormValid && !_isLoading)
                                    ? _resetPassword
                                    : null,
                              ),
                            ),
                          ),
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
