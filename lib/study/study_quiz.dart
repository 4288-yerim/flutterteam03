import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutterteam03/widgets/app_state_views.dart';

import '../theme.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/loading_overlay.dart';
import 'study_quiz_add.dart';

class StudyQuizPage extends StatefulWidget {
  final String studyId;
  final String groupName;

  const StudyQuizPage({
    super.key,
    required this.studyId,
    required this.groupName,
  });

  @override
  State<StudyQuizPage> createState() {
    return _StudyQuizPageState();
  }
}

class _StudyQuizPageState extends State<StudyQuizPage> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _quizStream;

  bool _isOwner = false;
  bool _isOwnerLoading = true;

  @override
  void initState() {
    super.initState();

    _quizStream = _createQuizStream();
    _loadOwnerStatus();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _createQuizStream() {
    return FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(widget.studyId)
        .collection('quizzes')
        .snapshots();
  }

  bool _isNetworkError(Object? error) {
    if (error is FirebaseException) {
      if (error.code == 'unavailable' ||
          error.code == 'network-request-failed' ||
          error.code == 'deadline-exceeded') {
        return true;
      }
    }

    return false;
  }

  int _getInt(Map<String, dynamic> data, String fieldName) {
    dynamic value = data[fieldName];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  DateTime? _getDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return null;
  }

  String _formatDateTime(dynamic value) {
    DateTime? dateTime = _getDateTime(value);

    if (dateTime == null) {
      return '';
    }

    String month = dateTime.month.toString().padLeft(2, '0');

    String day = dateTime.day.toString().padLeft(2, '0');

    String hour = dateTime.hour.toString().padLeft(2, '0');

    String minute = dateTime.minute.toString().padLeft(2, '0');

    return '${dateTime.year}.$month.$day $hour:$minute';
  }

  String _formatLimitTime(int seconds) {
    if (seconds < 60) {
      return '$seconds초';
    }

    int minutes = seconds ~/ 60;

    return '$minutes분';
  }

  String _getQuizTypeText(Map<String, dynamic> data) {
    String quizType = data['quizType']?.toString() ?? 'MULTIPLE_CHOICE';

    if (quizType == 'OX') {
      return 'OX';
    }

    return '객관식';
  }

  bool _isDeadlinePassed(Map<String, dynamic> data) {
    DateTime? deadlineAt = _getDateTime(data['deadlineAt']);

    if (deadlineAt == null) {
      return false;
    }

    return DateTime.now().isAfter(deadlineAt);
  }

  Future<void> _loadOwnerStatus() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _isOwner = false;
          _isOwnerLoading = false;
        });
      }

      return;
    }

    try {
      DocumentSnapshot<Map<String, dynamic>> groupSnapshot =
          await FirebaseFirestore.instance
              .collection('studyGroups')
              .doc(widget.studyId)
              .get();

      bool isOwner = false;

      if (groupSnapshot.exists) {
        String ownerUid = groupSnapshot.data()?['ownerUid']?.toString() ?? '';

        isOwner = ownerUid == currentUser.uid;
      }

      if (!isOwner) {
        DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
            await FirebaseFirestore.instance
                .collection('studyGroups')
                .doc(widget.studyId)
                .collection('members')
                .doc(currentUser.uid)
                .get();

        String role = memberSnapshot.data()?['role']?.toString() ?? '';

        isOwner = role == 'OWNER';
      }

      if (mounted) {
        setState(() {
          _isOwner = isOwner;
          _isOwnerLoading = false;
        });
      }
    } catch (error) {
      debugPrint('문제 발송 권한 확인 오류: $error');

      if (mounted) {
        setState(() {
          _isOwner = false;
          _isOwnerLoading = false;
        });
      }
    }
  }

  void _reloadQuizList() {
    setState(() {
      _quizStream = _createQuizStream();
    });

    _loadOwnerStatus();
  }

  Future<void> _openQuizAddPage() async {
    bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return StudyQuizAddPage(
            studyId: widget.studyId,
            groupName: widget.groupName,
          );
        },
      ),
    );

    if (result == true) {
      _reloadQuizList();
    }
  }

  void _openQuiz(String quizId, Map<String, dynamic> quizData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return _QuizSolvePage(
            studyId: widget.studyId,
            quizId: quizId,
            quizData: quizData,
            isOwner: _isOwner,
          );
        },
      ),
    );
  }

  Future<void> _closeQuiz(String quizId) async {
    try {
      await FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('quizzes')
          .doc(quizId)
          .update({
            'status': 'CLOSED',
            'closedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('문제 제출을 마감했습니다.')));
    } catch (error) {
      debugPrint('문제 마감 오류: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('문제를 마감하지 못했습니다.')));
    }
  }

  Future<void> _deleteCollection(Query<Map<String, dynamic>> query) async {
    while (true) {
      QuerySnapshot<Map<String, dynamic>> snapshot = await query
          .limit(200)
          .get();

      if (snapshot.docs.isEmpty) {
        break;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (int i = 0; i < snapshot.docs.length; i++) {
        batch.delete(snapshot.docs[i].reference);
      }

      await batch.commit();

      if (snapshot.docs.length < 200) {
        break;
      }
    }
  }

  Future<void> _deleteQuiz(String quizId, String title) async {
    bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: appDialogShape,
          title: AppDialogTitle(
            icon: Icons.delete_outline,
            title: '문제 삭제',
            isDestructive: true,
          ),
          content: Text(
            '"$title" 문제를 삭제할까요?\n'
            '제출된 답안과 결과도 함께 삭제됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.incorrect,
                foregroundColor: context.colors.onPrimary,
              ),
              child: Text('삭제'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      DocumentReference<Map<String, dynamic>> quizDocument = FirebaseFirestore
          .instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('quizzes')
          .doc(quizId);

      await _deleteCollection(quizDocument.collection('answers'));

      await quizDocument.delete();

      QuerySnapshot<Map<String, dynamic>> messageSnapshot =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.studyId)
              .collection('messages')
              .where('quizId', isEqualTo: quizId)
              .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (int i = 0; i < messageSnapshot.docs.length; i++) {
        batch.update(messageSnapshot.docs[i].reference, {
          'message': '삭제된 문제입니다.',
          'messageType': 'DELETED',
          'isDeleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (messageSnapshot.docs.isNotEmpty) {
        await batch.commit();
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('문제를 삭제했습니다.')));
    } catch (error) {
      debugPrint('문제 삭제 오류: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('문제를 삭제하지 못했습니다.')));
    }
  }

  void _openQuizResult(String quizId, Map<String, dynamic> quizData) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0),
      builder: (bottomSheetContext) {
        return _QuizResultSheet(
          studyId: widget.studyId,
          quizId: quizId,
          quizData: quizData,
        );
      },
    );
  }

  Widget _buildBadge(String text, Color backgroundColor, Color textColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildQuizCard(
    QueryDocumentSnapshot<Map<String, dynamic>> quizDocument,
  ) {
    Map<String, dynamic> quizData = quizDocument.data();

    String title = quizData['title']?.toString() ?? '제목 없는 문제';

    String question = quizData['question']?.toString() ?? '';

    String subject = quizData['subject']?.toString() ?? '과목 미지정';

    String senderNickname = quizData['senderNickname']?.toString() ?? '방장';

    int point = _getInt(quizData, 'point');

    int timeLimitSeconds = _getInt(quizData, 'timeLimitSeconds');

    int answerCount = _getInt(quizData, 'answerCount');

    int correctCount = _getInt(quizData, 'correctAnswerCount');

    bool isClosed =
        quizData['status']?.toString() == 'CLOSED' ||
        _isDeadlinePassed(quizData);

    return Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _openQuiz(quizDocument.id, quizData);
        },
        child: AppCard(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildBadge(
                    subject,
                    context.colors.lavender,
                    context.colors.pinkStart,
                  ),
                  SizedBox(width: 7),
                  _buildBadge(
                    _getQuizTypeText(quizData),
                    context.colors.pinkSoft,
                    context.colors.pinkStart,
                  ),
                  SizedBox(width: 7),
                  _buildBadge(
                    isClosed ? '마감' : '진행 중',
                    isClosed
                        ? Theme.of(context).colorScheme.outlineVariant
                        : context.colors.mint,
                    isClosed
                        ? context.colors.textSecondary
                        : Theme.of(context).colorScheme.tertiary,
                  ),
                  Spacer(),
                  if (_isOwner)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'result') {
                          _openQuizResult(quizDocument.id, quizData);
                        }

                        if (value == 'close') {
                          _closeQuiz(quizDocument.id);
                        }

                        if (value == 'delete') {
                          _deleteQuiz(quizDocument.id, title);
                        }
                      },
                      itemBuilder: (context) {
                        return [
                          PopupMenuItem(value: 'result', child: Text('결과 보기')),
                          if (!isClosed)
                            PopupMenuItem(value: 'close', child: Text('제출 마감')),
                          PopupMenuItem(value: 'delete', child: Text('문제 삭제')),
                        ];
                      },
                    ),
                ],
              ),
              SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                question.isEmpty ? '문제를 눌러 내용을 확인하세요.' : question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: context.colors.textSecondary,
                ),
              ),
              SizedBox(height: 15),
              Wrap(
                spacing: 12,
                runSpacing: 7,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: context.colors.textSecondary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _formatLimitTime(timeLimitSeconds),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 16,
                        color: context.colors.textSecondary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '마감 '
                        '${_formatDateTime(quizData['deadlineAt'])}',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (point > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stars_outlined,
                          size: 16,
                          color: context.colors.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '$point점',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              SizedBox(height: 13),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 17,
                    color: context.colors.textSecondary,
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '$senderNickname 님이 발송',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                  if (_isOwner)
                    Text(
                      '참여 $answerCount · '
                      '정답 $correctCount',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.pinkStart,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Text(
                      isClosed ? '결과 확인' : '문제 풀기',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.pinkStart,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  SizedBox(width: 3),
                  Icon(Icons.chevron_right, color: context.colors.pinkStart),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> appBarActions = [];

    if (!_isOwnerLoading && _isOwner) {
      appBarActions.add(
        IconButton(
          tooltip: '문제 발송',
          onPressed: _openQuizAddPage,
          icon: Icon(
            Icons.add_rounded,
            color: context.colors.textPrimary,
            size: 29,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppTopBar(title: '발송된 문제', actions: appBarActions),
      body: AppMainBackground(
        applySafeArea: false,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _quizStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AppLoadingView(message: '발송된 문제를 불러오는 중입니다.');
            }

            if (snapshot.hasError) {
              if (_isNetworkError(snapshot.error)) {
                return AppNetworkErrorView(
                  message: '인터넷 연결을 확인해 주세요.',
                  description: '네트워크 연결 후 발송된 문제를 다시 불러와 주세요.',
                  onRetryPressed: _reloadQuizList,
                );
              }

              return AppErrorView(
                message: '발송된 문제를 불러오지 못했습니다.',
                description: '잠시 후 다시 시도해 주세요.',
                onRetryPressed: _reloadQuizList,
              );
            }

            List<QueryDocumentSnapshot<Map<String, dynamic>>> quizList =
                snapshot.data?.docs.toList() ?? [];

            quizList.sort((a, b) {
              dynamic aCreatedAt = a.data()['createdAt'];

              dynamic bCreatedAt = b.data()['createdAt'];

              int aTime = aCreatedAt is Timestamp
                  ? aCreatedAt.millisecondsSinceEpoch
                  : 0;

              int bTime = bCreatedAt is Timestamp
                  ? bCreatedAt.millisecondsSinceEpoch
                  : 0;

              return bTime.compareTo(aTime);
            });

            if (quizList.isEmpty) {
              return AppEmptyView(
                message: '발송된 문제가 없습니다.',
                description: _isOwner
                    ? '우측 상단의 + 버튼을 눌러 첫 문제를 발송해 보세요.'
                    : '새로운 문제가 발송되면 이곳에 표시됩니다.',
                buttonText: _isOwner ? '문제 발송하기' : null,
                onButtonPressed: _isOwner ? _openQuizAddPage : null,
              );
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 40),
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.colors.lavender,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.edit_note_rounded,
                          color: context.colors.pinkStart,
                          size: 29,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.groupName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '총 ${quizList.length}개의 문제가 발송되었습니다.',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 22),
                Text(
                  '문제 목록',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                SizedBox(height: 12),
                for (int i = 0; i < quizList.length; i++)
                  _buildQuizCard(quizList[i]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuizSolvePage extends StatefulWidget {
  final String studyId;
  final String quizId;
  final Map<String, dynamic> quizData;
  final bool isOwner;

  const _QuizSolvePage({
    required this.studyId,
    required this.quizId,
    required this.quizData,
    required this.isOwner,
  });

  @override
  State<_QuizSolvePage> createState() {
    return _QuizSolvePageState();
  }
}

class _QuizSolvePageState extends State<_QuizSolvePage> {
  Timer? _timer;

  int? _selectedAnswerIndex;
  int _remainingSeconds = 0;
  int _timeLimitSeconds = 0;

  bool _isSubmitted = false;
  bool _isCorrect = false;
  bool _isLoadingAnswer = true;
  bool _isSaving = false;
  bool _isTimedOut = false;

  DateTime? _attemptStartedAt;

  @override
  void initState() {
    super.initState();

    _prepareAnswer();
  }

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  List<String> _getChoices() {
    dynamic choices = widget.quizData['choices'];

    if (choices is List) {
      return choices.map((choice) => choice.toString()).toList();
    }

    return [];
  }

  int _getCorrectAnswerIndex() {
    dynamic value = widget.quizData['correctAnswerIndex'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return -1;
  }

  int _getInt(Map<String, dynamic> data, String fieldName) {
    dynamic value = data[fieldName];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  DateTime? _getDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return null;
  }

  bool _isDeadlinePassed() {
    DateTime? deadlineAt = _getDateTime(widget.quizData['deadlineAt']);

    if (deadlineAt == null) {
      return false;
    }

    return DateTime.now().isAfter(deadlineAt);
  }

  bool _isQuizClosed() {
    String status = widget.quizData['status']?.toString() ?? 'ACTIVE';

    return status == 'CLOSED' || _isDeadlinePassed();
  }

  bool _canRevealAnswer() {
    if (widget.isOwner) {
      return true;
    }

    String revealType =
        widget.quizData['answerRevealType']?.toString() ?? 'AFTER_SUBMIT';

    if (revealType == 'AFTER_DEADLINE') {
      return _isDeadlinePassed();
    }

    return _isSubmitted;
  }

  String _formatTimer(int seconds) {
    if (seconds < 0) {
      seconds = 0;
    }

    int minutes = seconds ~/ 60;
    int remainSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainSeconds.toString().padLeft(2, '0')}';
  }

  Future<Map<String, String>> _getCurrentUserProfile(User currentUser) async {
    String nickname = '';
    String profileImageUrl = '';

    DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
        await FirebaseFirestore.instance
            .collection('studyGroups')
            .doc(widget.studyId)
            .collection('members')
            .doc(currentUser.uid)
            .get();

    if (memberSnapshot.exists) {
      nickname = memberSnapshot.data()?['nickname']?.toString().trim() ?? '';

      profileImageUrl =
          memberSnapshot.data()?['profileImageUrl']?.toString().trim() ?? '';
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
        profileImageUrl = userData['profileImageUrl']?.toString().trim() ?? '';

        if (profileImageUrl.isEmpty) {
          profileImageUrl = userData['photoUrl']?.toString().trim() ?? '';
        }
      }
    }

    if (nickname.isEmpty) {
      nickname = currentUser.displayName?.trim() ?? '';
    }

    if (profileImageUrl.isEmpty) {
      profileImageUrl = currentUser.photoURL?.trim() ?? '';
    }

    if (nickname.isEmpty) {
      nickname = '사용자';
    }

    return {'nickname': nickname, 'profileImageUrl': profileImageUrl};
  }

  Future<void> _prepareAnswer() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoadingAnswer = false;
        });
      }

      return;
    }

    try {
      DocumentReference<Map<String, dynamic>> answerDocument = FirebaseFirestore
          .instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('answers')
          .doc(currentUser.uid);

      DocumentSnapshot<Map<String, dynamic>> answerSnapshot =
          await answerDocument.get();

      Map<String, dynamic> answerData = answerSnapshot.data() ?? {};

      String answerStatus = answerData['status']?.toString() ?? '';

      dynamic selectedAnswerIndex = answerData['selectedAnswerIndex'];

      if (selectedAnswerIndex is int) {
        _selectedAnswerIndex = selectedAnswerIndex;
      } else if (selectedAnswerIndex is num) {
        _selectedAnswerIndex = selectedAnswerIndex.toInt();
      }

      if (answerStatus == 'SUBMITTED' || answerData['submittedAt'] != null) {
        if (mounted) {
          setState(() {
            _isSubmitted = true;
            _isCorrect = answerData['isCorrect'] == true;

            _isTimedOut = answerData['isTimedOut'] == true;

            _isLoadingAnswer = false;
          });
        }

        return;
      }

      if (_isQuizClosed()) {
        if (mounted) {
          setState(() {
            _remainingSeconds = 0;
            _isLoadingAnswer = false;
          });
        }

        return;
      }

      _timeLimitSeconds = _getInt(widget.quizData, 'timeLimitSeconds');

      if (_timeLimitSeconds <= 0) {
        _timeLimitSeconds = 60;
      }

      DateTime startedAt = DateTime.now();

      DateTime? savedStartedAt = _getDateTime(answerData['attemptStartedAt']);

      if (savedStartedAt != null) {
        startedAt = savedStartedAt;
      } else {
        await answerDocument.set({
          'userUid': currentUser.uid,
          'status': 'STARTED',
          'attemptStartedAt': Timestamp.fromDate(startedAt),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _attemptStartedAt = startedAt;

      int elapsedSeconds = DateTime.now().difference(startedAt).inSeconds;

      int remainingSeconds = _timeLimitSeconds - elapsedSeconds;

      if (_isQuizClosed()) {
        remainingSeconds = 0;
      }

      if (remainingSeconds < 0) {
        remainingSeconds = 0;
      }

      if (mounted) {
        setState(() {
          _remainingSeconds = remainingSeconds;

          _isLoadingAnswer = false;
        });
      }

      if (remainingSeconds == 0) {
        await _submitAnswer(timedOut: true);

        return;
      }

      _startTimer();
    } catch (error) {
      debugPrint('문제 답안 준비 오류: $error');

      if (mounted) {
        setState(() {
          _isLoadingAnswer = false;
        });
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted || _isSubmitted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        setState(() {
          _remainingSeconds = 0;
        });

        timer.cancel();

        _submitAnswer(timedOut: true);

        return;
      }

      setState(() {
        _remainingSeconds--;
      });
    });
  }

  Future<void> _saveWrongAnswer({
    required User currentUser,
    required bool isCorrect,
    required int selectedIndex,
  }) async {
    DocumentReference<Map<String, dynamic>> wrongAnswerDocument =
        FirebaseFirestore.instance
            .collection('studyGroups')
            .doc(widget.studyId)
            .collection('members')
            .doc(currentUser.uid)
            .collection('wrongAnswers')
            .doc(widget.quizId);

    if (isCorrect) {
      DocumentSnapshot<Map<String, dynamic>> wrongSnapshot =
          await wrongAnswerDocument.get();

      if (wrongSnapshot.exists) {
        await wrongAnswerDocument.delete();
      }

      return;
    }

    await wrongAnswerDocument.set({
      'quizId': widget.quizId,
      'studyId': widget.studyId,
      'title': widget.quizData['title']?.toString() ?? '',
      'subject': widget.quizData['subject']?.toString() ?? '',
      'question': widget.quizData['question']?.toString() ?? '',
      'choices': _getChoices(),
      'selectedAnswerIndex': selectedIndex,
      'correctAnswerIndex': _getCorrectAnswerIndex(),
      'explanation': widget.quizData['explanation']?.toString() ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _submitAnswer({bool timedOut = false}) async {
    if (_isSaving || _isSubmitted) {
      return;
    }

    if (!timedOut && _selectedAnswerIndex == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('정답을 먼저 선택해 주세요.')));

      return;
    }

    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그인 정보가 없습니다.')));

      return;
    }

    setState(() {
      _isSaving = true;
    });

    _timer?.cancel();

    int selectedIndex = _selectedAnswerIndex ?? -1;

    int correctAnswerIndex = _getCorrectAnswerIndex();

    bool isCorrect = selectedIndex == correctAnswerIndex;

    try {
      Map<String, String> profile = await _getCurrentUserProfile(currentUser);

      DocumentReference<Map<String, dynamic>> quizDocument = FirebaseFirestore
          .instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('quizzes')
          .doc(widget.quizId);

      DocumentReference<Map<String, dynamic>> answerDocument = quizDocument
          .collection('answers')
          .doc(currentUser.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot<Map<String, dynamic>> quizSnapshot = await transaction
            .get(quizDocument);

        DocumentSnapshot<Map<String, dynamic>> answerSnapshot =
            await transaction.get(answerDocument);

        if (!quizSnapshot.exists) {
          throw Exception('문제를 찾을 수 없습니다.');
        }

        Map<String, dynamic> answerData = answerSnapshot.data() ?? {};

        if (answerData['status']?.toString() == 'SUBMITTED') {
          throw Exception('이미 제출한 문제입니다.');
        }

        int answerCount = _getInt(quizSnapshot.data() ?? {}, 'answerCount');

        int correctCount = _getInt(
          quizSnapshot.data() ?? {},
          'correctAnswerCount',
        );

        int wrongCount = _getInt(quizSnapshot.data() ?? {}, 'wrongAnswerCount');

        int elapsedSeconds = _timeLimitSeconds - _remainingSeconds;

        if (elapsedSeconds < 0) {
          elapsedSeconds = 0;
        }

        transaction.set(answerDocument, {
          'userUid': currentUser.uid,
          'userNickname': profile['nickname'],
          'userProfileImageUrl': profile['profileImageUrl'],
          'selectedAnswerIndex': selectedIndex,
          'isCorrect': isCorrect,
          'isTimedOut': timedOut,
          'elapsedSeconds': elapsedSeconds,
          'status': 'SUBMITTED',
          'attemptStartedAt': Timestamp.fromDate(
            _attemptStartedAt ?? DateTime.now(),
          ),
          'submittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.update(quizDocument, {
          'answerCount': answerCount + 1,
          'correctAnswerCount': isCorrect ? correctCount + 1 : correctCount,
          'wrongAnswerCount': isCorrect ? wrongCount : wrongCount + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      await _saveWrongAnswer(
        currentUser: currentUser,
        isCorrect: isCorrect,
        selectedIndex: selectedIndex,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitted = true;
        _isCorrect = isCorrect;
        _isTimedOut = timedOut;
        _isSaving = false;
      });
    } catch (error) {
      debugPrint('문제 답안 저장 오류: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().contains('이미 제출')
                ? '이미 제출한 문제입니다.'
                : '답안을 저장하지 못했습니다.',
          ),
        ),
      );
    }
  }

  Widget _buildChoice(int index, String choice) {
    bool isSelected = _selectedAnswerIndex == index;

    bool revealAnswer = _canRevealAnswer();

    int correctAnswerIndex = _getCorrectAnswerIndex();

    Color backgroundColor = Theme.of(context).colorScheme.surface;

    Color borderColor = Theme.of(context).colorScheme.outlineVariant;

    Color numberColor = context.colors.textSecondary;

    if (!_isSubmitted && isSelected) {
      backgroundColor = context.colors.lavender;

      borderColor = context.colors.pinkStart;

      numberColor = context.colors.pinkStart;
    }

    if (revealAnswer && index == correctAnswerIndex) {
      backgroundColor = context.colors.mint;

      borderColor = Theme.of(context).colorScheme.tertiary;

      numberColor = Theme.of(context).colorScheme.tertiary;
    }

    if (_isSubmitted &&
        revealAnswer &&
        isSelected &&
        index != correctAnswerIndex) {
      backgroundColor = context.colors.pinkSoft;

      borderColor = Theme.of(context).colorScheme.error;

      numberColor = Theme.of(context).colorScheme.error;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isSubmitted || _remainingSeconds <= 0
          ? null
          : () {
              setState(() {
                _selectedAnswerIndex = index;
              });
            },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.3),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: numberColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                widget.quizData['quizType']?.toString() == 'OX'
                    ? choice
                    : '${index + 1}',
                style: TextStyle(
                  color: numberColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 13),
            Expanded(
              child: Text(
                choice,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                revealAnswer && index != correctAnswerIndex
                    ? Icons.close_rounded
                    : Icons.check_rounded,
                color: revealAnswer && index != correctAnswerIndex
                    ? Theme.of(context).colorScheme.error
                    : context.colors.pinkStart,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    String revealType =
        widget.quizData['answerRevealType']?.toString() ?? 'AFTER_SUBMIT';

    bool revealAnswer = _canRevealAnswer();

    if (!_isSubmitted) {
      return SizedBox();
    }

    if (!revealAnswer) {
      return AppCard(
        backgroundColor: context.colors.lavender,
        child: Row(
          children: [
            Icon(Icons.lock_clock_outlined, color: context.colors.pinkStart),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                revealType == 'AFTER_DEADLINE'
                    ? '정답과 해설은 제출 마감 후 공개됩니다.'
                    : '정답 공개를 기다리고 있습니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    String explanation = widget.quizData['explanation']?.toString() ?? '';

    return AppCard(
      backgroundColor: _isCorrect
          ? context.colors.mint
          : context.colors.pinkSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: _isCorrect
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.error,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  _isTimedOut
                      ? '시간이 종료되어 자동 제출되었습니다.'
                      : _isCorrect
                      ? '정답입니다.'
                      : '오답입니다. 오답노트에 저장했어요.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (explanation.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              explanation,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.quizData['title']?.toString() ?? '발송된 문제';

    String subject = widget.quizData['subject']?.toString() ?? '과목 미지정';

    String question =
        widget.quizData['question']?.toString() ?? '등록된 문제 내용이 없습니다.';

    List<String> choices = _getChoices();

    if (_isLoadingAnswer) {
      return Scaffold(
        appBar: AppTopBar(title: '문제 풀기'),
        body: AppLoadingView(message: '문제 응답 상태를 확인하는 중입니다.'),
      );
    }

    return Scaffold(
      appBar: AppTopBar(title: '문제 풀기'),
      body: Stack(
        children: [
          AppMainBackground(
            applySafeArea: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.lavender,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          subject,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.pinkStart,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Spacer(),
                      if (!_isSubmitted)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _remainingSeconds <= 10
                                ? context.colors.pinkSoft
                                : context.colors.lavender,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 17,
                                color: _remainingSeconds <= 10
                                    ? Theme.of(context).colorScheme.error
                                    : context.colors.pinkStart,
                              ),
                              SizedBox(width: 5),
                              Text(
                                _formatTimer(_remainingSeconds),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _remainingSeconds <= 10
                                      ? Theme.of(context).colorScheme.error
                                      : context.colors.pinkStart,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 16),
                  AppCard(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    child: Text(
                      question,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  for (int i = 0; i < choices.length; i++)
                    _buildChoice(i, choices[i]),
                  SizedBox(height: 6),
                  _buildResultCard(),
                  SizedBox(height: 16),
                  if (!_isSubmitted)
                    AppButton(
                      text: _remainingSeconds <= 0
                          ? '제출 시간이 종료되었습니다.'
                          : '답안 제출하기',
                      type: AppButtonType.primaryPink,
                      height: 52,
                      onPressed: _remainingSeconds <= 0
                          ? null
                          : () {
                              _submitAnswer();
                            },
                    ),
                  if (widget.isOwner) ...[
                    SizedBox(height: 11),
                    AppButton(
                      text: '전체 결과 보기',
                      type: AppButtonType.outlinePink,
                      height: 48,
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface.withOpacity(0),
                          builder: (bottomSheetContext) {
                            return _QuizResultSheet(
                              studyId: widget.studyId,
                              quizId: widget.quizId,
                              quizData: widget.quizData,
                            );
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isSaving) Positioned.fill(child: LoadingOverlay()),
        ],
      ),
    );
  }
}

class _QuizResultSheet extends StatelessWidget {
  final String studyId;
  final String quizId;
  final Map<String, dynamic> quizData;

  const _QuizResultSheet({
    required this.studyId,
    required this.quizId,
    required this.quizData,
  });

  List<String> _getChoices() {
    dynamic choices = quizData['choices'];

    if (choices is List) {
      return choices.map((choice) => choice.toString()).toList();
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          SizedBox(height: 11),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 12, 14),
            child: Row(
              children: [
                Icon(Icons.analytics_outlined, color: context.colors.pinkStart),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '문제 결과',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('studyGroups')
                  .doc(studyId)
                  .collection('members')
                  .snapshots(),
              builder: (context, memberSnapshot) {
                if (memberSnapshot.connectionState == ConnectionState.waiting) {
                  return AppLoadingView(message: '그룹원 정보를 불러오는 중입니다.');
                }

                if (memberSnapshot.hasError) {
                  return AppErrorView(
                    message: '그룹원 정보를 불러오지 못했습니다.',
                    description: '잠시 후 다시 시도해 주세요.',
                  );
                }

                int activeMemberCount = 0;

                if (memberSnapshot.data != null) {
                  for (int i = 0; i < memberSnapshot.data!.docs.length; i++) {
                    Map<String, dynamic> memberData = memberSnapshot
                        .data!
                        .docs[i]
                        .data();

                    String status = memberData['status']?.toString() ?? '';

                    String role = memberData['role']?.toString() ?? 'MEMBER';

                    if (status == 'ACTIVE' || role == 'OWNER') {
                      activeMemberCount++;
                    }
                  }
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studyGroups')
                      .doc(studyId)
                      .collection('quizzes')
                      .doc(quizId)
                      .collection('answers')
                      .snapshots(),
                  builder: (context, answerSnapshot) {
                    if (answerSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return AppLoadingView(message: '문제 결과를 불러오는 중입니다.');
                    }

                    if (answerSnapshot.hasError) {
                      return AppErrorView(
                        message: '문제 결과를 불러오지 못했습니다.',
                        description: '잠시 후 다시 시도해 주세요.',
                      );
                    }

                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    answerList =
                        answerSnapshot.data?.docs.where((document) {
                          return document.data()['status']?.toString() ==
                              'SUBMITTED';
                        }).toList() ??
                        [];

                    int correctCount = 0;
                    int timedOutCount = 0;

                    List<String> choices = _getChoices();

                    List<int> choiceCountList = List<int>.filled(
                      choices.length,
                      0,
                    );

                    for (int i = 0; i < answerList.length; i++) {
                      Map<String, dynamic> answerData = answerList[i].data();

                      if (answerData['isCorrect'] == true) {
                        correctCount++;
                      }

                      if (answerData['isTimedOut'] == true) {
                        timedOutCount++;
                      }

                      dynamic selectedIndex = answerData['selectedAnswerIndex'];

                      int answerIndex = -1;

                      if (selectedIndex is int) {
                        answerIndex = selectedIndex;
                      } else if (selectedIndex is num) {
                        answerIndex = selectedIndex.toInt();
                      }

                      if (answerIndex >= 0 &&
                          answerIndex < choiceCountList.length) {
                        choiceCountList[answerIndex]++;
                      }
                    }

                    int answerCount = answerList.length;

                    int wrongCount = answerCount - correctCount;

                    int noAnswerCount = activeMemberCount - answerCount;

                    if (noAnswerCount < 0) {
                      noAnswerCount = 0;
                    }

                    int correctRate = 0;

                    if (answerCount > 0) {
                      correctRate = ((correctCount / answerCount) * 100)
                          .round();
                    }

                    return ListView(
                      padding: EdgeInsets.fromLTRB(18, 16, 18, 30),
                      children: [
                        Text(
                          quizData['title']?.toString() ?? '발송 문제',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 14),
                        Row(
                          children: [
                            _buildResultMetric(
                              context,
                              '참여',
                              '$answerCount / '
                                  '$activeMemberCount명',
                            ),
                            SizedBox(width: 8),
                            _buildResultMetric(context, '정답', '$correctCount명'),
                            SizedBox(width: 8),
                            _buildResultMetric(context, '오답', '$wrongCount명'),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            _buildResultMetric(
                              context,
                              '미참여',
                              '$noAnswerCount명',
                            ),
                            SizedBox(width: 8),
                            _buildResultMetric(
                              context,
                              '시간 초과',
                              '$timedOutCount명',
                            ),
                            SizedBox(width: 8),
                            _buildResultMetric(context, '정답률', '$correctRate%'),
                          ],
                        ),
                        SizedBox(height: 24),
                        Text(
                          '보기별 선택 현황',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 11),
                        for (int i = 0; i < choices.length; i++)
                          Container(
                            margin: EdgeInsets.only(bottom: 9),
                            padding: EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: context.colors.lavender,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    quizData['quizType']?.toString() == 'OX'
                                        ? choices[i]
                                        : '${i + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.pinkStart,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 11),
                                Expanded(
                                  child: Text(
                                    choices[i],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${choiceCountList[i]}명',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: context.colors.pinkStart,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(height: 16),
                        Text(
                          '제출자',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 11),
                        if (answerList.isEmpty)
                          SizedBox(
                            height: 210,
                            child: AppEmptyView(
                              message: '제출된 답안이 없습니다.',
                              description: '그룹원이 문제를 풀면 결과가 표시됩니다.',
                            ),
                          )
                        else
                          for (int i = 0; i < answerList.length; i++)
                            _buildAnswerItem(context, answerList[i].data()),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildResultMetric(
    BuildContext context,
    String label,
    String value,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        decoration: BoxDecoration(
          color: context.colors.lavender,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.colors.pinkStart,
              ),
            ),
            SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildAnswerItem(
    BuildContext context,
    Map<String, dynamic> answerData,
  ) {
    String nickname = answerData['userNickname']?.toString() ?? '사용자';

    bool isCorrect = answerData['isCorrect'] == true;

    bool isTimedOut = answerData['isTimedOut'] == true;

    int elapsedSeconds = 0;

    dynamic elapsedValue = answerData['elapsedSeconds'];

    if (elapsedValue is int) {
      elapsedSeconds = elapsedValue;
    } else if (elapsedValue is num) {
      elapsedSeconds = elapsedValue.toInt();
    }

    return Container(
      margin: EdgeInsets.only(bottom: 9),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isCorrect
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.error,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              nickname,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          Text(
            isTimedOut ? '시간 초과' : '$elapsedSeconds초',
            style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
