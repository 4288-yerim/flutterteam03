import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../utils/study_time_formatter.dart';

class MyPageSummaryCard extends StatelessWidget {
  final int studySeconds;
  final int studyGroupCount;
  final int postCount;

  final VoidCallback onStudyTap;
  final VoidCallback onGroupTap;
  final VoidCallback onPostTap;

  const MyPageSummaryCard({
    super.key,
    required this.studySeconds,
    required this.studyGroupCount,
    required this.postCount,
    required this.onStudyTap,
    required this.onGroupTap,
    required this.onPostTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 20,
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              icon: Icons.timer_outlined,
              title: '이번 주 학습',
              value: formatStudyTime(studySeconds),
              onTap: onStudyTap,
            ),
          ),
          const _VerticalSummaryDivider(),
          Expanded(
            child: _SummaryItem(
              icon: Icons.groups_outlined,
              title: '참여 스터디',
              value: '$studyGroupCount개',
              onTap: onGroupTap,
            ),
          ),
          const _VerticalSummaryDivider(),
          Expanded(
            child: _SummaryItem(
              icon: Icons.article_outlined,
              title: '내가 쓴 글',
              value: '$postCount개',
              onTap: onPostTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SummaryItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 4,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: const Color(0xFFF0788F),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9AA0AC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalSummaryDivider extends StatelessWidget {
  const _VerticalSummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 54,
      color: const Color(0xFFF0F0F2),
    );
  }
}
