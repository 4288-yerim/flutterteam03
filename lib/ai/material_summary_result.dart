import 'package:flutter/material.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class MaterialSummaryResultPage extends StatelessWidget {
  final String? selectedCertificate;
  final bool isSplitSummary;
  final List<String> uploadedFileNames;

  const MaterialSummaryResultPage({
    super.key,
    required this.selectedCertificate,
    required this.isSplitSummary,
    required this.uploadedFileNames,
  });

  static const Color _textColor = Color(0xFF302C2E);
  static const Color _subTextColor = Color(0xFF817B7D);
  static const Color _pinkColor = Color(0xFFF4869D);

  void _saveSummary(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('요약본 저장 기능은 추후 연결될 예정입니다.'),
      ),
    );
  }

  void _downloadSummary(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('요약본 다운로드 기능은 추후 연결될 예정입니다.'),
      ),
    );
  }

  void _summarizeAnotherMaterial(BuildContext context) {
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: const AppTopBar(
        title: '요약 결과',
        centerTitle: false,
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              24,
              22,
              24,
              40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryResultHeader(
                  selectedCertificate: selectedCertificate,
                  isSplitSummary: isSplitSummary,
                  fileCount: uploadedFileNames.length,
                ),

                const SizedBox(height: 30),

                const Text(
                  '구름iT 요약 노트',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  '업로드한 자료의 핵심 내용을 정리했어요.',
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 16),

                if (isSplitSummary) ...[
                  const _CertificateSummarySection(
                    certificateName: '정보처리기사',
                    summaryNumber: 1,
                  ),

                  const SizedBox(height: 18),

                  const _CertificateSummarySection(
                    certificateName: 'SQLD',
                    summaryNumber: 2,
                  ),
                ] else ...[
                  _CertificateSummarySection(
                    certificateName:
                    selectedCertificate ?? '정보처리기사',
                    summaryNumber: 1,
                  ),
                ],

                const SizedBox(height: 22),

                _SummaryActionButtons(
                  onSavePressed: () {
                    _saveSummary(context);
                  },
                  onDownloadPressed: () {
                    _downloadSummary(context);
                  },
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _summarizeAnotherMaterial(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _pinkColor,
                      backgroundColor:
                      Colors.white.withValues(alpha: 0.84),
                      side: const BorderSide(
                        color: _pinkColor,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 21,
                    ),
                    label: const Text(
                      '다른 자료 요약하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryResultHeader extends StatelessWidget {
  final String? selectedCertificate;
  final bool isSplitSummary;
  final int fileCount;

  const _SummaryResultHeader({
    required this.selectedCertificate,
    required this.isSplitSummary,
    required this.fileCount,
  });

  @override
  Widget build(BuildContext context) {
    final description = isSplitSummary
        ? '서로 다른 자격증 자료를 나누어 요약했어요.'
        : selectedCertificate != null
        ? '$selectedCertificate 자료를 요약했어요.'
        : '업로드한 자료를 요약했어요.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        22,
        24,
        20,
        22,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE4ED),
            Color(0xFFF2E4FF),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '요약이 완료됐어요!',
                  style: TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),

                const SizedBox(height: 9),

                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF817B7D),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '업로드 자료 $fileCount개',
                  style: const TextStyle(
                    color: Color(0xFFF4869D),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF2F5),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFF4869D),
              size: 32,
            ),
          ),

          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _CertificateSummarySection extends StatelessWidget {
  final String certificateName;
  final int summaryNumber;

  const _CertificateSummarySection({
    required this.certificateName,
    required this.summaryNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        22,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF0E4E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE6EC),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$summaryNumber',
                  style: const TextStyle(
                    color: Color(0xFFF4869D),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Text(
                  certificateName,
                  style: const TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          const _SummaryResultTitle(
            title: '핵심 개념',
          ),

          const SizedBox(height: 12),

          const Text(
            '네트워크 계층은 서로 다른 네트워크 간에 데이터를 전달하며, '
                'IP 주소를 기반으로 최적의 경로를 선택합니다.',
            style: TextStyle(
              color: Color(0xFF595254),
              fontSize: 14,
              height: 1.65,
            ),
          ),

          const SizedBox(height: 22),

          const Divider(
            color: Color(0xFFF0E7E9),
            height: 1,
          ),

          const SizedBox(height: 22),

          const _SummaryResultTitle(
            title: '주요 내용',
          ),

          const SizedBox(height: 12),

          const _SummaryBulletText(
            text: 'IP 주소를 사용하여 출발지와 목적지를 구분해요.',
          ),

          const SizedBox(height: 9),

          const _SummaryBulletText(
            text: '라우터가 패킷이 이동할 경로를 결정해요.',
          ),

          const SizedBox(height: 9),

          const _SummaryBulletText(
            text: '대표적인 프로토콜에는 IP, ICMP, ARP 등이 있어요.',
          ),

          const SizedBox(height: 22),

          const Divider(
            color: Color(0xFFF0E7E9),
            height: 1,
          ),

          const SizedBox(height: 22),

          const _SummaryResultTitle(
            title: '시험 포인트',
          ),

          const SizedBox(height: 12),

          const Text(
            'OSI 7계층에서 네트워크 계층의 역할과 주요 장비인 '
                '라우터의 특징을 함께 정리해두는 것이 좋아요.',
            style: TextStyle(
              color: Color(0xFF595254),
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryResultTitle extends StatelessWidget {
  final String title;

  const _SummaryResultTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF302C2E),
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SummaryBulletText extends StatelessWidget {
  final String text;

  const _SummaryBulletText({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: Icon(
            Icons.circle,
            size: 6,
            color: Color(0xFFF4869D),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF595254),
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryActionButtons extends StatelessWidget {
  final VoidCallback onSavePressed;
  final VoidCallback onDownloadPressed;

  const _SummaryActionButtons({
    required this.onSavePressed,
    required this.onDownloadPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: onSavePressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF4869D),
                backgroundColor:
                Colors.white.withValues(alpha: 0.84),
                side: const BorderSide(
                  color: Color(0xFFF4869D),
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(
                Icons.bookmark_add_outlined,
                size: 20,
              ),
              label: const Text(
                '요약본 저장',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: onDownloadPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4869D),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(
                Icons.download_rounded,
                size: 20,
              ),
              label: const Text(
                '요약본 다운',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
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