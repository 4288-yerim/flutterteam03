import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

class LoadingOverlay extends StatefulWidget {
  const LoadingOverlay({super.key});

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _orbitController;
  late final AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>();
    final pinkStart = colors?.pinkStart ?? const Color(0xFFFF7E9C);
    final pinkEnd = colors?.pinkEnd ?? const Color(0xFFFF5C8A);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 흐림 처리된 반투명 배경
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(color: Colors.black.withOpacity(0.18)),
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _entryController,
                curve: Curves.easeOutBack,
              ),
              child: FadeTransition(
                opacity: _entryController,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: pinkStart.withOpacity(0.25),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: AnimatedBuilder(
                        animation: _orbitController,
                        builder: (context, _) {
                          return Stack(
                            alignment: Alignment.center,
                            children: List.generate(3, (i) {
                              final phase = i * (2 * math.pi / 3);
                              final t =
                                  _orbitController.value * 2 * math.pi + phase;
                              const radius = 16.0;
                              final dx = radius * math.cos(t);
                              final dy = radius * math.sin(t);

                              // 궤도를 따라 크기/투명도가 파동처럼 변함
                              final pulse =
                                  (math.sin(t - phase * 0) + 1) / 2; // 0~1
                              final scale = 0.55 + pulse * 0.65;
                              final opacity = 0.45 + pulse * 0.55;

                              return Transform.translate(
                                offset: Offset(dx, dy),
                                child: Opacity(
                                  opacity: opacity,
                                  child: Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [pinkStart, pinkEnd],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}