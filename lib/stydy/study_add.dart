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

class StudyCreatePage extends StatefulWidget {
  const StudyCreatePage({super.key});

  @override
  State<StudyCreatePage> createState() =>
      _StudyCreatePageState();
}

class _StudyCreatePageState extends State<StudyCreatePage> {
  // 입력값 확인용 키
  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  // 입력창 컨트롤러
  final TextEditingController _groupNameController =
  TextEditingController();

  final TextEditingController
  _certificateNameController =
  TextEditingController();

  final TextEditingController _descriptionController =
  TextEditingController();

  // 최대 인원
  int _maxMemberCount = 5;

  // 공개 여부
  bool _isPublic = true;

  // 참여 승인 필요 여부
  bool _joinApprovalRequired = true;

  // 저장 중인지 확인
  bool _isSaving = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _certificateNameController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  /// Firestore에 스터디 저장
  Future<void> _saveStudy() async {
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
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('로그인 정보가 없습니다.');
      }

      final String ownerNickname =
      user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : '익명 사용자';

      // 스터디 문서를 먼저 직접 생성
      final studyDocument = FirebaseFirestore.instance
          .collection('studyGroups')
          .doc();

      // 스터디와 방장 멤버 정보를 한꺼번에 저장
      final batch = FirebaseFirestore.instance.batch();

      batch.set(
        studyDocument,
        {
          // 스터디 기본 정보
          'groupName':
          _groupNameController.text.trim(),
          'description':
          _descriptionController.text.trim(),

          // 방장 정보
          'ownerUid': user.uid,
          'ownerNickname': ownerNickname,

          // 자격증 정보
          'certificateId': '',
          'certificateName':
          _certificateNameController.text
              .trim()
              .isEmpty
              ? '공통 스터디'
              : _certificateNameController.text
              .trim(),

          // 인원 정보
          'maxMemberCount': _maxMemberCount,
          'currentMemberCount': 1,

          // 공개 및 승인 설정
          'isPublic': _isPublic,
          'joinApprovalRequired':
          _joinApprovalRequired,

          // 추후 연결할 값
          'inviteCode': '',
          'chatId': '',

          // 모집 상태
          'status': 'RECRUITING',

          // 생성 및 수정 시간
          'createdAt':
          FieldValue.serverTimestamp(),
          'updatedAt':
          FieldValue.serverTimestamp(),
        },
      );

      // 방장을 스터디 멤버로 저장
      final ownerMemberDocument = studyDocument
          .collection('members')
          .doc(user.uid);

      batch.set(
        ownerMemberDocument,
        {
          'uid': user.uid,
          'nickname': ownerNickname,
          'role': 'OWNER',
          'status': 'ACTIVE',

          // 공부시간은 분 단위로 저장
          'totalStudyMinutes': 0,

          'joinedAt':
          FieldValue.serverTimestamp(),
          'updatedAt':
          FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('스터디가 등록되었습니다.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('스터디 등록 오류: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '스터디 등록 실패: $error',
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
        title: '스터디 만들기',
        centerTitle: false,
      ),

      body: Stack(
        children: [
          AppMainBackground(
            applySafeArea: false,
            child: SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
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
                        '새로운 스터디를 만들어보세요',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 8),

                      Text(
                        '스터디 정보를 입력하면 목록에 바로 등록됩니다.',
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

                            // 스터디 이름
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

                            // 자격증 이름
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

                            // 스터디 소개
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
                                  _maxMemberCount > 2
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
                                '최소 2명 · 최대 30명',
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
                        text: '스터디 만들기',
                        type: AppButtonType.primaryPink,
                        height: 54,
                        onPressed: _isSaving ? null : _saveStudy,
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