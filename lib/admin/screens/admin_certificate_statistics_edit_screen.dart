import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/app_button.dart';
import '../services/admin_certificate_statistics_service.dart';
import '../widgets/admin_certificate_theme.dart';

class AdminCertificateStatisticsEditScreen extends StatefulWidget {
  const AdminCertificateStatisticsEditScreen({
    super.key,
    required this.certificationId,
    required this.certificateName,
  });

  final String certificationId;
  final String certificateName;

  @override
  State<AdminCertificateStatisticsEditScreen> createState() =>
      _AdminCertificateStatisticsEditScreenState();
}

class _AdminCertificateStatisticsEditScreenState
    extends State<AdminCertificateStatisticsEditScreen>
    with SingleTickerProviderStateMixin {
  final _service = AdminCertificateStatisticsService();
  final Map<AdminCertificateStatisticsType, List<_StatisticRowEditor>>
  _editors = {};
  final Set<AdminCertificateStatisticsType> _dirtyTypes = {};
  late final TabController _tabController;
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  AdminCertificateStatisticsType get _selectedType =>
      AdminCertificateStatisticsType.values[_tabController.index];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: AdminCertificateStatisticsType.values.length,
      vsync: this,
    )..addListener(_handleTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _disposeEditors();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final data = await _service.getStatistics(widget.certificationId);
      if (!mounted) return;
      _disposeEditors();
      final integratedYears = data
          .statisticsByType[AdminCertificateStatisticsType.integrated]!
          .map((entry) => entry.year)
          .toList();
      final templateYears = integratedYears.isEmpty
          ? <int>[DateTime.now().year]
          : integratedYears;
      for (final type in AdminCertificateStatisticsType.values) {
        final entries = data.statisticsByType[type] ?? const [];
        _editors[type] = entries.isNotEmpty
            ? entries.map(_StatisticRowEditor.fromEntry).toList()
            : templateYears
                  .map((year) => _StatisticRowEditor(year: year))
                  .toList();
      }
      setState(() {
        _dirtyTypes.clear();
        _loading = false;
      });
    } on AdminCertificateStatisticsException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _loading = false;
      });
    }
  }

  void _disposeEditors() {
    for (final editors in _editors.values) {
      for (final editor in editors) {
        editor.dispose();
      }
    }
    _editors.clear();
  }

  void _markDirty(AdminCertificateStatisticsType type) {
    if (_dirtyTypes.add(type)) setState(() {});
  }

  void _addYear() {
    final type = _selectedType;
    final editors = _editors[type]!;
    final years = editors
        .map((editor) => int.tryParse(editor.year.text.trim()) ?? 0)
        .where((year) => year > 0);
    final nextYear = years.isEmpty
        ? DateTime.now().year
        : years.reduce((first, second) => first > second ? first : second) + 1;
    setState(() {
      editors.insert(0, _StatisticRowEditor(year: nextYear));
      _dirtyTypes.add(type);
    });
  }

  void _removeRow(int index) {
    final type = _selectedType;
    setState(() {
      _editors[type]!.removeAt(index).dispose();
      _dirtyTypes.add(type);
    });
  }

  Future<void> _save() async {
    if (_dirtyTypes.isEmpty || _saving) return;
    final changes =
        <
          AdminCertificateStatisticsType,
          List<AdminCertificateStatisticEntry>
        >{};
    for (final type in _dirtyTypes) {
      final entries = <AdminCertificateStatisticEntry>[];
      final years = <int>{};
      for (final editor in _editors[type]!) {
        final entry = editor.toEntry();
        if (entry == null) {
          _showMessage('${type.label} 통계의 연도와 인원수를 확인해주세요.');
          return;
        }
        if (!years.add(entry.year)) {
          _showMessage('${type.label} 통계에 같은 연도가 중복되어 있습니다.');
          return;
        }
        entries.add(entry);
      }
      changes[type] = entries;
    }

    setState(() => _saving = true);
    try {
      await _service.saveStatistics(
        certificationId: widget.certificationId,
        statisticsByType: changes,
      );
      if (!mounted) return;
      setState(() => _dirtyTypes.clear());
      _showMessage('통계 정보를 저장했습니다.');
    } on AdminCertificateStatisticsException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AdminCertificateTheme(
      child: Scaffold(
        appBar: AppBar(title: Text('${widget.certificateName} 통계 수정')),
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: '다시 시도',
                type: AppButtonType.outlineAdmin,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: context.colors.surfaceTransparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: context.colors.lavender,
                borderRadius: BorderRadius.circular(12),
              ),
              tabs: [
                for (final type in AdminCertificateStatisticsType.values)
                  Tab(height: 44, text: type.label),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${_selectedType.label} 통계',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '연도별 접수자 수, 응시자 수, 합격자 수를 입력해주세요.',
                style: TextStyle(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 18),
              for (final entry in _editors[_selectedType]!.asMap().entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildRow(entry.key, entry.value),
                ),
              AppButton(
                text: '연도 추가',
                type: AppButtonType.outlineAdmin,
                icon: Icons.add_rounded,
                height: 44,
                onPressed: _addYear,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: AppButton(
            text: _saving ? '저장 중...' : '변경한 통계 저장',
            type: AppButtonType.primaryAdmin,
            onPressed: _saving || _dirtyTypes.isEmpty ? null : _save,
          ),
        ),
      ],
    );
  }

  Widget _buildRow(int index, _StatisticRowEditor editor) {
    final type = _selectedType;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _numberField(editor.year, '연도', type)),
              IconButton(
                tooltip: '연도 삭제',
                onPressed: () => _removeRow(index),
                icon: Icon(
                  Icons.remove_circle_outline_rounded,
                  color: context.colors.incorrect,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _numberField(editor.registrationCount, '접수자 수', type),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _numberField(editor.examineeCount, '응시자 수', type),
              ),
              const SizedBox(width: 8),
              Expanded(child: _numberField(editor.passerCount, '합격자 수', type)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    AdminCertificateStatisticsType type,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (_) => _markDirty(type),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: context.colors.surfaceElevated,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _StatisticRowEditor {
  _StatisticRowEditor({required int year})
    : year = TextEditingController(text: year.toString()),
      registrationCount = TextEditingController(),
      examineeCount = TextEditingController(),
      passerCount = TextEditingController();

  _StatisticRowEditor.fromEntry(AdminCertificateStatisticEntry entry)
    : year = TextEditingController(text: entry.year.toString()),
      registrationCount = TextEditingController(
        text: entry.registrationCount.toString(),
      ),
      examineeCount = TextEditingController(
        text: entry.examineeCount.toString(),
      ),
      passerCount = TextEditingController(text: entry.passerCount.toString());

  final TextEditingController year;
  final TextEditingController registrationCount;
  final TextEditingController examineeCount;
  final TextEditingController passerCount;

  AdminCertificateStatisticEntry? toEntry() {
    final parsedYear = int.tryParse(year.text.trim());
    final registration = _parseCount(registrationCount.text);
    final examinee = _parseCount(examineeCount.text);
    final passer = _parseCount(passerCount.text);
    if (parsedYear == null ||
        parsedYear <= 0 ||
        registration == null ||
        examinee == null ||
        passer == null) {
      return null;
    }
    return AdminCertificateStatisticEntry(
      year: parsedYear,
      registrationCount: registration,
      examineeCount: examinee,
      passerCount: passer,
    );
  }

  static int? _parseCount(String value) {
    final normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) return 0;
    final parsed = int.tryParse(normalized);
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  void dispose() {
    year.dispose();
    registrationCount.dispose();
    examineeCount.dispose();
    passerCount.dispose();
  }
}
