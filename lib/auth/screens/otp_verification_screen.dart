import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterteam03/auth/screens/terms_agreement_screen.dart';
import '../../main_page.dart';
import '../../theme.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/loading_overlay.dart';
import 'goal_certificate_screen.dart';
import 'profile_setup_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String password;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
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
  bool _wasCodeComplete = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);

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

  void _onCodeChanged() {
    if (_codeError != null) setState(() => _codeError = null);
    setState(() {});
    final completeNow = _isCodeComplete;
    if (completeNow && !_wasCodeComplete) {
      _buttonPulseController.forward(from: 0);
    }
    _wasCodeComplete = completeNow;
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
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
      final callable = FirebaseFunctions.instance.httpsCallable('sendOtp');
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

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _codeError = '6자리 코드를 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _codeError = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('verifyOtp');
      final result = await callable.call({'email': widget.email, 'code': code});

      final verificationToken = result.data['verificationToken'] as String;

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GoalCertificateScreen(
            onNext: (certContext, goalCertificateId) {
              Navigator.of(certContext).push(
                MaterialPageRoute(
                  builder: (_) => ProfileSetupScreen(
                    onNext:
                        (
                          profileContext, {
                          required String nickname,
                          String? bio,
                          File? profileImageFile,
                        }) {
                          Navigator.of(profileContext).push(
                            MaterialPageRoute(
                              builder: (_) => TermsAgreementScreen(
                                onAgree: (termsContext, agreements) async {
                                  await _completeSignup(
                                    termsContext,
                                    verificationToken,
                                    agreements,
                                    goalCertificateId,
                                    nickname,
                                    bio,
                                    profileImageFile,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                  ),
                ),
              );
            },
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      String message = '인증에 실패했어요. 잠시 후 다시 시도해주세요.';
      switch (e.code) {
        case 'invalid-argument':
          message = e.message ?? '인증코드가 일치하지 않습니다.';
          break;
        case 'deadline-exceeded':
          message = '인증코드가 만료됐어요. 다시 요청해주세요.';
          break;
        case 'resource-exhausted':
          message = '시도 횟수를 초과했어요. 다시 요청해주세요.';
          break;
        case 'not-found':
          message = '인증코드를 먼저 요청해주세요.';
          break;
      }
      setState(() => _codeError = message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _codeError = '인증에 실패했어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeSignup(
    BuildContext termsContext,
    String verificationToken,
    Map<String, bool> agreements,
    String? goalCertificateId,
    String nickname,
    String? bio,
    File? profileImageFile,
  ) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'completeSignup',
      );
      final result = await callable.call({
        'email': widget.email,
        'password': widget.password,
        'verificationToken': verificationToken,
        'agreements': agreements,
        'goalCertificateId': goalCertificateId,
        'nickname': nickname,
        'bio': bio,
      });

      final customToken = result.data['customToken'] as String;
      await FirebaseAuth.instance.signInWithCustomToken(customToken);

      if (profileImageFile != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            final path = 'profile_images/${user.uid}.jpg';
            final ref = FirebaseStorage.instance.ref().child(path);
            await ref.putFile(profileImageFile);
            final url = await ref.getDownloadURL();
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'profileImageUrl': url, 'profileImagePath': path});
          } catch (e) {
            debugPrint('PROFILE IMAGE UPLOAD FAILED: $e');
          }
        }
      }
      if (!termsContext.mounted) return;
      Navigator.of(termsContext).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainPage(showTutorial: true)),
        (route) => false,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('COMPLETE_SIGNUP ERROR CODE: ${e.code}');
      debugPrint('COMPLETE_SIGNUP ERROR MESSAGE: ${e.message}');

      if (e.code == 'already-exists') {
        final recovered = await _tryRecoverExistingAccount(termsContext);
        if (recovered) return;
      }

      if (!termsContext.mounted) return;
      String message = '가입 처리에 실패했어요. 잠시 후 다시 시도해주세요.';
      switch (e.code) {
        case 'deadline-exceeded':
          message = '인증이 만료됐어요. 이메일 인증부터 다시 진행해주세요.';
          break;
        case 'already-exists':
          message = '이미 가입된 이메일입니다. 로그인 화면에서 로그인해주세요.';
          break;
        case 'permission-denied':
        case 'invalid-argument':
          message = e.message ?? message;
          break;
      }
      ScaffoldMessenger.of(
        termsContext,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(termsContext).popUntil((route) => route.isFirst);
    } catch (e, st) {
      debugPrint('COMPLETE_SIGNUP UNEXPECTED ERROR: $e');
      debugPrint('$st');
      if (!termsContext.mounted) return;
      ScaffoldMessenger.of(termsContext).showSnackBar(
        const SnackBar(content: Text('가입 처리에 실패했어요. 잠시 후 다시 시도해주세요.')),
      );
      Navigator.of(termsContext).popUntil((route) => route.isFirst);
    }
  }

  Future<bool> _tryRecoverExistingAccount(BuildContext termsContext) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );
      if (!termsContext.mounted) return false;
      Navigator.of(termsContext).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainPage()),
        (route) => false,
      );
      return true;
    } catch (e) {
      debugPrint('RECOVER LOGIN FAILED: $e');
      return false;
    }
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
                        Icons.check_rounded,
                        color: context.colors.onPrimary,
                        size: 14,
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

  Widget _dot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final errorColor = Theme.of(context).colorScheme.error;
    final canVerify = _isCodeComplete && !_isLoading;

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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 24),
                        _iconHeader(colors),
                        SizedBox(height: 28),
                        Text(
                          '인증코드를 입력해주세요',
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
                        SizedBox(height: 32),
                        TextField(
                          controller: _codeController,
                          focusNode: _codeFocus,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: colors.textSecondary.withOpacity(0.25),
                                width: 1.2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: colors.textSecondary.withOpacity(0.25),
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: colors.pinkStart,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: errorColor,
                                width: 1.2,
                              ),
                            ),
                          ),
                          onSubmitted: (_) {
                            if (canVerify) _verifyCode();
                          },
                        ),
                        if (_codeError != null) ...[
                          SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _codeError!,
                              style: TextStyle(color: errorColor, fontSize: 12),
                            ),
                          ),
                        ],
                        SizedBox(height: 32),
                        AnimatedBuilder(
                          animation: _buttonPulseController,
                          builder: (context, child) {
                            final t = _buttonPulseController.value;
                            final scale =
                                1.0 +
                                (Curves.easeOutBack.transform(t) *
                                    (t < 1 ? 0.05 : 0.0));
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: AppButton(
                            text: '인증하기',
                            type: canVerify
                                ? AppButtonType.primaryPink
                                : AppButtonType.gray,
                            onPressed: canVerify ? _verifyCode : null,
                          ),
                        ),
                        SizedBox(height: 14),
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
