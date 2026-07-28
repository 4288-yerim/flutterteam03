import 'package:flutter/material.dart';

import '../../widgets/app_main_background.dart';
import '../../widgets/app_state_views.dart';
import '../../widgets/app_top_bar.dart';
import '../services/certificate_schedule_service.dart';
import '../widgets/certificate_common_widgets.dart';
import '../widgets/certificate_schedule_widgets.dart';
import 'certificate_search.dart';

class CertificateSchedulePage extends StatefulWidget {
  const CertificateSchedulePage({super.key});

  @override
  State<CertificateSchedulePage> createState() =>
      _CertificateSchedulePageState();
}

class _CertificateSchedulePageState extends State<CertificateSchedulePage> {
  final CertificateScheduleService _scheduleService =
  CertificateScheduleService();

  int _selectedTabIndex = 0;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  bool _isLoading = true;
  String? _loadError;

  final List<CertificateSchedule> _schedules = [];

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final schedules = await _scheduleService.getSchedules();

      if (!mounted) {
        return;
      }

      setState(() {
        _schedules
          ..clear()
          ..addAll(schedules);

        _isLoading = false;
      });
    } on CertificateScheduleException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = '자격증 일정을 불러오지 못했습니다.';
      });
    }
  }

  List<CertificateSchedule> _getSchedulesForDay(DateTime day) {
    final schedules = _schedules.where((schedule) {
      return schedule.occursOn(day);
    }).toList();

    schedules.sort((a, b) {
      final typeCompare =
      a.scheduleType.compareTo(b.scheduleType);

      if (typeCompare != 0) {
        return typeCompare;
      }

      return a.certificateName.compareTo(b.certificateName);
    });

    return schedules;
  }

  List<CertificateSchedule> _getSchedulesForMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final schedules = _schedules.where((schedule) {
      return !schedule.endDate.isBefore(firstDay) &&
          !schedule.startDate.isAfter(lastDay);
    }).toList();

    schedules.sort((a, b) {
      final dateCompare =
      a.startDate.compareTo(b.startDate);

      if (dateCompare != 0) {
        return dateCompare;
      }

      return a.certificateName.compareTo(b.certificateName);
    });

    return schedules;
  }

  void _moveMonth(int amount) {
    final newMonth = DateTime(
      _focusedDay.year,
      _focusedDay.month + amount,
      1,
    );

    setState(() {
      _focusedDay = newMonth;
      _selectedDay = newMonth;
    });
  }

  void _openCertificateSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const CertificateSearchPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '자격증 일정 조회',
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: certificateDarkText,
            size: 21,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openCertificateSearch,
            icon: const Icon(
              Icons.search_rounded,
              color: certificateDarkText,
              size: 26,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppMainBackground(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingView(
        message: '자격증 일정을 불러오는 중입니다.',
      );
    }

    if (_loadError != null) {
      return CertificateScheduleLoadError(
        message: _loadError!,
        onRetry: _loadSchedules,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: CertificateScheduleTabSelector(
            selectedIndex: _selectedTabIndex,
            onChanged: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
          ),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: IndexedStack(
            index: _selectedTabIndex,
            children: [
              _buildCalendarTab(),
              _buildListTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarTab() {
    final selectedSchedules =
    _getSchedulesForDay(_selectedDay);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        children: [
          CertificateMonthHeader(
            focusedDay: _focusedDay,
            onPrevious: () => _moveMonth(-1),
            onNext: () => _moveMonth(1),
          ),
          const SizedBox(height: 14),
          CertificateCalendarCard(
            focusedDay: _focusedDay,
            selectedDay: _selectedDay,
            eventLoader: _getSchedulesForDay,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
                _selectedDay = DateTime(
                  focusedDay.year,
                  focusedDay.month,
                  1,
                );
              });
            },
          ),
          const SizedBox(height: 30),
          Align(
            alignment: Alignment.centerLeft,
            child: CertificateScheduleDateTitle(
              date: _selectedDay,
              count: selectedSchedules.length,
            ),
          ),
          const SizedBox(height: 15),
          if (selectedSchedules.isEmpty)
            const EmptyCertificateScheduleCard(
              message: '선택한 날짜에 자격증 일정이 없습니다.',
            )
          else
            ...selectedSchedules.map(
                  (schedule) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CertificateScheduleCard(
                  schedule: schedule,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListTab() {
    final monthlySchedules =
    _getSchedulesForMonth(_focusedDay);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CertificateMonthHeader(
            focusedDay: _focusedDay,
            onPrevious: () => _moveMonth(-1),
            onNext: () => _moveMonth(1),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: monthlySchedules.isEmpty
              ? const SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: EmptyCertificateScheduleCard(
              message: '이번 달에 등록된 자격증 일정이 없습니다.',
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              24,
              0,
              24,
              40,
            ),
            itemCount: monthlySchedules.length,
            itemBuilder: (context, index) {
              final schedule =
              monthlySchedules[index];

              final showDateHeader = index == 0 ||
                  !_isSameScheduleStartDay(
                    schedule,
                    monthlySchedules[index - 1],
                  );

              return Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  if (showDateHeader) ...[
                    if (index != 0)
                      const SizedBox(height: 18),
                    CertificateScheduleListDateHeader(
                      date: schedule.startDate,
                    ),
                    const SizedBox(height: 10),
                  ],
                  Padding(
                    padding:
                    const EdgeInsets.only(bottom: 12),
                    child: CertificateScheduleCard(
                      schedule: schedule,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isSameScheduleStartDay(
      CertificateSchedule first,
      CertificateSchedule second,
      ) {
    return DateUtils.isSameDay(
      first.startDate,
      second.startDate,
    );
  }
}
