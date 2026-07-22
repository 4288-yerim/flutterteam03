import 'certificate_detail_service.dart';
import 'certificate_search_service.dart';

class ProfessionalCertificateService {
  ProfessionalCertificateService({
    CertificateDetailService? certificateDetailService,
  }) : _certificateDetailService =
            certificateDetailService ?? CertificateDetailService();

  final CertificateDetailService _certificateDetailService;

  Future<Certification> getProfessionalCertificateById(
    String certificationId,
  ) async {
    final certificate = await _certificateDetailService
        .getCertificationById(certificationId);

    if (!certificate.isProfessional) {
      throw const CertificateDetailException(
        '국가전문자격 정보가 아닙니다.',
      );
    }

    return certificate;
  }
}
