import 'package:flutter/material.dart';

/// 앱 전체에서 재사용하는 기본 카드 (Radius 22 / Shadow Soft)
///
/// 사용 예시 1 - 제목/설명만 필요한 경우:
/// ```dart
/// AppCard(
///   title: '기본 카드',
///   subtitle: 'Radius 22 / Shadow Soft',
/// )
/// ```
///
/// 사용 예시 2 - 자유로운 내용을 넣고 싶은 경우:
/// ```dart
/// AppCard(
///   child: Column(
///     children: [ ... ],
///   ),
/// )
/// ```
class AppCard extends StatelessWidget {
  /// 제목만 넣고 싶을 때 사용 (child와 함께 쓰지 않는 걸 권장)
  final String? title;
  final String? subtitle;

  /// 자유롭게 내용을 넣고 싶을 때 사용. 지정하면 title/subtitle 대신 이게 표시됨
  final Widget? child;

  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;

  const AppCard({
    super.key,
    this.title,
    this.subtitle,
    this.child,
    this.borderRadius = 22,
    this.padding = const EdgeInsets.all(24),
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Text(
                  title!,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              if (title != null && subtitle != null) const SizedBox(height: 6),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF9AA0AC)),
                ),
            ],
          ),
    );
  }
}