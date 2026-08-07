import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../theme.dart';

class ExamResultDialog extends StatefulWidget {
  final String studyPlanId;
  final String certificateName;

  const ExamResultDialog({
    super.key,
    required this.studyPlanId,
    required this.certificateName,
  });

  @override
  State<ExamResultDialog> createState() => _ExamResultDialogState();
}

class _ExamResultDialogState extends State<ExamResultDialog> {
  bool _isSubmitting = false;

  Future<void> _submit(bool passed) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('reportExamResult');
      await callable.call({
        'studyPlanId': widget.studyPlanId,
        'passed': passed,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('결과 저장에 실패했어요. 나중에 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 22),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.colors.pinkSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.emoji_events_outlined,
                color: context.colors.pinkStart,
                size: 26,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '${widget.certificateName} 시험은\n어떠셨나요?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '결과를 알려주시면 AI 합격 예측이 더 정확해져요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => _submit(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.textPrimary,
                        side: BorderSide(color: context.colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        '아쉽게 불합격',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : () => _submit(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.pinkStart,
                        foregroundColor: context.colors.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: context.colors.onPrimary,
                        ),
                      )
                          : Text(
                        '합격했어요',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
              child: Text(
                '나중에 알려줄게요',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}