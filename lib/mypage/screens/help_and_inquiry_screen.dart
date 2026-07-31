import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../models/inquiry_models.dart';
import '../services/help_service.dart';
import 'chat_history_screen.dart';
import 'chatbot_screen.dart';

enum _InquiryFilter { all, waiting, completed }

class HelpAndInquiryScreen extends StatefulWidget {
  const HelpAndInquiryScreen({super.key});

  @override
  State<HelpAndInquiryScreen> createState() => _HelpAndInquiryScreenState();
}

class _HelpAndInquiryScreenState extends State<HelpAndInquiryScreen> {
  static const Color _pink = Color(0xFFF0788F);
  static const Color _pinkDeep = Color(0xFFE85C79);
  static const Color _textColor = Color(0xFF1A1A1A);
  static const Color _subTextColor = Color(0xFF666A73);

  final HelpService _helpService = HelpService();
  _InquiryFilter _selectedFilter = _InquiryFilter.all;
  late final Stream<List<FaqItem>> _faqsStream = _helpService.watchFaqs();
  late final Stream<List<InquiryItem>> _inquiriesStream = _helpService.watchInquiries();
  late final Stream<List<ChatSessionSummary>> _chatSessionsStream = _helpService.watchChatSessions();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '문의 및 도움말',
        actions: [
          StreamBuilder<List<ChatSessionSummary>>(
            stream: _chatSessionsStream,
            builder: (context, snapshot) {
              final hasUnread = (snapshot.data ?? const [])
                  .any((s) => s.hasUnreadBotReply);

              return StreamBuilder<List<FaqItem>>(
                stream: _faqsStream,
                builder: (context, faqSnapshot) {
                  final faqs = faqSnapshot.data ?? const [];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatHistoryScreen(faqItems: faqs)),
                        ),
                        icon: const Icon(Icons.history_rounded, color: Color(0xFF302C2E)),
                      ),
                      if (hasUnread)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: AppMainBackground(
        child: StreamBuilder<List<FaqItem>>(
          stream: _faqsStream,
          builder: (context, faqSnapshot) {
            final faqs = faqSnapshot.data ?? const [];
            final faqsLoading = faqSnapshot.connectionState == ConnectionState.waiting && !faqSnapshot.hasData;

            return StreamBuilder<List<InquiryItem>>(
              stream: _inquiriesStream,
              builder: (context, inquirySnapshot) {
                final inquiries = inquirySnapshot.data ?? const [];
                final inquiriesLoading =
                    inquirySnapshot.connectionState == ConnectionState.waiting && !inquirySnapshot.hasData;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    _buildHeroCard(faqs),
                    const SizedBox(height: 28),
                    _buildSectionHeader(title: '자주 묻는 질문', countText: '${faqs.length}개'),
                    const SizedBox(height: 12),
                    if (faqsLoading)
                      const Center(child: CircularProgressIndicator(color: _pink))
                    else if (faqs.isEmpty)
                      _buildEmptyText('등록된 FAQ가 없습니다.')
                    else
                      ...faqs.map(
                            (faq) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildFaqCard(faq: faq),
                        ),
                      ),
                    const SizedBox(height: 22),
                    _buildSectionHeader(title: '내 문의 내역', countText: '${inquiries.length}건'),
                    const SizedBox(height: 12),
                    if (!inquiriesLoading && inquiries.isNotEmpty) ...[
                      _buildFilterChips(),
                      const SizedBox(height: 12),
                    ],
                    if (inquiriesLoading)
                      const Center(child: CircularProgressIndicator(color: _pink))
                    else if (inquiries.isEmpty)
                      _buildEmptyInquiryCard()
                    else if (_applyFilter(inquiries).isEmpty)
                        _buildEmptyText('해당하는 문의가 없습니다.')
                      else
                        ..._applyFilter(inquiries).map(
                              (inquiry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildInquiryCard(inquiry),
                          ),
                        ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<InquiryItem> _applyFilter(List<InquiryItem> inquiries) {
    switch (_selectedFilter) {
      case _InquiryFilter.waiting:
        return inquiries.where((i) => i.status == InquiryStatus.waiting).toList();
      case _InquiryFilter.completed:
        return inquiries.where((i) => i.status == InquiryStatus.completed).toList();
      case _InquiryFilter.all:
        return inquiries;
    }
  }

  Widget _buildFilterChips() {
    const options = {
      _InquiryFilter.all: '전체',
      _InquiryFilter.waiting: '답변대기',
      _InquiryFilter.completed: '답변완료',
    };

    return Row(
      children: options.entries.map((entry) {
        final isSelected = _selectedFilter == entry.key;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(entry.value),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedFilter = entry.key),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : _subTextColor,
            ),
            selectedColor: _pink,
            backgroundColor: const Color(0xFFF6F2F3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            side: BorderSide.none,
            showCheckmark: false,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(text, style: const TextStyle(fontSize: 13, color: _subTextColor)),
      ),
    );
  }

  Widget _buildHeroCard(List<FaqItem> faqs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 20, 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE4ED), Color(0xFFFFF5F8)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: _pink.withOpacity(0.14), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -75,
                top: -20,
                child: Opacity(
                  opacity: 0.92,
                  child: Image.asset(
                    'assets/images/cloud_it.png',
                    width: 104,
                    height: 104,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 68),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('도움이 필요하신가요?',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textColor)),
                    const SizedBox(height: 6),
                    const Text(
                      '자주 묻는 질문을 확인하거나\n챗봇에게 바로 물어볼 수 있어요.',
                      style: TextStyle(fontSize: 13.5, height: 1.55, color: _subTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_pink, _pinkDeep]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: _pinkDeep.withOpacity(0.32), blurRadius: 14, offset: const Offset(0, 6)),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openChatbot(faqs),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_rounded, size: 19, color: Colors.white),
                        SizedBox(width: 8),
                        Text('문의 챗봇 시작하기',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required String countText}) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: _pink, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: _textColor)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFFCEFF3), borderRadius: BorderRadius.circular(20)),
          child: Text(countText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _pink)),
        ),
      ],
    );
  }

  Widget _buildFaqCard({required FaqItem faq}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => faq.isExpanded = !faq.isExpanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFCEFF3)),
                    alignment: Alignment.center,
                    child: const Text('Q', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _pink)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(faq.question,
                        style: const TextStyle(fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w700, color: _textColor)),
                  ),
                  AnimatedRotation(
                    turns: faq.isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9AA0AC)),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: faq.isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF6F2F3),
                          border: Border.all(color: const Color(0xFFE7E3E5)),
                        ),
                        alignment: Alignment.center,
                        child: const Text('A',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _subTextColor)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(faq.answer, style: const TextStyle(fontSize: 13, height: 1.6, color: _subTextColor)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInquiryCard(InquiryItem inquiry) {
    final style = _getInquiryStatusStyle(inquiry.status);
    final barColor = inquiry.status == InquiryStatus.completed ? const Color(0xFF2E8B57) : const Color(0xFFE59B2E);
    final showUnreadDot = inquiry.status == InquiryStatus.completed && !inquiry.isReadByUser;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 4, color: barColor),
                Expanded(
                  child: InkWell(
                    onTap: () => _openInquiryDetail(inquiry),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 15, 12, 15),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _chip(inquiry.category, const Color(0xFFF6F2F3), _subTextColor),
                                    const SizedBox(width: 8),
                                    _chip(style.label, style.backgroundColor, style.foregroundColor),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(inquiry.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w700, color: _textColor)),
                                const SizedBox(height: 8),
                                Text(_formatDateTime(inquiry.createdAt),
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF9AA0AC))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(top: 26),
                            child: Icon(Icons.chevron_right_rounded, color: Color(0xFFB4B8C2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showUnreadDot)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFF0788F),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _buildEmptyInquiryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.94), borderRadius: BorderRadius.circular(20)),
      child: const Column(
        children: [
          Icon(Icons.mark_email_read_outlined, size: 44, color: Color(0xFFB4B8C2)),
          SizedBox(height: 12),
          Text('등록한 문의가 없습니다.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textColor)),
          SizedBox(height: 6),
          Text('궁금한 내용이 있다면\n챗봇으로 문의해보세요.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF9AA0AC))),
        ],
      ),
    );
  }

  Future<void> _openChatbot(List<FaqItem> faqs) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ChatbotScreen(faqItems: faqs)),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('문의가 등록되었습니다.')));
    }
  }

  void _openInquiryDetail(InquiryItem inquiry) {
    if (inquiry.status == InquiryStatus.completed && !inquiry.isReadByUser) {
      unawaited(_helpService.markInquiryRead(inquiry.id));
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => InquiryDetailScreen(inquiry: inquiry)));
  }
  InquiryStatusStyle _getInquiryStatusStyle(InquiryStatus status) {
    if (status == InquiryStatus.completed) {
      return const InquiryStatusStyle(
        label: '답변 완료',
        foregroundColor: Color(0xFF2E8B57),
        backgroundColor: Color(0xFFE8F7EE),
      );
    }
    return const InquiryStatusStyle(
      label: '답변 대기',
      foregroundColor: Color(0xFFE59B2E),
      backgroundColor: Color(0xFFFFF4DF),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}.$month.$day $hour:$minute';
  }
}

