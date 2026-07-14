import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';

class StudyQuizPage extends StatelessWidget {
  final String studyId;
  final String groupName;

  const StudyQuizPage({
    super.key,
    required this.studyId,
    required this.groupName,
  });

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

  /// Firestore 날짜 표시
  String _formatDate(dynamic createdAt) {
    if (createdAt is! Timestamp) {
      return '';
    }

    final dateTime = createdAt.toDate().toLocal();

    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.'
        '${dateTime.day.toString().padLeft(2, '0')}';
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
          studyId: studyId,
          quizId: quizId,
          quizData: quizData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('발송된 문제'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: AppMainBackground(
        applySafeArea: false,
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('studyGroups')
              .doc(studyId)
              .collection('quizzes')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              debugPrint(
                '발송된 문제 조회 오류: ${snapshot.error}',
              );

              return const Center(
                child: Text(
                  '발송된 문제를 불러오지 못했습니다.',
                ),
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
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0ECFF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.quiz_outlined,
                          size: 41,
                          color: Color(0xFF8068D8),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        '발송된 문제가 없습니다.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        '스터디에 문제가 발송되면\n이곳에서 확인하고 풀 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          height: 1.5,
                          color: Color(0xFF858994),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                22,
                20,
                40,
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F0FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE8E1FF),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                          BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.edit_note_rounded,
                          color: Color(0xFF8068D8),
                          size: 29,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              groupName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              '총 ${quizList.length}개의 문제가 발송되었습니다.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF777383),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  '문제 목록',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

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
                    const EdgeInsets.only(bottom: 14),
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
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                    const Color(0xFFE9E4FF),
                                    borderRadius:
                                    BorderRadius.circular(
                                      14,
                                    ),
                                  ),
                                  child: const Text(
                                    '발송 문제',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                      Color(0xFF6F58C9),
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),
                                ),

                                if (point > 0) ...[
                                  const SizedBox(width: 7),
                                  Container(
                                    padding: const EdgeInsets
                                        .symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFFFEDF2,
                                      ),
                                      borderRadius:
                                      BorderRadius.circular(
                                        14,
                                      ),
                                    ),
                                    child: Text(
                                      '$point점',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color:
                                        Color(0xFFD85F82),
                                        fontWeight:
                                        FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],

                                const Spacer(),

                                Text(
                                  _formatDate(createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color:
                                    Color(0xFF999DA6),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 15),

                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              question.isEmpty
                                  ? '문제를 눌러 내용을 확인하세요.'
                                  : question,
                              maxLines: 2,
                              overflow:
                              TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: Color(0xFF777C86),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 17,
                                  color: Color(0xFF90949D),
                                ),

                                const SizedBox(width: 5),

                                Expanded(
                                  child: Text(
                                    '$senderNickname 님이 발송',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color:
                                      Color(0xFF858994),
                                    ),
                                  ),
                                ),

                                const Text(
                                  '문제 풀기',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                    Color(0xFF6C54C8),
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(width: 3),

                                const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF6C54C8),
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
          const SnackBar(
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
        const SnackBar(
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
        const SnackBar(
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

    Color backgroundColor = Colors.white;
    Color borderColor =
    const Color(0xFFE1E3E8);
    Color numberColor =
    const Color(0xFF777C86);

    if (!_isSubmitted && isSelected) {
      backgroundColor =
      const Color(0xFFF0ECFF);
      borderColor =
      const Color(0xFF8068D8);
      numberColor =
      const Color(0xFF6C54C8);
    }

    if (_isSubmitted &&
        index == correctAnswerIndex) {
      backgroundColor =
      const Color(0xFFE5F7EE);
      borderColor =
      const Color(0xFF4BA87D);
      numberColor =
      const Color(0xFF31825E);
    }

    if (_isSubmitted &&
        isSelected &&
        index != correctAnswerIndex) {
      backgroundColor =
      const Color(0xFFFFECEF);
      borderColor =
      const Color(0xFFE66F7E);
      numberColor =
      const Color(0xFFD95668);
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
        duration: const Duration(
          milliseconds: 180,
        ),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
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

            const SizedBox(width: 13),

            Expanded(
              child: Text(
                choice,
                style: const TextStyle(
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
                    ? const Color(0xFFD95668)
                    : const Color(0xFF6C54C8),
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
      appBar: AppBar(
        title: const Text('문제 풀기'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: AppMainBackground(
        applySafeArea: false,
        child: _isLoadingAnswer
            ? const Center(
          child:
          CircularProgressIndicator(),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
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
                const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                  const Color(0xFFE9E4FF),
                  borderRadius:
                  BorderRadius.circular(15),
                ),
                child: const Text(
                  '객관식 문제',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6F58C9),
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              AppCard(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.55,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                '정답 선택',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              if (choices.isEmpty)
                const AppCard(
                  child: Text(
                    '등록된 보기가 없습니다.',
                    style: TextStyle(
                      color: Color(0xFF858994),
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
                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: _isCorrect
                        ? const Color(0xFFE5F7EE)
                        : const Color(0xFFFFECEF),
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
                                ? const Color(
                              0xFF31825E,
                            )
                                : const Color(
                              0xFFD95668,
                            ),
                          ),

                          const SizedBox(width: 8),

                          Text(
                            _isCorrect
                                ? '정답입니다!'
                                : '오답입니다.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                              FontWeight.bold,
                              color: _isCorrect
                                  ? const Color(
                                0xFF31825E,
                              )
                                  : const Color(
                                0xFFD95668,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (explanation.isNotEmpty) ...[
                        const SizedBox(height: 12),

                        Text(
                          explanation,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color:
                            Color(0xFF5F636B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                  choices.isEmpty ||
                      _isSubmitted ||
                      _isSaving
                      ? null
                      : _submitAnswer,
                  style:
                  ElevatedButton.styleFrom(
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
                    width: 20,
                    height: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    _isSubmitted
                        ? '제출 완료'
                        : '정답 제출',
                    style: const TextStyle(
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
    );
  }
}