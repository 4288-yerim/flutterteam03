import 'dart:ui';
import 'package:flutter/material.dart';

/// 메인 화면(홈, 목록 등)에서 쓰는 배경 위젯
///
/// 로그인/회원가입용 `AppBackground`와 달리, 두 개의 블러 원이
/// 화면 상단(좌측 상단 핑크, 우측 상단 보라)에만 작게 배치됩니다.
///
/// 사용 예시:
/// ```dart
/// Scaffold(
///   extendBodyBehindAppBar: true,
///   appBar: AppTopBar(title: '내 스터디'),
///   body: AppMainBackground(
///     child: YourPageContent(),
///   ),
/// )
/// ```
class AppMainBackground extends StatelessWidget {
  final Widget child;

  /// 블러 원(blob) 표시 여부
  final bool showBlobs;

  /// 내용(child)에 SafeArea를 적용할지 여부
  final bool applySafeArea;

  const AppMainBackground({
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
      color: const Color(0xFFFFFDFC), // 아주 옅은 화이트 배경
      child: Stack(
        children: [
          if (showBlobs) ...[
            // 좌측 상단 연분홍색 블러 원
            Positioned(
              top: size.width * 0.25,
              left: size.width * 0.01,
              child: _BlurBlob(
                diameter: size.width * 0.3,
                color: const Color(0x66FCE7EF), // 연분홍
              ),
            ),
            // 우측 상단 연보라색 블러 원
            Positioned(
              top: size.width * 0.05,
              right: -size.width * 0.05,
              child: _BlurBlob(
                diameter: size.width * 0.45,
                color: const Color(0x66E8E4FB), // 연보라
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