import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../mypage/screens/mypage_screen.dart';
import '../theme.dart';
import 'services/certificate_api_service.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'widgets/wave_loading_indicator.dart';

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
    if (_isLoading == true && _roadmap.isNotEmpty) return;
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

        final dbInfo =
        await CertificateApiService.fetchCertificateInfoFromFirestore(cert.name);

        final matched = CertificateApiService.findUpcoming(schedules, cert.name);
        final detailInfo = await CertificateApiService.fetchCertificateDetailInfo(cert.name);
        final examRounds = await CertificateApiService.fetchAllExamRounds(cert.name);

        String? level = dbInfo?.level;
        String? registrationPeriod =
            dbInfo?.registrationPeriod ?? matched?.docRegPeriod;
        String? examDate = dbInfo?.examDate ?? matched?.docExamDate;

        final needsAiFill =
            level == null || registrationPeriod == null || examDate == null;
        var isEstimated = registrationPeriod == null || examDate == null;

        if (needsAiFill) {
          final aiInfo =
          await CertificateApiService.estimateCertificateInfoWithAi(cert.name);
          level ??= aiInfo.level;
          registrationPeriod ??= aiInfo.registrationPeriod;
          examDate ??= aiInfo.examDate;
          if (aiInfo.registrationPeriod != null || aiInfo.examDate != null) {
            isEstimated = true;
          }
        }

        roadmap.add(_RoadmapCertificate(
          order: i + 1,
          name: cert.name,
          description: cert.description,
          level: level,
          registrationPeriod: registrationPeriod ?? '주관 기관 홈페이지에서 확인해주세요',
          examDate: examDate ?? '-',
          isEstimated: isEstimated,
          detailInfo: detailInfo,
          examRounds: examRounds,
        ));
      }

      await _loadingController.animateTo(1.0, duration: const Duration(milliseconds: 200));
      await Future.delayed(const Duration(milliseconds: 700));
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
      MaterialPageRoute(builder: (_) => _CertificateDetailPage(certificate: certificate)),
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
                      Text(certificate.name,
                          style: TextStyle(
                              color: colors.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.2, height: 1.25)),
                      if (certificate.level != null || certificate.isEstimated) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (certificate.level != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(color: tone.bg.first, borderRadius: BorderRadius.circular(20)),
                                child: Text(certificate.level!, style: TextStyle(color: tone.fg, fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                            if (certificate.isEstimated)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFFF3F0F5), borderRadius: BorderRadius.circular(20)),
                                child: const Text('주관사 확인 필요',
                                    style: TextStyle(color: Color(0xFF897F82), fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                      ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(top: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
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
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WaveLoadingIndicator(
            size: 72,
            progress: progress.value,
            backgroundColor: colors.pinkSoft,
            waveColorStart: colors.pinkStart,
            waveColorEnd: colors.pinkDeep,
            useSmoothing: false,
          ),
          const SizedBox(height: 16),
          Text('${(progress.value * 100).toInt()}%',
              style: TextStyle(color: colors.pinkDeep, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('로드맵을 만들고 있어요',
              style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
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
  final CertificateDetailInfo? detailInfo;
  final List<CertificateExamRound> examRounds;

  const _RoadmapCertificate({
    required this.order,
    required this.name,
    required this.description,
    required this.level,
    required this.registrationPeriod,
    required this.examDate,
    required this.isEstimated,
    this.detailInfo,
    this.examRounds = const [],
  });
}

class _CertificateDetailPage extends StatelessWidget {
  final _RoadmapCertificate certificate;
  const _CertificateDetailPage({required this.certificate});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(title: certificate.name, centerTitle: false),
      body: AppMainBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailHeader(certificate: certificate, colors: colors),
                const SizedBox(height: 26),
                Text('자격증 소개',
                    style: TextStyle(color: colors.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF2E6EA)),
                  ),
                  child: Text(
                    certificate.description.isEmpty ? '등록된 소개 정보가 없어요.' : certificate.description,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13.5, height: 1.6),
                  ),
                ),
                const SizedBox(height: 26),
                Text('일정 정보',
                    style: TextStyle(color: colors.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                _ScheduleRoundsSection(
                  rounds: certificate.examRounds,
                  colors: colors,
                  fallbackRegPeriod: certificate.registrationPeriod,
                  fallbackExamDate: certificate.examDate,
                ),
                if (certificate.examRounds.isEmpty && certificate.isEstimated) ...[
                  const SizedBox(height: 14),
                  _NoticeBanner(colors: colors),
                ],

                if (certificate.detailInfo?.examFee != null) ...[
                  const SizedBox(height: 26),
                  Text('응시료', style: TextStyle(color: colors.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  _ExamFeeCard(raw: certificate.detailInfo!.examFee!),
                ],
                if (certificate.detailInfo?.examTrends != null) ...[
                  const SizedBox(height: 26),
                  Text('출제 경향', style: TextStyle(color: colors.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  _ExamTrendsCard(raw: certificate.detailInfo!.examTrends!),
                ],
                if (certificate.detailInfo?.howToObtain != null) ...[
                  const SizedBox(height: 26),
                  Text('취득 방법', style: TextStyle(color: colors.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  _HowToObtainCard(raw: certificate.detailInfo!.howToObtain!),
                ],
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse(CertificateApiService.buildApplicationUrl(certificate.name));
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.pinkStart,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 19),
                    label: const Text('신청 홈페이지 바로가기', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: colors.pinkSoft, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 19),
                    label: const Text('로드맵으로 돌아가기', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
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

class _DetailHeader extends StatelessWidget {
  final _RoadmapCertificate certificate;
  final AppColors colors;
  const _DetailHeader({required this.certificate, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.pinkSoft, colors.lavender],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [colors.pinkStart, colors.pinkDeep]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: colors.pinkStart.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
              ],
            ),
            child: Text('${certificate.order}',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${certificate.order}번째 취득 자격증',
                    style: TextStyle(color: colors.pinkDeep, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(certificate.name,
                    style: TextStyle(
                        color: colors.textPrimary, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                if (certificate.level != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)),
                    child: Text(certificate.level!,
                        style: TextStyle(color: colors.pinkDeep, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;

  const _DetailInfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF2E6EA)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  final AppColors colors;
  const _NoticeBanner({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCE5AE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFCA9A2E), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '정확한 일정은 등록된 정보가 없어 예상 값이에요. 주관 기관 홈페이지에서 다시 확인해주세요.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRoundsSection extends StatefulWidget {
  final List<CertificateExamRound> rounds;
  final AppColors colors;
  final String? fallbackRegPeriod;
  final String? fallbackExamDate;
  const _ScheduleRoundsSection({
    required this.rounds,
    required this.colors,
    this.fallbackRegPeriod,
    this.fallbackExamDate,
  });

  @override
  State<_ScheduleRoundsSection> createState() => _ScheduleRoundsSectionState();
}

class _ScheduleRoundsSectionState extends State<_ScheduleRoundsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    if (widget.rounds.isEmpty) {
      final hasFallback = (widget.fallbackRegPeriod != null && widget.fallbackRegPeriod != '주관 기관 홈페이지에서 확인해주세요')
          || (widget.fallbackExamDate != null && widget.fallbackExamDate != '-');
      if (!hasFallback) {
        return _InfoTextCard(text: '등록된 일정 정보가 없어요. 주관 기관 홈페이지에서 확인해주세요.');
      }
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF2E6EA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.fallbackRegPeriod != null)
              _DateInformation(
                icon: Icons.edit_calendar_outlined,
                label: '접수 기간',
                value: widget.fallbackRegPeriod!,
                color: colors.softBlueAccent,
              ),
            if (widget.fallbackRegPeriod != null && widget.fallbackExamDate != null)
              const SizedBox(height: 8),
            if (widget.fallbackExamDate != null)
              _DateInformation(
                icon: Icons.event_available_outlined,
                label: '시험일',
                value: widget.fallbackExamDate!,
                color: colors.pinkDeep,
              ),
          ],
        ),
      );
    }

    final current = widget.rounds.firstWhere(
          (r) => !r.isFullyClosed,
      orElse: () => widget.rounds.last,
    );
    final others = widget.rounds.where((r) => r != current).toList().reversed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RoundCard(round: current, highlighted: true, colors: colors),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_expanded ? '전체 회차 접기' : '전체 회차 보기',
                      style: TextStyle(color: colors.pinkDeep, fontSize: 13, fontWeight: FontWeight.w700)),
                  Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: colors.pinkDeep, size: 18),
                ],
              ),
            ),
          ),
          if (_expanded)
            ...others.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RoundCard(round: r, highlighted: false, colors: colors),
            )),
        ],
      ],
    );
  }
}

