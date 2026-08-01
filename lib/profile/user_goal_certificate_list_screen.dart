import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_state_views.dart';
import '../widgets/app_top_bar.dart';

class UserGoalCertificateListScreen extends StatefulWidget {
  final String userUid;
  final String nickname;

  const UserGoalCertificateListScreen({
    super.key,
    required this.userUid,
    required this.nickname,
  });

  @override
  State<UserGoalCertificateListScreen> createState() =>
      _UserGoalCertificateListScreenState();
}

class _UserGoalCertificateListScreenState
    extends State<UserGoalCertificateListScreen> {
  bool _isLoading = true;
  bool _isPrivate = false;
  bool _hasError = false;
  List<_GoalCertificateItem> _goals = const [];

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      if (!await _canViewActivity()) {
        if (!mounted) return;
        setState(() {
          _isPrivate = true;
          _isLoading = false;
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('goals')
          .get();
      final goals = snapshot.docs
          .where((document) {
            final status =
                (document.data()['goalStatus']?.toString() ?? 'ACTIVE')
                    .toUpperCase();
            return status != 'DELETED';
          })
          .map((document) {
            final data = document.data();
            return _GoalCertificateItem(
              certificateName: _text(data['certificateName'], '자격증 이름 없음'),
              examName: _text(data['targetRound'], '시험 이름 미선택'),
              examType: _formatExamType(data['targetExamType']),
              registrationStartDate: _date(data['targetRegistrationStartDate']),
              registrationEndDate: _date(data['targetRegistrationEndDate']),
              examDate: _date(data['targetExamDate']),
              examEndDate: _date(data['targetExamEndDate']),
              passAnnouncementDate: _date(data['targetPassAnnouncementDate']),
              passAnnouncementEndDate: _date(
                data['targetPassAnnouncementEndDate'],
              ),
              isMainGoal: data['isMainGoal'] as bool? ?? false,
            );
          })
          .toList();

      goals.sort((a, b) {
        if (a.isMainGoal != b.isMainGoal) return a.isMainGoal ? -1 : 1;
        if (a.examDate == null && b.examDate == null) {
          return a.certificateName.compareTo(b.certificateName);
        }
        if (a.examDate == null) return 1;
        if (b.examDate == null) return -1;
        return a.examDate!.compareTo(b.examDate!);
      });

      if (!mounted) return;
      setState(() {
        _goals = goals;
        _isPrivate = false;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<bool> _canViewActivity() async {
    if (FirebaseAuth.instance.currentUser?.uid == widget.userUid) return true;
    try {
      final user = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .get();
      final value = user.data()?['profileActivityPublic'];
      return value is bool ? value : true;
    } catch (_) {
      return false;
    }
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _text(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatExamType(dynamic value) {
    final type = value?.toString().toUpperCase() ?? '';
    if (type == 'WRITTEN') return '필기';
    if (type == 'PRACTICAL') return '실기';
    return '시험 유형 미선택';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '일정 미선택';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '일정 미선택';
    if (start == null) return _formatDate(end);
    if (end == null || _isSameDay(start, end)) return _formatDate(start);
    return '${_formatDate(start)} ~ ${_formatDate(end)}';
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(title: '${widget.nickname}님의 목표 자격증'),
      body: AppMainBackground(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingView(message: '목표 자격증을 불러오는 중입니다.');
    }
    if (_isPrivate) {
      return const AppEmptyView(
        message: '비공개 활동입니다.',
        description: '사용자가 프로필 활동을 비공개로 설정했습니다.',
      );
    }
    if (_hasError) {
      return AppErrorView(
        message: '목표 자격증을 불러오지 못했습니다.',
        onRetryPressed: _loadGoals,
      );
    }
    if (_goals.isEmpty) {
      return const AppEmptyView(message: '설정한 목표 자격증이 없습니다.');
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      itemCount: _goals.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildGoalCard(_goals[index]),
    );
  }

  Widget _buildGoalCard(_GoalCertificateItem goal) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: context.colors.pinkSoft,
                child: Icon(
                  Icons.workspace_premium_outlined,
                  color: context.colors.pinkDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.certificateName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      goal.examName,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (goal.isMainGoal)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.warningSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '대표 목표',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.colors.warning,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _GoalInfoRow(
            label: '원서 접수',
            value: _formatRange(
              goal.registrationStartDate,
              goal.registrationEndDate,
            ),
          ),
          _GoalInfoRow(
            label: '시험일',
            value: _formatRange(goal.examDate, goal.examEndDate),
          ),
          _GoalInfoRow(label: '시험 유형', value: goal.examType),
          _GoalInfoRow(
            label: '합격자 발표일',
            value: _formatRange(
              goal.passAnnouncementDate,
              goal.passAnnouncementEndDate,
            ),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _GoalInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool showDivider;

  const _GoalInfoRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: context.colors.divider),
      ],
    );
  }
}

class _GoalCertificateItem {
  final String certificateName;
  final String examName;
  final String examType;
  final DateTime? registrationStartDate;
  final DateTime? registrationEndDate;
  final DateTime? examDate;
  final DateTime? examEndDate;
  final DateTime? passAnnouncementDate;
  final DateTime? passAnnouncementEndDate;
  final bool isMainGoal;

  const _GoalCertificateItem({
    required this.certificateName,
    required this.examName,
    required this.examType,
    required this.registrationStartDate,
    required this.registrationEndDate,
    required this.examDate,
    required this.examEndDate,
    required this.passAnnouncementDate,
    required this.passAnnouncementEndDate,
    required this.isMainGoal,
  });
}
