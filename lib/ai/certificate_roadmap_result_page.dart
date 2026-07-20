import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../mypage/screens/mypage_screen.dart';
import '../theme.dart';
import 'services/certificate_api_service.dart';
import 'certificate_roadmap_result_page.dart';
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

class _CertificateRoadmapResultPageState extends State<CertificateRoadmapResultPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  List<_RoadmapCertificate> _roadmap = [];
  bool _popularityCounted = false;
  bool _isSaving = false;
  bool _isSaved = false;

  late final AnimationController _loadingController =
  AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_isLoading == true && _roadmap.isNotEmpty) return; // 재생성 중 중복 탭 방지
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _loadingController.value = 0;
    _loadingController.duration = const Duration(milliseconds: 900);
    _loadingController.animateTo(0.9, curve: Curves.easeOut);

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

      await _loadingController.animateTo(1.0, duration: const Duration(milliseconds: 200));
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      setState(() {
        _roadmap = roadmap;
        _isLoading = false;
      });

      if (!_popularityCounted && widget.job.isNotEmpty) {
        _popularityCounted = true;
        CertificateApiService.incrementJobPopularity(widget.job);
      }
    } catch (e) {
      _loadingController.stop();
      if (!mounted) return;
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
  Future<void> _saveRoadmap() async {
    if (_isSaving) return;

    if (_isSaved) {
      _showAlreadySavedDialog();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 이용할 수 있어요.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('roadmaps')
          .add({
        'job': widget.job,
        'certificates': _roadmap
            .map((c) => {
          'order': c.order,
          'name': c.name,
          'description': c.description,
          'registrationPeriod': c.registrationPeriod,
          'examDate': c.examDate,
          'isEstimated': c.isEstimated,
        })
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isSaved = true);
      _showSaveSuccessDialog();
    } catch (e) {
      debugPrint('로드맵 저장 에러: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장에 실패했어요. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showAlreadySavedDialog() {
    final colors = context.colors;
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogContext) {
        final c = dialogContext.colors;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.fromLTRB(26, 30, 26, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 14)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.pinkSoft, shape: BoxShape.circle),
                  child: Icon(Icons.bookmark_rounded, color: c.pinkStart, size: 27),
                ),
                const SizedBox(height: 16),
                Text('이미 저장된 로드맵이에요',
                    style: TextStyle(color: c.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('마이페이지로 이동할까요?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.5)),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.textSecondary,
                          side: BorderSide(color: c.pinkSoft),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: c.pinkStart),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _goToMyPage();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Center(
                                child: Text('이동하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _goToMyPage() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyPageScreen()),
    );
  }

  Future<void> _showSaveSuccessDialog() {
    final colors = context.colors;
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogContext) {
        final c = dialogContext.colors;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.fromLTRB(26, 32, 26, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 14)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SaveSuccessBadge(colorStart: c.pinkStart, colorEnd: c.pinkDeep),
                const SizedBox(height: 18),
                Text('저장 완료!',
                    style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('로드맵을 컬렉션에 추가했어요.\n마이페이지에서 확인할 수 있어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.5)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.textSecondary,
                          side: BorderSide(color: c.pinkSoft),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: c.pinkStart,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _goToMyPage();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Center(
                                child: Text('마이페이지로 이동',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
              ? Center(child: _LoadingIndicator(progress: _loadingController, colors: colors))
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
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('추천 자격증 로드맵',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                const SizedBox(height: 6),
                Text('취득 순서대로 정렬했어요. 카드를 누르면 상세 정보를 볼 수 있어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13.5)),
                const SizedBox(height: 12),
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
          ),
          const SizedBox(height: 28),
          _RoadmapTimeline(roadmap: _roadmap, onTap: _openCertificateDetail),
          const SizedBox(height: 10),
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: colors.pinkStart,
                        boxShadow: [BoxShadow(color: colors.pinkStart.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 8))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _isSaving ? null : _saveRoadmap,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isSaving)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                )
                              else
                                Icon(
                                  _isSaved ? Icons.check_circle_rounded : Icons.bookmark_add_outlined,
                                  size: 21,
                                  color: Colors.white,
                                ),
                              const SizedBox(width: 9),
                              Text(
                                _isSaving ? '저장 중...' : (_isSaved ? '저장됨' : '로드맵 저장하기'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

/// 좌측 세로 라인 + 번호 노드로 이어지는 진짜 "로드맵" 형태의 타임라인
class _RoadmapTimeline extends StatelessWidget {
  final List<_RoadmapCertificate> roadmap;
  final ValueChanged<_RoadmapCertificate> onTap;

  const _RoadmapTimeline({required this.roadmap, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        _TimelineFlag(colors: colors, icon: Icons.flag_rounded, label: '출발'),
        ...List.generate(roadmap.length, (index) {
          final cert = roadmap[index];
          final isLast = index == roadmap.length - 1;
          return _FadeSlideIn(
            delay: Duration(milliseconds: 70 * index),
            child: _TimelineItem(
              certificate: cert,
              accentIndex: index,
              isLast: isLast,
              onPressed: () => onTap(cert),
            ),
          );
        }),
        _TimelineFlag(colors: colors, icon: Icons.emoji_events_rounded, label: '목표 달성', isGoal: true),
      ],
    );
  }
}

class _TimelineFlag extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final String label;
  final bool isGoal;

  const _TimelineFlag({required this.colors, required this.icon, required this.label, this.isGoal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isGoal ? 0 : 10, top: isGoal ? 10 : 0),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Center(
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [colors.pinkStart, colors.pinkDeep]),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: colors.pinkStart.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: colors.pinkSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label, style: TextStyle(color: colors.pinkDeep, fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final _RoadmapCertificate certificate;
  final int accentIndex;
  final bool isLast;
  final VoidCallback onPressed;

  const _TimelineItem({
    required this.certificate,
    required this.accentIndex,
    required this.isLast,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = <({List<Color> bg, Color fg})>[
      (bg: [colors.pinkEnd, colors.pinkSoft], fg: colors.pinkDeep),
      (bg: [colors.lavender, colors.lavender], fg: colors.lavenderAccent),
      (bg: [colors.softBlue, colors.softBlue], fg: colors.softBlueAccent),
      (bg: [colors.mint, colors.mint], fg: colors.mintAccent),
    ];
    final tone = palette[accentIndex % palette.length];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.pinkSoft, tone.fg],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: tone.bg),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: tone.fg.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Text('${certificate.order}',
                      style: TextStyle(color: tone.fg, fontSize: 15, fontWeight: FontWeight.w900)),
                ),
                Expanded(
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tone.fg, isLast ? colors.pinkStart : colors.pinkSoft],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18, top: 2),
              child: _TimelineCard(certificate: certificate, tone: tone, onPressed: onPressed),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final _RoadmapCertificate certificate;
  final ({List<Color> bg, Color fg}) tone;
  final VoidCallback onPressed;

  const _TimelineCard({required this.certificate, required this.tone, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF2E6EA)),
        boxShadow: const [BoxShadow(color: Color(0x12C98198), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(certificate.name,
                                style: TextStyle(
                                    color: colors.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
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
                              child: const Text('주관사 확인 필요',
                                  style: TextStyle(color: Color(0xFF897F82), fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(certificate.description, style: TextStyle(color: colors.textSecondary, fontSize: 12.5, height: 1.45)),
                      const SizedBox(height: 14),
                      _DateInformation(icon: Icons.edit_calendar_outlined, label: '접수 기간', value: certificate.registrationPeriod, color: colors.softBlueAccent),
                      const SizedBox(height: 7),
                      _DateInformation(icon: Icons.event_available_outlined, label: '시험일', value: certificate.examDate, color: colors.pinkDeep),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Padding(padding: const EdgeInsets.only(top: 6), child: Icon(Icons.chevron_right_rounded, color: tone.fg, size: 23)),
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

class _LoadingIndicator extends StatelessWidget {
  final Animation<double> progress;
  final AppColors colors;
  const _LoadingIndicator({required this.progress, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress.value,
                minHeight: 6,
                backgroundColor: colors.pinkSoft,
                valueColor: AlwaysStoppedAnimation(colors.pinkStart),
              ),
            ),
            const SizedBox(height: 8),
            Text('${(progress.value * 100).toInt()}%',
                style: TextStyle(color: colors.pinkDeep, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text('로드맵을 만들고 있어요', style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
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

class _SaveSuccessBadge extends StatefulWidget {
  final Color colorStart;
  final Color colorEnd;
  const _SaveSuccessBadge({required this.colorStart, required this.colorEnd});

  @override
  State<_SaveSuccessBadge> createState() => _SaveSuccessBadgeState();
}

class _SaveSuccessBadgeState extends State<_SaveSuccessBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
  late final Animation<double> _scale =
  CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.55, curve: Curves.elasticOut));
  late final Animation<double> _haloScale =
  CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.8, curve: Curves.easeOut));
  late final Animation<double> _check =
  CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.7 + (_haloScale.value * 0.3),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.colorStart.withValues(alpha: 0.14 * (1 - _haloScale.value * 0.3)),
                  ),
                ),
              ),
              Transform.scale(
                scale: _scale.value.clamp(0.0, 1.15),
                child: Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [widget.colorStart, widget.colorEnd],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: widget.colorStart.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: CustomPaint(
                    size: const Size(28, 28),
                    painter: _CheckmarkPainter(progress: _check.value),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  const _CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.06, size.height * 0.52)
      ..lineTo(size.width * 0.4, size.height * 0.82)
      ..lineTo(size.width * 0.98, size.height * 0.16);

    final metric = path.computeMetrics().first;
    final drawnPath = metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0));
    canvas.drawPath(drawnPath, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) => oldDelegate.progress != progress;
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