import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../study/study_list.dart';
import '../../study/study_detail.dart';
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
  final List<JoinedStudyData> _studies = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadJoinedStudies();
  }

  Future<void> _loadJoinedStudies() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '로그인이 필요합니다.';
      });
      return;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> groupSnapshot =
      await FirebaseFirestore.instance
          .collection('studyGroups')
          .get();

      final List<JoinedStudyData> loadedStudies = [];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> groupDocument
      in groupSnapshot.docs) {
        final DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
        await groupDocument.reference
            .collection('members')
            .doc(user.uid)
            .get();

        if (!memberSnapshot.exists) {
          continue;
        }

        final Map<String, dynamic> memberData =
            memberSnapshot.data() ?? <String, dynamic>{};

        final String memberStatus =
        (memberData['status'] as String? ?? 'ACTIVE')
            .trim()
            .toUpperCase();

        if (memberStatus != 'ACTIVE') {
          continue;
        }

        final Map<String, dynamic> groupData = groupDocument.data();

        final String groupStatus =
        (groupData['status'] as String? ?? 'ACTIVE')
            .trim()
            .toUpperCase();

        final String role =
        (memberData['role'] as String? ?? 'MEMBER')
            .trim()
            .toUpperCase();

        loadedStudies.add(
          JoinedStudyData(
            id: groupDocument.id,
            title:
            (groupData['groupName'] as String? ?? '이름 없는 스터디')
                .trim(),
            certificateName:
            (groupData['certificateName'] as String? ?? '자격증 미지정')
                .trim(),
            description:
            (groupData['description'] as String? ?? '스터디 소개가 없습니다.')
                .trim(),
            memberCount:
            (groupData['currentMemberCount'] as num?)?.toInt() ?? 0,
            maxMemberCount:
            (groupData['maxMemberCount'] as num?)?.toInt() ?? 0,
            progressPercent: groupStatus == 'CLOSED' ? 100 : 0,
            nextSchedule: groupStatus == 'CLOSED'
                ? '종료된 스터디'
                : '등록된 다음 일정 없음',
            role: role == 'OWNER' || role == 'LEADER'
                ? StudyMemberRole.leader
                : StudyMemberRole.member,
            status: groupStatus == 'CLOSED'
                ? JoinedStudyStatus.completed
                : JoinedStudyStatus.active,
            memberDocumentId: memberSnapshot.id,
          ),
        );
      }

      loadedStudies.sort((a, b) {
        if (a.status != b.status) {
          return a.status == JoinedStudyStatus.active ? -1 : 1;
        }

        return a.title.compareTo(b.title);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _studies
          ..clear()
          ..addAll(loadedStudies);
        _isLoading = false;
        _errorMessage = null;
      });
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.code == 'permission-denied'
            ? '참여 중인 스터디를 조회할 권한이 없습니다.'
            : '참여 중인 스터디를 불러오지 못했습니다.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '참여 중인 스터디를 불러오지 못했습니다.';
      });
    }
  }

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
        child: _isLoading
            ? const AppLoadingView(
          message: '참여 중인 스터디를 불러오는 중입니다.',
        )
            : _errorMessage != null
            ? AppErrorView(
          message: _errorMessage!,
          onRetryPressed: () {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
            _loadJoinedStudies();
          },
        )
            : _studies.isEmpty
            ? AppEmptyView(
            message: "참여 중인 스터디가 없습니다",
            description: "스터디를 찾아 함께 목표를 준비해 보세요",
            buttonText: "스터디 찾기",
            onButtonPressed: () {
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
                separatorBuilder: (_, _) {
                  return const SizedBox(height: 12);
                },
                itemBuilder: (context, index) {
                  final study = _studies[index];

                  return _JoinedStudyCard(
                    study: study,
                    onTap: () {
                      _openStudyDetail(study);
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

  Future<void> _openStudyDetail(JoinedStudyData study,) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> studySnapshot =
      await FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(study.id)
          .get();

      if (!mounted) {
        return;
      }

      if (!studySnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('스터디 정보를 찾을 수 없습니다.'),
          ),
        );
        return;
      }

      final Map<String, dynamic>? studyData =
      studySnapshot.data();

      if (studyData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('스터디 정보를 불러오지 못했습니다.'),
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) {
            return StudyDetailPage(
              studyId: study.id,
              studyData: studyData,
            );
          },
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _loadJoinedStudies();
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      String message = '스터디 정보를 불러오지 못했습니다.';

      if (error.code == 'permission-denied') {
        message = '스터디 상세 정보를 조회할 권한이 없습니다.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (error) {
      debugPrint('스터디 상세 화면 이동 오류: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('스터디 정보를 불러오지 못했습니다.'),
        ),
      );
    }
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

  const _JoinedStudyCard({
    required this.study,
    required this.onTap,
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
  final String memberDocumentId;

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
    required this.memberDocumentId,
  });
}
