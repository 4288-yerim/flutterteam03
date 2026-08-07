import 'package:flutter/material.dart';

import '../theme.dart';

class AppDropdownItem<T> {
  const AppDropdownItem({required this.value, required this.label});

  final T value;
  final String label;
}

class AppAdminDropdown<T> extends StatelessWidget {
  const AppAdminDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.initialCenteredValue,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T> onChanged;
  final T? initialCenteredValue;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _AppDropdown<T>(
      label: label,
      value: value,
      items: items,
      onChanged: onChanged,
      initialCenteredValue: initialCenteredValue,
      enabled: enabled,
      selectedColor: context.colors.lavender,
      accentColor: context.colors.lavenderAccent,
    );
  }
}

class AppUserDropdown<T> extends StatelessWidget {
  const AppUserDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.initialCenteredValue,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T> onChanged;
  final T? initialCenteredValue;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _AppDropdown<T>(
      label: label,
      value: value,
      items: items,
      onChanged: onChanged,
      initialCenteredValue: initialCenteredValue,
      enabled: enabled,
      selectedColor: context.colors.pinkSoft,
      accentColor: context.colors.pinkDeep,
    );
  }
}

class _AppDropdown<T> extends StatefulWidget {
  const _AppDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.initialCenteredValue,
    required this.enabled,
    required this.selectedColor,
    required this.accentColor,
  });

  final String label;
  final T value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T> onChanged;
  final T? initialCenteredValue;
  final bool enabled;
  final Color selectedColor;
  final Color accentColor;

  @override
  State<_AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<_AppDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _targetKey = GlobalKey();
  OverlayEntry? _menuEntry;
  ScrollController? _menuScrollController;

  bool get _isOpen => _menuEntry != null;

  @override
  void dispose() {
    _menuEntry?.remove();
    _menuEntry = null;
    _menuScrollController?.dispose();
    _menuScrollController = null;
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
      return;
    }
    _openMenu();
  }

  void _openMenu() {
    final renderBox =
        _targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final width = renderBox.size.width;
    const itemHeight = 48.0;
    const separatorHeight = 1.0;
    const verticalPadding = 12.0;
    const maxMenuHeight = 280.0;
    final centeredIndex = widget.items.indexWhere(
      (item) => item.value == widget.initialCenteredValue,
    );
    final separatorCount = widget.items.isEmpty ? 0 : widget.items.length - 1;
    final contentHeight =
        verticalPadding +
        (widget.items.length * itemHeight) +
        (separatorCount * separatorHeight);
    final viewportHeight = contentHeight.clamp(0.0, maxMenuHeight).toDouble();
    final maxOffset = (contentHeight - viewportHeight)
        .clamp(0.0, double.infinity)
        .toDouble();
    final initialOffset = centeredIndex < 0
        ? 0.0
        : (6 +
                  centeredIndex * (itemHeight + separatorHeight) +
                  itemHeight / 2 -
                  viewportHeight / 2)
              .clamp(0.0, maxOffset)
              .toDouble();
    _menuScrollController = ScrollController(
      initialScrollOffset: initialOffset,
    );
    _menuEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeMenu,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 8),
            child: Material(
              elevation: 8,
              color: context.colors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width,
                  maxHeight: maxMenuHeight,
                ),
                child: SizedBox(
                  width: width,
                  child: ListView.separated(
                    controller: _menuScrollController,
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: widget.items.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: context.colors.divider),
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final selected = item.value == widget.value;
                      return SizedBox(
                        height: itemHeight,
                        child: ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: widget.selectedColor,
                          title: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: selected
                              ? Icon(
                                  Icons.check_rounded,
                                  color: widget.accentColor,
                                )
                              : null,
                          onTap: () {
                            _closeMenu();
                            widget.onChanged(item.value);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_menuEntry!);
    setState(() {});
  }

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
    _menuScrollController?.dispose();
    _menuScrollController = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    String selectedLabel = '';
    for (final item in widget.items) {
      if (item.value == widget.value) {
        selectedLabel = item.label;
        break;
      }
    }
    final borderColor = _isOpen ? widget.accentColor : context.colors.border;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Material(
        key: _targetKey,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.enabled ? _toggleMenu : null,
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            isEmpty: selectedLabel.isEmpty,
            decoration: InputDecoration(
              enabled: widget.enabled,
              labelText: selectedLabel.isEmpty ? null : widget.label,
              hintText: selectedLabel.isEmpty ? widget.label : null,
              filled: true,
              fillColor: context.colors.surfaceTransparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: context.colors.iconSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
