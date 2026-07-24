import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/loading_overlay.dart';

Brightness get _studyBrightness {
  return WidgetsBinding.instance.platformDispatcher.platformBrightness;
}

AppColors get studyColors {
  if (_studyBrightness == Brightness.dark) {
    return AppColors.dark;
  }
  return AppColors.light;
}

ColorScheme get studyColorScheme {
  if (_studyBrightness == Brightness.dark) {
    return darkTheme.colorScheme;
  }
  return lightTheme.colorScheme;
}

// ── 공통 스타일 헬퍼 (study_edit.dart 에서도 import해서 사용) ──────
InputDecoration studyFieldDecoration({
  required String labelText,
  required String hintText,
  required IconData icon,
  String? suffixText,
  bool alignLabelWithHint = false,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    suffixText: suffixText,
    alignLabelWithHint: alignLabelWithHint,
    filled: true,
    fillColor: studyColors.background,
    prefixIcon: alignLabelWithHint
        ? null
        : Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Icon(icon, color: studyColors.pinkStart, size: 21),
    ),
    labelStyle: TextStyle(color: studyColors.textSecondary, fontSize: 13.5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: studyColors.textSecondary.withOpacity(0.18)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: studyColors.textSecondary.withOpacity(0.18)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: studyColors.pinkStart, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: studyColorScheme.error, width: 1.2),
    ),
  );
}

class SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = studyColors;
    return Container(
      decoration: BoxDecoration(
        color: studyColorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.textSecondary.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.pinkStart.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: colors.pinkStart),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Text(
                subtitle!,
                style: TextStyle(fontSize: 12, height: 1.4, color: colors.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class MemberCountStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final String caption;

  const MemberCountStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onDecrease,
    required this.onIncrease,
    required this.caption,
  });

  Widget _circleButton({required IconData icon, required VoidCallback? onTap}) {
    final enabled = onTap != null;
    final colors = studyColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? colors.pinkStart.withOpacity(0.12) : colors.textSecondary.withOpacity(0.06),
          border: Border.all(
            color: enabled ? colors.pinkStart.withOpacity(0.4) : colors.textSecondary.withOpacity(0.15),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? colors.pinkStart : colors.textSecondary.withOpacity(0.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = studyColors;
    return Column(
      children: [
        Row(
          children: [
            _circleButton(icon: Icons.remove_rounded, onTap: onDecrease),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.pinkStart, colors.pinkStart.withOpacity(0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.pinkStart.withOpacity(0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Text(
                  '$value명',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 14),
            _circleButton(icon: Icons.add_rounded, onTap: onIncrease),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            caption,
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class StudySwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const StudySwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = studyColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: value ? colors.pinkStart.withOpacity(0.06) : colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? colors.pinkStart.withOpacity(0.3) : colors.textSecondary.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value ? colors.pinkStart.withOpacity(0.15) : colors.textSecondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: value ? colors.pinkStart : colors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.3)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: colors.pinkStart,
          ),
        ],
      ),
    );
  }
}
// ────────────────────────────────────────────────────────────

class StudyCreatePage extends StatefulWidget {
  const StudyCreatePage({super.key});

  @override
  State<StudyCreatePage> createState() => _StudyCreatePageState();
}

class _StudyCreatePageState extends State<StudyCreatePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _certificateNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _weeklyGoalHourController = TextEditingController(text: '15');

  DateTime? _examDate;
  int _maxMemberCount = 5;
  bool _isPublic = true;
  bool _joinApprovalRequired = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _certificateNameController.dispose();
    _descriptionController.dispose();
    _weeklyGoalHourController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dateTime) {
    String year = dateTime.year.toString();
    String month = dateTime.month.toString().padLeft(2, '0');
    String day = dateTime.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }

  Future<void> _selectExamDate() async {
    DateTime now = DateTime.now();
    DateTime initialDate = _examDate ?? now.add(Duration(days: 30));

    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: '시험일 선택',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (selectedDate == null || !mounted) return;

    setState(() {
      _examDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    });
  }

  Future<void> _saveStudy() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('로그인 정보가 없습니다.');

      final String ownerNickname = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : '익명 사용자';

      final studyDocument = FirebaseFirestore.instance.collection('studyGroups').doc();
      final batch = FirebaseFirestore.instance.batch();

      batch.set(studyDocument, {
        'groupName': _groupNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'ownerUid': user.uid,
        'ownerNickname': ownerNickname,
        'certificateId': '',
        'certificateName': _certificateNameController.text.trim().isEmpty
            ? '공통 스터디'
            : _certificateNameController.text.trim(),
        'examDate': _examDate == null ? null : Timestamp.fromDate(_examDate!),
        'weeklyGoalMinutes':
        (int.tryParse(_weeklyGoalHourController.text.trim()) ?? 15) * 60,
        'maxMemberCount': _maxMemberCount,
        'currentMemberCount': 1,
        'isPublic': _isPublic,
        'joinApprovalRequired': _joinApprovalRequired,
        'inviteCode': '',
        'chatId': '',
        'status': 'RECRUITING',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final ownerMemberDocument = studyDocument.collection('members').doc(user.uid);
      batch.set(ownerMemberDocument, {
        'uid': user.uid,
        'nickname': ownerNickname,
        'role': 'OWNER',
        'status': 'ACTIVE',
        'totalStudyMinutes': 0,
        'joinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('스터디가 등록되었습니다.')),
      );

      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('스터디 등록 오류: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('스터디 등록 실패: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = studyColors;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppTopBar(title: '스터디 만들기', centerTitle: false),
      body: Stack(
        children: [
          AppMainBackground(
            applySafeArea: false,
            child: SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, 25, 20, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '새로운 스터디를\n만들어보세요',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.35),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '스터디 정보를 입력하면 목록에 바로 등록됩니다.',
                        style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
                      ),
                      SizedBox(height: 26),

                      SectionCard(
                        icon: Icons.groups_rounded,
                        title: '기본 정보',
                        children: [
                          TextFormField(
                            controller: _groupNameController,
                            textInputAction: TextInputAction.next,
                            decoration: studyFieldDecoration(
                              labelText: '스터디 이름',
                              hintText: '예: 정보처리기사 실기 스터디',
                              icon: Icons.groups_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '스터디 이름을 입력해주세요.';
                              }
                              if (value.trim().length < 2) {
                                return '스터디 이름을 2글자 이상 입력해주세요.';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _certificateNameController,
                            textInputAction: TextInputAction.next,
                            decoration: studyFieldDecoration(
                              labelText: '자격증 이름',
                              hintText: '예: 정보처리기사',
                              icon: Icons.workspace_premium_outlined,
                            ),
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 4,
                            maxLength: 200,
                            textInputAction: TextInputAction.newline,
                            decoration: studyFieldDecoration(
                              labelText: '스터디 소개',
                              hintText: '스터디 목표와 진행 방법을 입력해주세요.',
                              icon: Icons.edit_note_rounded,
                              alignLabelWithHint: true,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '스터디 소개를 입력해주세요.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      SectionCard(
                        icon: Icons.flag_rounded,
                        title: '시험 및 학습 목표',
                        subtitle: '시험일까지 남은 기간과 주간 달성률을 스터디방에 표시합니다.',
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _selectExamDate,
                            child: Container(
                              width: double.infinity,
                              constraints: BoxConstraints(minHeight: 60),
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: colors.background,
                                border: Border.all(color: colors.textSecondary.withOpacity(0.18)),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: colors.pinkStart.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.calendar_month_outlined,
                                        size: 18, color: colors.pinkStart),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('시험일',
                                            style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                                        SizedBox(height: 4),
                                        Text(
                                          _examDate == null ? '시험일을 선택해 주세요.' : _formatDate(_examDate!),
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: _examDate == null
                                                ? colors.textSecondary
                                                : colors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_examDate != null)
                                    IconButton(
                                      tooltip: '시험일 지우기',
                                      onPressed: () => setState(() => _examDate = null),
                                      icon: Icon(Icons.close_rounded, size: 19),
                                    )
                                  else
                                    Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _weeklyGoalHourController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            decoration: studyFieldDecoration(
                              labelText: '주간 목표 공부시간',
                              hintText: '예: 15',
                              icon: Icons.flag_outlined,
                              suffixText: '시간',
                            ),
                            validator: (value) {
                              int? goalHour = int.tryParse(value?.trim() ?? '');
                              if (goalHour == null) return '주간 목표시간을 숫자로 입력해주세요.';
                              if (goalHour < 1 || goalHour > 168) {
                                return '1시간 이상 168시간 이하로 입력해주세요.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      SectionCard(
                        icon: Icons.tune_rounded,
                        title: '스터디 설정',
                        children: [
                          Text('최대 인원', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                          SizedBox(height: 12),
                          MemberCountStepper(
                            value: _maxMemberCount,
                            min: 2,
                            max: 30,
                            caption: '최소 2명 · 최대 30명',
                            onDecrease: _maxMemberCount > 2
                                ? () => setState(() => _maxMemberCount--)
                                : null,
                            onIncrease: _maxMemberCount < 30
                                ? () => setState(() => _maxMemberCount++)
                                : null,
                          ),
                          SizedBox(height: 20),
                          StudySwitchTile(
                            icon: Icons.public_rounded,
                            title: '공개 스터디',
                            subtitle: _isPublic
                                ? '다른 사용자가 검색하고 확인할 수 있습니다.'
                                : '초대받은 사용자만 확인할 수 있습니다.',
                            value: _isPublic,
                            onChanged: (value) => setState(() => _isPublic = value),
                          ),
                          StudySwitchTile(
                            icon: Icons.verified_user_rounded,
                            title: '참여 승인 필요',
                            subtitle: _joinApprovalRequired
                                ? '방장이 승인해야 참여할 수 있습니다.'
                                : '신청하면 바로 참여할 수 있습니다.',
                            value: _joinApprovalRequired,
                            onChanged: (value) => setState(() => _joinApprovalRequired = value),
                          ),
                        ],
                      ),

                      SizedBox(height: 26),

                      AppButton(
                        text: '스터디 만들기',
                        type: AppButtonType.primaryPink,
                        height: 56,
                        onPressed: _isSaving ? null : _saveStudy,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isSaving) Positioned.fill(child: LoadingOverlay()),
        ],
      ),
    );
  }
}