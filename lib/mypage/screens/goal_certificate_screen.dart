import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/app_state_views.dart';

class GoalCertificateScreen extends StatefulWidget {
  const GoalCertificateScreen({super.key});

  @override
  State<GoalCertificateScreen> createState() =>
      _GoalCertificateScreenState();
}

class _GoalCertificateScreenState extends State<GoalCertificateScreen> {
  final List<GoalCertificateItem> _goals = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
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
      final QuerySnapshot<Map<String, dynamic>> snapshot =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .get();

      final List<GoalCertificateItem> loadedGoals = [];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
      in snapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final String goalStatus =
        (data['goalStatus'] as String? ?? 'ACTIVE').trim();

        if (goalStatus == 'DELETED') {
          continue;
        }

        final String certificateId =
        (data['certificateId'] as String? ?? '').trim();

        String certificateName =
        (data['certificateName'] as String? ?? '').trim();

        if (certificateId.isEmpty) {
          continue;
        }

        // 기존 목표 문서에 자격증명이 없으면
        // 자격증 원본 문서의 jmfldnm을 사용합니다.
        if (certificateName.isEmpty) {
          final DocumentSnapshot<Map<String, dynamic>>
          certificateSnapshot =
          await FirebaseFirestore.instance
              .collection('certifications')
              .doc(certificateId)
              .get();

          certificateName =
              (certificateSnapshot.data()?['jmfldnm'] as String? ?? '')
                  .trim();
        }

        if (certificateName.isEmpty) {
          certificateName = certificateId.toUpperCase();
        }

        final Timestamp? targetExamTimestamp =
        data['targetExamDate'] as Timestamp?;

        final Timestamp? passAnnouncementTimestamp =
        data['targetPassAnnouncementDate'] as Timestamp?;

        final Timestamp? passAnnouncementEndTimestamp =
        data['targetPassAnnouncementEndDate'] as Timestamp?;

