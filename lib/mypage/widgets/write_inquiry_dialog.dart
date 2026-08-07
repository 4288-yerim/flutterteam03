import 'package:flutter/material.dart';

import '../../theme.dart';
import '../models/inquiry_models.dart';

const List<String> kInquiryCategories =
<String>[
  '앱 이용',
  '계정',
  '자격증 정보',
  '학습 기능',
  '커뮤니티',
  '기타',
];

Future<InquiryDraft?> showWriteInquiryDialog(
    BuildContext context,
    ) {
  return showGeneralDialog<InquiryDraft>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '문의하기',
    barrierColor: context.colors.overlay,
    transitionDuration:
    const Duration(milliseconds: 220),
    pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        ) {
      return const _WriteInquiryDialogContent();
    },
    transitionBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
        ) {
      final double value =
      animation.value.clamp(0.0, 1.0);

      return Transform.scale(
        scale: 0.92 + (0.08 * value),
        child: Opacity(
          opacity: value,
          child: child,
        ),
      );
    },
  );
}

class _WriteInquiryDialogContent
    extends StatefulWidget {
  const _WriteInquiryDialogContent();

  @override
  State<_WriteInquiryDialogContent>
  createState() =>
      _WriteInquiryDialogContentState();
}

class _WriteInquiryDialogContentState
    extends State<_WriteInquiryDialogContent> {
  final TextEditingController _titleController =
  TextEditingController();

  final TextEditingController
  _contentController =
  TextEditingController();

  final FocusNode _titleFocusNode =
  FocusNode();

  final FocusNode _contentFocusNode =
  FocusNode();

  String _selectedCategory =
      kInquiryCategories.first;

  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();

    super.dispose();
  }

  void _submit() {
    final String title =
    _titleController.text.trim();

    final String content =
    _contentController.text.trim();

    if (title.isEmpty) {
      setState(() {
        _errorMessage =
        '문의 제목을 입력해주세요.';
      });

      _titleFocusNode.requestFocus();
      return;
    }

    if (content.isEmpty) {
      setState(() {
        _errorMessage =
        '문의 내용을 입력해주세요.';
      });

      _contentFocusNode.requestFocus();
      return;
    }

    FocusManager.instance.primaryFocus
        ?.unfocus();

    Navigator.pop(
      context,
      InquiryDraft(
        category: _selectedCategory,
        title: title,
        content: content,
      ),
    );
  }

  void _clearError() {
    if (_errorMessage == null) {
      return;
    }

    setState(() {
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
      const EdgeInsets.symmetric(
        horizontal: 22,
      ),
      child: ConstrainedBox(
        constraints:
        const BoxConstraints(
          maxWidth: 420,
        ),
        child: Container(
          padding:
          const EdgeInsets.fromLTRB(
            22,
            22,
            22,
            18,
          ),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius:
            BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow,
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration:
                      BoxDecoration(
                        gradient:
                        LinearGradient(
                          colors: [
                            context
                                .colors
                                .pinkStart,
                            context
                                .colors
                                .pinkDeep,
                          ],
                        ),
                        shape:
                        BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: context
                            .colors
                            .onPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '문의하기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                          FontWeight.w800,
                          color: context
                              .colors
                              .textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: context
                            .colors
                            .textMuted,
                      ),
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '문의 유형',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                    FontWeight.w700,
                    color: context
                        .colors
                        .textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                  kInquiryCategories.map((
                      String category,
                      ) {
                    final bool
                    isSelected =
                        category ==
                            _selectedCategory;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory =
                              category;
                        });
                      },
                      child:
                      AnimatedContainer(
                        duration:
                        const Duration(
                          milliseconds:
                          150,
                        ),
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal:
                          14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          gradient:
                          isSelected
                              ? LinearGradient(
                            colors: [
                              context
                                  .colors
                                  .pinkStart,
                              context
                                  .colors
                                  .pinkDeep,
                            ],
                          )
                              : null,
                          color:
                          isSelected
                              ? null
                              : context
                              .colors
                              .surfaceMuted,
                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                            FontWeight
                                .w700,
                            color:
                            isSelected
                                ? context
                                .colors
                                .onPrimary
                                : context
                                .colors
                                .textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text(
                  '제목',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                    FontWeight.w700,
                    color: context
                        .colors
                        .textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  textInputAction:
                  TextInputAction.next,
                  onChanged: (
                      String value,
                      ) {
                    _clearError();
                  },
                  onSubmitted: (
                      String value,
                      ) {
                    _contentFocusNode
                        .requestFocus();
                  },
                  onTapOutside: (
                      PointerDownEvent event,
                      ) {
                    FocusManager
                        .instance
                        .primaryFocus
                        ?.unfocus();
                  },
                  decoration: InputDecoration(
                    hintText:
                    '문의 제목을 입력해주세요.',
                    filled: true,
                    fillColor: context
                        .colors
                        .surfaceMuted,
                    contentPadding:
                    const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border:
                    OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(
                        14,
                      ),
                      borderSide:
                      BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '문의 내용',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                    FontWeight.w700,
                    color: context
                        .colors
                        .textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller:
                  _contentController,
                  focusNode:
                  _contentFocusNode,
                  minLines: 5,
                  maxLines: 8,
                  onChanged: (
                      String value,
                      ) {
                    _clearError();
                  },
                  onTapOutside: (
                      PointerDownEvent event,
                      ) {
                    FocusManager
                        .instance
                        .primaryFocus
                        ?.unfocus();
                  },
                  decoration: InputDecoration(
                    hintText:
                    '문의할 내용을 자세히 입력해주세요.',
                    filled: true,
                    fillColor: context
                        .colors
                        .surfaceMuted,
                    contentPadding:
                    const EdgeInsets.all(
                      14,
                    ),
                    border:
                    OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(
                        14,
                      ),
                      borderSide:
                      BorderSide.none,
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: context
                          .colors
                          .incorrectSoft,
                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),
                      border: Border.all(
                        color: context
                            .colors
                            .incorrect
                            .withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons
                              .error_outline_rounded,
                          size: 18,
                          color: context
                              .colors
                              .incorrect,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: context
                                  .colors
                                  .incorrect,
                              fontSize: 13,
                              height: 1.4,
                              fontWeight:
                              FontWeight
                                  .w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context
                              .colors
                              .pinkStart,
                          context
                              .colors
                              .pinkDeep,
                        ],
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        16,
                      ),
                    ),
                    child: Material(
                      color:
                      Colors.transparent,
                      child: InkWell(
                        borderRadius:
                        BorderRadius.circular(
                          16,
                        ),
                        onTap: _submit,
                        child: Center(
                          child: Text(
                            '등록하기',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                              FontWeight
                                  .w800,
                              color: context
                                  .colors
                                  .onPrimary,
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