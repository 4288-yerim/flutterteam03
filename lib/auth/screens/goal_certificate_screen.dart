import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';
import '../widgets/step_indicator.dart';
import '../../ai/services/certificate_api_service.dart';
import '../../ai/widgets/wave_loading_indicator.dart';

class GoalCertificateScreen extends StatefulWidget {
  final void Function(BuildContext context, String? goalCertificateId) onNext;

  const GoalCertificateScreen({super.key, required this.onNext});

  @override
  State<GoalCertificateScreen> createState() => _GoalCertificateScreenState();
}

enum _SearchStatus { idle, loading, done }

class _GoalCertificateScreenState extends State<GoalCertificateScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedId;
  String? _selectedName;
  final _searchController = TextEditingController();

  bool _isLoadingAll = true;
  List<Map<String, dynamic>> _results = [];
  bool _isAdding = false;

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
        );
    _entryController.forward();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      await CertificateApiService.loadAllCertifications();
    } catch (e) {
      debugPrint('자격증 전체 로드 실패: $e');
    }
    if (!mounted) return;
    setState(() => _isLoadingAll = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() {
      _results = CertificateApiService.filterCertifications(
        _searchController.text,
      );
    });
  }

  void _select(String id, String name) {
    setState(() {
      if (_selectedId == id) {
        _selectedId = null;
        _selectedName = null;
      } else {
        _selectedId = id;
        _selectedName = name;
      }
    });
  }

  Future<void> _confirmAddCertificate() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _isAdding) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: context.colors.overlay,
      builder: (dialogContext) => _AddCertificateDialog(query: query),
    );
    if (confirmed != true) return;

    setState(() => _isAdding = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: context.colors.overlay,
      builder: (_) => _AiVerifyingDialog(query: query),
    );

    final result = await CertificateApiService.addCertificationWithAi(query);
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _isAdding = false);

    if (!result.success || result.certificate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '자격증을 추가하지 못했어요.')),
      );
      return;
    }

    final cert = result.certificate!;
    final id = cert['jmcd'] as String?;
    final name = cert['jmfldnm'] as String?;
    if (id == null || name == null) return;

    await CertificateApiService.loadAllCertifications(forceRefresh: true);

    setState(() {
      _results = [cert, ..._results];
      _selectedId = id;
      _selectedName = name;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('자격증을 추가했어요.')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        StepIndicator(
                          currentStep: 1,
                          label: '1단계 · 목표 자격증',
                          colors: colors,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '목표 자격증이\n있으신가요?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '선택해주시면 맞춤 학습 캘린더를 준비해드려요.\n나중에 언제든 바꿀 수 있어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.6,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _searchController,
                          enabled: !_isLoadingAll,
                          decoration: InputDecoration(
                            hintText: _isLoadingAll
                                ? '자격증 목록을 불러오는 중...'
                                : '자격증 이름으로 검색해보세요',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: colors.textSecondary.withOpacity(0.7),
                            ),
                            filled: true,
                            fillColor: colors.background,
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: colors.textSecondary,
                              size: 20,
                            ),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: colors.textSecondary,
                                      size: 18,
                                    ),
                                    onPressed: () => _searchController.clear(),
                                  ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: colors.textSecondary.withOpacity(0.2),
                                width: 1.2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: colors.textSecondary.withOpacity(0.2),
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: colors.pinkStart,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildBody(colors)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: AppButton(
                      text: _selectedId == null ? '다음에 정할게요' : '선택 완료',
                      type: AppButtonType.primaryPink,
                      onPressed: () => widget.onNext(context, _selectedId),
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

  Widget _buildBody(AppColors colors) {
    if (_isLoadingAll) {
      return Center(child: CircularProgressIndicator(color: colors.pinkStart));
    }
    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            '자격증 이름을 검색해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return _EmptySearchState(
        colors: colors,
        query: _searchController.text.trim(),
        isAdding: _isAdding,
        onAdd: _confirmAddCertificate,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final cert = _results[index];
        final id = cert['jmcd'] as String? ?? '';
        final name = cert['jmfldnm'] as String? ?? '';
        final category =
            (cert['obligfldnm'] as String?) ??
            (cert['qualgbnm'] as String?) ??
            '기타';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CertificateCard(
            id: id,
            name: name,
            category: category,
            isSelected: _selectedId == id,
            colors: colors,
            onTap: () => _select(id, name),
          ),
        );
      },
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  final AppColors colors;
  final String query;
  final bool isAdding;
  final VoidCallback onAdd;

  const _EmptySearchState({
    required this.colors,
    required this.query,
    required this.isAdding,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: colors.textSecondary.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              '\'$query\'에 대한 검색 결과가 없어요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: isAdding ? null : onAdd,
              icon: isAdding
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.pinkStart,
                      ),
                    )
                  : Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: colors.pinkStart,
                    ),
              label: Text(
                isAdding ? 'AI가 확인하는 중...' : 'AI로 확인 후 추가하기',
                style: TextStyle(
                  color: colors.pinkStart,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.pinkStart),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  final String id;
  final String name;
  final String category;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onTap;

  const _CertificateCard({
    required this.id,
    required this.name,
    required this.category,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.pinkStart.withOpacity(0.10)
              : colors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? colors.pinkStart
                : colors.textSecondary.withOpacity(0.15),
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.pinkStart.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isSelected
                    ? colors.pinkStart
                    : colors.pinkStart.withOpacity(0.10),
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 22,
                color: isSelected ? colors.onPrimary : colors.pinkStart,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colors.pinkStart : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? colors.pinkStart
                      : colors.textSecondary.withOpacity(0.35),
                  width: 1.6,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded, size: 14, color: colors.onPrimary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCertificateDialog extends StatelessWidget {
  final String query;
  const _AddCertificateDialog({required this.query});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow,
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.pinkStart, colors.pinkStart.withOpacity(0.7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.pinkStart.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: colors.onPrimary,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),

            Text(
              '자격증 확인하기',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: colors.textSecondary,
                ),
                children: [
                  const TextSpan(text: '\''),
                  TextSpan(
                    text: query,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const TextSpan(text: '\'가 실제 존재하는\n자격증인지 따iT이 확인한 뒤 추가할게요.'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: colors.textSecondary.withOpacity(0.25),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [
                          colors.pinkStart,
                          colors.pinkStart.withOpacity(0.85),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.pinkStart.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(context, true),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              '확인',
                              style: TextStyle(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
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
  }
}

class _AiVerifyingDialog extends StatefulWidget {
  final String query;
  const _AiVerifyingDialog({required this.query});

  @override
  State<_AiVerifyingDialog> createState() => _AiVerifyingDialogState();
}

class _AiVerifyingDialogState extends State<_AiVerifyingDialog> {
  double _progress = 0.08;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 실제 진행률 API가 없으므로 92%까지만 서서히 채우며 대기감을 표현
    _timer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted) return;
      setState(() {
        if (_progress < 0.92) {
          _progress = (_progress + 0.1).clamp(0.0, 0.92);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow,
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WaveLoadingIndicator(
              size: 72,
              progress: _progress,
              backgroundColor: colors.pinkStart.withOpacity(0.08),
              waveColorStart: colors.pinkStart,
              waveColorEnd: colors.pinkStart.withOpacity(0.75),
            ),
            const SizedBox(height: 18),
            Text(
              'AI가 확인하고 있어요',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\'${widget.query}\'가 실제 자격증인지\n잠시만 기다려주세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
