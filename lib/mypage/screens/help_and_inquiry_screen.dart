import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class HelpAndInquiryScreen extends StatefulWidget {
  const HelpAndInquiryScreen({super.key});

  @override
  State<HelpAndInquiryScreen> createState() =>
      _HelpAndInquiryScreenState();
}

class _HelpAndInquiryScreenState
    extends State<HelpAndInquiryScreen> {
  // Firebase 연결 전 임시 FAQ 데이터
  final List<FaqItem> _faqItems = [
     FaqItem(
      question: '목표 자격증은 어디에서 추가하나요?',
      answer:
      '자격증 상세 화면에서 목표 자격증으로 등록할 수 있습니다. '
          '등록한 목표 자격증은 마이페이지의 목표 자격증 관리에서 확인하고 삭제할 수 있습니다.',
    ),
     FaqItem(
      question: '학습 계획은 어떻게 추가하나요?',
      answer:
      '마이페이지의 학습 계획 화면에서 날짜를 선택한 뒤 '
          '하단의 할 일 추가 버튼을 눌러 직접 등록할 수 있습니다.',
    ),
     FaqItem(
      question: '캘린더 일정을 휴대폰에 저장할 수 있나요?',
      answer:
      '캘린더 일정 카드의 메뉴를 누른 뒤 '
          '휴대폰 캘린더에 추가를 선택하면 저장할 수 있습니다.',
    ),
     FaqItem(
      question: '북마크한 게시글은 어디에서 확인하나요?',
      answer:
      '마이페이지의 북마크 메뉴에서 저장한 커뮤니티 게시글을 확인할 수 있습니다.',
    ),
     FaqItem(
      question: '알림을 종류별로 끌 수 있나요?',
      answer:
      '마이페이지의 설정 화면에서 자격증, 공부, 스터디, '
          '커뮤니티, 친구, 채팅 등의 알림을 각각 설정할 수 있습니다.',
    ),
  ];

  // Firebase 연결 전 임시 문의 내역
  final List<InquiryItem> _inquiries = [
    InquiryItem(
      id: 'inquiry_001',
      category: '앱 이용',
      title: '학습 계획 시간이 저장되지 않습니다.',
      content:
      '학습 계획을 추가한 뒤 다시 들어가면 시간이 사라집니다. 확인 부탁드립니다.',
      createdAt: DateTime(2026, 7, 14, 15, 30),
      status: InquiryStatus.waiting,
    ),
    InquiryItem(
      id: 'inquiry_002',
      category: '자격증 정보',
      title: '시험 일정 정보가 실제 일정과 다릅니다.',
      content:
      '정보처리기사 시험 일정이 큐넷에 표시된 일정과 다르게 보입니다.',
      createdAt: DateTime(2026, 7, 10, 11, 20),
      status: InquiryStatus.completed,
      answer:
      '제보해주신 시험 일정을 확인하여 수정했습니다. '
          '앱을 다시 실행한 뒤 확인해주세요.',
      answeredAt: DateTime(2026, 7, 11, 14, 10),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '문의 및 도움말',
      ),
      body: AppMainBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            40,
          ),
          children: [
            _buildHelpSummaryCard(),
            const SizedBox(height: 26),

            _buildSectionHeader(
              title: '자주 묻는 질문',
              countText: '${_faqItems.length}개',
            ),
            const SizedBox(height: 12),

            ...List.generate(
              _faqItems.length,
                  (index) {
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: _buildFaqCard(
                    faq: _faqItems[index],
                    index: index,
                  ),
                );
              },
            ),

            const SizedBox(height: 18),

            _buildInquiryButton(),
            const SizedBox(height: 28),

            _buildSectionHeader(
              title: '내 문의 내역',
              countText: '${_inquiries.length}건',
            ),
            const SizedBox(height: 12),

            if (_inquiries.isEmpty)
              _buildEmptyInquiryCard()
            else
              ..._inquiries.map(
                    (inquiry) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: _buildInquiryCard(inquiry),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSummaryCard() {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFCEFF3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.support_agent_outlined,
              size: 28,
              color: Color(0xFFF0788F),
            ),
          ),
          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '도움이 필요하신가요?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '자주 묻는 질문을 확인하거나\n새로운 문의를 등록할 수 있습니다.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF666A73),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String countText,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        Text(
          countText,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF0788F),
          ),
        ),
      ],
    );
  }

  Widget _buildFaqCard({
    required FaqItem faq,
    required int index,
  }) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            faq.isExpanded = !faq.isExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            17,
            15,
            14,
            15,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFCEFF3),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Q',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF0788F),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      faq.question,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Icon(
                    faq.isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF9AA0AC),
                  ),
                ],
              ),

              if (faq.isExpanded) ...[
                const SizedBox(height: 14),
                const Divider(
                  height: 1,
                  color: Color(0xFFF0EEF0),
                ),
                const SizedBox(height: 14),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF6F2F3),
                        border: Border.all(
                          color: const Color(0xFFE7E3E5),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'A',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF666A73),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        faq.answer,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: Color(0xFF666A73),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInquiryButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _showWriteInquiryDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF0788F),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(
          Icons.edit_note_rounded,
        ),
        label: const Text(
          '문의하기',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildInquiryCard(
      InquiryItem inquiry,
      ) {
    final InquiryStatusStyle statusStyle =
    _getInquiryStatusStyle(inquiry.status);

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          _openInquiryDetail(inquiry);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            17,
            16,
            12,
            16,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F2F3),
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                          child: Text(
                            inquiry.category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF666A73),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusStyle.backgroundColor,
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusStyle.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusStyle.foregroundColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Text(
                      inquiry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      _formatDateTime(inquiry.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9AA0AC),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Padding(
                padding: EdgeInsets.only(top: 26),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB4B8C2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyInquiryCard() {
    return AppCard(
      child: const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 30,
        ),
        child: Column(
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 44,
              color: Color(0xFFB4B8C2),
            ),
            SizedBox(height: 12),
            Text(
              '등록한 문의가 없습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 6),
            Text(
              '궁금한 내용이 있다면\n문의하기 버튼을 눌러주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF9AA0AC),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWriteInquiryDialog() async {
    final TextEditingController titleController =
    TextEditingController();

    final TextEditingController contentController =
    TextEditingController();

    String selectedCategory = '앱 이용';

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                '문의하기',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: '문의 유형',
                        border: OutlineInputBorder(),
                      ),
                      dropdownColor: Colors.white,
                      items: const [
                        DropdownMenuItem<String>(
                          value: '앱 이용',
                          child: Text('앱 이용'),
                        ),
                        DropdownMenuItem<String>(
                          value: '계정',
                          child: Text('계정'),
                        ),
                        DropdownMenuItem<String>(
                          value: '자격증 정보',
                          child: Text('자격증 정보'),
                        ),
                        DropdownMenuItem<String>(
                          value: '학습 기능',
                          child: Text('학습 기능'),
                        ),
                        DropdownMenuItem<String>(
                          value: '커뮤니티',
                          child: Text('커뮤니티'),
                        ),
                        DropdownMenuItem<String>(
                          value: '기타',
                          child: Text('기타'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: titleController,
                      textInputAction: TextInputAction.next,
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus
                            ?.unfocus();
                      },
                      decoration: const InputDecoration(
                        labelText: '제목',
                        hintText: '문의 제목을 입력해주세요.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: contentController,
                      minLines: 5,
                      maxLines: 8,
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus
                            ?.unfocus();
                      },
                      decoration: const InputDecoration(
                        labelText: '문의 내용',
                        hintText:
                        '문의할 내용을 자세히 입력해주세요.',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FocusManager.instance.primaryFocus
                        ?.unfocus();

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
                    if (titleController.text
                        .trim()
                        .isEmpty) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            '문의 제목을 입력해주세요.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (contentController.text
                        .trim()
                        .isEmpty) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            '문의 내용을 입력해주세요.',
                          ),
                        ),
                      );
                      return;
                    }

                    FocusManager.instance.primaryFocus
                        ?.unfocus();

                    Navigator.pop(
                      dialogContext,
                      true,
                    );
                  },
                  child: const Text(
                    '등록',
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
      },
    );

    if (result != true) {
      titleController.dispose();
      contentController.dispose();
      return;
    }

    final InquiryItem newInquiry = InquiryItem(
      id: DateTime.now()
          .millisecondsSinceEpoch
          .toString(),
      category: selectedCategory,
      title: titleController.text.trim(),
      content: contentController.text.trim(),
      createdAt: DateTime.now(),
      status: InquiryStatus.waiting,
    );

    titleController.dispose();
    contentController.dispose();

    setState(() {
      _inquiries.insert(
        0,
        newInquiry,
      );
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '문의가 등록되었습니다.',
        ),
      ),
    );
  }

  void _openInquiryDetail(
      InquiryItem inquiry,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return InquiryDetailScreen(
            inquiry: inquiry,
          );
        },
      ),
    );
  }

  InquiryStatusStyle _getInquiryStatusStyle(
      InquiryStatus status,
      ) {
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

  String _formatDateTime(
      DateTime dateTime,
      ) {
    final String month =
    dateTime.month.toString().padLeft(2, '0');

    final String day =
    dateTime.day.toString().padLeft(2, '0');

    final String hour =
    dateTime.hour.toString().padLeft(2, '0');

    final String minute =
    dateTime.minute.toString().padLeft(2, '0');

    return '${dateTime.year}.$month.$day $hour:$minute';
  }
}

