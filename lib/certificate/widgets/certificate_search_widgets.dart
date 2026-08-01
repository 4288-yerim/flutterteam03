import 'package:flutter/material.dart';

import '../../theme.dart';

import 'certificate_common_widgets.dart';

class CertificateSearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const CertificateSearchField({
    super.key,
    required this.controller,
    required this.isSearching,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: certificateCardDecoration(context: context),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        style: TextStyle(
          color: context.colors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: '자격증 이름을 검색해보세요',
          hintStyle: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: context.colors.pinkDeep,
            size: 23,
          ),
          suffixIcon: isSearching
              ? IconButton(
                  onPressed: onClear,
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.colors.textSecondary,
                    size: 20,
                  ),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        ),
      ),
    );
  }
}

class QualificationTypeSelector extends StatelessWidget {
  final Map<String, String> qualificationTypes;
  final String selectedCode;
  final ValueChanged<String> onSelected;

  const QualificationTypeSelector({
    super.key,
    required this.qualificationTypes,
    required this.selectedCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: context.colors.pinkSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: qualificationTypes.entries.map((entry) {
          final bool selected = entry.key == selectedCode;

          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelected(entry.key),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 180),
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? context.colors.pinkDeep
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    entry.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? context.colors.onPrimary
                          : context.colors.textSecondary,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class CertificateCategoryCard extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const CertificateCategoryCard({
    super.key,
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? context.colors.pinkSoft : context.colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? context.colors.pinkDeep : Colors.transparent,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? context.colors.pinkDeep
                    : context.colors.textSecondary,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CollapsedSelectionCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onReselect;

  const CollapsedSelectionCard({
    super.key,
    required this.title,
    required this.value,
    required this.onReselect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: certificateCardDecoration(context: context),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: context.colors.pinkDeep,
            size: 24,
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          TextButton(
            onPressed: onReselect,
            style: TextButton.styleFrom(
              foregroundColor: context.colors.pinkDeep,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            child: Text(
              '다시 선택',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class CertificateSelectionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CertificateSelectionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.colors.pinkDeep : context.colors.pinkSoft,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 17, vertical: 11),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(30)),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? context.colors.onPrimary
                  : context.colors.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class SelectedPathCard extends StatelessWidget {
  final String text;

  const SelectedPathCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.pinkSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_tree_outlined,
            color: context.colors.pinkDeep,
            size: 19,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CertificateListTile extends StatelessWidget {
  final String certificateName;
  final String detailText;
  final String qualificationCode;
  final VoidCallback onTap;

  const CertificateListTile({
    super.key,
    required this.certificateName,
    required this.detailText,
    required this.qualificationCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTechnical = qualificationCode == 'T';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isTechnical
                      ? context.colors.softBlue
                      : context.colors.mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  color: isTechnical
                      ? context.colors.info
                      : context.colors.correct,
                  size: 22,
                ),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificateName,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (detailText.isNotEmpty) ...[
                      SizedBox(height: 5),
                      Text(
                        detailText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CertificateSearchResultTile extends StatelessWidget {
  final String certificateName;
  final String qualificationType;
  final String detailText;
  final String qualificationCode;
  final VoidCallback onTap;

  const CertificateSearchResultTile({
    super.key,
    required this.certificateName,
    required this.qualificationType,
    required this.detailText,
    required this.qualificationCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTechnical = qualificationCode == 'T';

    final String subtitle = detailText.isEmpty
        ? qualificationType
        : '$qualificationType · $detailText';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isTechnical
                      ? context.colors.softBlue
                      : context.colors.mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  color: isTechnical
                      ? context.colors.info
                      : context.colors.correct,
                  size: 22,
                ),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificateName,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptySearchResult extends StatelessWidget {
  const EmptySearchResult({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        children: [
          CertificateEmptyIcon(icon: Icons.search_off_rounded),
          SizedBox(height: 14),
          Text(
            '검색 결과가 없습니다.',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '다른 자격증 이름으로 검색해보세요.',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
