import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../models/notice_models.dart';
import '../services/notice_service.dart';
import '../widgets/notice_date_filter_sheet.dart';
import 'notice_detail_screen.dart';

class NoticeListScreen extends StatefulWidget {
  const NoticeListScreen({super.key});

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  final NoticeService _noticeService = NoticeService();
  final TextEditingController _searchController = TextEditingController();

  late Stream<List<NoticeItem>> _noticesStream;

  NoticeType? _selectedType;
  String _searchQuery = '';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _noticesStream = _noticeService.watchNotices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retryLoadNotices() {
    setState(() {
      _noticesStream = _noticeService.watchNotices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(title: '공지사항'),
      body: AppMainBackground(
        child: SafeArea(
          child: StreamBuilder<List<NoticeItem>>(
            stream: _noticesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorView();
              }

              final bool loading =
                  snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;

              if (loading) {
                return Center(
                  child: CircularProgressIndicator(
                    color: context.colors.pinkStart,
                  ),
                );
              }

              final List<NoticeItem> allNotices = snapshot.data ?? [];
              final List<NoticeItem> notices = _applyFilters(allNotices);

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _buildSearchField(),
                  ),
                  SizedBox(height: 10),
                  _buildFilterRow(),
                  SizedBox(height: 12),
                  Expanded(
                    child: notices.isEmpty
                        ? _buildEmptyView(hasAnyNotice: allNotices.isNotEmpty)
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, 40),
                            itemCount: notices.length,
                            separatorBuilder: (_, __) => SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _buildCard(notices, index);
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.colors.incorrectSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 38,
                color: context.colors.incorrect,
              ),
            ),
            SizedBox(height: 18),
            Text(
              '공지사항을 불러오지 못했습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '인터넷 연결을 확인한 후 다시 시도해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _retryLoadNotices,
              icon: Icon(Icons.refresh_rounded),
              label: Text('다시 시도'),
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.pinkStart,
                foregroundColor: context.colors.onPrimary,
                padding: EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView({required bool hasAnyNotice}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAnyNotice ? Icons.search_off_rounded : Icons.campaign_outlined,
              size: 42,
              color: context.colors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              hasAnyNotice ? '조건에 맞는 공지사항이 없습니다.' : '등록된 공지사항이 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.colors.textSecondary,
              ),
            ),
            if (hasAnyNotice) ...[
              SizedBox(height: 14),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: Icon(Icons.refresh_rounded, size: 18),
                label: Text('검색 조건 초기화'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _selectedType = null;
      _dateRange = null;
    });
  }

  List<NoticeItem> _applyFilters(List<NoticeItem> notices) {
    final String query = _searchQuery.trim().toLowerCase();
    final DateTimeRange? range = _dateRange;

    return notices.where((notice) {
      final bool typeMatches =
          _selectedType == null || notice.noticeType == _selectedType;

      final bool queryMatches =
          query.isEmpty ||
          notice.title.toLowerCase().contains(query) ||
          notice.content.toLowerCase().contains(query);

      final DateTime noticeDate = notice.publishedAt ?? notice.createdAt;

      final bool dateMatches =
          range == null ||
          (!noticeDate.isBefore(range.start) &&
              noticeDate.isBefore(range.end.add(Duration(days: 1))));

      return typeMatches && queryMatches && dateMatches;
    }).toList();
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
        decoration: InputDecoration(
          hintText: '제목, 내용으로 검색',
          hintStyle: TextStyle(fontSize: 13.5, color: context.colors.textMuted),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: context.colors.textSecondary,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: context.colors.textSecondary,
                  ),
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchQuery = '';
                    });
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    final Map<NoticeType?, String> options = {
      null: '전체',
      NoticeType.app: '일반',
      NoticeType.exam: '시험·접수',
      NoticeType.update: '업데이트',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          ...options.entries.map((entry) {
            final bool isSelected = _selectedType == entry.key;

            final Color selectedColor = entry.key == null
                ? context.colors.pinkStart
                : entry.key!.badgeFg(context);

            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedType = entry.key;
                  });
                },
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : context.colors.textSecondary,
                ),
                selectedColor: selectedColor,
                backgroundColor: context.colors.surfaceMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide.none,
                showCheckmark: false,
              ),
            );
          }),
          _buildDateFilterChip(),
        ],
      ),
    );
  }

  Widget _buildDateFilterChip() {
    final DateTimeRange? range = _dateRange;
    final bool active = range != null;

    final String label = active
        ? '${_formatShort(range.start)}~${_formatShort(range.end)}'
        : '날짜 필터';

    return InputChip(
      avatar: Icon(
        Icons.calendar_today_rounded,
        size: 14,
        color: active ? Colors.white : context.colors.textSecondary,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: active ? Colors.white : context.colors.textSecondary,
      ),
      backgroundColor: active ? Color(0xFF5CBE93) : context.colors.surfaceMuted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      onPressed: _openDateFilterSheet,
      onDeleted: active
          ? () {
              setState(() {
                _dateRange = null;
              });
            }
          : null,
      deleteIcon: active
          ? Icon(Icons.close_rounded, size: 15, color: Colors.white)
          : null,
    );
  }

  Future<void> _openDateFilterSheet() async {
    final Object? result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return NoticeDateFilterSheet(initialRange: _dateRange);
      },
    );

    if (!mounted) return;

    if (result == noticeDateFilterCleared) {
      setState(() {
        _dateRange = null;
      });
      return;
    }

    if (result is DateTimeRange) {
      setState(() {
        _dateRange = result;
      });
    }
  }

  Widget _buildCard(List<NoticeItem> notices, int index) {
    final NoticeItem notice = notices[index];

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) {
                return NoticeDetailScreen(notices: notices, index: index);
              },
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (notice.isPinned) ...[
                          Icon(
                            Icons.push_pin_rounded,
                            size: 13,
                            color: context.colors.pinkStart,
                          ),
                          SizedBox(width: 4),
                        ],
                        _buildTypeChip(notice),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      notice.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      notice.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _formatRelative(notice.publishedAt ?? notice.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 26),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(NoticeItem notice) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: notice.noticeType.badgeBg(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        notice.noticeType.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: notice.noticeType.badgeFg(context),
        ),
      ),
    );
  }

  String _formatRelative(DateTime date) {
    final Duration difference = DateTime.now().difference(date);

    // 서버 시간 차이로 미래 시각이 들어온 경우 음수 표시를 방지합니다.
    if (difference.isNegative || difference.inMinutes < 1) {
      return '방금 전';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    }

    if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}주 전';
    }

    if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}개월 전';
    }

    return '${(difference.inDays / 365).floor()}년 전';
  }

  String _formatShort(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '$month.$day';
  }
}
