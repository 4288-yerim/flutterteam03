import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../services/notification_service.dart';

class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({
    super.key,
    required this.onPressed,
    this.notificationService,
  });

  final VoidCallback onPressed;
  final NotificationService? notificationService;

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  Stream<bool>? _hasNewNotificationsStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _hasNewNotificationsStream =
          (widget.notificationService ?? NotificationService())
              .watchHasNewNotifications(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _hasNewNotificationsStream;
    if (stream == null) {
      return _BellIcon(onPressed: widget.onPressed, showBadge: false);
    }

    return StreamBuilder<bool>(
      stream: stream,
      initialData: false,
      builder: (context, snapshot) {
        return _BellIcon(
          onPressed: widget.onPressed,
          showBadge: snapshot.data ?? false,
        );
      },
    );
  }
}

class _BellIcon extends StatelessWidget {
  const _BellIcon({required this.onPressed, required this.showBadge});

  final VoidCallback onPressed;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '알림',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            color: context.colors.iconPrimary,
          ),
          if (showBadge)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.colors.incorrect,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.surface, width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
