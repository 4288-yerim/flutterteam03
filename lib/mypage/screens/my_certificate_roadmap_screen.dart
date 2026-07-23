import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../ai/certificate_roadmap.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/app_state_views.dart';

class MyCertificateRoadmapScreen extends StatefulWidget {
  const MyCertificateRoadmapScreen({super.key});

  @override
  State<MyCertificateRoadmapScreen> createState() =>
      _MyCertificateRoadmapScreenState();
}

class _MyCertificateRoadmapScreenState
    extends State<MyCertificateRoadmapScreen> {
  final List<CertificateRoadmapItem> _roadmaps = [];

  bool _isLoading = true;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadRoadmaps();
  }

  Future<void> _loadRoadmaps() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '로그인 정보를 확인할 수 없습니다.';
        _roadmaps.clear();
      });

      return;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('roadmaps')
          .orderBy('createdAt', descending: true)
          .get();

      final List<CertificateRoadmapItem> loadedRoadmaps = [];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
      in snapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final List<dynamic> certificateData =
            data['certificates'] as List<dynamic>? ?? [];

        final List<RoadmapCertificateStep> certificates = [];

        for (final dynamic item in certificateData) {
          if (item is! Map) {
            continue;
          }

          final Map<String, dynamic> certificate =
          Map<String, dynamic>.from(item);

          certificates.add(
            RoadmapCertificateStep(
              order: _readInt(certificate['order']),
              certificateName:
              certificate['name']?.toString() ?? '자격증명 없음',
              description:
              certificate['description']?.toString() ?? '',
              examDate:
              certificate['examDate']?.toString() ?? '-',
              registrationPeriod:
              certificate['registrationPeriod']?.toString() ?? '-',
              isEstimated:
              certificate['isEstimated'] == true,
            ),
          );
        }

        certificates.sort(
              (
              RoadmapCertificateStep first,
              RoadmapCertificateStep second,
              ) {
            return first.order.compareTo(second.order);
          },
        );

        DateTime? createdAt;
        final dynamic createdAtValue = data['createdAt'];

        if (createdAtValue is Timestamp) {
          createdAt = createdAtValue.toDate();
        }

        loadedRoadmaps.add(
          CertificateRoadmapItem(
            roadmapId: document.id,
            jobName: data['job']?.toString() ?? '직무 정보 없음',
            createdAt: createdAt,
            certificates: certificates,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;

        _roadmaps
          ..clear()
          ..addAll(loadedRoadmaps);
      });
    } catch (error) {
      debugPrint('나의 자격증 로드맵 조회 오류: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '저장한 로드맵을 불러오지 못했습니다.';
        _roadmaps.clear();
      });
    }
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _openAiRoadmapScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CertificateRoadmapPage(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _loadRoadmaps();
  }

  Future<void> _showDeleteDialog(
      CertificateRoadmapItem roadmap,
      ) async {
    if (_isDeleting) {
      return;
    }

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('로드맵 삭제'),
          content: Text(
            '${roadmap.jobName} 자격증 로드맵을 삭제하시겠습니까?\n'
                '삭제한 로드맵은 복구할 수 없습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await _deleteRoadmap(roadmap);
  }

  Future<void> _deleteRoadmap(
      CertificateRoadmapItem roadmap,
      ) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('로그인 정보를 확인할 수 없습니다.');
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('roadmaps')
          .doc(roadmap.roadmapId)
          .delete();

      if (!mounted) {
        return;
      }

      setState(() {
        _roadmaps.removeWhere(
              (CertificateRoadmapItem item) {
            return item.roadmapId == roadmap.roadmapId;
          },
        );
      });

      _showMessage('로드맵을 삭제했습니다.');
    } catch (error) {
      debugPrint('자격증 로드맵 삭제 오류: $error');

      if (!mounted) {
        return;
      }

      _showMessage('로드맵을 삭제하지 못했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

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
        child: RefreshIndicator(
          onRefresh: _loadRoadmaps,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              110,
            ),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingView(
        message: '저장한 로드맵을 불러오는 중입니다.',
      );
    }

    if (_errorMessage != null) {
      return AppErrorView(
        message: '로드맵을 불러오지 못했습니다.',
        description: _errorMessage,
        onRetryPressed: () {
          setState(() {
            _isLoading = true;
            _errorMessage = null;
          });

          _loadRoadmaps();
        },
      );
    }

    if (_roadmaps.isEmpty) {
      return AppEmptyView(
        message: '저장된 자격증 로드맵이 없습니다.',
        description: 'AI 자격증 로드맵에서 원하는 직무를 입력하고\n추천 로드맵을 만들어 보세요.',
        buttonText: 'AI 자격증 로드맵 만들기',
        onButtonPressed: _openAiRoadmapScreen,
      );
    }

    return Column(
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
        ListView.separated(
          itemCount: _roadmaps.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, _) {
            return const SizedBox(height: 16);
          },
          itemBuilder: (context, index) {
            final CertificateRoadmapItem roadmap =
            _roadmaps[index];

            return _RoadmapSummaryCard(
              roadmap: roadmap,
              isDeleting: _isDeleting,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) {
                      return CertificateRoadmapDetailScreen(
                        roadmap: roadmap,
                      );
                    },
                  ),
                );
              },
              onDelete: () {
                _showDeleteDialog(roadmap);
              },
            );
          },
        ),
      ],
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
}

