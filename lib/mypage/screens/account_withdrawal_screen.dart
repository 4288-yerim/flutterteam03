import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/screens/welcome_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class AccountWithdrawalScreen extends StatefulWidget {
  const AccountWithdrawalScreen({super.key});

  @override
  State<AccountWithdrawalScreen> createState() =>
      _AccountWithdrawalScreenState();
}

class _AccountWithdrawalScreenState extends State<AccountWithdrawalScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _reasonController = TextEditingController();

  String? _selectedReason;
  bool _agreeToWithdrawal = false;
  bool _isLoading = false;

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  static const Color _primary = Color(0xFFE85D6A);
  static const Color _primaryDark = Color(0xFFD14D5C);
  static const Color _primaryLight = Color(0xFFFFECEE);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _textSub = Color(0xFF666A73);
  static const Color _textFaint = Color(0xFF9AA0AC);
  static const Color _fieldFill = Color(0xFFF8F6F7);

  final List<_ReasonOption> _withdrawalReasons = const [
    _ReasonOption('앱을 자주 사용하지 않아요.', Icons.hourglass_empty_rounded),
    _ReasonOption('원하는 기능이 부족해요.', Icons.widgets_outlined),
    _ReasonOption('앱 사용이 불편해요.', Icons.sentiment_dissatisfied_outlined),
    _ReasonOption('알림이 너무 많아요.', Icons.notifications_off_outlined),
    _ReasonOption('개인정보가 걱정돼요.', Icons.shield_outlined),
    _ReasonOption('다른 서비스를 이용할 예정이에요.', Icons.swap_horiz_rounded),
    _ReasonOption('기타', Icons.more_horiz_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  String _getWithdrawalReasonCode(String reason) {
    switch (reason) {
      case '앱을 자주 사용하지 않아요.':
        return 'NOT_USED_OFTEN';
      case '원하는 기능이 부족해요.':
        return 'LACK_OF_FEATURES';
      case '앱 사용이 불편해요.':
        return 'INCONVENIENT';
      case '알림이 너무 많아요.':
        return 'TOO_MANY_NOTIFICATIONS';
      case '개인정보가 걱정돼요.':
        return 'PRIVACY_CONCERN';
      case '다른 서비스를 이용할 예정이에요.':
        return 'USE_OTHER_SERVICE';
      case '기타':
        return 'OTHER';
      default:
        return 'UNKNOWN';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canWithdraw =
        _selectedReason != null && _agreeToWithdrawal && !_isLoading;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(title: '회원 탈퇴'),
      body: AppMainBackground(
        child: Column(
          children: [
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeroWarning(),
                        const SizedBox(height: 16),
                        _buildProcessStepper(),
                        const SizedBox(height: 22),
                        _buildNoticeCard(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('탈퇴 사유', Icons.edit_note_rounded),
                        const SizedBox(height: 12),
                        _buildReasonCard(),
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                            '탈퇴 확인', Icons.fact_check_outlined),
                        const SizedBox(height: 12),
                        _buildConfirmCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildBottomBar(canWithdraw),
          ],
        ),
      ),
    );
  }

  // ── 하단 고정 버튼 바 ────────────────────────────────────
  Widget _buildBottomBar(bool canWithdraw) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: canWithdraw ? _showFinalWithdrawalDialog : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE4E5E9),
            disabledForegroundColor: _textFaint,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return const Color(0xFFE4E5E9);
              }
              return null;
            }),
          ),
          child: Ink(
            decoration: canWithdraw
                ? BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primary, _primaryDark],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            )
                : null,
            child: Container(
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
                  : const Text(
                '탈퇴 신청하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _textMain,
          ),
        ),
      ],
    );
  }

  // ── 히어로 경고 배너 ────────────────────────────────────
  Widget _buildHeroWarning() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryLight, Color(0xFFFFF6F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFAD9DC)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 28,
              color: _primary,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '탈퇴 전에 꼭 확인해주세요',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _textMain,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '아래 절차와 유의사항을 확인한 뒤 진행해주세요.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: _textSub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 탈퇴 프로세스 스텝퍼 ────────────────────────────────
  Widget _buildProcessStepper() {
    final steps = [
      ('신청', Icons.description_outlined, true),
      ('대기 7일', Icons.hourglass_top_rounded, false),
      ('최종 처리', Icons.check_circle_outline_rounded, false),
    ];

    return AppCard(
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final bool passed = false;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: passed
                    ? _primary
                    : const Color(0xFFE9E7EF),
              ),
            );
          }
          final (label, icon, active) = steps[i ~/ 2];
          return Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: active ? _primary : const Color(0xFFF1EFF2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: active ? Colors.white : _textFaint,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? _primary : _textFaint,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── 유의사항 카드 (아이콘 리스트) ─────────────────────
  Widget _buildNoticeCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _WithdrawalNoticeItem(
            icon: Icons.restore_rounded,
            text: '탈퇴 신청 후 7일 동안 계정 복구가 가능합니다.',
          ),
          SizedBox(height: 14),
          _WithdrawalNoticeItem(
            icon: Icons.delete_outline_rounded,
            text: '7일이 지나면 계정과 개인 데이터가 최종 삭제될 수 있습니다.',
          ),
          SizedBox(height: 14),
          _WithdrawalNoticeItem(
            icon: Icons.visibility_off_outlined,
            text: '작성한 게시글과 댓글은 정책에 따라 익명 상태로 남을 수 있습니다.',
          ),
          SizedBox(height: 14),
          _WithdrawalNoticeItem(
            icon: Icons.login_rounded,
            text: '탈퇴 대기 중에는 로그인 후 복구 또는 탈퇴 진행을 선택할 수 있습니다.',
          ),
        ],
      ),
    );
  }

  Widget _buildReasonCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReasonSelectField(
            selected: _withdrawalReasons.firstWhere(
                  (o) => o.label == _selectedReason,
              orElse: () => const _ReasonOption('', Icons.help_outline),
            ),
            hasSelection: _selectedReason != null,
            onTap: _openReasonPicker,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _reasonController,
            minLines: 3,
            maxLines: 5,
            maxLength: 300,
            onTapOutside: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            style: const TextStyle(fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              labelText: '추가 의견 (선택)',
              hintText: '불편했던 점이 있다면 알려주세요.',
              alignLabelWithHint: true,
              filled: true,
              fillColor: _fieldFill,
              counterStyle: const TextStyle(color: _textFaint, fontSize: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReasonPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ReasonPickerSheet(
          options: _withdrawalReasons,
          selectedLabel: _selectedReason,
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedReason = result;
      });
    }
  }

  Widget _buildConfirmCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AgreementTile(
            value: _agreeToWithdrawal,
            onChanged: (value) {
              setState(() => _agreeToWithdrawal = value);
            },
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline_rounded, size: 15, color: _textFaint),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '탈퇴 신청 후 7일 이내에는 계정 복구가 가능합니다.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: _textFaint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _requestAccountWithdrawal() async {
    if (_isLoading) return;

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보를 확인할 수 없습니다. 다시 로그인해주세요.')),
      );
      return;
    }

    final String? selectedReason = _selectedReason;

    if (selectedReason == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('탈퇴 사유를 선택해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final DateTime requestedDateTime = DateTime.now();
      final DateTime scheduledDateTime =
      requestedDateTime.add(const Duration(days: 7));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set(
        {
          'status': 'WITHDRAWAL_PENDING',
          'withdrawalRequestedAt': Timestamp.fromDate(requestedDateTime),
          'withdrawalScheduledAt': Timestamp.fromDate(scheduledDateTime),
          'withdrawalReasonCode': _getWithdrawalReasonCode(selectedReason),
          'withdrawalReason': selectedReason,
          'withdrawalReasonDetail': _reasonController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      await showAnimatedStyledDialog(
        context: context,
        barrierDismissible: false,
        dialog: _StyledDialog(
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF3D9960),
          iconBackground: const Color(0xFFF0F9F3),
          title: '탈퇴 신청 완료',
          description:
          '탈퇴 신청이 완료되었습니다.\n신청일로부터 7일 이내에는\n계정을 복구할 수 있습니다.',
          primaryText: '확인',
          primaryColor: _primary,
          onPrimary: () => Navigator.pop(context),
        ),
      );

      if (!mounted) return;

      try {
        await AuthService.signOut();
      } catch (error) {
        await FirebaseAuth.instance.signOut();
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '탈퇴 신청 저장에 실패했습니다.\n${error.message ?? error.code}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다.\n$error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showFinalWithdrawalDialog() async {
    if (_isLoading) return;

    FocusManager.instance.primaryFocus?.unfocus();

    final bool? result = await showAnimatedStyledDialog<bool>(
      context: context,
      dialog: _StyledDialog(
        icon: Icons.logout_rounded,
        iconColor: _primary,
        iconBackground: _primaryLight,
        title: '탈퇴를 신청하시겠어요?',
        description:
        '탈퇴 신청 후 계정은 7일 동안\n탈퇴 대기 상태가 돼요.\n7일 이내에는 직접 복구할 수 있어요.',
        primaryText: '탈퇴 신청',
        primaryColor: _primary,
        secondaryText: '취소',
        onPrimary: () => Navigator.pop(context, true),
        onSecondary: () => Navigator.pop(context, false),
      ),
    );

    if (result != true) return;

    await _requestAccountWithdrawal();
  }
}

class _ReasonOption {
  final String label;
  final IconData icon;

  const _ReasonOption(this.label, this.icon);
}

class _ReasonChip extends StatelessWidget {
  final _ReasonOption option;
  final bool selected;
  final VoidCallback onTap;

  static const Color _primary = Color(0xFFE85D6A);
  static const Color _primaryLight = Color(0xFFFFECEE);

  const _ReasonChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14), // 👈 20 -> 14
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _primaryLight : const Color(0xFFF8F6F7),
            borderRadius: BorderRadius.circular(14), // 👈 20 -> 14
            border: Border.all(
              color: selected ? _primary : Colors.transparent,
              width: 1.3,
            ),
          ),
          child: Row(
            children: [
              Icon(
                option.icon,
                size: 16,
                color: selected ? _primary : const Color(0xFF9AA0AC),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? _primary : const Color(0xFF4A4A50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgreementTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  static const Color _primary = Color(0xFFE85D6A);

  const _AgreementTile({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: value ? _primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: value ? _primary : const Color(0xFFC9CBD1),
                    width: 1.6,
                  ),
                ),
                child: value
                    ? const Icon(Icons.check_rounded,
                    size: 15, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '탈퇴 신청 후 7일이 지나면 계정과 개인 데이터가 삭제될 수 있음을 확인했습니다.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WithdrawalNoticeItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _WithdrawalNoticeItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFFFECEE),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFFE85D6A)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.55,
              color: Color(0xFF666A73),
            ),
          ),
        ),
      ],
    );
  }
}

