import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/app_auth_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_overlay.dart';
import '../widgets/step_indicator.dart';

class TermsAgreementScreen extends StatefulWidget {
  final Future<void> Function(
    BuildContext context,
    Map<String, bool> agreements,
  )
  onAgree;

  const TermsAgreementScreen({super.key, required this.onAgree});

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsItem {
  final String key;
  final String title;
  final bool required;
  bool checked;
  final String content;

  _TermsItem({
    required this.key,
    required this.title,
    required this.required,
    this.checked = false,
    required this.content,
  });
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  final List<_TermsItem> _items = [
    _TermsItem(
      key: 'age',
      title: '만 14세 이상입니다',
      required: true,
      content:
          '본 서비스는 만 14세 미만 아동의 개인정보 보호를 위하여, 만 14세 이상인 이용자만 가입 및 이용이 가능합니다.\n\n'
          '가입 절차를 계속 진행하시는 경우, 귀하는 만 14세 이상임을 확인하는 것으로 간주합니다.\n\n'
          '만약 허위로 체크할 경우, 관련 법령에 따라 서비스 이용이 제한되거나 계정이 삭제될 수 있습니다.',
    ),
    _TermsItem(
      key: 'terms',
      title: '이용약관 동의',
      required: true,
      content:
          '[따자 서비스 이용약관]\n\n'
          '제1조 (목적)\n'
          '본 약관은 \'따자\'(이하 "회사")가 제공하는 서비스의 이용과 관련하여 회사와 이용자의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.\n\n'
          '제2조 (용어의 정의)\n'
          '1. "서비스"라 함은 구현되는 단말기와 상관없이 이용자가 이용할 수 있는 따자 관련 제반 서비스를 의미합니다.\n'
          '2. "이용자"라 함은 본 약관에 따라 회사가 제공하는 서비스를 이용하는 회원을 의미합니다.\n\n'
          '제3조 (약관의 효력 및 변경)\n'
          '본 약관은 서비스를 이용하고자 하는 모든 이용자에 대하여 그 효력을 발생합니다. 회사는 합리적인 사유가 있을 경우 관련 법령을 위배하지 않는 범위에서 본 약관을 개정할 수 있습니다.',
    ),
    _TermsItem(
      key: 'privacy',
      title: '개인정보 처리방침 동의',
      required: true,
      content:
          '[개인정보 처리방침]\n\n'
          '회사는 이용자의 개인정보를 중요시하며, \'개인정보 보호법\'을 준수합니다.\n\n'
          '1. 수집하는 개인정보 항목\n'
          '- 필수 항목: 이메일 주소, 비밀번호, 닉네임, 기기 정보\n'
          '- 선택 항목: 프로필 사진, 위치 정보\n\n'
          '2. 개인정보의 수집 및 이용 목적\n'
          '- 회원제 서비스 제공 및 본인 확인\n'
          '- 서비스 이용에 따른 민원 처리 및 공지사항 전달\n\n'
          '3. 개인정보의 보유 및 이용 기간\n'
          '- 회원 탈퇴 시까지 또는 법령에 따른 보관 기간까지 이용자의 개인정보를 보유합니다.',
    ),
    _TermsItem(
      key: 'marketing',
      title: '마케팅 정보 수신 동의',
      required: false,
      content:
          '[마케팅 정보 수신 동의]\n\n'
          '회사는 이용자에게 보다 나은 서비스 경험을 제공하기 위하여, 이벤트 정보, 혜택, 제휴 서비스 등 다양한 마케팅 정보를 제공할 수 있습니다.\n\n'
          '- 수신 동의 항목: 이벤트 소식, 할인 쿠폰, 맞춤형 서비스 제안\n'
          '- 수신 거부: 이용자는 설정 메뉴를 통해 언제든지 마케팅 수신 동의를 철회할 수 있습니다.\n\n'
          '※ 마케팅 정보 수신에 동의하지 않으셔도 필수 서비스는 이용하실 수 있습니다.',
    ),
  ];

  // 순서대로 하나씩 보여주기 위한 "현재까지 보여진 개수"
  int _visibleCount = 1;
  bool _isLoading = false;

  bool get _allChecked => _items.every((e) => e.checked);

  bool get _canProceed =>
      _items.where((e) => e.required).every((e) => e.checked);

  int get _requiredCheckedCount =>
      _items.where((e) => e.required && e.checked).length;

  int get _requiredTotalCount => _items.where((e) => e.required).length;

  void _onItemChanged(int index, bool value) {
    setState(() {
      _items[index].checked = value;
      // 방금 체크한 항목이 현재 마지막으로 보이는 항목이면 다음 항목 공개
      if (value &&
          index == _visibleCount - 1 &&
          _visibleCount < _items.length) {
        _visibleCount++;
      }
    });
  }

  void _toggleAll(bool value) {
    setState(() {
      for (final item in _items) {
        item.checked = value;
      }
      if (value) _visibleCount = _items.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: AppBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StepIndicator(
                      currentStep: 3,
                      label: '3단계 · 약관 동의',
                      colors: Theme.of(context).extension<AppColors>()!,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '서비스 이용을 위해\n약관에 동의해주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '필수 항목 $_requiredCheckedCount / $_requiredTotalCount 동의했어요',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _requiredCheckedCount == _requiredTotalCount
                            ? context.colors.pinkStart
                            : context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _AllAgreeTile(checked: _allChecked, onChanged: _toggleAll),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, color: context.colors.divider),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _visibleCount,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _AnimatedTermsRow(
                            key: ValueKey(index),
                            item: item,
                            onChanged: (value) => _onItemChanged(index, value),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24, top: 8),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          elevatedButtonTheme: ElevatedButtonThemeData(
                            style: ElevatedButton.styleFrom(
                              disabledBackgroundColor:
                                  context.colors.surfaceMuted,
                              disabledForegroundColor:
                                  context.colors.textSecondary,
                            ),
                          ),
                        ),
                        child: AppButton(
                          text: '동의하고 시작하기',
                          type: _canProceed
                              ? AppButtonType.primaryPink
                              : AppButtonType.gray,
                          onPressed: _canProceed
                              ? () async {
                                  setState(() => _isLoading = true);
                                  final agreements = {
                                    for (final item in _items)
                                      item.key: item.checked,
                                  };
                                  await widget.onAgree(context, agreements);
                                  if (!mounted) return;
                                  setState(() => _isLoading = false);
                                }
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isLoading) const LoadingOverlay(),
      ],
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
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: checked ? 1.15 : 1.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Icon(
                checked ? Icons.check_circle : Icons.check_circle_outline,
                color: checked
                    ? context.colors.pinkStart
                    : context.colors.textMuted,
                size: 26,
              ),
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

class _AnimatedTermsRow extends StatefulWidget {
  final _TermsItem item;
  final ValueChanged<bool> onChanged;

  const _AnimatedTermsRow({
    super.key,
    required this.item,
    required this.onChanged,
  });

  @override
  State<_AnimatedTermsRow> createState() => _AnimatedTermsRowState();
}

class _AnimatedTermsRowState extends State<_AnimatedTermsRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: InkWell(
          onTap: () => widget.onChanged(!item.checked),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.7, end: item.checked ? 1.2 : 1.0),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Icon(
                    item.checked
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: item.checked
                        ? context.colors.pinkStart
                        : context.colors.border,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (item.required ? '[필수] ' : '[선택] ') + item.title,
                    style: TextStyle(
                      fontSize: 15,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _TermsDetailScreen(
                          title: item.title,
                          content: item.content,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    '보기',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
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

class _TermsDetailScreen extends StatelessWidget {
  final String title;
  final String content;

  const _TermsDetailScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: context.colors.divider, height: 1),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.shadow,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      content,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.8,
                        letterSpacing: -0.2,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: AppButton(
                  text: '확인',
                  type: AppButtonType.primaryPink,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
