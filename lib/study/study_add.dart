import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/loading_overlay.dart';

// ── 공통 스타일 헬퍼 (study_edit.dart 에서도 import해서 사용) ──────
InputDecoration studyFieldDecoration({
  required BuildContext context,
  required String labelText,
  required String hintText,
  required IconData icon,
  String? suffixText,
  bool alignLabelWithHint = false,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    suffixText: suffixText,
    alignLabelWithHint: alignLabelWithHint,
    // 라벨을 항상 위로 띄워서 필드마다 스타일을 통일하고, hintText(예시)가 항상 보이게 함
    floatingLabelBehavior: FloatingLabelBehavior.always,
    filled: true,
    // 카드가 흰색이 되므로, 필드 배경은 카드보다 한 톤 톤다운된 뉴트럴로 — 카드-필드 경계도 또렷해짐
    fillColor: context.colors.background,
    prefixIcon: alignLabelWithHint
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: Icon(icon, color: context.colors.pinkStart, size: 21),
          ),
    labelStyle: TextStyle(
      color: context.colors.pinkStart,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
    ),
    hintStyle: TextStyle(
      color: context.colors.textSecondary.withOpacity(0.55),
      fontSize: 14,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: context.colors.pinkStart, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.error,
        width: 1.2,
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════
// 커스텀 캘린더 (기본 Material DatePicker 대체)
// ════════════════════════════════════════════════════════════

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String helpText = '날짜 선택',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AppCalendarSheet(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
    ),
  );
}

class _AppCalendarSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String helpText;

  const _AppCalendarSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.helpText,
  });

  @override
  State<_AppCalendarSheet> createState() => _AppCalendarSheetState();
}

class _AppCalendarSheetState extends State<_AppCalendarSheet> {
  late DateTime _displayedMonth;
  late DateTime _selectedDate;

