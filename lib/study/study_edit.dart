import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/loading_overlay.dart';


Brightness get _studyBrightness {
  return WidgetsBinding.instance.platformDispatcher.platformBrightness;
}

AppColors get _studyColors {
  if (_studyBrightness == Brightness.dark) {
    return AppColors.dark;
  }

  return AppColors.light;
}

ColorScheme get _studyColorScheme {
  if (_studyBrightness == Brightness.dark) {
    return darkTheme.colorScheme;
  }

  return lightTheme.colorScheme;
}

class StudyEditPage extends StatefulWidget {
  final String studyId;
  final Map<String, dynamic> studyData;

  const StudyEditPage({
    super.key,
    required this.studyId,
    required this.studyData,
  });

  @override
  State<StudyEditPage> createState() =>
      _StudyEditPageState();
}

class _StudyEditPageState extends State<StudyEditPage> {
  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  late final TextEditingController
  _groupNameController;

  late final TextEditingController
  _certificateNameController;

  late final TextEditingController
  _descriptionController;

  late final TextEditingController
  _weeklyGoalHourController;

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

    _groupNameController = TextEditingController(
      text: widget.studyData['groupName']
          ?.toString() ??
          '',
    );

    _certificateNameController =
        TextEditingController(
          text: widget.studyData['certificateName']
              ?.toString() ??
              '',
        );

    _descriptionController = TextEditingController(
      text: widget.studyData['description']
          ?.toString() ??
          '',
    );

    int weeklyGoalMinutes = _getInt(
      widget.studyData,
      'weeklyGoalMinutes',
      fallback: 900,
    );

    int weeklyGoalHours =
    (weeklyGoalMinutes / 60).round();

    if (weeklyGoalHours < 1) {
      weeklyGoalHours = 15;
    }

    _weeklyGoalHourController =
        TextEditingController(
          text: weeklyGoalHours.toString(),
        );

    dynamic examDateValue =
    widget.studyData['examDate'];

    if (examDateValue is Timestamp) {
      DateTime savedExamDate =
      examDateValue.toDate().toLocal();

      _examDate = DateTime(
        savedExamDate.year,
        savedExamDate.month,
        savedExamDate.day,
      );
    }

    _currentMemberCount = _getInt(
      widget.studyData,
      'currentMemberCount',
      fallback: 1,
    );

    // 현재 참여 인원보다 최대 인원을 작게 설정할 수 없음
    _minimumMemberCount =
        max(2, _currentMemberCount);

    _maxMemberCount = _getInt(
      widget.studyData,
      'maxMemberCount',
      fallback: 5,
    );

    if (_maxMemberCount < _minimumMemberCount) {
      _maxMemberCount = _minimumMemberCount;
    }

    if (_maxMemberCount > 30) {
      _maxMemberCount = 30;
    }

    _isPublic =
    widget.studyData['isPublic'] is bool
        ? widget.studyData['isPublic'] as bool
        : true;

