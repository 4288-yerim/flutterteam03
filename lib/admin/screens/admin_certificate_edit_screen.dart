import 'package:flutter/material.dart';

import '../../certificate/services/certificate_category_content_service.dart';
import '../../theme.dart';
import '../../widgets/app_button.dart';
import '../widgets/admin_schedule_date_picker.dart';
import '../widgets/admin_certificate_theme.dart';
import '../services/admin_certificate_service.dart';

class AdminCertificateEditScreen extends StatefulWidget {
  const AdminCertificateEditScreen({super.key, required this.certificationId, required this.mode});
  final String certificationId;
  final AdminCertificateEditMode mode;
  @override
  State<AdminCertificateEditScreen> createState() => _AdminCertificateEditScreenState();
}

class _AdminCertificateEditScreenState extends State<AdminCertificateEditScreen> {
  final _service = AdminCertificateService();
  final _formKey = GlobalKey<FormState>();
  final _feeRound1 = TextEditingController();
  final _feeRound2 = TextEditingController();
  final _trends = TextEditingController();
  final _obtain = TextEditingController();
  List<_LinkEditor> _feeLinks = [];
  List<_LinkEditor> _trendLinks = [];
  List<_LinkEditor> _obtainLinks = [];
  List<_LinkEditor> _scheduleLinks = [];
  List<AdminCertificateScheduleDraft> _schedules = [];
  AdminCertificateEditorData? _data;
  bool _saving = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await _service.getEditorData(widget.certificationId);
      if (!mounted) return;
      _feeRound1.text = data.details['examFee']?['feeRound1']?.toString() ?? '';
      _feeRound2.text = data.details['examFee']?['feeRound2']?.toString() ?? '';
      _trends.text = data.examTrends;
      _obtain.text = data.howToObtain;
      setState(() {
        _data = data;
        _schedules = List.of(data.schedules);
        _feeLinks = _makeEditors(data.details['examFee']);
        _trendLinks = _makeEditors(data.details['examTrends']);
        _obtainLinks = _makeEditors(data.details['howToObtain']);
        _scheduleLinks = _makeEditors(data.details['scheduleLinks']);
      });
    } on AdminCertificateException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  void dispose() {
    for (final controller in [_feeRound1, _feeRound2, _trends, _obtain]) { controller.dispose(); }
    for (final editor in [..._feeLinks, ..._trendLinks, ..._obtainLinks, ..._scheduleLinks]) { editor.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isInformation = widget.mode == AdminCertificateEditMode.information;
    return AdminCertificateTheme(
      child: Scaffold(
        appBar: AppBar(title: Text(isInformation ? '자격정보 수정' : '시험 일정 수정')),
        body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(data.certificate.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          if (isInformation) ..._informationSections() else ..._scheduleSections(),
          const SizedBox(height: 24),
          AppButton(
            text: _saving ? '저장 중...' : '저장',
            type: AppButtonType.primaryAdmin,
            onPressed: _saving ? null : _save,
          ),
        ]),
        ),
      ),
    );
  }

  List<Widget> _informationSections() => [
    _section('응시 수수료', [_field(_feeRound1, '필기/통합 수수료', number: true), const SizedBox(height: 10), _field(_feeRound2, '실기/면접 수수료', number: true), const SizedBox(height: 14), _linkFields(_feeLinks)]),
    const SizedBox(height: 16),
    _section('시험 경향', [_field(_trends, '내용', lines: 5), const SizedBox(height: 14), _linkFields(_trendLinks)]),
    const SizedBox(height: 16),
    _section('취득 방법', [_field(_obtain, '내용', lines: 5), const SizedBox(height: 14), _linkFields(_obtainLinks)]),
  ];

  List<Widget> _scheduleSections() => [
    _section('시험 일정', [
      for (final entry in _schedules.asMap().entries) ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(entry.value.title.isEmpty ? '시험 회차' : entry.value.title),
        trailing: IconButton(
          onPressed: () => setState(() => _schedules.removeAt(entry.key)),
          icon: Icon(
            Icons.close_rounded,
            color: context.colors.incorrect,
          ),
        ),
      ),
      const SizedBox(height: 16),
      AppButton(
        text: '시험 일정 추가',
        type: AppButtonType.outlineAdmin,
        icon: Icons.add_rounded,
        height: 44,
        onPressed: _addSchedule,
      ),
    ]),
    const SizedBox(height: 16),
    _section('시험 일정 링크', [_linkFields(_scheduleLinks)]),
  ];

  Widget _section(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: context.colors.surfaceTransparent, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.colors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 12), ...children]),
  );

  Widget _field(TextEditingController controller, String label, {int lines = 1, bool number = false}) => TextFormField(
    controller: controller, maxLines: lines, keyboardType: number ? TextInputType.number : null,
    decoration: InputDecoration(labelText: label, filled: true, fillColor: context.colors.surfaceElevated, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
  );

  Widget _linkFields(List<_LinkEditor> links) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('링크', style: TextStyle(fontWeight: FontWeight.w700)),
    for (var index = 0; index < links.length; index++) Row(children: [
      Expanded(child: Column(children: [_field(links[index].label, '링크 버튼 문구'), const SizedBox(height: 8), _field(links[index].url, '링크 주소')])),
      IconButton(
        onPressed: () => setState(() {
          if (links.length == 1) {
            links[index].clear();
          } else {
            links.removeAt(index).dispose();
          }
        }),
        icon: Icon(
          Icons.remove_circle_outline_rounded,
          color: context.colors.incorrect,
        ),
      ),
    ]),
    const SizedBox(height: 16),
    AppButton(
      text: '링크 추가',
      type: AppButtonType.outlineAdmin,
      icon: Icons.add_rounded,
      height: 44,
      onPressed: () => setState(() => links.add(_LinkEditor())),
    ),
  ]);

  List<_LinkEditor> _makeEditors(Map<String, dynamic>? detail) {
    final result = (detail?['links'] as List? ?? const []).map(CertificateContentLink.fromMap).map((link) => _LinkEditor(link.label, link.url)).toList();
    return result.isEmpty ? [_LinkEditor()] : result;
  }

  bool _validLinks(Iterable<_LinkEditor> links) => links.every((link) {
    final label = link.label.text.trim(); final url = link.url.text.trim(); final uri = Uri.tryParse(url);
    return label.isEmpty == url.isEmpty && (url.isEmpty || (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')));
  });

  List<Map<String, String>> _maps(Iterable<_LinkEditor> links) => links.where((link) => link.label.text.trim().isNotEmpty).map((link) => {'label': link.label.text.trim(), 'url': link.url.text.trim()}).toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _data == null) return;
    if (!_validLinks([..._feeLinks, ..._trendLinks, ..._obtainLinks, ..._scheduleLinks])) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크 문구와 올바른 http(s) 주소를 모두 입력해주세요.'))); return;
    }
    setState(() => _saving = true);
    final details = Map<String, Map<String, dynamic>>.from(_data!.details);
    details['examFee'] = {'feeRound1': _feeRound1.text.trim(), 'feeRound2': _feeRound2.text.trim(), 'links': _maps(_feeLinks)};
    details['examTrends'] = {'contents': _trends.text, 'links': _maps(_trendLinks)};
    details['howToObtain'] = {'contents': _obtain.text, 'links': _maps(_obtainLinks)};
    details['scheduleLinks'] = {'links': _maps(_scheduleLinks)};
    try {
      await _service.saveEditorData(AdminCertificateEditorData(certificate: _data!.certificate, details: details, schedules: _schedules));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장하지 못했습니다.')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _addSchedule() async {
    final draft = await showDialog<AdminCertificateScheduleDraft>(context: context, builder: (_) => const _ScheduleDialog());
    if (draft != null && mounted) setState(() => _schedules.add(draft));
  }
}

