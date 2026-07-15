import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 배경이 투명한 상단 앱바
///
/// 사용 예시:
/// ```dart
/// Scaffold(
///   extendBodyBehindAppBar: true, // 필수! 이게 있어야 body 배경이 앱바 뒤까지 이어짐
///   appBar: AppTopBar(
///     title: '제목',
///   ),
///   body: AppBackground(
///     child: YourContent(),
///   ),
/// )
/// ```
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final TextStyle? titleStyle;

  const AppTopBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
      titleSpacing: 24,
      title: title != null
          ? Text(
        title!,
        style: titleStyle ??
            const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
      )
          : null,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}