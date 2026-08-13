import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/user_profile_cache_service.dart';
import '../../theme.dart';
import '../services/admin_report_service.dart';

class ReportManagementScreen extends StatefulWidget {
  const ReportManagementScreen({super.key});

  @override
  State<ReportManagementScreen> createState() =>
      _ReportManagementScreenState();
}

enum _ReportFilter { all, pending, approved, rejected }

class _ReportManagementScreenState extends State<ReportManagementScreen> {
  final AdminReportService _service = AdminReportService();
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _reopeningReportIds = <String>{};
  final Set<String> _requestedNicknameUids = <String>{};
  final Map<String, String> _resolvedNicknames = <String, String>{};

  late final Stream<List<AdminReport>> _reports;

  _ReportFilter _filter = _ReportFilter.pending;

  @override
  void initState() {
    super.initState();
    _reports = _service.watchReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminReport>>(
      stream: _reports,
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

        _queueNicknameLoads(allReports);

        final reports = _applyFilters(allReports);
        final pendingCount = allReports
            .where((report) => report.isPending)
            .length;

        final hasQuery = _searchController.text.trim().isNotEmpty;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
            children: [
              _ReportHeader(
                totalCount: allReports.length,
                pendingCount: pendingCount,
                searchController: _searchController,
                selectedFilter: _filter,
                onSearchChanged: (_) => setState(() {}),
                onFilterChanged: (filter) {
                  setState(() => _filter = filter);
                },
              ),
              const SizedBox(height: 18),
              if (reports.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: _ReportMessage(
                    icon: hasQuery
                        ? Icons.search_off_rounded
                        : Icons.inbox_outlined,
                    message: hasQuery
                        ? '검색 조건에 맞는 신고 내역이 없습니다.'
                        : '표시할 신고 내역이 없습니다.',
                  ),
                )
              else
                ...reports.map((report) {
                  final reporterNickname = _nicknameFor(
                    uid: report.reporterUid,
                    fallback: report.reporterNickname,
                  );

                  final targetNickname = _nicknameFor(
                    uid: report.targetUid,
                    fallback: report.targetNickname,
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReportCard(
                      report: report,
                      reporterNickname: reporterNickname,
                      targetNickname: targetNickname,
                      onProcess: () => _showProcessSheet(report),
                      isReopening: _reopeningReportIds.contains(report.id),
                      onReopen: () => _confirmReopen(report),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  void _queueNicknameLoads(List<AdminReport> reports) {
    for (final report in reports) {
      _queueNicknameLoad(
        uid: report.reporterUid,
        fallback: report.reporterNickname,
      );

      _queueNicknameLoad(
        uid: report.targetUid,
        fallback: report.targetNickname,
      );
    }
  }

  void _queueNicknameLoad({
    required String uid,
    required String fallback,
  }) {
    final normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) return;
    if (!_requestedNicknameUids.add(normalizedUid)) return;

    unawaited(
      _loadNickname(
        uid: normalizedUid,
        fallback: fallback,
      ),
    );
  }

  Future<void> _loadNickname({
    required String uid,
    required String fallback,
  }) async {
    try {
      final nickname =
      await UserProfileCacheService.instance.resolveNickname(
        uid: uid,
        fallback: fallback,
      );

      if (!mounted) return;
      if (_resolvedNicknames[uid] == nickname) return;

      setState(() {
        _resolvedNicknames[uid] = nickname;
      });
    } catch (_) {
      // 프로필 조회 실패 시 신고 문서에 저장된 닉네임을 사용합니다.
    }
  }

  String _nicknameFor({
    required String uid,
    required String fallback,
  }) {
    final normalizedUid = uid.trim();
    final normalizedFallback = fallback.trim();

    if (normalizedUid.isEmpty) {
      return normalizedFallback;
    }

    return _resolvedNicknames[normalizedUid] ??
        (normalizedFallback.isNotEmpty ? normalizedFallback : '사용자');
  }

  List<AdminReport> _applyFilters(List<AdminReport> reports) {
    final query = _searchController.text.trim().toLowerCase();

    return reports.where((report) {
      final matchesFilter = switch (_filter) {
        _ReportFilter.all => true,
        _ReportFilter.pending => report.isPending,
        _ReportFilter.approved => report.isApproved,
        _ReportFilter.rejected => report.isRejected,
      };

      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      final reporterNickname = _nicknameFor(
        uid: report.reporterUid,
        fallback: report.reporterNickname,
      );

      final targetNickname = _nicknameFor(
        uid: report.targetUid,
        fallback: report.targetNickname,
      );

      final searchableValues = <String>[
        reporterNickname,
        targetNickname,
        report.targetTitle,
        report.description,
        report.reasonType,
        _reasonLabel(report.reasonType),
        report.targetType,
        _targetTypeLabel(report.targetType),
        report.status,
        report.id,
        ...report.targetIds,
      ];

      return searchableValues.any(
            (value) => value.toLowerCase().contains(query),
      );
    }).toList();
  }

  Future<void> _showProcessSheet(AdminReport report) async {
    var hideContent = report.canHideContent;
    var isProcessing = false;
    String? errorMessage;

    final reporterNickname = _nicknameFor(
      uid: report.reporterUid,
      fallback: report.reporterNickname,
    );

    final targetNickname = _nicknameFor(
      uid: report.targetUid,
      fallback: report.targetNickname,
    );

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
                    _ReportDetailBox(
                      report: report,
                      reporterNickname: reporterNickname,
                      targetNickname: targetNickname,
                    ),
                    if (report.canHideContent) ...[
                      const SizedBox(height: 14),
                      CheckboxListTile(
                        value: hideContent,
                        enabled: !isProcessing,
                        onChanged: (value) {
                          setSheetState(() {
                            hideContent = value ?? false;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        controlAffinity:
                        ListTileControlAffinity.leading,
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
                                : () => process(
                              AdminReportDecision.reject,
                            ),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('반려'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                              context.colors.incorrect,
                              side: BorderSide(
                                color: context.colors.incorrectSoft,
                              ),
                              padding:
                              const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isProcessing
                                ? null
                                : () => process(
                              AdminReportDecision.approve,
                            ),
                            icon: isProcessing
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.check_rounded),
                            label: Text(
                              isProcessing ? '처리 중...' : '승인',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                              context.colors.lavenderAccent,
                              padding:
                              const EdgeInsets.symmetric(
                                vertical: 14,
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

  Future<void> _confirmReopen(AdminReport report) async {
    if (_reopeningReportIds.contains(report.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('신고 처리 취소'),
        content: Text(
          report.contentWasHidden
              ? '신고를 미처리 상태로 되돌리고, 이 신고로 숨긴 콘텐츠도 복구합니다.'
              : '신고를 미처리 상태로 되돌립니다. 다시 승인하거나 반려할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(false),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(true),
            child: const Text('처리 취소'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _reopeningReportIds.add(report.id));

    try {
      await _service.reopenReport(report);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('신고 처리를 취소했습니다.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_processErrorMessage(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _reopeningReportIds.remove(report.id);
        });
      }
    }
  }

  static String _processErrorMessage(Object error) {
    final message =
    error.toString().replaceFirst('Bad state: ', '');

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
    required this.searchController,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final int totalCount;
  final int pendingCount;
  final TextEditingController searchController;
  final _ReportFilter selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_ReportFilter> onFilterChanged;

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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '전체 $totalCount건 · 미처리 $pendingCount건',
            style: TextStyle(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '대상, 대상자, 신고자 또는 내용 검색',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                tooltip: '검색어 지우기',
                onPressed: () {
                  searchController.clear();
                  onSearchChanged('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ReportFilter.values.map((filter) {
              return FilterChip(
                selected: selectedFilter == filter,
                label: Text(_filterLabel(filter)),
                onSelected: (_) => onFilterChanged(filter),
                selectedColor: context.colors.lavender,
                checkmarkColor:
                context.colors.lavenderAccent,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static String _filterLabel(_ReportFilter filter) {
    return switch (filter) {
      _ReportFilter.all => '전체',
      _ReportFilter.pending => '미처리',
      _ReportFilter.approved => '승인',
      _ReportFilter.rejected => '반려',
    };
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.reporterNickname,
    required this.targetNickname,
    required this.onProcess,
    required this.onReopen,
    required this.isReopening,
  });

  final AdminReport report;
  final String reporterNickname;
  final String targetNickname;
  final VoidCallback onProcess;
  final VoidCallback onReopen;
  final bool isReopening;

  @override
  Widget build(BuildContext context) {
    final targetTitle = report.targetTitle.trim().isNotEmpty
        ? report.targetTitle.trim()
        : targetNickname.trim().isNotEmpty
        ? targetNickname.trim()
        : report.targetType == 'STUDY_GROUP'
        ? '스터디 그룹'
        : '대상 정보 없음';

    final hasTargetMember =
        report.targetUid.trim().isNotEmpty ||
            report.targetNickname.trim().isNotEmpty;

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
              _Badge(
                label: _targetTypeLabel(report.targetType),
              ),
              const SizedBox(width: 8),
              _ReportStatusBadge(report: report),
              const Spacer(),
              Text(
                _dateLabel(report.createdAt),
                style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            targetTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (hasTargetMember) ...[
            const SizedBox(height: 8),
            _PersonInfoRow(
              icon: Icons.person_outline_rounded,
              label: '신고 대상자',
              nickname: targetNickname.trim().isNotEmpty
                  ? targetNickname
                  : '사용자',
              color: context.colors.textSecondary,
            ),
          ] else if (report.targetType == 'STUDY_GROUP') ...[
            const SizedBox(height: 8),
            _PersonInfoRow(
              icon: Icons.groups_outlined,
              label: '신고 대상',
              nickname: '스터디 그룹',
              color: context.colors.textSecondary,
            ),
          ],
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
          _PersonInfoRow(
            icon: Icons.outlined_flag_rounded,
            label: '신고자',
            nickname: reporterNickname,
            color: context.colors.textMuted,
          ),
          if (!report.isPending) ...[
            const SizedBox(height: 10),
            _ProcessedSummary(report: report),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isReopening ? null : onReopen,
                icon: isReopening
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.undo_rounded,
                  size: 18,
                ),
                label: Text(
                  isReopening ? '취소 중...' : '처리 취소',
                ),
              ),
            ),
          ],
          if (report.isPending) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onProcess,
                icon: const Icon(
                  Icons.gavel_rounded,
                  size: 18,
                ),
                label: const Text('신고 처리'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                  context.colors.lavenderAccent,
                  padding: const EdgeInsets.symmetric(
                    vertical: 13,
                  ),
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
  const _ReportDetailBox({
    required this.report,
    required this.reporterNickname,
    required this.targetNickname,
  });

  final AdminReport report;
  final String reporterNickname;
  final String targetNickname;

  @override
  Widget build(BuildContext context) {
    final targetTitle = report.targetTitle.trim().isNotEmpty
        ? report.targetTitle.trim()
        : targetNickname.trim().isNotEmpty
        ? targetNickname.trim()
        : report.targetType == 'STUDY_GROUP'
        ? '스터디 그룹'
        : '대상 정보 없음';

    final hasTargetMember =
        report.targetUid.trim().isNotEmpty ||
            report.targetNickname.trim().isNotEmpty;

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
            '${_targetTypeLabel(report.targetType)} · '
                '${_reasonLabel(report.reasonType)}',
            style: TextStyle(
              color: context.colors.lavenderAccent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            targetTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (hasTargetMember) ...[
            const SizedBox(height: 10),
            _PersonInfoRow(
              icon: Icons.person_outline_rounded,
              label: '신고 대상자',
              nickname: targetNickname.trim().isNotEmpty
                  ? targetNickname
                  : '사용자',
              color: context.colors.textSecondary,
            ),
          ] else if (report.targetType == 'STUDY_GROUP') ...[
            const SizedBox(height: 10),
            _PersonInfoRow(
              icon: Icons.groups_outlined,
              label: '신고 대상',
              nickname: '스터디 그룹',
              color: context.colors.textSecondary,
            ),
          ],
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
          _PersonInfoRow(
            icon: Icons.outlined_flag_rounded,
            label: '신고자',
            nickname: reporterNickname,
            color: context.colors.textMuted,
            suffix: ' · ${_dateLabel(report.createdAt)}',
          ),
        ],
      ),
    );
  }
}

class _PersonInfoRow extends StatelessWidget {
  const _PersonInfoRow({
    required this.icon,
    required this.label,
    required this.nickname,
    required this.color,
    this.suffix = '',
  });

  final IconData icon;
  final String label;
  final String nickname;
  final Color color;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label: $nickname$suffix',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProcessedSummary extends StatelessWidget {
  const _ProcessedSummary({required this.report});

  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (report.contentWasHidden) '콘텐츠 숨김',
    ];

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
            style: TextStyle(
              color: context.colors.textMuted,
              fontSize: 12,
            ),
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
        ? (
    '미처리',
    context.colors.warning,
    context.colors.warningSoft,
    )
        : report.isApproved
        ? (
    '승인',
    context.colors.correct,
    context.colors.correctSoft,
    )
        : (
    '반려',
    context.colors.textSecondary,
    context.colors.surfaceMuted,
    );

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
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? context.colors.lavender,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:
          foregroundColor ?? context.colors.lavenderAccent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReportMessage extends StatelessWidget {
  const _ReportMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 46,
            color: context.colors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime? date) {
  if (date == null) return '날짜 없음';

  return '${date.year}.${_twoDigits(date.month)}.'
      '${_twoDigits(date.day)} '
      '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
}

String _targetTypeLabel(String type) {
  return switch (type.toUpperCase()) {
    'POST' => '게시글',
    'COMMENT' => '댓글',
    'STUDY_MEMBER' => '스터디원',
    'STUDY_GROUP' => '스터디',
    _ => '기타',
  };
}

String _reasonLabel(String reason) {
  return switch (reason.toUpperCase()) {
    'SPAM' => '스팸/홍보',
    'ABUSE' => '욕설/괴롭힘',
    'INAPPROPRIATE' => '부적절한 콘텐츠',
    'FALSE_INFORMATION' => '거짓 정보',
    'FRAUD' => '사기/허위 정보',
    'COPYRIGHT' => '저작권 침해',
    'ETC' => '기타',
    _ => '기타',
  };
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}