enum AdminCertificateEditMode { information, schedule }

class _LinkEditor {
  _LinkEditor([String label = '', String url = '']) : label = TextEditingController(text: label), url = TextEditingController(text: url);
  final TextEditingController label; final TextEditingController url;
  void clear() { label.clear(); url.clear(); }
  void dispose() { label.dispose(); url.dispose(); }
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog();

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  final _title = TextEditingController();
  DateTime? _writtenRegistrationStart;
  DateTime? _writtenRegistrationEnd;
  DateTime? _writtenExamStart;
  DateTime? _writtenExamEnd;
  DateTime? _writtenPassStart;
  DateTime? _writtenPassEnd;
  DateTime? _practicalRegistrationStart;
  DateTime? _practicalRegistrationEnd;
  DateTime? _practicalExamStart;
  DateTime? _practicalExamEnd;
  DateTime? _practicalPassStart;
  DateTime? _practicalPassEnd;
  DateTime? _documentSubmitStart;
  DateTime? _documentSubmitEnd;

  @override
  void dispose() { _title.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AdminCertificateTheme(
    child: AlertDialog(
    title: const Text('시험 일정 추가'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.lavender,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '단일 시험은 실기/면접을 제외한 필기/통합 일정만 입력해주세요.\n기간이 하루인 경우 시작일만 입력해주세요.',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('회차명'),
          const SizedBox(height: 10),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              hintText: '예: 2026년 정기 기사 1회',
            ),
          ),
          const SizedBox(height: 22),
          _sectionTitle('필기/통합'),
          const SizedBox(height: 10),
          _dateRangeFields(
            startLabel: '원서 접수 시작일',
            startValue: _writtenRegistrationStart,
            onStartChanged: (value) => _writtenRegistrationStart = value,
            endLabel: '원서 접수 마감일',
            endValue: _writtenRegistrationEnd,
            onEndChanged: (value) => _writtenRegistrationEnd = value,
          ),
          _dateRangeFields(
            startLabel: '시험 시작일',
            startValue: _writtenExamStart,
            onStartChanged: (value) => _writtenExamStart = value,
            endLabel: '시험 종료일',
            endValue: _writtenExamEnd,
            onEndChanged: (value) => _writtenExamEnd = value,
          ),
          _dateRangeFields(
            startLabel: '합격자 발표 시작일',
            startValue: _writtenPassStart,
            onStartChanged: (value) => _writtenPassStart = value,
            endLabel: '합격자 발표 마감일',
            endValue: _writtenPassEnd,
            onEndChanged: (value) => _writtenPassEnd = value,
          ),
          const SizedBox(height: 12),
          _sectionTitle('실기/면접'),
          const SizedBox(height: 10),
          _dateRangeFields(
            startLabel: '원서 접수 시작일',
            startValue: _practicalRegistrationStart,
            onStartChanged: (value) => _practicalRegistrationStart = value,
            endLabel: '원서 접수 마감일',
            endValue: _practicalRegistrationEnd,
            onEndChanged: (value) => _practicalRegistrationEnd = value,
          ),
          _dateRangeFields(
            startLabel: '시험 시작일',
            startValue: _practicalExamStart,
            onStartChanged: (value) => _practicalExamStart = value,
            endLabel: '시험 종료일',
            endValue: _practicalExamEnd,
            onEndChanged: (value) => _practicalExamEnd = value,
          ),
          _dateRangeFields(
            startLabel: '합격자 발표 시작일',
            startValue: _practicalPassStart,
            onStartChanged: (value) => _practicalPassStart = value,
            endLabel: '합격자 발표 마감일',
            endValue: _practicalPassEnd,
            onEndChanged: (value) => _practicalPassEnd = value,
          ),
          const SizedBox(height: 12),
          _sectionTitle('서류 제출'),
          const SizedBox(height: 10),
          _dateRangeFields(
            startLabel: '서류 제출 시작일',
            startValue: _documentSubmitStart,
            onStartChanged: (value) => _documentSubmitStart = value,
            endLabel: '서류 제출 종료일',
            endValue: _documentSubmitEnd,
            onEndChanged: (value) => _documentSubmitEnd = value,
          ),
        ]),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
      FilledButton(onPressed: _submit, child: const Text('추가')),
    ],
    ),
  );

  Widget _sectionTitle(String title) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      title,
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _dateRangeFields({
    required String startLabel,
    required DateTime? startValue,
    required ValueChanged<DateTime?> onStartChanged,
    required String endLabel,
    required DateTime? endValue,
    required ValueChanged<DateTime?> onEndChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: _dateField(startLabel, startValue, onStartChanged),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Text('~', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        Expanded(child: _dateField(endLabel, endValue, onEndChanged)),
      ],
    ),
  );

  Widget _dateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      ),
      onPressed: () async {
        final selected = await showDialog<DateTime>(
          context: context,
          builder: (_) => AdminScheduleDatePickerDialog(
            initialDate: value ?? DateTime.now(),
          ),
        );
        if (selected != null) setState(() => onChanged(selected));
      },
      child: Align(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(value == null ? label : _formatDate(value)),
        ),
      ),
    ),
  );

  String _formatDate(DateTime value) => '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';

  void _submit() {
    if (_title.text.trim().isEmpty ||
        _writtenRegistrationStart == null ||
        _writtenExamStart == null ||
        _writtenPassStart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '회차명, 필기/통합 원서 접수 시작일, 시험 시작일, 합격자 발표 시작일은 필수입니다.',
          ),
        ),
      );
      return;
    }
    Navigator.pop(context, AdminCertificateScheduleDraft(
      id: 'admin_${DateTime.now().microsecondsSinceEpoch}', title: _title.text.trim(),
      writtenRegistrationStartAt: _writtenRegistrationStart, writtenRegistrationEndAt: _writtenRegistrationEnd,
      writtenExamStartAt: _writtenExamStart, writtenExamEndAt: _writtenExamEnd,
      writtenPassStartAt: _writtenPassStart, writtenPassEndAt: _writtenPassEnd,
      practicalRegistrationStartAt: _practicalRegistrationStart, practicalRegistrationEndAt: _practicalRegistrationEnd,
      practicalExamStartAt: _practicalExamStart, practicalExamEndAt: _practicalExamEnd,
      practicalPassStartAt: _practicalPassStart, practicalPassEndAt: _practicalPassEnd,
      documentSubmitStartAt: _documentSubmitStart, documentSubmitEndAt: _documentSubmitEnd,
    ));
  }
}
