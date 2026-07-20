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

class _GoalCertificateScreenState
    extends State<GoalCertificateScreen> {
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
          .collection('userGoals')
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
        final String certificateName =
        (data['certificateName'] as String? ?? '').trim();

        if (certificateId.isEmpty || certificateName.isEmpty) {
          continue;
        }

        final Timestamp? targetExamTimestamp =
        data['targetExamDate'] as Timestamp?;
        final DateTime? targetExamDate =
        targetExamTimestamp?.toDate();

        loadedGoals.add(
          GoalCertificateItem(
            goalId: document.id,
            certificateId: certificateId,
            certificateName: certificateName,
            examRound:
            (data['targetRound'] as String? ?? '시험 일정 미선택')
                .trim(),
            examDate: targetExamDate,
            calendarLinked:
            data['calendarLinked'] as bool? ?? false,
            alarmEnabled:
            data['alarmEnabled'] as bool? ?? false,
          ),
        );
      }

      loadedGoals.sort((a, b) {
        if (a.examDate == null && b.examDate == null) {
          return a.certificateName.compareTo(b.certificateName);
        }

        if (a.examDate == null) {
          return 1;
        }

        if (b.examDate == null) {
          return -1;
        }

        return a.examDate!.compareTo(b.examDate!);
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
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final GoalCertificateItem goal =
                      _goals[index];

                      return GoalCertificateCard(
                        goal: goal,
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
              '등록한 목표 자격증의 시험일과 D-Day를 확인할 수 있습니다.',
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
      message: _errorMessage ?? '목표 자격증을 불러오지 못했습니다.',
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
      description: '자격증 상세보기에서 목표 자격증을 등록할 수 있습니다.',
    );
  }

  Future<void> _showDeleteDialog(
      int index,
      ) async {
    final GoalCertificateItem goal = _goals[index];

    final bool? deleteResult =
    await showDialog<bool>(
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
            '${goal.certificateName} 목표를 삭제하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
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
                Navigator.pop(
                  dialogContext,
                  true,
                );
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
      final DocumentReference<Map<String, dynamic>> goalDocument =
      FirebaseFirestore.instance
          .collection('userGoals')
          .doc(user.uid)
          .collection('goals')
          .doc(goal.goalId);

      final DocumentReference<Map<String, dynamic>> userDocument =
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      await FirebaseFirestore.instance.runTransaction(
            (transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
          await transaction.get(userDocument);

          transaction.delete(goalDocument);

          final String currentGoalCertificateId =
          (userSnapshot.data()?['goalCertificateId'] as String? ?? '')
              .trim();

          if (currentGoalCertificateId == goal.certificateId) {
            transaction.update(
              userDocument,
              {
                'goalCertificateId': FieldValue.delete(),
                'updatedAt': FieldValue.serverTimestamp(),
              },
            );
          }
        },
      );

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
}

class GoalCertificateCard extends StatelessWidget {
  final GoalCertificateItem goal;
  final VoidCallback onDelete;

  const GoalCertificateCard({
    super.key,
    required this.goal,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final int? dDay = goal.examDate == null
        ? null
        : _calculateDday(goal.examDate!);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCEFF3),
                    borderRadius:
                    BorderRadius.circular(15),
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
                          fontWeight:
                          FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        goal.examRound,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9AA0AC),
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  tooltip: '목표 자격증 삭제',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete,
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
                borderRadius:
                BorderRadius.circular(14),
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
                    child: Text(
                      goal.examDate == null
                          ? '시험 일정 미선택'
                          : _formatDate(goal.examDate!),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight:
                        FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),

                  Text(
                    dDay == null
                        ? '-'
                        : _formatDday(dDay),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                      FontWeight.w700,
                      color: dDay != null && dDay >= 0
                          ? const Color(0xFFF0788F)
                          : const Color(
                        0xFF9AA0AC,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                _StatusLabel(
                  icon:
                  Icons.calendar_month_outlined,
                  text: goal.calendarLinked
                      ? '캘린더 연동'
                      : '캘린더 미연동',
                  enabled: goal.calendarLinked,
                ),

                const SizedBox(width: 16),

                _StatusLabel(
                  icon:
                  Icons.notifications_none,
                  text: goal.alarmEnabled
                      ? '시험 알림 사용'
                      : '시험 알림 미사용',
                  enabled: goal.alarmEnabled,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static int _calculateDday(
      DateTime examDate,
      ) {
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

  static String _formatDday(
      int dDay,
      ) {
    if (dDay > 0) {
      return 'D-$dDay';
    }

    if (dDay == 0) {
      return 'D-Day';
    }

    return '시험 종료';
  }

  static String _formatDate(
      DateTime date,
      ) {
    return '${date.year}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _StatusLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool enabled;

  const _StatusLabel({
    required this.icon,
    required this.text,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: enabled
              ? const Color(0xFFF0788F)
              : const Color(0xFFB4B8C2),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: enabled
                ? const Color(0xFF666A73)
                : const Color(0xFF9AA0AC),
          ),
        ),
      ],
    );
  }
}

class GoalCertificateItem {
  final String goalId;
  final String certificateId;
  final String certificateName;
  final String examRound;
  final DateTime? examDate;

  // 현재는 조회용 임시 데이터
  final bool calendarLinked;
  final bool alarmEnabled;

  const GoalCertificateItem({
    required this.goalId,
    required this.certificateId,
    required this.certificateName,
    required this.examRound,
    required this.examDate,
    required this.calendarLinked,
    required this.alarmEnabled,
  });
}