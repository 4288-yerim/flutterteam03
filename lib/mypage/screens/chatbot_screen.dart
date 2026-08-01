import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../certificate/screens/certificate_schedule.dart';
import '../../mypage/screens/study_plan_screen.dart';
import '../../notification/screens/notification.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../models/inquiry_models.dart';
import '../services/help_service.dart';
import '../utils/relative_time.dart';
import '../widgets/write_inquiry_dialog.dart';
import 'chat_history_screen.dart';

class _QuickOption {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  _QuickOption({required this.label, required this.icon, required this.onTap});
}

class _ChatMessage {
  final String text;
  final bool isBot;
  final bool isTyping;
  final DateTime createdAt;
  final String? quickLinkLabel;
  final String? quickLinkRoute;
  List<_QuickOption>? options;

  _ChatMessage({
    required this.text,
    required this.isBot,
    required this.createdAt,
    this.isTyping = false,
    this.quickLinkLabel,
    this.quickLinkRoute,
    this.options,
  });
}

class ChatbotScreen extends StatefulWidget {
  final List<FaqItem> faqItems;
  final String? sessionId;

  const ChatbotScreen({super.key, this.faqItems = const [], this.sessionId});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  static final Map<String, WidgetBuilder> _quickLinkRoutes = {
    'certificate_schedule': (_) => const CertificateSchedulePage(),
    'study_plan': (_) => const StudyPlanScreen(),
    'notification': (_) => const NotificationPage(),
  };

  final HelpService _helpService = HelpService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  String? _sessionId;
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;

