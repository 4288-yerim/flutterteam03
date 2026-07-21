import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../main_page.dart';
import '../../mypage/screens/withdrawal_pending_screen.dart';
import '../../mypage/services/withdrawal_status_service.dart';
import '../../theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkSlide;
  late final Animation<double> _dotsOpacity;

  late final AnimationController _breatheController;
  late final AnimationController _characterController;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _wordmarkOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _wordmarkSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _dotsOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    // 배경 블롭 은은하게 숨쉬는 애니메이션
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // 캐릭터 인사/들썩임 애니메이션
    _characterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _controller.forward();
    _goNext();
  }

  Future<void> _goNext() async {
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    Widget nextScreen;

    if (user == null) {
      nextScreen = const WelcomeScreen();
    } else {
      try {
        final bool isWithdrawalPending =
        await WithdrawalStatusService.isCurrentUserWithdrawalPending();
        nextScreen = isWithdrawalPending
            ? const WithdrawalPendingScreen()
            : const MainPage();
      } catch (_) {
        // 회원 상태를 확인할 수 없을 때 메인 화면으로 우회하지 않습니다.
        await FirebaseAuth.instance.signOut();
        nextScreen = const WelcomeScreen();
      }
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => nextScreen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _breatheController.dispose();
    _characterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(colors.pinkStart, Colors.white, 0.75)!,
              Color.lerp(colors.pinkEnd, Colors.white, 0.75)!,
            ],
          ),
        ),
        child: Stack(
          children: [
            // 배경 장식 원 (은은하게 숨쉬기)
            _BackgroundBlob(
              controller: _breatheController,
              alignment: const Alignment(-1.3, -1.0),
              size: 220,
            ),
            _BackgroundBlob(
              controller: _breatheController,
              alignment: const Alignment(1.3, 1.1),
              size: 260,
              reverse: true,
            ),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 캐릭터: 인사하듯 좌우로 까딱이며 살짝 들썩임
                  FadeTransition(
                    opacity: _wordmarkOpacity,
                    child: _WavingCharacter(controller: _characterController),
                  ),

                  const SizedBox(height: 18),

                  // 워드마크: 텍스트로고 이미지
                  SlideTransition(
                    position: _wordmarkSlide,
                    child: FadeTransition(
                      opacity: _wordmarkOpacity,
                      child: Image.asset(
                        'assets/images/textLogo.png',
                        height: 34,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  FadeTransition(
                    opacity: _wordmarkOpacity,
                    child: Text(
                      '목표를 세우고, 함께 공부하고',
                      style: TextStyle(
                        color: const Color(0xFF7A4A52).withOpacity(0.85),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  FadeTransition(
                    opacity: _dotsOpacity,
                    child: const _LoadingDots(color: Color(0xFF7A4A52)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundBlob extends StatelessWidget {
  final AnimationController controller;
  final Alignment alignment;
  final double size;
  final bool reverse;

  const _BackgroundBlob({
    required this.controller,
    required this.alignment,
    required this.size,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final t = reverse ? 1 - controller.value : controller.value;
          final scale = 1.0 + t * 0.12;
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.08),
          ),
        ),
      ),
    );
  }
}

class _WavingCharacter extends StatelessWidget {
  final AnimationController controller;

  const _WavingCharacter({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // -0.06 ~ 0.06 라디안 사이로 좌우 까딱임 (인사하는 느낌)
        final tilt = (controller.value - 0.5) * 0.12;
        // 살짝 위아래로도 들썩 (열공 텐션)
        final bounce = -6 * (1 - (controller.value - 0.5).abs() * 2);
        return Transform.translate(
          offset: Offset(0, bounce),
          child: Transform.rotate(
            angle: tilt,
            child: child,
          ),
        );
      },
      child: Image.asset(
        'assets/icons/character.png',
        width: 88,
        height: 88,
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  final Color color;

  const _LoadingDots({required this.color});

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final t = (_controller.value - i * 0.2) % 1.0;
            final bounce = (t < 0.5)
                ? Curves.easeOut.transform(t * 2)
                : Curves.easeIn.transform((1 - t) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.translate(
                offset: Offset(0, -10 * bounce),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.6 + 0.4 * bounce),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
