import 'package:flutter/material.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_button.dart';

/// 소셜/이메일 회원가입 직후, 최초 1회 노출되는 약관동의 화면.
///
/// 사용 예:
/// ```dart
/// Navigator.of(context).pushReplacement(
///   MaterialPageRoute(
///     builder: (_) => TermsAgreementScreen(
///       onAgree: () {
///         Navigator.of(context).pushReplacement(
///           MaterialPageRoute(builder: (_) => const HomeScreen()),
///         );
///       },
///     ),
///   ),
/// );
/// ```
class TermsAgreementScreen extends StatefulWidget {
  final VoidCallback onAgree;

  const TermsAgreementScreen({super.key, required this.onAgree});

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsItem {
  final String title;
  final bool required;
  bool checked;
  final String? url; // 상세 약관 링크 (없으면 상세보기 버튼 숨김)

  _TermsItem({
    required this.title,
    required this.required,
    this.checked = false,
    this.url,
  });
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  final List<_TermsItem> _items = [
    _TermsItem(title: '[필수] 만 14세 이상입니다', required: true),
    _TermsItem(title: '[필수] 이용약관 동의', required: true),
    _TermsItem(title: '[필수] 개인정보 처리방침 동의', required: true),
    _TermsItem(title: '[선택] 마케팅 정보 수신 동의', required: false),
  ];

  bool get _allChecked => _items.every((e) => e.checked);

  bool get _canProceed => _items.where((e) => e.required).every((e) => e.checked);

  void _toggleAll(bool value) {
    setState(() {
      for (final item in _items) {
        item.checked = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 16),
                const Text(
                  '서비스 이용을 위해\n약관에 동의해주세요',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.35),
                ),
                const SizedBox(height: 32),

                // 전체 동의
                _AllAgreeTile(
                  checked: _allChecked,
                  onChanged: _toggleAll,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                ),

                // 개별 약관 목록
                Expanded(
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _TermsRow(
                        item: item,
                        onChanged: (value) {
                          setState(() => item.checked = value);
                        },
                        onViewDetail: item.url == null
                            ? null
                            : () {
                          // TODO: 약관 상세 화면 또는 WebView로 item.url 연결
                        },
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 24, top: 8),
                  child: AppButton(
                    text: '동의하고 시작하기',
                    type: AppButtonType.primaryPink,
                    onPressed: _canProceed ? widget.onAgree : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AllAgreeTile extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _AllAgreeTile({required this.checked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              checked ? Icons.check_circle : Icons.check_circle_outline,
              color: checked ? const Color(0xFFFF4D6D) : const Color(0xFFB0B4BB),
              size: 26,
            ),
            const SizedBox(width: 12),
            const Text(
              '약관 전체 동의',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  final _TermsItem item;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onViewDetail;

  const _TermsRow({
    required this.item,
    required this.onChanged,
    this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!item.checked),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              item.checked ? Icons.check : Icons.check,
              size: 20,
              color: item.checked ? const Color(0xFFFF4D6D) : const Color(0xFFD1D5DB),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
              ),
            ),
            if (onViewDetail != null)
              GestureDetector(
                onTap: onViewDetail,
                child: const Text(
                  '보기',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9AA0AC),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}