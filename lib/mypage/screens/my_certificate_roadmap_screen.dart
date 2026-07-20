
import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/app_state_views.dart';
// TODO: AI 담당자 저장 구조 확인 후 Firestore 연결
// 필요한 정보:
// 1. 컬렉션 경로
// 2. 직무명 필드
// 3. 추천 자격증 목록 필드
// 4. 자격증 순서 및 보유 여부 필드
class MyCertificateRoadmapScreen extends StatefulWidget {
  const MyCertificateRoadmapScreen({super.key});

  @override
  State<MyCertificateRoadmapScreen> createState() =>
      _MyCertificateRoadmapScreenState();
}

class _MyCertificateRoadmapScreenState
    extends State<MyCertificateRoadmapScreen> {
  // Firebase 연결 전 테스트용 임시 데이터
  //
  // 실제 연결 예정 경로 예시:
  // userCareerRoadmaps/{uid}/roadmaps/{roadmapId}
  final List<CertificateRoadmapItem> _roadmaps = [
    CertificateRoadmapItem(
      roadmapId: 'roadmap_001',
      jobName: 'QA',
      createdAt: DateTime(2026, 7, 20),
      certificates: const [
        RoadmapCertificateStep(
          order: 1,
          certificateName: 'ISTQB Foundation Level',
          description: '소프트웨어 테스팅의 기본 이론과 국제 표준을 익히는 입문 자격증입니다.',
          status: RoadmapStepStatus.completed,
        ),
        RoadmapCertificateStep(
          order: 2,
          certificateName: '정보처리기사',
          description: '소프트웨어 개발 전반의 기초 지식과 실무 이해도를 확인하는 자격증입니다.',
          status: RoadmapStepStatus.inProgress,
        ),
        RoadmapCertificateStep(
          order: 3,
          certificateName: 'ISTQB Advanced Level',
          description: '테스트 관리와 분석 등 심화된 품질 보증 역량을 확인하는 자격증입니다.',
          status: RoadmapStepStatus.pending,
        ),
      ],
    ),
    CertificateRoadmapItem(
      roadmapId: 'roadmap_002',
      jobName: '백엔드 개발자',
      createdAt: DateTime(2026, 7, 18),
      certificates: const [
        RoadmapCertificateStep(
          order: 1,
          certificateName: 'SQLD',
          description: '데이터 모델링과 SQL 활용 능력을 검증하는 데이터베이스 자격증입니다.',
          status: RoadmapStepStatus.completed,
        ),
        RoadmapCertificateStep(
          order: 2,
          certificateName: '정보처리기사',
          description: '소프트웨어 개발 전반의 기본 지식을 확인하는 국가기술자격입니다.',
          status: RoadmapStepStatus.pending,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '나의 자격증 로드맵',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGuideCard(),
              const SizedBox(height: 22),

              Row(
                children: [
                  const Text(
                    '저장한 로드맵',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_roadmaps.length}개',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF0788F),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              if (_roadmaps.isEmpty)
                _buildEmptyView()
              else
                ListView.separated(
                  itemCount: _roadmaps.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, _) =>
                  const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final CertificateRoadmapItem roadmap =
                    _roadmaps[index];

                    return _RoadmapSummaryCard(
                      roadmap: roadmap,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CertificateRoadmapDetailScreen(
                                  roadmap: roadmap,
                                ),
                          ),
                        );
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

  Widget _buildGuideCard() {
    return AppCard(
      backgroundColor: Colors.white,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFF19AAF),
                  Color(0xFF9B74F4),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              size: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Text(
              '직무와 보유 자격증을 기준으로 AI가 추천한 자격증 취득 순서를 확인할 수 있습니다.',
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: Color(0xFF666A73),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return const AppEmptyView(
      message: '저장된 자격증 로드맵이 없습니다.',
      description: 'AI 자격증 로드맵에서 직무를 입력하고\n추천 로드맵을 저장해 보세요.',
    );
  }
}

class _RoadmapSummaryCard extends StatelessWidget {
  final CertificateRoadmapItem roadmap;
  final VoidCallback onTap;

  const _RoadmapSummaryCard({
    required this.roadmap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final int completedCount = roadmap.certificates
        .where(
          (step) => step.status == RoadmapStepStatus.completed,
    )
        .length;

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCEFF3),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.route_outlined,
                      color: Color(0xFFF0788F),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${roadmap.jobName} 자격증 로드맵',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${roadmap.certificates.length}단계 · '
                              '${_formatDate(roadmap.createdAt)} 저장',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9AA0AC),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 17,
                    color: Color(0xFF9B74F4),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: roadmap.certificates.isEmpty
                      ? 0
                      : completedCount /
                      roadmap.certificates.length,
                  backgroundColor: const Color(0xFFF2EDF9),
                  valueColor:
                  const AlwaysStoppedAnimation<Color>(
                    Color(0xFFB17AE8),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Text(
                    '$completedCount/${roadmap.certificates.length}단계 완료',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7A7F89),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    roadmap.certificates.isEmpty
                        ? '0%'
                        : '${((completedCount / roadmap.certificates.length) * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF0788F),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: roadmap.certificates
                    .take(3)
                    .map(
                      (step) => _RoadmapChip(
                    text:
                    '${step.order}. ${step.certificateName}',
                    completed:
                    step.status ==
                        RoadmapStepStatus.completed,
                  ),
                )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.year}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class CertificateRoadmapDetailScreen extends StatelessWidget {
  final CertificateRoadmapItem roadmap;

  const CertificateRoadmapDetailScreen({
    super.key,
    required this.roadmap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '${roadmap.jobName} 로드맵',
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
            18,
            20,
            110,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '추천 자격증 로드맵',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${roadmap.jobName} 직무에 맞는 자격증을 취득 순서대로 정리했어요.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: Color(0xFF9AA0AC),
                ),
              ),
              const SizedBox(height: 22),

              ListView.separated(
                itemCount: roadmap.certificates.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, _) =>
                const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final RoadmapCertificateStep step =
                  roadmap.certificates[index];

                  return _RoadmapStepCard(step: step);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoadmapStepCard extends StatelessWidget {
  final RoadmapCertificateStep step;

  const _RoadmapStepCard({
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _stepBackgroundColor(step.status),
              shape: BoxShape.circle,
            ),
            child: step.status == RoadmapStepStatus.completed
                ? const Icon(
              Icons.check,
              color: Colors.white,
              size: 22,
            )
                : Text(
              '${step.order}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _stepTextColor(step.status),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        step.certificateName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    _StatusBadge(status: step.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  step.description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color: Color(0xFF8C93A2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _stepBackgroundColor(
      RoadmapStepStatus status,
      ) {
    switch (status) {
      case RoadmapStepStatus.completed:
        return const Color(0xFFE592A8);
      case RoadmapStepStatus.inProgress:
        return const Color(0xFFE9E1FF);
      case RoadmapStepStatus.pending:
        return const Color(0xFFF3F0FF);
    }
  }

  static Color _stepTextColor(
      RoadmapStepStatus status,
      ) {
    switch (status) {
      case RoadmapStepStatus.completed:
        return Colors.white;
      case RoadmapStepStatus.inProgress:
        return const Color(0xFF8B62E7);
      case RoadmapStepStatus.pending:
        return const Color(0xFF9B74F4);
    }
  }
}

class _RoadmapChip extends StatelessWidget {
  final String text;
  final bool completed;

  const _RoadmapChip({
    required this.text,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: completed
            ? const Color(0xFFF9E8ED)
            : const Color(0xFFF2EEFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: completed
              ? const Color(0xFFD96B88)
              : const Color(0xFF7D62C9),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final RoadmapStepStatus status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color backgroundColor;
    final Color textColor;

    switch (status) {
      case RoadmapStepStatus.completed:
        text = '취득 완료';
        backgroundColor = const Color(0xFFFCE7ED);
        textColor = const Color(0xFFD85E7F);
        break;
      case RoadmapStepStatus.inProgress:
        text = '준비 중';
        backgroundColor = const Color(0xFFEDE7FF);
        textColor = const Color(0xFF8660E5);
        break;
      case RoadmapStepStatus.pending:
        text = '추천';
        backgroundColor = const Color(0xFFF3F0F8);
        textColor = const Color(0xFF898491);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

enum RoadmapStepStatus {
  completed,
  inProgress,
  pending,
}

class CertificateRoadmapItem {
  final String roadmapId;
  final String jobName;
  final DateTime createdAt;
  final List<RoadmapCertificateStep> certificates;

  const CertificateRoadmapItem({
    required this.roadmapId,
    required this.jobName,
    required this.createdAt,
    required this.certificates,
  });
}

class RoadmapCertificateStep {
  final int order;
  final String certificateName;
  final String description;
  final RoadmapStepStatus status;

  const RoadmapCertificateStep({
    required this.order,
    required this.certificateName,
    required this.description,
    required this.status,
  });
}
