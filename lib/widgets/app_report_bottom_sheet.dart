import 'package:flutter/material.dart';

import '../theme.dart';

class AppReportResult {
  final String reasonType;
  final String description;

  const AppReportResult({required this.reasonType, required this.description});
}

class AppReportBottomSheet extends StatefulWidget {
  final String title;
  final Map<String, String> reasons;
  final String initialReason;
  final String descriptionHint;

  const AppReportBottomSheet({
    super.key,
    required this.title,
    required this.reasons,
    this.initialReason = 'SPAM',
    this.descriptionHint = '신고 내용을 자세히 알려주세요. (선택)',
  });

  static Future<AppReportResult?> show(
    BuildContext context, {
    required String title,
    required Map<String, String> reasons,
    String initialReason = 'SPAM',
    String descriptionHint = '신고 내용을 자세히 알려주세요. (선택)',
  }) {
    return showModalBottomSheet<AppReportResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppReportBottomSheet(
        title: title,
        reasons: reasons,
        initialReason: initialReason,
        descriptionHint: descriptionHint,
      ),
    );
  }

  @override
  State<AppReportBottomSheet> createState() => _AppReportBottomSheetState();
}

class _AppReportBottomSheetState extends State<AppReportBottomSheet> {
  late String _selectedReason;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedReason = widget.initialReason;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.textSecondary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.colors.incorrectSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.report_outlined,
                      color: context.colors.incorrect,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '신고 사유를 선택해 주세요.',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...widget.reasons.entries.map(_buildReasonItem),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLength: 500,
                maxLines: 4,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: InputDecoration(
                  labelText: '상세 내용 (선택)',
                  hintText: widget.descriptionHint,
                  filled: true,
                  fillColor: context.colors.incorrectSoft.withValues(
                    alpha: 0.45,
                  ),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.colors.incorrect),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      AppReportResult(
                        reasonType: _selectedReason,
                        description: _descriptionController.text.trim(),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.incorrect,
                    foregroundColor: context.colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.report_outlined),
                  label: const Text(
                    '신고 접수하기',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonItem(MapEntry<String, String> entry) {
    final isSelected = _selectedReason == entry.key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedReason = entry.key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? context.colors.incorrectSoft
                : context.colors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? context.colors.incorrect
                  : context.colors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected
                    ? context.colors.incorrect
                    : context.colors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                entry.value,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
