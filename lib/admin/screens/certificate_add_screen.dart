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
  final _seriesController = TextEditingController();
  final _service = AdminCertificateService();

  String _qualificationCode = 'T';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _fieldController.dispose();
    _categoryController.dispose();
    _seriesController.dispose();
    super.dispose();
  }

  bool get _isTechnical => _qualificationCode == 'T';
  bool get _isProfessional => _qualificationCode == 'S';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _service.addCertificate(
        AdminCertificateDraft(
          name: _nameController.text,
          qualificationCode: _qualificationCode,
          qualificationName: _qualificationLabel(_qualificationCode),
          technicalFieldName: _isTechnical ? _fieldController.text : '',
          categoryName: _isTechnical ? _categoryController.text : '',
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
                '등록된 자격증은 선택한 자격 분류와 세부 카테고리에서 확인할 수 있습니다.',
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
                initialValue: _qualificationCode,
                decoration: _decoration('자격 분류'),
                items: const [
                  DropdownMenuItem(value: 'T', child: Text('국가기술자격')),
                  DropdownMenuItem(value: 'S', child: Text('국가전문자격')),
                  DropdownMenuItem(value: 'P', child: Text('민간자격')),
                  DropdownMenuItem(value: 'L', child: Text('어학/기타')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _qualificationCode = value);
                },
              ),
              if (_isTechnical) ...[
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _fieldController,
                  label: '대분류',
                  hint: '예: 정보통신',
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _categoryController,
                  label: '세부 카테고리',
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
              const SizedBox(height: 28),
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
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: _decoration(label).copyWith(hintText: hint),
      validator: (value) {
        if (required && (value?.trim().isEmpty ?? true)) {
          return '$label을 입력해주세요.';
        }
        return validator?.call(value);
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
