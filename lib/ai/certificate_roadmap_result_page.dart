import 'package:flutter/material.dart';

import '../theme.dart';
import 'services/certificate_api_service.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class CertificateRoadmapResultPage extends StatefulWidget {
  final String job;
  final List<SuggestedCertificate> certificates;

  const CertificateRoadmapResultPage({
    super.key,
    required this.job,
    required this.certificates,
  });

  @override
  State<CertificateRoadmapResultPage> createState() => _CertificateRoadmapResultPageState();
}

class _CertificateRoadmapResultPageState extends State<CertificateRoadmapResultPage> {
  bool _isLoading = true;
  String? _error;
  List<_RoadmapCertificate> _roadmap = [];
  bool _popularityCounted = false; // 화면 하나당 인기 직무는 딱 1번만 집계

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    if (_isLoading == true && _roadmap.isNotEmpty) return; // 재생성 중 중복 탭 방지
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final schedules = await CertificateApiService.fetchSchedule();

      final roadmap = <_RoadmapCertificate>[];
      for (var i = 0; i < widget.certificates.length; i++) {
        final cert = widget.certificates[i];
        final matched = CertificateApiService.findUpcoming(schedules, cert.name);
        roadmap.add(_RoadmapCertificate(
          order: i + 1,
          name: cert.name,
          description: cert.description,
          level: null,
          registrationPeriod: matched?.docRegPeriod ?? '주관 기관 홈페이지에서 확인해주세요',
          examDate: matched?.docExamDate ?? '-',
          isEstimated: matched == null,
        ));
      }

      setState(() {
        _roadmap = roadmap;
        _isLoading = false;
      });

      if (!_popularityCounted && widget.job.isNotEmpty) {
        _popularityCounted = true;
        CertificateApiService.incrementJobPopularity(widget.job);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '일정을 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  void _openCertificateDetail(_RoadmapCertificate certificate) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _TemporaryCertificateDetailPage(certificateName: certificate.name)),
    );
  }

  void _saveRoadmap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로드맵 저장 기능은 추후 연결될 예정입니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(title: '${widget.job} 로드맵', centerTitle: false),
      body: AppMainBackground(
        child: SafeArea(
          child: _isLoading
              ? Center(child: _LoadingIndicator(colors: colors))
              : _error != null
              ? _buildErrorState(colors)
              : _buildResult(colors),
        ),
      ),
    );
  }

  Widget _buildErrorState(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontSize: 14)),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: _generate,
              icon: Icon(Icons.refresh_rounded, color: colors.pinkDeep),
              label: Text('다시 시도', style: TextStyle(color: colors.pinkDeep, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(AppColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('추천 자격증 로드맵',
                        style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                    const SizedBox(height: 6),
                    Text('취득 순서대로 정렬했어요. 카드를 누르면 상세 정보를 볼 수 있어요.',
                        style: TextStyle(color: colors.textSecondary, fontSize: 13.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [colors.pinkSoft, colors.lavender]),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text('${_roadmap.length}개', style: TextStyle(color: colors.pinkDeep, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Column(
            children: List.generate(_roadmap.length, (index) {
              final cert = _roadmap[index];
              return _FadeSlideIn(
                delay: Duration(milliseconds: 60 * index),
                child: Column(
                  children: [
                    _RoadmapCard(certificate: cert, accentIndex: index, onPressed: () => _openCertificateDetail(cert)),
                    if (index != _roadmap.length - 1) _RoadmapConnector(colors: colors),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, 'restart'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: colors.pinkSoft, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 20),
                  label: const Text('처음부터', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _saveRoadmap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.lavenderAccent,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: colors.lavenderAccent, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 21),
                    label: const Text('로드맵 저장하기', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  final _RoadmapCertificate certificate;
  final int accentIndex;
  final VoidCallback onPressed;

  const _RoadmapCard({required this.certificate, required this.accentIndex, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = [
      (bg: [colors.pinkEnd, colors.pinkSoft], fg: colors.pinkDeep),
      (bg: [colors.lavender, colors.lavender], fg: colors.lavenderAccent),
      (bg: [colors.softBlue, colors.softBlue], fg: colors.softBlueAccent),
      (bg: [colors.mint, colors.mint], fg: colors.mintAccent),
    ];
    final tone = palette[accentIndex % palette.length];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF2E6EA)),
        boxShadow: const [BoxShadow(color: Color(0x12C98198), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: tone.bg), shape: BoxShape.circle),
                  child: Text('${certificate.order}', style: TextStyle(color: tone.fg, fontSize: 17, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(certificate.name,
                                style: TextStyle(color: colors.textPrimary, fontSize: 17.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                          ),
                          if (certificate.level != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: tone.bg.first, borderRadius: BorderRadius.circular(20)),
                              child: Text(certificate.level!, style: TextStyle(color: tone.fg, fontSize: 10, fontWeight: FontWeight.w800)),
                            ),
                          ],
                          if (certificate.isEstimated) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFF3F0F5), borderRadius: BorderRadius.circular(20)),
                              child: const Text('주관사 확인 필요', style: TextStyle(color: Color(0xFF897F82), fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(certificate.description, style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.45)),
                      const SizedBox(height: 16),
                      _DateInformation(icon: Icons.edit_calendar_outlined, label: '접수 기간', value: certificate.registrationPeriod, color: colors.softBlueAccent),
                      const SizedBox(height: 8),
                      _DateInformation(icon: Icons.event_available_outlined, label: '시험일', value: certificate.examDate, color: colors.pinkDeep),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Padding(padding: const EdgeInsets.only(top: 8), child: Icon(Icons.chevron_right_rounded, color: tone.fg, size: 25)),
              ],
            ),
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
  final Color color;

  const _DateInformation({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 9),
        Expanded(child: Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class _RoadmapConnector extends StatelessWidget {
  final AppColors colors;
  const _RoadmapConnector({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 26,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.pinkSoft, colors.lavender], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  final AppColors colors;
  const _LoadingIndicator({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: colors.pinkStart, strokeWidth: 3)),
        const SizedBox(height: 12),
        Text('로드맵을 만들고 있어요', style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _RoadmapCertificate {
  final int order;
  final String name;
  final String description;
  final String? level;
  final String registrationPeriod;
  final String examDate;
  final bool isEstimated;

  const _RoadmapCertificate({
    required this.order,
    required this.name,
    required this.description,
    required this.level,
    required this.registrationPeriod,
    required this.examDate,
    required this.isEstimated,
  });
}

class _TemporaryCertificateDetailPage extends StatelessWidget {
  final String certificateName;
  const _TemporaryCertificateDetailPage({required this.certificateName});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(title: certificateName, centerTitle: false),
      body: AppMainBackground(
        child: SafeArea(
          child: Center(
            child: Text('$certificateName 상세 페이지', style: TextStyle(color: colors.textPrimary, fontSize: 21, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}