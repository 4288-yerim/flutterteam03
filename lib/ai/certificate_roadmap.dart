import 'package:flutter/material.dart';

import '../theme.dart';
import 'services/certificate_api_service.dart';
import 'certificate_roadmap_result_page.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class CertificateRoadmapPage extends StatefulWidget {
  const CertificateRoadmapPage({super.key});

  @override
  State<CertificateRoadmapPage> createState() =>
      _CertificateRoadmapPageState();
}

class _CertificateRoadmapPageState extends State<CertificateRoadmapPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

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

  @override
  void dispose() {
    _pageController.dispose();
    _jobController.dispose();
    _customCertController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
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

    try {
      final suggestions = await CertificateApiService.suggestCertificates(job);
      setState(() {
        _suggestedCertificates = suggestions;
        _isLoadingSuggestions = false;
      });
      if (suggestions.isEmpty) {
        setState(() => _suggestionError = '해당 직무에 대한 자격증을 찾지 못했어요. 다른 직무로 시도해주세요.');
        return;
      }
      _goToStep(1); // 성공하면 자동으로 2단계로 슬라이드
    } catch (e) {
      debugPrint('자격증 추천 에러: $e');
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
        _suggestedCertificates.add(SuggestedCertificate(name: name, description: ''));
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
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [c.lavender, c.pinkSoft]),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.help_outline_rounded, color: c.lavenderAccent, size: 30),
                ),
                const SizedBox(height: 18),
                Text('확인되지 않는 자격증이에요',
                    style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.55),
                    children: [
                      const TextSpan(text: '"'),
                      TextSpan(text: name, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
                      const TextSpan(text: '"은(는) 자격증 정보에서\n확인되지 않았어요. 그래도 추가할까요?'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.textSecondary,
                          side: BorderSide(color: c.pinkSoft),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: LinearGradient(colors: [c.pinkStart, c.pinkDeep]),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () => Navigator.pop(dialogContext, true),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Center(
                                child: Text('그래도 추가',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
        const SnackBar(content: Text('추천할 자격증이 없어요. 이미 보유한 자격증을 확인해주세요.')),
      );
      return;
    }

    setState(() => _isNavigatingToResult = true);
    final result = await Navigator.push(
      context,
      _slideRoute(CertificateRoadmapResultPage(
        job: _jobController.text.trim(),
        certificates: recommended,
      )),
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
      transitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final tween = Tween(begin: const Offset(1, 0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic));
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => _goToStep(0),
        )
            : null,
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 48),
              _StepProgressBar(currentStep: _currentStep, colors: colors),
              const SizedBox(height: 8),
              Expanded(
                child: PageView(
                controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentStep = i),
                  children: [
                    _FadeSlideIn(key: ValueKey('step0-$_currentStep'), child: _buildStep1(colors)),
                    _FadeSlideIn(key: ValueKey('step1-$_currentStep'), child: _buildStep2(colors)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(AppColors colors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 44),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('원하는 직무를 입력해주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textPrimary, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text('직무를 알려주시면 AI가 어울리는 자격증을 순서대로 추천해드려요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary, fontSize: 13.5, height: 1.5)),
                  const SizedBox(height: 24),
                  _buildJobInput(colors),
                  if (_isLoadingSuggestions) ...[
                    const SizedBox(height: 34),
                    _LoadingIndicator(label: 'AI가 자격증을 찾고 있어요', colors: colors),
                  ],
                  if (_suggestionError != null) ...[
                    const SizedBox(height: 18),
                    _InlineMessage(text: _suggestionError!, colors: colors),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep2(AppColors colors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 44),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('보유 자격증을 선택해주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textPrimary, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text('이미 갖고 있는 자격증을 체크하면 추천에서 제외돼요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary, fontSize: 13.5, height: 1.5)),
                  const SizedBox(height: 20),
                  _buildCertificateSelector(colors),
                  const SizedBox(height: 12),
                  _buildCustomCertInput(colors),
                  const SizedBox(height: 30),
                  _buildGenerateButton(colors),
                ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _jobInputError != null ? const Color(0xFFE96B7A) : colors.pinkSoft),
        boxShadow: const [BoxShadow(color: Color(0x14C98198), blurRadius: 18, offset: Offset(0, 8))],
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
            style: TextStyle(color: colors.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: '예: 백엔드 개발자, 데이터 분석가',
              hintStyle: const TextStyle(color: Color(0xFFB7AFB1), fontSize: 15),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [colors.pinkSoft, colors.lavender]),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.work_outline_rounded, color: colors.pinkDeep, size: 19),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [colors.pinkStart, colors.lavenderAccent]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _isLoadingSuggestions ? null : _onFindCertificates,
                      child: _isLoadingSuggestions
                          ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2)),
                      )
                          : const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.search_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 17),
              border: InputBorder.none,
            ),
          ),
          if (_jobInputError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Text(_jobInputError!,
                  style: const TextStyle(color: Color(0xFFE05169), fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildCertificateSelector(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFD),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.pinkSoft),
        boxShadow: const [BoxShadow(color: Color(0x0FC98198), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 12,
        children: List.generate(_suggestedCertificates.length, (index) {
          final cert = _suggestedCertificates[index];
          final isOwned = _ownedCertificates.contains(cert.name);
          final palette = [
            (bg: colors.pinkSoft, selected: colors.pinkStart, border: colors.pinkStart),
            (bg: colors.lavender, selected: colors.lavenderAccent, border: colors.lavenderAccent),
            (bg: colors.mint, selected: colors.mintAccent, border: colors.mintAccent),
          ];
          final tone = palette[index % palette.length];
          return FilterChip(
            selected: isOwned,
            label: Text(cert.name),
            onSelected: (selected) => _toggleOwned(cert.name, selected),
            showCheckmark: true,
            checkmarkColor: Colors.white,
            selectedColor: tone.selected,
            backgroundColor: tone.bg,
            side: BorderSide(color: isOwned ? tone.border : Colors.transparent, width: isOwned ? 1.4 : 1),
            labelStyle: TextStyle(color: isOwned ? Colors.white : colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
                  if (_customCertError != null) setState(() => _customCertError = null);
                },
                style: TextStyle(fontSize: 13.5, color: colors.textPrimary, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: '목록에 없는 보유 자격증 직접 입력',
                  hintStyle: const TextStyle(color: Color(0xFFB7AFB1), fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _customCertError != null ? const Color(0xFFE96B7A) : colors.pinkSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _customCertError != null ? const Color(0xFFE96B7A) : colors.pinkSoft),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [colors.mintAccent, colors.softBlueAccent]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _isCheckingCertName ? null : _addCustomCertificate,
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: _isCheckingCertName
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                        : const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_customCertError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(_customCertError!, style: const TextStyle(color: Color(0xFFE05169), fontSize: 12.5, fontWeight: FontWeight.w600)),
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
          gradient: LinearGradient(colors: [colors.pinkStart, colors.lavenderAccent], begin: Alignment.centerLeft, end: Alignment.centerRight),
          boxShadow: [BoxShadow(color: colors.pinkStart.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8))],
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
                  const Icon(Icons.auto_awesome_rounded, size: 21, color: Colors.white),
                  const SizedBox(width: 9),
                  const Text('자격증 로드맵 생성하기',
                      style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
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
  const _StepProgressBar({required this.currentStep, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (i) {
        final active = i == currentStep;
        final done = i < currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 18,
          height: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: (active || done)
                ? LinearGradient(colors: [colors.pinkStart, colors.lavenderAccent])
                : null,
            color: (active || done) ? null : colors.pinkSoft,
          ),
        );
      }),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  final String label;
  final AppColors colors;
  const _LoadingIndicator({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: colors.pinkStart, strokeWidth: 3)),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _InlineMessage({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: colors.pinkSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFBDDE3))),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontSize: 13.5, fontWeight: FontWeight.w600)),
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