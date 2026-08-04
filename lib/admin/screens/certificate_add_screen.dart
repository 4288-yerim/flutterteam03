import 'package:flutter/material.dart';

import '../../theme.dart';
import '../services/admin_certificate_service.dart';

class CertificateAddScreen extends StatefulWidget {
  const CertificateAddScreen({super.key});

  @override
  State<CertificateAddScreen> createState() => _CertificateAddScreenState();
}

class _CertificateAddScreenState extends State<CertificateAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fieldController = TextEditingController();
  final _categoryController = TextEditingController();
  final _fieldFocusNode = FocusNode();
  final _categoryFocusNode = FocusNode();
  final _seriesController = TextEditingController();
  final _service = AdminCertificateService();

  String? _qualificationCode;
  bool _isSaving = false;
  List<String> _technicalFields = const [];
  Map<String, List<String>> _categoriesByField = const {};
  String _technicalFieldName = '';
  String _technicalCategoryName = '';

  @override
  void initState() {
    super.initState();
    _loadTechnicalCategoryOptions();
  }

  Future<void> _loadTechnicalCategoryOptions() async {
    try {
      final options = await _service.getTechnicalCategoryOptions();
      if (!mounted) return;
      setState(() {
        _technicalFields = options.fields;
        _categoriesByField = options.categoriesByField;
      });
    } on AdminCertificateException {
      // 직접 입력은 가능하므로 분류 자동완성 로드 실패를 화면에 노출하지 않습니다.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fieldController.dispose();
    _categoryController.dispose();
    _fieldFocusNode.dispose();
    _categoryFocusNode.dispose();
    _seriesController.dispose();
    super.dispose();
  }

  bool get _isTechnical => _qualificationCode == 'T';
  bool get _isProfessional => _qualificationCode == 'S';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_qualificationCode == null ||
        _fieldController.text.trim().isEmpty ||
        _categoryController.text.trim().isEmpty) {
      _showMessage('자격 구분, 직무 분야, 분류를 모두 입력해 주세요.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _service.addCertificate(
        AdminCertificateDraft(
          name: _nameController.text,
          qualificationCode: _qualificationCode!,
          qualificationName: _qualificationLabel(_qualificationCode!),
          technicalFieldName: _technicalFieldName,
          categoryName: _technicalCategoryName,
          professionalSeriesName: _isProfessional ? _seriesController.text : '',
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AdminCertificateException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('자격증을 추가하지 못했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('자격증 추가')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                '관리자 추가 자격증',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '등록된 자격증은 선택한 자격 구분과 분류에서 확인할 수 있습니다.',
                style: TextStyle(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _nameController,
                label: '자격증 이름',
                hint: '예: 정보처리기사',
                required: true,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _qualificationCode,
                dropdownColor: context.colors.surfaceElevated,
                decoration: _decoration('자격 구분'),
                items: const [
                  DropdownMenuItem(value: 'T', child: Text('국가기술자격')),
                  DropdownMenuItem(value: 'S', child: Text('국가전문자격')),
                  DropdownMenuItem(value: 'P', child: Text('민간자격')),
                  DropdownMenuItem(value: 'L', child: Text('어학/기타')),
                ],
                onChanged: (value) => setState(() => _qualificationCode = value),
                validator: (value) => value == null ? '자격 구분을 선택해 주세요.' : null,
              ),
              ...[
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _fieldController,
                  label: '직무 분야',
                  hint: '예: 정보통신',
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _categoryController,
                  label: '분류',
                  hint: '예: 정보기술',
                ),
              ],
              if (_isProfessional) ...[
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _seriesController,
                  label: '계열',
                  hint: '예: 변호사, 세무사',
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.warningSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.warning),
                ),
                child: Text(
                  '\uCD94\uAC00\uB41C \uC790\uACA9\uC99D\uC740 \uAE30\uBCF8\uC801\uC73C\uB85C \uBE44\uD65C\uC131\uD654 \uC0C1\uD0DC\uB85C \uB4F1\uB85D\uB429\uB2C8\uB2E4. \uAD00\uB9AC\uC790 \uC790\uACA9\uC99D \uC0C1\uC138\uBCF4\uAE30\uC5D0\uC11C \uD65C\uC131\uD654\uB85C \uBC14\uAFC0 \uC218 \uC788\uC73C\uBA70, \uC790\uACA9\uC99D \uC0C1\uC138\uC815\uBCF4\uB97C \uC218\uC815\uD560 \uC218 \uC788\uC2B5\uB2C8\uB2E4.',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(_isSaving ? '추가 중...' : '자격증 추가'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    String? Function(String?)? validator,
  }) {
    if (identical(controller, _fieldController)) {
      return _buildCategoryAutocomplete(
        controller: controller,
        label: label,
        hint: hint,
        options: _technicalFields,
        onChanged: (value) {
          setState(() {
            _technicalFieldName = value;
            _technicalCategoryName = '';
            _categoryController.clear();
          });
        },
      );
    }
    if (identical(controller, _categoryController)) {
      return _buildCategoryAutocomplete(
        controller: controller,
        label: label,
        hint: hint,
        options: _categoriesByField[_technicalFieldName] ?? const [],
        onChanged: (value) => setState(() => _technicalCategoryName = value),
      );
    }
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      decoration: _decoration(label).copyWith(hintText: hint),
      validator: (value) {
        if (required && (value?.trim().isEmpty ?? true)) {
          return '$label을 입력해주세요.';
        }
        return validator?.call(value);
      },
    );
  }

  Widget _buildCategoryAutocomplete({
    required TextEditingController controller,
    required String label,
    required String hint,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    final focusNode = identical(controller, _fieldController)
        ? _fieldFocusNode
        : _categoryFocusNode;
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (value) {
        final keyword = value.text.trim().toLowerCase();
        if (keyword.isEmpty) return options;
        return options.where((option) => option.toLowerCase().contains(keyword));
      },
      onSelected: (option) {
        controller.text = option;
        onChanged(option);
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          onChanged: onChanged,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: _decoration(label).copyWith(
            hintText: hint,
            suffixIcon: const Icon(Icons.search_rounded),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, matches) {
        final suggestions = matches.toList();
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 360),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final option = suggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: context.colors.surfaceTransparent,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      );

  String _qualificationLabel(String code) => switch (code) {
        'T' => '국가기술자격',
        'S' => '국가전문자격',
        'P' => '민간자격',
        _ => '어학/기타',
      };
}
