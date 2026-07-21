import 'package:flutter/material.dart';

import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../services/certificate_detail_service.dart';
import '../services/certificate_search_service.dart';
import '../widgets/certificate_common_widgets.dart';
import '../widgets/certificate_detail_widgets.dart';

class CertificateDetailPage extends StatefulWidget {
  final String certificationId;

  const CertificateDetailPage({
    super.key,
    required this.certificationId,
  });

  @override
  State<CertificateDetailPage> createState() =>
      _CertificateDetailPageState();
}

class _CertificateDetailPageState
    extends State<CertificateDetailPage> {
  final CertificateDetailService _certificateDetailService =
  CertificateDetailService();

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
      await _certificateDetailService.getCertificationById(
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '자격증 상세',
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
        CertificateDetailHeader(
          name: certificate.name,
          qualificationName:
          certificate.qualificationName,
          isTechnical: certificate.isTechnical,
        ),
        const SizedBox(height: 24),
        CertificateInfoCard(
          items: _buildInformationItems(certificate),
        ),
      ],
    );
  }

  List<CertificateInfoItem> _buildInformationItems(
      Certification certificate,
      ) {
    if (certificate.isTechnical) {
      return [
        CertificateInfoItem(
          label: '자격 구분',
          value: certificate.qualificationName,
        ),
        CertificateInfoItem(
          label: '직무 분야',
          value: certificate.obligfldnm,
        ),
        CertificateInfoItem(
          label: '분류',
          value: certificate.mdobligfldnm,
        ),
      ];
    }

    return [
      CertificateInfoItem(
        label: '자격 구분',
        value: certificate.qualificationName,
      ),
      CertificateInfoItem(
        label: '분야',
        value: certificate.seriesnm,
      ),
    ];
  }
}