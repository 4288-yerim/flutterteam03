import 'package:flutter/material.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class CertificateRoadmapPage extends StatefulWidget {
  const CertificateRoadmapPage({super.key});

  @override
  State<CertificateRoadmapPage> createState() =>
      _CertificateRoadmapPageState();
}

class _CertificateRoadmapPageState
    extends State<CertificateRoadmapPage> {
  static const Color _textColor = Color(0xFF302C2E);
  static const Color _subTextColor = Color(0xFF817B7D);
  static const Color _pinkColor = Color(0xFFF4869D);

  final List<String> _jobOptions = const [
    '백엔드 개발자',
    '프론트엔드 개발자',
    '데이터 분석가',
    '정보보안 전문가',
    '네트워크 엔지니어',
    '클라우드 엔지니어',
  ];

  final List<String> _certificateOptions = const [
    '정보처리기사',
    'SQLD',
    'ADsP',
    '빅데이터분석기사',
    '네트워크관리사 2급',
    '리눅스마스터 2급',
  ];

  final List<_RoadmapCertificate> _sampleRoadmap = const [
    _RoadmapCertificate(
      order: 1,
      name: '정보처리기사',
      description: '개발 직무에 필요한 기본적인 소프트웨어 지식을 학습해요.',
      registrationPeriod: '2026. 07. 20 ~ 2026. 07. 23',
      examDate: '2026. 08. 11',
    ),
    _RoadmapCertificate(
      order: 2,
      name: 'SQLD',
      description: '데이터베이스와 SQL 활용 능력을 학습해요.',
      registrationPeriod: '2026. 08. 03 ~ 2026. 08. 07',
      examDate: '2026. 09. 12',
    ),
    _RoadmapCertificate(
      order: 3,
      name: '리눅스마스터 2급',
      description: '서버 환경과 리눅스 운영에 필요한 내용을 학습해요.',
      registrationPeriod: '2026. 09. 01 ~ 2026. 09. 11',
      examDate: '2026. 10. 10',
    ),
  ];

  String? _selectedJob;
  final Set<String> _selectedCertificates = {};

  bool _isRoadmapGenerated = false;

  void _toggleCertificate(String certificate, bool selected) {
    setState(() {
      if (selected) {
        _selectedCertificates.add(certificate);
      } else {
        _selectedCertificates.remove(certificate);
      }

      // 선택 조건이 변경되면 기존 결과를 숨김
      _isRoadmapGenerated = false;
    });
  }

  void _generateRoadmap() {
    if (_selectedJob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('원하는 직무를 선택해주세요.'),
        ),
      );

      return;
    }

    setState(() {
      _isRoadmapGenerated = true;
    });
  }

  void _openCertificateDetail(_RoadmapCertificate certificate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TemporaryCertificateDetailPage(
          certificateName: certificate.name,
        ),
      ),
    );
  }

  void _saveRoadmap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('로드맵 저장 기능은 추후 연결될 예정입니다.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: const AppTopBar(
        title: '자격증 로드맵',
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
                const _RoadmapHeader(),

                const SizedBox(height: 30),

                const _SectionTitle(
                  number: '1',
                  title: '원하는 직무를 선택해주세요',
                ),

                const SizedBox(height: 14),

                _buildJobDropdown(),

                const SizedBox(height: 30),

                const _SectionTitle(
                  number: '2',
                  title: '보유 자격증을 선택해주세요',
                  description: '보유한 자격증이 없다면 선택하지 않아도 돼요.',
                ),

                const SizedBox(height: 14),

                _buildCertificateSelector(),

                const SizedBox(height: 28),

                _buildGenerateButton(),

                if (_isRoadmapGenerated) ...[
                  const SizedBox(height: 38),

                  _buildRoadmapHeader(),

                  const SizedBox(height: 18),

                  _buildRoadmapList(),

                  const SizedBox(height: 24),

                  _buildSaveButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF0E5E9),
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedJob,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: _pinkColor,
        ),
        decoration: const InputDecoration(
          hintText: '직무를 선택해주세요',
          hintStyle: TextStyle(
            color: Color(0xFFA29A9D),
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.work_outline_rounded,
            color: _pinkColor,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
          border: InputBorder.none,
        ),
        items: _jobOptions.map((job) {
          return DropdownMenuItem<String>(
            value: job,
            child: Text(
              job,
              style: const TextStyle(
                color: _textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedJob = value;
            _isRoadmapGenerated = false;
          });
        },
      ),
    );
  }

  Widget _buildCertificateSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF0E5E9),
        ),
      ),
      child: Wrap(
        spacing: 9,
        runSpacing: 10,
        children: _certificateOptions.map((certificate) {
          final isSelected =
          _selectedCertificates.contains(certificate);

          return FilterChip(
            selected: isSelected,
            label: Text(certificate),
            onSelected: (selected) {
              _toggleCertificate(certificate, selected);
            },
            showCheckmark: true,
            checkmarkColor: Colors.white,
            selectedColor: _pinkColor,
            backgroundColor: const Color(0xFFFFF5F7),
            side: BorderSide(
              color: isSelected
                  ? _pinkColor
                  : const Color(0xFFF2DDE3),
            ),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : _textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 7,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: _generateRoadmap,
        style: FilledButton.styleFrom(
          backgroundColor: _pinkColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(21),
          ),
        ),
        icon: const Icon(
          Icons.auto_awesome_rounded,
          size: 22,
        ),
        label: const Text(
          '자격증 로드맵 생성하기',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildRoadmapHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '추천 자격증 로드맵',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              SizedBox(height: 7),
              Text(
                '자격증을 누르면 상세 정보를 확인할 수 있어요.',
                style: TextStyle(
                  color: _subTextColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE4EA),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            '${_sampleRoadmap.length}개 추천',
            style: const TextStyle(
              color: _pinkColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoadmapList() {
    return Column(
      children: List.generate(
        _sampleRoadmap.length,
            (index) {
          final certificate = _sampleRoadmap[index];

          return Column(
            children: [
              _RoadmapCard(
                certificate: certificate,
                onPressed: () {
                  _openCertificateDetail(certificate);
                },
              ),
              if (index != _sampleRoadmap.length - 1)
                const _RoadmapConnector(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _saveRoadmap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _pinkColor,
          backgroundColor: Colors.white.withValues(alpha: 0.8),
          side: const BorderSide(
            color: _pinkColor,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        icon: const Icon(
          Icons.bookmark_add_outlined,
          size: 22,
        ),
        label: const Text(
          '로드맵 저장하기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RoadmapHeader extends StatelessWidget {
  const _RoadmapHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        22,
        25,
        22,
        24,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE5ED),
            Color(0xFFECE4FF),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '어떤 자격증부터\n준비해야 할까요?',
                  style: TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 22,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                SizedBox(height: 11),
                Text(
                  '원하는 직무와 보유 자격증을 바탕으로\n구름iT이 순서대로 추천해드려요.',
                  style: TextStyle(
                    color: Color(0xFF817B7D),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Icon(
            Icons.route_rounded,
            size: 72,
            color: Color(0xFF9B7AF5),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String number;
  final String title;
  final String? description;

  const _SectionTitle({
    required this.number,
    required this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 29,
          height: 29,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFF4869D),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF302C2E),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 6),
                Text(
                  description!,
                  style: const TextStyle(
                    color: Color(0xFF817B7D),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  final _RoadmapCertificate certificate;
  final VoidCallback onPressed;

  const _RoadmapCard({
    required this.certificate,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(23),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            18,
            18,
            14,
            18,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE4EA),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${certificate.order}',
                  style: const TextStyle(
                    color: Color(0xFFF4869D),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificate.name,
                      style: const TextStyle(
                        color: Color(0xFF302C2E),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      certificate.description,
                      style: const TextStyle(
                        color: Color(0xFF817B7D),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 15),

                    _DateInformation(
                      icon: Icons.edit_calendar_outlined,
                      label: '접수 기간',
                      value: certificate.registrationPeriod,
                    ),

                    const SizedBox(height: 8),

                    _DateInformation(
                      icon: Icons.event_available_outlined,
                      label: '시험일',
                      value: certificate.examDate,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 5),

              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFF4869D),
                  size: 25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateInformation extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DateInformation({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: const Color(0xFFF4869D),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF817B7D),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF4A4547),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoadmapConnector extends StatelessWidget {
  const _RoadmapConnector();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 25,
      decoration: BoxDecoration(
        color: const Color(0xFFF4C3CF),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _RoadmapCertificate {
  final int order;
  final String name;
  final String description;
  final String registrationPeriod;
  final String examDate;

  const _RoadmapCertificate({
    required this.order,
    required this.name,
    required this.description,
    required this.registrationPeriod,
    required this.examDate,
  });
}

/// 실제 자격증 상세 페이지가 연결되기 전까지 사용하는 임시 화면
class _TemporaryCertificateDetailPage extends StatelessWidget {
  final String certificateName;

  const _TemporaryCertificateDetailPage({
    required this.certificateName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(
        title: certificateName,
        centerTitle: false,
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: Center(
            child: Text(
              '$certificateName 상세 페이지',
              style: const TextStyle(
                color: Color(0xFF302C2E),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}