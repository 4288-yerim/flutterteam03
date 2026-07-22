import 'package:flutter/material.dart';

import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../services/certificate_detail_service.dart';
import '../services/professional_certificate_service.dart';
import '../services/certificate_search_service.dart';
import '../widgets/certificate_common_widgets.dart';
import '../widgets/certificate_detail_widgets.dart';
import '../widgets/professional_certificate_widgets.dart';

class ProfessionalCertificateDetailPage extends StatefulWidget {
  final String certificationId;

  const ProfessionalCertificateDetailPage({
    super.key,
    required this.certificationId,
  });

  @override
  State<ProfessionalCertificateDetailPage> createState() =>
      _ProfessionalCertificateDetailPageState();
}

class _ProfessionalCertificateDetailPageState
    extends State<ProfessionalCertificateDetailPage> {
  final ProfessionalCertificateService _professionalCertificateService =
      ProfessionalCertificateService();

  bool _isLoading = true;
  String? _loadError;
  Certification? _certificate;

  @override
  void initState() {
    super.initState();
    _loadCertificate();
  }

  Future<void> _loadCertificate() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final certificate =
      await _professionalCertificateService.getProfessionalCertificateById(
        widget.certificationId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _certificate = certificate;
        _isLoading = false;
      });
    } on CertificateDetailException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = '자격증 정보를 불러오지 못했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final certificateName = _certificate?.name.trim() ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: certificateName.isEmpty
            ? '국가전문자격 상세'
            : '$certificateName 상세',
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: certificateDarkText,
            size: 21,
          ),
        ),
      ),
      body: AppMainBackground(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: certificatePrimaryPink,
        ),
      );
    }

    if (_loadError != null) {
      return CertificateLoadError(
        message: _loadError!,
        onRetry: _loadCertificate,
      );
    }

    final certificate = _certificate;

    if (certificate == null) {
      return CertificateLoadError(
        message: '자격증 정보를 찾을 수 없습니다.',
        onRetry: _loadCertificate,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
      children: [
        ProfessionalCertificateOverview(
          certificate: certificate,
        ),
      ],
    );
  }
}