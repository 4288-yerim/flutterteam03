import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 원형 안에서 물결이 차오르는 로딩 인디케이터.
/// [progress]가 바뀔 때마다 이전 값에서 새 값으로 부드럽게 채워지고,
/// 물결 표면은 계속 움직입니다.
///
/// 여러 페이지(자격증 로드맵, 학습 플랜, 문제 생성 등)에서 공통으로 사용합니다.
// 변경 — useSmoothing 파라미터 추가
class WaveLoadingIndicator extends StatefulWidget {
  final double size;
  final double progress; // 0(빔) ~ 1(가득 참) — 목표 채움 정도
  final Color backgroundColor;
  final Color waveColorStart;
  final Color waveColorEnd;

  /// true: 목표치가 바뀔 때마다 부드럽게 뒤쫓아가며 채움.
  /// 메시지 전환처럼 목표가 "띄엄띄엄" 바뀌는 경우에 적합.
  ///
  /// false: progress 값을 그대로 즉시 반영. 이미 부드럽게 움직이는
  /// AnimationController(예: 로딩 진행률 컨트롤러)의 값을 매 프레임
  /// 그대로 넘기는 경우에는 이 모드를 써야 물결이 목표를 따라잡지 못하고
  /// 계속 뒤처지는 문제가 생기지 않는다.
  final bool useSmoothing;

  const WaveLoadingIndicator({
    super.key,
    this.size = 72,
    required this.progress,
    required this.backgroundColor,
    required this.waveColorStart,
    required this.waveColorEnd,
    this.useSmoothing = true,
  });

  @override
  State<WaveLoadingIndicator> createState() => _WaveLoadingIndicatorState();
}

class _WaveLoadingIndicatorState extends State<WaveLoadingIndicator>
    with TickerProviderStateMixin {
  AnimationController? _levelController;
  Animation<double>? _levelAnimation;
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    if (widget.useSmoothing) {
      _levelController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      );
      _levelAnimation = Tween<double>(begin: 0, end: widget.progress).animate(
        CurvedAnimation(parent: _levelController!, curve: Curves.easeOut),
      );
      _levelController!.forward();
    }

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant WaveLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.useSmoothing) return;
    if (oldWidget.progress != widget.progress) {
      _levelAnimation = Tween<double>(
        begin: _levelAnimation!.value,
        end: widget.progress,
      ).animate(CurvedAnimation(parent: _levelController!, curve: Curves.easeOut));
      _levelController!
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _levelController?.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: AnimatedBuilder(
          animation: widget.useSmoothing
              ? Listenable.merge([_levelController!, _waveController])
              : _waveController,
          builder: (context, _) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _WavePainter(
                level: widget.useSmoothing ? _levelAnimation!.value : widget.progress,
                wavePhase: _waveController.value,
                bgColor: widget.backgroundColor,
                waveColorStart: widget.waveColorStart,
                waveColorEnd: widget.waveColorEnd,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double level; // 0(빈 상태) ~ 1(가득 참), 목표치까지 부드럽게 차오름
  final double wavePhase; // 물결 표면 움직임용, 0~1 반복
  final Color bgColor;
  final Color waveColorStart;
  final Color waveColorEnd;

  const _WavePainter({
    required this.level,
    required this.wavePhase,
    required this.bgColor,
    required this.waveColorStart,
    required this.waveColorEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final baseY = size.height * (1 - level);
    final waveHeight = size.height * 0.045;

    final path = Path()..moveTo(0, baseY);
    for (double x = 0; x <= size.width; x += 2) {
      final y = baseY +
          math.sin((x / size.width * 2 * math.pi) + wavePhase * 2 * math.pi) *
              waveHeight;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    final wavePaint = Paint()
      ..shader = LinearGradient(
        colors: [waveColorStart, waveColorEnd],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.level != level || oldDelegate.wavePhase != wavePhase;
}