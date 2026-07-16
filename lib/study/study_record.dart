import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutterteam03/widgets/app_state_views.dart';

import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

Brightness get _studyRecordBrightness {
  return WidgetsBinding.instance.platformDispatcher.platformBrightness;
}

AppColors get _studyRecordColors {
  if (_studyRecordBrightness == Brightness.dark) {
    return AppColors.dark;
  }

  return AppColors.light;
}

ColorScheme get _studyRecordColorScheme {
  if (_studyRecordBrightness == Brightness.dark) {
    return darkTheme.colorScheme;
  }

  return lightTheme.colorScheme;
}

class StudyRecordPage extends StatefulWidget {
  final String studyId;
  final String groupName;

  const StudyRecordPage({
    super.key,
    required this.studyId,
    required this.groupName,
  });

  @override
  State<StudyRecordPage> createState() {
    return _StudyRecordPageState();
  }
}

class _StudyRecordPageState extends State<StudyRecordPage> {
  String _selectedPeriod = '오늘';

  late DateTime _calendarMonth;
  late DateTime _selectedCalendarDate;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _recordStream;

  @override
  void initState() {
    super.initState();

    DateTime now = DateTime.now();

    _calendarMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    _selectedCalendarDate = DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  bool _isNetworkError(Object? error) {
    if (error is FirebaseException) {
      if (error.code == 'unavailable' ||
          error.code == 'network-request-failed' ||
          error.code == 'deadline-exceeded') {
        return true;
      }
    }

    return false;
  }

  void _reloadRecords() {
    setState(() {
      _recordStream = null;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getRecordStream(
      String uid,
      ) {
    _recordStream ??= FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(widget.studyId)
        .collection('studyRecords')
        .where(
      'uid',
      isEqualTo: uid,
    )
        .snapshots();

    return _recordStream!;
  }

  int _getRecordStudySeconds(
      Map<String, dynamic> recordData,
      ) {
    dynamic studySecondsValue =
    recordData['studySeconds'];

    if (studySecondsValue is int) {
      return studySecondsValue;
    }

    if (studySecondsValue is num) {
      return studySecondsValue.toInt();
    }

    dynamic elapsedSecondsValue =
    recordData['elapsedSeconds'];

    if (elapsedSecondsValue is int) {
      return elapsedSecondsValue;
    }

    if (elapsedSecondsValue is num) {
      return elapsedSecondsValue.toInt();
    }

    dynamic studyMinutesValue =
    recordData['studyMinutes'];

    if (studyMinutesValue is int) {
      return studyMinutesValue * 60;
    }

    if (studyMinutesValue is num) {
      return (studyMinutesValue * 60).round();
    }

    return 0;
  }

  DateTime? _getRecordDate(
      Map<String, dynamic> recordData,
      ) {
    dynamic endedAt = recordData['endedAt'];

    if (endedAt is Timestamp) {
      return endedAt.toDate().toLocal();
    }

    dynamic startedAt = recordData['startedAt'];

    if (startedAt is Timestamp) {
      return startedAt.toDate().toLocal();
    }

    dynamic createdAt = recordData['createdAt'];

    if (createdAt is Timestamp) {
      return createdAt.toDate().toLocal();
    }

    String studyDate =
        recordData['studyDate']?.toString() ?? '';

    if (studyDate.isNotEmpty) {
      return DateTime.tryParse(studyDate);
    }

    return null;
  }

  String _getSubjectName(
      Map<String, dynamic> recordData,
      ) {
    String subject =
        recordData['subject']?.toString() ?? '';

    if (subject.isEmpty) {
      subject =
          recordData['studySubject']?.toString() ?? '';
    }

    if (subject.isEmpty) {
      subject = '과목 미지정';
    }

    return subject;
  }

  DateTime _getTodayStart() {
    DateTime now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  DateTime _getPeriodStart() {
    DateTime todayStart = _getTodayStart();

    if (_selectedPeriod == '오늘') {
      return todayStart;
    }

    if (_selectedPeriod == '이번 주') {
      return todayStart.subtract(
        Duration(
          days: todayStart.weekday - 1,
        ),
      );
    }

    return DateTime(
      _calendarMonth.year,
      _calendarMonth.month,
      1,
    );
  }

  DateTime _getPeriodEnd() {
    DateTime periodStart = _getPeriodStart();

    if (_selectedPeriod == '오늘') {
      return periodStart.add(
        Duration(days: 1),
      );
    }

    if (_selectedPeriod == '이번 주') {
      return periodStart.add(
        Duration(days: 7),
      );
    }

    return DateTime(
      periodStart.year,
      periodStart.month + 1,
      1,
    );
  }

  bool _isInSelectedPeriod(
      DateTime recordDate,
      ) {
    DateTime periodStart = _getPeriodStart();
    DateTime periodEnd = _getPeriodEnd();

    bool isAfterStart =
        recordDate.isAtSameMomentAs(periodStart) ||
            recordDate.isAfter(periodStart);

    bool isBeforeEnd =
    recordDate.isBefore(periodEnd);

    return isAfterStart && isBeforeEnd;
  }

  bool _isSameDate(
      DateTime firstDate,
      DateTime secondDate,
      ) {
    return firstDate.year == secondDate.year &&
        firstDate.month == secondDate.month &&
        firstDate.day == secondDate.day;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
  _filterRecordList(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      allRecordList,
      ) {
    List<QueryDocumentSnapshot<Map<String, dynamic>>>
    visibleRecordList = [];

    for (int i = 0;
    i < allRecordList.length;
    i++) {
      Map<String, dynamic> recordData =
      allRecordList[i].data();

      DateTime? recordDate =
      _getRecordDate(recordData);

      if (recordDate == null) {
        continue;
      }

      if (_isInSelectedPeriod(recordDate)) {
        visibleRecordList.add(
          allRecordList[i],
        );
      }
    }

    visibleRecordList.sort((a, b) {
      DateTime? aDate = _getRecordDate(a.data());
      DateTime? bDate = _getRecordDate(b.data());

      int aTime =
          aDate?.millisecondsSinceEpoch ?? 0;

      int bTime =
          bDate?.millisecondsSinceEpoch ?? 0;

      return bTime.compareTo(aTime);
    });

    return visibleRecordList;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
  _filterRecordListByDate(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      allRecordList,
      DateTime selectedDate,
      ) {
    List<QueryDocumentSnapshot<Map<String, dynamic>>>
    selectedDateRecordList = [];

    for (int i = 0;
    i < allRecordList.length;
    i++) {
      DateTime? recordDate =
      _getRecordDate(allRecordList[i].data());

      if (recordDate == null) {
        continue;
      }

      if (_isSameDate(
        recordDate,
        selectedDate,
      )) {
        selectedDateRecordList.add(
          allRecordList[i],
        );
      }
    }

    selectedDateRecordList.sort((a, b) {
      DateTime? aDate = _getRecordDate(a.data());
      DateTime? bDate = _getRecordDate(b.data());

      int aTime =
          aDate?.millisecondsSinceEpoch ?? 0;

      int bTime =
          bDate?.millisecondsSinceEpoch ?? 0;

      return bTime.compareTo(aTime);
    });

    return selectedDateRecordList;
  }

  String _formatStudyTime(
      int totalSeconds,
      ) {
    if (totalSeconds <= 0) {
      return '0분';
    }

    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    if (hours > 0) {
      if (seconds > 0) {
        return '$hours시간 $minutes분 $seconds초';
      }

      return '$hours시간 $minutes분';
    }

    if (minutes > 0) {
      if (seconds > 0) {
        return '$minutes분 $seconds초';
      }

      return '$minutes분';
    }

    return '$seconds초';
  }

  String _formatDateKey(
      DateTime dateTime,
      ) {
    String month =
    dateTime.month.toString().padLeft(2, '0');

    String day =
    dateTime.day.toString().padLeft(2, '0');

    return '${dateTime.year}-$month-$day';
  }

  String _formatDisplayDate(
      DateTime dateTime,
      ) {
    if (_selectedPeriod == '오늘') {
      String hour =
      dateTime.hour.toString().padLeft(2, '0');

      String minute =
      dateTime.minute.toString().padLeft(2, '0');

      return '$hour:$minute';
    }

    return '${dateTime.month}월 ${dateTime.day}일';
  }

  String _formatSessionTime(
      DateTime dateTime,
      ) {
    String hour =
    dateTime.hour.toString().padLeft(2, '0');

    String minute =
    dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _getPeriodDescription() {
    if (_selectedPeriod == '오늘') {
      return '오늘 종료한 공부 기록을 확인해요.';
    }

    if (_selectedPeriod == '이번 주') {
      return '이번 주 월요일부터 오늘까지의 기록이에요.';
    }

    return '${_calendarMonth.month}월 과목별 공부시간과 날짜별 기록이에요.';
  }

  Widget _buildPeriodButton(
      String title,
      ) {
    bool isSelected =
        _selectedPeriod == title;

    Color backgroundColor =
        _studyRecordColorScheme.surface;

    Color borderColor =
        _studyRecordColorScheme.outlineVariant;

    Color textColor =
        _studyRecordColors.textSecondary;

    if (isSelected) {
      backgroundColor =
          _studyRecordColors.pinkSoft;

      borderColor =
          _studyRecordColors.pinkStart;

      textColor =
          _studyRecordColors.pinkStart;
    }

    return Expanded(
      child: SizedBox(
        height: 41,
        child: OutlinedButton(
          onPressed: () {
            setState(() {
              _selectedPeriod = title;

              if (title == '이번 달') {
                DateTime now = DateTime.now();

                _calendarMonth = DateTime(
                  now.year,
                  now.month,
                  1,
                );

                _selectedCalendarDate = DateTime(
                  now.year,
                  now.month,
                  now.day,
                );
              }
            });
          },
          style: OutlinedButton.styleFrom(
            backgroundColor: backgroundColor,
            side: BorderSide(
              color: borderColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(13),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: isSelected
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(
      IconData icon,
      String label,
      String value,
      ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: _studyRecordColorScheme.surface
              .withOpacity(0.88),
          borderRadius:
          BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: _studyRecordColors.pinkStart,
            ),
            SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color:
                _studyRecordColors.textPrimary,
              ),
            ),
            SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color:
                _studyRecordColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      recordList,
      ) {
    int totalSeconds = 0;
    Set<String> studyDateSet = {};

    for (int i = 0;
    i < recordList.length;
    i++) {
      Map<String, dynamic> recordData =
      recordList[i].data();

      totalSeconds +=
          _getRecordStudySeconds(recordData);

      DateTime? recordDate =
      _getRecordDate(recordData);

      if (recordDate != null) {
        studyDateSet.add(
          _formatDateKey(recordDate),
        );
      }
    }

    int averageSeconds = 0;

    if (studyDateSet.isNotEmpty) {
      averageSeconds =
          totalSeconds ~/ studyDateSet.length;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _studyRecordColors.lavender,
            _studyRecordColors.pinkSoft,
          ],
        ),
        borderRadius:
        BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            widget.groupName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color:
              _studyRecordColors.textPrimary,
            ),
          ),
          SizedBox(height: 5),
          Text(
            _getPeriodDescription(),
            style: TextStyle(
              fontSize: 11,
              color:
              _studyRecordColors.textSecondary,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryMetric(
                Icons.schedule_rounded,
                '총 공부시간',
                _formatStudyTime(totalSeconds),
              ),
              SizedBox(width: 8),
              _buildSummaryMetric(
                Icons.checklist_rounded,
                '공부 횟수',
                '${recordList.length}회',
              ),
              SizedBox(width: 8),
              _buildSummaryMetric(
                Icons.insights_rounded,
                '공부한 날',
                '${studyDateSet.length}일',
              ),
            ],
          ),
          if (_selectedPeriod != '오늘') ...[
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _studyRecordColorScheme.surface
                    .withOpacity(0.88),
                borderRadius:
                BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_graph_rounded,
                    size: 18,
                    color:
                    _studyRecordColors.pinkStart,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '공부한 날 평균 '
                        '${_formatStudyTime(averageSeconds)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _studyRecordColors
                          .textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, int> _createSubjectSecondsMap(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      recordList,
      ) {
    Map<String, int> subjectSecondsMap = {};

    for (int i = 0;
    i < recordList.length;
    i++) {
      Map<String, dynamic> recordData =
      recordList[i].data();

      String subjectName =
      _getSubjectName(recordData);

      int previousSeconds =
          subjectSecondsMap[subjectName] ?? 0;

      subjectSecondsMap[subjectName] =
          previousSeconds +
              _getRecordStudySeconds(recordData);
    }

    return subjectSecondsMap;
  }

  Widget _buildSubjectSummary(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      recordList,
      ) {
    Map<String, int> subjectSecondsMap =
    _createSubjectSecondsMap(recordList);

    List<MapEntry<String, int>> subjectList =
    subjectSecondsMap.entries.toList();

    subjectList.sort((a, b) {
      return b.value.compareTo(a.value);
    });

    if (subjectList.isEmpty) {
      return SizedBox(
        height: 190,
        child: AppEmptyView(
          message: '과목별 공부 기록이 없습니다.',
          description:
          '과목을 선택해 공부하고 종료하면 이곳에 표시됩니다.',
        ),
      );
    }

    int maxSeconds = subjectList.first.value;

    if (maxSeconds <= 0) {
      maxSeconds = 1;
    }

    return Column(
      children: [
        for (int i = 0;
        i < subjectList.length;
        i++)
          Container(
            margin: EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
              _studyRecordColorScheme.surface,
              borderRadius:
              BorderRadius.circular(18),
              border: Border.all(
                color: _studyRecordColorScheme
                    .outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color:
                        _studyRecordColors.lavender,
                        borderRadius:
                        BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 20,
                        color: _studyRecordColors
                            .pinkStart,
                      ),
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        subjectList[i].key,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                          FontWeight.bold,
                          color: _studyRecordColors
                              .textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _formatStudyTime(
                        subjectList[i].value,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                        FontWeight.bold,
                        color: _studyRecordColors
                            .pinkStart,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 11),
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value:
                    subjectList[i].value /
                        maxSeconds,
                    backgroundColor:
                    _studyRecordColors.pinkSoft,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(
                      _studyRecordColors.pinkStart,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Map<String, int> _createDailySecondsMap(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      recordList,
      ) {
    Map<String, int> dailySecondsMap = {};

    for (int i = 0;
    i < recordList.length;
    i++) {
      Map<String, dynamic> recordData =
      recordList[i].data();

      DateTime? recordDate =
      _getRecordDate(recordData);

      if (recordDate == null) {
        continue;
      }

      String dateKey =
      _formatDateKey(recordDate);

      int previousSeconds =
          dailySecondsMap[dateKey] ?? 0;

      dailySecondsMap[dateKey] =
          previousSeconds +
              _getRecordStudySeconds(recordData);
    }

    return dailySecondsMap;
  }

  Widget _buildDailySummary(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      recordList,
      ) {
    Map<String, int> dailySecondsMap =
    _createDailySecondsMap(recordList);

    List<MapEntry<String, int>> dailyList =
    dailySecondsMap.entries.toList();

    dailyList.sort((a, b) {
      return b.key.compareTo(a.key);
    });

    if (dailyList.isEmpty) {
      return SizedBox(
        height: 190,
        child: AppEmptyView(
          message: '날짜별 공부 기록이 없습니다.',
          description:
          '공부시간을 저장하면 날짜별 기록이 표시됩니다.',
        ),
      );
    }

    int maxSeconds = 1;

    for (int i = 0;
    i < dailyList.length;
    i++) {
      if (dailyList[i].value > maxSeconds) {
        maxSeconds = dailyList[i].value;
      }
    }

    return Column(
      children: [
        for (int i = 0;
        i < dailyList.length;
        i++)
          Container(
            margin: EdgeInsets.only(bottom: 9),
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
              _studyRecordColorScheme.surface,
              borderRadius:
              BorderRadius.circular(17),
              border: Border.all(
                color: _studyRecordColorScheme
                    .outlineVariant,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    dailyList[i].key.substring(5),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _studyRecordColors
                          .textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                    BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value:
                      dailyList[i].value /
                          maxSeconds,
                      backgroundColor:
                      _studyRecordColors.softBlue,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(
                        _studyRecordColors
                            .pinkStart,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 11),
                SizedBox(
                  width: 78,
                  child: Text(
                    _formatStudyTime(
                      dailyList[i].value,
                    ),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _studyRecordColors
                          .pinkStart,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSessionList(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      recordList, {
        bool showTimeOnly = false,
      }) {
    if (recordList.isEmpty) {
      return SizedBox(
        height: 190,
        child: AppEmptyView(
          message: '선택한 날짜의 공부 기록이 없습니다.',
          description:
          '공부를 종료해 기록을 저장하면 이곳에 표시됩니다.',
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0;
        i < recordList.length;
        i++)
          Container(
            margin: EdgeInsets.only(bottom: 9),
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
              _studyRecordColorScheme.surface,
              borderRadius:
              BorderRadius.circular(17),
              border: Border.all(
                color: _studyRecordColorScheme
                    .outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 41,
                  height: 41,
                  decoration: BoxDecoration(
                    color:
                    _studyRecordColors.mint,
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.timer_outlined,
                    color: _studyRecordColorScheme
                        .tertiary,
                    size: 21,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getSubjectName(
                          recordList[i].data(),
                        ),
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                          FontWeight.bold,
                          color: _studyRecordColors
                              .textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _getRecordDate(
                          recordList[i].data(),
                        ) ==
                            null
                            ? ''
                            : showTimeOnly
                            ? _formatSessionTime(
                          _getRecordDate(
                            recordList[i].data(),
                          )!,
                        )
                            : _formatDisplayDate(
                          _getRecordDate(
                            recordList[i].data(),
                          )!,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: _studyRecordColors
                              .textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatStudyTime(
                    _getRecordStudySeconds(
                      recordList[i].data(),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _studyRecordColors
                        .pinkStart,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  int _calculateStudyStreak(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      allRecordList,
      ) {
    Set<String> studyDateSet = {};

    for (int i = 0;
    i < allRecordList.length;
    i++) {
      DateTime? recordDate =
      _getRecordDate(allRecordList[i].data());

      if (recordDate == null) {
        continue;
      }

      studyDateSet.add(
        _formatDateKey(recordDate),
      );
    }

    if (studyDateSet.isEmpty) {
      return 0;
    }

    DateTime today = _getTodayStart();
    DateTime streakDate = today;

    if (!studyDateSet.contains(
      _formatDateKey(today),
    )) {
      DateTime yesterday =
      today.subtract(Duration(days: 1));

      if (!studyDateSet.contains(
        _formatDateKey(yesterday),
      )) {
        return 0;
      }

      streakDate = yesterday;
    }

    int streak = 0;

    while (studyDateSet.contains(
      _formatDateKey(streakDate),
    )) {
      streak++;

      streakDate =
          streakDate.subtract(Duration(days: 1));
    }

    return streak;
  }

  int _getMaximumDailySeconds(
      Map<String, int> dailySecondsMap,
      ) {
    int maximumSeconds = 0;

    dailySecondsMap.forEach(
          (dateKey, seconds) {
        if (seconds > maximumSeconds) {
          maximumSeconds = seconds;
        }
      },
    );

    return maximumSeconds;
  }

  Color _getCalendarCellColor(
      int studySeconds,
      int maximumSeconds,
      ) {
    if (studySeconds <= 0 ||
        maximumSeconds <= 0) {
      return _studyRecordColorScheme.surface;
    }

    double ratio =
        studySeconds / maximumSeconds;

    if (ratio > 1) {
      ratio = 1;
    }

    double opacity =
        0.18 + (ratio * 0.68);

    return _studyRecordColors.pinkStart
        .withOpacity(opacity);
  }

  Color _getCalendarTextColor(
      int studySeconds,
      int maximumSeconds,
      ) {
    if (studySeconds <= 0 ||
        maximumSeconds <= 0) {
      return _studyRecordColors.textPrimary;
    }

    double ratio =
        studySeconds / maximumSeconds;

    if (ratio >= 0.55) {
      return _studyRecordColorScheme.onPrimary;
    }

    return _studyRecordColors.textPrimary;
  }

  bool _canMoveToNextMonth() {
    DateTime now = DateTime.now();

    DateTime currentMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    return _calendarMonth.isBefore(
      currentMonth,
    );
  }

  void _moveCalendarMonth(
      int monthDifference,
      ) {
    DateTime nextMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + monthDifference,
      1,
    );

    DateTime now = DateTime.now();

    DateTime currentMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    if (nextMonth.isAfter(currentMonth)) {
      return;
    }

    setState(() {
      _calendarMonth = nextMonth;

      if (_calendarMonth.year == now.year &&
          _calendarMonth.month == now.month) {
        _selectedCalendarDate = DateTime(
          now.year,
          now.month,
          now.day,
        );
      } else {
        _selectedCalendarDate = DateTime(
          _calendarMonth.year,
          _calendarMonth.month,
          1,
        );
      }
    });
  }

  Widget _buildCalendarLegendBox(
      double opacity,
      ) {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: _studyRecordColors.pinkStart
            .withOpacity(opacity),
        borderRadius:
        BorderRadius.circular(5),
      ),
    );
  }

  Widget _buildMonthlyCalendar(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      allRecordList,
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      monthRecordList,
      ) {
    Map<String, int> dailySecondsMap =
    _createDailySecondsMap(monthRecordList);

    int maximumSeconds =
    _getMaximumDailySeconds(
      dailySecondsMap,
    );

    int streak =
    _calculateStudyStreak(allRecordList);

    DateTime firstDay = DateTime(
      _calendarMonth.year,
      _calendarMonth.month,
      1,
    );

    int daysInMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + 1,
      0,
    ).day;

    int leadingEmptyCellCount =
        firstDay.weekday - 1;

    int usedCellCount =
        leadingEmptyCellCount + daysInMonth;

    int totalCellCount =
        ((usedCellCount + 6) ~/ 7) * 7;

    List<String> weekDayList = [
      '월',
      '화',
      '수',
      '목',
      '금',
      '토',
      '일',
    ];

    return AppCard(
      borderRadius: 23,
      padding: EdgeInsets.all(16),
      backgroundColor:
      _studyRecordColorScheme.surface,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  _moveCalendarMonth(-1);
                },
                icon: Icon(
                  Icons.chevron_left_rounded,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${_calendarMonth.year}년 '
                          '${_calendarMonth.month}월',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _studyRecordColors
                            .textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      streak > 0
                          ? '현재 $streak일 연속 공부 중'
                          : '연속 공부 기록이 없습니다.',
                      style: TextStyle(
                        fontSize: 11,
                        color: streak > 0
                            ? _studyRecordColors
                            .pinkStart
                            : _studyRecordColors
                            .textSecondary,
                        fontWeight: streak > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _canMoveToNextMonth()
                    ? () {
                  _moveCalendarMonth(1);
                }
                    : null,
                icon: Icon(
                  Icons.chevron_right_rounded,
                ),
              ),
            ],
          ),
          SizedBox(height: 13),
          Row(
            children: [
              for (int i = 0;
              i < weekDayList.length;
              i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekDayList[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _studyRecordColors
                            .textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics:
            NeverScrollableScrollPhysics(),
            itemCount: totalCellCount,
            gridDelegate:
            SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              int dayNumber =
                  index -
                      leadingEmptyCellCount +
                      1;

              if (dayNumber < 1 ||
                  dayNumber > daysInMonth) {
                return SizedBox();
              }

              DateTime date = DateTime(
                _calendarMonth.year,
                _calendarMonth.month,
                dayNumber,
              );

              String dateKey =
              _formatDateKey(date);

              int studySeconds =
                  dailySecondsMap[dateKey] ?? 0;

              bool isSelected =
              _isSameDate(
                date,
                _selectedCalendarDate,
              );

              bool isToday =
              _isSameDate(
                date,
                _getTodayStart(),
              );

              return InkWell(
                borderRadius:
                BorderRadius.circular(11),
                onTap: () {
                  setState(() {
                    _selectedCalendarDate =
                        date;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _getCalendarCellColor(
                      studySeconds,
                      maximumSeconds,
                    ),
                    borderRadius:
                    BorderRadius.circular(11),
                    border: Border.all(
                      color: isSelected
                          ? _studyRecordColors
                          .pinkStart
                          : isToday
                          ? _studyRecordColors
                          .pinkSoft
                          : _studyRecordColorScheme
                          .outlineVariant,
                      width: isSelected
                          ? 1.7
                          : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ||
                              isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color:
                          _getCalendarTextColor(
                            studySeconds,
                            maximumSeconds,
                          ),
                        ),
                      ),
                      if (studySeconds > 0) ...[
                        SizedBox(height: 2),
                        Container(
                          width: 4,
                          height: 4,
                          decoration:
                          BoxDecoration(
                            color:
                            _getCalendarTextColor(
                              studySeconds,
                              maximumSeconds,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 14),
          Row(
            mainAxisAlignment:
            MainAxisAlignment.end,
            children: [
              Text(
                '적음',
                style: TextStyle(
                  fontSize: 10,
                  color: _studyRecordColors
                      .textSecondary,
                ),
              ),
              SizedBox(width: 6),
              _buildCalendarLegendBox(0.18),
              SizedBox(width: 4),
              _buildCalendarLegendBox(0.35),
              SizedBox(width: 4),
              _buildCalendarLegendBox(0.55),
              SizedBox(width: 4),
              _buildCalendarLegendBox(0.78),
              SizedBox(width: 6),
              Text(
                '많음',
                style: TextStyle(
                  fontSize: 10,
                  color: _studyRecordColors
                      .textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelectedDateRecords(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      allRecordList,
      ) {
    List<QueryDocumentSnapshot<Map<String, dynamic>>>
    selectedDateRecordList =
    _filterRecordListByDate(
      allRecordList,
      _selectedCalendarDate,
    );

    int selectedDateTotalSeconds = 0;

    for (int i = 0;
    i < selectedDateRecordList.length;
    i++) {
      selectedDateTotalSeconds +=
          _getRecordStudySeconds(
            selectedDateRecordList[i].data(),
          );
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_selectedCalendarDate.month}월 '
                    '${_selectedCalendarDate.day}일 기록',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color:
                  _studyRecordColors.textPrimary,
                ),
              ),
            ),
            Text(
              _formatStudyTime(
                selectedDateTotalSeconds,
              ),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color:
                _studyRecordColors.pinkStart,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          '선택한 날짜에 종료한 공부 기록이에요.',
          style: TextStyle(
            fontSize: 11,
            color:
            _studyRecordColors.textSecondary,
          ),
        ),
        SizedBox(height: 11),
        _buildSessionList(
          selectedDateRecordList,
          showTimeOnly: true,
        ),
      ],
    );
  }

  Widget _buildRecordContent(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      allRecordList,
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      visibleRecordList,
      ) {
    return AppMainBackground(
      applySafeArea: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          MediaQuery.of(context).padding.bottom + 36,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildPeriodButton('오늘'),
                SizedBox(width: 7),
                _buildPeriodButton('이번 주'),
                SizedBox(width: 7),
                _buildPeriodButton('이번 달'),
              ],
            ),
            SizedBox(height: 15),
            _buildSummaryCard(
              visibleRecordList,
            ),
            if (_selectedPeriod == '이번 달') ...[
              SizedBox(height: 22),
              Text(
                '공부 캘린더',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color:
                  _studyRecordColors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '공부시간이 많을수록 날짜 색상이 진하게 표시됩니다.',
                style: TextStyle(
                  fontSize: 11,
                  color:
                  _studyRecordColors.textSecondary,
                ),
              ),
              SizedBox(height: 11),
              _buildMonthlyCalendar(
                allRecordList,
                visibleRecordList,
              ),
              SizedBox(height: 24),
              _buildMonthSelectedDateRecords(
                allRecordList,
              ),
              SizedBox(height: 14),
            ],
            SizedBox(height: 24),
            Text(
              '과목별 공부시간',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color:
                _studyRecordColors.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '어떤 과목을 가장 많이 공부했는지 확인해요.',
              style: TextStyle(
                fontSize: 11,
                color:
                _studyRecordColors.textSecondary,
              ),
            ),
            SizedBox(height: 11),
            _buildSubjectSummary(
              visibleRecordList,
            ),
            if (_selectedPeriod != '이번 달') ...[
              SizedBox(height: 14),
              Text(
                _selectedPeriod == '오늘'
                    ? '오늘 공부 기록'
                    : '날짜별 공부시간',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color:
                  _studyRecordColors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                _selectedPeriod == '오늘'
                    ? '종료한 타이머 기록이 시간순으로 표시됩니다.'
                    : '날짜별 총 공부시간을 비교해 보세요.',
                style: TextStyle(
                  fontSize: 11,
                  color:
                  _studyRecordColors.textSecondary,
                ),
              ),
              SizedBox(height: 11),
              if (_selectedPeriod == '오늘')
                _buildSessionList(
                  visibleRecordList,
                )
              else
                _buildDailySummary(
                  visibleRecordList,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPeriodView() {
    return AppMainBackground(
      applySafeArea: false,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              14,
              18,
              0,
            ),
            child: Row(
              children: [
                _buildPeriodButton('오늘'),
                SizedBox(width: 7),
                _buildPeriodButton('이번 주'),
                SizedBox(width: 7),
                _buildPeriodButton('이번 달'),
              ],
            ),
          ),
          Expanded(
            child: AppEmptyView(
              message: '공부 기록이 없습니다.',
              description:
              '과목을 선택해 공부를 시작하고 종료하면 기록이 저장됩니다.',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser =
        FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppTopBar(
        title: '공부 기록',
      ),
      body: currentUser == null
          ? AppErrorView(
        message:
        '로그인 정보를 확인할 수 없습니다.',
        description:
        '다시 로그인한 뒤 공부 기록을 확인해 주세요.',
      )
          : StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream:
        _getRecordStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return AppLoadingView(
              message:
              '공부 기록을 불러오는 중입니다.',
            );
          }

          if (snapshot.hasError) {
            if (_isNetworkError(
              snapshot.error,
            )) {
              return AppNetworkErrorView(
                message:
                '인터넷 연결을 확인해 주세요.',
                description:
                '네트워크 연결 후 공부 기록을 다시 불러와 주세요.',
                retryButtonText:
                '다시 시도',
                onRetryPressed:
                _reloadRecords,
              );
            }

            return AppErrorView(
              message:
              '공부 기록을 불러오지 못했습니다.',
              description:
              '잠시 후 다시 시도해 주세요.',
              retryButtonText:
              '다시 시도',
              onRetryPressed:
              _reloadRecords,
            );
          }

          List<
              QueryDocumentSnapshot<
                  Map<String, dynamic>>>
          allRecordList =
              snapshot.data?.docs.toList() ??
                  [];

          List<
              QueryDocumentSnapshot<
                  Map<String, dynamic>>>
          visibleRecordList =
          _filterRecordList(
            allRecordList,
          );

          if (visibleRecordList.isEmpty &&
              _selectedPeriod != '이번 달') {
            return _buildEmptyPeriodView();
          }

          return _buildRecordContent(
            allRecordList,
            visibleRecordList,
          );
        },
      ),
    );
  }
}
