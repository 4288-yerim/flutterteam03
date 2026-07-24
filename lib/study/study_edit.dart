import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/loading_overlay.dart';
import 'study_add.dart';

class StudyEditPage extends StatefulWidget {
  final String studyId;
  final Map<String, dynamic> studyData;

  const StudyEditPage({
    super.key,
    required this.studyId,
    required this.studyData,
  });

  @override
  State<StudyEditPage> createState() => _StudyEditPageState();
}

class _StudyEditPageState extends State<StudyEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _groupNameController;
  late final TextEditingController _certificateNameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _weeklyGoalHourController;

  DateTime? _examDate;

  late int _currentMemberCount;
  late int _minimumMemberCount;
  late int _maxMemberCount;

  late bool _isPublic;
  late bool _joinApprovalRequired;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _groupNameController =
        TextEditingController(text: widget.studyData['groupName']?.toString() ?? '');

    _certificateNameController = TextEditingController(
      text: widget.studyData['certificateName']?.toString() ?? '',
    );

    _descriptionController =
        TextEditingController(text: widget.studyData['description']?.toString() ?? '');

    int weeklyGoalMinutes = _getInt(widget.studyData, 'weeklyGoalMinutes', fallback: 900);
    int weeklyGoalHours = (weeklyGoalMinutes / 60).round();
    if (weeklyGoalHours < 1) weeklyGoalHours = 15;

    _weeklyGoalHourController = TextEditingController(text: weeklyGoalHours.toString());

    dynamic examDateValue = widget.studyData['examDate'];
    if (examDateValue is Timestamp) {
      DateTime savedExamDate = examDateValue.toDate().toLocal();
      _examDate = DateTime(savedExamDate.year, savedExamDate.month, savedExamDate.day);
    }

    _currentMemberCount = _getInt(widget.studyData, 'currentMemberCount', fallback: 1);
    _minimumMemberCount = max(2, _currentMemberCount);

    _maxMemberCount = _getInt(widget.studyData, 'maxMemberCount', fallback: 5);
    if (_maxMemberCount < _minimumMemberCount) _maxMemberCount = _minimumMemberCount;
    if (_maxMemberCount > 30) _maxMemberCount = 30;

    _isPublic = widget.studyData['isPublic'] is bool ? widget.studyData['isPublic'] as bool : true;

    _joinApprovalRequired = widget.studyData['joinApprovalRequired'] is bool
        ? widget.studyData['joinApprovalRequired'] as bool
        : true;
  }

  int _getInt(Map<String, dynamic> data, String fieldName, {int fallback = 0}) {
    final value = data[fieldName];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
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
    DateTime firstDate = DateTime(now.year - 1, 1, 1);
    DateTime lastDate = DateTime(now.year + 10, 12, 31);

    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: '시험일 선택',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (selectedDate == null || !mounted) return;

    setState(() {
      _examDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    });
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _certificateNameController.dispose();
    _descriptionController.dispose();
    _weeklyGoalHourController.dispose();
    super.dispose();
  }

  Future<void> _updateStudy() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final previousStatus = widget.studyData['status']?.toString() ?? 'RECRUITING';
      String nextStatus = previousStatus;

      if (previousStatus != 'COMPLETED') {
        nextStatus = _currentMemberCount >= _maxMemberCount ? 'CLOSED' : 'RECRUITING';
      }

      await FirebaseFirestore.instance.collection('studyGroups').doc(widget.studyId).update({
        'groupName': _groupNameController.text.trim(),
        'certificateName': _certificateNameController.text.trim().isEmpty
            ? '공통 스터디'
            : _certificateNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'examDate': _examDate == null ? null : Timestamp.fromDate(_examDate!),
        'weeklyGoalMinutes':
        (int.tryParse(_weeklyGoalHourController.text.trim()) ?? 15) * 60,
        'maxMemberCount': _maxMemberCount,
        'isPublic': _isPublic,
        'joinApprovalRequired': _joinApprovalRequired,
        'status': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('스터디 정보가 수정되었습니다.')),
      );

      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('스터디 수정 오류: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('스터디 수정 실패: $error')),
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
      appBar: AppTopBar(title: '스터디 수정', centerTitle: false),
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
                        '스터디 정보를\n수정해보세요',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.35),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '수정한 내용은 스터디 화면에 바로 반영됩니다.',
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
                            min: _minimumMemberCount,
                            max: 30,
                            caption: _currentMemberCount > 2
                                ? '현재 인원 $_currentMemberCount명 · 최대 30명'
                                : '최소 2명 · 최대 30명',
                            onDecrease: _maxMemberCount > _minimumMemberCount
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
                        text: '수정 완료',
                        type: AppButtonType.primaryPink,
                        height: 56,
                        onPressed: _isSaving ? null : _updateStudy,
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