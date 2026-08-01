import 'package:flutter/material.dart';

import '../../theme.dart';
import '../services/notification_service.dart';

class NotificationEmptyView extends StatelessWidget {
  const NotificationEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return const NotificationMessageView(
      icon: Icons.notifications_none_rounded,
      title: '아직 알림이 없습니다.',
      description: '새로운 알림이 도착하면 이곳에서 확인할 수 있습니다.',
    );
  }
}

class NotificationMessageView extends StatelessWidget {
  const NotificationMessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.colors.pinkSoftAlt,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 36, color: context.colors.pinkDeep),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationList extends StatelessWidget {
  const NotificationList({
    super.key,
    required this.notifications,
    required this.onNotificationPressed,
  });

  final List<AppNotification> notifications;
  final ValueChanged<AppNotification> onNotificationPressed;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return NotificationCard(
          notification: notifications[index],
          onPressed: notifications[index].isNavigable
              ? () => onNotificationPressed(notifications[index])
              : null,
        );
      },
    );
  }
}

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    this.onPressed,
  });

  final AppNotification notification;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final createdAt = notification.createdAt;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.pinkSoftAlt,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              notification.opensCommunityPost
                  ? Icons.forum_outlined
                  : notification.opensFriends
                  ? Icons.people_outline_rounded
                  : notification.opensStudyPlan
                  ? Icons.checklist_rounded
                  : notification.opensStudyGroup
                  ? Icons.menu_book_rounded
                  : Icons.workspace_premium_outlined,
              color: context.colors.pinkDeep,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                if (notification.body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    notification.body,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _formatDateTime(createdAt),
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.border),
          ),
          child: card,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? '오전' : '오후';

    if (isToday) {
      return '오늘 $period $hour:$minute';
    }

    return '${local.year}.${local.month.toString().padLeft(2, '0')}.'
        '${local.day.toString().padLeft(2, '0')} $period $hour:$minute';
  }
}
