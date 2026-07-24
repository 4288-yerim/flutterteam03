import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutterteam03/auth/screens/signup_screen.dart';
import 'terms_agreement_screen.dart';
import '../../theme.dart';
import '../../widgets/loading_overlay.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main_page.dart';
import '../../mypage/screens/withdrawal_pending_screen.dart';
import '../../mypage/services/withdrawal_status_service.dart';
import 'goal_certificate_screen.dart';
import 'profile_setup_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;

  late final AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  // 0~1 구간 중 start~end 사이에서 등장하는 fade+slide 애니메이션
  Widget _stagger({
    required double start,
    required double end,
    required Widget child,
    double slideFrom = 22,
  }) {
    final curved = CurvedAnimation(
      parent: _entryController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        return Opacity(
          opacity: curved.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - curved.value) * slideFrom),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Future<void> _handleAuthResult(
      BuildContext context,
      AuthResult? result,
      String provider,
      ) async {
    if (result == null || !context.mounted) return;

    if (result.isNewUser && result.signupTicket != null) {
      final ticket = result.signupTicket!;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GoalCertificateScreen(
            onNext: (certContext, goalCertificateId) {
              Navigator.of(certContext).push(
                MaterialPageRoute(
                  builder: (_) => ProfileSetupScreen(
                    onNext: (profileContext, {required nickname, bio, profileImageFile}) {
                      Navigator.of(profileContext).push(
                        MaterialPageRoute(
                          builder: (_) => TermsAgreementScreen(
                            onAgree: (termsContext, agreements) async {
                              final authResult = await AuthService.completeSocialSignup(
                                ticket: ticket,
                                agreements: agreements,
                                goalCertificateId: goalCertificateId,
                                nickname: nickname,
                                bio: bio,
                              );
                              if (authResult?.user == null) {
                                // 실패 처리 (스낵바 등)
                                return;
                              }
                              // 이제 계정 생겼으니 이미지 업로드
                              if (profileImageFile != null) {
                                final path = 'profile_images/${authResult!.user!.uid}.jpg';
                                final ref = FirebaseStorage.instance.ref().child(path);
                                await ref.putFile(profileImageFile);
                                final url = await ref.getDownloadURL();
                                await FirebaseFirestore.instance
                                    .collection('users').doc(authResult.user!.uid)
                                    .update({'profileImageUrl': url, 'profileImagePath': path});
                              }
                              if (!termsContext.mounted) return;
                              Navigator.of(termsContext).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const MainPage()),
                                    (route) => false,
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
    } else {
      // 기존 유저: 즉시 로그인 완료
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'lastLoginAt': FieldValue.serverTimestamp(),
          });
        }

        final bool isWithdrawalPending =
        await WithdrawalStatusService.isCurrentUserWithdrawalPending();

        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => isWithdrawalPending
                ? const WithdrawalPendingScreen()
                : const MainPage(),
          ),
              (route) => false,
        );
      } catch (_) {
        await FirebaseAuth.instance.signOut();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '회원 상태를 확인하지 못했습니다. 잠시 후 다시 로그인해주세요.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleSocialLogin(
      Future<AuthResult?> Function() signInFn,
      String provider,
      ) async {
    setState(() => _isLoading = true);
    final result = await signInFn();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!context.mounted) return;
    await _handleAuthResult(context, result, provider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      Expanded(
                        child: _stagger(
                          start: 0.0,
                          end: 0.55,
                          slideFrom: 0,
                          child: const _HeroIllustration(),
                        ),
                      ),
                      SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                          child: Column(
                            children: [
                              _stagger(
                                start: 0.45,
                                end: 0.80,
                                child: _SocialButton(
                                  text: '카카오로 계속하기',
                                  backgroundColor: const Color(0xFFFEE500),
                                  textColor: const Color(0xFF1A1A1A),
                                  icon: Image.asset(
                                    'assets/icons/kakaoIcon.png',
                                    width: 22,
                                    height: 22,
                                  ),
                                  onPressed: () => _handleSocialLogin(
                                      AuthService.signInWithKakao, 'KAKAO'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _stagger(
                                start: 0.52,
                                end: 0.87,
                                child: _SocialButton(
                                  text: 'Google로 계속하기',
                                  backgroundColor: Colors.white,
                                  textColor: const Color(0xFF1A1A1A),
                                  borderColor: const Color(0xFFE5E7EB),
                                  icon: Image.asset(
                                    'assets/icons/googleIcon.png',
                                    width: 22,
                                    height: 22,
                                  ),
                                  onPressed: () => _handleSocialLogin(
                                      AuthService.signInWithGoogle, 'GOOGLE'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _stagger(
                                start: 0.59,
                                end: 0.94,
                                child: _SocialButton(
                                  text: '네이버로 계속하기',
                                  backgroundColor: const Color(0xFF03C75A),
                                  textColor: Colors.white,
                                  icon: _BadgeIcon(
                                    label: 'N',
                                    backgroundColor: Colors.white,
                                    textColor: const Color(0xFF03C75A),
                                  ),
                                  onPressed: () => _handleSocialLogin(
                                      AuthService.signInWithNaver, 'NAVER'),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _stagger(
                                start: 0.65,
                                end: 1.0,
                                child: _OrDivider(colors: colors),
                              ),
                              const SizedBox(height: 24),
                              _stagger(
                                start: 0.70,
                                end: 1.0,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => SignupScreen()),
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: colors.pinkStart,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/images/textLogo.png',
                                          height: 20,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '시작하기',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: colors.pinkStart,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              _stagger(
                                start: 0.75,
                                end: 1.0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '이메일 회원이신가요? ',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) => LoginScreen()),
                                        );
                                      },
                                      child: Text(
                                        '로그인',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                          decoration: TextDecoration.underline,
                                          decorationColor: colors.textPrimary,
                                          decorationThickness: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (_isLoading) const LoadingOverlay(),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  final AppColors colors;

  const _OrDivider({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: colors.textSecondary.withOpacity(0.2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '또는',
            style: TextStyle(
              fontSize: 12.5,
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: colors.textSecondary.withOpacity(0.2))),
      ],
    );
  }
}

class _SocialButton extends StatefulWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final Widget icon;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.onPressed,
    this.borderColor,
  });

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: widget.borderColor != null
                ? Border.all(color: widget.borderColor!, width: 1.4)
                : null,
            boxShadow: widget.borderColor != null
                ? []
                : [
              BoxShadow(
                color: widget.backgroundColor.withOpacity(0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.icon,
              const SizedBox(width: 8),
              Text(
                widget.text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _BadgeIcon({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textColor),
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.12, 0.88, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SizedBox.expand(
        child: Image.asset(
          'assets/images/welcome.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