        loadedGoals.add(
          GoalCertificateItem(
            goalId: document.id,
            certificateId: certificateId,
            certificateName: certificateName,
            targetRound:
            (data['targetRound'] as String? ?? '시험 회차 미선택')
                .trim(),
            targetExamType:
            (data['targetExamType'] as String? ?? '').trim(),
            targetExamDate: targetExamTimestamp?.toDate(),
            passAnnouncementDate:
            passAnnouncementTimestamp?.toDate(),
            passAnnouncementEndDate:
            passAnnouncementEndTimestamp?.toDate(),
            isMainGoal: data['isMainGoal'] as bool? ?? false,
          ),
        );
      }

      loadedGoals.sort((a, b) {
        if (a.isMainGoal != b.isMainGoal) {
          return a.isMainGoal ? -1 : 1;
        }
        if (a.targetExamDate == null &&
            b.targetExamDate == null) {
          return a.certificateName.compareTo(
            b.certificateName,
          );
        }

        if (a.targetExamDate == null) {
          return 1;
        }

        if (b.targetExamDate == null) {
          return -1;
        }

        return a.targetExamDate!.compareTo(
          b.targetExamDate!,
        );
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _goals
          ..clear()
          ..addAll(loadedGoals);

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
            ? '목표 자격증을 조회할 권한이 없습니다.'
            : '목표 자격증을 불러오지 못했습니다.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '목표 자격증을 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _setMainGoal(int index) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final GoalCertificateItem selectedGoal = _goals[index];

    if (selectedGoal.isMainGoal) {
      return;
    }

    try {
      final WriteBatch batch =
      FirebaseFirestore.instance.batch();

      final CollectionReference<Map<String, dynamic>>
      goalsCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('goals');

      // 기존 목표는 모두 false로 변경하고,
      // 선택한 목표만 true로 변경합니다.
      for (final GoalCertificateItem goal in _goals) {
        batch.update(
          goalsCollection.doc(goal.goalId),
          {
            'isMainGoal':
            goal.goalId == selectedGoal.goalId,
            'updatedAt':
            FieldValue.serverTimestamp(),
          },
        );
      }

      await batch.commit();

      if (!mounted) {
        return;
      }

      setState(() {
        for (int i = 0; i < _goals.length; i++) {
          _goals[i] = _goals[i].copyWith(
            isMainGoal:
            _goals[i].goalId == selectedGoal.goalId,
          );
        }

        _goals.sort((a, b) {
          if (a.isMainGoal != b.isMainGoal) {
            return a.isMainGoal ? -1 : 1;
          }

          return a.certificateName.compareTo(
            b.certificateName,
          );
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selectedGoal.certificateName}이(가) '
                '대표 목표로 설정되었습니다.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      final String message =
      error.code == 'permission-denied'
          ? '대표 목표를 변경할 권한이 없습니다.'
          : '대표 목표 변경에 실패했습니다.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    }
  }

  Future<void> _showDeleteDialog(int index) async {
    final GoalCertificateItem goal = _goals[index];

    final bool? deleteResult = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '목표 삭제',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '${goal.certificateName} '
                '${goal.targetRound} '
                '${_formatExamType(goal.targetExamType)} 목표를 '
                '삭제하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
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
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (deleteResult != true) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다.'),
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .doc(goal.goalId)
          .delete();

      if (!mounted) {
        return;
      }

      setState(() {
        _goals.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${goal.certificateName} 목표가 삭제되었습니다.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      final String message = error.code == 'permission-denied'
          ? '목표 자격증을 삭제할 권한이 없습니다.'
          : '목표 자격증 삭제에 실패했습니다.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '목표 자격증 관리',
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
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '준비 중인 자격증',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_goals.length}개',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF0788F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                _buildLoadingView()
              else if (_errorMessage != null)
                _buildErrorView()
              else if (_goals.isEmpty)
                  _buildEmptyView()
                else
                  ListView.separated(
                    itemCount: _goals.length,
                    shrinkWrap: true,
                    physics:
                    const NeverScrollableScrollPhysics(),
                    separatorBuilder: (_, _) =>
                    const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final GoalCertificateItem goal =
                      _goals[index];

                      return GoalCertificateCard(
                        goal: goal,
                        onSetMain: () {
                          _setMainGoal(index);
                        },
                        onDelete: () {
                          _showDeleteDialog(index);
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFCEFF3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              size: 21,
              color: Color(0xFFF0788F),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '등록한 목표 자격증의 시험 회차와 '
                  '필기·실기 시험일을 확인할 수 있습니다.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF666A73),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return const AppLoadingView(
      message: '목표 자격증을 불러오는 중입니다.',
    );
  }

  Widget _buildErrorView() {
    return AppErrorView(
      message:
      _errorMessage ?? '목표 자격증을 불러오지 못했습니다.',
      description: '잠시 후 다시 시도해 주세요.',
      onRetryPressed: () {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        _loadGoals();
      },
    );
  }

  Widget _buildEmptyView() {
    return const AppEmptyView(
      message: '등록된 목표 자격증이 없습니다.',
      description:
      '자격증 상세보기에서 목표 자격증을 등록할 수 있습니다.',
    );
  }

  static String _formatExamType(String examType) {
    if (examType == 'WRITTEN') {
      return '필기';
    }

    if (examType == 'PRACTICAL') {
      return '실기';
    }

    return '시험 유형 미선택';
  }
}

class GoalCertificateCard extends StatelessWidget {
  final GoalCertificateItem goal;
  final VoidCallback onSetMain;
  final VoidCallback onDelete;

  const GoalCertificateCard({
    super.key,
    required this.goal,
    required this.onSetMain,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final int? dDay = goal.targetExamDate == null
        ? null
        : _calculateDday(goal.targetExamDate!);

    return AppCard(
      padding: EdgeInsets.zero,
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
                    Icons.workspace_premium_outlined,
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
                        goal.certificateName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _GoalLabel(
                            text: goal.targetRound,
                            backgroundColor:
                            const Color(0xFFF4F1FF),
                            textColor:
                            const Color(0xFF7665A7),
                          ),
                          _GoalLabel(
                            text: _formatExamType(
                              goal.targetExamType,
                            ),
                            backgroundColor:
                            const Color(0xFFFCEFF3),
                            textColor:
                            const Color(0xFFF0788F),
                          ),
                          if (goal.isMainGoal)
                            const _GoalLabel(
                              text: '대표 목표',
                              backgroundColor:
                              Color(0xFFFFE8AE),
                              textColor:
                              Color(0xFF9A6B00),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '목표 자격증 삭제',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 20,
                    color: Color(0xFFF0788F),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '목표 시험일',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9AA0AC),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          goal.targetExamDate == null
                              ? '시험 일정 미선택'
                              : _formatDate(
                            goal.targetExamDate!,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    dDay == null
                        ? '-'
                        : _formatDday(dDay),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: dDay != null && dDay >= 0
                          ? const Color(0xFFF0788F)
                          : const Color(0xFF9AA0AC),
                    ),
                  ),
                ],
              ),
            ),
            if (goal.passAnnouncementDate != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.campaign_outlined,
                    size: 18,
                    color: Color(0xFF9AA0AC),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '합격 발표',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF777B84),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatPassAnnouncement(
                      goal.passAnnouncementDate!,
                      goal.passAnnouncementEndDate,
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF44474E),
                    ),
                  ),
                ],
              ),
            ],
            if (!goal.isMainGoal) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onSetMain,
                  icon: const Icon(
                    Icons.star_outline,
                    size: 19,
                  ),
                  label: const Text(
                    '대표 목표로 설정',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                    const Color(0xFFF0788F),
                    side: const BorderSide(
                      color: Color(0xFFF0788F),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(14),
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

  static String _formatExamType(String examType) {
    if (examType == 'WRITTEN') {
      return '필기';
    }

    if (examType == 'PRACTICAL') {
      return '실기';
    }

    return '시험 유형 미선택';
  }

  static int _calculateDday(DateTime examDate) {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime examDay = DateTime(
      examDate.year,
      examDate.month,
      examDate.day,
    );

    return examDay.difference(today).inDays;
  }

  static String _formatDday(int dDay) {
    if (dDay > 0) {
      return 'D-$dDay';
    }

    if (dDay == 0) {
      return 'D-Day';
    }

    return '시험 종료';
  }

  static String _formatDate(DateTime date) {
    return '${date.year}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatPassAnnouncement(
      DateTime startDate,
      DateTime? endDate,
      ) {
    if (endDate == null ||
        _isSameDate(startDate, endDate)) {
      return _formatDate(startDate);
    }

    return '${_formatDate(startDate)}'
        ' ~ ${_formatDate(endDate)}';
  }

  static bool _isSameDate(
      DateTime firstDate,
      DateTime secondDate,
      ) {
    return firstDate.year == secondDate.year &&
        firstDate.month == secondDate.month &&
        firstDate.day == secondDate.day;
  }
}

class _GoalLabel extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const _GoalLabel({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
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

class GoalCertificateItem {
  final String goalId;
  final String certificateId;
  final String certificateName;
  final String targetRound;
  final String targetExamType;
  final DateTime? targetExamDate;
  final DateTime? passAnnouncementDate;
  final DateTime? passAnnouncementEndDate;
  final bool isMainGoal;

  const GoalCertificateItem({
    required this.goalId,
    required this.certificateId,
    required this.certificateName,
    required this.targetRound,
    required this.targetExamType,
    required this.targetExamDate,
    required this.passAnnouncementDate,
    required this.passAnnouncementEndDate,
    required this.isMainGoal,
  });

  GoalCertificateItem copyWith({
    bool? isMainGoal,
  }) {
    return GoalCertificateItem(
      goalId: goalId,
      certificateId: certificateId,
      certificateName: certificateName,
      targetRound: targetRound,
      targetExamType: targetExamType,
      targetExamDate: targetExamDate,
      passAnnouncementDate:
      passAnnouncementDate,
      passAnnouncementEndDate:
      passAnnouncementEndDate,
      isMainGoal:
      isMainGoal ?? this.isMainGoal,
    );
  }
}