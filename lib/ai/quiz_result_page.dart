import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'services/question_generation_api_service.dart';

class QuizResultPage extends StatelessWidget {
  final int totalCount;
  final List<WrongAnswer> wrongAnswers;
  final Duration elapsed;

  const QuizResultPage({
    super.key,
    required this.totalCount,
    required this.wrongAnswers,
    required this.elapsed,
  });

  String get _elapsedLabel {
    final m = elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final correctCount = totalCount - wrongAnswers.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(title: '결과', centerTitle: true, leading: const SizedBox.shrink()),
      body: AppMainBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Color(0x14C98198), blurRadius: 18, offset: Offset(0, 8))],
                ),
                child: Column(
                  children: [
                    Text('$correctCount / $totalCount',
                        style: TextStyle(color: context.colors.pinkDeep, fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('정답',
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer_outlined, size: 18, color: context.colors.textSecondary),
                        const SizedBox(width: 6),
                        Text('소요 시간 $_elapsedLabel',
                            style: TextStyle(
                                color: context.colors.textSecondary, fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (wrongAnswers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.emoji_events_rounded, color: context.colors.correct, size: 40),
                      const SizedBox(height: 12),
                      Text('전 문제를 다 맞혔어요!', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w800)),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    Text('틀린 문제', style: TextStyle(color: context.colors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Text('${wrongAnswers.length}개',
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('오답노트에 자동으로 저장됐어요.',
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 12.5)),
                const SizedBox(height: 14),
                ...wrongAnswers.map((wa) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _WrongAnswerCard(wrongAnswer: wa),
                )),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.pinkDeep,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text('완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WrongAnswerCard extends StatelessWidget {
  final WrongAnswer wrongAnswer;
  const _WrongAnswerCard({required this.wrongAnswer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1EBEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(wrongAnswer.question,
              style: TextStyle(color: context.colors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.4)),
          const SizedBox(height: 10),
          _answerRow(context, '내 답', wrongAnswer.userAnswer, context.colors.incorrect),
          const SizedBox(height: 4),
          _answerRow(context, '정답', wrongAnswer.correctAnswer, context.colors.correct),
          if (wrongAnswer.explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF7F5F6), borderRadius: BorderRadius.circular(12)),
              child: Text(wrongAnswer.explanation,
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 12.5, height: 1.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _answerRow(BuildContext context, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label  ', style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800)),
        Expanded(child: Text(value, style: TextStyle(color: context.colors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600))),
      ],
    );
  }
}