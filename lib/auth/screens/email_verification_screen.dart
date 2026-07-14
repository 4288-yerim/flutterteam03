import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutterteam03/auth/screens/terms_agreement_screen.dart';
import '../../main_page.dart';
import '../../theme.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/loading_overlay.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _notVerifiedYet = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _iconScale;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
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

    _entryController.forward();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

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

  Future<void> _resendEmail() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.setLanguageCode('ko');
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      _startCooldown();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증 메일을 다시 보냈어요.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = '메일 재전송에 실패했어요. 잠시 후 다시 시도해주세요.';
      if (e.code == 'too-many-requests') {
        message = '요청이 너무 많아요. 잠시 후 다시 시도해주세요.';
        _startCooldown(); // 서버 제한이니 쿨다운도 걸어줌
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메일 재전송에 실패했어요. 잠시 후 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() {
      _isLoading = true;
      _notVerifiedYet = false;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      final refreshed = FirebaseAuth.instance.currentUser;

      if (refreshed != null && refreshed.emailVerified) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TermsAgreementScreen(
              onAgree: (context, agreements) async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(refreshed.uid)
                    .set({
                  'uid': refreshed.uid,
                  'email': refreshed.email,
                  'loginProvider': 'PASSWORD',
                  'role': 'USER',
                  'status': 'ACTIVE',
                  'loginFailCount': 0,
                  'reportCount': 0,
                  'termsAgreed': agreements['terms'] ?? false,
                  'privacyAgreed': agreements['privacy'] ?? false,
                  'marketingAgreed': agreements['marketing'] ?? false,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MainPage()),
                );
              },
            ),
          ),
        );
      } else {
        setState(() => _notVerifiedYet = true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 상단 아이콘: 등장 팝 + 계속되는 은은한 펄스 링
  Widget _iconHeader(AppColors colors) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Transform.scale(scale: _iconScale.value, child: child);
      },
      child: SizedBox(
        width: 108,
        height: 108,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 은은하게 커졌다 작아지는 펄스 링
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + _pulseController.value * 0.28;
                final opacity = (1 - _pulseController.value) * 0.35;
                return Transform.scale(
                  scale: scale,
                  child: Opacity(opacity: opacity, child: child),
                );
              },
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.pinkStart,
                ),
              ),
            ),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [colors.pinkStart, colors.pinkEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.pinkStart.withOpacity(0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.mark_email_unread_rounded,
                  color: Colors.white, size: 38),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _iconHeader(colors),
                        SizedBox(height: 28),
                        Text(
                          '인증 메일을 보냈어요',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '아래 주소로 인증 메일을 보냈어요.\n메일함에서 링크를 눌러 인증을 완료해주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 16),
                        // 이메일 주소 카드
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
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
                              Icon(Icons.mail_outline_rounded,
                                  size: 16, color: colors.pinkStart),
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
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          child: _notVerifiedYet
                              ? Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .error
                                    .withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '아직 인증이 확인되지 않았어요.\n메일함(스팸함 포함)을 확인해주세요.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                              : const SizedBox.shrink(),
                        ),
                        SizedBox(height: 40),
                        AppButton(
                          text: '인증 완료 확인',
                          type: AppButtonType.primaryPink,
                          onPressed: _isLoading ? null : _checkVerified,
                        ),
                        SizedBox(height: 14),
                        TextButton(
                          onPressed: (_isLoading || _resendCooldown > 0)
                              ? null
                              : _resendEmail,
                          child: Text(
                            _resendCooldown > 0
                                ? '재전송 가능까지 ${_resendCooldown}초'
                                : '인증 메일 다시 받기',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _resendCooldown > 0
                                  ? colors.textSecondary
                                  : colors.pinkStart,
                            ),
                          ),
                        ),
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