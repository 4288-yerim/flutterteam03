import 'package:flutter/material.dart';

import '../theme.dart';

class AppLoadingView extends StatelessWidget {
  final String message;
  final String imagePath;

  const AppLoadingView({
    super.key,
    this.message = '데이터를 불러오는 중입니다.',
    this.imagePath = 'assets/images/loading_state_transparent.png',
  });

  @override
  Widget build(BuildContext context) {
    return AppStateViewLayout(
      imagePath: imagePath,
      message: message,
      showProgressIndicator: true,
    );
  }
}

class AppEmptyView extends StatelessWidget {
  final String imagePath;
  final String message;
  final String? description;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final bool scrollable;
  final double imageWidth;
  final double imageHeight;
  final EdgeInsetsGeometry padding;

  const AppEmptyView({
    super.key,
    this.imagePath = 'assets/images/empty_state_transparent.png',
    required this.message,
    this.description,
    this.buttonText,
    this.onButtonPressed,
    this.scrollable = true,
    this.imageWidth = 240,
    this.imageHeight = 240,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
  });

  @override
  Widget build(BuildContext context) {
    return AppStateViewLayout(
      imagePath: imagePath,
      message: message,
      description: description,
      buttonText: buttonText,
      onButtonPressed: onButtonPressed,
      scrollable: scrollable,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      padding: padding,
    );
  }
}

class AppErrorView extends StatelessWidget {
  final String imagePath;
  final String message;
  final String? description;
  final String retryButtonText;
  final VoidCallback? onRetryPressed;

  const AppErrorView({
    super.key,
    this.imagePath = 'assets/images/error_state_transparent.png',
    this.message = '오류가 발생했습니다.',
    this.description = '잠시 후 다시 시도해 주세요.',
    this.retryButtonText = '다시 시도',
    this.onRetryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppStateViewLayout(
      imagePath: imagePath,
      message: message,
      description: description,
      buttonText: onRetryPressed == null ? null : retryButtonText,
      onButtonPressed: onRetryPressed,
    );
  }
}

class AppNetworkErrorView extends StatelessWidget {
  final String imagePath;
  final String message;
  final String? description;
  final String retryButtonText;
  final VoidCallback? onRetryPressed;

  const AppNetworkErrorView({
    super.key,
    this.imagePath = 'assets/images/network_error_transparent.png',
    this.message = '인터넷 연결을 확인해 주세요.',
    this.description = 'Wi-Fi 또는 모바일 데이터를 확인한 뒤 다시 시도해 주세요.',
    this.retryButtonText = '다시 시도',
    this.onRetryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppStateViewLayout(
      imagePath: imagePath,
      message: message,
      description: description,
      buttonText: onRetryPressed == null ? null : retryButtonText,
      onButtonPressed: onRetryPressed,
    );
  }
}

class AppStateViewLayout extends StatelessWidget {
  final String imagePath;
  final String message;
  final String? description;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final bool showProgressIndicator;
  final bool scrollable;
  final double imageWidth;
  final double imageHeight;
  final EdgeInsetsGeometry padding;

  const AppStateViewLayout({
    super.key,
    required this.imagePath,
    required this.message,
    this.description,
    this.buttonText,
    this.onButtonPressed,
    this.showProgressIndicator = false,
    this.scrollable = true,
    this.imageWidth = 240,
    this.imageHeight = 240,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          imagePath,
          width: imageWidth,
          height: imageHeight,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 20),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        if (description != null && description!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            description!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: colors.textSecondary,
            ),
          ),
        ],
        if (showProgressIndicator) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: colors.info,
            ),
          ),
        ],
        if (buttonText != null &&
            buttonText!.trim().isNotEmpty &&
            onButtonPressed != null) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.info,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonText!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return Center(
      child: scrollable
          ? SingleChildScrollView(padding: padding, child: content)
          : Padding(padding: padding, child: content),
    );
  }
}
