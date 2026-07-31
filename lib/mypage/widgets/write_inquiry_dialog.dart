import 'package:flutter/material.dart';
import '../models/inquiry_models.dart';

const List<String> kInquiryCategories = [
  '앱 이용', '계정', '자격증 정보', '학습 기능', '커뮤니티', '기타',
];

const Color _pink = Color(0xFFF0788F);
const Color _pinkDeep = Color(0xFFE85C79);

Future<InquiryDraft?> showWriteInquiryDialog(BuildContext context) {
  return showGeneralDialog<InquiryDraft>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '문의하기',
    barrierColor: Colors.black.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, __) => const _WriteInquiryDialogContent(),
    transitionBuilder: (context, animation, _, child) {
      final value = animation.value.clamp(0.0, 1.0);
      return Transform.scale(
        scale: 0.92 + (0.08 * value),
        child: Opacity(opacity: value, child: child),
      );
    },
  );
}

class _WriteInquiryDialogContent extends StatefulWidget {
  const _WriteInquiryDialogContent();

  @override
  State<_WriteInquiryDialogContent> createState() => _WriteInquiryDialogContentState();
}

class _WriteInquiryDialogContentState extends State<_WriteInquiryDialogContent> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = kInquiryCategories.first;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('문의 제목을 입력해주세요.')));
      return;
    }
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('문의 내용을 입력해주세요.')));
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.pop(
      context,
      InquiryDraft(
        category: _selectedCategory,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 30, offset: const Offset(0, 14)),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [_pink, _pinkDeep]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '문의하기',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFFB4B8C2)),
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('문의 유형',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF666A73))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kInquiryCategories.map((c) {
                    final selected = c == _selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          gradient: selected ? const LinearGradient(colors: [_pink, _pinkDeep]) : null,
                          color: selected ? null : const Color(0xFFF6F2F3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : const Color(0xFF666A73),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const Text('제목',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF666A73))),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    hintText: '문의 제목을 입력해주세요.',
                    filled: true,
                    fillColor: const Color(0xFFF6F2F3),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('문의 내용',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF666A73))),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  minLines: 5,
                  maxLines: 8,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    hintText: '문의할 내용을 자세히 입력해주세요.',
                    filled: true,
                    fillColor: const Color(0xFFF6F2F3),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_pink, _pinkDeep]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _submit,
                        child: const Center(
                          child: Text('등록하기',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
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