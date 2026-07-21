import 'quiz_session_page.dart';
import 'package:flutter/material.dart';
import 'question_generation.dart';
import '../theme.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'services/question_generation_api_service.dart';

class QuizResultPage extends StatelessWidget {
  final int totalCount;
  final List<WrongAnswer> wrongAnswers;
  final Duration elapsed;
  final QuizSourceType sourceType;
  final String? certificationName;
  final String examType;
  final String? subject;
  final AnswerCheckMode checkMode;

  const QuizResultPage({
    super.key,
    required this.totalCount,
    required this.wrongAnswers,
    required this.elapsed,
    required this.sourceType,
    required this.certificationName,
    required this.examType,
    required this.subject,
    required this.checkMode,
  });

  String get _elapsedLabel {
    final m = elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final correctCount = totalCount - wrongAnswers.length;
    final ratio = totalCount == 0 ? 0.0 : correctCount / totalCount;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(title: '결과', centerTitle: true, leading: const SizedBox.shrink()),
      body: AppMainBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _ResultHeaderCard(
                correctCount: correctCount,
                totalCount: totalCount,
                ratio: ratio,
                elapsedLabel: _elapsedLabel,
              ),
              const SizedBox(height: 28),
              if (wrongAnswers.isEmpty)
                const _PerfectScoreCard()
              else ...[
                Row(
                  children: [
                    Text('틀린 문제',
                        style: TextStyle(
                            color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.colors.incorrectSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${wrongAnswers.length}개',
                          style: TextStyle(
                              color: context.colors.incorrect, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 13, color: context.colors.textSecondary),
                    const SizedBox(width: 4),
                    Text('오답노트에 자동으로 저장됐어요.',
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 12.5)),
                  ],
                ),
                const SizedBox(height: 16),
                ...wrongAnswers.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _WrongAnswerCard(index: e.key + 1, wrongAnswer: e.value),
                )),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [context.colors.pinkDeep, const Color(0xFFFF9EAE)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.pinkDeep.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      child: const Center(
                        child: Text('완료',
                            style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
              ),
              if (certificationName != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _confirmRetry(context),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: context.colors.pinkDeep, width: 1.5),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, color: context.colors.pinkDeep, size: 19),
                              const SizedBox(width: 8),
                              Text('다시 풀기',
                                  style: TextStyle(
                                      color: context.colors.pinkDeep,
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRetry(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: context.colors.pinkDeep.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: context.colors.pinkDeep),
                child: const Icon(Icons.replay_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 18),
              Text(
                '${certificationName ?? ''}(으)로\n계속 풀까요?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '같은 자격증으로 새 문제를 만들거나,\n다른 자격증을 선택할 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: Material(
                        color: const Color(0xFFF6F1F2),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.pop(dialogContext);
                            _goToFreshGeneration(context);
                          },
                          child: Center(
                            child: Text(
                              '새 자격증 선택',
                              style: TextStyle(
                                color: context.colors.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: Material(
                        color: context.colors.pinkDeep,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.pop(dialogContext);
                            _retry(context);
                          },
                          child: const Center(
                            child: Text(
                              '계속 풀기',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToFreshGeneration(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const QuestionGenerationPage()),
          (route) => route.isFirst,
    );
  }

  Future<void> _retry(BuildContext context) async {
    final certName = certificationName;
    if (certName == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: context.colors.pinkDeep),
              const SizedBox(height: 18),
              Text(
                '새 문제를 준비하고 있어요',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final stopwatch = Stopwatch()..start();
    try {
      final questions = await QuestionGenerationApiService.generateQuestionBatch(
        certificationName: certName,
        examType: examType,
        subject: subject == '전체' ? null : subject,
        count: totalCount,
      );
      stopwatch.stop();

      if (!context.mounted) return;
      Navigator.of(context).pop(); // 로딩 닫기

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuizSessionPage(
            sourceType: sourceType,
            certificationName: certName,
            pdfFileName: null,
            examType: examType,
            subject: subject,
            questions: questions,
            checkMode: checkMode,
            generationDurationSeconds: stopwatch.elapsed.inSeconds,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // 로딩 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문제를 다시 생성하지 못했어요. 잠시 후 다시 시도해주세요.')),
      );
    }
  }
}

class _ResultHeaderCard extends StatelessWidget {
  final int correctCount;
  final int totalCount;
  final double ratio;
  final String elapsedLabel;

  const _ResultHeaderCard({
    required this.correctCount,
    required this.totalCount,
    required this.ratio,
    required this.elapsedLabel,
  });

  ({IconData icon, String message}) get _mood {
    if (ratio >= 0.8) return (icon: Icons.emoji_events_rounded, message: '완벽에 가까운 실력이에요!');
    if (ratio >= 0.5) return (icon: Icons.local_fire_department_rounded, message: '좋아요, 감을 잡아가고 있어요!');
    return (icon: Icons.spa_rounded, message: '오답노트로 차근차근 채워볼까요?');
  }

  @override
  Widget build(BuildContext context) {
    final mood = _mood;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [context.colors.pinkDeep, const Color(0xFFFF8FA3), const Color(0xFFFFC9D4)],
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(mood.icon, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 18),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$correctCount',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, height: 1),
                      ),
                      TextSpan(
                        text: ' / $totalCount',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 22,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  mood.message,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92), fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 17, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('소요 시간 $elapsedLabel',
                          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 장식용 원형 일러스트 레이어
          Positioned(
            top: -30,
            right: -30,
            child: _softCircle(90, Colors.white.withValues(alpha: 0.12)),
          ),
          Positioned(
            bottom: -40,
            left: -20,
            child: _softCircle(120, Colors.white.withValues(alpha: 0.10)),
          ),
          Positioned(
            top: 60,
            left: -10,
            child: _softCircle(30, Colors.white.withValues(alpha: 0.14)),
          ),
        ],
      ),
    );
  }

  Widget _softCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _PerfectScoreCard extends StatelessWidget {
  const _PerfectScoreCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.colors.correctSoft, Colors.white],
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [context.colors.correct, context.colors.correct.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.correct.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 40),
              ..._sparkles(context),
            ],
          ),
          const SizedBox(height: 20),
          Text('전 문제를 다 맞혔어요!',
              style: TextStyle(color: context.colors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('이 페이스라면 실전도 문제없어요',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  List<Widget> _sparkles(BuildContext context) {
    const positions = [
      Offset(-46, -36),
      Offset(50, -30),
      Offset(-52, 30),
      Offset(48, 34),
    ];
    return positions
        .map((p) => Positioned(
      left: 52 + p.dx,
      top: 52 + p.dy,
      child: Icon(Icons.auto_awesome_rounded, size: 14, color: context.colors.pinkDeep),
    ))
        .toList();
  }
}

class _WrongAnswerCard extends StatelessWidget {
  final int index;
  final WrongAnswer wrongAnswer;
  const _WrongAnswerCard({required this.index, required this.wrongAnswer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14C98198), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.colors.incorrectSoft, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: context.colors.incorrect, shape: BoxShape.circle),
                  child: Text('$index',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(wrongAnswer.question,
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          height: 1.4)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _answerChip(
                  context,
                  icon: Icons.cancel_rounded,
                  label: '내 답',
                  value: wrongAnswer.userAnswer,
                  color: context.colors.incorrect,
                  bg: context.colors.incorrectSoft,
                ),
                const SizedBox(height: 8),
                _answerChip(
                  context,
                  icon: Icons.check_circle_rounded,
                  label: '정답',
                  value: wrongAnswer.correctAnswer,
                  color: context.colors.correct,
                  bg: context.colors.correctSoft,
                ),
                if (wrongAnswer.explanation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F5F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF1EBEE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_rounded, size: 15, color: context.colors.pinkDeep),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(wrongAnswer.explanation,
                              style: TextStyle(
                                  color: context.colors.textSecondary, fontSize: 12.5, height: 1.5)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerChip(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String value,
        required Color color,
        required Color bg,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(value,
                style:
                TextStyle(color: context.colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}