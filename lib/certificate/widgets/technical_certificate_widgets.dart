import 'package:flutter/material.dart';

import '../../theme.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/technical_certificate_service.dart';
import 'certificate_common_widgets.dart';
import 'certificate_detail_widgets.dart';

class TechnicalScheduleCard extends StatefulWidget {
  final String title;

  final DateTime? writtenRegistrationStartAt;
  final DateTime? writtenRegistrationEndAt;

  final DateTime? writtenExamStartAt;
  final DateTime? writtenExamEndAt;

  final DateTime? writtenPassAt;

  final DateTime? documentSubmitStartAt;
  final DateTime? documentSubmitEndAt;

  final DateTime? practicalRegistrationStartAt;
  final DateTime? practicalRegistrationEndAt;

  final DateTime? practicalExamStartAt;
  final DateTime? practicalExamEndAt;

  final DateTime? practicalPassStartAt;
  final DateTime? practicalPassEndAt;

  const TechnicalScheduleCard({
    super.key,
    required this.title,
    required this.writtenRegistrationStartAt,
    required this.writtenRegistrationEndAt,
    required this.writtenExamStartAt,
    required this.writtenExamEndAt,
    required this.writtenPassAt,
    required this.documentSubmitStartAt,
    required this.documentSubmitEndAt,
    required this.practicalRegistrationStartAt,
    required this.practicalRegistrationEndAt,
    required this.practicalExamStartAt,
    required this.practicalExamEndAt,
    required this.practicalPassStartAt,
    required this.practicalPassEndAt,
  });

  @override
  State<TechnicalScheduleCard> createState() => _TechnicalScheduleCardState();
}

