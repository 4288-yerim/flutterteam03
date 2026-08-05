import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/app_dropdown.dart';
import '../services/admin_notice_service.dart';

class NoticeManagementScreen extends StatefulWidget {
  const NoticeManagementScreen({super.key});

  @override
  State<NoticeManagementScreen> createState() => _NoticeManagementScreenState();
}

class _NoticeManagementScreenState extends State<NoticeManagementScreen> {
  final AdminNoticeService _service = AdminNoticeService();
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<AdminNotice>> _notices = _service.watchNotices();
  _NoticeFilter _filter = _NoticeFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNoticeEditor(),
        backgroundColor: context.colors.lavenderAccent,
        foregroundColor: context.colors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('공지 작성'),
      ),
      body: StreamBuilder<List<AdminNotice>>(
        stream: _notices,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageView(
              icon: Icons.error_outline_rounded,
              title: '공지 목록을 불러오지 못했습니다.',
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

          final allNotices = snapshot.data!;
          final visibleNotices = _applyFilter(allNotices);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
            children: [
              _NoticeHeader(
                totalCount: allNotices.length,
                publishedCount: allNotices
                    .where((notice) => notice.status == 'PUBLISHED')
                    .length,
                searchController: _searchController,
                selectedFilter: _filter,
                onSearchChanged: (_) => setState(() {}),
                onFilterChanged: (filter) => setState(() => _filter = filter),
              ),
              const SizedBox(height: 18),
              if (visibleNotices.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: _MessageView(
                    icon: Icons.campaign_outlined,
                    title: '표시할 공지가 없습니다.',
                  ),
                )
              else
                ...visibleNotices.map(
                  (notice) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _NoticeCard(
                      notice: notice,
                      onEdit: () => _openNoticeEditor(notice),
                      onPublish: notice.canPublish
                          ? () => _confirmPublish(notice)
                          : null,
                      onEnd: notice.canEnd ? () => _confirmEnd(notice) : null,
                      onDelete: () => _confirmDelete(notice),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<AdminNotice> _applyFilter(List<AdminNotice> notices) {
    final query = _searchController.text.trim().toLowerCase();
    final result = notices.where((notice) {
      final matchesStatus =
          _filter == _NoticeFilter.all ||
          notice.status == _filter.name.toUpperCase();
      final matchesQuery =
          query.isEmpty ||
          notice.title.toLowerCase().contains(query) ||
          notice.content.toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();

    result.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final first = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final second = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return second.compareTo(first);
    });
    return result;
  }

  Future<void> _openNoticeEditor([AdminNotice? notice]) async {
    var noticeType = notice?.noticeType ?? 'APP';
    var targetType = notice?.targetType ?? 'ALL';
    var status = notice?.status == 'ENDED'
        ? 'DRAFT'
        : notice?.status ?? 'DRAFT';
    var isPinned = notice?.isPinned ?? false;
    DateTime? scheduledAt = status == 'SCHEDULED' ? notice?.publishedAt : null;
    var isSaving = false;
    String? errorMessage;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.surfaceElevated,
      builder: (sheetContext) => _NoticeEditorControllerScope(
        initialTitle: notice?.title ?? '',
        initialContent: notice?.content ?? '',
        initialTargetUids: notice?.targetUids.join(', ') ?? '',
        builder:
            (
              context,
              titleController,
              contentController,
              targetUidsController,
            ) => StatefulBuilder(
              builder: (context, setSheetState) {
                Future<void> pickSchedule() async {
                  final now = DateTime.now();
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: scheduledAt?.isAfter(now) == true
                        ? scheduledAt!
                        : now.add(const Duration(days: 1)),
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (selectedDate == null || !context.mounted) return;
                  final selectedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(
                      scheduledAt ?? now.add(const Duration(hours: 1)),
                    ),
                  );
                  if (selectedTime == null) return;
                  setSheetState(() {
                    scheduledAt = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                  });
                }

                Future<void> save() async {
                  if (isSaving) return;
                  setSheetState(() {
                    isSaving = true;
                    errorMessage = null;
                  });
                  try {
                    await _service.saveNotice(
                      noticeId: notice?.id,
                      draft: NoticeDraft(
                        title: titleController.text,
                        content: contentController.text,
                        noticeType: noticeType,
                        targetType: targetType,
                        targetUids: _parseUids(targetUidsController.text),
                        isPinned: isPinned,
                        status: status,
                        publishedAt: status == 'SCHEDULED'
                            ? scheduledAt
                            : status == 'PUBLISHED'
                            ? notice?.publishedAt
                            : null,
                        expiredAt: null,
                      ),
                    );
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop(true);
                    }
                  } catch (error) {
                    if (!sheetContext.mounted) return;
                    setSheetState(() {
                      isSaving = false;
                      errorMessage = error is ArgumentError
                          ? error.message?.toString()
                          : '공지 저장에 실패했습니다. 잠시 후 다시 시도해 주세요.';
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
                          Text(
                            notice == null ? '공지 작성' : '공지 수정',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: titleController,
                            enabled: !isSaving,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: '공지 제목',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: contentController,
                            enabled: !isSaving,
                            minLines: 6,
                            maxLines: 10,
                            maxLength: 5000,
                            decoration: const InputDecoration(
                              labelText: '공지 내용',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: AppAdminDropdown<String>(
                                  label: '공지 종류',
                                  value: noticeType,
                                  enabled: !isSaving,
                                  items: const [
                                    AppDropdownItem(value: 'APP', label: '일반'),
                                    AppDropdownItem(
                                      value: 'EXAM',
                                      label: '시험·접수',
                                    ),
                                    AppDropdownItem(
                                      value: 'UPDATE',
                                      label: '업데이트',
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setSheetState(() => noticeType = value),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AppAdminDropdown<String>(
                                  label: '게시 상태',
                                  value: status,
                                  enabled: !isSaving,
                                  items: const [
                                    AppDropdownItem(
                                      value: 'DRAFT',
                                      label: '작성 중',
                                    ),
                                    AppDropdownItem(
                                      value: 'SCHEDULED',
                                      label: '예약 게시',
                                    ),
                                    AppDropdownItem(
                                      value: 'PUBLISHED',
                                      label: '즉시 게시',
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setSheetState(() => status = value),
                                ),
                              ),
                            ],
                          ),
                          if (status == 'SCHEDULED') ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: isSaving ? null : pickSchedule,
                              icon: const Icon(Icons.schedule_rounded),
                              label: Text(
                                scheduledAt == null
                                    ? '예약 게시 일시 선택'
                                    : _formatDateTime(scheduledAt!),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          AppAdminDropdown<String>(
                            label: '공지 대상',
                            value: targetType,
                            enabled: !isSaving,
                            items: const [
                              AppDropdownItem(value: 'ALL', label: '전체 회원'),
                              AppDropdownItem(
                                value: 'SPECIFIC_USERS',
                                label: '특정 회원',
                              ),
                            ],
                            onChanged: (value) =>
                                setSheetState(() => targetType = value),
                          ),
                          if (targetType == 'SPECIFIC_USERS') ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: targetUidsController,
                              enabled: !isSaving,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: '수신자 UID',
                                hintText: 'UID를 쉼표 또는 줄바꿈으로 구분',
                              ),
                            ),
                          ],
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('상단 고정'),
                            value: isPinned,
                            onChanged: isSaving
                                ? null
                                : (value) =>
                                      setSheetState(() => isPinned = value),
                          ),
                          if (errorMessage != null) ...[
                            Text(
                              errorMessage!,
                              style: TextStyle(
                                color: context.colors.incorrect,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          FilledButton.icon(
                            onPressed: isSaving ? null : save,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(isSaving ? '저장 중...' : '저장'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      ),
    );

    if (saved == true && mounted) _showMessage('공지를 저장했습니다.');
  }

  Future<void> _confirmPublish(AdminNotice notice) async {
    final confirmed = await _confirm(
      title: '공지 게시',
      message: '「${notice.title}」 공지를 지금 게시하시겠습니까?',
      confirmLabel: '게시',
    );
    if (!confirmed) return;
    await _runAction(() => _service.publishNow(notice), '공지를 게시했습니다.');
  }

  Future<void> _confirmEnd(AdminNotice notice) async {
    final confirmed = await _confirm(
      title: '게시 종료',
      message: '「${notice.title}」 공지 게시를 종료하시겠습니까?',
      confirmLabel: '종료',
    );
    if (!confirmed) return;
    await _runAction(() => _service.endNotice(notice), '공지 게시를 종료했습니다.');
  }

  Future<void> _confirmDelete(AdminNotice notice) async {
    final confirmed = await _confirm(
      title: '공지 삭제',
      message: '「${notice.title}」 공지를 삭제하시겠습니까? 삭제 후 복구할 수 없습니다.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!confirmed) return;
    await _runAction(() => _service.deleteNotice(notice), '공지를 삭제했습니다.');
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: context.colors.incorrect,
                      )
                    : null,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (mounted) _showMessage(successMessage);
    } catch (_) {
      if (mounted) _showMessage('처리에 실패했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static List<String> _parseUids(String raw) {
    return raw
        .split(RegExp(r'[,\n]'))
        .map((uid) => uid.trim())
        .where((uid) => uid.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static String _errorMessage(Object? error) {
    final message = error?.toString() ?? '';
    if (message.contains('permission-denied')) {
      return 'Firestore 관리자 권한을 확인해 주세요.';
    }
    if (message.contains('failed-precondition')) {
      return 'Firestore가 안내하는 인덱스를 생성해 주세요.';
    }
    return '네트워크 상태와 Firestore 설정을 확인해 주세요.';
  }
}

class _NoticeEditorControllerScope extends StatefulWidget {
  const _NoticeEditorControllerScope({
    required this.initialTitle,
    required this.initialContent,
    required this.initialTargetUids,
    required this.builder,
  });

  final String initialTitle;
  final String initialContent;
  final String initialTargetUids;
  final Widget Function(
    BuildContext context,
    TextEditingController titleController,
    TextEditingController contentController,
    TextEditingController targetUidsController,
  )
  builder;

  @override
  State<_NoticeEditorControllerScope> createState() =>
      _NoticeEditorControllerScopeState();
}

class _NoticeEditorControllerScopeState
    extends State<_NoticeEditorControllerScope> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _targetUidsController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
    _targetUidsController = TextEditingController(
      text: widget.initialTargetUids,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _targetUidsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _titleController,
      _contentController,
      _targetUidsController,
    );
  }
}

enum _NoticeFilter { all, draft, scheduled, published, ended }

class _NoticeHeader extends StatelessWidget {
  const _NoticeHeader({
    required this.totalCount,
    required this.publishedCount,
    required this.searchController,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final int totalCount;
  final int publishedCount;
  final TextEditingController searchController;
  final _NoticeFilter selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_NoticeFilter> onFilterChanged;

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
            '공지 목록',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '전체 $totalCount건 · 게시 중 $publishedCount건',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: '공지 제목 또는 내용 검색',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _NoticeFilter.values.map((filter) {
              return FilterChip(
                selected: selectedFilter == filter,
                label: Text(_filterLabel(filter)),
                onSelected: (_) => onFilterChanged(filter),
                color: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed) ||
                      states.contains(WidgetState.selected)) {
                    return context.colors.lavender;
                  }
                  return null;
                }),
                selectedColor: context.colors.lavender,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.onEdit,
    required this.onPublish,
    required this.onEnd,
    required this.onDelete,
  });

  final AdminNotice notice;
  final VoidCallback onEdit;
  final VoidCallback? onPublish;
  final VoidCallback? onEnd;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
              if (notice.isPinned) ...[
                Icon(
                  Icons.push_pin_rounded,
                  size: 17,
                  color: context.colors.lavenderAccent,
                ),
                const SizedBox(width: 6),
              ],
              _StatusBadge(status: notice.status),
              const SizedBox(width: 8),
              Text(
                _noticeTypeLabel(notice.noticeType),
                style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'publish':
                      onPublish?.call();
                    case 'end':
                      onEnd?.call();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('수정')),
                  if (onPublish != null)
                    const PopupMenuItem(value: 'publish', child: Text('지금 게시')),
                  if (onEnd != null)
                    const PopupMenuItem(value: 'end', child: Text('게시 종료')),
                  const PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            notice.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            notice.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.colors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 12),
          Text(
            '${_targetLabel(notice)} · ${_noticeDateLabel(notice)}',
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isPublished = status == 'PUBLISHED';
    final color = isPublished
        ? context.colors.correct
        : status == 'ENDED'
        ? context.colors.textMuted
        : context.colors.warning;
    final background = isPublished
        ? context.colors.correctSoft
        : status == 'ENDED'
        ? context.colors.surfaceMuted
        : context.colors.warningSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.title, this.detail});

  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.colors.textMuted),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
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

String _filterLabel(_NoticeFilter filter) => switch (filter) {
  _NoticeFilter.all => '전체',
  _NoticeFilter.draft => '작성 중',
  _NoticeFilter.scheduled => '예약',
  _NoticeFilter.published => '게시 중',
  _NoticeFilter.ended => '종료',
};

String _statusLabel(String status) => switch (status) {
  'SCHEDULED' => '예약 게시',
  'PUBLISHED' => '게시 중',
  'ENDED' => '게시 종료',
  _ => '작성 중',
};

String _noticeTypeLabel(String type) => switch (type) {
  'EXAM' => '시험·접수',
  'UPDATE' => '업데이트',
  _ => '일반',
};

String _targetLabel(AdminNotice notice) {
  return notice.targetType == 'SPECIFIC_USERS'
      ? '특정 회원 ${notice.targetUids.length}명'
      : '전체 회원';
}

String _noticeDateLabel(AdminNotice notice) {
  if (notice.status == 'SCHEDULED' && notice.publishedAt != null) {
    return '예약 ${_formatDateTime(notice.publishedAt!)}';
  }
  if (notice.status == 'PUBLISHED' && notice.publishedAt != null) {
    return '게시 ${_formatDateTime(notice.publishedAt!)}';
  }
  if (notice.status == 'ENDED' && notice.expiredAt != null) {
    return '종료 ${_formatDateTime(notice.expiredAt!)}';
  }
  return notice.createdAt == null
      ? '날짜 없음'
      : '작성 ${_formatDateTime(notice.createdAt!)}';
}

String _formatDateTime(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}.${two(date.month)}.${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}
