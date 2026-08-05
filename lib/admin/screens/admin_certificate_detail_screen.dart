import 'dart:async';

import 'package:flutter/material.dart';

import '../../certificate/screens/other_certificate_detail.dart';
import '../../certificate/screens/professional_certificate_detail.dart';
import '../../certificate/screens/technical_certificate_detail.dart';
import '../../theme.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../services/admin_certificate_service.dart';
import 'admin_certificate_edit_screen.dart';
import 'admin_certificate_statistics_edit_screen.dart';

class AdminCertificateDetailScreen extends StatefulWidget {
  const AdminCertificateDetailScreen({super.key, required this.certificate});

  final AdminCertificate certificate;

  @override
  State<AdminCertificateDetailScreen> createState() =>
      _AdminCertificateDetailScreenState();
}

class _AdminCertificateDetailScreenState
    extends State<AdminCertificateDetailScreen> {
  final _service = AdminCertificateService();
  late bool _isEnabled;
  bool _isProcessing = false;

  AdminCertificate get _certificate => widget.certificate;

  @override
  void initState() {
    super.initState();
    _isEnabled = _certificate.isEnabled;
  }

  Future<void> _toggleEnabled() async {
    await _runAction(() async {
      await _service.setCertificateEnabled(
        certificationId: _certificate.id,
        isEnabled: !_isEnabled,
      );
      if (mounted) setState(() => _isEnabled = !_isEnabled);
    });
  }

  Future<void> _openEdit(AdminCertificateEditMode mode) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminCertificateEditScreen(
          certificationId: _certificate.id,
          mode: mode,
        ),
      ),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('자격증 정보를 수정했습니다.')));
    }
  }

  Future<void> _deleteCertificate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _HoldToDeleteDialog(certificateName: _certificate.name),
    );
    if (confirmed != true) return;

    await _runAction(() async {
      await _service.deleteCertificate(_certificate.id);
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('요청을 처리하지 못했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _certificate.name;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '관리자 자격증 상세',
        centerTitle: true,
        leading: IconButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.colors.textPrimary,
            size: 21,
          ),
        ),
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            children: [
              Text(
                name,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _CertificateSummaryRow(
                label: '자격증 분류',
                value: _certificateCategoryLabel,
              ),
              const SizedBox(height: 10),
              _CertificateSummaryRow(
                label: '직무 분야',
                value: _certificateFieldLabel,
              ),
              if (_certificate.isOther) ...[
                const SizedBox(height: 10),
                _CertificateSummaryRow(
                  label: '분류',
                  value: _certificateCategoryNameLabel,
                ),
              ],
              const SizedBox(height: 28),
              _AdminActionButton(
                icon: Icons.visibility_outlined,
                label: '$name 상세보기 확인하기',
                onTap: _isProcessing
                    ? null
                    : () => _openCertificateDetail(context),
              ),
              const SizedBox(height: 12),
              _AdminActionButton(
                icon: _isEnabled
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                label: '$name ${_isEnabled ? '비활성화' : '활성화'}',
                onTap: _isProcessing ? null : _toggleEnabled,
                accentColor: _isEnabled
                    ? context.colors.warning
                    : context.colors.correct,
              ),
              const SizedBox(height: 12),
              _AdminActionButton(
                icon: Icons.event_note_outlined,
                label: '$name 일정 수정',
                onTap: _isProcessing
                    ? null
                    : () => _openEdit(AdminCertificateEditMode.schedule),
                accentColor: context.colors.info,
              ),
              const SizedBox(height: 12),
              _AdminActionButton(
                icon: Icons.edit_note_rounded,
                label: '$name 자격정보 수정',
                onTap: _isProcessing
                    ? null
                    : () => _openEdit(AdminCertificateEditMode.information),
                accentColor: context.colors.lavenderAccent,
              ),
              if (_certificate.isOther) ...[
                const SizedBox(height: 12),
                _AdminActionButton(
                  icon: Icons.query_stats_rounded,
                  label: '$name 통계 수정',
                  onTap: _isProcessing
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminCertificateStatisticsEditScreen(
                                  certificateName: name,
                                ),
                          ),
                        ),
                  accentColor: context.colors.info,
                ),
              ],
              const SizedBox(height: 12),
              _AdminActionButton(
                icon: Icons.delete_outline_rounded,
                label: '$name 삭제',
                onTap: _isProcessing ? null : _deleteCertificate,
                accentColor: context.colors.incorrect,
                isDestructive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCertificateDetail(BuildContext context) {
    final Widget page;
    if (_certificate.isOther) {
      page = OtherCertificateDetailPage(certificationId: _certificate.id);
    } else if (_certificate.isTechnical) {
      page = TechnicalCertificateDetailPage(certificationId: _certificate.id);
    } else {
      page = ProfessionalCertificateDetailPage(
        certificationId: _certificate.id,
      );
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  String get _certificateCategoryLabel {
    if (_certificate.isOther) return '그 외 자격증';
    if (_certificate.isTechnical) return '국가기술자격';
    return '국가전문자격';
  }

  String get _certificateFieldLabel {
    final value = _certificate.isProfessional
        ? _certificate.seriesName
        : _certificate.fieldName;
    return value.isEmpty ? '-' : value;
  }

  String get _certificateCategoryNameLabel {
    final value = _certificate.categoryName.trim();
    return value.isEmpty ? '-' : value;
  }
}

class _CertificateSummaryRow extends StatelessWidget {
  const _CertificateSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
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
}

class _AdminActionButton extends StatelessWidget {
  const _AdminActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accentColor,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? context.colors.pinkDeep;
    final isDisabled = onTap == null;
    final backgroundColor = isDestructive
        ? context.colors.incorrectSoft
        : color.withValues(alpha: 0.1);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1,
          child: Ink(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.65)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HoldToDeleteDialog extends StatefulWidget {
  const _HoldToDeleteDialog({required this.certificateName});

  final String certificateName;

  @override
  State<_HoldToDeleteDialog> createState() => _HoldToDeleteDialogState();
}

class _HoldToDeleteDialogState extends State<_HoldToDeleteDialog> {
  Timer? _timer;
  bool _isHolding = false;

  void _startHolding() {
    if (_timer != null) return;
    setState(() => _isHolding = true);
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  void _stopHolding() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _isHolding = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        color: context.colors.incorrect,
        size: 32,
      ),
      title: Text('${widget.certificateName}을(를) 정말 삭제할까요?'),
      content: const Text(
        '자격증을 삭제하면 되돌릴 수 없습니다.\n\n삭제하려면 아래 삭제 버튼을 3초간 꾹 눌러주세요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.incorrect,
          ),
          child: const Text('취소'),
        ),
        Material(
          color: _isHolding
              ? context.colors.incorrect
              : context.colors.incorrectSoft,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTapDown: (_) => _startHolding(),
            onTapUp: (_) => _stopHolding(),
            onTapCancel: _stopHolding,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                _isHolding ? '삭제 중...' : '3초간 꾹 눌러 삭제',
                style: TextStyle(
                  color: _isHolding
                      ? context.colors.onPrimary
                      : context.colors.incorrect,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