class _TechnicalScheduleCardState extends State<TechnicalScheduleCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final scheduleStatus = _resolveScheduleStatus();

    final items = <CertificateInfoItem>[
      if (_hasDate(
        widget.writtenRegistrationStartAt,
        widget.writtenRegistrationEndAt,
      ))
        CertificateInfoItem(
          label: _writtenScheduleLabel('원서접수'),
          value: _formatDateRange(
            widget.writtenRegistrationStartAt,
            widget.writtenRegistrationEndAt,
          ),
        ),
      if (_hasDate(widget.writtenExamStartAt, widget.writtenExamEndAt))
        CertificateInfoItem(
          label: _writtenScheduleLabel('시험'),
          value: _formatDateRange(
            widget.writtenExamStartAt,
            widget.writtenExamEndAt,
          ),
        ),
      if (widget.writtenPassAt != null)
        CertificateInfoItem(
          label: '필기 합격 발표',
          value: _formatDate(widget.writtenPassAt!),
        ),
      if (_hasDate(widget.documentSubmitStartAt, widget.documentSubmitEndAt))
        CertificateInfoItem(
          label: '서류 제출',
          value: _formatDateRange(
            widget.documentSubmitStartAt,
            widget.documentSubmitEndAt,
          ),
        ),
      if (_hasDate(
        widget.practicalRegistrationStartAt,
        widget.practicalRegistrationEndAt,
      ))
        CertificateInfoItem(
          label: '실기 원서접수',
          value: _formatDateRange(
            widget.practicalRegistrationStartAt,
            widget.practicalRegistrationEndAt,
          ),
        ),
      if (_hasDate(widget.practicalExamStartAt, widget.practicalExamEndAt))
        CertificateInfoItem(
          label: '실기시험',
          value: _formatDateRange(
            widget.practicalExamStartAt,
            widget.practicalExamEndAt,
          ),
        ),
      if (_hasDate(widget.practicalPassStartAt, widget.practicalPassEndAt))
        CertificateInfoItem(
          label: '최종 합격 발표',
          value: _formatDateRange(
            widget.practicalPassStartAt,
            widget.practicalPassEndAt,
          ),
        ),
    ];

    return Container(
      width: double.infinity,
      decoration: certificateCardDecoration(context: context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title.isEmpty ? '시험 일정' : widget.title,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                  ),

                  if (scheduleStatus != null) ...[
                    SizedBox(width: 8),
                    CertificateScheduleStatusBadge(
                      label: scheduleStatus.label,
                      isActive: scheduleStatus.isActive,
                    ),
                  ],

                  SizedBox(width: 10),

                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: context.colors.textSecondary,
                      size: 27,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: SizedBox(width: double.infinity, height: 0),
            secondChild: items.isEmpty
                ? SizedBox.shrink()
                : Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        Divider(height: 1, color: context.colors.border),
                        SizedBox(height: 18),
                        ...List.generate(items.length, (index) {
                          final item = items[index];

                          return Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 108,
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        color: context.colors.textSecondary,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      item.value,
                                      style: TextStyle(
                                        color: context.colors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (index != items.length - 1)
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Divider(
                                    height: 1,
                                    color: context.colors.border,
                                  ),
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  _TechnicalScheduleStatus? _resolveScheduleStatus() {
    final today = _dateOnly(DateTime.now());

    final upcomingStatus = _resolveUpcomingCountdown(today);
    if (upcomingStatus != null) {
      return upcomingStatus;
    }

    /*
     * 회차 전체 종료 판단
     *
     * 해당 회차에 존재하는 모든 일정의 마지막 날짜가
     * 오늘보다 이전이면 더 이상 남은 일정이 없으므로 종료한다.
     */
    if (_isEntireScheduleFinished(today)) {
      return _TechnicalScheduleStatus(label: '종료', isActive: false);
    }

    /*
     * 현재 진행 중인 단계
     *
     * 일정이 겹치면 뒤쪽 단계가 우선 표시되도록
     * 실기시험부터 역순으로 검사한다.
     */

    if (_isDateWithinRange(
      today,
      widget.practicalExamStartAt,
      widget.practicalExamEndAt,
    )) {
      return _TechnicalScheduleStatus(label: '실기시험 진행중', isActive: true);
    }

    if (_isDateWithinRange(
      today,
      widget.practicalRegistrationStartAt,
      widget.practicalRegistrationEndAt,
    )) {
      return _TechnicalScheduleStatus(label: '실기 원서접수 중', isActive: true);
    }

    if (_isDateWithinRange(
      today,
      widget.writtenExamStartAt,
      widget.writtenExamEndAt,
    )) {
      return _TechnicalScheduleStatus(label: '필기시험 진행중', isActive: true);
    }

    if (_isDateWithinRange(
      today,
      widget.writtenRegistrationStartAt,
      widget.writtenRegistrationEndAt,
    )) {
      return _TechnicalScheduleStatus(label: '필기 원서접수 중', isActive: true);
    }

    /*
     * 현재 진행 중인 일정이 없으면
     * 가장 최근에 끝난 원서접수·시험 단계를 표시한다.
     *
     * 합격자 발표와 서류 제출은 회차 종료 판단에는 포함하지만
     * 별도 상태 뱃지는 표시하지 않는다.
     */

    if (_isRangeFinished(
      today,
      widget.practicalExamStartAt,
      widget.practicalExamEndAt,
    )) {
      return _TechnicalScheduleStatus(label: '실기시험 종료', isActive: false);
    }

    if (_isRangeFinished(
      today,
      widget.practicalRegistrationStartAt,
      widget.practicalRegistrationEndAt,
    )) {
      return _TechnicalScheduleStatus(label: '실기 원서접수 종료', isActive: false);
    }

    if (_isRangeFinished(
      today,
      widget.writtenExamStartAt,
      widget.writtenExamEndAt,
    )) {
      return _TechnicalScheduleStatus(label: '필기시험 종료', isActive: false);
    }

    if (_isRangeFinished(
      today,
      widget.writtenRegistrationStartAt,
      widget.writtenRegistrationEndAt,
    )) {
      return _TechnicalScheduleStatus(label: '필기 원서접수 종료', isActive: false);
    }

    return null;
  }

  String _writtenScheduleLabel(String label) {
    final hasPracticalExam = widget.practicalExamStartAt != null ||
        widget.practicalExamEndAt != null;
    return hasPracticalExam ? '필기 $label' : label;
  }

  _TechnicalScheduleStatus? _resolveUpcomingCountdown(DateTime today) {
    final activeRanges = [
      (widget.writtenRegistrationStartAt, widget.writtenRegistrationEndAt),
      (widget.writtenExamStartAt, widget.writtenExamEndAt),
      (widget.practicalRegistrationStartAt, widget.practicalRegistrationEndAt),
      (widget.practicalExamStartAt, widget.practicalExamEndAt),
    ];
    if (activeRanges.any((range) => _isDateWithinRange(today, range.$1, range.$2))) {
      return null;
    }

    final hasPracticalExam = widget.practicalExamStartAt != null ||
        widget.practicalExamEndAt != null;
    final sameExamStart = hasPracticalExam &&
        widget.writtenExamStartAt != null &&
        widget.writtenExamStartAt == widget.practicalExamStartAt;
    final writtenPrefix = hasPracticalExam && !sameExamStart ? '필기 ' : '';
    final practicalPrefix = hasPracticalExam && !sameExamStart ? '실기 ' : '';

    final candidates = <(DateTime, String)>[];
    _addCountdownCandidate(
      candidates,
      today: today,
      registrationStart: widget.writtenRegistrationStartAt,
      registrationEnd: widget.writtenRegistrationEndAt,
      examStart: widget.writtenExamStartAt,
      prefix: writtenPrefix,
    );
    _addCountdownCandidate(
      candidates,
      today: today,
      registrationStart: widget.practicalRegistrationStartAt,
      registrationEnd: widget.practicalRegistrationEndAt,
      examStart: widget.practicalExamStartAt,
      prefix: practicalPrefix,
    );
    if (candidates.isEmpty) return null;

    candidates.sort((first, second) => first.$1.compareTo(second.$1));
    final candidate = candidates.first;
    final remainingDays = _dateOnly(candidate.$1).difference(today).inDays;
    return _TechnicalScheduleStatus(
      label: '${candidate.$2} D-$remainingDays',
      isActive: false,
    );
  }

  void _addCountdownCandidate(
    List<(DateTime, String)> candidates, {
    required DateTime today,
    required DateTime? registrationStart,
    required DateTime? registrationEnd,
    required DateTime? examStart,
    required String prefix,
  }) {
    if (registrationStart != null && _dateOnly(registrationStart).isAfter(today)) {
      candidates.add((registrationStart, '${prefix}원서접수'));
      return;
    }
    final registrationFinished = registrationEnd != null &&
        _dateOnly(registrationEnd).isBefore(today);
    if ((registrationFinished || registrationStart == null) &&
        examStart != null &&
        !_dateOnly(examStart).isBefore(today)) {
      candidates.add((examStart, '${prefix}시험'));
    }
  }

  bool _isEntireScheduleFinished(DateTime today) {
    final scheduleDates = <DateTime?>[
      widget.writtenRegistrationStartAt,
      widget.writtenRegistrationEndAt,

      widget.writtenExamStartAt,
      widget.writtenExamEndAt,

      widget.writtenPassAt,

      widget.documentSubmitStartAt,
      widget.documentSubmitEndAt,

      widget.practicalRegistrationStartAt,
      widget.practicalRegistrationEndAt,

      widget.practicalExamStartAt,
      widget.practicalExamEndAt,

      widget.practicalPassStartAt,
      widget.practicalPassEndAt,
    ];

    final existingDates = scheduleDates
        .whereType<DateTime>()
        .map(_dateOnly)
        .toList();

    if (existingDates.isEmpty) {
      return false;
    }

    final lastScheduleDate = existingDates.reduce((currentLatest, date) {
      return date.isAfter(currentLatest) ? date : currentLatest;
    });

    return lastScheduleDate.isBefore(today);
  }

  static bool _isDateWithinRange(
    DateTime today,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate == null && endDate == null) {
      return false;
    }

    final start = _dateOnly(startDate ?? endDate!);

    final end = _dateOnly(endDate ?? startDate!);

    return !today.isBefore(start) && !today.isAfter(end);
  }

  static bool _isRangeFinished(
    DateTime today,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate == null && endDate == null) {
      return false;
    }

    final lastDate = _dateOnly(endDate ?? startDate!);

    return lastDate.isBefore(today);
  }

  static DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();

    return DateTime(local.year, local.month, local.day);
  }

  static bool _hasDate(DateTime? startDate, DateTime? endDate) {
    return startDate != null || endDate != null;
  }

  static String _formatDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) {
      return '';
    }

    if (startDate == null) {
      return _formatDate(endDate!);
    }

    if (endDate == null) {
      return _formatDate(startDate);
    }

    final formattedStart = _formatDate(startDate);
    final formattedEnd = _formatDate(endDate);

    if (formattedStart == formattedEnd) {
      return formattedStart;
    }

    return '$formattedStart ~ $formattedEnd';
  }

  static String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    final year = localDate.year.toString();
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');

    return '$year.$month.$day';
  }
}

