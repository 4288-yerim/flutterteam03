import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:portone_flutter/iamport_payment.dart';
import 'package:portone_flutter/model/payment_data.dart';
import '../widgets/app_button.dart';
import 'services/subscription_service.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'study_plan.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  static const Color textColor = Color(0xFF2E2635);
  static const Color subTextColor = Color(0xFF847E88);
  static const Color pinkColor = Color(0xFFFF6F9C);
  static const Color violetColor = Color(0xFF8A6FF0);
  static const Color skyColor = Color(0xFF4FB6E8);
  static const Color mintColor = Color(0xFF2FC6A6);
  static const Color sunColor = Color(0xFFFFB648);

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage>
    with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _badgeController;

  final SubscriptionService _subscriptionService = SubscriptionService.instance;
  bool _isPurchasing = false;
  bool _hasNavigatedToStudyPlan = false;

  @override
  void initState() {
    super.initState();

    _subscriptionService.onStateChanged = _onPurchaseStateChanged;
    _subscriptionService.init();

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _enterController.dispose();
    _badgeController.dispose();
    _subscriptionService.onStateChanged = null;
    _subscriptionService.dispose();
    super.dispose();
  }

  void _onPurchaseStateChanged(SubscriptionPurchaseState state, {
    String? message,
  }) {
    if (!mounted) return;

    setState(() {
      _isPurchasing = state == SubscriptionPurchaseState.loading;
    });

    switch (state) {
      case SubscriptionPurchaseState.success:
        _showSuccessSheet();
        break;
      case SubscriptionPurchaseState.cancelled:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('결제가 취소되었어요.')),
        );
        break;
      case SubscriptionPurchaseState.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? '결제 중 문제가 발생했어요. 다시 시도해주세요.')),
        );
        break;
      case SubscriptionPurchaseState.loading:
      case SubscriptionPurchaseState.idle:
        break;
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/subscribe_success.png',
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 16,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00FFFFFF),
                              Color(0xFFFFFFFF),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '구독이 시작됐어요!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: SubscriptionPage.textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '첫 달 1,000원 결제가 완료되었어요.\n지금부터 구름iT의 모든 혜택을 이용할 수 있어요.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: SubscriptionPage.subTextColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7FB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _SuccessSheetRow(label: '결제 금액', value: '1,000원'),
                            const SizedBox(height: 10),
                            _SuccessSheetRow(label: '다음 결제 금액', value: '2,900원 / 월'),
                            const SizedBox(height: 10),
                            _SuccessSheetRow(label: '요금제', value: '월간 구독'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [SubscriptionPage.pinkColor, SubscriptionPage.violetColor],
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const AiStudyPlanPage(),
                                  ),
                                );
                              },
                              child: const Center(
                                child: Text(
                                  '확인',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Animation<double> _fadeFor(int index, {int total = 7}) {
    final start = (index / total) * 0.6;
    final end = start + 0.4;
    return CurvedAnimation(
      parent: _enterController,
      curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
    );
  }

  Widget _staggered({required int index, required Widget child}) {
    final fade = _fadeFor(index);
    return AnimatedBuilder(
      animation: fade,
      builder: (context, _) {
        return Opacity(
          opacity: fade.value,
          child: Transform.translate(
            offset: Offset(0, (1 - fade.value) * 24),
            child: child,
          ),
        );
      },
    );
  }

  void _onSubscribePressed() {
    if (_isPurchasing) return;

    final merchantUid = 'sub_${DateTime.now().millisecondsSinceEpoch}';
    final customerUid = FirebaseAuth.instance.currentUser!.uid;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IamportPayment(
          appBar: AppBar(title: const Text('결제')),
          initialChild: const Center(child: CircularProgressIndicator()),
          userCode: kImpUserCode,
          data: PaymentData(
            pg: 'html5_inicis.INIBillTst',
            payMethod: 'card',
            name: kMerchantOrderName,
            merchantUid: merchantUid,
            amount: 0,
            customerUid: customerUid,
            buyerTel: '01000000000',
            buyerName: '',
            buyerEmail: '',
            appScheme: 'DdajaiT',
          ),
          callback: (Map<String, String> result) async {
            print('빌링키 등록 콜백 결과: $result');
            Navigator.of(context).pop();

            if (result['success'] == 'true') {
              await _subscriptionService.verifyAndActivate(
                customerUid: customerUid,
              );
            } else {
              _subscriptionService.onPaymentCancelled();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: const AppTopBar(
        title: '구름iT 구독',
        centerTitle: false,
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: uid == null
              ? const Center(child: Text('로그인이 필요합니다.'))
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _subscriptionService.subscriptionStream(uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '구독 정보를 불러오지 못했어요.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data?.data();
              final isActive = data != null && data['status'] == 'ACTIVE';

              if (isActive) {
                if (!_hasNavigatedToStudyPlan) {
                  _hasNavigatedToStudyPlan = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const AiStudyPlanPage(),
                      ),
                    );
                  });
                }
                return const Center(child: CircularProgressIndicator());
              }

              return _buildPurchaseView();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _onCancelPressed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('구독 해지'),
        content: const Text(
            '구독을 해지하면 다음 결제일부터 자동 결제가 중단돼요.\n남은 기간까지는 계속 이용할 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('해지하기'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isPurchasing = true);
    final success = await _subscriptionService.cancelSubscription();
    if (!mounted) return;
    setState(() => _isPurchasing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '구독이 해지되었어요.' : '해지 처리 중 오류가 발생했어요.')),
    );
  }

  Widget _buildPurchaseView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _staggered(index: 0, child: const _SubscriptionHeader()),
          const SizedBox(height: 28),
          _staggered(
            index: 1,
            child: const Text(
              '구독 혜택',
              style: TextStyle(
                color: SubscriptionPage.textColor,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _staggered(
            index: 2,
            child: const _BenefitCard(
              icon: Icons.calendar_month_rounded,
              accentColor: SubscriptionPage.violetColor,
              gradientColors: [Color(0xFFF1ECFF), Color(0xFFFFFFFF)],
              title: '맞춤형 AI 학습 플랜',
              description: '자격증 시험 일정에 맞춰 구름iT이 학습 플랜을 생성해요.',
            ),
          ),
          const SizedBox(height: 12),
          _staggered(
            index: 3,
            child: const _BenefitCard(
              icon: Icons.insights_rounded,
              accentColor: SubscriptionPage.skyColor,
              gradientColors: [Color(0xFFE7F6FF), Color(0xFFFFFFFF)],
              title: '합격 가능성 예측',
              description: '사용자의 학습량을 분석해 현재 합격 가능성을 예측해요.',
            ),
          ),
          const SizedBox(height: 12),
          _staggered(
            index: 4,
            child: const _BenefitCard(
              icon: Icons.auto_fix_high_rounded,
              accentColor: SubscriptionPage.mintColor,
              gradientColors: [Color(0xFFE3FBF4), Color(0xFFFFFFFF)],
              title: '학습 플랜 자동 조정',
              description: '학습량이 부족하면 남은 일정에 맞게 학습 플랜을 조정해요.',
            ),
          ),
          const SizedBox(height: 28),
          _staggered(
            index: 5,
            child: _PriceCard(badgeController: _badgeController),
          ),
          const SizedBox(height: 18),
          _staggered(
            index: 6,
            child: _isPurchasing
                ? const SizedBox(
              width: double.infinity,
              height: 56,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: SubscriptionPage.pinkColor,
                  ),
                ),
              ),
            )
                : AppButton(
              text: '첫 달 1,000원으로 시작하기',
              type: AppButtonType.primaryPink,
              onPressed: _onSubscribePressed,
            ),
          ),
          const SizedBox(height: 16),
          const _NoticeCard(),
        ],
      ),
    );
  }
}

