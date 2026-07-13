import 'dart:ui';
import 'package:flutter/material.dart';

/// 앱 전체에서 재사용하는 배경 위젯
///
/// 사용 예시:
/// ```dart
/// Scaffold(
///   body: AppBackground(
///     child: YourPageContent(),
///   ),
/// )
/// ```
class AppBackground extends StatelessWidget {
  final Widget child;

  /// 블러 원(blob) 표시 여부. 필요 없으면 false로 끄면 됩니다.
  final bool showBlobs;

  /// 내용(child)에 SafeArea를 적용할지 여부.
  /// true면 상태바/노치/앱바 영역을 피해서 내용이 배치됩니다.
  /// (블러 원 배경 자체는 이 설정과 상관없이 화면 끝까지 퍼집니다)
  final bool applySafeArea;

  const AppBackground({
    super.key,
    required this.child,
    this.showBlobs = true,
    this.applySafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFFFFDFC), // 이미지의 아주 옅은 화이트 배경
      child: Stack(
        children: [
          if (showBlobs) ...[
            // 우측 상단 연보라색 블러 원
            Positioned(
              top: size.width * 0.1,
              right: -size.width * 0.1,
              child: _BlurBlob(
                diameter: size.width * 0.5,
                color: const Color(0x66E8E4FB), // 연보라
              ),
            ),
            // 좌측 하단 연분홍색 블러 원
            Positioned(
              bottom: size.width * 0.2,
              left: -size.width * 0.1,
              child: _BlurBlob(
                diameter: size.width * 0.5,
                color: const Color(0x66FCE7EF), // 연분홍
              ),
            ),
          ],
          // 실제 화면 콘텐츠 (배경과 달리 상태바/앱바를 침범하지 않도록 SafeArea 적용)
          applySafeArea ? SafeArea(child: child) : child,
        ],
      ),
    );
  }
}

/// 흐릿하게 퍼지는 원형(blob) 하나를 그리는 내부 위젯
class _BlurBlob extends StatelessWidget {
  final double diameter;
  final Color color;

  const _BlurBlob({
    required this.diameter,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}