import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../main_page.dart';
import '../../theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkSlide;
  late final Animation<double> _dotsOpacity;

  late final AnimationController _breatheController;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );

    _wordmarkOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
    );
    _wordmarkSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _dotsOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    );

    // 배경 블롭 은은하게 숨쉬는 애니메이션
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _controller.forward();
    _goNext();
  }

  Future<void> _goNext() async {
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    final nextScreen = user == null
        ? const WelcomeScreen()
        : const MainPage();

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
            colors: [colors.pinkStart, colors.pinkEnd],
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
                  // 로고: 흰 카드 없이 은은한 글로우 위에 배치
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: AnimatedBuilder(
                      animation: _breatheController,
                      builder: (context, child) {
                        final scale = 1.0 + _breatheController.value * 0.04;
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: SizedBox(
                        width: 168,
                        height: 168,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 은은한 글로우 링
                            Container(
                              width: 168,
                              height: 168,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.22),
                                    Colors.white.withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                            // 로고 카드 (반투명 유리 느낌)
                            Container(
                              width: 116,
                              height: 116,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.35),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Image.asset('assets/splash/logo.png'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

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
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  FadeTransition(
                    opacity: _dotsOpacity,
                    child: const _LoadingDots(),
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

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

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
                    color: Colors.white.withOpacity(0.6 + 0.4 * bounce),
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