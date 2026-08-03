import 'package:flutter/material.dart';
import '../theme.dart';

class MonthNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const MonthNavButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? context.colors.lavender : context.colors.surfaceMuted,
      shape: CircleBorder(),
      child: InkWell(
        customBorder: CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? context.colors.lavenderAccent
                : context.colors.textDisabled,
          ),
        ),
      ),
    );
  }
}

/// 파스텔 톤 커스텀 날짜 선택 바텀시트
class AppDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;

  const AppDatePickerSheet({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
  });

  static Future<DateTime?> show(
      BuildContext context, {
        required DateTime initialDate,
        required DateTime firstDate,
        required DateTime lastDate,
        required String title,
      }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppDatePickerSheet(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        title: title,
      ),
    );
  }

  @override
  State<AppDatePickerSheet> createState() => _AppDatePickerSheetState();
}

class _AppDatePickerSheetState extends State<AppDatePickerSheet> {
  static const List<String> _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  late DateTime _displayedMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayedMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isSelectable(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final first = DateTime(
        widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    final last =
    DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    return !d.isBefore(first) && !d.isAfter(last);
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + delta);
    });
  }

  bool get _canGoPrev {
    final prevMonthLastDay =
    DateTime(_displayedMonth.year, _displayedMonth.month, 0);
    return !prevMonthLastDay
        .isBefore(DateTime(widget.firstDate.year, widget.firstDate.month, 1));
  }

  bool get _canGoNext {
    final nextMonthFirstDay =
    DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    return !nextMonthFirstDay.isAfter(DateTime(
        widget.lastDate.year, widget.lastDate.month, widget.lastDate.day));
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday % 7;
    final daysInMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 22, 24, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.title,
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_displayedMonth.year}년 ${_displayedMonth.month}월',
                    style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                Row(
                  children: [
                    MonthNavButton(
                      icon: Icons.chevron_left_rounded,
                      enabled: _canGoPrev,
                      onTap: () => _changeMonth(-1),
                    ),
                    SizedBox(width: 6),
                    MonthNavButton(
                      icon: Icons.chevron_right_rounded,
                      enabled: _canGoNext,
                      onTap: () => _changeMonth(1),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: _weekdays.map((w) {
                return Expanded(
                  child: Center(
                    child: Text(w,
                        style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: firstWeekday + daysInMonth,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
              itemBuilder: (context, index) {
                if (index < firstWeekday) return SizedBox.shrink();
                final day = index - firstWeekday + 1;
                final date =
                DateTime(_displayedMonth.year, _displayedMonth.month, day);
                final selectable = _isSelectable(date);
                final isSelected =
                    _selectedDate != null && _isSameDay(_selectedDate!, date);
                final isToday = _isSameDay(date, DateTime.now());

                return GestureDetector(
                  onTap: selectable
                      ? () => setState(() => _selectedDate = date)
                      : null,
                  child: Container(
                    margin: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.colors.lavenderAccent
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: (isToday && !isSelected)
                          ? Border.all(
                          color: context.colors.lavenderAccent, width: 1.4)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: !selectable
                            ? context.colors.textDisabled
                            : isSelected
                            ? context.colors.onPrimary
                            : context.colors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _selectedDate == null
                    ? null
                    : () => Navigator.pop(context, _selectedDate),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.lavenderAccent,
                  foregroundColor: context.colors.onPrimary,
                  disabledBackgroundColor: context.colors.border,
                  elevation: 0,
                  shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text('선택 완료',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 파스텔 톤 커스텀 시간 선택 바텀시트 (휠 피커)
class AppTimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  final String title;

  const AppTimePickerSheet({
    super.key,
    required this.initialTime,
    required this.title,
  });

  static Future<TimeOfDay?> show(
      BuildContext context, {
        required TimeOfDay initialTime,
        required String title,
      }) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AppTimePickerSheet(initialTime: initialTime, title: title),
    );
  }

  @override
  State<AppTimePickerSheet> createState() => _AppTimePickerSheetState();
}

class _AppTimePickerSheetState extends State<AppTimePickerSheet> {
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = (widget.initialTime.minute / 5).round() * 5 % 60;
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController =
        FixedExtentScrollController(initialItem: _selectedMinute ~/ 5);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int) labelBuilder,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 88,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.lavender,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 44,
            diameterRatio: 1.6,
            physics: FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: itemCount,
              builder: (context, index) {
                return Center(
                  child: Text(labelBuilder(index),
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 22, 24, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.title,
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildWheel(
                  controller: _hourController,
                  itemCount: 24,
                  labelBuilder: (i) => _pad(i),
                  onChanged: (i) => setState(() => _selectedHour = i),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(':',
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                ),
                _buildWheel(
                  controller: _minuteController,
                  itemCount: 12,
                  labelBuilder: (i) => _pad(i * 5),
                  onChanged: (i) => setState(() => _selectedMinute = i * 5),
                ),
              ],
            ),
            SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.lavenderAccent,
                  foregroundColor: context.colors.onPrimary,
                  elevation: 0,
                  shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text('선택 완료',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}