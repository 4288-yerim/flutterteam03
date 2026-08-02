import 'package:flutter/material.dart';

import '../../theme.dart';
import '../services/admin_report_service.dart';

class ReportManagementScreen extends StatefulWidget {
  const ReportManagementScreen({super.key});

  @override
  State<ReportManagementScreen> createState() => _ReportManagementScreenState();
}

class _ReportManagementScreenState extends State<ReportManagementScreen> {
  final AdminReportService _service = AdminReportService();
  bool _pendingOnly = true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminReport>>(
      stream: _service.watchReports(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _ReportMessage(
            icon: Icons.error_outline_rounded,
            message: '신고 내역을 불러오지 못했습니다.',
          );
        }
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: context.colors.lavenderAccent,
            ),
          );
        }

        final allReports = snapshot.data!;
        final reports = _pendingOnly
            ? allReports.where((report) => report.isPending).toList()
            : allReports;
        final pendingCount = allReports
            .where((report) => report.isPending)
            .length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
          children: [
            _ReportHeader(
              totalCount: allReports.length,
              pendingCount: pendingCount,
              pendingOnly: _pendingOnly,
              onPendingOnlyChanged: (value) {
                setState(() => _pendingOnly = value);
              },
            ),
            const SizedBox(height: 18),
            if (reports.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: _ReportMessage(
                  icon: Icons.inbox_outlined,
                  message: '표시할 신고 내역이 없습니다.',
                ),
              )
            else
              ...reports.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReportCard(
                    report: report,
                    onProcess: () => _showProcessSheet(report),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showProcessSheet(AdminReport report) async {
    var hideContent = report.canHideContent;
    var isProcessing = false;
    String? errorMessage;

    final result = await showModalBottomSheet<AdminReportDecision>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.surfaceElevated,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> process(AdminReportDecision decision) async {
            if (isProcessing) return;

            setSheetState(() {
              isProcessing = true;
              errorMessage = null;
            });
            try {
              await _service.processReport(
                report: report,
                decision: decision,
                hideContent:
                    decision == AdminReportDecision.approve && hideContent,
              );
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop(decision);
            } catch (error) {
              if (!sheetContext.mounted) return;
              setSheetState(() {
                isProcessing = false;
                errorMessage = _processErrorMessage(error);
              });
            }
          }

          return SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.fromLTRB(
                22,
                0,
                22,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '신고 처리',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ReportDetailBox(report: report),
                    if (report.canHideContent) ...[
                      const SizedBox(height: 14),
                      CheckboxListTile(
                        value: hideContent,
                        enabled: !isProcessing,
                        onChanged: (value) {
                          setSheetState(() => hideContent = value ?? false);
                        },
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          '승인 시 신고 대상 콘텐츠 숨기기',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          report.targetType == 'POST'
                              ? '게시글을 비공개 처리하고 목록에서 숨깁니다.'
                              : '댓글 상태를 차단으로 변경해 목록에서 숨깁니다.',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    if (errorMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          color: context.colors.incorrect,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isProcessing
                                ? null
                                : () => process(AdminReportDecision.reject),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('반려'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.colors.incorrect,
                              side: BorderSide(
                                color: context.colors.incorrectSoft,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isProcessing
                                ? null
                                : () => process(AdminReportDecision.approve),
                            icon: isProcessing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(isProcessing ? '처리 중...' : '승인'),
                            style: FilledButton.styleFrom(
                              backgroundColor: context.colors.lavenderAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
        },
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == AdminReportDecision.approve
                ? '신고를 승인했습니다.'
                : '신고를 반려했습니다.',
          ),
        ),
      );
    }
  }

  static String _processErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '');
    if (message.contains('permission-denied')) {
      return '관리자의 신고·회원·콘텐츠 수정 권한을 확인해 주세요.';
    }
    if (message.contains('not-found')) {
      return '신고 대상 문서를 찾지 못했습니다. 콘텐츠 숨김을 해제하고 다시 시도해 주세요.';
    }
    if (error is ArgumentError) {
      return error.message?.toString() ?? '입력값을 확인해 주세요.';
    }
    if (error is StateError) return message;
    return '처리에 실패했습니다. 잠시 후 다시 시도해 주세요.';
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({
    required this.totalCount,
    required this.pendingCount,
    required this.pendingOnly,
    required this.onPendingOnlyChanged,
  });

  final int totalCount;
  final int pendingCount;
  final bool pendingOnly;
  final ValueChanged<bool> onPendingOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '신고 내역',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '전체 $totalCount건 · 미처리 $pendingCount건',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 12),
          FilterChip(
            selected: pendingOnly,
            label: const Text('미처리만 보기'),
            onSelected: onPendingOnlyChanged,
            selectedColor: context.colors.lavender,
            checkmarkColor: context.colors.lavenderAccent,
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onProcess});

  final AdminReport report;
  final VoidCallback onProcess;

  @override
  Widget build(BuildContext context) {
    final target = report.targetTitle.isNotEmpty
        ? report.targetTitle
        : report.targetNickname.isNotEmpty
        ? report.targetNickname
        : '대상 정보 없음';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Badge(label: _targetTypeLabel(report.targetType)),
              const SizedBox(width: 8),
              _ReportStatusBadge(report: report),
              const Spacer(),
              Text(
                _dateLabel(report.createdAt),
                style: TextStyle(color: context.colors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            target,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            '신고 사유: ${_reasonLabel(report.reasonType)}',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (report.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              report.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '신고자: ${report.reporterNickname}',
            style: TextStyle(color: context.colors.textMuted, fontSize: 13),
          ),
          if (!report.isPending) ...[
            const SizedBox(height: 10),
            _ProcessedSummary(report: report),
          ],
          if (report.isPending) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onProcess,
                icon: const Icon(Icons.gavel_rounded, size: 18),
                label: const Text('신고 처리'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.lavenderAccent,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportDetailBox extends StatelessWidget {
  const _ReportDetailBox({required this.report});

  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final target = report.targetTitle.isNotEmpty
        ? report.targetTitle
        : report.targetNickname.isNotEmpty
        ? report.targetNickname
        : '대상 정보 없음';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_targetTypeLabel(report.targetType)} · ${_reasonLabel(report.reasonType)}',
            style: TextStyle(
              color: context.colors.lavenderAccent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            target,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          if (report.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText(
              report.description,
              style: TextStyle(
                color: context.colors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '신고자: ${report.reporterNickname} · ${_dateLabel(report.createdAt)}',
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ProcessedSummary extends StatelessWidget {
  const _ProcessedSummary({required this.report});

  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final details = <String>[if (report.contentWasHidden) '콘텐츠 숨김'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '처리일: ${_dateLabel(report.processedAt)}',
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              details.join(' · '),
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportStatusBadge extends StatelessWidget {
  const _ReportStatusBadge({required this.report});

  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = report.isPending
        ? ('미처리', context.colors.warning, context.colors.warningSoft)
        : report.isApproved
        ? ('승인', context.colors.correct, context.colors.correctSoft)
        : ('반려', context.colors.textSecondary, context.colors.surfaceMuted);
    return _Badge(
      label: label,
      foregroundColor: foreground,
      backgroundColor: background,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    this.foregroundColor,
    this.backgroundColor,
  });

  final String label;
  final Color? foregroundColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor ?? context.colors.lavender,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor ?? context.colors.lavenderAccent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReportMessage extends StatelessWidget {
  const _ReportMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: context.colors.textMuted),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: context.colors.textSecondary)),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime? date) {
  if (date == null) return '날짜 없음';
  return '${date.year}.${_twoDigits(date.month)}.${_twoDigits(date.day)} '
      '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
}

String _targetTypeLabel(String type) => switch (type.toUpperCase()) {
  'POST' => '게시글',
  'COMMENT' => '댓글',
  'STUDY_MEMBER' => '스터디원',
  'STUDY_GROUP' => '스터디',
  _ => '기타',
};

String _reasonLabel(String reason) => switch (reason.toUpperCase()) {
  'SPAM' => '스팸/홍보',
  'ABUSE' => '욕설/괴롭힘',
  'INAPPROPRIATE' => '부적절한 콘텐츠',
  'FALSE_INFORMATION' => '거짓 정보',
  'FRAUD' => '사기/허위 정보',
  'COPYRIGHT' => '저작권 침해',
  'ETC' => '기타',
  _ => '기타',
};

String _twoDigits(int value) => value.toString().padLeft(2, '0');
