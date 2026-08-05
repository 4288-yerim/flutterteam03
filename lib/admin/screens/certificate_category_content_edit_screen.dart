import 'package:flutter/material.dart';

import '../../certificate/services/certificate_category_content_service.dart';
import '../../theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../widgets/admin_certificate_theme.dart';

class CertificateCategoryContentEditScreen extends StatefulWidget {
  const CertificateCategoryContentEditScreen({super.key});

  @override
  State<CertificateCategoryContentEditScreen> createState() =>
      _CertificateCategoryContentEditScreenState();
}

class _CertificateCategoryContentEditScreenState
    extends State<CertificateCategoryContentEditScreen>
    with SingleTickerProviderStateMixin {
  final _service = CertificateCategoryContentService();
  late final TabController _tabController;
  late final Map<CertificateCategory, _CategoryNoticeEditor> _editors;
  final _loaded = <CertificateCategory>{};
  final _saving = <CertificateCategory>{};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: CertificateCategory.values.length, vsync: this)
      ..addListener(_handleTabChange);
    _editors = {
      for (final category in CertificateCategory.values)
        category: _CategoryNoticeEditor(),
    };
    _load(CertificateCategory.technical);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    for (final editor in _editors.values) {
      editor.dispose();
    }
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      _load(CertificateCategory.values[_tabController.index]);
    }
  }

  Future<void> _load(CertificateCategory category) async {
    if (_loaded.contains(category)) {
      return;
    }
    try {
      final notice = await _service.getScheduleNotice(category);
      if (!mounted) return;
      _editors[category]!.setNotice(notice);
      setState(() => _loaded.add(category));
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = '시험 일정 안내를 불러오지 못했습니다.');
      }
    }
  }

  Future<void> _save(CertificateCategory category) async {
    final editor = _editors[category]!;
    if (!editor.hasValidLinks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크 문구와 http(s) 링크 주소를 모두 입력해주세요.')),
      );
      return;
    }
    setState(() => _saving.add(category));
    try {
      await _service.saveScheduleNotice(category, editor.toNotice());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시험 일정 안내를 저장했습니다.')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('시험 일정 안내를 저장하지 못했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(category));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminCertificateTheme(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppTopBar(
        title: '자격증 안내 수정',
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.colors.textPrimary,
            size: 21,
          ),
        ),
      ),
        body: AppMainBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
            child: Column(
              children: [
                _buildTabBar(),
                const SizedBox(height: 20),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) => _buildEditor(
                      CertificateCategory.values[_tabController.index],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
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
        labelPadding: EdgeInsets.zero,
        indicator: BoxDecoration(
          color: context.colors.lavender,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: context.colors.lavenderAccent,
        unselectedLabelColor: context.colors.textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(height: 44, text: '국가기술'),
          Tab(height: 44, text: '국가전문'),
          Tab(height: 44, text: '그 외'),
        ],
      ),
    );
  }

  Widget _buildEditor(CertificateCategory category) {
    if (!_loaded.contains(category) && _errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!, style: TextStyle(color: context.colors.incorrect)),
      );
    }
    final isSaving = _saving.contains(category);
    final editor = _editors[category]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_categoryLabel(category)} 시험 일정 안내',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '안내 문구는 한 줄씩 추가하세요. 저장하면 상세 화면에서도 줄마다 불릿 항목으로 표시됩니다.',
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              ...List.generate(editor.itemControllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: editor.itemControllers[index],
                          decoration: _inputDecoration(
                            context,
                            hintText: '안내 문구 ${index + 1}',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '문구 삭제',
                        onPressed: editor.itemControllers.length == 1
                            ? null
                            : () => setState(() => editor.removeItem(index)),
                        icon: Icon(
                          Icons.remove_circle_outline_rounded,
                          color: context.colors.incorrect,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              AppButton(
                onPressed: () => setState(editor.addItem),
                type: AppButtonType.outlineAdmin,
                icon: Icons.add_rounded,
                text: '안내 문구 추가',
                height: 44,
              ),
              const SizedBox(height: 24),
              Text(
                '안내 링크',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(editor.linkEditors.length, (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Expanded(child: Column(children: [
                        TextField(controller: editor.linkEditors[index].label,
                          decoration: _inputDecoration(context, hintText: '링크 버튼 문구'),),
                        const SizedBox(height: 10),
                        TextField(controller: editor.linkEditors[index].url,
                          keyboardType: TextInputType.url,
                          decoration: _inputDecoration(context, hintText: 'https:// 로 시작하는 링크 주소'),),
                      ])),
                      IconButton(
                        tooltip: '링크 삭제',
                        onPressed: () => setState(() {
                          if (editor.linkEditors.length == 1) {
                            editor.clearLink(index);
                          } else {
                            editor.removeLink(index);
                          }
                        }),
                        icon: Icon(Icons.remove_circle_outline_rounded,
                            color: context.colors.incorrect),
                      ),
                    ]),
                  )),
              AppButton(
                onPressed: () => setState(editor.addLink),
                type: AppButtonType.outlineAdmin,
                icon: Icons.add_rounded,
                text: '링크 추가',
                height: 44,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppButton(
          text: isSaving ? '저장 중...' : '저장',
          type: AppButtonType.primaryAdmin,
          height: 52,
          onPressed: isSaving ? null : () => _save(category),
        ),
      ],
    );
  }

  String _categoryLabel(CertificateCategory category) => switch (category) {
        CertificateCategory.technical => '국가기술자격',
        CertificateCategory.professional => '국가전문자격',
        CertificateCategory.other => '그 외 자격증',
      };

  InputDecoration _inputDecoration(BuildContext context, {required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: context.colors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.colors.border),
      ),
    );
  }
}

