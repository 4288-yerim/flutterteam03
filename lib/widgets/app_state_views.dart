import 'package:flutter/material.dart';

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

  const AppEmptyView({
    super.key,
    this.imagePath = 'assets/images/empty_state_transparent.png',
    required this.message,
    this.description,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppStateViewLayout(
      imagePath: imagePath,
      message: message,
      description: description,
      buttonText: buttonText,
      onButtonPressed: onButtonPressed,
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

  const AppStateViewLayout({
    super.key,
    required this.imagePath,
    required this.message,
    this.description,
    this.buttonText,
    this.onButtonPressed,
    this.showProgressIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              imagePath,
              width: 240,
              height: 240,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF24324A),
              ),
            ),
            if (description != null && description!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF6F7C91),
                ),
              ),
            ],
            if (showProgressIndicator) ...[
              const SizedBox(height: 24),
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF4F7DF3),
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
                    backgroundColor: const Color(0xFF4F7DF3),
                    foregroundColor: Colors.white,
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
        ),
      ),
    );
  }
}
