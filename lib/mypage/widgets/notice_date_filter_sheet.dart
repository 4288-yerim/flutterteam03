import 'package:flutter/material.dart';

import '../../theme.dart';

const Object noticeDateFilterCleared = Object();

class NoticeDateFilterSheet extends StatefulWidget {
  final DateTimeRange? initialRange;

  const NoticeDateFilterSheet({super.key, this.initialRange});

  static Color pink(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFF4A2E3B) : const Color(0xFFFBD4E1);
  static Color pinkDeep(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFFFFA6C4) : const Color(0xFFEC6A9C);
  static Color lavender(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFF3A3350) : const Color(0xFFE3D6FA);
  static Color lavenderDeep(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFFC3AEFB) : const Color(0xFFA98CF0);
  static Color mint(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFF25433A) : const Color(0xFFD4F3E6);
  static Color mintDeep(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFF80E0B0) : const Color(0xFF5CBE93);

  @override
  State<NoticeDateFilterSheet> createState() => _NoticeDateFilterSheetState();
}

class _NoticeDateFilterSheetState extends State<NoticeDateFilterSheet> {
  late DateTime _visibleMonth;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRange;
    _rangeStart = initial?.start;
    _rangeEnd = initial?.end;
    final base = initial?.start ?? DateTime.now();
    _visibleMonth = DateTime(base.year, base.month);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 12, 4),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 18, color: NoticeDateFilterSheet.lavenderDeep(context)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '날짜로 찾아보기',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPresets(),
                  SizedBox(height: 18),
                  _buildMonthHeader(),
                  SizedBox(height: 10),
                  _buildWeekdayRow(),
                  SizedBox(height: 4),
                  _buildCalendarGrid(),
                  SizedBox(height: 6),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: _buildFooter(),
          ),
        ],
      ),
    );
  }

  Widget _buildPresets() {
    final presets = <String, DateTimeRange? Function()>{
      '전체': () => null,
      '최근 7일': () => DateTimeRange(start: _daysAgo(6), end: _today()),
      '최근 30일': () => DateTimeRange(start: _daysAgo(29), end: _today()),
      '이번 달': () => DateTimeRange(start: DateTime(_today().year, _today().month, 1), end: _today()),
    };
    final colors = [
      context.colors.surfaceMuted,
      NoticeDateFilterSheet.pink(context),
      NoticeDateFilterSheet.lavender(context),
      NoticeDateFilterSheet.mint(context),
    ];

    final entries = presets.entries.toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(entries.length, (i) {
        final label = entries[i].key;
        final rangeFn = entries[i].value;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (label == '전체') {
              Navigator.pop(context, noticeDateFilterCleared);
              return;
            }
            final r = rangeFn();
            setState(() {
              _rangeStart = r?.start;
              _rangeEnd = r?.end;
              if (r != null) _visibleMonth = DateTime(r.end.year, r.end.month);
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: colors[i % colors.length],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
          icon: Icon(Icons.chevron_left_rounded, color: context.colors.textSecondary),
        ),
        Expanded(
          child: Center(
            child: Text(
              '${_visibleMonth.year}년 ${_visibleMonth.month}월',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
            ),
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
          icon: Icon(Icons.chevron_right_rounded, color: context.colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildWeekdayRow() {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      children: labels
          .map((l) => Expanded(
        child: Center(
          child: Text(l, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.colors.textMuted)),
        ),
      ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7;

    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++) const SizedBox(),
      for (var day = 1; day <= daysInMonth; day++) _buildDayCell(DateTime(_visibleMonth.year, _visibleMonth.month, day)),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 2,
      children: cells,
    );
  }

  Widget _buildDayCell(DateTime date) {
    final isToday = _isSameDay(date, _today());
    final isFuture = date.isAfter(_today());
    final isStart = _rangeStart != null && _isSameDay(date, _rangeStart!);
    final isEnd = _rangeEnd != null && _isSameDay(date, _rangeEnd!);
    final inRange = _rangeStart != null && _rangeEnd != null && date.isAfter(_rangeStart!) && date.isBefore(_rangeEnd!);
    final lavenderDeep = NoticeDateFilterSheet.lavenderDeep(context);
    final lavender = NoticeDateFilterSheet.lavender(context);
    final pinkDeep = NoticeDateFilterSheet.pinkDeep(context);

    return GestureDetector(
      onTap: isFuture ? null : () => _onDayTap(date),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: (isStart || isEnd)
              ? lavenderDeep
              : inRange
              ? lavender.withOpacity(0.55)
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isStart ? const Radius.circular(18) : Radius.zero,
            right: isEnd ? const Radius.circular(18) : Radius.zero,
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: (isToday && !isStart && !isEnd) ? Border.all(color: pinkDeep, width: 1.4) : null,
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: (isStart || isEnd) ? FontWeight.w800 : FontWeight.w500,
              color: isFuture
                  ? context.colors.textMuted.withOpacity(0.4)
                  : (isStart || isEnd)
                  ? Colors.white
                  : context.colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
  void _onDayTap(DateTime date) {
    setState(() {
      if (_rangeStart == null || (_rangeStart != null && _rangeEnd != null)) {
        _rangeStart = date;
        _rangeEnd = null;
      } else if (date.isBefore(_rangeStart!)) {
        _rangeStart = date;
      } else {
        _rangeEnd = date;
      }
    });
  }

  Widget _buildFooter() {
    final hasStart = _rangeStart != null;
    final hasEnd = _rangeEnd != null;
    final label = !hasStart
        ? '시작일을 선택해주세요'
        : !hasEnd
        ? '종료일을 선택해주세요'
        : '${_fmt(_rangeStart!)} ~ ${_fmt(_rangeEnd!)}';

    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
        ),
        SizedBox(width: 12),
        ElevatedButton(
          onPressed: (hasStart && hasEnd)
              ? () => Navigator.pop(context, DateTimeRange(start: _rangeStart!, end: _rangeEnd!))
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: NoticeDateFilterSheet.lavenderDeep(context),
            disabledBackgroundColor: context.colors.surfaceMuted,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text('적용하기', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
        ),
      ],
    );
  }

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime _daysAgo(int days) => _today().subtract(Duration(days: days));

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmt(DateTime d) => '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}