class _SubscriptionHeader extends StatelessWidget {
  const _SubscriptionHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE4ED),
            Color(0xFFF6D7FF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/cloud_it.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            Text(
              '구름iT과 함께\n합격까지 계획적으로 공부해요',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SubscriptionPage.textColor.withValues(alpha: 0.85),
                fontSize: 23,
                height: 1.35,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '시험 일정과 학습 기록을 분석해\n나에게 맞는 학습 계획을 제공해요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SubscriptionPage.subTextColor,
                fontSize: 15,
                height: 1.55,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final List<Color> gradientColors;
  final String title;
  final String description;

  const _BenefitCard({
    required this.icon,
    required this.accentColor,
    required this.gradientColors,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.14),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accentColor, accentColor.withValues(alpha: 0.7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 27),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: SubscriptionPage.textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  style: const TextStyle(
                    color: SubscriptionPage.subTextColor,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final AnimationController badgeController;

  const _PriceCard({required this.badgeController});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SubscriptionPage.violetColor,
            SubscriptionPage.pinkColor,
            SubscriptionPage.sunColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: SubscriptionPage.pinkColor.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  '월간 구독',
                  style: TextStyle(
                    color: SubscriptionPage.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: badgeController,
                  builder: (context, child) {
                    final shimmer =
                    (0.5 + 0.5 * (badgeController.value * 2 - 1).abs())
                        .clamp(0.6, 1.0);
                    return Opacity(opacity: shimmer, child: child);
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          SubscriptionPage.sunColor,
                          SubscriptionPage.pinkColor,
                        ],
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(30)),
                      boxShadow: [
                        BoxShadow(
                          color: SubscriptionPage.sunColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 3),
                          Text(
                            '65% 첫 달 할인',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  '첫 달',
                  style: TextStyle(
                    color: SubscriptionPage.subTextColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '2,900원',
                  style: TextStyle(
                    color: Color(0xFFC5BFC1),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Color(0xFFC5BFC1),
                    decorationThickness: 2,
                  ),
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      SubscriptionPage.violetColor.withValues(alpha: 0.75),
                      SubscriptionPage.pinkColor.withValues(alpha: 0.75),
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    '1,000원',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '1,900원 절약 · 오늘만 이 가격',
                style: TextStyle(
                  color: SubscriptionPage.mintColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _DashedDivider(),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  '다음 달부터',
                  style: TextStyle(
                    color: SubscriptionPage.subTextColor,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                const Text(
                  '월 2,900원',
                  style: TextStyle(
                    color: SubscriptionPage.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashGap = 5.0;
        final dashCount =
        (constraints.maxWidth / (dashWidth + dashGap)).floor();
        return Row(
          children: List.generate(dashCount, (index) {
            return Padding(
              padding: const EdgeInsets.only(right: dashGap),
              child: Container(
                width: dashWidth,
                height: 1.5,
                color: const Color(0xFFEFE3E8),
              ),
            );
          }),
        );
      },
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SubscriptionPage.violetColor.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoticeRow(
            icon: Icons.credit_card_rounded,
            text: '카드 등록 화면에는 0원으로 표시되며, 등록 직후 첫 달 1,000원이 자동 결제돼요.',
          ),
          const SizedBox(height: 10),
          _NoticeRow(
            icon: Icons.autorenew_rounded,
            text: '첫 달 이후에는 매월 2,900원이 결제되며, 언제든 해지가 가능해요.',
          ),
          const SizedBox(height: 10),
          _NoticeRow(
            icon: Icons.insights_outlined,
            text: '합격 가능성 예측 결과는 학습 참고용이며, 실제 시험 결과를 보장하지 않아요.',
          ),
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _NoticeRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: SubscriptionPage.violetColor.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: SubscriptionPage.subTextColor,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveSubscriptionView extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onCancel;
  final bool isLoading;

  const _ActiveSubscriptionView({
    required this.data,
    required this.onCancel,
    required this.isLoading,
  });

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final expiresAtRaw = data['expiresAt'];
    final expiresAt = expiresAtRaw is Timestamp ? expiresAtRaw : null;
    final amountRaw = data['amount'];
    final amount = amountRaw is int ? amountRaw : (amountRaw as num?)?.toInt() ?? 2900;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [SubscriptionPage.violetColor, SubscriptionPage.pinkColor],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      '구독 중',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '다음 결제일: ${_formatDate(expiresAt)}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '결제 금액: ${amount.toString()}원 / 월',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _BenefitCard(
            icon: Icons.calendar_month_rounded,
            accentColor: SubscriptionPage.violetColor,
            gradientColors: [Color(0xFFF1ECFF), Color(0xFFFFFFFF)],
            title: '맞춤형 AI 학습 플랜',
            description: '자격증 시험 일정에 맞춰 구름iT이 학습 플랜을 생성해요.',
          ),
          const SizedBox(height: 12),
          const _BenefitCard(
            icon: Icons.insights_rounded,
            accentColor: SubscriptionPage.skyColor,
            gradientColors: [Color(0xFFE7F6FF), Color(0xFFFFFFFF)],
            title: '합격 가능성 예측',
            description: '사용자의 학습량을 분석해 현재 합격 가능성을 예측해요.',
          ),
          const SizedBox(height: 32),
          Center(
            child: TextButton(
              onPressed: onCancel,
              child: isLoading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text(
                '구독 해지하기',
                style: TextStyle(
                  color: SubscriptionPage.subTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessSheetRow extends StatelessWidget {
  final String label;
  final String value;

  const _SuccessSheetRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: SubscriptionPage.subTextColor,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: SubscriptionPage.textColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}