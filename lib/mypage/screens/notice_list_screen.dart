import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../models/notice_models.dart';
import '../services/notice_service.dart';
import 'notice_detail_screen.dart';
import '../widgets/notice_date_filter_sheet.dart';

class NoticeListScreen extends StatefulWidget {
  const NoticeListScreen({super.key});

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  final NoticeService _noticeService = NoticeService();
  late final Stream<List<NoticeItem>> _noticesStream =
  _noticeService.watchNotices();

  NoticeType? _selectedType;
  String _searchQuery = '';
  DateTimeRange? _dateRange;

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
              final allNotices = snapshot.data ?? [];
              final loading =
                  snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
              final notices = _applyFilters(allNotices);

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _buildSearchField(),
                  ),
                  SizedBox(height: 10),
                  _buildFilterRow(context),
                  SizedBox(height: 12),
                  Expanded(
                    child: loading
                        ? Center(child: CircularProgressIndicator(color: context.colors.pinkStart))
                        : notices.isEmpty
                        ? Center(
                      child: Text(
                        allNotices.isEmpty ? '등록된 공지사항이 없습니다.' : '조건에 맞는 공지사항이 없습니다.',
                        style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
                      ),
                    )
                        : ListView.separated(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 40),
                      itemCount: notices.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10),
                      itemBuilder: (context, index) => _buildCard(notices, index),
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

  List<NoticeItem> _applyFilters(List<NoticeItem> notices) {
    return notices.where((n) {
      final typeMatch = _selectedType == null || n.noticeType == _selectedType;

      final query = _searchQuery.trim().toLowerCase();
      final queryMatch = query.isEmpty ||
          n.title.toLowerCase().contains(query) ||
          n.content.toLowerCase().contains(query);

      final date = n.publishedAt ?? n.createdAt;
      final range = _dateRange;
      final dateMatch = range == null ||
          (!date.isBefore(range.start) &&
              date.isBefore(range.end.add(const Duration(days: 1))));

      return typeMatch && queryMatch && dateMatch;
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
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
        decoration: InputDecoration(
          hintText: '제목, 내용으로 검색',
          hintStyle: TextStyle(fontSize: 13.5, color: context.colors.textMuted),
          prefixIcon: Icon(Icons.search_rounded, color: context.colors.textSecondary),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: context.colors.textSecondary),
            onPressed: () => setState(() => _searchQuery = ''),
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

  Widget _buildFilterRow(BuildContext context) {
    final options = <NoticeType?, String>{
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
            final isSelected = _selectedType == entry.key;
            final selectedColor = entry.key == null ? context.colors.pinkStart : entry.key!.badgeFg(context);
            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedType = entry.key),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : context.colors.textSecondary,
                ),
                selectedColor: selectedColor,
                backgroundColor: context.colors.surfaceMuted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    final range = _dateRange;
    final active = range != null;
    final label = active ? '${_formatShort(range.start)}~${_formatShort(range.end)}' : '날짜 필터';

    return InputChip(
      avatar: Icon(Icons.calendar_today_rounded, size: 14, color: active ? Colors.white : context.colors.textSecondary),
      label: Text(label),
      labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? Colors.white : context.colors.textSecondary),
      backgroundColor: active ? const Color(0xFF5CBE93) : context.colors.surfaceMuted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      onPressed: _openDateFilterSheet,
      onDeleted: active ? () => setState(() => _dateRange = null) : null,
      deleteIcon: active ? Icon(Icons.close_rounded, size: 15, color: Colors.white) : null,
    );
  }

  Future<void> _openDateFilterSheet() async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoticeDateFilterSheet(initialRange: _dateRange),
    );

    if (result == noticeDateFilterCleared) {
      setState(() => _dateRange = null);
    } else if (result is DateTimeRange) {
      setState(() => _dateRange = result);
    }
  }

  Widget _buildCard(List<NoticeItem> notices, int index) {
    final notice = notices[index];
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NoticeDetailScreen(notices: notices, index: index),
          ),
        ),
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
                          Icon(Icons.push_pin_rounded, size: 13, color: context.colors.pinkStart),
                          SizedBox(width: 4),
                        ],
                        _chip(notice.noticeType.label, bg: notice.noticeType.badgeBg(context), fg: notice.noticeType.badgeFg(context)),
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
                      style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 26),
                child: Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, {Color? bg, Color? fg}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? context.colors.pinkSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg ?? context.colors.pinkStart),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '${dateTime.year}.$month.$day';
  }

  String _formatRelative(DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}주 전';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}개월 전';
    return '${(diff.inDays / 365).floor()}년 전';
  }

  String _formatShort(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$month.$day';
  }
}

class _PastelDots extends StatelessWidget {
  const _PastelDots();

  static const _pink = Color(0xFFFBD4E1);
  static const _lavender = Color(0xFFE3D6FA);
  static const _mint = Color(0xFFD4F3E6);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: -60, left: -50, child: _blob(180, _pink)),
          Positioned(top: 30, right: -70, child: _blob(150, _lavender)),
          Positioned(top: 260, left: -45, child: _blob(110, _mint)),
          Positioned(bottom: 140, right: -55, child: _blob(140, _pink)),
          Positioned(bottom: -50, left: 50, child: _blob(120, _lavender)),
          Positioned(top: 140, right: 36, child: _sparkle(_pink)),
          Positioned(bottom: 240, left: 28, child: _sparkle(_mint)),
          Positioned(top: 420, right: 90, child: _sparkle(_lavender)),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.32)),
    );
  }

  Widget _sparkle(Color color) {
    return Icon(Icons.auto_awesome_rounded, size: 16, color: color.withOpacity(0.7));
  }
}