/// ── 공용: 튕기듯 등장하는 스타일 다이얼로그 ─────────────────
/// withdrawal_pending_screen.dart 등 다른 화면에서도 재사용 가능하도록
/// widgets/styled_dialog.dart 로 옮겨서 공용 사용을 추천해요.
Future<T?> showAnimatedStyledDialog<T>({
  required BuildContext context,
  required Widget dialog,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: '',
    barrierColor: Colors.black.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, anim1, anim2) => dialog,
    transitionBuilder: (context, anim, secondaryAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
      );
      return FadeTransition(
        opacity: anim,
        child: Transform.scale(
          scale: 0.85 + (curved.value.clamp(0.0, 1.2) * 0.15),
          child: child,
        ),
      );
    },
  );
}

class _StyledDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;
  final String primaryText;
  final Color primaryColor;
  final String? secondaryText;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;

  const _StyledDialog({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
    required this.primaryText,
    required this.primaryColor,
    required this.onPrimary,
    this.secondaryText,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [iconBackground, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withOpacity(0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(icon, size: 30, color: iconColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: Color(0xFF666A73),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (secondaryText != null) ...[
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: onSecondary,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9AA0AC),
                          side: const BorderSide(color: Color(0xFFE4E5E9)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          secondaryText!,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: onPrimary,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        primaryText,
                        style: const TextStyle(fontWeight: FontWeight.w700),
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

class _ReasonSelectField extends StatelessWidget {
  final _ReasonOption selected;
  final bool hasSelection;
  final VoidCallback onTap;

  static const Color _primary = Color(0xFFE85D6A);
  static const Color _primaryLight = Color(0xFFFFECEE);
  static const Color _fieldFill = Color(0xFFF8F6F7);

  const _ReasonSelectField({
    required this.selected,
    required this.hasSelection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: hasSelection ? _primaryLight : _fieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasSelection ? _primary.withOpacity(0.4) : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasSelection ? selected.icon : Icons.list_alt_rounded,
                size: 20,
                color: hasSelection ? _primary : const Color(0xFF9AA0AC),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasSelection ? selected.label : '탈퇴 사유를 선택해주세요.',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: hasSelection ? FontWeight.w700 : FontWeight.w500,
                    color: hasSelection ? _primary : const Color(0xFF9AA0AC),
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: hasSelection ? _primary : const Color(0xFF9AA0AC),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonPickerSheet extends StatelessWidget {
  final List<_ReasonOption> options;
  final String? selectedLabel;

  static const Color _primary = Color(0xFFE85D6A);
  static const Color _primaryLight = Color(0xFFFFECEE);

  const _ReasonPickerSheet({
    required this.options,
    required this.selectedLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E5E9),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 20),
                child: Text(
                  '탈퇴 사유를 선택해주세요',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final bool selected = option.label == selectedLabel;

                  return Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context, option.label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: selected ? _primaryLight : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFFF3F1F4),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                option.icon,
                                size: 18,
                                color: selected
                                    ? _primary
                                    : const Color(0xFF8B8890),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: selected
                                      ? _primary
                                      : const Color(0xFF2A2A2E),
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle_rounded,
                                  size: 20, color: _primary),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}