import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme.dart';

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
    final colors = context.colors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          width: size.width,
          height: size.height,
          child: Container(
            color: colors.background,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (showBlobs) ...[
                  Positioned(
                    top: size.width * 0.25,
                    left: size.width * 0.01,
                    child: _BlurBlob(
                      diameter: size.width * 0.3,
                      color: colors.backgroundBlobPink,
                    ),
                  ),
                  Positioned(
                    top: size.width * 0.05,
                    right: -size.width * 0.05,
                    child: _BlurBlob(
                      diameter: size.width * 0.45,
                      color: colors.backgroundBlobLavender,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned.fill(child: applySafeArea ? SafeArea(child: child) : child),
      ],
    );
  }
}

/// 흐릿하게 퍼지는 원형(blob) 하나를 그리는 내부 위젯
class _BlurBlob extends StatelessWidget {
  final double diameter;
  final Color color;

  const _BlurBlob({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
