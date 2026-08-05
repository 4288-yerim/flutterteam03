import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dropdown.dart';
import '../services/admin_certificate_service.dart';
import '../widgets/admin_certificate_theme.dart';

class CertificateAddScreen extends StatefulWidget {
  const CertificateAddScreen({super.key});

  @override
  State<CertificateAddScreen> createState() => _CertificateAddScreenState();
}

class _CertificateAddScreenState extends State<CertificateAddScreen> {
  static const _noSearchResults = '__NO_SEARCH_RESULTS__';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fieldController = TextEditingController();
  final _categoryController = TextEditingController();
  final _fieldFocusNode = FocusNode();
  final _categoryFocusNode = FocusNode();
  final _seriesController = TextEditingController();
  final _seriesFocusNode = FocusNode();
  final _service = AdminCertificateService();

  String? _qualificationCode;
  bool _isSaving = false;
  List<String> _fieldOptions = const [];
  Map<String, List<String>> _categoriesByField = const {};
  String _selectedFieldName = '';
  List<String> _seriesOptions = const [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadCategoryOptions(String selectedCode) async {
    try {
      if (selectedCode == 'HRDK_S') {
        final seriesOptions = await _service.getProfessionalSeriesOptions();
        if (!mounted || _qualificationCode != selectedCode) return;
        setState(() => _seriesOptions = seriesOptions);
        _refreshFocusedAutocompleteAfterBuild();
        return;
      }
      final options = selectedCode == 'HRDK_T'
          ? await _service.getTechnicalCategoryOptions()
          : await _service.getOtherCategoryOptions(selectedCode);
      if (!mounted || _qualificationCode != selectedCode) return;
      setState(() {
        _fieldOptions = options.fields;
        _categoriesByField = options.categoriesByField;
      });
      _refreshFocusedAutocompleteAfterBuild();
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
    _seriesFocusNode.dispose();
    super.dispose();
  }

  bool get _isHrdkProfessional => _qualificationCode == 'HRDK_S';

  bool get _isHrdkCertificate =>
      _qualificationCode == 'HRDK_T' || _qualificationCode == 'HRDK_S';

  String get _storedQualificationCode => switch (_qualificationCode) {
        'HRDK_T' => 'T',
        'HRDK_S' => 'S',
        final code? => code,
        null => '',
      };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_qualificationCode == null) {
      _showMessage('자격 구분을 선택해 주세요.');
      return;
    }
    if (_isHrdkProfessional && _seriesController.text.trim().isEmpty) {
      _showMessage('계열을 입력해 주세요.');
      return;
    }
    if (!_isHrdkProfessional && _fieldController.text.trim().isEmpty) {
      _showMessage('직무 분야를 입력해 주세요.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _service.addCertificate(
        AdminCertificateDraft(
          name: _nameController.text,
          qualificationCode: _storedQualificationCode,
          qualificationName: _qualificationLabel(_storedQualificationCode),
          technicalFieldName:
              _isHrdkProfessional ? '' : _fieldController.text,
          categoryName:
              _isHrdkProfessional ? '' : _categoryController.text,
          professionalSeriesName:
              _isHrdkProfessional ? _seriesController.text : '',
          source: _isHrdkCertificate ? null : 'ADMIN',
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
    return AdminCertificateTheme(
      child: Scaffold(
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
              const SizedBox(height: 24),
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
              _buildTextField(
                controller: _nameController,
                label: '자격증 이름',
                hint: '예: 정보처리기사',
                required: true,
              ),
              const SizedBox(height: 14),
              AppAdminDropdown<String?>(
                label: '자격 구분',
                value: _qualificationCode,
                items: const [
                  AppDropdownItem<String?>(
                    value: 'HRDK_T',
                    label: '국가기술자격(산업인력공단)',
                  ),
                  AppDropdownItem<String?>(
                    value: 'HRDK_S',
                    label: '국가전문자격(산업인력공단)',
                  ),
                  AppDropdownItem<String?>(value: 'T', label: '국가기술자격'),
                  AppDropdownItem<String?>(value: 'S', label: '국가전문자격'),
                  AppDropdownItem<String?>(value: 'P', label: '민간자격'),
                  AppDropdownItem<String?>(value: 'L', label: '어학/기타'),
                ],
                onChanged: _onQualificationChanged,
              ),
              if (_qualificationCode != null && !_isHrdkProfessional) ...[
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _fieldController,
                  label: '직무 분야',
                  hint: '',
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _categoryController,
                  label: '분류',
                  hint: '',
                ),
              ],
              if (_isHrdkProfessional) ...[
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _seriesController,
                  label: '계열',
                  hint: '',
                ),
              ],
              const SizedBox(height: 20),
              AppButton(
                onPressed: _isSaving ? null : _save,
                type: AppButtonType.primaryAdmin,
                icon: _isSaving ? null : Icons.add_rounded,
                text: _isSaving ? '추가 중...' : '자격증 추가',
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  void _onQualificationChanged(String? value) {
    setState(() {
      _qualificationCode = value;
      _fieldController.clear();
      _categoryController.clear();
      _seriesController.clear();
      _selectedFieldName = '';
      _fieldOptions = const [];
      _categoriesByField = const {};
      _seriesOptions = const [];
    });
    if (value != null) {
      _loadCategoryOptions(value);
    }
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
        options: _fieldOptions,
        onChanged: (value) {
          setState(() {
            _selectedFieldName = value;
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
        options: _categoriesByField[_selectedFieldName] ?? const [],
        onChanged: (_) {},
      );
    }
    if (identical(controller, _seriesController)) {
      return _buildCategoryAutocomplete(
        controller: controller,
        label: label,
        hint: hint,
        options: _seriesOptions,
        onChanged: (_) {},
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
        : identical(controller, _categoryController)
            ? _categoryFocusNode
            : _seriesFocusNode;
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (value) {
        final keyword = value.text.trim().toLowerCase();
        if (keyword.isEmpty) return options;
        final matches = options
            .where((option) => option.toLowerCase().contains(keyword))
            .toList();
        return matches.isEmpty ? const [_noSearchResults] : matches;
      },
      onSelected: (option) {
        if (option == _noSearchResults) return;
        controller.text = option;
        onChanged(option);
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          onChanged: onChanged,
          onTap: () => _refreshAutocompleteOptions(textController),
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
        if (suggestions.length == 1 &&
            suggestions.single == _noSearchResults) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: context.colors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(16),
                child: Text(
                  identical(controller, _seriesController)
                      ? '검색 결과가 없습니다.\n입력한 계열을 그대로 사용할 수 있습니다.'
                      : '검색 결과가 없습니다.\n자격증을 추가하면 입력한 직무 분야/분류가 추가됩니다.',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          );
        }
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

  void _refreshAutocompleteOptions(TextEditingController controller) {
    final originalValue = controller.value;
    controller.value = originalValue.copyWith(
      text: '${originalValue.text} ',
      composing: TextRange.empty,
    );
    controller.value = originalValue;
  }

  void _refreshFocusedAutocompleteAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_fieldFocusNode.hasFocus) {
        _refreshAutocompleteOptions(_fieldController);
      } else if (_categoryFocusNode.hasFocus) {
        _refreshAutocompleteOptions(_categoryController);
      } else if (_seriesFocusNode.hasFocus) {
        _refreshAutocompleteOptions(_seriesController);
      }
    });
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