class FaqItem {
  final String question;
  final String answer;
  bool isExpanded;

  FaqItem({
    required this.question,
    required this.answer,
    this.isExpanded = false,
  });
}

enum InquiryStatus {
  waiting,
  completed,
}

class InquiryItem {
  final String id;
  final String category;
  final String title;
  final String content;
  final DateTime createdAt;
  final InquiryStatus status;
  final String? answer;
  final DateTime? answeredAt;

  InquiryItem({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.status,
    this.answer,
    this.answeredAt,
  });
}

class InquiryStatusStyle {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const InquiryStatusStyle({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });
}

class InquiryDetailScreen extends StatelessWidget {
  final InquiryItem inquiry;

  const InquiryDetailScreen({
    super.key,
    required this.inquiry,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted =
        inquiry.status == InquiryStatus.completed;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '문의 상세',
      ),
      body: AppMainBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F2F3),
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                          child: Text(
                            inquiry.category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF666A73),
                            ),
                          ),
                        ),
                        const Spacer(),

                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFFE8F7EE)
                                : const Color(0xFFFFF4DF),
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                          child: Text(
                            isCompleted
                                ? '답변 완료'
                                : '답변 대기',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isCompleted
                                  ? const Color(0xFF2E8B57)
                                  : const Color(0xFFE59B2E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      inquiry.title,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.4,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      _formatDateTime(inquiry.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9AA0AC),
                      ),
                    ),
                    const SizedBox(height: 18),

                    const Divider(
                      height: 1,
                      color: Color(0xFFF0EEF0),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      inquiry.content,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.65,
                        color: Color(0xFF4F525A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (isCompleted)
                _buildAnswerCard()
              else
                _buildWaitingCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.support_agent_outlined,
                size: 22,
                color: Color(0xFFF0788F),
              ),
              SizedBox(width: 8),
              Text(
                '관리자 답변',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            inquiry.answer ?? '',
            style: const TextStyle(
              fontSize: 14,
              height: 1.65,
              color: Color(0xFF4F525A),
            ),
          ),

          if (inquiry.answeredAt != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatDateTime(inquiry.answeredAt!),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9AA0AC),
                ),
              ),
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
        border: Border.all(
          color: const Color(0xFFFFE5B2),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 21,
            color: Color(0xFFE59B2E),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '관리자가 문의 내용을 확인하고 있습니다. '
                  '답변이 등록되면 문의 내역에서 확인할 수 있습니다.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF8A6429),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(
      DateTime dateTime,
      ) {
    final String month =
    dateTime.month.toString().padLeft(2, '0');

    final String day =
    dateTime.day.toString().padLeft(2, '0');

    final String hour =
    dateTime.hour.toString().padLeft(2, '0');

    final String minute =
    dateTime.minute.toString().padLeft(2, '0');

    return '${dateTime.year}.$month.$day $hour:$minute';
  }
}