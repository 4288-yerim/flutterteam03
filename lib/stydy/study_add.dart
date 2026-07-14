import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';

class StudyCreatePage extends StatefulWidget {
  const StudyCreatePage({super.key});

  @override
  State<StudyCreatePage> createState() => _StudyCreatePageState();
}

class _StudyCreatePageState extends State<StudyCreatePage> {
  // 입력값 확인용 키
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // 입력창 컨트롤러
  final TextEditingController _groupNameController =
  TextEditingController();

  final TextEditingController _certificateNameController =
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
    // 입력값 검사
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 중복 클릭 방지
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('로그인 정보가 없습니다.');
      }

      await FirebaseFirestore.instance
          .collection('studyGroups')
          .add({
        // 스터디 기본 정보
        'groupName': _groupNameController.text.trim(),
        'description': _descriptionController.text.trim(),

        // 방장 정보
        'ownerUid': user.uid,
        'ownerNickname': user.displayName ?? '익명 사용자',

        // 자격증 정보
        'certificateId': '',
        'certificateName':
        _certificateNameController.text.trim().isEmpty
            ? '공통 스터디'
            : _certificateNameController.text.trim(),

        // 인원 정보
        'maxMemberCount': _maxMemberCount,
        'currentMemberCount': 1,

        // 공개 및 승인 설정
        'isPublic': _isPublic,
        'joinApprovalRequired': _joinApprovalRequired,

        // 추후 연결할 값
        'inviteCode': '',
        'chatId': '',

        // 모집 상태
        'status': 'RECRUITING',

        // 생성 및 수정 시간
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('스터디가 등록되었습니다.'),
        ),
      );

      // 목록 화면으로 돌아가기
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('스터디 등록 실패: $error'),
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
      appBar: AppTopBar(
        title: '스터디 만들기',
        centerTitle: false,
      ),

      body: AppMainBackground(
        applySafeArea: false,

        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              25,
              20,
              40,
            ),

            child: Form(
              key: _formKey,

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    '새로운 스터디를 만들어보세요',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    '스터디 정보를 입력하면 목록에 바로 등록됩니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7B7F89),
                    ),
                  ),

                  const SizedBox(height: 25),

                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          '기본 정보',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 스터디 이름
                        TextFormField(
                          controller: _groupNameController,

                          decoration: InputDecoration(
                            labelText: '스터디 이름',
                            hintText: '예: 정보처리기사 실기 스터디',
                            prefixIcon: const Icon(
                              Icons.groups_outlined,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(14),
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

                        // 자격증 이름
                        TextFormField(
                          controller:
                          _certificateNameController,

                          decoration: InputDecoration(
                            labelText: '자격증 이름',
                            hintText: '예: 정보처리기사',
                            prefixIcon: const Icon(
                              Icons.workspace_premium_outlined,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // 스터디 소개
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          maxLength: 200,

                          decoration: InputDecoration(
                            labelText: '스터디 소개',
                            hintText: '스터디 목표와 진행 방법을 입력해주세요.',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(14),
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
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          '스터디 설정',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          '최대 인원',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            IconButton(
                              onPressed: _maxMemberCount > 2
                                  ? () {
                                setState(() {
                                  _maxMemberCount--;
                                });
                              }
                                  : null,
                              icon: const Icon(
                                Icons.remove_circle_outline,
                              ),
                            ),

                            Container(
                              width: 90,
                              padding:
                              const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              alignment: Alignment.center,

                              decoration: BoxDecoration(
                                color: const Color(0xFFF0ECFF),
                                borderRadius:
                                BorderRadius.circular(12),
                              ),

                              child: Text(
                                '$_maxMemberCount명',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6F58C9),
                                ),
                              ),
                            ),

                            IconButton(
                              onPressed: _maxMemberCount < 30
                                  ? () {
                                setState(() {
                                  _maxMemberCount++;
                                });
                              }
                                  : null,
                              icon: const Icon(
                                Icons.add_circle_outline,
                              ),
                            ),

                            const Spacer(),

                            const Text(
                              '최소 2명 · 최대 30명',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF858994),
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 35),

                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,

                          title: const Text(
                            '공개 스터디',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
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
                          contentPadding: EdgeInsets.zero,

                          title: const Text(
                            '참여 승인 필요',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          subtitle: Text(
                            _joinApprovalRequired
                                ? '방장이 승인해야 참여할 수 있습니다.'
                                : '신청하면 바로 참여할 수 있습니다.',
                          ),

                          value: _joinApprovalRequired,

                          onChanged: (value) {
                            setState(() {
                              _joinApprovalRequired = value;
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
                      _isSaving ? null : _saveStudy,

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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        '스터디 만들기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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