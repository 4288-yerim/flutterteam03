import 'package:flutter/material.dart';

import '../services/admin_member_service.dart';

class AdminCommunityCategoryTabs extends StatelessWidget {
  const AdminCommunityCategoryTabs({
    super.key,
    required this.activities,
    required this.selectedBoard,
    required this.onSelected,
  });

  static const boards = [
    'ALL',
    'FREE',
    'QUESTION',
    'PASS_REVIEW',
    'EXAM_REVIEW',
    'STUDY_SHARE',
    'BOOK_REVIEW',
    'TIP',
    'GROUP_RECRUIT',
  ];

  final List<AdminCommunityActivity> activities;
  final String selectedBoard;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        scrollDirection: Axis.horizontal,
        itemCount: boards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final board = boards[index];
          final count = board == 'ALL'
              ? activities.length
              : activities.where((item) => item.boardType == board).length;
          final selected = board == selectedBoard;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            label: Text('${adminBoardLabel(board)}($count)'),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF5D5962),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            selectedColor: const Color(0xFF6C63FF),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE2DFE6)),
            onSelected: (_) => onSelected(board),
          );
        },
      ),
    );
  }
}

class AdminCommunityActivityTile extends StatelessWidget {
  const AdminCommunityActivityTile({
    super.key,
    required this.activity,
    required this.onTap,
  });

  final AdminCommunityActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF29292E),
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0EDFF),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            adminBoardLabel(activity.boardType),
                            style: const TextStyle(
                              color: Color(0xFF5D54D6),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          adminActivityDate(activity.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF99949E),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF99949E)),
            ],
          ),
        ),
      ),
    );
  }
}

String adminBoardLabel(String board) => switch (board) {
  'ALL' => '전체',
  'FREE' => '자유',
  'QUESTION' => '질문',
  'PASS_REVIEW' => '합격 후기',
  'EXAM_REVIEW' => '시험 후기',
  'STUDY_SHARE' => '학습 자료',
  'BOOK_REVIEW' => '교재·인강',
  'TIP' => '학습 팁',
  'GROUP_RECRUIT' => '스터디 모집',
  _ => board,
};

String adminActivityDate(DateTime? value) {
  if (value == null) return '날짜 정보 없음';
  return '${value.year}.${value.month.toString().padLeft(2, '0')}.'
      '${value.day.toString().padLeft(2, '0')}';
}
