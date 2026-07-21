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

class _AccountWithdrawalScreenState
    extends State<AccountWithdrawalScreen> {
  final TextEditingController _reasonController =
  TextEditingController();

  String? _selectedReason;

  bool _agreeToWithdrawal = false;
  bool _isLoading = false;

  final List<String> _withdrawalReasons = [
    '앱을 자주 사용하지 않아요.',
    '원하는 기능이 부족해요.',
    '앱 사용이 불편해요.',
    '알림이 너무 많아요.',
    '개인정보가 걱정돼요.',
    '다른 서비스를 이용할 예정이에요.',
    '기타',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
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
        _selectedReason != null &&
            _agreeToWithdrawal &&
            !_isLoading;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '회원 탈퇴',
      ),
      body: AppMainBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  20,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    _buildWarningCard(),
                    const SizedBox(height: 22),

                    const Text(
                      '탈퇴 사유',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildReasonCard(),
                    const SizedBox(height: 22),

                    const Text(
                      '탈퇴 확인',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildConfirmCard(),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                8,
                20,
                24,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canWithdraw
                      ? _showFinalWithdrawalDialog
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    const Color(0xFFE85D6A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                    const Color(0xFFE4E5E9),
                    disabledForegroundColor:
                    const Color(0xFFA8ABB3),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                  ),
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
                    '탈퇴 신청',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEE),
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 25,
                  color: Color(0xFFE85D6A),
                ),
              ),
              const SizedBox(width: 13),

              const Expanded(
                child: Text(
                  '탈퇴 전에 확인해주세요.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const _WithdrawalNoticeItem(
            text: '탈퇴 신청 후 7일 동안 계정 복구가 가능합니다.',
          ),
          const SizedBox(height: 12),

          const _WithdrawalNoticeItem(
            text: '7일이 지나면 계정과 개인 데이터가 최종 삭제될 수 있습니다.',
          ),
          const SizedBox(height: 12),

          const _WithdrawalNoticeItem(
            text: '작성한 게시글과 댓글은 서비스 운영 정책에 따라 익명 상태로 남을 수 있습니다.',
          ),
          const SizedBox(height: 12),

          const _WithdrawalNoticeItem(
            text: '탈퇴 대기 중에는 로그인 후 계정 복구 또는 탈퇴 진행을 선택할 수 있습니다.',
          ),
        ],
      ),
    );
  }

  Widget _buildReasonCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedReason,
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              labelText: '탈퇴 사유 선택',
              hintText: '사유를 선택해주세요.',
              filled: true,
              fillColor: const Color(0xFFF8F6F7),
              border: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFF0788F),
                  width: 1.5,
                ),
              ),
            ),
            items: _withdrawalReasons.map(
                  (reason) {
                return DropdownMenuItem<String>(
                  value: reason,
                  child: Text(reason),
                );
              },
            ).toList(),
            onChanged: (value) {
              setState(() {
                _selectedReason = value;
              });
            },
          ),

          const SizedBox(height: 14),

          TextField(
            controller: _reasonController,
            minLines: 3,
            maxLines: 5,
            maxLength: 300,
            onTapOutside: (_) {
              FocusManager.instance.primaryFocus
                  ?.unfocus();
            },
            decoration: InputDecoration(
              labelText: '추가 의견',
              hintText: '불편했던 점이 있다면 알려주세요. (선택)',
              alignLabelWithHint: true,
              filled: true,
              fillColor: const Color(0xFFF8F6F7),
              border: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFF0788F),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            value: _agreeToWithdrawal,
            contentPadding: EdgeInsets.zero,
            controlAffinity:
            ListTileControlAffinity.leading,
            activeColor:
            const Color(0xFFE85D6A),
            title: const Text(
              '탈퇴 신청 후 7일이 지나면 계정과 개인 데이터가 삭제될 수 있음을 확인했습니다.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _agreeToWithdrawal =
                    value ?? false;
              });
            },
          ),

          const SizedBox(height: 14),

          const Text(
            '탈퇴 신청 후 7일 이내에는 계정 복구가 가능합니다.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF9AA0AC),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestAccountWithdrawal() async {
    if (_isLoading) {
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 정보를 확인할 수 없습니다. 다시 로그인해주세요.'),
        ),
      );

      return;
    }

    final String? selectedReason = _selectedReason;

    if (selectedReason == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('탈퇴 사유를 선택해주세요.'),
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final DateTime requestedDateTime = DateTime.now();
      final DateTime scheduledDateTime = requestedDateTime.add(
        const Duration(days: 7),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set(
        {
          'status': 'WITHDRAWAL_PENDING',
          'withdrawalRequestedAt': Timestamp.fromDate(
            requestedDateTime,
          ),
          'withdrawalScheduledAt': Timestamp.fromDate(
            scheduledDateTime,
          ),
          'withdrawalReasonCode': _getWithdrawalReasonCode(
            selectedReason,
          ),
          'withdrawalReason': selectedReason,
          'withdrawalReasonDetail':
          _reasonController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              '탈퇴 신청 완료',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              '탈퇴 신청이 완료되었습니다.\n\n'
                  '신청일로부터 7일 이내에는 계정을 복구할 수 있습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  '확인',
                  style: TextStyle(
                    color: Color(0xFFF0788F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      try {
        await AuthService.signOut();
      } catch (error) {
        await FirebaseAuth.instance.signOut();
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        ),
            (route) => false,
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '탈퇴 신청 저장에 실패했습니다.\n'
                '${error.message ?? error.code}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '오류가 발생했습니다.\n$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showFinalWithdrawalDialog() async {
    if (_isLoading) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '탈퇴를 신청하시겠습니까?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            '탈퇴 신청 후 계정은 7일 동안 탈퇴 대기 상태가 됩니다.\n\n'
                '7일 이내에는 직접 계정을 복구할 수 있습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF9AA0AC),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                '탈퇴 신청',
                style: TextStyle(
                  color: Color(0xFFE85D6A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != true) {
      return;
    }

    await _requestAccountWithdrawal();
  }
}

class _WithdrawalNoticeItem
    extends StatelessWidget {
  final String text;

  const _WithdrawalNoticeItem({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(
            Icons.circle,
            size: 6,
            color: Color(0xFFE85D6A),
          ),
        ),
        const SizedBox(width: 10),

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
