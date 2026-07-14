import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

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

  @override
  void dispose() {
    _groupNameController.dispose();
    _certificateNameController.dispose();
    _descriptionController.dispose();

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
        const SnackBar(
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

      body: AppMainBackground(
        applySafeArea: false,
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior
                .onDrag,
            padding: const EdgeInsets.fromLTRB(
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
                  const Text(
                    '스터디 정보를 수정해보세요',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    '수정한 내용은 스터디 화면에 바로 반영됩니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7B7F89),
                    ),
                  ),

                  const SizedBox(height: 25),

                  AppCard(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '기본 정보',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 20),

                        TextFormField(
                          controller:
                          _groupNameController,
                          textInputAction:
                          TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: '스터디 이름',
                            hintText:
                            '예: 정보처리기사 실기 스터디',
                            prefixIcon: const Icon(
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

                        const SizedBox(height: 18),

                        TextFormField(
                          controller:
                          _certificateNameController,
                          textInputAction:
                          TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: '자격증 이름',
                            hintText: '예: 정보처리기사',
                            prefixIcon: const Icon(
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

                        const SizedBox(height: 18),

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

                  const SizedBox(height: 18),

                  AppCard(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '스터디 설정',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          '최대 인원',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 12),

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
                              icon: const Icon(
                                Icons
                                    .remove_circle_outline,
                              ),
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: Container(
                                height: 56,
                                alignment:
                                Alignment.center,
                                decoration:
                                BoxDecoration(
                                  color: const Color(
                                    0xFFF0ECFF,
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(
                                    14,
                                  ),
                                ),
                                child: Text(
                                  '$_maxMemberCount명',
                                  style:
                                  const TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                    FontWeight.bold,
                                    color: Color(
                                      0xFF6F58C9,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            IconButton(
                              onPressed:
                              _maxMemberCount < 30
                                  ? () {
                                setState(() {
                                  _maxMemberCount++;
                                });
                              }
                                  : null,
                              icon: const Icon(
                                Icons
                                    .add_circle_outline,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 9),

                        Align(
                          alignment:
                          Alignment.centerRight,
                          child: Text(
                            _currentMemberCount > 2
                                ? '현재 인원 $_currentMemberCount명 · 최대 30명'
                                : '최소 2명 · 최대 30명',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(
                                0xFF858994,
                              ),
                            ),
                          ),
                        ),

                        const Divider(height: 35),

                        SwitchListTile(
                          contentPadding:
                          EdgeInsets.zero,
                          title: const Text(
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

                        const Divider(height: 1),

                        SwitchListTile(
                          contentPadding:
                          EdgeInsets.zero,
                          title: const Text(
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

                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed:
                      _isSaving ? null : _updateStudy,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF8068D8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(15),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        '수정 완료',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}