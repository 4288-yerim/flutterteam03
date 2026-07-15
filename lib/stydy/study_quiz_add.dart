import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/loading_overlay.dart';


Brightness get _quizAddBrightness {
  return WidgetsBinding.instance.platformDispatcher.platformBrightness;
}

AppColors get _quizAddColors {
  if (_quizAddBrightness == Brightness.dark) {
    return AppColors.dark;
  }

  return AppColors.light;
}

ColorScheme get _quizAddColorScheme {
  if (_quizAddBrightness == Brightness.dark) {
    return darkTheme.colorScheme;
  }

  return lightTheme.colorScheme;
}

class StudyQuizAddPage extends StatefulWidget {
  final String studyId;
  final String groupName;

  const StudyQuizAddPage({
    super.key,
    required this.studyId,
    required this.groupName,
  });

  @override
  State<StudyQuizAddPage> createState() {
    return _StudyQuizAddPageState();
  }
}

class _StudyQuizAddPageState
    extends State<StudyQuizAddPage> {
  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  final TextEditingController _titleController =
  TextEditingController();

  final TextEditingController _questionController =
  TextEditingController();

  final TextEditingController _choice1Controller =
  TextEditingController();

  final TextEditingController _choice2Controller =
  TextEditingController();

  final TextEditingController _choice3Controller =
  TextEditingController();

  final TextEditingController _choice4Controller =
  TextEditingController();

  final TextEditingController _explanationController =
  TextEditingController();

  final TextEditingController _pointController =
  TextEditingController(
    text: '10',
  );

  int _correctAnswerIndex = 0;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _questionController.dispose();
    _choice1Controller.dispose();
    _choice2Controller.dispose();
    _choice3Controller.dispose();
    _choice4Controller.dispose();
    _explanationController.dispose();
    _pointController.dispose();

    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String? _validateRequired(
      String? value,
      String fieldName,
      ) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName을 입력해 주세요.';
    }

    return null;
  }

  int _getPoint() {
    int point =
        int.tryParse(_pointController.text.trim()) ?? 0;

    if (point < 0) {
      point = 0;
    }

    if (point > 100) {
      point = 100;
    }

    return point;
  }

  /// 방장 여부 확인
  Future<bool> _checkOwner(
      User currentUser,
      ) async {
    DocumentSnapshot<Map<String, dynamic>> groupSnapshot =
    await FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(widget.studyId)
        .get();

    if (groupSnapshot.exists == false) {
      throw Exception('스터디 정보를 찾을 수 없습니다.');
    }

    Map<String, dynamic> groupData =
        groupSnapshot.data() ?? {};

    String ownerUid =
        groupData['ownerUid']?.toString() ?? '';

    if (ownerUid == currentUser.uid) {
      return true;
    }

    DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
    await FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(widget.studyId)
        .collection('members')
        .doc(currentUser.uid)
        .get();

    if (memberSnapshot.exists) {
      Map<String, dynamic> memberData =
          memberSnapshot.data() ?? {};

      String role =
          memberData['role']?.toString() ?? '';

      if (role == 'OWNER') {
        return true;
      }
    }

    return false;
  }

  /// 발송자 닉네임 가져오기
  Future<String> _getSenderNickname(
      User currentUser,
      ) async {
    String nickname =
        currentUser.displayName?.trim() ?? '';

    try {
      DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
      await FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('members')
          .doc(currentUser.uid)
          .get();

      if (memberSnapshot.exists) {
        Map<String, dynamic> memberData =
            memberSnapshot.data() ?? {};

        String memberNickname =
            memberData['nickname']?.toString().trim() ?? '';

        if (memberNickname.isNotEmpty) {
          nickname = memberNickname;
        }
      }
    } catch (error) {
      debugPrint('문제 발송자 닉네임 조회 오류: $error');
    }

    if (nickname.isEmpty) {
      nickname = '방장';
    }

    return nickname;
  }

  /// Firestore에 문제 발송
  Future<void> _sendQuiz() async {
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
      User? currentUser =
          FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('로그인 정보가 없습니다.');
      }

      bool isOwner =
      await _checkOwner(currentUser);

      if (isOwner == false) {
        throw Exception('방장만 문제를 발송할 수 있습니다.');
      }

      String senderNickname =
      await _getSenderNickname(currentUser);

      List<String> choices = [
        _choice1Controller.text.trim(),
        _choice2Controller.text.trim(),
        _choice3Controller.text.trim(),
        _choice4Controller.text.trim(),
      ];

      await FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('quizzes')
          .add({
        'groupId': widget.studyId,
        'groupName': widget.groupName,

        'title':
        _titleController.text.trim(),

        'question':
        _questionController.text.trim(),

        'choices': choices,

        'correctAnswerIndex':
        _correctAnswerIndex,

        'explanation':
        _explanationController.text.trim(),

        'point': _getPoint(),

        'senderUid': currentUser.uid,
        'senderNickname': senderNickname,

        'status': 'ACTIVE',
        'answerCount': 0,
        'correctAnswerCount': 0,

        'createdAt':
        FieldValue.serverTimestamp(),

        'updatedAt':
        FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      _showMessage('문제가 발송되었습니다.');

      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('문제 발송 오류: $error');

      if (!mounted) {
        return;
      }

      String message = '문제를 발송하지 못했습니다.';

      String errorText = error.toString();

      if (errorText.contains('방장만')) {
        message = '방장만 문제를 발송할 수 있습니다.';
      } else if (errorText.contains('로그인')) {
        message = '로그인 정보가 없습니다.';
      } else if (errorText.contains('스터디 정보')) {
        message = '스터디 정보를 찾을 수 없습니다.';
      }

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildSectionTitle(
      String title,
      String description,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _quizAddColors.textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: _quizAddColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required String fieldName,
    int maxLines = 1,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: required
          ? (value) {
        return _validateRequired(
          value,
          fieldName,
        );
      }
          : null,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: _quizAddColors.textSecondary,
          fontSize: 13,
        ),
        counterText: '',
        filled: true,
        fillColor: _quizAddColorScheme.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color:
            _quizAddColorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: _quizAddColors.pinkStart,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: _quizAddColorScheme.error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: _quizAddColorScheme.error,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceInput(
      int index,
      TextEditingController controller,
      ) {
    bool isCorrect =
        _correctAnswerIndex == index;

    return Container(
      margin: EdgeInsets.only(bottom: 11),
      padding: EdgeInsets.fromLTRB(
        10,
        9,
        12,
        9,
      ),
      decoration: BoxDecoration(
        color: isCorrect
            ? _quizAddColors.lavender
            : _quizAddColorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isCorrect
              ? _quizAddColors.pinkStart
              : _quizAddColorScheme.outlineVariant,
          width: isCorrect ? 1.4 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Radio<int>(
            value: index,
            groupValue: _correctAnswerIndex,
            activeColor: _quizAddColors.pinkStart,
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _correctAnswerIndex = value;
              });
            },
          ),

          SizedBox(width: 2),

          Expanded(
            child: TextFormField(
              controller: controller,
              maxLength: 100,
              validator: (value) {
                return _validateRequired(
                  value,
                  '${index + 1}번 보기',
                );
              },
              decoration: InputDecoration(
                hintText: '${index + 1}번 보기를 입력하세요.',
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(
                  top: 13,
                  bottom: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppTopBar(
        title: '문제 발송',
      ),
      body: Stack(
        children: [
          AppMainBackground(
            applySafeArea: false,
            child: SingleChildScrollView(
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                22,
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
                      widget.groupName,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                        _quizAddColors.textSecondary,
                      ),
                    ),

                    SizedBox(height: 5),

                    Text(
                      '스터디원에게 보낼 문제를 작성해 주세요.',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color:
                        _quizAddColors.textPrimary,
                      ),
                    ),

                    SizedBox(height: 22),

                    AppCard(
                      backgroundColor:
                      _quizAddColorScheme.surface,
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            '문제 정보',
                            '제목과 문제 내용을 입력해 주세요.',
                          ),

                          SizedBox(height: 18),

                          _buildTextField(
                            controller:
                            _titleController,
                            hintText:
                            '예: 네트워크 기본 문제',
                            fieldName: '문제 제목',
                            maxLength: 60,
                          ),

                          SizedBox(height: 13),

                          _buildTextField(
                            controller:
                            _questionController,
                            hintText:
                            '스터디원에게 출제할 문제를 입력하세요.',
                            fieldName: '문제 내용',
                            maxLines: 5,
                            maxLength: 500,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 18),

                    AppCard(
                      backgroundColor:
                      _quizAddColorScheme.surface,
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            '보기와 정답',
                            '정답인 보기의 동그라미를 선택해 주세요.',
                          ),

                          SizedBox(height: 18),

                          _buildChoiceInput(
                            0,
                            _choice1Controller,
                          ),

                          _buildChoiceInput(
                            1,
                            _choice2Controller,
                          ),

                          _buildChoiceInput(
                            2,
                            _choice3Controller,
                          ),

                          _buildChoiceInput(
                            3,
                            _choice4Controller,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 18),

                    AppCard(
                      backgroundColor:
                      _quizAddColorScheme.surface,
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            '해설과 점수',
                            '해설은 선택이며 점수는 0점부터 100점까지 입력할 수 있습니다.',
                          ),

                          SizedBox(height: 18),

                          _buildTextField(
                            controller:
                            _explanationController,
                            hintText:
                            '정답 해설을 입력하세요.',
                            fieldName: '해설',
                            maxLines: 4,
                            maxLength: 500,
                            required: false,
                          ),

                          SizedBox(height: 13),

                          _buildTextField(
                            controller:
                            _pointController,
                            hintText: '점수',
                            fieldName: '점수',
                            keyboardType:
                            TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .digitsOnly,
                              LengthLimitingTextInputFormatter(
                                3,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    AppButton(
                      text: '문제 발송하기',
                      type:
                      AppButtonType.primaryPink,
                      height: 52,
                      onPressed: _isSaving
                          ? null
                          : _sendQuiz,
                    ),
                  ],
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
