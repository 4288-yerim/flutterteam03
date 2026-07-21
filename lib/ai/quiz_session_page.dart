import 'dart:async';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'quiz_result_page.dart';
import 'question_generation.dart' show AnswerCheckMode;
import 'services/question_generation_api_service.dart';

class QuizSessionPage extends StatefulWidget {
  final String certificationName;
  final String examType;
  final String? subject;
  final List<GeneratedQuestion> questions;
  final AnswerCheckMode checkMode;

  const QuizSessionPage({
    super.key,
    required this.certificationName,
    required this.examType,
    required this.subject,
    required this.questions,
    required this.checkMode,
  });

  @override
  State<QuizSessionPage> createState() => _QuizSessionPageState();
}

class _QuizSessionPageState extends State<QuizSessionPage> {
  late final Stopwatch _stopwatch;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  int _currentIndex = 0;
  late final List<String?> _userAnswers;
  bool _revealed = false;

  GeneratedQuestion get _current => widget.questions[_currentIndex];
  bool get _isLast => _currentIndex == widget.questions.length - 1;
  bool get _isMultipleChoice => _current.options.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _userAnswers = List.filled(widget.questions.length, null, growable: false);
    _stopwatch = Stopwatch()..start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = _stopwatch.elapsed);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  String get _elapsedLabel {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _selectOption(String option) {
    if (widget.checkMode == AnswerCheckMode.immediate && _revealed) return;
    setState(() => _userAnswers[_currentIndex] = option);
    if (widget.checkMode == AnswerCheckMode.immediate) {
      setState(() => _revealed = true);
    }
  }

  void _reveal() => setState(() => _revealed = true);

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    setState(() {
      _currentIndex += 1;
      _revealed = false;
    });
  }

  void _finish() {
    _stopwatch.stop();
    _ticker?.cancel();

    final wrongAnswers = <WrongAnswer>[];
    for (var i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final userAnswer = _userAnswers[i];
      if (userAnswer != q.answer) {
        wrongAnswers.add(WrongAnswer(
          certificationName: widget.certificationName,
          examType: widget.examType,
          subject: widget.subject,
          question: q.question,
          options: q.options,
          correctAnswer: q.answer,
          userAnswer: (userAnswer == null || userAnswer.isEmpty) ? '(미응답)' : userAnswer,
          explanation: q.explanation,
        ));
      }
    }

    QuestionGenerationApiService.saveWrongAnswers(wrongAnswers).catchError((e) {
      debugPrint('오답노트 저장 실패: $e');
    });

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizResultPage(
          totalCount: widget.questions.length,
          wrongAnswers: wrongAnswers,
          elapsed: _elapsed,
        ),
      ),
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('퀴즈를 종료할까요?'),
        content: const Text('지금까지 푼 문제는 저장되지 않아요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('계속 풀기')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('종료'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          title: '${_currentIndex + 1} / ${widget.questions.length}',
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _confirmExit,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: context.colors.textSecondary),
                    const SizedBox(width: 4),
                    Text(_elapsedLabel,
                        style: TextStyle(color: context.colors.textSecondary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: AppMainBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildProgressBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuestionCard(),
                        const SizedBox(height: 20),
                        if (_isMultipleChoice)
                          ..._current.options.asMap().entries.map(
                                (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildOption(e.value, e.key),
                            ),
                          )
                        else
                          _buildShortAnswerInput(),
                        if (_revealed) ...[
                          const SizedBox(height: 16),
                          _buildExplanationCard(),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentIndex + 1) / widget.questions.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: context.colors.pinkSoft,
          valueColor: AlwaysStoppedAnimation(context.colors.pinkDeep),
        ),
      ),
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14C98198), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: context.colors.pinkSoft, borderRadius: BorderRadius.circular(8)),
            child: Text('Q${_currentIndex + 1}',
                style: TextStyle(color: context.colors.pinkDeep, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          Text(
            _current.question,
            style: TextStyle(
                color: context.colors.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(String option, int index) {
    final label = String.fromCharCode(65 + index);
    final isSelected = _userAnswers[_currentIndex] == option;
    final isCorrectOption = option == _current.answer;
    final showResult = _revealed;

    var borderColor = const Color(0xFFF1EBEE);
    var fillColor = Colors.white;
    var labelColor = context.colors.textSecondary;
    var labelBg = const Color(0xFFF2EEF0);

    if (showResult) {
      if (isCorrectOption) {
        borderColor = context.colors.correct;
        fillColor = context.colors.correctSoft;
        labelColor = Colors.white;
        labelBg = context.colors.correct;
      } else if (isSelected) {
        borderColor = context.colors.incorrect;
        fillColor = context.colors.incorrectSoft;
        labelColor = Colors.white;
        labelBg = context.colors.incorrect;
      }
    } else if (isSelected) {
      borderColor = context.colors.pinkDeep;
      fillColor = context.colors.pinkSoft;
      labelColor = Colors.white;
      labelBg = context.colors.pinkDeep;
    }

    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: showResult ? null : () => _selectOption(option),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: labelBg, shape: BoxShape.circle),
                child:
                Text(label, style: TextStyle(color: labelColor, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(option,
                    style: TextStyle(
                        color: context.colors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w600)),
              ),
              if (showResult && isCorrectOption)
                Icon(Icons.check_circle_rounded, color: context.colors.correct, size: 20)
              else if (showResult && isSelected)
                Icon(Icons.cancel_rounded, color: context.colors.incorrect, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortAnswerInput() {
    return TextField(
      enabled: !_revealed,
      onChanged: (v) => setState(() => _userAnswers[_currentIndex] = v),
      decoration: InputDecoration(
        hintText: '답을 입력해주세요',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF7F5F6), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('정답: ${_current.answer}',
              style: TextStyle(color: context.colors.correct, fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(_current.explanation,
              style: TextStyle(color: context.colors.textPrimary, fontSize: 13.5, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final answered = (_userAnswers[_currentIndex]?.trim().isNotEmpty ?? false);

    if (widget.checkMode == AnswerCheckMode.immediate && !_isMultipleChoice && !_revealed) {
      return _bottomButton(label: '정답 확인', enabled: answered, onPressed: _reveal);
    }

    final canProceed = widget.checkMode == AnswerCheckMode.immediate ? _revealed : answered;
    return _bottomButton(
      label: _isLast ? '결과 보기' : '다음 문제',
      enabled: canProceed,
      onPressed: _next,
    );
  }

  Widget _bottomButton({required String label, required bool enabled, required VoidCallback onPressed}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.pinkDeep,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}