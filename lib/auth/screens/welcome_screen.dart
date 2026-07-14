import 'package:flutter/material.dart';
import 'package:flutterteam03/auth/screens/signup_screen.dart';
import 'terms_agreement_screen.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_overlay.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main_page.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;

  void _handleAuthResult(
      BuildContext context,
      AuthResult? result,
      String provider,
      ) {    if (result == null || !context.mounted) return;

    if (result.isNewUser) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TermsAgreementScreen(
            onAgree: (termsContext) async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set({
                  'uid': user.uid,
                  'email': user.email,
                  'loginProvider': provider,
                  'role': 'USER',
                  'status': 'ACTIVE',
                  'loginFailCount': 0,
                  'reportCount': 0,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              }

              if (!termsContext.mounted) return;
              Navigator.of(termsContext).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainPage()),
              );
            },
          ),
        ),
      );
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
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
    _handleAuthResult(context, result, provider);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: AppBackground(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // 상단: 앱 소개 영역
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '따자!',
                          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '목표를 세우고, 함께 공부하고,\n자격증 합격까지 따자!',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF9AA0AC),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(
                      children: [
                        _SocialButton(
                          text: '카카오로 계속하기',
                          backgroundColor: const Color(0xFFFEE500),
                          textColor: const Color(0xFF1A1A1A),
                          icon: Image.asset(
                            'assets/icons/kakaoIcon.png',
                            width: 22,
                            height: 22,
                          ),
                          onPressed: () =>
                              _handleSocialLogin(AuthService.signInWithKakao, 'KAKAO'),
                        ),
                        const SizedBox(height: 12),
                        _SocialButton(
                          text: 'Google로 계속하기',
                          backgroundColor: Colors.white,
                          textColor: const Color(0xFF1A1A1A),
                          borderColor: const Color(0xFFE0E0E0),
                          icon: Image.asset(
                            'assets/icons/googleIcon.png',
                            width: 22,
                            height: 22,
                          ),
                          onPressed: () =>
                              _handleSocialLogin(AuthService.signInWithGoogle, 'GOOGLE'),
                        ),
                        const SizedBox(height: 12),
                        _SocialButton(
                          text: '네이버로 계속하기',
                          backgroundColor: const Color(0xFF03C75A),
                          textColor: Colors.white,
                          icon: _BadgeIcon(
                            label: 'N',
                            backgroundColor: Colors.white,
                            textColor: const Color(0xFF03C75A),
                          ),
                          onPressed: () =>
                              _handleSocialLogin(AuthService.signInWithNaver, 'NAVER'),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          text: '따자 시작하기',
                          type: AppButtonType.outlinePink,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => SignupScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '이메일 회원이신가요? ',
                              style: TextStyle(fontSize: 14, color: Color(0xFF9AA0AC)),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => LoginScreen()),
                                );
                              },
                              child: const Text(
                                '로그인',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1A1A1A),
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFF1A1A1A),
                                  decorationThickness: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading) const LoadingOverlay(),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: borderColor != null
                ? BorderSide(color: borderColor!, width: 1.5)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
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