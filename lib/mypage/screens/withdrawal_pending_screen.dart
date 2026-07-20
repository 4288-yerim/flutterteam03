import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  String? _errorMessage;
  String? _withdrawalScheduledText;

  @override
  void initState() {
    super.initState();
    _loadWithdrawalInformation();
  }

  Future<void> _loadWithdrawalInformation() async {
    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage =
        '로그인 정보를 확인할 수 없습니다.';
      });

      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>>
      userDocument =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final Map<String, dynamic>? userData =
      userDocument.data();

      if (userData == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
          '사용자 정보를 찾을 수 없습니다.';
        });

        return;
      }

      final String? status =
      userData['status'] as String?;

      if (status != 'WITHDRAWAL_PENDING') {
        setState(() {
          _isLoading = false;
          _errorMessage =
          '현재 탈퇴 대기 상태가 아닙니다.';
        });

        return;
      }

      final Timestamp? scheduledTimestamp =
      userData['withdrawalScheduledAt']
      as Timestamp?;

      String scheduledText = '확인할 수 없음';

      if (scheduledTimestamp != null) {
        final DateTime scheduledDate =
        scheduledTimestamp.toDate();

        scheduledText =
        '${scheduledDate.year}년 '
            '${scheduledDate.month}월 '
            '${scheduledDate.day}일 '
            '${_formatTime(scheduledDate)}';
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _withdrawalScheduledText =
            scheduledText;
        _isLoading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            error.message ??
                '탈퇴 정보를 불러오지 못했습니다.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
        '오류가 발생했습니다.\n$error';
      });
    }
  }

  String _formatTime(DateTime dateTime) {
    final int hour = dateTime.hour;
    final String minute =
    dateTime.minute.toString().padLeft(2, '0');

    if (hour == 0) {
      return '오전 12시 $minute분';
    }

    if (hour < 12) {
      return '오전 $hour시 $minute분';
    }

    if (hour == 12) {
      return '오후 12시 $minute분';
    }

    return '오후 ${hour - 12}시 $minute분';
  }

  Future<void> _showRecoveryDialog() async {
    if (_isRecovering) {
      return;
    }

    final bool? result =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '계정을 복구하시겠습니까?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            '계정을 복구하면 탈퇴 신청이 취소되고 '
                '기존 계정을 계속 사용할 수 있습니다.',
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
                '계정 복구',
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

    if (result != true) {
      return;
    }

    await _recoverAccount();
  }

  Future<void> _recoverAccount() async {
    if (_isRecovering) {
      return;
    }

    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '로그인 정보를 확인할 수 없습니다.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isRecovering = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'status': 'ACTIVE',
        'withdrawalRequestedAt':
        FieldValue.delete(),
        'withdrawalScheduledAt':
        FieldValue.delete(),
        'withdrawalReasonCode':
        FieldValue.delete(),
        'withdrawalReason':
        FieldValue.delete(),
        'withdrawalReasonDetail':
        FieldValue.delete(),
        'updatedAt':
        FieldValue.serverTimestamp(),
      });

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
              '계정 복구 완료',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              '탈퇴 신청이 취소되었습니다.\n'
                  '이제 기존 계정을 계속 사용할 수 있습니다.',
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

      Navigator.pop(context, true);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '계정 복구에 실패했습니다.\n'
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
          _isRecovering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppTopBar(
        title: '탈퇴 대기 안내',
      ),
      body: AppMainBackground(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 54,
                color: Color(0xFFE85D6A),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF666A73),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });

                  _loadWithdrawalInformation();
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        30,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEE),
                    borderRadius:
                    BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 38,
                    color: Color(0xFFE85D6A),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '현재 탈퇴 대기 상태입니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '탈퇴 신청 후 7일 동안은\n'
                      '계정을 다시 복구할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF666A73),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '최종 탈퇴 예정일',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666A73),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _withdrawalScheduledText ??
                      '확인할 수 없음',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE85D6A),
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 14),
                const Text(
                  '예정일이 지나면 계정과 개인 데이터가 '
                      '최종 처리될 수 있습니다.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color: Color(0xFF666A73),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isRecovering
                  ? null
                  : _showRecoveryDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xFFF0788F),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                const Color(0xFFE4E5E9),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(14),
                ),
              ),
              child: _isRecovering
                  ? const SizedBox(
                width: 22,
                height: 22,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
                  : const Text(
                '계정 복구',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}