  static const List<String> _weekdayLabels = [
    '일',
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayedMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      1,
    );
  }

  bool get _canGoPrev {
    final prevMonthEnd = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      0,
    );
    return !prevMonthEnd.isBefore(widget.firstDate);
  }

  bool get _canGoNext {
    final nextMonthStart = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      1,
    );
    return !nextMonthStart.isAfter(widget.lastDate);
  }

  void _goPrevMonth() {
    if (!_canGoPrev) return;
    setState(
      () => _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
        1,
      ),
    );
  }

  void _goNextMonth() {
    if (!_canGoNext) return;
    setState(
      () => _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        1,
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isSelectable(DateTime day) {
    final first = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
      widget.firstDate.day,
    );
    final last = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
      widget.lastDate.day,
    );
    return !day.isBefore(first) && !day.isAfter(last);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = DateTime.now();

    final firstWeekday = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    ).weekday;
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final leadingBlanks = firstWeekday % 7;
    final rowCount = ((leadingBlanks + daysInMonth) / 7).ceil();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: colors.textSecondary.withOpacity(0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              widget.helpText,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CalendarNavArrow(
                  icon: Icons.chevron_left_rounded,
                  onTap: _canGoPrev ? _goPrevMonth : null,
                ),
                Text(
                  '${_displayedMonth.year}년 ${_displayedMonth.month}월',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                _CalendarNavArrow(
                  icon: Icons.chevron_right_rounded,
                  onTap: _canGoNext ? _goNextMonth : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: _weekdayLabels.map((label) {
                final isWeekend = label == '일' || label == '토';
                return Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isWeekend
                            ? colors.pinkStart.withOpacity(0.8)
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            ...List.generate(rowCount, (rowIndex) {
              return Row(
                children: List.generate(7, (colIndex) {
                  final cellIndex = rowIndex * 7 + colIndex;
                  final dayNumber = cellIndex - leadingBlanks + 1;

                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 44));
                  }

                  final date = DateTime(
                    _displayedMonth.year,
                    _displayedMonth.month,
                    dayNumber,
                  );
                  final selectable = _isSelectable(date);
                  final isSelected = _isSameDay(date, _selectedDate);
                  final isToday = _isSameDay(date, today);

                  return Expanded(
                    child: GestureDetector(
                      onTap: selectable
                          ? () => setState(() => _selectedDate = date)
                          : null,
                      child: Container(
                        height: 44,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? colors.pinkStart
                              : Colors.transparent,
                          border: (isToday && !isSelected)
                              ? Border.all(color: colors.pinkStart, width: 1.4)
                              : null,
                        ),
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: !selectable
                                ? colors.textSecondary.withOpacity(0.28)
                                : isSelected
                                ? colors.onPrimary
                                : colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: Material(
                      color: colors.textSecondary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).pop(),
                        child: Center(
                          child: Text(
                            '취소',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            colors.pinkStart,
                            colors.pinkStart.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).pop(_selectedDate),
                          child: Center(
                            child: Text(
                              '선택 완료',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: colors.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarNavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CalendarNavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.textSecondary.withOpacity(0.08),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? colors.textPrimary
              : colors.textSecondary.withOpacity(0.3),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 공용 위젯
// ── 배경은 뉴트럴, 카드는 순백 + 컬러 그림자/상단 액센트바로
//    경계를 명확히 하고, 토글은 세그먼트 필(pill) 스타일로 트렌디하게 ──
// ════════════════════════════════════════════════════════════

class SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          // 은은한 핑크 앰비언트 섀도우 — 배경과의 경계를 색으로도 분리
          BoxShadow(
            color: colors.pinkStart.withOpacity(0.10),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: colors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 그라데이션 액센트 바 — 카드 시작점을 시각적으로 또렷하게
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.pinkStart, colors.pinkStart.withOpacity(0.25)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colors.pinkStart.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 17, color: colors.pinkStart),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 최대 인원 선택. 자주 쓰는 값은 칩으로 바로 탭, 세부 조정은 슬라이더로.
class MemberCountPicker extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String caption;

  const MemberCountPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.caption,
  });

  static const List<int> _basePresets = [2, 4, 5, 6, 8, 10, 15, 20, 25, 30];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final presets = _basePresets.where((p) => p >= min && p <= max).toList();
    if (!presets.contains(min)) presets.insert(0, min);
    if (!presets.contains(max)) presets.add(max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최대 인원',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.pinkStart, colors.pinkStart.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$value명',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colors.onPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final preset = presets[index];
              final selected = preset == value;
              return GestureDetector(
                onTap: () => onChanged(preset),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? colors.pinkStart : colors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? colors.pinkStart
                          : colors.textSecondary.withOpacity(0.16),
                    ),
                  ),
                  child: Text(
                    '$preset명',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? colors.onPrimary : colors.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colors.pinkStart,
            inactiveTrackColor: colors.textSecondary.withOpacity(0.15),
            thumbColor: colors.pinkStart,
            overlayColor: colors.pinkStart.withOpacity(0.15),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
          ),
          child: Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: (max - min) > 0 ? (max - min) : null,
            label: '$value명',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            caption,
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// 트렌디한 필(pill) 스타일 토글. iOS/Toss류 앱에서 흔히 쓰는 슬라이딩 스위치.
class _PillToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PillToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: value
              ? LinearGradient(
                  colors: [
                    colors.pinkStart,
                    colors.pinkStart.withOpacity(0.75),
                  ],
                )
              : null,
          color: value ? null : colors.textSecondary.withOpacity(0.2),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surface,
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StudySwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const StudySwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 카드 안에 또 박스를 두지 않고, 얇은 구분선을 쓰는 플랫한 리스트 로우 스타일로 변경
    // (중첩 박스가 많으면 "경계가 흐릿하다"는 느낌을 오히려 가중시킴)
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: value
                    ? colors.pinkStart.withOpacity(0.14)
                    : colors.textPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 18,
                color: value
                    ? colors.pinkStart
                    : colors.textPrimary.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _PillToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// 페이지 상단 — 큰 아이콘 배지 대신, 작은 아이콘+eyebrow 라벨과 굵은 타이틀로
/// 미니멀하고 에디토리얼한 트렌디 헤더로 재구성.
class StudyPageHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String eyebrow;

  const StudyPageHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.eyebrow = 'STUDY',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: colors.pinkStart),
            const SizedBox(width: 6),
            Text(
              eyebrow,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: colors.pinkStart,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            height: 1.28,
            letterSpacing: -0.4,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: 13,
            color: colors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// 시험일 선택 타일.
class ExamDateTile extends StatelessWidget {
  final DateTime? examDate;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final String Function(DateTime) formatDate;

  const ExamDateTile({
    super.key,
    required this.examDate,
    required this.onTap,
    required this.onClear,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasDate = examDate != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(
            color: hasDate
                ? colors.pinkStart.withOpacity(0.45)
                : colors.textSecondary.withOpacity(0.18),
            width: hasDate ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasDate
                    ? colors.pinkStart.withOpacity(0.14)
                    : colors.textPrimary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                size: 19,
                color: hasDate
                    ? colors.pinkStart
                    : colors.textPrimary.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '시험일',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasDate ? formatDate(examDate!) : '시험일을 선택해 주세요.',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: hasDate
                          ? colors.textPrimary
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (hasDate)
              IconButton(
                tooltip: '시험일 지우기',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 19),
              )
            else
              Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
// ────────────────────────────────────────────────────────────

class StudyCreatePage extends StatefulWidget {
  const StudyCreatePage({super.key});

  @override
  State<StudyCreatePage> createState() => _StudyCreatePageState();
}

class _StudyCreatePageState extends State<StudyCreatePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _certificateNameController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _weeklyGoalHourController = TextEditingController(
    text: '15',
  );

  DateTime? _examDate;
  int _maxMemberCount = 5;
  bool _isPublic = true;
  bool _joinApprovalRequired = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _certificateNameController.dispose();
    _descriptionController.dispose();
    _weeklyGoalHourController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dateTime) {
    String year = dateTime.year.toString();
    String month = dateTime.month.toString().padLeft(2, '0');
    String day = dateTime.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }

  Future<void> _selectExamDate() async {
    DateTime now = DateTime.now();
    DateTime initialDate = _examDate ?? now.add(const Duration(days: 30));

    DateTime? selectedDate = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: '시험일 선택',
    );

    if (selectedDate == null || !mounted) return;

    setState(() {
      _examDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
    });
  }

  Future<void> _saveStudy() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('로그인 정보가 없습니다.');

      final String ownerNickname = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : '익명 사용자';

      final studyDocument = FirebaseFirestore.instance
          .collection('studyGroups')
          .doc();
      final batch = FirebaseFirestore.instance.batch();

      batch.set(studyDocument, {
        'groupName': _groupNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'ownerUid': user.uid,
        'ownerNickname': ownerNickname,
        'certificateId': '',
        'certificateName': _certificateNameController.text.trim().isEmpty
            ? '공통 스터디'
            : _certificateNameController.text.trim(),
        'examDate': _examDate == null ? null : Timestamp.fromDate(_examDate!),
        'weeklyGoalMinutes':
            (int.tryParse(_weeklyGoalHourController.text.trim()) ?? 15) * 60,
        'maxMemberCount': _maxMemberCount,
        'currentMemberCount': 1,
        'isPublic': _isPublic,
        'joinApprovalRequired': _joinApprovalRequired,
        'inviteCode': '',
        'chatId': '',
        'status': 'RECRUITING',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final ownerMemberDocument = studyDocument
          .collection('members')
          .doc(user.uid);
      batch.set(ownerMemberDocument, {
        'uid': user.uid,
        'nickname': ownerNickname,
        'role': 'OWNER',
        'status': 'ACTIVE',
        'totalStudyMinutes': 0,
        'joinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('스터디가 등록되었습니다.')));

      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('스터디 등록 오류: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('스터디 등록 실패: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppTopBar(title: '스터디 만들기', centerTitle: false),
      body: Stack(
        children: [
          AppMainBackground(
            applySafeArea: false,
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                // 하단 고정 버튼에 가려지지 않도록 여유 패딩
                padding: const EdgeInsets.fromLTRB(20, 25, 20, 110),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const StudyPageHeader(
                        icon: Icons.groups_2_rounded,
                        eyebrow: '새 스터디',
                        title: '새로운 스터디를\n만들어보세요',
                        description: '스터디 정보를 입력하면 목록에 바로 등록됩니다.',
                      ),
                      const SizedBox(height: 28),

                      SectionCard(
                        icon: Icons.groups_rounded,
                        title: '기본 정보',
                        children: [
                          TextFormField(
                            controller: _groupNameController,
                            textInputAction: TextInputAction.next,
                            decoration: studyFieldDecoration(
                              context: context,
                              labelText: '스터디 이름',
                              hintText: '예: 정보처리기사 실기 스터디',
                              icon: Icons.groups_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '스터디 이름을 입력해주세요.';
                              }
                              if (value.trim().length < 2) {
                                return '스터디 이름을 2글자 이상 입력해주세요.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _certificateNameController,
                            textInputAction: TextInputAction.next,
                            decoration: studyFieldDecoration(
                              context: context,
                              labelText: '자격증 이름',
                              hintText: '예: 정보처리기사',
                              icon: Icons.workspace_premium_outlined,
                            ),
                          ),
                          SizedBox(height: 16),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _descriptionController,
                            builder: (context, value, child) {
                              return Stack(
                                children: [
                                  TextFormField(
                                    controller: _descriptionController,
                                    maxLines: 4,
                                    maxLength: 200,
                                    textInputAction: TextInputAction.newline,
                                    decoration:
                                        studyFieldDecoration(
                                          context: context,
                                          labelText: '스터디 소개',
                                          hintText: '스터디 목표와 진행 방법을 입력해주세요.',
                                          icon: Icons.edit_note_rounded,
                                          alignLabelWithHint: true,
                                        ).copyWith(
                                          counterText: '',
                                          helperText: ' ',
                                          contentPadding:
                                              const EdgeInsets.fromLTRB(
                                                14,
                                                20,
                                                14,
                                                30,
                                              ),
                                        ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return '스터디 소개를 입력해주세요.';
                                      }
                                      return null;
                                    },
                                  ),
                                  Positioned(
                                    right: 14,
                                    bottom: 28,
                                    child: IgnorePointer(
                                      child: Text(
                                        '${value.text.length}/200',
                                        style: TextStyle(
                                          color: colors.textSecondary
                                              .withOpacity(0.45),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      SectionCard(
                        icon: Icons.flag_rounded,
                        title: '시험 및 학습 목표',
                        subtitle: '시험일까지 남은 기간과 주간 달성률을 스터디방에 표시합니다.',
                        children: [
                          ExamDateTile(
                            examDate: _examDate,
                            onTap: _selectExamDate,
                            onClear: () => setState(() => _examDate = null),
                            formatDate: _formatDate,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _weeklyGoalHourController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            decoration: studyFieldDecoration(
                              context: context,
                              labelText: '주간 목표 공부시간',
                              hintText: '예: 15',
                              icon: Icons.flag_outlined,
                              suffixText: '시간',
                            ),
                            validator: (value) {
                              int? goalHour = int.tryParse(value?.trim() ?? '');
                              if (goalHour == null)
                                return '주간 목표시간을 숫자로 입력해주세요.';
                              if (goalHour < 1 || goalHour > 168) {
                                return '1시간 이상 168시간 이하로 입력해주세요.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      SectionCard(
                        icon: Icons.tune_rounded,
                        title: '스터디 설정',
                        children: [
                          MemberCountPicker(
                            value: _maxMemberCount,
                            min: 2,
                            max: 30,
                            caption: '최소 2명 · 최대 30명',
                            onChanged: (v) =>
                                setState(() => _maxMemberCount = v),
                          ),
                          const SizedBox(height: 8),
                          Divider(
                            height: 1,
                            color: colors.textSecondary.withOpacity(0.1),
                          ),
                          StudySwitchTile(
                            icon: Icons.public_rounded,
                            title: '공개 스터디',
                            subtitle: _isPublic
                                ? '다른 사용자가 검색하고 확인할 수 있습니다.'
                                : '초대받은 사용자만 확인할 수 있습니다.',
                            value: _isPublic,
                            onChanged: (value) =>
                                setState(() => _isPublic = value),
                          ),
                          Divider(
                            height: 1,
                            color: colors.textSecondary.withOpacity(0.1),
                          ),
                          StudySwitchTile(
                            icon: Icons.verified_user_rounded,
                            title: '참여 승인 필요',
                            subtitle: _joinApprovalRequired
                                ? '방장이 승인해야 참여할 수 있습니다.'
                                : '신청하면 바로 참여할 수 있습니다.',
                            value: _joinApprovalRequired,
                            onChanged: (value) =>
                                setState(() => _joinApprovalRequired = value),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isSaving) const Positioned.fill(child: LoadingOverlay()),
        ],
      ),
      // 저장 버튼을 하단에 고정 — 스크롤에 파묻히지 않는 요즘 앱 방식
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: colors.surface,
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: AppButton(
            text: '스터디 만들기',
            type: AppButtonType.primaryPink,
            height: 54,
            onPressed: _isSaving ? null : _saveStudy,
          ),
        ),
      ),
    );
  }
}
