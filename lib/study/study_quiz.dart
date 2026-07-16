import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutterteam03/widgets/app_state_views.dart';

import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/loading_overlay.dart';
import 'study_quiz_add.dart';


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

  /// 현재 로그인한 사용자가 방장인지 확인
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
        Map<String, dynamic> groupData =
            groupSnapshot.data() ?? {};

        String ownerUid =
            groupData['ownerUid']?.toString() ?? '';

        if (ownerUid == currentUser.uid) {
          isOwner = true;
        }
      }

      if (isOwner == false) {
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
            isOwner = true;
          }
        }
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

  /// Firestore 숫자 필드 가져오기
  int _getInt(
      Map<String, dynamic> data,
      String fieldName,
      ) {
    final value = data[fieldName];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
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

  /// 문제 목록 다시 불러오기
  void _reloadQuizList() {
    setState(() {
      _quizStream = _createQuizStream();
    });

    _loadOwnerStatus();
  }

  /// Firestore 날짜 표시
  String _formatDate(dynamic createdAt) {
    if (createdAt is! Timestamp) {
      return '';
    }

    final dateTime = createdAt.toDate().toLocal();

    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.'
        '${dateTime.day.toString().padLeft(2, '0')}';
  }

  /// 문제 작성 화면으로 이동
  Future<void> _openQuizAddPage() async {
    await Navigator.push<bool>(
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
  }

  /// 문제 풀이 화면으로 이동
  void _openQuiz(
      BuildContext context,
      String quizId,
      Map<String, dynamic> quizData,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QuizSolvePage(
          studyId: widget.studyId,
          quizId: quizId,
          quizData: quizData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> appBarActions = [];

    if (_isOwnerLoading == false && _isOwner) {
      appBarActions.add(
        IconButton(
          tooltip: '문제 발송',
          onPressed: _openQuizAddPage,
          icon: Icon(
            Icons.add_rounded,
            color: _studyColors.textPrimary,
            size: 29,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppTopBar(
        title: '발송된 문제',
        actions: appBarActions,
      ),
      body: AppMainBackground(
        applySafeArea: false,
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: _quizStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return AppLoadingView(
                message: '발송된 문제를 불러오는 중입니다.',
              );
            }

            if (snapshot.hasError) {
              debugPrint(
                '발송된 문제 조회 오류: ${snapshot.error}',
              );

              if (_isNetworkError(snapshot.error)) {
                return AppNetworkErrorView(
                  message: '인터넷 연결을 확인해 주세요.',
                  description:
                  '네트워크 연결 후 발송된 문제를 다시 불러와 주세요.',
                  retryButtonText: '다시 시도',
                  onRetryPressed: _reloadQuizList,
                );
              }

              return AppErrorView(
                message: '발송된 문제를 불러오지 못했습니다.',
                description: '잠시 후 다시 시도해 주세요.',
                retryButtonText: '다시 시도',
                onRetryPressed: _reloadQuizList,
              );
            }

            final quizList =
                snapshot.data?.docs.toList() ?? [];

            // 최근 발송된 문제가 위로 표시되도록 정렬
            quizList.sort((a, b) {
              final aCreatedAt =
              a.data()['createdAt'];

              final bCreatedAt =
              b.data()['createdAt'];

              final aTime =
              aCreatedAt is Timestamp
                  ? aCreatedAt.millisecondsSinceEpoch
                  : 0;

              final bTime =
              bCreatedAt is Timestamp
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
                buttonText: _isOwner
                    ? '문제 발송하기'
                    : null,
                onButtonPressed: _isOwner
                    ? _openQuizAddPage
                    : null,
              );
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                22,
                20,
                40,
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _studyColors.lavender,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _studyColors.lavender,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _studyColorScheme.surface,
                          borderRadius:
                          BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.edit_note_rounded,
                          color: _studyColors.pinkStart,
                          size: 29,
                        ),
                      ),

                      SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.groupName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 4),

                            Text(
                              '총 ${quizList.length}개의 문제가 발송되었습니다.',
                              style: TextStyle(
                                fontSize: 12,
                                color: _studyColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_isOwner)
                        IconButton(
                          tooltip: '문제 발송',
                          onPressed: _openQuizAddPage,
                          icon: Icon(
                            Icons.add_circle_rounded,
                            color: _studyColors.pinkStart,
                            size: 28,
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
                  ),
                ),

                SizedBox(height: 12),

                ...quizList.map((quizDocument) {
                  final quizData =
                  quizDocument.data();

                  final title =
                      quizData['title']?.toString() ??
                          '제목 없는 문제';

                  final question =
                      quizData['question']?.toString() ??
                          '';

                  final senderNickname =
                      quizData['senderNickname']
                          ?.toString() ??
                          '스터디원';

                  final createdAt =
                  quizData['createdAt'];

                  final point =
                  _getInt(quizData, 'point');

                  return Padding(
                    padding:
                    EdgeInsets.only(bottom: 14),
                    child: GestureDetector(
                      onTap: () {
                        _openQuiz(
                          context,
                          quizDocument.id,
                          quizData,
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AppCard(
                        backgroundColor: _studyColorScheme.surface,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding:
                                  EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                    _studyColors.lavender,
                                    borderRadius:
                                    BorderRadius.circular(
                                      14,
                                    ),
                                  ),
                                  child: Text(
                                    '발송 문제',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                      _studyColors.pinkStart,
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),
                                ),

                                if (point > 0) ...[
                                  SizedBox(width: 7),
                                  Container(
                                    padding: EdgeInsets
                                        .symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _studyColors.pinkSoft,
                                      borderRadius:
                                      BorderRadius.circular(
                                        14,
                                      ),
                                    ),
                                    child: Text(
                                      '$point점',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                        _studyColors.pinkStart,
                                        fontWeight:
                                        FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],

                                Spacer(),

                                Text(
                                  _formatDate(createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                    _studyColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 15),

                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 8),

                            Text(
                              question.isEmpty
                                  ? '문제를 눌러 내용을 확인하세요.'
                                  : question,
                              maxLines: 2,
                              overflow:
                              TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: _studyColors.textSecondary,
                              ),
                            ),

                            SizedBox(height: 16),

                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 17,
                                  color: _studyColors.textSecondary,
                                ),

                                SizedBox(width: 5),

                                Expanded(
                                  child: Text(
                                    '$senderNickname 님이 발송',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                      _studyColors.textSecondary,
                                    ),
                                  ),
                                ),

                                Text(
                                  '문제 풀기',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                    _studyColors.pinkStart,
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),

                                SizedBox(width: 3),

                                Icon(
                                  Icons.chevron_right,
                                  color: _studyColors.pinkStart,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 문제 풀이 화면
class _QuizSolvePage extends StatefulWidget {
  final String studyId;
  final String quizId;
  final Map<String, dynamic> quizData;

  const _QuizSolvePage({
    required this.studyId,
    required this.quizId,
    required this.quizData,
  });

  @override
  State<_QuizSolvePage> createState() =>
      _QuizSolvePageState();
}

class _QuizSolvePageState
    extends State<_QuizSolvePage> {
  int? _selectedAnswerIndex;

  bool _isSubmitted = false;
  bool _isCorrect = false;
  bool _isLoadingAnswer = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _loadMyAnswer();
  }

  /// 보기 목록 가져오기
  List<String> _getChoices() {
    final choices = widget.quizData['choices'];

    if (choices is List) {
      return choices
          .map((choice) => choice.toString())
          .toList();
    }

    return [];
  }

  /// 정답 번호 가져오기
  int _getCorrectAnswerIndex() {
    final value =
    widget.quizData['correctAnswerIndex'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return -1;
  }

  /// 기존에 제출한 답안이 있는지 확인
  Future<void> _loadMyAnswer() async {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoadingAnswer = false;
        });
      }

      return;
    }

    try {
      final answerSnapshot =
      await FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('answers')
          .doc(currentUser.uid)
          .get();

      if (answerSnapshot.exists) {
        final answerData =
            answerSnapshot.data() ?? {};

        final selectedAnswerIndex =
        answerData['selectedAnswerIndex'];

        if (mounted) {
          setState(() {
            if (selectedAnswerIndex is int) {
              _selectedAnswerIndex =
                  selectedAnswerIndex;
            } else if (selectedAnswerIndex is num) {
              _selectedAnswerIndex =
                  selectedAnswerIndex.toInt();
            }

            _isSubmitted = true;
            _isCorrect =
                answerData['isCorrect'] == true;
          });
        }
      }
    } catch (error) {
      debugPrint(
        '기존 문제 답안 조회 오류: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAnswer = false;
        });
      }
    }
  }

  /// 답안 제출
  Future<void> _submitAnswer() async {
    if (_selectedAnswerIndex == null ||
        _isSaving ||
        _isSubmitted) {
      if (_selectedAnswerIndex == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('정답을 먼저 선택해주세요.'),
          ),
        );
      }

      return;
    }

    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그인 정보가 없습니다.'),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final correctAnswerIndex =
      _getCorrectAnswerIndex();

      final isCorrect =
          _selectedAnswerIndex ==
              correctAnswerIndex;

      await FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('answers')
          .doc(currentUser.uid)
          .set({
        'userUid': currentUser.uid,
        'userNickname':
        currentUser.displayName ?? '사용자',
        'selectedAnswerIndex':
        _selectedAnswerIndex,
        'isCorrect': isCorrect,
        'submittedAt':
        FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitted = true;
        _isCorrect = isCorrect;
      });
    } catch (error) {
      debugPrint('문제 답안 저장 오류: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('답안을 저장하지 못했습니다.'),
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

  /// 보기 항목
  Widget _buildChoice(
      int index,
      String choice,
      ) {
    final isSelected =
        _selectedAnswerIndex == index;

    final correctAnswerIndex =
    _getCorrectAnswerIndex();

    Color backgroundColor = _studyColorScheme.surface;
    Color borderColor =
        _studyColorScheme.outlineVariant;
    Color numberColor =
        _studyColors.textSecondary;

    if (!_isSubmitted && isSelected) {
      backgroundColor =
          _studyColors.lavender;
      borderColor =
          _studyColors.pinkStart;
      numberColor =
          _studyColors.pinkStart;
    }

    if (_isSubmitted &&
        index == correctAnswerIndex) {
      backgroundColor =
          _studyColors.mint;
      borderColor =
          _studyColorScheme.tertiary;
      numberColor =
          _studyColorScheme.tertiary;
    }

    if (_isSubmitted &&
        isSelected &&
        index != correctAnswerIndex) {
      backgroundColor =
          _studyColors.pinkSoft;
      borderColor =
          _studyColors.pinkStart;
      numberColor =
          _studyColorScheme.error;
    }

    return GestureDetector(
      onTap: _isSubmitted
          ? null
          : () {
        setState(() {
          _selectedAnswerIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Duration(
          milliseconds: 180,
        ),
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: 1.3,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: numberColor.withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
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
                ),
              ),
            ),

            if (isSelected)
              Icon(
                _isSubmitted && !_isCorrect
                    ? Icons.close_rounded
                    : Icons.check_rounded,
                color: _isSubmitted && !_isCorrect
                    ? _studyColorScheme.error
                    : _studyColors.pinkStart,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.quizData['title']?.toString() ??
            '발송된 문제';

    final question =
        widget.quizData['question']?.toString() ??
            '등록된 문제 내용이 없습니다.';

    final explanation =
        widget.quizData['explanation']
            ?.toString() ??
            '';

    final choices = _getChoices();

    return Scaffold(
      appBar: AppTopBar(
        title: '문제 풀기',
      ),
      body: Stack(
        children: [
          AppMainBackground(
            applySafeArea: false,
            child: _isLoadingAnswer
                ? AppLoadingView(
              message: '문제 정보를 불러오는 중입니다.',
            )
                : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                22,
                20,
                40,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                    EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                      _studyColors.lavender,
                      borderRadius:
                      BorderRadius.circular(15),
                    ),
                    child: Text(
                      '객관식 문제',
                      style: TextStyle(
                        fontSize: 12,
                        color: _studyColors.pinkStart,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 20),

                  AppCard(
                    backgroundColor: _studyColorScheme.surface,
                    child: Text(
                      question,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.55,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),

                  SizedBox(height: 22),

                  Text(
                    '정답 선택',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 12),

                  if (choices.isEmpty)
                    AppCard(
                      backgroundColor: _studyColorScheme.surface,
                      child: Text(
                        '등록된 보기가 없습니다.',
                        style: TextStyle(
                          color: _studyColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    ...List.generate(
                      choices.length,
                          (index) => _buildChoice(
                        index,
                        choices[index],
                      ),
                    ),

                  if (_isSubmitted) ...[
                    SizedBox(height: 10),

                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: _isCorrect
                            ? _studyColors.mint
                            : _studyColors.pinkSoft,
                        borderRadius:
                        BorderRadius.circular(17),
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isCorrect
                                    ? Icons
                                    .check_circle_outline
                                    : Icons
                                    .cancel_outlined,
                                color: _isCorrect
                                    ? _studyColorScheme.tertiary
                                    : _studyColorScheme.error,
                              ),

                              SizedBox(width: 8),

                              Text(
                                _isCorrect
                                    ? '정답입니다!'
                                    : '오답입니다.',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                  FontWeight.bold,
                                  color: _isCorrect
                                      ? _studyColorScheme.tertiary
                                      : _studyColorScheme.error,
                                ),
                              ),
                            ],
                          ),

                          if (explanation.isNotEmpty) ...[
                            SizedBox(height: 12),

                            Text(
                              explanation,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color:
                                _studyColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 24),

                  AppButton(
                    text: _isSubmitted ? '제출 완료' : '정답 제출',
                    type: AppButtonType.primaryPink,
                    height: 50,
                    onPressed:
                    choices.isEmpty ||
                        _isSubmitted ||
                        _isSaving
                        ? null
                        : _submitAnswer,
                  ),
                ],
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