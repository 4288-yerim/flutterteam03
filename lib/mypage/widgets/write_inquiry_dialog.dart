import 'package:flutter/material.dart';

import '../../theme.dart';
import '../models/inquiry_models.dart';

List<String> kInquiryCategories = [
  '앱 이용',
  '계정',
  '자격증 정보',
  '학습 기능',
  '커뮤니티',
  '기타',
];

Future<InquiryDraft?> showWriteInquiryDialog(BuildContext context) {
  return showGeneralDialog<InquiryDraft>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '문의하기',
    barrierColor: context.colors.overlay,
    transitionDuration: Duration(milliseconds: 220),
    pageBuilder: (context, _, __) => _WriteInquiryDialogContent(),
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
  _WriteInquiryDialogContent();

  @override
  State<_WriteInquiryDialogContent> createState() =>
      _WriteInquiryDialogContentState();
}

class _WriteInquiryDialogContentState
    extends State<_WriteInquiryDialogContent> {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('문의 제목을 입력해주세요.')));
      return;
    }
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('문의 내용을 입력해주세요.')));
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
      insetPadding: EdgeInsets.symmetric(horizontal: 22),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420),
        child: Container(
          padding: EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow,
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
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
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.colors.pinkStart,
                            context.colors.pinkDeep,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: context.colors.onPrimary,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '문의하기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: context.colors.textMuted,
                      ),
                      splashRadius: 20,
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '문의 유형',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textSecondary,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kInquiryCategories.map((c) {
                    final selected = c == _selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = c),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          gradient: selected
                              ? LinearGradient(
                                  colors: [
                                    context.colors.pinkStart,
                                    context.colors.pinkDeep,
                                  ],
                                )
                              : null,
                          color: selected ? null : context.colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? context.colors.onPrimary
                                : context.colors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 18),
                Text(
                  '제목',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textSecondary,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    hintText: '문의 제목을 입력해주세요.',
                    filled: true,
                    fillColor: context.colors.surfaceMuted,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '문의 내용',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textSecondary,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  minLines: 5,
                  maxLines: 8,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    hintText: '문의할 내용을 자세히 입력해주세요.',
                    filled: true,
                    fillColor: context.colors.surfaceMuted,
                    contentPadding: EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.colors.pinkStart,
                          context.colors.pinkDeep,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _submit,
                        child: Center(
                          child: Text(
                            '등록하기',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: context.colors.onPrimary,
                            ),
                          ),
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