class _RoundCard extends StatelessWidget {
  final CertificateExamRound round;
  final bool highlighted;
  final AppColors colors;
  const _RoundCard({required this.round, required this.highlighted, required this.colors});

  @override
  Widget build(BuildContext context) {
    final closed = round.isFullyClosed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: closed ? const Color(0xFFF7F5F6) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted && !closed ? colors.pinkStart.withValues(alpha: 0.4) : const Color(0xFFF2E6EA),
          width: highlighted && !closed ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (round.roundLabel.isNotEmpty)
                Text('${round.roundLabel}회',
                    style: TextStyle(color: closed ? colors.textSecondary : colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: colors.pinkSoft, borderRadius: BorderRadius.circular(20)),
                child: Text(round.examTypeLabel, style: TextStyle(color: colors.pinkDeep, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              if (closed)
                Text('종료', style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          if (round.hasWritten) _StageRow(label: '필기', stage: round.written, colors: colors),
          if (round.hasWritten && round.hasPractical) const SizedBox(height: 8),
          if (round.hasPractical) _StageRow(label: '실기', stage: round.practical, colors: colors),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  final String label;
  final ScheduleStage stage;
  final AppColors colors;
  const _StageRow({required this.label, required this.stage, required this.colors});

  static String _fmt(DateTime? d) {
    if (d == null) return '-';
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}. $m. $day';
  }

  @override
  Widget build(BuildContext context) {
    final status = stage.status;
    final isClosed = status == ScheduleStageStatus.closed;

    late Color badgeColor;
    late Color badgeBg;
    late String badgeText;
    switch (status) {
      case ScheduleStageStatus.open:
        badgeColor = colors.pinkDeep;
        badgeBg = colors.pinkSoft;
        badgeText = '접수중';
        break;
      case ScheduleStageStatus.upcoming:
        badgeColor = colors.softBlueAccent;
        badgeBg = colors.softBlue;
        badgeText = '접수예정';
        break;
      case ScheduleStageStatus.closed:
        badgeColor = const Color(0xFF9AA0AC);
        badgeBg = const Color(0xFFF0F0F0);
        badgeText = '접수마감';
        break;
    }

    return Opacity(
      opacity: isClosed ? 0.55 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 34, child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('접수 ${_fmt(stage.regStart)} ~ ${_fmt(stage.regEnd)}',
                    style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                Text('시험일 ${_fmt(stage.examDate)}', style: TextStyle(color: colors.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
            child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _InfoTextCard extends StatelessWidget {
  final String text;
  const _InfoTextCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lines = _splitContentIntoLines(text);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF2E6EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          final isHeader = line.startsWith('<') && line.endsWith('>');
          if (isHeader) {
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                line.replaceAll('<', '').replaceAll('>', ''),
                style: TextStyle(color: colors.pinkDeep, fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(line, style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.6)),
          );
        }).toList(),
      ),
    );
  }
}

class _ExamFeeCard extends StatelessWidget {
  final String raw;
  const _ExamFeeCard({required this.raw});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fees = _parseExamFee(raw);

    if (fees.isEmpty) {
      return _InfoTextCard(text: raw);
    }

    return Row(
      children: fees.asMap().entries.map((entry) {
        final index = entry.key;
        final fee = entry.value;
        final isFirst = index == 0;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: isFirst ? 0 : 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isFirst
                      ? [colors.pinkSoft, colors.pinkEnd]
                      : [colors.lavender, colors.lavender],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payments_outlined,
                          size: 15, color: isFirst ? colors.pinkDeep : colors.lavenderAccent),
                      const SizedBox(width: 5),
                      Text(fee.label,
                          style: TextStyle(
                            color: isFirst ? colors.pinkDeep : colors.lavenderAccent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatWon(fee.amount),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ExamTrendsCard extends StatelessWidget {
  final String raw;
  const _ExamTrendsCard({required this.raw});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final data = _parseExamTrends(raw);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF2E6EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.header != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: colors.pinkSoft, borderRadius: BorderRadius.circular(20)),
              child: Text(data.header!, style: TextStyle(color: colors.pinkDeep, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 12),
          ],
          if (data.topics.length > 1)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.topics.asMap().entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.pinkSoft.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: colors.pinkStart, shape: BoxShape.circle),
                        child: Text('${e.key + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(e.value, style: TextStyle(color: colors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          else if (data.topics.isNotEmpty)
            Text(data.topics.first, style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.7)),
          if (data.detailNote != null && data.detailNote!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF9F5F6), borderRadius: BorderRadius.circular(14)),
              child: Text(data.detailNote!, style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.6)),
            ),
          ],
          if (data.refUrl != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.link_rounded, size: 15, color: colors.softBlueAccent),
                const SizedBox(width: 5),
                Text(data.refUrl!, style: TextStyle(color: colors.softBlueAccent, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HowToObtainCard extends StatelessWidget {
  final String raw;
  const _HowToObtainCard({required this.raw});

  static IconData _iconFor(String label) {
    if (label.contains('시행')) return Icons.apartment_rounded;
    if (label.contains('학과')) return Icons.school_outlined;
    if (label.contains('과목')) return Icons.menu_book_outlined;
    if (label.contains('검정') || label.contains('방법')) return Icons.quiz_outlined;
    if (label.contains('합격') || label.contains('기준')) return Icons.emoji_events_outlined;
    return Icons.info_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = _parseHowToObtain(raw);

    if (items.isEmpty) return _InfoTextCard(text: raw);

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF2E6EA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: colors.softBlue, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(_iconFor(item.label), size: 18, color: colors.softBlueAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label, style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),

                      if (item.writtenSubjects != null) ...[
                        Text('필기', style: TextStyle(color: colors.pinkDeep, fontSize: 11, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: item.writtenSubjects!.map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: colors.pinkSoft.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(s, style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                          )).toList(),
                        ),
                        if (item.practicalSubjects != null && item.practicalSubjects!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text('실기', style: TextStyle(color: colors.pinkDeep, fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(item.practicalSubjects!,
                              style: TextStyle(color: colors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ] else
                        Text(item.value ?? '',
                            style: TextStyle(color: colors.textPrimary, fontSize: 12.5, height: 1.55, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
List<String> _splitContentIntoLines(String raw) {
  var text = raw;
  text = text.replaceAllMapped(RegExp(r'(<[^>]+>)'), (m) => '\n${m.group(1)}\n');
  text = text.replaceAllMapped(RegExp(r'(?<=\)|다|음|함)(\d{1,2}\.\s)'), (m) => '\n${m.group(1)}');
  text = text.replaceAllMapped(RegExp(r'([①②③④⑤⑥⑦⑧⑨⑩])'), (m) => '\n${m.group(1)}');
  return text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
}

class _FeeItem {
  final String label;
  final int amount;
  const _FeeItem({required this.label, required this.amount});
}

List<_FeeItem> _parseExamFee(String raw) {
  final items = <_FeeItem>[];
  final parts = raw.split(',');
  for (final part in parts) {
    final match = RegExp(r'([^:：]+)[:：]\s*([\d,]+)').firstMatch(part.trim());
    if (match != null) {
      final label = match.group(1)!.trim();
      final amount = int.tryParse(match.group(2)!.replaceAll(',', '')) ?? 0;
      if (amount > 0) items.add(_FeeItem(label: label, amount: amount));
    }
  }
  return items;
}

class _ObtainItem {
  final String label;
  final String? value;
  final List<String>? writtenSubjects;
  final String? practicalSubjects;
  const _ObtainItem({required this.label, this.value, this.writtenSubjects, this.practicalSubjects});
}

List<_ObtainItem> _parseHowToObtain(String raw) {
  final items = <_ObtainItem>[];
  final markerRegex = RegExp(r'[①②③④⑤⑥⑦⑧⑨⑩]');
  final matches = markerRegex.allMatches(raw).toList();

  for (var i = 0; i < matches.length; i++) {
    final start = matches[i].end;
    final end = i + 1 < matches.length ? matches[i + 1].start : raw.length;
    final segment = raw.substring(start, end).trim();
    if (segment.isEmpty) continue;

    if (segment.contains('필기') && RegExp(r'\d\.').hasMatch(segment)) {
      final labelMatch = RegExp(r'^([^\-:：]+)').firstMatch(segment);
      var label = (labelMatch?.group(1) ?? '시험과목').replaceAll('필기', '').trim();
      if (label.isEmpty) label = '시험과목';

      final hasPractical = segment.contains('실기');
      final writtenPart = segment.substring(
        segment.indexOf('필기') + 2,
        hasPractical ? segment.indexOf('실기') : segment.length,
      );

      final subjects = RegExp(r'\d{1,2}\.\s*([^\d]+?)(?=\d{1,2}\.|$)')
          .allMatches(writtenPart)
          .map((m) => m.group(1)!.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      String? practical;
      if (hasPractical) {
        practical = segment
            .substring(segment.indexOf('실기') + 2)
            .replaceFirst(RegExp(r'^[\s\-:：]+'), '')
            .trim();
      }

      items.add(_ObtainItem(label: label, writtenSubjects: subjects, practicalSubjects: practical));
    } else {
      final match = RegExp(r'^([^:：]+)[:：]\s*(.*)$', dotAll: true).firstMatch(segment);
      if (match != null) {
        items.add(_ObtainItem(label: match.group(1)!.trim(), value: match.group(2)!.trim()));
      } else {
        items.add(_ObtainItem(label: segment));
      }
    }
  }
  return items;
}

class _ExamTrendsData {
  final String? header;
  final List<String> topics;
  final String? detailNote;
  final String? refUrl;
  const _ExamTrendsData({this.header, required this.topics, this.detailNote, this.refUrl});
}

_ExamTrendsData _parseExamTrends(String raw) {
  final headerMatches = RegExp(r'<([^>]+)>').allMatches(raw).toList();
  final header = headerMatches.isNotEmpty ? headerMatches.first.group(1) : null;

  String? detailNote;
  if (headerMatches.length > 1) {
    detailNote = raw.substring(headerMatches[1].start).replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }

  final topicsStart = headerMatches.isNotEmpty ? headerMatches.first.end : 0;
  final topicsEnd = headerMatches.length > 1 ? headerMatches[1].start : raw.length;
  var body = raw.substring(topicsStart, topicsEnd).trim();

  String? refUrl;
  final urlMatch = RegExp(r'\(?(www\.[^\s\)]+)\)?').firstMatch(body);
  if (urlMatch != null) {
    refUrl = urlMatch.group(1);
    body = body.replaceAll(urlMatch.group(0)!, '').trim();
  }

  var topics = RegExp(r'(\d{1,2})\.\s*([^\d]+?)(?=\d{1,2}\.|$)')
      .allMatches(body)
      .map((m) => m.group(2)!.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  if (topics.length < 2) {
    topics = body
        .split(RegExp(r'\s*-\s*'))
        .map((s) => s.trim())
        .where((s) => s.length > 1)
        .toList();
  }

  if (topics.isEmpty && body.isNotEmpty) topics = [body];

  return _ExamTrendsData(header: header, topics: topics, detailNote: detailNote, refUrl: refUrl);
}

String _formatWon(int amount) {
  final str = amount.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
    buffer.write(str[i]);
  }
  return '${buffer.toString()}원';
}