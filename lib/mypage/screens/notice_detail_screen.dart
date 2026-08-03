import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../models/notice_models.dart';

class NoticeDetailScreen extends StatelessWidget {
  final List<NoticeItem> notices;
  final int index;

  const NoticeDetailScreen({super.key, required this.notices, required this.index});

  NoticeItem get notice => notices[index];
  bool get hasPrev => index > 0;
  bool get hasNext => index < notices.length - 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(title: '공지사항 상세'),
      body: AppMainBackground(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.surface.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: context.colors.shadow, blurRadius: 14, offset: Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (notice.isPinned) ...[
                          Icon(Icons.push_pin_rounded, size: 14, color: context.colors.pinkStart),
                          SizedBox(width: 6),
                        ],
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: notice.noticeType.badgeBg(context),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            notice.noticeType.label,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: notice.noticeType.badgeFg(context)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      notice.title,
                      style: TextStyle(fontSize: 19, height: 1.4, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _formatDate(notice.publishedAt ?? notice.createdAt),
                      style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                    ),
                    SizedBox(height: 18),
                    Divider(height: 1, color: context.colors.divider),
                    SizedBox(height: 18),
                    Text(
                      notice.content,
                      style: TextStyle(fontSize: 14, height: 1.65, color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18),
              _buildNavRow(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavRow(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: context.colors.shadow, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          _navTile(
            context,
            icon: Icons.expand_less_rounded,
            label: '이전 글',
            title: hasPrev ? notices[index - 1].title : null,
            onTap: hasPrev
                ? () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => NoticeDetailScreen(notices: notices, index: index - 1),
              ),
            )
                : null,
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: context.colors.divider),
          _navTile(
            context,
            icon: Icons.expand_more_rounded,
            label: '다음 글',
            title: hasNext ? notices[index + 1].title : null,
            onTap: hasNext
                ? () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => NoticeDetailScreen(notices: notices, index: index + 1),
              ),
            )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _navTile(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String? title,
        required VoidCallback? onTap,
      }) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: enabled ? context.colors.pinkStart : context.colors.textMuted),
            SizedBox(width: 10),
            SizedBox(
              width: 52,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: enabled ? context.colors.textPrimary : context.colors.textMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title ?? '없습니다',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: enabled ? context.colors.textSecondary : context.colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}.$month.$day $hour:$minute';
  }
}