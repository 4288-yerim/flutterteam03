import 'package:flutter/material.dart';

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
  State<TechnicalScheduleCard> createState() =>
      _TechnicalScheduleCardState();
}

class _TechnicalScheduleCardState
    extends State<TechnicalScheduleCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final items = <CertificateInfoItem>[
      if (_hasDate(
        widget.writtenRegistrationStartAt,
        widget.writtenRegistrationEndAt,
      ))
        CertificateInfoItem(
          label: '필기 원서접수',
          value: _formatDateRange(
            widget.writtenRegistrationStartAt,
            widget.writtenRegistrationEndAt,
          ),
        ),
      if (_hasDate(
        widget.writtenExamStartAt,
        widget.writtenExamEndAt,
      ))
        CertificateInfoItem(
          label: '필기시험',
          value: _formatDateRange(
            widget.writtenExamStartAt,
            widget.writtenExamEndAt,
          ),
        ),
      if (widget.writtenPassAt != null)
        CertificateInfoItem(
          label: '필기 합격 발표',
          value: _formatDate(
            widget.writtenPassAt!,
          ),
        ),
      if (_hasDate(
        widget.documentSubmitStartAt,
        widget.documentSubmitEndAt,
      ))
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
      if (_hasDate(
        widget.practicalExamStartAt,
        widget.practicalExamEndAt,
      ))
        CertificateInfoItem(
          label: '실기시험',
          value: _formatDateRange(
            widget.practicalExamStartAt,
            widget.practicalExamEndAt,
          ),
        ),
      if (_hasDate(
        widget.practicalPassStartAt,
        widget.practicalPassEndAt,
      ))
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
      decoration: certificateCardDecoration(),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title.isEmpty
                          ? '시험 일정'
                          : widget.title,
                      style: const TextStyle(
                        color: certificateDarkText,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(
                      milliseconds: 200,
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: certificateGrayText,
                      size: 27,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(
              width: double.infinity,
              height: 0,
            ),
            secondChild: items.isEmpty
                ? const SizedBox.shrink()
                : Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                0,
                20,
                20,
              ),
              child: Column(
                children: [
                  const Divider(
                    height: 1,
                    color: certificateBorderColor,
                  ),
                  const SizedBox(height: 18),
                  ...List.generate(
                    items.length,
                        (index) {
                      final item = items[index];

                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 108,
                                child: Text(
                                  item.label,
                                  style: const TextStyle(
                                    color:
                                    certificateGrayText,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.value,
                                  style: const TextStyle(
                                    color:
                                    certificateDarkText,
                                    fontSize: 14,
                                    fontWeight:
                                    FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (index !=
                              items.length - 1)
                            const Padding(
                              padding:
                              EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              child: Divider(
                                height: 1,
                                color:
                                certificateBorderColor,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(
              milliseconds: 200,
            ),
          ),
        ],
      ),
    );
  }

  static bool _hasDate(
      DateTime? startDate,
      DateTime? endDate,
      ) {
    return startDate != null || endDate != null;
  }

  static String _formatDateRange(
      DateTime? startDate,
      DateTime? endDate,
      ) {
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
    final month = localDate.month
        .toString()
        .padLeft(2, '0');
    final day = localDate.day
        .toString()
        .padLeft(2, '0');

    return '$year.$month.$day';
  }
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
                _ExamFeeRow(
                  label: '필기',
                  fee: writtenFee!,
                ),
              if (writtenFee != null &&
                  practicalFee != null)
                const SizedBox(height: 10),
              if (practicalFee != null)
                _ExamFeeRow(
                  label: '실기',
                  fee: practicalFee!,
                ),
            ],
          ),
        ),
      if (examTrends.trim().isNotEmpty)
        _TechnicalExamInformationSection(
          title: '출제경향',
          child: Text(
            _formatStructuredContents(examTrends),
            style: const TextStyle(
              color: certificateDarkText,
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
            style: const TextStyle(
              color: certificateDarkText,
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
            const Text(
              '출제기준은 Q-Net 출제기준에서 확인 바랍니다.',
              style: TextStyle(
                color: certificateDarkText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onOpenExamStandard,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: certificatePinkSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Q-Net에서 출제기준 확인하기',
                        style: TextStyle(
                          color: certificatePrimaryPink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 7),
                      Icon(
                        Icons.open_in_new_rounded,
                        color: certificatePrimaryPink,
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
            const Text(
              '그외 사항은 Q-Net에서 확인 바랍니다.',
              style: TextStyle(
                color: certificateDarkText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onOpenOtherInformation,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: certificatePinkSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Q-Net에서 상세정보 확인하기',
                        style: TextStyle(
                          color: certificatePrimaryPink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 7),
                      Icon(
                        Icons.open_in_new_rounded,
                        color: certificatePrimaryPink,
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
      padding: const EdgeInsets.all(20),
      decoration: certificateCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          sections.length,
              (index) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sections[index],
                if (index != sections.length - 1)
                  const Padding(
                    padding:
                    EdgeInsets.symmetric(vertical: 20),
                    child: Divider(
                      height: 1,
                      color: certificateBorderColor,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
  static String _formatStructuredContents(
      String contents,
      ) {
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
      formatted = formatted.replaceAll(
        number,
        '\n$number ',
      );
    }

    formatted = formatted.replaceAllMapped(
      RegExp(r'(\d{1,2})\.\s*'),
          (match) {
        return '\n${match.group(1)}. ';
      },
    );

    formatted = formatted.replaceAllMapped(
      RegExp(r'<([^>]+)>'),
          (match) {
        return '\n<${match.group(1)}>\n';
      },
    );

    formatted = formatted.replaceAll(
      RegExp(r'\n{3,}'),
      '\n\n',
    );

    return formatted.trim();
  }
}

class _TechnicalExamInformationSection
    extends StatelessWidget {
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
          style: const TextStyle(
            color: certificateDarkText,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 13),
        child,
      ],
    );
  }
}

class _ExamFeeRow extends StatelessWidget {
  final String label;
  final int fee;

  const _ExamFeeRow({
    required this.label,
    required this.fee,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: const TextStyle(
              color: certificateDarkText,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            '${_formatFee(fee)}원',
            style: const TextStyle(
              color: certificateDarkText,
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

  const CertificateScheduleNoticeCard({
    super.key,
    required this.onOpenNotice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: certificateCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: certificatePrimaryPink,
                size: 21,
              ),
              SizedBox(width: 9),
              Text(
                '시험 일정 안내',
                style: TextStyle(
                  color: certificateDarkText,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          const _ScheduleNoticeRow(
            text:
            '원서접수 시간은 원서접수 첫날 10:00부터 마지막 날 18:00까지입니다.',
          ),
          const SizedBox(height: 11),
          const _ScheduleNoticeRow(
            text:
            '필기시험 합격예정자 및 최종합격자 발표 시간은 해당 발표일 09:00입니다.',
          ),
          const SizedBox(height: 11),
          const _ScheduleNoticeRow(
            text:
            '시험 일정은 종목별, 지역별로 상이할 수 있습니다.',
          ),
          const SizedBox(height: 11),
          const _ScheduleNoticeRow(
            text:
            '접수 일정 전에 공지되는 해당 회별 수험자 안내(Q-Net 공지사항 게시)를 반드시 확인해야 합니다.',
          ),
          const SizedBox(height: 17),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: onOpenNotice,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: certificatePinkSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Q-Net에서 공지사항 확인하기',
                      style: TextStyle(
                        color: certificatePrimaryPink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 7),
                    Icon(
                      Icons.open_in_new_rounded,
                      color: certificatePrimaryPink,
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

  const _ScheduleNoticeRow({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Icon(
            Icons.circle,
            size: 5,
            color: certificateGrayText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: certificateDarkText,
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
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: certificateCardDecoration(),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    color: certificatePrimaryPink,
                    size: 22,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      '시험 교시·과목 정보',
                      style: TextStyle(
                        color: certificateDarkText,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(
                      milliseconds: 200,
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: certificateGrayText,
                      size: 27,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(
              width: double.infinity,
              height: 0,
            ),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                0,
                20,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(
                    height: 1,
                    color: certificateBorderColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '현재 자격증의 시험 과목, 교시, 문항 수와 시험시간을 조회합니다.\n'
                        '차수는 대체로 1차는 필기, 2차는 실기/면접입니다.',
                    style: TextStyle(
                      color: certificateGrayText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 17),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                      widget.isLoading ? null : widget.onLookup,
                      style: FilledButton.styleFrom(
                        backgroundColor: certificatePrimaryPink,
                        disabledBackgroundColor:
                        certificatePrimaryPink.withValues(
                          alpha: 0.55,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: widget.isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        widget.hasRequested
                            ? '다시 조회하기'
                            : '과목 조회하기',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (widget.errorMessage != null) ...[
                    const SizedBox(height: 18),
                    _ExamSubjectMessage(
                      icon: Icons.error_outline_rounded,
                      message: widget.errorMessage!,
                    ),
                  ] else if (widget.hasRequested &&
                      widget.subjects.isEmpty) ...[
                    const SizedBox(height: 18),
                    const _ExamSubjectMessage(
                      icon: Icons.search_off_rounded,
                      message: '조회된 시험 교시·과목 정보가 없습니다.',
                    ),
                  ] else if (widget.subjects.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 20,
                      ),
                      child: Divider(
                        height: 1,
                        color: certificateBorderColor,
                      ),
                    ),
                    ...List.generate(
                      widget.subjects.length,
                          (index) => Padding(
                        padding: EdgeInsets.only(
                          bottom:
                          index == widget.subjects.length - 1
                              ? 0
                              : 12,
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
            duration: const Duration(
              milliseconds: 200,
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicalExamSubjectItem extends StatelessWidget {
  final TechnicalExamSubject subject;

  const _TechnicalExamSubjectItem({
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    final items = <CertificateInfoItem>[
      if (subject.detailTypeName.isNotEmpty)
        CertificateInfoItem(
          label: '세부유형',
          value: subject.detailTypeName,
        ),
      if (subject.sequenceNumber != null)
        CertificateInfoItem(
          label: '차수',
          value: '${subject.sequenceNumber}차',
        ),
      if (subject.lessonNumber != null)
        CertificateInfoItem(
          label: '교시',
          value: '${subject.lessonNumber}교시',
        ),
      if (subject.requiredSubjectName.isNotEmpty)
        CertificateInfoItem(
          label: '필수 여부',
          value: subject.requiredSubjectName,
        ),
      if (subject.questionCount != null)
        CertificateInfoItem(
          label: '문항 수',
          value: '${subject.questionCount}문항',
        ),
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
        CertificateInfoItem(
          label: '선택분야',
          value: subject.selectionFieldName,
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: certificatePinkSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: certificateBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subject.subjectName.isEmpty ? '과목 정보' : subject.subjectName,
            style: const TextStyle(
              color: certificateDarkText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 14),
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
                        style: const TextStyle(
                          color: certificateGrayText,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        items[index].value,
                        style: const TextStyle(
                          color: certificateDarkText,
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

  const _ExamSubjectMessage({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: certificatePinkSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: certificatePrimaryPink,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: certificateDarkText,
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
