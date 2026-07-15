import 'package:flutter/material.dart';
import '../../theme.dart';

class StepIndicator extends StatefulWidget {
  final int currentStep; // 1, 2, 3
  final int totalSteps;
  final String label;
  final AppColors colors;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.label,
    required this.colors,
    this.totalSteps = 3,
  });

  @override
  State<StepIndicator> createState() => _StepIndicatorState();
}

class _StepIndicatorState extends State<StepIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.totalSteps, (i) {
            final isCurrent = i == widget.currentStep - 1;
            final isDone = i < widget.currentStep - 1;

            // 점마다 살짝 다른 타이밍으로 등장하도록 stagger
            final start = (i * 0.15).clamp(0.0, 1.0);
            final end = (start + 0.5).clamp(0.0, 1.0);
            final curved = CurvedAnimation(
              parent: _entryController,
              curve: Interval(start, end, curve: Curves.easeOutBack),
            );

            return AnimatedBuilder(
              animation: Listenable.merge([curved, _pulseController]),
              builder: (context, child) {
                final entryScale = curved.value.clamp(0.0, 1.2);
                final pulseGlow = isCurrent ? _pulseController.value : 0.0;

                return Transform.scale(
                  scale: entryScale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: isCurrent ? 26 : 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: isCurrent || isDone
                            ? colors.pinkStart
                            : colors.textSecondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: isCurrent
                            ? [
                          BoxShadow(
                            color: colors.pinkStart
                                .withOpacity(0.35 + pulseGlow * 0.25),
                            blurRadius: 8 + pulseGlow * 6,
                            spreadRadius: pulseGlow * 1.2,
                          ),
                        ]
                            : [],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
        const SizedBox(height: 12),
        FadeTransition(
          opacity: CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}