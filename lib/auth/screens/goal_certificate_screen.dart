import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';
import '../widgets/step_indicator.dart';

/// 회원가입 중 "목표 자격증이 있으신가요?" 를 물어보는 화면.
/// 선택된 자격증의 id는 completeSignup 호출 시 users 컬렉션의
/// goalCertificateId 필드로 저장된다.
///
/// TODO: 지금은 하드코딩된 샘플 리스트를 쓰고 있음.
/// 실제 자격증 컬렉션이 정해지면 이 리스트를 Firestore 조회로 교체하면 됨
/// (예: FirebaseFirestore.instance.collection('certifications').get()).
/// 그때도 검색/카테고리 그룹핑 UI 구조는 그대로 재사용 가능.
class GoalCertificate {
  final String id;
  final String name;
  final String category;
  final IconData icon;

  const GoalCertificate({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
  });
}

const List<GoalCertificate> _sampleCertificates = [
  GoalCertificate(
    id: 'info_processing_engineer',
    name: '정보처리기사',
    category: 'IT · 소프트웨어',
    icon: Icons.memory_rounded,
  ),
  GoalCertificate(
    id: 'sqld',
    name: 'SQLD',
    category: 'IT · 데이터베이스',
    icon: Icons.storage_rounded,
  ),
  GoalCertificate(
    id: 'adsp',
    name: 'ADsP',
    category: 'IT · 데이터분석',
    icon: Icons.bar_chart_rounded,
  ),
  GoalCertificate(
    id: 'network_engineer',
    name: '네트워크관리사',
    category: 'IT · 네트워크',
    icon: Icons.hub_rounded,
  ),
  GoalCertificate(
    id: 'linux_master',
    name: '리눅스마스터',
    category: 'IT · 시스템',
    icon: Icons.terminal_rounded,
  ),
  GoalCertificate(
    id: 'toeic',
    name: 'TOEIC',
    category: '어학',
    icon: Icons.language_rounded,
  ),
  GoalCertificate(
    id: 'toeic_speaking',
    name: 'TOEIC Speaking',
    category: '어학',
    icon: Icons.record_voice_over_rounded,
  ),
  GoalCertificate(
    id: 'opic',
    name: 'OPIc',
    category: '어학',
    icon: Icons.chat_bubble_rounded,
  ),
];

// 리스트에 섞어 렌더링하기 위한 항목 타입 (카테고리 헤더 vs 자격증 카드)
class _ListEntry {
  final String? header;
  final GoalCertificate? cert;
  const _ListEntry.header(this.header) : cert = null;
  const _ListEntry.cert(this.cert) : header = null;
}

class GoalCertificateScreen extends StatefulWidget {
  /// 사용자가 선택(또는 건너뛰기)을 마쳤을 때 호출됨.
  /// context는 이 화면 자신의 BuildContext (호출부에서 다음 화면으로 push할 때 사용).
  /// goalCertificateId는 선택하지 않았다면 null.
  final void Function(BuildContext context, String? goalCertificateId) onNext;

  const GoalCertificateScreen({super.key, required this.onNext});

  @override
  State<GoalCertificateScreen> createState() => _GoalCertificateScreenState();
}

class _GoalCertificateScreenState extends State<GoalCertificateScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedId;
  final _searchController = TextEditingController();
  String _query = '';

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _entryController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _select(String id) {
    setState(() {
      _selectedId = (_selectedId == id) ? null : id;
    });
  }

  List<GoalCertificate> get _filtered {
    if (_query.isEmpty) return _sampleCertificates;
    final q = _query.toLowerCase();
    return _sampleCertificates
        .where((c) =>
    c.name.toLowerCase().contains(q) ||
        c.category.toLowerCase().contains(q))
        .toList();
  }

  List<_ListEntry> get _entries {
    final result = <_ListEntry>[];
    String? lastCategory;
    for (final cert in _filtered) {
      if (cert.category != lastCategory) {
        result.add(_ListEntry.header(cert.category));
        lastCategory = cert.category;
      }
      result.add(_ListEntry.cert(cert));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final entries = _entries;

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
                        SizedBox(height: 20),
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
                        SizedBox(height: 8),
                        Text(
                          '선택해주시면 맞춤 학습 캘린더를 준비해드려요.\n나중에 언제든 바꿀 수 있어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.6,
                            color: colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 20),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: '자격증 이름으로 검색해보세요',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: colors.textSecondary.withOpacity(0.7),
                            ),
                            filled: true,
                            fillColor: colors.background,
                            prefixIcon: Icon(Icons.search_rounded,
                                color: colors.textSecondary, size: 20),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                              icon: Icon(Icons.close,
                                  color: colors.textSecondary, size: 18),
                              onPressed: () => _searchController.clear(),
                            ),
                            contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
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
                              borderSide: BorderSide(color: colors.pinkStart, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: entries.isEmpty
                        ? _EmptySearchState(colors: colors, query: _query)
                        : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        if (entry.header != null) {
                          return Padding(
                            padding: EdgeInsets.only(
                                top: index == 0 ? 4 : 18, bottom: 8),
                            child: Text(
                              entry.header!,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: colors.textSecondary,
                              ),
                            ),
                          );
                        }
                        final cert = entry.cert!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CertificateCard(
                            cert: cert,
                            isSelected: _selectedId == cert.id,
                            colors: colors,
                            onTap: () => _select(cert.id),
                          ),
                        );
                      },
                    ),
                  ),
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
}

class _EmptySearchState extends StatelessWidget {
  final AppColors colors;
  final String query;

  const _EmptySearchState({required this.colors, required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 40, color: colors.textSecondary.withOpacity(0.4)),
            SizedBox(height: 12),
            Text(
              '\'$query\'에 대한 검색 결과가 없어요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  final GoalCertificate cert;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onTap;

  const _CertificateCard({
    required this.cert,
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
          color: isSelected ? colors.pinkStart.withOpacity(0.10) : colors.background,
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
                cert.icon,
                size: 22,
                color: isSelected ? Colors.white : colors.pinkStart,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cert.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    cert.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
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
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}