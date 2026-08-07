import 'package:flutter/material.dart';

import '../../theme.dart';
import 'package:flutter/services.dart';

import '../services/technical_certificate_service.dart';
import 'certificate_common_widgets.dart';
import 'certificate_detail_widgets.dart';



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
            text: '원서 접수 시간은 원서 접수 첫날 10:00부터 마지막 날 18:00까지입니다.',
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
            text: '빈자리 원서 접수 기간이 운영될 수 있으나, 자격증 상세보기에는 표시되지 않을 수 있습니다.',
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
                      '실기/면접 시험 지참 준비물',
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
                          ? '저장된 실기/면접 시험 지참 준비물입니다.'
                          : '${widget.storedImplementationYear}년 기준으로 저장된 실기/면접 시험 지참 준비물입니다.',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    )
                  else ...[
                    Text(
                      '시행년도와 시행회차를 입력해 현재 자격증의 실기/면접 시험 지참 준비물을 조회합니다.\n'
                      '실기/면접 시험 지참 준비물이 있는 경우에만 조회할 수 있습니다.',
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
                      message: '실기/면접 시험 지참 준비물을 조회하고 있습니다.',
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
                      message: '조회된 실기/면접 시험 지참 준비물이 없습니다.',
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
