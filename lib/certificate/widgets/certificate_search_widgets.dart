import 'package:flutter/material.dart';

import 'certificate_common_widgets.dart';

/// 자격증 이름 검색 필드.
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
      decoration: certificateCardDecoration(),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        style: const TextStyle(
          color: certificateDarkText,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: '자격증 이름을 검색해보세요',
          hintStyle: const TextStyle(
            color: certificateGrayText,
            fontSize: 15,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: certificatePrimaryPink,
            size: 23,
          ),
          suffixIcon: isSearching
              ? IconButton(
            onPressed: onClear,
            icon: const Icon(
              Icons.close_rounded,
              color: certificateGrayText,
              size: 20,
            ),
          )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

/// 국가기술자격 / 국가전문자격 선택 영역.
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
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: certificatePinkSoft,
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
                  duration: const Duration(milliseconds: 180),
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? certificatePrimaryPink
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    entry.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : certificateBodyText,
                      fontSize: 14,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
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

/// 직무 분야 및 전문자격 분야 선택 카드.
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
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: selected ? certificatePinkSoft : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? certificatePrimaryPink
                  : Colors.transparent,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? certificatePrimaryPink
                    : certificateGrayText,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: certificateDarkText,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w600,
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

/// 선택한 직무 분야 또는 전문자격 분야 요약 카드.
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
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      decoration: certificateCardDecoration(),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: certificatePrimaryPink,
            size: 24,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: certificateGrayText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: certificateDarkText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onReselect,
            style: TextButton.styleFrom(
              foregroundColor: certificatePrimaryPink,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
            child: const Text(
              '다시 선택',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 기술자격 세부 분류 선택 칩.
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
      color: selected ? certificatePrimaryPink : certificatePinkSoft,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : certificateBodyText,
              fontSize: 13,
              fontWeight: selected
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 현재 선택한 경로를 간단하게 표시한다.
class SelectedPathCard extends StatelessWidget {
  final String text;

  const SelectedPathCard({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: certificatePinkSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_tree_outlined,
            color: certificatePrimaryPink,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: certificateBodyText,
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

/// 분야 선택 이후 표시되는 자격증 목록 항목.
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
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isTechnical
                      ? certificateSoftBlue
                      : certificateMint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  color: isTechnical
                      ? const Color(0xFF5B7FC4)
                      : const Color(0xFF4D9678),
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificateName,
                      style: const TextStyle(
                        color: certificateDarkText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (detailText.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        detailText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: certificateGrayText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: certificateGrayText,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이름 검색 결과 항목.
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
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isTechnical
                      ? certificateSoftBlue
                      : certificateMint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  color: isTechnical
                      ? const Color(0xFF5B7FC4)
                      : const Color(0xFF4D9678),
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificateName,
                      style: const TextStyle(
                        color: certificateDarkText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: certificateGrayText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: certificateGrayText,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이름 검색 결과가 없을 때 표시한다.
class EmptySearchResult extends StatelessWidget {
  const EmptySearchResult({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 40,
      ),
      decoration: certificateCardDecoration(),
      child: const Column(
        children: [
          CertificateEmptyIcon(
            icon: Icons.search_off_rounded,
          ),
          SizedBox(height: 14),
          Text(
            '검색 결과가 없습니다.',
            style: TextStyle(
              color: certificateBodyText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '다른 자격증 이름으로 검색해보세요.',
            style: TextStyle(
              color: certificateGrayText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}