class _RoadmapSummaryCard extends StatelessWidget {
  final CertificateRoadmapItem roadmap;
  final bool isDeleting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RoadmapSummaryCard({
    required this.roadmap,
    required this.isDeleting,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
                          _buildSummaryText(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9AA0AC),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: isDeleting ? null : onDelete,
                    tooltip: '로드맵 삭제',
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 22,
                      color: Color(0xFFE36D83),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'AI 추천 취득 순서',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7A7F89),
                ),
              ),
              const SizedBox(height: 10),
              if (roadmap.certificates.isEmpty)
                const Text(
                  '추천된 자격증이 없습니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9AA0AC),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: roadmap.certificates
                      .take(3)
                      .map(
                        (RoadmapCertificateStep step) {
                      return _RoadmapChip(
                        text:
                        '${step.order}. ${step.certificateName}',
                      );
                    },
                  )
                      .toList(),
                ),
              if (roadmap.certificates.length > 3) ...[
                const SizedBox(height: 10),
                Text(
                  '외 ${roadmap.certificates.length - 3}개',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9AA0AC),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildSummaryText() {
    final String stepText =
        '${roadmap.certificates.length}단계';

    if (roadmap.createdAt == null) {
      return stepText;
    }

    return '$stepText · ${_formatDate(roadmap.createdAt!)} 저장';
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
              if (roadmap.certificates.isEmpty)
                const AppEmptyView(
                  message: '추천된 자격증이 없습니다.',
                  description: 'AI 자격증 로드맵을 다시 생성해 주세요.',
                )
              else
                ListView.separated(
                  itemCount: roadmap.certificates.length,
                  shrinkWrap: true,
                  physics:
                  const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, _) {
                    return const SizedBox(height: 12);
                  },
                  itemBuilder: (context, index) {
                    final RoadmapCertificateStep step =
                    roadmap.certificates[index];

                    return _RoadmapStepCard(
                      step: step,
                    );
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
            decoration: const BoxDecoration(
              color: Color(0xFFF3EEFF),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${step.order}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8B62E7),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (step.isEstimated)
                      const _EstimatedBadge(),
                  ],
                ),
                if (step.description.isNotEmpty) ...[
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
                const SizedBox(height: 14),
                _RoadmapInformationRow(
                  icon: Icons.event_outlined,
                  title: '시험일',
                  value: step.examDate,
                ),
                const SizedBox(height: 9),
                _RoadmapInformationRow(
                  icon: Icons.edit_calendar_outlined,
                  title: '접수 기간',
                  value: step.registrationPeriod,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadmapInformationRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _RoadmapInformationRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: const Color(0xFF9B74F4),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 58,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A7F89),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF8C93A2),
            ),
          ),
        ),
      ],
    );
  }
}

class _EstimatedBadge extends StatelessWidget {
  const _EstimatedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2DC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        '예상 일정',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFFD78A27),
        ),
      ),
    );
  }
}

class _RoadmapChip extends StatelessWidget {
  final String text;

  const _RoadmapChip({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EEFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF7D62C9),
        ),
      ),
    );
  }
}

class CertificateRoadmapItem {
  final String roadmapId;
  final String jobName;
  final DateTime? createdAt;
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
  final String examDate;
  final String registrationPeriod;
  final bool isEstimated;

  const RoadmapCertificateStep({
    required this.order,
    required this.certificateName,
    required this.description,
    required this.examDate,
    required this.registrationPeriod,
    required this.isEstimated,
  });
}