import 'package:flutter/material.dart';

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

  final TextEditingController _confirmController =
  TextEditingController();

  String? _selectedReason;

  bool _agreeToWithdrawal = false;

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
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canWithdraw =
        _agreeToWithdrawal &&
            _confirmController.text.trim() == '탈퇴합니다';

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
                  child: const Text(
                    '회원 탈퇴',
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
            text: '탈퇴 후에는 현재 계정으로 로그인할 수 없습니다.',
          ),
          const SizedBox(height: 12),

          const _WithdrawalNoticeItem(
            text: '목표 자격증과 학습 기록 등 개인 데이터가 삭제될 수 있습니다.',
          ),
          const SizedBox(height: 12),

          const _WithdrawalNoticeItem(
            text: '작성한 게시글과 댓글은 서비스 운영 정책에 따라 남을 수 있습니다.',
          ),
          const SizedBox(height: 12),

          const _WithdrawalNoticeItem(
            text: '탈퇴한 계정과 데이터는 복구하지 못할 수 있습니다.',
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
              '회원 탈퇴 시 계정과 일부 데이터가 삭제될 수 있음을 확인했습니다.',
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
            '아래 입력란에 “탈퇴합니다”를 입력해주세요.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF666A73),
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _confirmController,
            onChanged: (_) {
              setState(() {});
            },
            onTapOutside: (_) {
              FocusManager.instance.primaryFocus
                  ?.unfocus();
            },
            decoration: InputDecoration(
              hintText: '탈퇴합니다',
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
                  color: Color(0xFFE85D6A),
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            '실제 계정 삭제 전에는 비밀번호 또는 소셜 로그인 재인증 과정이 추가될 예정입니다.',
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

  Future<void> _showFinalWithdrawalDialog() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '정말 탈퇴하시겠습니까?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            '회원 탈퇴 후에는 계정과 데이터를 복구하지 못할 수 있습니다.',
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
                '탈퇴',
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

    if (!mounted) {
      return;
    }

    // 추후 실제 구현 시:
    // 1. Firebase Auth 사용자 재인증
    // 2. Firestore 사용자 상태 또는 탈퇴 요청 저장
    // 3. 관련 사용자 데이터 처리
    // 4. FirebaseAuth.currentUser?.delete()
    // 5. 로그인 화면으로 이동

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '탈퇴 기능 안내',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            '현재는 화면 확인용 임시 기능입니다.\n'
                '계정 재인증 및 Firebase 탈퇴 정책이 확정된 후 실제 탈퇴 기능이 적용됩니다.',
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