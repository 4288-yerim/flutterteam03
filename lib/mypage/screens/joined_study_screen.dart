import 'package:flutter/material.dart';

import '../../stydy/study_list.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/app_state_views.dart';

class JoinedStudyScreen extends StatefulWidget {
  const JoinedStudyScreen({super.key});

  @override
  State<JoinedStudyScreen> createState() => _JoinedStudyScreenState();
}

class _JoinedStudyScreenState extends State<JoinedStudyScreen> {
  // Firebase 연결 전 사용하는 임시 데이터
  final List<JoinedStudyData> _studies = [
    JoinedStudyData(
      id: 'study_001',
      title: '정보처리기사 실기 합격 스터디',
      certificateName: '정보처리기사',
      description: '주 3회 기출문제 풀이와 오답 정리를 진행합니다.',
      memberCount: 6,
      maxMemberCount: 8,
      progressPercent: 72,
      nextSchedule: '오늘 오후 8:00',
      role: StudyMemberRole.leader,
      status: JoinedStudyStatus.active,
    ),
    JoinedStudyData(
      id: 'study_002',
      title: 'SQLD 한 달 완성반',
      certificateName: 'SQLD',
      description: '개념 정리와 주말 모의고사 풀이를 함께합니다.',
      memberCount: 5,
      maxMemberCount: 6,
      progressPercent: 45,
      nextSchedule: '7월 16일 오후 7:30',
      role: StudyMemberRole.member,
      status: JoinedStudyStatus.active,
    ),
    JoinedStudyData(
      id: 'study_003',
      title: '컴퓨터활용능력 1급 실기',
      certificateName: '컴퓨터활용능력 1급',
      description: '엑셀과 액세스 실기 문제를 함께 연습합니다.',
      memberCount: 4,
      maxMemberCount: 5,
      progressPercent: 100,
      nextSchedule: '진행 일정 없음',
      role: StudyMemberRole.member,
      status: JoinedStudyStatus.completed,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final activeCount = _studies
        .where(
          (study) => study.status == JoinedStudyStatus.active,
    )
        .length;

    final completedCount = _studies
        .where(
          (study) => study.status == JoinedStudyStatus.completed,
    )
        .length;

    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppTopBar(
        title: '참여 중인 스터디',
        leading: IconButton(
          tooltip: '뒤로 가기',
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),

      body: AppMainBackground(
        child: _studies.isEmpty
            ? AppEmptyView(
            message: "참여 중인 스터디가 없습니다",
            description: "스터디를 찾아 함께 목표를 준비해 보세요",
            buttonText: "스터디 찾기",
            onButtonPressed: (){
              Navigator.push(
                context,
                MaterialPageRoute(
                builder: (context) => StudyListPage(),
                ),
              );
            }
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            110,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StudySummaryCard(
                totalCount: _studies.length,
                activeCount: activeCount,
                completedCount: completedCount,
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '내 스터디',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  Text(
                    '총 ${_studies.length}개',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9AA0AC),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _studies.length,
                separatorBuilder: (_, __) {
                  return const SizedBox(height: 12);
                },
                itemBuilder: (context, index) {
                  final study = _studies[index];

                  return _JoinedStudyCard(
                    study: study,
                    onTap: () {
                      _openStudyDetail(study);
                    },
                    onLeave: () {
                      _showLeaveDialog(study);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStudyDetail(JoinedStudyData study) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemporaryStudyDetailScreen(
          study: study,
        ),
      ),
    );
  }

  void _showLeaveDialog(JoinedStudyData study) {
    // if (study.role == StudyMemberRole.leader) {
    //   showDialog<void>(
    //     context: context,
    //     builder: (dialogContext) {
    //       return AlertDialog(
    //         backgroundColor: Colors.white,
    //         title: const Text(
    //           '스터디장 권한 확인',
    //           style: TextStyle(
    //             fontWeight: FontWeight.w700,
    //           ),
    //         ),
    //         content: const Text(
    //           '스터디장은 바로 나갈 수 없습니다.\n다른 멤버에게 스터디장 권한을 넘긴 후 나가 주세요.',
    //         ),
    //         actions: [
    //           TextButton(
    //             onPressed: () {
    //               Navigator.pop(dialogContext);
    //             },
    //             child: const Text(
    //               '확인',
    //               style: TextStyle(
    //                 color: Color(0xFFF0788F),
    //                 fontWeight: FontWeight.w700,
    //               ),
    //             ),
    //           ),
    //         ],
    //       );
    //     },
    //   );
    //
    //   return;
    // }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '스터디 나가기',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '"${study.title}" 스터디에서 나가시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF9AA0AC),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                setState(() {
                  _studies.removeWhere(
                        (item) => item.id == study.id,
                  );
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '스터디에서 나갔습니다.',
                    ),
                  ),
                );
              },
              child: const Text(
                '나가기',
                style: TextStyle(
                  color: Color(0xFFF0788F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StudySummaryCard extends StatelessWidget {
  final int totalCount;
  final int activeCount;
  final int completedCount;

  const _StudySummaryCard({
    required this.totalCount,
    required this.activeCount,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              icon: Icons.groups_outlined,
              label: '전체',
              value: '$totalCount개',
            ),
          ),
          const _SummaryDivider(),
          Expanded(
            child: _SummaryItem(
              icon: Icons.play_circle_outline,
              label: '진행 중',
              value: '$activeCount개',
            ),
          ),
          const _SummaryDivider(),
          Expanded(
            child: _SummaryItem(
              icon: Icons.check_circle_outline,
              label: '완료',
              value: '$completedCount개',
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinedStudyCard extends StatelessWidget {
  final JoinedStudyData study;
  final VoidCallback onTap;
  final VoidCallback onLeave;

  const _JoinedStudyCard({
    required this.study,
    required this.onTap,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            18,
            16,
            10,
            18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CertificateChip(
                    text: study.certificateName,
                  ),
                  const SizedBox(width: 8),
                  _StudyStatusChip(
                    status: study.status,
                  ),
                  const SizedBox(width: 8),
                  _MemberRoleChip(
                    role: study.role,
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: '스터디 메뉴',
                    color: Colors.white,
                    icon: const Icon(
                      Icons.more_vert,
                      size: 21,
                      color: Color(0xFF9AA0AC),
                    ),
                    onSelected: (value) {
                      if (value == 'leave') {
                        onLeave();
                      }
                    },
                    itemBuilder: (_) {
                      return const [
                        PopupMenuItem(
                          value: 'leave',
                          child: Row(
                            children: [
                              Icon(
                                Icons.logout,
                                size: 19,
                                color: Color(0xFFF0788F),
                              ),
                              SizedBox(width: 10),
                              Text(
                                '스터디 나가기',
                                style: TextStyle(
                                  color: Color(0xFFF0788F),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                study.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),

              const SizedBox(height: 7),

              Text(
                study.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF666A73),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 17,
                    color: Color(0xFF9AA0AC),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${study.memberCount}/${study.maxMemberCount}명',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666A73),
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Icon(
                    Icons.schedule_outlined,
                    size: 17,
                    color: Color(0xFF9AA0AC),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      study.nextSchedule,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666A73),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  const Text(
                    '진행률',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666A73),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${study.progressPercent}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF0788F),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 7),

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: study.progressPercent / 100,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFF0F0F2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFF0788F),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 21,
          color: const Color(0xFFF0788F),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9AA0AC),
          ),
        ),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      color: const Color(0xFFF0F0F2),
    );
  }
}

class _CertificateChip extends StatelessWidget {
  final String text;

  const _CertificateChip({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 120,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEFF3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF0788F),
        ),
      ),
    );
  }
}

class _StudyStatusChip extends StatelessWidget {
  final JoinedStudyStatus status;

  const _StudyStatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color backgroundColor;
    final Color textColor;

    switch (status) {
      case JoinedStudyStatus.active:
        text = '진행 중';
        backgroundColor = const Color(0xFFF1F7F3);
        textColor = const Color(0xFF4C9A65);

      case JoinedStudyStatus.completed:
        text = '완료';
        backgroundColor = const Color(0xFFF3F3F5);
        textColor = const Color(0xFF777B84);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _MemberRoleChip extends StatelessWidget {
  final StudyMemberRole role;

  const _MemberRoleChip({
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    if (role != StudyMemberRole.leader) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6DF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '스터디장',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFFD89422),
        ),
      ),
    );
  }
}

class _EmptyStudyView extends StatelessWidget {
  const _EmptyStudyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          24,
          80,
          24,
          40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFCEFF3),
              ),
              child: const Icon(
                Icons.groups_outlined,
                size: 40,
                color: Color(0xFFF0788F),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '참여 중인 스터디가 없습니다.',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '스터디를 찾아 함께 목표를 준비해 보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9AA0AC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum JoinedStudyStatus {
  active,
  completed,
}

enum StudyMemberRole {
  leader,
  member,
}

class JoinedStudyData {
  final String id;
  final String title;
  final String certificateName;
  final String description;
  final int memberCount;
  final int maxMemberCount;
  final int progressPercent;
  final String nextSchedule;
  final StudyMemberRole role;
  final JoinedStudyStatus status;

  const JoinedStudyData({
    required this.id,
    required this.title,
    required this.certificateName,
    required this.description,
    required this.memberCount,
    required this.maxMemberCount,
    required this.progressPercent,
    required this.nextSchedule,
    required this.role,
    required this.status,
  });
}

/// 실제 스터디 상세 화면이 완성되기 전 사용하는 임시 상세 화면
class TemporaryStudyDetailScreen extends StatelessWidget {
  final JoinedStudyData study;

  const TemporaryStudyDetailScreen({
    super.key,
    required this.study,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppTopBar(
        title: '스터디 상세',
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),

      body: AppMainBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            110,
          ),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CertificateChip(
                  text: study.certificateName,
                ),

                const SizedBox(height: 14),

                Text(
                  study.title,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  study.description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: Color(0xFF44474E),
                  ),
                ),

                const SizedBox(height: 24),

                const Divider(
                  color: Color(0xFFF0F0F2),
                ),

                const SizedBox(height: 20),

                _DetailRow(
                  icon: Icons.people_outline,
                  label: '참여 인원',
                  value:
                  '${study.memberCount}/${study.maxMemberCount}명',
                ),

                const SizedBox(height: 14),

                _DetailRow(
                  icon: Icons.schedule_outlined,
                  label: '다음 일정',
                  value: study.nextSchedule,
                ),

                const SizedBox(height: 14),

                _DetailRow(
                  icon: Icons.percent,
                  label: '진행률',
                  value: '${study.progressPercent}%',
                ),

                const SizedBox(height: 28),

                const Text(
                  '스터디 상세 기능은 스터디 그룹 화면 구현 후 연결됩니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9AA0AC),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: const Color(0xFFF0788F),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF666A73),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}