class _CategoryNoticeEditor {
  _CategoryNoticeEditor() : itemControllers = [TextEditingController()];

  final List<TextEditingController> itemControllers;
  final List<_LinkEditor> linkEditors = [_LinkEditor()];

  void setNotice(CertificateCategoryScheduleNotice notice) {
    for (final controller in itemControllers) {
      controller.dispose();
    }
    itemControllers
      ..clear()
      ..addAll(
        notice.items.isEmpty
            ? [TextEditingController()]
            : notice.items
                .map((item) => TextEditingController(text: item)),
      );
    for (final editor in linkEditors) {
      editor.dispose();
    }
    linkEditors
      ..clear()
      ..addAll(notice.links.isEmpty
          ? [_LinkEditor()]
          : notice.links.map((link) => _LinkEditor(link.label, link.url)));
  }

  void addItem() => itemControllers.add(TextEditingController());

  void removeItem(int index) {
    itemControllers.removeAt(index).dispose();
  }

  void addLink() => linkEditors.add(_LinkEditor());

  void removeLink(int index) => linkEditors.removeAt(index).dispose();

  void clearLink(int index) => linkEditors[index].clear();

  bool get hasValidLinks => linkEditors.every((editor) {
        final label = editor.label.text.trim();
        final url = editor.url.text.trim();
        final uri = Uri.tryParse(url);
        return label.isEmpty == url.isEmpty &&
            (url.isEmpty ||
                (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')));
      });

  CertificateCategoryScheduleNotice toNotice() => CertificateCategoryScheduleNotice(
        items: itemControllers.map((controller) => controller.text).toList(),
        links: linkEditors
            .where((editor) => editor.label.text.trim().isNotEmpty)
            .map((editor) => CertificateContentLink(
                  label: editor.label.text,
                  url: editor.url.text,
                ))
            .toList(),
      );

  void dispose() {
    for (final controller in itemControllers) {
      controller.dispose();
    }
    for (final editor in linkEditors) {
      editor.dispose();
    }
  }
}

class _LinkEditor {
  _LinkEditor([String label = '', String url = ''])
      : label = TextEditingController(text: label),
        url = TextEditingController(text: url);

  final TextEditingController label;
  final TextEditingController url;

  void clear() {
    label.clear();
    url.clear();
  }

  void dispose() {
    label.dispose();
    url.dispose();
  }
}