class _TechnicalScheduleStatus {
  final String label;
  final bool isActive;

  const _TechnicalScheduleStatus({required this.label, required this.isActive});
}

class TechnicalExamInformationCard extends StatelessWidget {
  final int? writtenFee;
  final int? practicalFee;
  final String examTrends;
  final String howToObtain;
  final VoidCallback onOpenExamStandard;
  final VoidCallback onOpenOtherInformation;

  const TechnicalExamInformationCard({
    super.key,
    required this.writtenFee,
    required this.practicalFee,
    required this.examTrends,
    required this.howToObtain,
    required this.onOpenExamStandard,
    required this.onOpenOtherInformation,
  });

  bool get _hasExamFee {
    return writtenFee != null || practicalFee != null;
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      if (_hasExamFee)
        _TechnicalExamInformationSection(
          title: '응시수수료',
          child: Column(
            children: [
              if (writtenFee != null)
                _ExamFeeRow(label: '필기', fee: writtenFee!),
              if (writtenFee != null && practicalFee != null)
                SizedBox(height: 10),
              if (practicalFee != null)
                _ExamFeeRow(label: '실기', fee: practicalFee!),
            ],
          ),
        ),
      if (examTrends.trim().isNotEmpty)
        _TechnicalExamInformationSection(
          title: '출제경향',
          child: Text(
            _formatStructuredContents(examTrends),
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.65,
            ),
          ),
        ),
      if (howToObtain.trim().isNotEmpty)
        _TechnicalExamInformationSection(
          title: '취득방법',
          child: Text(
            _formatStructuredContents(howToObtain),
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.65,
            ),
          ),
        ),
      _TechnicalExamInformationSection(
        title: '출제기준',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '출제기준은 Q-Net 출제기준에서 확인 바랍니다.',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onOpenExamStandard,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: context.colors.pinkSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Q-Net에서 출제기준 확인하기',
                        style: TextStyle(
                          color: context.colors.pinkDeep,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 7),
                      Icon(
                        Icons.open_in_new_rounded,
                        color: context.colors.pinkDeep,
                        size: 17,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      _TechnicalExamInformationSection(
        title: '그외 사항',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '그외 사항은 Q-Net에서 확인 바랍니다.',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onOpenOtherInformation,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: context.colors.pinkSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Q-Net에서 상세정보 확인하기',
                        style: TextStyle(
                          color: context.colors.pinkDeep,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 7),
                      Icon(
                        Icons.open_in_new_rounded,
                        color: context.colors.pinkDeep,
                        size: 17,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(sections.length, (index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sections[index],
              if (index != sections.length - 1)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(height: 1, color: context.colors.border),
                ),
            ],
          );
        }),
      ),
    );
  }

  static String _formatStructuredContents(String contents) {
    var formatted = contents.trim();

    const circledNumbers = [
      '①',
      '②',
      '③',
      '④',
      '⑤',
      '⑥',
      '⑦',
      '⑧',
      '⑨',
      '⑩',
      '⑪',
      '⑫',
      '⑬',
      '⑭',
      '⑮',
      '⑯',
      '⑰',
      '⑱',
      '⑲',
      '⑳',
    ];

    for (final number in circledNumbers) {
      formatted = formatted.replaceAll(number, '\n$number ');
    }

    formatted = formatted.replaceAllMapped(RegExp(r'(\d{1,2})\.\s*'), (match) {
      return '\n${match.group(1)}. ';
    });

    formatted = formatted.replaceAllMapped(RegExp(r'<([^>]+)>'), (match) {
      return '\n<${match.group(1)}>\n';
    });

    formatted = formatted.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return formatted.trim();
  }
}

class _TechnicalExamInformationSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _TechnicalExamInformationSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 13),
        child,
      ],
    );
  }
}

class _ExamFeeRow extends StatelessWidget {
  final String label;
  final int fee;

  const _ExamFeeRow({required this.label, required this.fee});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            '${_formatFee(fee)}원',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  static String _formatFee(int value) {
    final characters = value.toString().split('').reversed;
    final result = <String>[];

    var index = 0;

    for (final character in characters) {
      if (index > 0 && index % 3 == 0) {
        result.add(',');
      }

      result.add(character);
      index++;
    }

    return result.reversed.join();
  }
}

class CertificateScheduleNoticeCard extends StatelessWidget {
  final VoidCallback onOpenNotice;