    if (_sessionId != null) {
      _isLoadingHistory = true;
      _loadExistingSession();
    } else {
      _messages.add(
        _ChatMessage(
          text: '안녕하세요! 무엇을 도와드릴까요? 😊\n아래에서 궁금한 항목을 선택하거나 직접 입력해주세요.',
          isBot: true,
          createdAt: DateTime.now(),
          options: _buildRootOptions(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingSession() async {
    try {
      final records = await _helpService.fetchChatMessages(_sessionId!);
      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(
            records.map(
              (r) => _ChatMessage(
                text: r.text,
                isBot: r.isBot,
                createdAt: r.createdAt ?? DateTime.now(),
                quickLinkLabel: r.quickLinkLabel,
                quickLinkRoute: r.quickLinkRoute,
              ),
            ),
          );

        if (_messages.isNotEmpty && _messages.last.isBot) {
          _messages.last.options = _buildRootOptions();
        }

        _isLoadingHistory = false;
      });

      // 지금 보고 있으니 읽음 처리
      unawaited(_helpService.markSessionRead(_sessionId!));
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: '대화 기록을 불러오지 못했어요.',
            isBot: true,
            createdAt: DateTime.now(),
          ),
        );
        _isLoadingHistory = false;
      });
    }
  }

  List<_QuickOption> _buildRootOptions() {
    final options = widget.faqItems
        .map(
          (faq) => _QuickOption(
            label: faq.question,
            icon: Icons.help_outline_rounded,
            onTap: () => _onFaqSelected(faq),
          ),
        )
        .toList();

    options.add(
      _QuickOption(
        label: '일반 문의 작성하기',
        icon: Icons.edit_note_rounded,
        onTap: _openWriteInquiry,
      ),
    );

    return options;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<String> _ensureSession() async {
    if (_sessionId != null) return _sessionId!;
    final id = await _helpService.createChatSession();
    _sessionId = id;
    return id;
  }

  /// 지금 화면을 보고 있는 상태에서 봇 답변을 받았다면, 곧바로 읽음 처리합니다.
  /// (안 읽은 상태로 남는 건 "답을 보지 못하고 나갔을 때"뿐이어야 하므로)
  void _markCurrentSessionRead() {
    final id = _sessionId;
    if (id != null) {
      unawaited(_helpService.markSessionRead(id));
    }
  }

  Future<void> _onFaqSelected(FaqItem faq) async {
    setState(() {
      for (final m in _messages) {
        m.options = null;
      }
      _messages.add(
        _ChatMessage(
          text: faq.question,
          isBot: false,
          createdAt: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();

    try {
      final sessionId = await _ensureSession();
      unawaited(
        _helpService.addChatMessage(
          sessionId: sessionId,
          text: faq.question,
          isBot: false,
        ),
      );
    } catch (_) {}

    if (mounted) {
      setState(
        () => _messages.add(
          _ChatMessage(
            text: '',
            isBot: true,
            isTyping: true,
            createdAt: DateTime.now(),
          ),
        ),
      );
      _scrollToBottom();
    }

    await Future.delayed(const Duration(milliseconds: 1800));

    if (mounted) {
      setState(() {
        _messages.removeWhere((m) => m.isTyping);
        _messages.add(
          _ChatMessage(
            text: faq.answer,
            isBot: true,
            createdAt: DateTime.now(),
            quickLinkLabel: faq.quickLinkLabel,
            quickLinkRoute: faq.quickLinkRoute,
            options: _buildRootOptions(),
          ),
        );
      });
      _scrollToBottom();
    }

    if (_sessionId != null) {
      await _helpService.addChatMessage(
        sessionId: _sessionId!,
        text: faq.answer,
        isBot: true,
        quickLinkLabel: faq.quickLinkLabel,
        quickLinkRoute: faq.quickLinkRoute,
      );

      if (mounted) {
        _markCurrentSessionRead();
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      for (final m in _messages) {
        m.options = null;
      }
      _messages.add(
        _ChatMessage(text: text, isBot: false, createdAt: DateTime.now()),
      );
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final sessionId = await _ensureSession();
      unawaited(
        _helpService.addChatMessage(
          sessionId: sessionId,
          text: text,
          isBot: false,
        ),
      );
    } catch (_) {}

    if (mounted) {
      setState(
        () => _messages.add(
          _ChatMessage(
            text: '',
            isBot: true,
            isTyping: true,
            createdAt: DateTime.now(),
          ),
        ),
      );
      _scrollToBottom();
    }

    final results = await Future.wait([
      _generateBotReply(text),
      Future.delayed(const Duration(milliseconds: 1800)),
    ]);
    final reply = results[0] as String;

    if (mounted) {
      setState(() {
        _messages.removeWhere((m) => m.isTyping);
        _messages.add(
          _ChatMessage(
            text: reply,
            isBot: true,
            createdAt: DateTime.now(),
            options: _buildRootOptions(),
          ),
        );
      });
      _scrollToBottom();
    }

    if (_sessionId != null) {
      await _helpService.addChatMessage(
        sessionId: _sessionId!,
        text: reply,
        isBot: true,
      );

      if (mounted) {
        _markCurrentSessionRead();
      }
    }
  }

  Future<String> _generateBotReply(String userText) async {
    for (final faq in widget.faqItems) {
      final keywords = faq.question.replaceAll(RegExp(r'[?？]'), '').split(' ');
      final hit = keywords.any((k) => k.length >= 2 && userText.contains(k));
      if (hit) return faq.answer;
    }

    final aiReply = await _helpService.getAiReply(userText);
    if (aiReply != null) return aiReply;

    return '죄송해요, 정확한 답변을 찾지 못했어요.\n'
        '아래 "일반 문의 작성하기" 버튼으로 문의를 남겨주시면\n'
        '담당자가 확인 후 답변드릴게요!';
  }

  Future<void> _openWriteInquiry() async {
    final InquiryDraft? draft = await showWriteInquiryDialog(context);
    if (draft == null || !mounted) return;

    try {
      await _helpService.submitInquiry(
        category: draft.category,
        title: draft.title,
        content: draft.content,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('문의 등록에 실패했어요. 다시 시도해주세요.')));
    }
  }

  void _onQuickLinkTap(String route) {
    final builder = _quickLinkRoutes[route];
    if (builder == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('아직 연결되지 않은 페이지예요.')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: builder));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '문의 챗봇',
        actions: [
          IconButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChatHistoryScreen(faqItems: widget.faqItems),
              ),
            ),
            icon: Icon(
              Icons.history_rounded,
              color: context.colors.iconPrimary,
            ),
          ),
        ],
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _isLoadingHistory
                    ? Center(
                        child: CircularProgressIndicator(
                          color: context.colors.pinkStart,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final showDivider =
                              index == 0 ||
                              !isSameDate(
                                _messages[index - 1].createdAt,
                                msg.createdAt,
                              );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showDivider)
                                _DateDivider(date: msg.createdAt),
                              _ChatBubble(
                                message: msg,
                                onQuickLinkTap: _onQuickLinkTap,
                              ),
                            ],
                          );
                        },
                      ),
              ),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow,
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요',
                filled: true,
                fillColor: context.colors.surfaceMuted,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: context.colors.themedPinkGradient,
              ),
              child: Icon(
                Icons.send_rounded,
                color: context.colors.onPrimary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: context.colors.shadow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            formatDateDivider(date),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 원형 테두리 + 그림자가 있는 봇 프로필 아바타.
class _BotAvatar extends StatelessWidget {
  final double size;
  const _BotAvatar({this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.surface,
        border: Border.all(color: context.colors.pinkBorder, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: context.colors.pinkSoft,
        backgroundImage: const AssetImage('assets/images/cloud_it.png'),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  final void Function(String route) onQuickLinkTap;

  const _ChatBubble({required this.message, required this.onQuickLinkTap});

  @override
  Widget build(BuildContext context) {
    final isBot = message.isBot;
    final hasOptions = message.options != null && message.options!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isBot
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBot) ...[const _BotAvatar(size: 32), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: isBot
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: isBot
                          ? null
                          : context.colors.themedPinkGradient,
                      color: isBot ? context.colors.surface : null,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isBot ? 4 : 16),
                        bottomRight: Radius.circular(isBot ? 16 : 4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.shadow,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    // 옵션 버튼이 있을 때만 폭을 꽉 채우고,
                    // 없으면 텍스트 길이에 맞게 자연스럽게 줄어듭니다.
                    child: Column(
                      crossAxisAlignment: hasOptions
                          ? CrossAxisAlignment.stretch
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.isTyping)
                          const _TypingIndicator()
                        else
                          Text(
                            message.text,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: isBot
                                  ? context.colors.textPrimary
                                  : context.colors.onPrimary,
                            ),
                          ),
                        if (message.quickLinkRoute != null) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _QuickLinkChip(
                              label: message.quickLinkLabel ?? '바로가기',
                              onTap: () =>
                                  onQuickLinkTap(message.quickLinkRoute!),
                            ),
                          ),
                        ],
                        if (hasOptions) ...[
                          const SizedBox(height: 12),
                          Divider(height: 1, color: context.colors.divider),
                          const SizedBox(height: 12),
                          ...message.options!.map(
                            (opt) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _QuickOptionButton(option: opt),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!message.isTyping) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      formatBubbleTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLinkChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickLinkChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.pinkSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.north_east_rounded,
                size: 14,
                color: context.colors.pinkStart,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: context.colors.pinkStart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickOptionButton extends StatelessWidget {
  final _QuickOption option;
  const _QuickOptionButton({required this.option});

  @override
  Widget build(BuildContext context) {
    final isWriteInquiry = option.icon == Icons.edit_note_rounded;

    return Material(
      color: isWriteInquiry
          ? context.colors.pinkStart
          : context.colors.surfaceMuted,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: option.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isWriteInquiry
                ? null
                : Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Icon(
                option.icon,
                size: 17,
                color: isWriteInquiry
                    ? context.colors.onPrimary
                    : context.colors.pinkStart,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isWriteInquiry
                        ? context.colors.onPrimary
                        : context.colors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isWriteInquiry
                    ? context.colors.onPrimary
                    : context.colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 통통 튀는 3점 타이핑 인디케이터. sin 곡선으로 각 점이 위아래로 바운스합니다.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 버블 안에서 위로 올려서 텍스트 기준선과 어색하게 붙지 않게
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: 44,
        height: 22,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(3, (i) {
                final phase = (_controller.value * 2 * math.pi) - (i * 0.6);
                final bounce = math.sin(phase).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Transform.translate(
                    offset: Offset(0, -bounce * 7),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.pinkStart,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
