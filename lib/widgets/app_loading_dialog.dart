import 'package:flutter/material.dart';

import '../theme.dart';

/// 앱 전역에서 쓰는 공통 로딩 다이얼로그.
///
/// 자료 업로드, 요약 생성, 파일 정리 등 여러 화면에서 거의 동일한 모양의
/// "스피너 + 제목 + 설명" 다이얼로그를 각자 복붙해서 쓰고 있었는데,
/// 이 위젯 하나로 합쳐서 모양이 어긋나지 않도록 합니다.
class AppLoadingDialog extends StatelessWidget {
  final String title;
  final String? description;

  const AppLoadingDialog({
    super.key,
    required this.title,
    this.description,
  });

  /// 로딩 다이얼로그를 띄웁니다. 뒤로가기로 닫히지 않으며,
  /// 닫으려면 [close]를 호출해야 합니다.
  static Future<void> show(
      BuildContext context, {
        required String title,
        String? description,
      }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AppLoadingDialog(title: title, description: description),
      ),
    );
  }

  /// 현재 떠 있는 최상단 다이얼로그(로딩)를 닫습니다.
  static void close(BuildContext context) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: AppColors.pink,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 9),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}