  const CertificateScheduleNoticeCard({super.key, required this.onOpenNotice});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: context.colors.pinkDeep,
                size: 21,
              ),
              SizedBox(width: 9),
              Text(
                '시험 일정 안내',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 17),
          _ScheduleNoticeRow(
            text: '원서접수 시간은 원서접수 첫날 10:00부터 마지막 날 18:00까지입니다.',
          ),
          SizedBox(height: 11),
          _ScheduleNoticeRow(
            text: '필기시험 합격예정자 및 최종합격자 발표 시간은 해당 발표일 09:00입니다.',
          ),
          SizedBox(height: 11),
          _ScheduleNoticeRow(text: '시험 일정은 종목별, 지역별로 상이할 수 있습니다.'),
          SizedBox(height: 11),
          _ScheduleNoticeRow(
            text: '접수 일정 전에 공지되는 해당 회별 수험자 안내(Q-Net 공지사항 게시)를 반드시 확인해야 합니다.',
          ),
          SizedBox(height: 11),
          _ScheduleNoticeRow(
            text: '빈자리 원서접수 기간이 운영될 수 있으나, 자격증 상세보기에는 표시되지 않을 수 있습니다.',
          ),
          SizedBox(height: 17),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: onOpenNotice,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: context.colors.pinkSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Q-Net에서 공지사항 확인하기',
                      style: TextStyle(
                        color: context.colors.pinkDeep,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 7),
                    Icon(
                      Icons.open_in_new_rounded,
                      color: context.colors.pinkDeep,
                      size: 17,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleNoticeRow extends StatelessWidget {
  final String text;

  const _ScheduleNoticeRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 8),
          child: Icon(
            Icons.circle,
            size: 5,
            color: context.colors.textSecondary,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class TechnicalExamSubjectLookupCard extends StatefulWidget {
  final bool isLoading;
  final bool hasRequested;
  final String? errorMessage;
  final List<TechnicalExamSubject> subjects;
  final VoidCallback onLookup;

  const TechnicalExamSubjectLookupCard({
    super.key,
    required this.isLoading,
    required this.hasRequested,
    required this.errorMessage,
    required this.subjects,
    required this.onLookup,
  });

  @override
  State<TechnicalExamSubjectLookupCard> createState() =>
      _TechnicalExamSubjectLookupCardState();
}

class _TechnicalExamSubjectLookupCardState
    extends State<TechnicalExamSubjectLookupCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: certificateCardDecoration(context: context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    color: context.colors.pinkDeep,
                    size: 22,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '시험 교시·과목 정보',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: context.colors.textSecondary,
                      size: 27,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: context.colors.border),
                  SizedBox(height: 16),
                  Text(
                    '현재 자격증의 시험 과목, 교시, 문항 수와 시험시간을 조회합니다.\n'
                    '차수는 대체로 1차는 필기, 2차는 실기/면접입니다.',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 17),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.isLoading ? null : widget.onLookup,
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.pinkDeep,
                        disabledBackgroundColor: context.colors.pinkDeep
                            .withValues(alpha: 0.55),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: widget.isLoading
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: context.colors.onPrimary,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  '조회 중...',
                                  style: TextStyle(
                                    color: context.colors.onPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              widget.hasRequested ? '다시 조회하기' : '과목 조회하기',
                              style: TextStyle(
                                color: context.colors.onPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  if (widget.isLoading) ...[
                    SizedBox(height: 18),
                    _ExamSubjectMessage(
                      icon: Icons.hourglass_top_rounded,
                      message: '시험 교시·과목 정보를 조회하고 있습니다.',
                    ),
                  ] else if (widget.errorMessage != null) ...[
                    SizedBox(height: 18),
                    _ExamSubjectMessage(
                      icon: Icons.error_outline_rounded,
                      message: widget.errorMessage!,
                    ),
                  ] else if (widget.hasRequested &&
                      widget.subjects.isEmpty) ...[
                    SizedBox(height: 18),
                    _ExamSubjectMessage(
                      icon: Icons.search_off_rounded,
                      message: '조회된 시험 교시·과목 정보가 없습니다.',
                    ),
                  ] else if (widget.subjects.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(height: 1, color: context.colors.border),
                    ),
                    ...List.generate(
                      widget.subjects.length,
                      (index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index == widget.subjects.length - 1 ? 0 : 12,
                        ),
                        child: _TechnicalExamSubjectItem(
                          subject: widget.subjects[index],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _TechnicalExamSubjectItem extends StatelessWidget {
  final TechnicalExamSubject subject;

  const _TechnicalExamSubjectItem({required this.subject});

  @override
  Widget build(BuildContext context) {
    final items = <CertificateInfoItem>[
      if (subject.detailTypeName.isNotEmpty)
        CertificateInfoItem(label: '세부유형', value: subject.detailTypeName),
      if (subject.sequenceNumber != null)
        CertificateInfoItem(label: '차수', value: '${subject.sequenceNumber}차'),
      if (subject.lessonNumber != null)
        CertificateInfoItem(label: '교시', value: '${subject.lessonNumber}교시'),
      if (subject.requiredSubjectName.isNotEmpty)
        CertificateInfoItem(label: '필수 여부', value: subject.requiredSubjectName),
      if (subject.questionCount != null)
        CertificateInfoItem(label: '문항 수', value: '${subject.questionCount}문항'),
      if (subject.shortAnswerQuestionCount != null)
        CertificateInfoItem(
          label: '단답형',
          value: '${subject.shortAnswerQuestionCount}문항',
        ),
      if (subject.examTimeMinutes != null)
        CertificateInfoItem(
          label: '시험시간',
          value: '${subject.examTimeMinutes}분',
        ),
      if (subject.omrStandardScore != null)
        CertificateInfoItem(
          label: 'OMR 만점',
          value: '${subject.omrStandardScore}점',
        ),
      if (subject.selectionFieldName.isNotEmpty &&
          subject.selectionFieldName != '선택분야없음')
        CertificateInfoItem(label: '선택분야', value: subject.selectionFieldName),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.pinkSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subject.subjectName.isEmpty ? '과목 정보' : subject.subjectName,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (items.isNotEmpty) ...[
            SizedBox(height: 14),
            ...List.generate(
              items.length,
              (index) => Padding(
                padding: EdgeInsets.only(
                  bottom: index == items.length - 1 ? 0 : 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 78,
                      child: Text(
                        items[index].label,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        items[index].value,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExamSubjectMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _ExamSubjectMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.pinkSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.pinkDeep, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TechnicalPracticalMaterialLookupCard extends StatefulWidget {
  final bool isLoading;
  final bool hasRequested;
  final String? errorMessage;
  final List<TechnicalPracticalExamMaterial> materials;
  final bool usesStoredData;
  final int? storedImplementationYear;
  final PracticalMaterialPrecautions precautions;

  final Future<void> Function({
    required String implementationYear,
    required String implementationSequence,
  })
  onLookup;

  const TechnicalPracticalMaterialLookupCard({
    super.key,
    required this.isLoading,
    required this.hasRequested,
    required this.errorMessage,
    required this.materials,
    required this.usesStoredData,
    required this.storedImplementationYear,
    required this.precautions,
    required this.onLookup,
  });

  @override
  State<TechnicalPracticalMaterialLookupCard> createState() =>
      _TechnicalPracticalMaterialLookupCardState();
}

class _TechnicalPracticalMaterialLookupCardState
    extends State<TechnicalPracticalMaterialLookupCard> {
  final TextEditingController _yearController = TextEditingController(
    text: '2026',
  );
  final TextEditingController _sequenceController = TextEditingController(
    text: '1',
  );

  bool _isExpanded = true;
  String? _inputError;

  @override
  void dispose() {
    _yearController.dispose();
    _sequenceController.dispose();
    super.dispose();
  }

  Future<void> _handleLookup() async {
    FocusScope.of(context).unfocus();

    final year = _yearController.text.trim();
    final sequence = _sequenceController.text.trim();

    if (!RegExp(r'^\d{4}$').hasMatch(year)) {
      setState(() {
        _inputError = '시행년도는 4자리 숫자로 입력해주세요.';
      });
      return;
    }

    final sequenceNumber = int.tryParse(sequence);
    if (sequenceNumber == null || sequenceNumber <= 0) {
      setState(() {
        _inputError = '시행회차는 1 이상의 숫자로 입력해주세요.';
      });
      return;
    }

    setState(() {
      _inputError = null;
    });

    await widget.onLookup(
      implementationYear: year,
      implementationSequence: sequenceNumber.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: certificateCardDecoration(context: context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Icon(
                    Icons.handyman_outlined,
                    color: context.colors.pinkDeep,
                    size: 22,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '실기시험 지참 준비물',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: context.colors.textSecondary,
                      size: 27,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: context.colors.border),
                  SizedBox(height: 16),
                  if (widget.usesStoredData)
                    Text(
                      widget.storedImplementationYear == null
                          ? '저장된 실기시험 지참 준비물입니다.'
                          : '${widget.storedImplementationYear}년 기준으로 저장된 실기시험 지참 준비물입니다.',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    )
                  else ...[
                    Text(
                      '시행년도와 시행회차를 입력해 현재 자격증의 실기시험 지참 준비물을 조회합니다.\n'
                      '실기시험 지참 준비물이 있는 경우에만 조회할 수 있습니다.',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _PracticalMaterialInput(
                            controller: _yearController,
                            label: '시행년도',
                            hintText: '2026',
                            maxLength: 4,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _PracticalMaterialInput(
                            controller: _sequenceController,
                            label: '시행회차',
                            hintText: '1',
                            maxLength: 3,
                          ),
                        ),
                      ],
                    ),
                    if (_inputError != null) ...[
                      SizedBox(height: 8),
                      Text(
                        _inputError!,
                        style: TextStyle(
                          color: context.colors.pinkDeep,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: widget.isLoading ? null : _handleLookup,
                        style: FilledButton.styleFrom(
                          backgroundColor: context.colors.pinkDeep,
                          disabledBackgroundColor: context.colors.pinkDeep
                              .withValues(alpha: 0.55),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: widget.isLoading
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: context.colors.onPrimary,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    '조회 중...',
                                    style: TextStyle(
                                      color: context.colors.onPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                widget.hasRequested ? '다시 조회하기' : '지참 준비물 조회하기',
                                style: TextStyle(
                                  color: context.colors.onPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                  if (widget.isLoading) ...[
                    SizedBox(height: 18),
                    _ExamSubjectMessage(
                      icon: Icons.hourglass_top_rounded,
                      message: '실기시험 지참 준비물을 조회하고 있습니다.',
                    ),
                  ] else if (widget.errorMessage != null) ...[
                    SizedBox(height: 18),
                    _ExamSubjectMessage(
                      icon: Icons.error_outline_rounded,
                      message: widget.errorMessage!,
                    ),
                  ] else if (widget.hasRequested &&
                      widget.materials.isEmpty) ...[
                    SizedBox(height: 18),
                    _ExamSubjectMessage(
                      icon: Icons.search_off_rounded,
                      message: '조회된 실기시험 지참 준비물이 없습니다.',
                    ),
                  ] else if (widget.materials.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(height: 1, color: context.colors.border),
                    ),
                    _PracticalMaterialsTable(materials: widget.materials),
                    if (widget.precautions.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(height: 1, color: context.colors.border),
                      ),
                      _PracticalMaterialPrecautionsView(
                        precautions: widget.precautions,
                      ),
                    ],
                  ],
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _PracticalMaterialPrecautionsView extends StatelessWidget {
  final PracticalMaterialPrecautions precautions;

  const _PracticalMaterialPrecautionsView({required this.precautions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(precautions.blocks.length, (index) {
        final block = precautions.blocks[index];

        return Padding(
          padding: EdgeInsets.only(
            bottom: index == precautions.blocks.length - 1 ? 0 : 24,
          ),
          child: _PracticalMaterialPrecautionBlockView(block: block),
        );
      }),
    );
  }
}

class _PracticalMaterialPrecautionBlockView extends StatelessWidget {
  final PracticalMaterialPrecautionBlock block;

  const _PracticalMaterialPrecautionBlockView({required this.block});

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case 'table':
        return _PracticalMaterialPrecautionTable(block: block);

      case 'section':
      default:
        return _PracticalMaterialPrecautionSection(block: block);
    }
  }
}

class _PracticalMaterialPrecautionSection extends StatelessWidget {
  final PracticalMaterialPrecautionBlock block;

  const _PracticalMaterialPrecautionSection({required this.block});

  @override
  Widget build(BuildContext context) {
    if (block.items.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          block.title.isEmpty ? '주의사항' : block.title,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 12),
        ...List.generate(block.items.length, (index) {
          final item = block.items[index];

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == block.items.length - 1 ? 0 : 10,
            ),
            child: _PracticalMaterialPrecautionItemView(item: item),
          );
        }),
      ],
    );
  }
}

class _PracticalMaterialPrecautionItemView extends StatelessWidget {
  final PracticalMaterialPrecautionItem item;
  final bool showBullet;

  const _PracticalMaterialPrecautionItemView({
    required this.item,
    this.showBullet = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = _textColor(context, item.type);
    final fontWeight = _fontWeight(item.type);

    if (!showBullet) {
      return Text(
        item.text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: fontWeight,
          height: 1.55,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 8),
          child: Icon(Icons.circle, size: 5, color: textColor),
        ),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            item.text,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: fontWeight,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }

  static Color _textColor(BuildContext context, String type) {
    switch (type) {
      case 'disqualification':
      case 'zeroScore':
        return context.colors.incorrect;

      case 'warning':
        return context.colors.pinkDeep;

      case 'prohibited':
        return context.colors.textPrimary;

      case 'normal':
      default:
        return context.colors.textSecondary;
    }
  }

  static FontWeight _fontWeight(String type) {
    switch (type) {
      case 'disqualification':
      case 'zeroScore':
      case 'warning':
        return FontWeight.w700;

      case 'prohibited':
        return FontWeight.w600;

      case 'normal':
      default:
        return FontWeight.w500;
    }
  }
}

class _PracticalMaterialPrecautionTable extends StatelessWidget {
  final PracticalMaterialPrecautionBlock block;

  const _PracticalMaterialPrecautionTable({required this.block});

  @override
  Widget build(BuildContext context) {
    if (block.rows.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          block.title.isEmpty ? '주의사항' : block.title,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 13),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 930,
              child: Table(
                border: TableBorder.all(color: context.colors.border, width: 1),
                columnWidths: {
                  0: FixedColumnWidth(58),
                  1: FixedColumnWidth(130),
                  2: FixedColumnWidth(155),
                  3: FixedColumnWidth(587),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  _buildHeaderRow(context),
                  ...List.generate(
                    block.rows.length,
                    (index) => _buildDataRow(
                      context: context,
                      row: block.rows[index],
                      previousRow: index == 0 ? null : block.rows[index - 1],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (block.footerNotes.isNotEmpty) ...[
          SizedBox(height: 14),
          ...List.generate(block.footerNotes.length, (index) {
            final item = block.footerNotes[index];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == block.footerNotes.length - 1 ? 0 : 9,
              ),
              child: _PracticalMaterialPrecautionItemView(item: item),
            );
          }),
        ],
      ],
    );
  }

  TableRow _buildHeaderRow(BuildContext context) {
    final columns = block.columns.length >= 4
        ? block.columns
        : ['순번', '구분', '세부 구분', '세부기준'];

    return TableRow(
      decoration: BoxDecoration(
        color: context.colors.pinkSoft.withValues(alpha: 0.7),
      ),
      children: [
        _buildHeaderCell(context, columns[0]),
        _buildHeaderCell(context, columns[1]),
        _buildHeaderCell(context, columns[2]),
        _buildHeaderCell(context, columns[3]),
      ],
    );
  }

  TableRow _buildDataRow({
    required BuildContext context,
    required PracticalMaterialPrecautionRow row,
    required PracticalMaterialPrecautionRow? previousRow,
  }) {
    final isSameGroup = row.group.isNotEmpty && previousRow?.group == row.group;

    return TableRow(
      children: [
        _buildCell(
          Text(
            row.number?.toString() ?? '-',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _buildCell(
          isSameGroup
              ? SizedBox.shrink()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      row.group.isEmpty ? '-' : row.group,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                    if (row.groupNote.isNotEmpty) ...[
                      SizedBox(height: 5),
                      Text(
                        row.groupNote,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.incorrect,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        _buildCell(
          Text(
            row.category.isEmpty ? '-' : row.category,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ),
        _buildCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(row.contents.length, (index) {
              final item = row.contents[index];

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == row.contents.length - 1 ? 0 : 7,
                ),
                child: _PracticalMaterialPrecautionItemView(
                  item: item,
                  showBullet: false,
                ),
              );
            }),
          ),
          alignment: Alignment.centerLeft,
        ),
      ],
    );
  }

  Widget _buildHeaderCell(BuildContext context, String text) {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.colors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildCell(Widget child, {Alignment alignment = Alignment.center}) {
    return Container(
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: 11, vertical: 13),
      child: child,
    );
  }
}

class _PracticalMaterialInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final int maxLength;

  const _PracticalMaterialInput({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      maxLength: maxLength,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        counterText: '',
        filled: true,
        fillColor: context.colors.surfaceMuted,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.pinkDeep, width: 1.4),
        ),
      ),
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PracticalMaterialsTable extends StatelessWidget {
  final List<TechnicalPracticalExamMaterial> materials;

  const _PracticalMaterialsTable({required this.materials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          horizontalMargin: 14,
          columnSpacing: 22,
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 100,
          headingRowColor: WidgetStateProperty.all(
            context.colors.pinkSoft.withValues(alpha: 0.7),
          ),
          border: TableBorder(
            horizontalInside: BorderSide(color: context.colors.border),
            verticalInside: BorderSide(color: context.colors.border),
          ),
          columns: [
            DataColumn(
              numeric: true,
              label: _PracticalMaterialTableHeader(text: '번호'),
            ),
            DataColumn(label: _PracticalMaterialTableHeader(text: '준비물명')),
            DataColumn(label: _PracticalMaterialTableHeader(text: '규격')),
            DataColumn(label: _PracticalMaterialTableHeader(text: '단위')),
            DataColumn(label: _PracticalMaterialTableHeader(text: '수량')),
            DataColumn(label: _PracticalMaterialTableHeader(text: '비고')),
          ],
          rows: List.generate(materials.length, (index) {
            final material = materials[index];

            return DataRow(
              cells: [
                DataCell(Text('${index + 1}', style: _cellTextStyle(context))),
                DataCell(
                  SizedBox(
                    width: 130,
                    child: Text(
                      _displayValue(material.materialName),
                      style: _importantCellTextStyle(context),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 180,
                    child: Text(
                      _displayValue(material.specification),
                      style: _cellTextStyle(context),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 60,
                    child: Text(
                      _displayValue(material.unitCode),
                      style: _cellTextStyle(context),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 60,
                    child: Text(
                      _displayValue(material.commonUseQuantity),
                      style: _cellTextStyle(context),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 190,
                    child: Text(
                      _buildRemark(material),
                      style: _cellTextStyle(context),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  static String _buildRemark(TechnicalPracticalExamMaterial material) {
    final values = <String>[
      if (material.standardRemark.trim().isNotEmpty)
        material.standardRemark.trim(),
      if (material.selectionFieldName.trim().isNotEmpty &&
          material.selectionFieldName.trim() != '선택분야없음')
        '선택분야: ${material.selectionFieldName.trim()}',
      if (material.drawingYn.trim().isNotEmpty)
        material.drawingYn.trim().toUpperCase() == 'Y' ? '도면 있음' : '도면 없음',
    ];

    return values.isEmpty ? '-' : values.join('\n');
  }

  static String _displayValue(String value) {
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? '-' : trimmedValue;
  }

  static TextStyle _cellTextStyle(BuildContext context) => TextStyle(
    color: context.colors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  static TextStyle _importantCellTextStyle(BuildContext context) => TextStyle(
    color: context.colors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.45,
  );
}

class _PracticalMaterialTableHeader extends StatelessWidget {
  final String text;

  const _PracticalMaterialTableHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _TechnicalPracticalMaterialItem extends StatelessWidget {
  final TechnicalPracticalExamMaterial material;

  const _TechnicalPracticalMaterialItem({required this.material});

  @override
  Widget build(BuildContext context) {
    final detailItems = <CertificateInfoItem>[
      if (material.examDate.isNotEmpty)
        CertificateInfoItem(label: '시험일', value: material.formattedExamDate),
      if (material.quantityText.isNotEmpty)
        CertificateInfoItem(label: '수량', value: material.quantityText),
      if (material.specification.isNotEmpty)
        CertificateInfoItem(label: '규격', value: material.specification),
      if (material.standardRemark.isNotEmpty)
        CertificateInfoItem(label: '비고', value: material.standardRemark),
      if (material.selectionFieldName.isNotEmpty &&
          material.selectionFieldName != '선택분야없음')
        CertificateInfoItem(label: '선택분야', value: material.selectionFieldName),
      if (material.drawingYn.isNotEmpty)
        CertificateInfoItem(
          label: '도면 여부',
          value: material.drawingYn == 'Y' ? '있음' : '없음',
        ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.pinkSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            material.materialName.isEmpty ? '지참 준비물' : material.materialName,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (material.implementationPlanName.isNotEmpty) ...[
            SizedBox(height: 6),
            Text(
              material.implementationPlanName,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
          if (detailItems.isNotEmpty) ...[
            SizedBox(height: 14),
            ...List.generate(
              detailItems.length,
              (index) => Padding(
                padding: EdgeInsets.only(
                  bottom: index == detailItems.length - 1 ? 0 : 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(
                        detailItems[index].label,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        detailItems[index].value,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TechnicalCertificateStatisticsSection extends StatelessWidget {
  final int baseYear;

  final bool isLoadingWritten;
  final String? writtenError;
  final List<TechnicalExamStatistic> writtenStatistics;
  final VoidCallback onRetryWritten;

  final bool isLoadingPractical;
  final String? practicalError;
  final List<TechnicalExamStatistic> practicalStatistics;
  final VoidCallback onRetryPractical;

  const TechnicalCertificateStatisticsSection({
    super.key,
    required this.baseYear,
    required this.isLoadingWritten,
    required this.writtenError,
    required this.writtenStatistics,
    required this.onRetryWritten,
    required this.isLoadingPractical,
    required this.practicalError,
    required this.practicalStatistics,
    required this.onRetryPractical,
  });

  @override
  Widget build(BuildContext context) {
    final hasTableData =
        writtenStatistics.isNotEmpty || practicalStatistics.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$baseYear년 기준 최근 5개년 통계',
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 12),
        TechnicalExamStatisticsCard(
          title: '필기시험 현황',
          icon: Icons.edit_note_rounded,
          isLoading: isLoadingWritten,
          errorMessage: writtenError,
          statistics: writtenStatistics,
          emptyMessage: '해당 종목의 필기시험 통계가 없습니다.',
          onRetry: onRetryWritten,
        ),
        SizedBox(height: 14),
        TechnicalExamStatisticsCard(
          title: '실기시험 현황',
          icon: Icons.build_outlined,
          isLoading: isLoadingPractical,
          errorMessage: practicalError,
          statistics: practicalStatistics,
          emptyMessage: '해당 종목의 실기시험 통계가 없습니다.',
          onRetry: onRetryPractical,
        ),
        if (hasTableData) ...[
          SizedBox(height: 14),
          TechnicalExamStatisticsTablesCard(
            writtenStatistics: writtenStatistics,
            practicalStatistics: practicalStatistics,
          ),
        ],
      ],
    );
  }
}

class TechnicalExamStatisticsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isLoading;
  final String? errorMessage;
  final List<TechnicalExamStatistic> statistics;
  final String emptyMessage;
  final VoidCallback onRetry;

  const TechnicalExamStatisticsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.isLoading,
    required this.errorMessage,
    required this.statistics,
    required this.emptyMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _StatisticsCardShell(
      title: title,
      icon: icon,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return _StatisticsLoading();
    }

    if (errorMessage != null) {
      return _StatisticsError(message: errorMessage!, onRetry: onRetry);
    }

    if (statistics.isEmpty) {
      return _StatisticsEmpty(message: emptyMessage);
    }

    return TechnicalExamStatisticsLineChart(statistics: statistics);
  }
}

class TechnicalExamStatisticsTablesCard extends StatelessWidget {
  final List<TechnicalExamStatistic> writtenStatistics;
  final List<TechnicalExamStatistic> practicalStatistics;

  const TechnicalExamStatisticsTablesCard({
    super.key,
    required this.writtenStatistics,
    required this.practicalStatistics,
  });

  @override
  Widget build(BuildContext context) {
    return _StatisticsCardShell(
      title: '연도별 합격 현황',
      icon: Icons.table_chart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (writtenStatistics.isNotEmpty)
            _ExamStatisticsTable(title: '필기', statistics: writtenStatistics),
          if (writtenStatistics.isNotEmpty && practicalStatistics.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Divider(height: 1, color: context.colors.border),
            ),
          if (practicalStatistics.isNotEmpty)
            _ExamStatisticsTable(title: '실기', statistics: practicalStatistics),
        ],
      ),
    );
  }
}

class _ExamStatisticsTable extends StatelessWidget {
  final String title;
  final List<TechnicalExamStatistic> statistics;

  const _ExamStatisticsTable({required this.title, required this.statistics});

  @override
  Widget build(BuildContext context) {
    final sortedStatistics = [...statistics]
      ..sort((a, b) => b.year.compareTo(a.year));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _ExamStatisticsTableRow(
                isHeader: true,
                year: '연도',
                examineeCount: '응시수',
                passerCount: '합격수',
                passRate: '합격률',
              ),
              ...List.generate(sortedStatistics.length, (index) {
                final statistic = sortedStatistics[index];

                return _ExamStatisticsTableRow(
                  year: '${statistic.year}',
                  examineeCount: '${_formatCount(statistic.examineeCount)}명',
                  passerCount: '${_formatCount(statistic.passerCount)}명',
                  passRate: '${statistic.passRate.toStringAsFixed(1)}%',
                  showTopBorder: true,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExamStatisticsTableRow extends StatelessWidget {
  final bool isHeader;
  final String year;
  final String examineeCount;
  final String passerCount;
  final String passRate;
  final bool showTopBorder;

  const _ExamStatisticsTableRow({
    this.isHeader = false,
    required this.year,
    required this.examineeCount,
    required this.passerCount,
    required this.passRate,
    this.showTopBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: isHeader
          ? context.colors.textPrimary
          : context.colors.textSecondary,
      fontSize: isHeader ? 12 : 11,
      fontWeight: isHeader ? FontWeight.w800 : FontWeight.w600,
    );

    return Container(
      decoration: BoxDecoration(
        color: isHeader
            ? context.colors.pinkSoft.withValues(alpha: 0.55)
            : context.colors.surface,
        border: showTopBorder
            ? Border(top: BorderSide(color: context.colors.border))
            : null,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 17,
            child: Text(year, textAlign: TextAlign.center, style: textStyle),
          ),
          Expanded(
            flex: 28,
            child: Text(
              examineeCount,
              textAlign: TextAlign.center,
              style: textStyle,
            ),
          ),
          Expanded(
            flex: 28,
            child: Text(
              passerCount,
              textAlign: TextAlign.center,
              style: textStyle,
            ),
          ),
          Expanded(
            flex: 27,
            child: Text(
              passRate,
              textAlign: TextAlign.center,
              style: textStyle.copyWith(
                color: isHeader
                    ? context.colors.textPrimary
                    : context.colors.pinkDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsCardShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _StatisticsCardShell({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.colors.pinkDeep, size: 22),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Divider(height: 1, color: context.colors.border),
          SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _StatisticsLoading extends StatelessWidget {
  const _StatisticsLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.colors.pinkDeep,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '조회 중...',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticsEmpty extends StatelessWidget {
  final String message;

  const _StatisticsEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _StatisticsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _StatisticsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: context.colors.pinkDeep,
            size: 30,
          ),
          SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.pinkDeep,
              side: BorderSide(color: context.colors.pinkDeep),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            icon: Icon(Icons.refresh_rounded, size: 18),
            label: Text('다시 조회', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

String _formatCount(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
}

class TechnicalExamStatisticsLineChart extends StatelessWidget {
  final List<TechnicalExamStatistic> statistics;

  const TechnicalExamStatisticsLineChart({super.key, required this.statistics});

  @override
  Widget build(BuildContext context) {
    if (statistics.isEmpty) {
      return SizedBox.shrink();
    }

    final sortedStatistics = [...statistics]
      ..sort((a, b) => a.year.compareTo(b.year));

    final maximumValue = sortedStatistics.fold<double>(0, (maximum, statistic) {
      final currentMaximum = [
        statistic.registrationCount,
        statistic.examineeCount,
        statistic.passerCount,
      ].reduce((a, b) => a > b ? a : b);

      return currentMaximum > maximum ? currentMaximum.toDouble() : maximum;
    });

    final chartMaximumY = maximumValue <= 0 ? 10.0 : maximumValue * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatisticsChartLegend(
          items: [
            _StatisticsLegendItem(label: '접수자', color: context.colors.pinkDeep),
            _StatisticsLegendItem(label: '응시자', color: context.colors.info),
            _StatisticsLegendItem(label: '합격자', color: context.colors.correct),
          ],
        ),
        SizedBox(height: 20),
        SizedBox(
          height: 290,
          child: Padding(
            padding: EdgeInsets.only(left: 4, right: 12, top: 8),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (sortedStatistics.length - 1).toDouble(),
                minY: 0,
                maxY: chartMaximumY,
                clipData: FlClipData(
                  top: false,
                  bottom: false,
                  left: false,
                  right: false,
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _calculateChartInterval(chartMaximumY),
                  getDrawingHorizontalLine: (_) {
                    return FlLine(color: context.colors.border, strokeWidth: 1);
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0) {
                          return SizedBox.shrink();
                        }

                        final index = value.toInt();
                        if (index < 0 || index >= sortedStatistics.length) {
                          return SizedBox.shrink();
                        }

                        return Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '${sortedStatistics[index].year}',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      interval: _calculateChartInterval(chartMaximumY),
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Text(
                            _formatCompactNumber(value),
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final labels = ['접수자', '응시자', '합격자'];

                        final statisticIndex = spot.x.round();
                        final statistic =
                            statisticIndex >= 0 &&
                                statisticIndex < sortedStatistics.length
                            ? sortedStatistics[statisticIndex]
                            : null;

                        final passRateText =
                            spot.barIndex == 2 && statistic != null
                            ? '\n합격률 '
                                  '${statistic.passRate.toStringAsFixed(1)}%'
                            : '';

                        return LineTooltipItem(
                          '${labels[spot.barIndex]}\n'
                          '${_formatCount(spot.y.round())}명'
                          '$passRateText',
                          TextStyle(
                            color: spot.bar.color ?? context.colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  _buildStatisticsLine(
                    statistics: sortedStatistics,
                    color: context.colors.pinkDeep,
                    dotColor: context.colors.surface,
                    valueSelector: (item) => item.registrationCount,
                  ),
                  _buildStatisticsLine(
                    statistics: sortedStatistics,
                    color: context.colors.info,
                    dotColor: context.colors.surface,
                    valueSelector: (item) => item.examineeCount,
                  ),
                  _buildStatisticsLine(
                    statistics: sortedStatistics,
                    color: context.colors.correct,
                    dotColor: context.colors.surface,
                    valueSelector: (item) => item.passerCount,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static LineChartBarData _buildStatisticsLine({
    required List<TechnicalExamStatistic> statistics,
    required Color color,
    required Color dotColor,
    required int Function(TechnicalExamStatistic item) valueSelector,
  }) {
    return LineChartBarData(
      isCurved: false,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: dotColor,
            strokeWidth: 2,
            strokeColor: color,
          );
        },
      ),
      belowBarData: BarAreaData(show: false),
      spots: List.generate(statistics.length, (index) {
        return FlSpot(
          index.toDouble(),
          valueSelector(statistics[index]).toDouble(),
        );
      }),
    );
  }

  static double _calculateChartInterval(double maximumY) {
    if (maximumY <= 10) return 2;
    if (maximumY <= 100) return 20;
    if (maximumY <= 1000) return 200;
    if (maximumY <= 10000) return 2000;
    if (maximumY <= 100000) return 20000;
    return maximumY / 5;
  }

  static String _formatCompactNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}백만';
    }
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}만';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}천';
    }
    return value.round().toString();
  }
}

class _StatisticsChartLegend extends StatelessWidget {
  final List<_StatisticsLegendItem> items;

  const _StatisticsChartLegend({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 6),
            Text(
              item.label,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _StatisticsLegendItem {
  final String label;
  final Color color;

  const _StatisticsLegendItem({required this.label, required this.color});
}
