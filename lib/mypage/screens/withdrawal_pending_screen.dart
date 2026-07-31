import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/screens/welcome_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../main_page.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class WithdrawalPendingScreen extends StatefulWidget {
  const WithdrawalPendingScreen({super.key});

  @override
  State<WithdrawalPendingScreen> createState() =>
      _WithdrawalPendingScreenState();
}

class _WithdrawalPendingScreenState
    extends State<WithdrawalPendingScreen> {
  bool _isLoading = true;
  bool _isRecovering = false;
  bool _canRecover = false;

  String? _errorMessage;
  String? _withdrawalScheduledText;
  int? _daysRemaining;

  static const Color _primary = Color(0xFFE85D6A);
  static const Color _primaryLight = Color(0xFFFFECEE);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _textSub = Color(0xFF666A73);
  static const Color _textFaint = Color(0xFF9AA0AC);

  @override
  void initState() {
    super.initState();
    _loadWithdrawalInformation();
  }

  Future<void> _loadWithdrawalInformation() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '로그인 정보를 확인할 수 없습니다.';
      });
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> userDocument =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final Map<String, dynamic>? userData = userDocument.data();

      if (userData == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '사용자 정보를 찾을 수 없습니다.';
        });
        return;
      }

      final String? status = userData['status'] as String?;

      if (status != 'WITHDRAWAL_PENDING') {
        setState(() {
          _isLoading = false;
          _errorMessage = '현재 탈퇴 대기 상태가 아닙니다.';
        });
        return;
      }

      final Timestamp? scheduledTimestamp =
      userData['withdrawalScheduledAt'] as Timestamp?;

      String scheduledText = '확인할 수 없음';
      int? daysRemaining;

      if (scheduledTimestamp != null) {
        final DateTime scheduledDate = scheduledTimestamp.toDate();
        scheduledText =
        '${scheduledDate.year}년 ${scheduledDate.month}월 ${scheduledDate.day}일 '
            '${_formatTime(scheduledDate)}';

        final diff = scheduledDate.difference(DateTime.now());
        daysRemaining = diff.inHours > 0
            ? (diff.inHours / 24).ceil()
            : 0;
      }

      if (!mounted) return;

      setState(() {
        _withdrawalScheduledText = scheduledText;
        _daysRemaining = daysRemaining;
        _canRecover = scheduledTimestamp != null &&
            DateTime.now().isBefore(scheduledTimestamp.toDate());
        _isLoading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message ?? '탈퇴 정보를 불러오지 못했습니다.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '오류가 발생했습니다.\n$error';
      });
    }
  }

  String _formatTime(DateTime dateTime) {
    final int hour = dateTime.hour;
    final String minute = dateTime.minute.toString().padLeft(2, '0');

    if (hour == 0) return '오전 12시 $minute분';
    if (hour < 12) return '오전 $hour시 $minute분';
    if (hour == 12) return '오후 12시 $minute분';
    return '오후 ${hour - 12}시 $minute분';
  }

  // ── 계정 복구 확인 다이얼로그 ─────────────────────────────
  Future<void> _showRecoveryDialog() async {
    if (_isRecovering || !_canRecover) return;

    final bool? result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) {
        return _StyledDialog(
          icon: Icons.refresh_rounded,
          iconColor: _primary,
          iconBackground: _primaryLight,
          title: '계정을 복구하시겠어요?',
          description: '복구하면 탈퇴 신청이 취소되고\n기존 계정을 계속 사용할 수 있어요.',
          primaryText: '계정 복구',
          primaryColor: _primary,
          secondaryText: '취소',
          onPrimary: () => Navigator.pop(dialogContext, true),
          onSecondary: () => Navigator.pop(dialogContext, false),
        );
      },
    );

    if (result != true) return;
    await _recoverAccount();
  }

  Future<void> _recoverAccount() async {
    if (_isRecovering) return;

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보를 확인할 수 없습니다.')),
      );
      return;
    }

    setState(() => _isRecovering = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'status': 'ACTIVE',
        'withdrawalRequestedAt': FieldValue.delete(),
        'withdrawalScheduledAt': FieldValue.delete(),
        'withdrawalReasonCode': FieldValue.delete(),
        'withdrawalReason': FieldValue.delete(),
        'withdrawalReasonDetail': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.45),
        builder: (dialogContext) {
          return _StyledDialog(
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF3D9960),
            iconBackground: const Color(0xFFF0F9F3),
            title: '계정 복구 완료',
            description: '탈퇴 신청이 취소되었습니다.\n이제 기존 계정을 계속 사용할 수 있어요.',
            primaryText: '확인',
            primaryColor: _primary,
            onPrimary: () => Navigator.pop(dialogContext),
          );
        },
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainPage()),
            (route) => false,
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('계정 복구에 실패했습니다.\n${error.message ?? error.code}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다.\n$error')),
      );
    } finally {
      if (mounted) setState(() => _isRecovering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppTopBar(title: '탈퇴 대기 안내'),
      body: AppMainBackground(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    size: 36, color: _primary),
              ),
              const SizedBox(height: 18),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: _textSub,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _loadWithdrawalInformation();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '다시 시도',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryLight, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 36,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '현재 탈퇴 대기 상태입니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: _textMain,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '탈퇴 신청 후 7일 이내에는\n계정을 다시 복구할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: _textSub,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '최종 탈퇴 예정일',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textSub,
                      ),
                    ),
                    if (_daysRemaining != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _canRecover
                              ? _primaryLight
                              : const Color(0xFFF1F1F3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _canRecover ? 'D-$_daysRemaining' : '만료',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _canRecover ? _primary : _textFaint,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _withdrawalScheduledText ?? '확인할 수 없음',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: _textFaint),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '예정일이 지나면 계정과 개인 데이터가 최종 처리될 수 있습니다.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: _textSub,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isRecovering
                  ? null
                  : _canRecover
                  ? _showRecoveryDialog
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE4E5E9),
                disabledForegroundColor: _textFaint,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isRecovering
                  ? const SizedBox.shrink()
                  : Icon(
                _canRecover
                    ? Icons.refresh_rounded
                    : Icons.block_rounded,
                size: 20,
              ),
              label: _isRecovering
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
                  : Text(
                _canRecover ? '계정 복구' : '복구 기간 만료',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isRecovering ? null : _signOut,
            child: const Text(
              '로그인 화면으로 돌아가기',
              style: TextStyle(
                color: _textFaint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
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
  }
}

/// 공통 스타일 다이얼로그 (아이콘 헤더 + 필박 버튼)
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
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
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
                color: iconBackground,
                shape: BoxShape.circle,
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