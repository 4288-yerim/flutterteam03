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

class _StudyQuizAddPageState extends State<StudyQuizAddPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _subjectController = TextEditingController();

  final TextEditingController _questionController = TextEditingController();

  final TextEditingController _choice1Controller = TextEditingController();

  final TextEditingController _choice2Controller = TextEditingController();

  final TextEditingController _choice3Controller = TextEditingController();

  final TextEditingController _choice4Controller = TextEditingController();

  final TextEditingController _explanationController = TextEditingController();

  final TextEditingController _pointController = TextEditingController(
    text: '10',
  );

  String _quizType = 'MULTIPLE_CHOICE';
  String _answerRevealType = 'AFTER_SUBMIT';

  int _correctAnswerIndex = 0;
  int _timeLimitSeconds = 60;
  int _deadlineHours = 24;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _choice1Controller.text = '';
    _choice2Controller.text = '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
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
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName을 입력해 주세요.';
    }

    return null;
  }

  int _getPoint() {
    int point = int.tryParse(_pointController.text.trim()) ?? 0;

    if (point < 0) {
      point = 0;
    }

    if (point > 100) {
      point = 100;
    }

    return point;
  }

  List<String> _getChoices() {
    if (_quizType == 'OX') {
      return ['O', 'X'];
    }

    return [
      _choice1Controller.text.trim(),
      _choice2Controller.text.trim(),
      _choice3Controller.text.trim(),
      _choice4Controller.text.trim(),
    ];
  }

  Future<bool> _checkOwner(User currentUser) async {
    DocumentSnapshot<Map<String, dynamic>> groupSnapshot =
        await FirebaseFirestore.instance
            .collection('studyGroups')
            .doc(widget.studyId)
            .get();

    if (!groupSnapshot.exists) {
      throw Exception('스터디 정보를 찾을 수 없습니다.');
    }

    Map<String, dynamic> groupData = groupSnapshot.data() ?? {};

    String ownerUid = groupData['ownerUid']?.toString() ?? '';

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

    if (!memberSnapshot.exists) {
      return false;
    }

    String role = memberSnapshot.data()?['role']?.toString() ?? '';

    return role == 'OWNER';
  }

  Future<Map<String, String>> _getSenderProfile(User currentUser) async {
    String nickname = '';
    String profileImageUrl = '';

    try {
      DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
          await FirebaseFirestore.instance
              .collection('studyGroups')
              .doc(widget.studyId)
              .collection('members')
              .doc(currentUser.uid)
              .get();

      if (memberSnapshot.exists) {
        Map<String, dynamic> memberData = memberSnapshot.data() ?? {};

        nickname = memberData['nickname']?.toString().trim() ?? '';

        profileImageUrl =
            memberData['profileImageUrl']?.toString().trim() ?? '';
      }

      if (nickname.isEmpty || profileImageUrl.isEmpty) {
        DocumentSnapshot<Map<String, dynamic>> directUserSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();

        Map<String, dynamic> userData = {};

        if (directUserSnapshot.exists) {
          userData = directUserSnapshot.data() ?? {};
        } else {
          QuerySnapshot<Map<String, dynamic>> userSnapshot =
              await FirebaseFirestore.instance
                  .collection('users')
                  .where('uid', isEqualTo: currentUser.uid)
                  .limit(1)
                  .get();

          if (userSnapshot.docs.isNotEmpty) {
            userData = userSnapshot.docs.first.data();
          }
        }

        if (nickname.isEmpty) {
          nickname = userData['nickname']?.toString().trim() ?? '';
        }

        if (profileImageUrl.isEmpty) {
          profileImageUrl =
              userData['profileImageUrl']?.toString().trim() ?? '';

          if (profileImageUrl.isEmpty) {
            profileImageUrl = userData['photoUrl']?.toString().trim() ?? '';
          }
        }
      }
    } catch (error) {
      debugPrint('문제 발송자 정보 조회 오류: $error');
    }

    if (nickname.isEmpty) {
      nickname = currentUser.displayName?.trim() ?? '';
    }

    if (profileImageUrl.isEmpty) {
      profileImageUrl = currentUser.photoURL?.trim() ?? '';
    }

    if (nickname.isEmpty) {
      nickname = '방장';
    }

    return {'nickname': nickname, 'profileImageUrl': profileImageUrl};
  }

  Future<void> _sendQuiz() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSaving) {
      return;
    }

    if (_quizType == 'MULTIPLE_CHOICE') {
      List<String> choices = _getChoices();

      for (int i = 0; i < choices.length; i++) {
        if (choices[i].isEmpty) {
          _showMessage('${i + 1}번 보기를 입력해 주세요.');
          return;
        }
      }
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('로그인 정보가 없습니다.');
      }

      bool isOwner = await _checkOwner(currentUser);

      if (!isOwner) {
        throw Exception('방장만 문제를 발송할 수 있습니다.');
      }

      Map<String, String> senderProfile = await _getSenderProfile(currentUser);

      String senderNickname = senderProfile['nickname'] ?? '방장';

      String senderProfileImageUrl = senderProfile['profileImageUrl'] ?? '';

      DateTime now = DateTime.now();

      DateTime deadlineAt = now.add(Duration(hours: _deadlineHours));

      DocumentReference<Map<String, dynamic>> quizDocument = FirebaseFirestore
          .instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('quizzes')
          .doc();

      DocumentReference<Map<String, dynamic>> chatDocument = FirebaseFirestore
          .instance
          .collection('chats')
          .doc(widget.studyId);

      DocumentReference<Map<String, dynamic>> messageDocument = chatDocument
          .collection('messages')
          .doc();

      String title = _titleController.text.trim();

      String subject = _subjectController.text.trim();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.set(quizDocument, {
        'groupId': widget.studyId,
        'groupName': widget.groupName,
        'title': title,
        'subject': subject,
        'question': _questionController.text.trim(),
        'quizType': _quizType,
        'choices': _getChoices(),
        'correctAnswerIndex': _correctAnswerIndex,
        'explanation': _explanationController.text.trim(),
        'point': _getPoint(),
        'timeLimitSeconds': _timeLimitSeconds,
        'deadlineAt': Timestamp.fromDate(deadlineAt),
        'answerRevealType': _answerRevealType,
        'senderUid': currentUser.uid,
        'senderNickname': senderNickname,
        'senderProfileImageUrl': senderProfileImageUrl,
        'status': 'ACTIVE',
        'answerCount': 0,
        'correctAnswerCount': 0,
        'wrongAnswerCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(messageDocument, {
        'senderUid': currentUser.uid,
        'senderNickname': senderNickname,
        'senderProfileImageUrl': senderProfileImageUrl,
        'message': '새 문제가 발송되었습니다.',
        'messageType': 'QUIZ',
        'quizId': quizDocument.id,
        'quizTitle': title,
        'quizSubject': subject,
        'quizType': _quizType,
        'quizTimeLimitSeconds': _timeLimitSeconds,
        'quizDeadlineAt': Timestamp.fromDate(deadlineAt),
        'replyMessageId': '',
        'replySenderNickname': '',
        'replyMessage': '',
        'readBy': [currentUser.uid],
        'hiddenFor': [],
        'isDeleted': false,
        'isEdited': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(chatDocument, {
        'chatType': 'GROUP',
        'groupId': widget.studyId,
        'groupName': widget.groupName,
        'lastMessage': '새 퀴즈: $title',
        'lastMessageId': messageDocument.id,
        'lastSenderUid': currentUser.uid,
        'lastSenderNickname': senderNickname,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

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

  Widget _buildSectionTitle(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
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
              return _validateRequired(value, fieldName);
            }
          : null,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        counterText: '',
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.colors.pinkStart, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceInput(int index, TextEditingController controller) {
    bool isCorrect = _correctAnswerIndex == index;

    return Container(
      margin: EdgeInsets.only(bottom: 11),
      padding: EdgeInsets.fromLTRB(10, 9, 12, 9),
      decoration: BoxDecoration(
        color: isCorrect
            ? context.colors.lavender
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isCorrect
              ? context.colors.pinkStart
              : Theme.of(context).colorScheme.outlineVariant,
          width: isCorrect ? 1.4 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Radio<int>(
            value: index,
            groupValue: _correctAnswerIndex,
            activeColor: context.colors.pinkStart,
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
                if (_quizType != 'MULTIPLE_CHOICE') {
                  return null;
                }

                return _validateRequired(value, '${index + 1}번 보기');
              },
              decoration: InputDecoration(
                hintText: '${index + 1}번 보기를 입력하세요.',
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(top: 13, bottom: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizTypeButton({
    required String value,
    required String title,
    required String description,
    required IconData icon,
  }) {
    bool isSelected = _quizType == value;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _quizType = value;
            _correctAnswerIndex = 0;

            if (value == 'OX') {
              _choice1Controller.text = 'O';

              _choice2Controller.text = 'X';
            }
          });
        },
        child: Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? context.colors.pinkSoft
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? context.colors.pinkStart
                  : Theme.of(context).colorScheme.outlineVariant,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? context.colors.pinkStart
                    : context.colors.textSecondary,
              ),
              SizedBox(height: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? context.colors.pinkStart
                      : context.colors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOXAnswer() {
    return Row(
      children: [
        for (int i = 0; i < 2; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 0 ? 8 : 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _correctAnswerIndex = i;
                  });
                },
                child: Container(
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _correctAnswerIndex == i
                        ? context.colors.lavender
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _correctAnswerIndex == i
                          ? context.colors.pinkStart
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: _correctAnswerIndex == i ? 1.4 : 1,
                    ),
                  ),
                  child: Text(
                    i == 0 ? 'O' : 'X',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _correctAnswerIndex == i
                          ? context.colors.pinkStart
                          : context.colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppTopBar(title: '문제 발송'),
      body: Stack(
        children: [
          AppMainBackground(
            applySafeArea: false,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 22, 20, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.groupName,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '스터디원에게 보낼 문제를 작성해 주세요.',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 22),
                    AppCard(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('문제 유형', '객관식 또는 OX 문제를 선택해 주세요.'),
                          SizedBox(height: 15),
                          Row(
                            children: [
                              _buildQuizTypeButton(
                                value: 'MULTIPLE_CHOICE',
                                title: '객관식',
                                description: '보기 4개 중 정답 선택',
                                icon: Icons.format_list_numbered_rounded,
                              ),
                              SizedBox(width: 10),
                              _buildQuizTypeButton(
                                value: 'OX',
                                title: 'OX',
                                description: 'O 또는 X로 빠르게 응답',
                                icon: Icons.check_circle_outline_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 18),
                    AppCard(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            '문제 정보',
                            '과목, 제목과 문제 내용을 입력해 주세요.',
                          ),
                          SizedBox(height: 18),
                          _buildTextField(
                            controller: _subjectController,
                            hintText: '예: 데이터베이스',
                            fieldName: '과목',
                            maxLength: 30,
                          ),
                          SizedBox(height: 13),
                          _buildTextField(
                            controller: _titleController,
                            hintText: '예: 기본키 특징 문제',
                            fieldName: '문제 제목',
                            maxLength: 60,
                          ),
                          SizedBox(height: 13),
                          _buildTextField(
                            controller: _questionController,
                            hintText: '스터디원에게 출제할 문제를 입력하세요.',
                            fieldName: '문제 내용',
                            maxLines: 5,
                            maxLength: 500,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 18),
                    AppCard(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            '보기와 정답',
                            _quizType == 'OX'
                                ? '정답인 O 또는 X를 선택해 주세요.'
                                : '정답인 보기의 동그라미를 선택해 주세요.',
                          ),
                          SizedBox(height: 18),
                          if (_quizType == 'OX')
                            _buildOXAnswer()
                          else ...[
                            _buildChoiceInput(0, _choice1Controller),
                            _buildChoiceInput(1, _choice2Controller),
                            _buildChoiceInput(2, _choice3Controller),
                            _buildChoiceInput(3, _choice4Controller),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 18),
                    AppCard(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            '응답 설정',
                            '제한시간과 제출 마감시간을 설정해 주세요.',
                          ),
                          SizedBox(height: 18),
                          _buildDropdown<int>(
                            label: '풀이 제한시간',
                            value: _timeLimitSeconds,
                            items: [
                              DropdownMenuItem(value: 30, child: Text('30초')),
                              DropdownMenuItem(value: 60, child: Text('1분')),
                              DropdownMenuItem(value: 180, child: Text('3분')),
                              DropdownMenuItem(value: 300, child: Text('5분')),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                _timeLimitSeconds = value;
                              });
                            },
                          ),
                          SizedBox(height: 13),
                          _buildDropdown<int>(
                            label: '제출 마감',
                            value: _deadlineHours,
                            items: [
                              DropdownMenuItem(value: 1, child: Text('1시간 후')),
                              DropdownMenuItem(value: 6, child: Text('6시간 후')),
                              DropdownMenuItem(
                                value: 24,
                                child: Text('24시간 후'),
                              ),
                              DropdownMenuItem(value: 72, child: Text('3일 후')),
                              DropdownMenuItem(value: 168, child: Text('7일 후')),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                _deadlineHours = value;
                              });
                            },
                          ),
                          SizedBox(height: 13),
                          _buildDropdown<String>(
                            label: '정답 공개',
                            value: _answerRevealType,
                            items: [
                              DropdownMenuItem(
                                value: 'AFTER_SUBMIT',
                                child: Text('제출 즉시 공개'),
                              ),
                              DropdownMenuItem(
                                value: 'AFTER_DEADLINE',
                                child: Text('마감 후 공개'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                _answerRevealType = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 18),
                    AppCard(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            '해설과 점수',
                            '해설은 선택이며 점수는 0점부터 100점까지 입력할 수 있습니다.',
                          ),
                          SizedBox(height: 18),
                          _buildTextField(
                            controller: _explanationController,
                            hintText: '정답 해설을 입력하세요.',
                            fieldName: '해설',
                            maxLines: 4,
                            maxLength: 500,
                            required: false,
                          ),
                          SizedBox(height: 13),
                          _buildTextField(
                            controller: _pointController,
                            hintText: '예: 10',
                            fieldName: '점수',
                            maxLength: 3,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    AppButton(
                      text: _isSaving ? '발송 중...' : '문제 발송하기',
                      type: AppButtonType.primaryPink,
                      height: 54,
                      onPressed: _isSaving ? null : _sendQuiz,
                    ),
                  ],
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
