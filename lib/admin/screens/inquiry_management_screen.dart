import 'package:flutter/material.dart';

import '../../theme.dart';
import '../services/admin_inquiry_service.dart';

class InquiryManagementScreen extends StatefulWidget {
  const InquiryManagementScreen({super.key});

  @override
  State<InquiryManagementScreen> createState() =>
      _InquiryManagementScreenState();
}

class _InquiryManagementScreenState extends State<InquiryManagementScreen> {
  final AdminInquiryService _service = AdminInquiryService();
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<AdminInquiry>> _inquiries;
  _InquiryFilter _filter = _InquiryFilter.pending;

  @override
  void initState() {
    super.initState();
    _inquiries = _service.watchInquiries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminInquiry>>(
      stream: _inquiries,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _InquiryMessageView(
            icon: Icons.error_outline_rounded,
            message: '문의 내역을 불러오지 못했습니다.',
            detail: _errorMessage(snapshot.error),
          );
        }
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: context.colors.lavenderAccent,
            ),
          );
        }

        final allInquiries = snapshot.data!;
        final visibleInquiries = _applyFilters(allInquiries);
        final pendingCount = allInquiries
            .where((inquiry) => !inquiry.isAnswered)
            .length;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
            children: [
              _InquiryHeader(
                totalCount: allInquiries.length,
                pendingCount: pendingCount,
                searchController: _searchController,
                selectedFilter: _filter,
                onSearchChanged: (_) => setState(() {}),
                onFilterChanged: (filter) => setState(() => _filter = filter),
              ),
              const SizedBox(height: 18),
              if (visibleInquiries.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: _InquiryMessageView(
                    icon: Icons.mark_email_read_outlined,
                    message: _searchController.text.trim().isEmpty
                        ? '표시할 문의가 없습니다.'
                        : '검색 조건에 맞는 문의가 없습니다.',
                  ),
                )
              else
                ...visibleInquiries.map(
                  (inquiry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InquiryCard(
                      inquiry: inquiry,
                      onTap: () => _showInquirySheet(inquiry),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<AdminInquiry> _applyFilters(List<AdminInquiry> inquiries) {
    final query = _searchController.text.trim().toLowerCase();
    return inquiries.where((inquiry) {
      final matchesFilter = switch (_filter) {
        _InquiryFilter.all => true,
        _InquiryFilter.pending => !inquiry.isAnswered,
        _InquiryFilter.answered => inquiry.isAnswered,
      };
      if (!matchesFilter || query.isEmpty) return matchesFilter;

      return inquiry.title.toLowerCase().contains(query) ||
          inquiry.content.toLowerCase().contains(query) ||
          inquiry.category.toLowerCase().contains(query) ||
          inquiry.userNickname.toLowerCase().contains(query) ||
          inquiry.userEmail.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _showInquirySheet(AdminInquiry inquiry) async {
    final answerController = TextEditingController(text: inquiry.answer ?? '');
    var isSaving = false;
    String? errorMessage;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.surfaceElevated,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> saveAnswer() async {
            if (isSaving) return;
            final answer = answerController.text.trim();
            if (answer.isEmpty) {
              setSheetState(() => errorMessage = '답변 내용을 입력해 주세요.');
              return;
            }

            setSheetState(() {
              isSaving = true;
              errorMessage = null;
            });
            try {
              await _service.saveAnswer(inquiry: inquiry, answer: answer);
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop(true);
            } catch (error) {
              if (!sheetContext.mounted) return;
              setSheetState(() {
                isSaving = false;
                errorMessage = error is ArgumentError
                    ? error.message?.toString()
                    : '답변 저장에 실패했습니다. 잠시 후 다시 시도해 주세요.';
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            inquiry.isAnswered ? '문의 답변 수정' : '문의 답변',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _StatusBadge(answered: inquiry.isAnswered),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _InquiryDetailSection(inquiry: inquiry),
                    const SizedBox(height: 20),
                    Text(
                      '답변',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: answerController,
                      enabled: !isSaving,
                      minLines: 5,
                      maxLines: 9,
                      maxLength: 2000,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: '사용자에게 전달할 답변을 입력해 주세요.',
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          color: context.colors.incorrect,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: isSaving ? null : saveAnswer,
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 19),
                      label: Text(
                        isSaving
                            ? '저장 중...'
                            : inquiry.isAnswered
                            ? '답변 수정'
                            : '답변 등록',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.lavenderAccent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    answerController.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inquiry.isAnswered ? '답변을 수정했습니다.' : '답변을 등록했습니다.'),
        ),
      );
    }
  }

  static String _errorMessage(Object? error) {
    final message = error?.toString() ?? '';
    if (message.contains('permission-denied')) {
      return 'Firestore에서 관리자의 문의 조회 권한을 확인해 주세요.';
    }
    if (message.contains('failed-precondition')) {
      return 'Firestore가 안내하는 컬렉션 그룹 인덱스를 추가해 주세요.';
    }
    return '네트워크 상태와 Firestore 설정을 확인해 주세요.';
  }
}

enum _InquiryFilter { all, pending, answered }

class _InquiryHeader extends StatelessWidget {
  const _InquiryHeader({
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
  final _InquiryFilter selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_InquiryFilter> onFilterChanged;

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
            '문의 내역',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '전체 $totalCount건 · 답변 대기 $pendingCount건',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: '제목, 내용, 회원명 또는 이메일 검색',
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
            children: _InquiryFilter.values.map((filter) {
              return FilterChip(
                selected: selectedFilter == filter,
                label: Text(_filterLabel(filter)),
                onSelected: (_) => onFilterChanged(filter),
                selectedColor: context.colors.lavender,
                checkmarkColor: context.colors.lavenderAccent,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static String _filterLabel(_InquiryFilter filter) => switch (filter) {
    _InquiryFilter.all => '전체',
    _InquiryFilter.pending => '답변 대기',
    _InquiryFilter.answered => '답변 완료',
  };
}

class _InquiryCard extends StatelessWidget {
  const _InquiryCard({required this.inquiry, required this.onTap});

  final AdminInquiry inquiry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surfaceTransparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusBadge(answered: inquiry.isAnswered),
                  const SizedBox(width: 8),
                  _CategoryBadge(label: inquiry.category),
                  const Spacer(),
                  Text(
                    _formatDate(inquiry.createdAt),
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                inquiry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                inquiry.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 17,
                    color: context.colors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${inquiry.userNickname} · ${inquiry.userEmail}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.iconSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InquiryDetailSection extends StatelessWidget {
  const _InquiryDetailSection({required this.inquiry});

  final AdminInquiry inquiry;

  @override
  Widget build(BuildContext context) {
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
            '${inquiry.userNickname} · ${inquiry.userEmail}',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${inquiry.category} · ${_formatDateTime(inquiry.createdAt)}',
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          SelectableText(
            inquiry.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          SelectableText(
            inquiry.content,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.answered});

  final bool answered;

  @override
  Widget build(BuildContext context) {
    final foreground = answered
        ? context.colors.correct
        : context.colors.warning;
    final background = answered
        ? context.colors.correctSoft
        : context.colors.warningSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        answered ? '답변 완료' : '답변 대기',
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: context.colors.lavender,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.colors.lavenderAccent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InquiryMessageView extends StatelessWidget {
  const _InquiryMessageView({
    required this.icon,
    required this.message,
    this.detail,
  });

  final IconData icon;
  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: context.colors.textMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 7),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return '날짜 없음';
  return '${date.year}.${_twoDigits(date.month)}.${_twoDigits(date.day)}';
}

String _formatDateTime(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return '날짜 없음';
  return '${_formatDate(date)} ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
