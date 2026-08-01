import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

import '../theme.dart';
import 'services/certificate_api_service.dart';
import 'certificate_roadmap_result_page.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'widgets/wave_loading_indicator.dart';

class CertificateRoadmapPage extends StatefulWidget {
  CertificateRoadmapPage({super.key});

  @override
  State<CertificateRoadmapPage> createState() => _CertificateRoadmapPageState();
}

class _CertificateRoadmapPageState extends State<CertificateRoadmapPage>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  late final AnimationController _loadingController;

  final TextEditingController _jobController = TextEditingController();
  final TextEditingController _customCertController = TextEditingController();

  bool _isLoadingSuggestions = false;
  String? _suggestionError;
  String? _jobInputError;
  String? _customCertError;
  List<SuggestedCertificate> _suggestedCertificates = [];

  final Set<String> _ownedCertificates = {};
  final Set<String> _customAddedCertificates = {};
  bool _isCheckingCertName = false;
  bool _isNavigatingToResult = false;

  List<_PopularJob> _popularJobs = [];
  bool _isLoadingPopularJobs = true;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(vsync: this);
    _loadPopularJobs();
  }

  Future<void> _loadPopularJobs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('job_popularity')
          .orderBy('count', descending: true)
          .limit(5)
          .get();

      if (!mounted) return;
      setState(() {
        _popularJobs = snapshot.docs
            .map(
              (doc) => _PopularJob(
                displayName: (doc.data()['displayName'] as String?) ?? doc.id,
                count: (doc.data()['count'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList();
        _isLoadingPopularJobs = false;
      });
    } catch (e) {
      debugPrint('인기 직종 불러오기 에러: $e');
      if (!mounted) return;
      setState(() => _isLoadingPopularJobs = false);
    }
  }

  void _selectPopularJob(String job) {
    _jobController.text = job;
    _jobController.selection = TextSelection.collapsed(offset: job.length);
    if (_jobInputError != null) setState(() => _jobInputError = null);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _jobController.dispose();
    _customCertController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  String? _validateFreeText(String value, {int minLen = 2, int maxLen = 25}) {
    if (value.length < minLen || value.length > maxLen) {
      return '$minLen~$maxLen자 사이로 입력해주세요.';
    }
    if (!RegExp(r'^[가-힣a-zA-Z0-9\s()\-/&]+$').hasMatch(value)) {
      return '특수문자는 사용할 수 없어요.';
    }
    if (RegExp(r'(.)\1{4,}').hasMatch(value)) {
      return '올바른 값을 입력해주세요.';
    }
    if (!RegExp(r'[가-힣a-zA-Z]').hasMatch(value)) {
      return '직무명을 입력해주세요.';
    }
    return null;
  }

  Future<void> _onFindCertificates() async {
    if (_isLoadingSuggestions) return;

    final job = _jobController.text.trim();
    if (job.isEmpty) return;

    final error = _validateFreeText(job);
    if (error != null) {
      setState(() => _jobInputError = error);
      return;
    }

    setState(() {
      _jobInputError = null;
      _isLoadingSuggestions = true;
      _suggestionError = null;
      _suggestedCertificates = [];
      _ownedCertificates.clear();
    });

    _loadingController.value = 0;
    _loadingController.duration = Duration(milliseconds: 1500);
    _loadingController.animateTo(0.9, curve: Curves.easeOut);

    try {
      final suggestions = await CertificateApiService.suggestCertificates(job);

      await _loadingController.animateTo(
        1.0,
        duration: Duration(milliseconds: 200),
      );
      await Future.delayed(Duration(milliseconds: 300));
      if (!mounted) return;

      setState(() {
        _suggestedCertificates = suggestions;
        _isLoadingSuggestions = false;
      });
      if (suggestions.isEmpty) {
        setState(
          () => _suggestionError = '해당 직무에 대한 자격증을 찾지 못했어요. 다른 직무로 시도해주세요.',
        );
        return;
      }
      _goToStep(1);
    } catch (e) {
      debugPrint('자격증 추천 에러: $e');
      _loadingController.stop();
      if (!mounted) return;
      setState(() {
        _isLoadingSuggestions = false;
        _suggestionError = '추천을 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  void _toggleOwned(String certificate, bool owned) {
    setState(() {
      if (owned) {
        _ownedCertificates.add(certificate);
      } else {
        _ownedCertificates.remove(certificate);
        if (_customAddedCertificates.contains(certificate)) {
          _suggestedCertificates.removeWhere((c) => c.name == certificate);
          _customAddedCertificates.remove(certificate);
        }
      }
    });
  }

  void _commitCustomCertificate(String name) {
    setState(() {
      _customCertError = null;
      if (!_suggestedCertificates.any((c) => c.name == name)) {
        _suggestedCertificates.add(
          SuggestedCertificate(name: name, description: ''),
        );
      }
      _ownedCertificates.add(name);
      _customAddedCertificates.add(name);
      _customCertController.clear();
    });
  }

  Future<void> _addCustomCertificate() async {
    if (_isCheckingCertName) return;

    final name = _customCertController.text.trim();
    if (name.isEmpty) return;

    final error = _validateFreeText(name);
    if (error != null) {
      setState(() => _customCertError = error);
      return;
    }

    setState(() => _isCheckingCertName = true);
    try {
      final isValid = await CertificateApiService.validateCertificateName(name);
      setState(() => _isCheckingCertName = false);

      if (isValid) {
        _commitCustomCertificate(name);
        return;
      }

      if (!mounted) return;
      final confirmed = await _showUnverifiedCertDialog(name);
      if (confirmed == true) _commitCustomCertificate(name);
    } catch (_) {
      setState(() => _isCheckingCertName = false);
      _commitCustomCertificate(name);
    }
  }

  Future<bool?> _showUnverifiedCertDialog(String name) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogContext) {
        final c = dialogContext.colors;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: EdgeInsets.fromLTRB(26, 30, 26, 22),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 30,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.pinkSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.help_outline_rounded,
                    color: c.pinkStart,
                    size: 30,
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  '확인되지 않는 자격증이에요',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 13.5,
                      height: 1.55,
                    ),
                    children: [
                      TextSpan(text: '"'),
                      TextSpan(
                        text: name,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: '"은(는) 자격증 정보에서\n확인되지 않았어요. 그래도 추가할까요?'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.textSecondary,
                          side: BorderSide(color: c.pinkSoft),
                          padding: EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          '취소',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
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
                            onTap: () => Navigator.pop(dialogContext, true),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Center(
                                child: Text(
                                  '그래도 추가',
                                  style: TextStyle(
                                    color: context.colors.onPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
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
          ),
        );
      },
    );
  }

  Future<void> _goToResultScreen() async {
    if (_isNavigatingToResult) return; // 결과 화면으로 두 번 넘어가는 것 방지

    final recommended = _suggestedCertificates
        .where((c) => !_ownedCertificates.contains(c.name))
        .toList();

    if (recommended.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('추천할 자격증이 없어요. 이미 보유한 자격증을 확인해주세요.')),
      );
      return;
    }

    setState(() => _isNavigatingToResult = true);
    final result = await Navigator.push(
      context,
      _slideRoute(
        CertificateRoadmapResultPage(
          job: _jobController.text.trim(),
          certificates: recommended,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _isNavigatingToResult = false);

    if (result == 'restart') {
      setState(() {
        _jobController.clear();
        _customCertController.clear();
        _suggestedCertificates = [];
        _ownedCertificates.clear();
        _customAddedCertificates.clear();
        _suggestionError = null;
        _jobInputError = null;
      });
      _goToStep(0);
    }
  }

  Route _slideRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: Duration(milliseconds: 340),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final tween = Tween(
          begin: Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(
        title: 'AI 자격증 로드맵',
        centerTitle: false,
        // 2단계에서는 페이지 뒤로가기가 아니라 1단계로 슬라이드 복귀
        leading: _currentStep == 1
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => _goToStep(0),
              )
            : null,
      ),
      // After
      body: AppMainBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // PageView가 화면 전체 높이를 차지 → 진짜 정중앙 센터링 가능
              Positioned.fill(
                child: PageView(
                  controller: _pageController,
                  physics: NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentStep = i),
                  children: [_buildStep1(colors), _buildStep2(colors)],
                ),
              ),
              Positioned(
                top: 48,
                left: 0,
                right: 0,
                child: _StepProgressBar(
                  currentStep: _currentStep,
                  colors: colors,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(AppColors colors) {
    return Align(
      alignment: Alignment(0, -0.15),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_isLoadingSuggestions),
                child: _isLoadingSuggestions
                    ? _buildLoadingContent(colors)
                    : _buildIdleContent(colors),
              ),
            ),
            if (_suggestionError != null) ...[
              SizedBox(height: 18),
              _InlineMessage(text: _suggestionError!, colors: colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIdleContent(AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FadeSlideIn(
          delay: Duration(milliseconds: 200),
          duration: Duration(milliseconds: 700),
          child: Column(
            children: [
              Text(
                '원하는 직무를 입력해주세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '직무를 알려주시면 AI가 어울리는 자격증을 순서대로 추천해드려요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        _FadeSlideIn(
          delay: Duration(milliseconds: 400),
          duration: Duration(milliseconds: 900),
          child: _buildJobInput(colors),
        ),
        SizedBox(height: 22),
        _FadeSlideIn(
          delay: Duration(milliseconds: 600),
          duration: Duration(milliseconds: 900),
          child: _buildPopularJobs(colors),
        ),
      ],
    );
  }

  Widget _buildLoadingContent(AppColors colors) {
    final job = _jobController.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AI가 자격증을 찾고 있어요',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '$job 직무에 맞는 자격증을 분석하고 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        SizedBox(height: 30),
        _LoadingIndicator(progress: _loadingController, colors: colors),
      ],
    );
  }

  Widget _buildPopularJobs(AppColors colors) {
    if (_isLoadingPopularJobs) {
      return SizedBox(
        height: 20,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.pinkSoft,
            ),
          ),
        ),
      );
    }
    if (_popularJobs.isEmpty) return SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.pinkStart, colors.pinkDeep],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.trending_up_rounded,
                size: 11,
                color: context.colors.onPrimary,
              ),
            ),
            SizedBox(width: 6),
            Text(
              '요즘 인기있는 직종',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_popularJobs.length, (index) {
            final job = _popularJobs[index];
            return _PopularJobChip(
              rank: index + 1,
              job: job,
              colors: colors,
              onTap: _isLoadingSuggestions
                  ? null
                  : () => _selectPopularJob(job.displayName),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStep2(AppColors colors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
            child: Center(
              child: _FadeSlideIn(
                delay: Duration(milliseconds: 300),
                duration: Duration(milliseconds: 800),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '보유 자격증을 선택해주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '이미 갖고 있는 자격증을 체크하면 추천에서 제외돼요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildCertificateSelector(colors),
                    SizedBox(height: 12),
                    _buildCustomCertInput(colors),
                    SizedBox(height: 30),
                    _buildGenerateButton(colors),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildJobInput(AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _jobInputError != null
              ? context.colors.incorrect
              : colors.pinkSoft,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14C98198),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _jobController,
            onSubmitted: (_) => _onFindCertificates(),
            onChanged: (_) {
              if (_jobInputError != null) setState(() => _jobInputError = null);
            },
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: '예: 백엔드 개발자, 데이터 분석가',
              hintStyle: TextStyle(
                color: context.colors.textMuted,
                fontSize: 15,
              ),
              prefixIcon: Padding(
                padding: EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.pinkSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.work_outline_rounded,
                    color: colors.pinkStart,
                    size: 19,
                  ),
                ),
              ),
              prefixIconConstraints: BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              suffixIcon: Padding(
                padding: EdgeInsets.only(right: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.pinkStart,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _isLoadingSuggestions ? null : _onFindCertificates,
                      child: _isLoadingSuggestions
                          ? Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: context.colors.surface,
                                  strokeWidth: 2.2,
                                ),
                              ),
                            )
                          : Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.search_rounded,
                                color: context.colors.onPrimary,
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              contentPadding: EdgeInsets.fromLTRB(
                6,
                17,
                6,
                _jobInputError != null ? 6 : 17,
              ),
              border: InputBorder.none,
            ),
          ),
          if (_jobInputError != null)
            Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Text(
                _jobInputError!,
                style: TextStyle(
                  color: context.colors.incorrect,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCertificateSelector(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.pinkSoft),
        boxShadow: [
          BoxShadow(
            color: Color(0x0FC98198),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 12,
        children: List.generate(_suggestedCertificates.length, (index) {
          final cert = _suggestedCertificates[index];
          final isOwned = _ownedCertificates.contains(cert.name);
          final palette = [
            (
              bg: colors.pinkSoft,
              selected: colors.pinkStart,
              border: colors.pinkStart,
            ),
            (
              bg: colors.lavender,
              selected: colors.lavenderAccent,
              border: colors.lavenderAccent,
            ),
            (
              bg: colors.mint,
              selected: colors.mintAccent,
              border: colors.mintAccent,
            ),
          ];
          final tone = palette[index % palette.length];
          return FilterChip(
            selected: isOwned,
            label: Text(cert.name),
            onSelected: (selected) => _toggleOwned(cert.name, selected),
            showCheckmark: true,
            checkmarkColor: context.colors.onPrimary,
            selectedColor: tone.selected,
            backgroundColor: tone.bg,
            side: BorderSide(
              color: isOwned ? tone.border : Colors.transparent,
              width: isOwned ? 1.4 : 1,
            ),
            labelStyle: TextStyle(
              color: isOwned ? context.colors.onPrimary : colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCustomCertInput(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customCertController,
                onSubmitted: (_) => _addCustomCertificate(),
                onChanged: (_) {
                  if (_customCertError != null)
                    setState(() => _customCertError = null);
                },
                style: TextStyle(
                  fontSize: 13.5,
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '목록에 없는 보유 자격증 직접 입력',
                  hintStyle: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 13,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  filled: true,
                  fillColor: context.colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _customCertError != null
                          ? context.colors.incorrect
                          : colors.pinkSoft,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _customCertError != null
                          ? context.colors.incorrect
                          : colors.pinkSoft,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.pinkStart,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _isCheckingCertName ? null : _addCustomCertificate,
                  child: Padding(
                    padding: EdgeInsets.all(13),
                    child: _isCheckingCertName
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: context.colors.surface,
                              strokeWidth: 2.2,
                            ),
                          )
                        : Icon(
                            Icons.add_rounded,
                            color: context.colors.onPrimary,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_customCertError != null)
          Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Text(
              _customCertError!,
              style: TextStyle(
                color: context.colors.incorrect,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGenerateButton(AppColors colors) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          color: colors.pinkStart,
          boxShadow: [
            BoxShadow(
              color: colors.pinkStart.withValues(alpha: 0.2),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(21),
            onTap: _isNavigatingToResult ? null : _goToResultScreen,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 21,
                    color: context.colors.onPrimary,
                  ),
                  SizedBox(width: 9),
                  Text(
                    '자격증 로드맵 생성하기',
                    style: TextStyle(
                      color: context.colors.onPrimary,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  final AppColors colors;
  _StepProgressBar({required this.currentStep, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (i) {
        final active = i == currentStep;
        final done = i < currentStep;
        return AnimatedContainer(
          duration: Duration(milliseconds: 280),
          curve: Curves.easeOut,
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 18,
          height: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: (active || done) ? colors.pinkStart : colors.pinkSoft,
          ),
        );
      }),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  final Animation<double> progress;
  final AppColors colors;
  _LoadingIndicator({required this.progress, required this.colors});

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
          SizedBox(height: 12),
          Text(
            '${(progress.value * 100).toInt()}%',
            style: TextStyle(
              color: colors.pinkStart,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final String text;
  final AppColors colors;
  _InlineMessage({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.pinkSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.pinkBorder),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PopularJob {
  final String displayName;
  final int count;
  _PopularJob({required this.displayName, required this.count});
}

class _PopularJobChip extends StatelessWidget {
  final int rank;
  final _PopularJob job;
  final AppColors colors;
  final VoidCallback? onTap;

  _PopularJobChip({
    required this.rank,
    required this.job,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 1;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isTop ? colors.pinkStart : colors.pinkSoft,
              width: isTop ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x0FC98198),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$rank',
                style: TextStyle(
                  color: isTop ? colors.pinkStart : colors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 6),
              Text(
                job.displayName,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  _FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
  });

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween(
    begin: Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

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
