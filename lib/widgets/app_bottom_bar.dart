import 'package:flutter/material.dart';

import '../theme.dart';

/// 하단 네비게이션 바 아이템
class AppBottomBarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const AppBottomBarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

/// 배경이 투명한 하단 네비게이션 바
/// 앱 전체에서 동일하게 쓰는 5개 메뉴가 파일 안에 고정되어 있어서,
/// 페이지에서는 currentIndex와 onTap만 넘기면 됩니다.
///
/// 사용 예시:
/// ```dart
/// Scaffold(
///   extendBody: true,
///   bottomNavigationBar: AppBottomBar(
///     currentIndex: _currentIndex,
///     onTap: (i) => setState(() => _currentIndex = i),
///   ),
///   body: AppMainBackground(child: YourContent()),
/// )
/// ```
class AppBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? unselectedColor;
  final List<Color>? elevatedGradient;

  // 👇 앱 전체에서 고정으로 쓰는 메뉴 목록. 아이콘/라벨 바꾸고 싶으면 여기만 수정하면 됩니다.
  static const List<AppBottomBarItem> _items = [
    AppBottomBarItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: '홈',
    ),
    AppBottomBarItem(
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book,
      label: '스터디',
    ),
    AppBottomBarItem(icon: Icons.auto_awesome, label: 'AI'),
    AppBottomBarItem(
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups,
      label: '커뮤니티',
    ),
    AppBottomBarItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: '마이페이지',
    ),
  ];

  // 👇 튀어나오는 자리는 항상 가운데(3번째, index 2)로 고정
  static const int _elevatedIndex = 2;

  const AppBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor,
    this.selectedColor,
    this.unselectedColor,
    this.elevatedGradient,
  });

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final elevatedIndex = _elevatedIndex;
    final colors = context.colors;
    final resolvedSelectedColor = selectedColor ?? colors.pinkDeep;
    final resolvedUnselectedColor = unselectedColor ?? colors.iconSecondary;
    final resolvedGradient =
        elevatedGradient ?? [colors.pinkStart, colors.pinkDeep];
    final bottomInset = MediaQuery.of(
      context,
    ).padding.bottom; // 홈 인디케이터 등 하단 안전영역

    return SizedBox(
      height: 78 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 기본 바 배경
          Positioned.fill(
            top: 14, // 튀어나온 버튼이 들어갈 공간 확보
            child: Container(
              padding: EdgeInsets.only(
                bottom: bottomInset,
              ), // 하단 안전영역만큼 아이콘을 위로 띄움
              decoration: BoxDecoration(
                color: backgroundColor ?? colors.surface,
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow,
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(items.length, (index) {
                  final isElevated = index == elevatedIndex;
                  return Expanded(
                    child: isElevated
                        ? const SizedBox.shrink() // 튀어나온 아이템 자리는 비워둠
                        : _NavItem(
                            item: items[index],
                            isSelected: index == currentIndex,
                            selectedColor: resolvedSelectedColor,
                            unselectedColor: resolvedUnselectedColor,
                            onTap: () => onTap(index),
                          ),
                  );
                }),
              ),
            ),
          ),
          // 튀어나온 버튼 (항상 가운데)
          Positioned(
            top: 0,
            child: _ElevatedNavItem(
              item: items[elevatedIndex],
              isSelected: elevatedIndex == currentIndex,
              gradientColors: resolvedGradient,
              selectedColor: resolvedSelectedColor,
              unselectedColor: resolvedUnselectedColor,
              onTap: () => onTap(elevatedIndex),
            ),
          ),
        ],
      ),
    );
  }
}

/// 일반 하단바 아이템 (아이콘 + 라벨)
class _NavItem extends StatelessWidget {
  final AppBottomBarItem item;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? selectedColor : unselectedColor;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected && item.activeIcon != null ? item.activeIcon : item.icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 위로 튀어나온(elevated) 하단바 아이템 — 가운데 AI 버튼 같은 용도
class _ElevatedNavItem extends StatelessWidget {
  final AppBottomBarItem item;
  final bool isSelected;
  final List<Color> gradientColors;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const _ElevatedNavItem({
    required this.item,
    required this.isSelected,
    required this.gradientColors,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.last.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(item.icon, color: colors.onPrimary, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? selectedColor : unselectedColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