    _joinApprovalRequired =
    widget.studyData['joinApprovalRequired']
    is bool
        ? widget.studyData[
    'joinApprovalRequired']
    as bool
        : true;
  }

  int _getInt(
      Map<String, dynamic> data,
      String fieldName, {
        int fallback = 0,
      }) {
    final value = data[fieldName];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

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

    DateTime initialDate =
        _examDate ?? now.add(Duration(days: 30));

    DateTime firstDate = DateTime(
      now.year - 1,
      1,
      1,
    );

    DateTime lastDate = DateTime(
      now.year + 10,
      12,
      31,
    );

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }

    if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: '시험일 선택',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _examDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
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

  /// 수정된 스터디 정보 저장
  Future<void> _updateStudy() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final previousStatus =
          widget.studyData['status']?.toString() ??
              'RECRUITING';

      String nextStatus = previousStatus;

      // 완료된 스터디가 아니라면 인원에 따라 모집 상태 변경
      if (previousStatus != 'COMPLETED') {
        nextStatus =
        _currentMemberCount >= _maxMemberCount
            ? 'CLOSED'
            : 'RECRUITING';
      }

      await FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .update({
        'groupName':
        _groupNameController.text.trim(),
        'certificateName':
        _certificateNameController.text
            .trim()
            .isEmpty
            ? '공통 스터디'
            : _certificateNameController.text
            .trim(),
        'description':
        _descriptionController.text.trim(),
        'examDate': _examDate == null
            ? null
            : Timestamp.fromDate(_examDate!),
        'weeklyGoalMinutes':
        (int.tryParse(
          _weeklyGoalHourController.text.trim(),
        ) ?? 15) * 60,
        'maxMemberCount': _maxMemberCount,
        'isPublic': _isPublic,
        'joinApprovalRequired':
        _joinApprovalRequired,
        'status': nextStatus,
        'updatedAt':
        FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '스터디 정보가 수정되었습니다.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('스터디 수정 오류: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '스터디 수정 실패: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,

      appBar: AppTopBar(
        title: '스터디 수정',
        centerTitle: false,
      ),

      body: Stack(
        children: [
          AppMainBackground(
            applySafeArea: false,
            child: SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior
                    .onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  25,
                  20,
                  40,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        '스터디 정보를 수정해보세요',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 8),

                      Text(
                        '수정한 내용은 스터디 화면에 바로 반영됩니다.',
                        style: TextStyle(
                          fontSize: 14,
                          color: _studyColors.textSecondary,
                        ),
                      ),

                      SizedBox(height: 25),

                      AppCard(
                        backgroundColor: _studyColorScheme.surface,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              '기본 정보',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 20),

                            TextFormField(
                              controller:
                              _groupNameController,
                              textInputAction:
                              TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: '스터디 이름',
                                hintText:
                                '예: 정보처리기사 실기 스터디',
                                prefixIcon: Icon(
                                  Icons.groups_outlined,
                                ),
                                border:
                                OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    14,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.trim().isEmpty) {
                                  return '스터디 이름을 입력해주세요.';
                                }

                                if (value.trim().length < 2) {
                                  return '스터디 이름을 2글자 이상 입력해주세요.';
                                }

                                return null;
                              },
                            ),

                            SizedBox(height: 18),

                            TextFormField(
                              controller:
                              _certificateNameController,
                              textInputAction:
                              TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: '자격증 이름',
                                hintText: '예: 정보처리기사',
                                prefixIcon: Icon(
                                  Icons
                                      .workspace_premium_outlined,
                                ),
                                border:
                                OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    14,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 18),

                            TextFormField(
                              controller:
                              _descriptionController,
                              maxLines: 4,
                              maxLength: 200,
                              textInputAction:
                              TextInputAction.newline,
                              decoration: InputDecoration(
                                labelText: '스터디 소개',
                                hintText:
                                '스터디 목표와 진행 방법을 입력해주세요.',
                                alignLabelWithHint: true,
                                border:
                                OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    14,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.trim().isEmpty) {
                                  return '스터디 소개를 입력해주세요.';
                                }

                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 18),

                      AppCard(
                        backgroundColor: _studyColorScheme.surface,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              '시험 및 학습 목표',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 6),

                            Text(
                              '시험일까지 남은 기간과 주간 달성률을 스터디방에 표시합니다.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: _studyColors.textSecondary,
                              ),
                            ),

                            SizedBox(height: 20),

                            InkWell(
                              borderRadius:
                              BorderRadius.circular(14),
                              onTap: _selectExamDate,
                              child: Container(
                                width: double.infinity,
                                constraints: BoxConstraints(
                                  minHeight: 58,
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _studyColorScheme
                                        .outlineVariant,
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons
                                          .calendar_month_outlined,
                                      color:
                                      _studyColors.pinkStart,
                                    ),

                                    SizedBox(width: 12),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '시험일',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _studyColors
                                                  .textSecondary,
                                            ),
                                          ),

                                          SizedBox(height: 4),

                                          Text(
                                            _examDate == null
                                                ? '시험일을 선택해 주세요.'
                                                : _formatDate(
                                              _examDate!,
                                            ),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                              FontWeight.w600,
                                              color: _examDate ==
                                                  null
                                                  ? _studyColors
                                                  .textSecondary
                                                  : _studyColors
                                                  .textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    if (_examDate != null)
                                      IconButton(
                                        tooltip: '시험일 지우기',
                                        onPressed: () {
                                          setState(() {
                                            _examDate = null;
                                          });
                                        },
                                        icon: Icon(
                                          Icons.close_rounded,
                                          size: 19,
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons
                                            .chevron_right_rounded,
                                        color: _studyColors
                                            .textSecondary,
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: 18),

                            TextFormField(
                              controller:
                              _weeklyGoalHourController,
                              keyboardType:
                              TextInputType.number,
                              textInputAction:
                              TextInputAction.done,
                              decoration: InputDecoration(
                                labelText:
                                '주간 목표 공부시간',
                                hintText: '예: 15',
                                suffixText: '시간',
                                prefixIcon: Icon(
                                  Icons
                                      .flag_outlined,
                                ),
                                border:
                                OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    14,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                int? goalHour =
                                int.tryParse(
                                  value?.trim() ?? '',
                                );

                                if (goalHour == null) {
                                  return '주간 목표시간을 숫자로 입력해주세요.';
                                }

                                if (goalHour < 1 ||
                                    goalHour > 168) {
                                  return '1시간 이상 168시간 이하로 입력해주세요.';
                                }

                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 18),

                      AppCard(
                        backgroundColor: _studyColorScheme.surface,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              '스터디 설정',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 20),

                            Text(
                              '최대 인원',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),

                            SizedBox(height: 12),

                            Row(
                              children: [
                                IconButton(
                                  onPressed:
                                  _maxMemberCount >
                                      _minimumMemberCount
                                      ? () {
                                    setState(() {
                                      _maxMemberCount--;
                                    });
                                  }
                                      : null,
                                  icon: Icon(
                                    Icons
                                        .remove_circle_outline,
                                  ),
                                ),

                                SizedBox(width: 8),

                                Expanded(
                                  child: Container(
                                    height: 56,
                                    alignment:
                                    Alignment.center,
                                    decoration:
                                    BoxDecoration(
                                      color: _studyColors.lavender,
                                      borderRadius:
                                      BorderRadius.circular(
                                        14,
                                      ),
                                    ),
                                    child: Text(
                                      '$_maxMemberCount명',
                                      style:
                                      TextStyle(
                                        fontSize: 18,
                                        fontWeight:
                                        FontWeight.bold,
                                        color: _studyColors.pinkStart,
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(width: 8),

                                IconButton(
                                  onPressed:
                                  _maxMemberCount < 30
                                      ? () {
                                    setState(() {
                                      _maxMemberCount++;
                                    });
                                  }
                                      : null,
                                  icon: Icon(
                                    Icons
                                        .add_circle_outline,
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 9),

                            Align(
                              alignment:
                              Alignment.centerRight,
                              child: Text(
                                _currentMemberCount > 2
                                    ? '현재 인원 $_currentMemberCount명 · 최대 30명'
                                    : '최소 2명 · 최대 30명',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _studyColors.textSecondary,
                                ),
                              ),
                            ),

                            Divider(height: 35),

                            SwitchListTile(
                              contentPadding:
                              EdgeInsets.zero,
                              title: Text(
                                '공개 스터디',
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                _isPublic
                                    ? '다른 사용자가 검색하고 확인할 수 있습니다.'
                                    : '초대받은 사용자만 확인할 수 있습니다.',
                              ),
                              value: _isPublic,
                              onChanged: (value) {
                                setState(() {
                                  _isPublic = value;
                                });
                              },
                            ),

                            Divider(height: 1),

                            SwitchListTile(
                              contentPadding:
                              EdgeInsets.zero,
                              title: Text(
                                '참여 승인 필요',
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                _joinApprovalRequired
                                    ? '방장이 승인해야 참여할 수 있습니다.'
                                    : '신청하면 바로 참여할 수 있습니다.',
                              ),
                              value:
                              _joinApprovalRequired,
                              onChanged: (value) {
                                setState(() {
                                  _joinApprovalRequired =
                                      value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 25),

                      AppButton(
                        text: '수정 완료',
                        type: AppButtonType.primaryPink,
                        height: 54,
                        onPressed: _isSaving ? null : _updateStudy,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isSaving)
            Positioned.fill(
              child: LoadingOverlay(),
            ),
        ],
      ),
    );
  }
}