class InquiryDetailScreen extends StatelessWidget {
  final InquiryItem inquiry;

  const InquiryDetailScreen({super.key, required this.inquiry});

  static const Color _pink = Color(0xFFF0788F);

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = inquiry.status == InquiryStatus.completed;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(title: '문의 상세'),
      body: AppMainBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF6F2F3), borderRadius: BorderRadius.circular(20)),
                          child: Text(inquiry.category,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF666A73))),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCompleted ? const Color(0xFFE8F7EE) : const Color(0xFFFFF4DF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isCompleted ? '답변 완료' : '답변 대기',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isCompleted ? const Color(0xFF2E8B57) : const Color(0xFFE59B2E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(inquiry.title,
                        style: const TextStyle(fontSize: 19, height: 1.4, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 8),
                    Text(_formatDateTime(inquiry.createdAt), style: const TextStyle(fontSize: 12, color: Color(0xFF9AA0AC))),
                    const SizedBox(height: 18),
                    const Divider(height: 1, color: Color(0xFFF0EEF0)),
                    const SizedBox(height: 18),
                    Text(inquiry.content, style: const TextStyle(fontSize: 14, height: 1.65, color: Color(0xFF4F525A))),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (isCompleted) _buildAnswerCard() else _buildWaitingCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.support_agent_outlined, size: 22, color: _pink),
              SizedBox(width: 8),
              Text('관리자 답변', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            ],
          ),
          const SizedBox(height: 14),
          Text(inquiry.answer ?? '', style: const TextStyle(fontSize: 14, height: 1.65, color: Color(0xFF4F525A))),
          if (inquiry.answeredAt != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: Text(_formatDateTime(inquiry.answeredAt!), style: const TextStyle(fontSize: 12, color: Color(0xFF9AA0AC))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaitingCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE5B2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_outlined, size: 21, color: Color(0xFFE59B2E)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '관리자가 문의 내용을 확인하고 있습니다. 답변이 등록되면 문의 내역에서 확인할 수 있습니다.',
              style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF8A6429)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}.$month.$day $hour:$minute';
  }
}