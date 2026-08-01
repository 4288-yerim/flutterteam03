import 'package:flutter/material.dart';

import '../services/admin_report_service.dart';

class ReportManagementScreen extends StatefulWidget {
  const ReportManagementScreen({super.key});

  @override
  State<ReportManagementScreen> createState() =>
      _ReportManagementScreenState();
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
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
          );
        }

        final allReports = snapshot.data!;
        final reports = _pendingOnly
            ? allReports.where((report) => report.isPending).toList()
            : allReports;

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
          children: [
            _ReportHeader(
              totalCount: allReports.length,
              pendingCount: allReports.where((report) => report.isPending).length,
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

  void _showProcessSheet(AdminReport report) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '신고 처리',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                '· ${report.targetTitle.isEmpty ? report.targetNickname : report.targetTitle}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF6E6A76), height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('반려'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('승인'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '· 승인/반려 처리 기능은 아직 연결되지 않았습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8A8692), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
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
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E5EE)),
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
            style: const TextStyle(color: Color(0xFF6E6A76)),
          ),
          const SizedBox(height: 12),
          FilterChip(
            selected: pendingOnly,
            label: const Text('미처리만 보기'),
            onSelected: onPendingOnlyChanged,
            selectedColor: const Color(0xFFE9E7FF),
            checkmarkColor: const Color(0xFF5D54D6),
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
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E5EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Badge(label: _targetTypeLabel(report.targetType)),
              const SizedBox(width: 8),
              _Badge(
                label: report.isPending ? '미처리' : '처리완료',
                highlighted: report.isPending,
              ),
              const Spacer(),
              Text(
                _dateLabel(report.createdAt),
                style: const TextStyle(color: Color(0xFF8A8692), fontSize: 12),
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
            style: const TextStyle(color: Color(0xFF4E4B55), fontWeight: FontWeight.w700),
          ),
          if (report.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              report.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6E6A76), height: 1.45),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '신고자: ${report.reporterNickname}',
            style: const TextStyle(color: Color(0xFF8A8692), fontSize: 13),
          ),
          if (report.isPending) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onProcess,
                icon: const Icon(Icons.gavel_rounded, size: 18),
                label: const Text('신고 처리'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5D54D6),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _dateLabel(DateTime? date) {
    if (date == null) return '날짜 없음';
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}.${twoDigits(date.month)}.${twoDigits(date.day)} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  static String _targetTypeLabel(String type) => switch (type.toUpperCase()) {
    'POST' => '게시글',
    'COMMENT' => '댓글',
    'STUDY_MEMBER' => '스터디원',
    'STUDY_GROUP' => '스터디',
    _ => '기타',
  };

  static String _reasonLabel(String reason) => switch (reason.toUpperCase()) {
    'SPAM' => '스팸/홍보',
    'ABUSE' => '욕설/괴롭힘',
    'INAPPROPRIATE' => '부적절한 콘텐츠',
    'FALSE_INFORMATION' => '거짓 정보',
    'COPYRIGHT' => '저작권 침해',
    _ => '기타',
  };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFECE8) : const Color(0xFFF1EFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? const Color(0xFFB23A2A) : const Color(0xFF5149B8),
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
          Icon(icon, size: 46, color: const Color(0xFF8A8692)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Color(0xFF6E6A76))),
        ],
      ),
    );
  }
}
