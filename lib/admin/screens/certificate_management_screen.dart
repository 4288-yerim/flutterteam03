import 'package:flutter/material.dart';

import '../../theme.dart';
import '../services/admin_certificate_service.dart';
import 'admin_certificate_detail_screen.dart';

class CertificateManagementScreen extends StatefulWidget {
  const CertificateManagementScreen({super.key});

  @override
  State<CertificateManagementScreen> createState() =>
      _CertificateManagementScreenState();
}

class _CertificateManagementScreenState
    extends State<CertificateManagementScreen> {
  final AdminCertificateService _service = AdminCertificateService();
  final TextEditingController _searchController = TextEditingController();
  AdminCertificateScope _selectedScope = AdminCertificateScope.all;
  String _selectedSubfilterKey = _CertificateSubfilterOption.allKey;
  String _selectedCertificateCategoryKey = _CertificateCategoryOption.allKey;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: StreamBuilder<List<AdminCertificate>>(
        stream: _service.watchCertificates(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _buildError();
          if (!snapshot.hasData) return _buildLoading();

          final allCertificates = snapshot.data!;
          final subfilters = _subfilterOptions(allCertificates);
          final selectedSubfilterKey = subfilters.any(
            (option) => option.key == _selectedSubfilterKey,
          )
              ? _selectedSubfilterKey
              : _CertificateSubfilterOption.allKey;
          const certificateCategories = <_CertificateCategoryOption>[];
          final selectedCertificateCategoryKey = certificateCategories.any(
            (option) => option.key == _selectedCertificateCategoryKey,
          )
              ? _selectedCertificateCategoryKey
              : _CertificateCategoryOption.allKey;
          final certificates = _filteredCertificates(
            allCertificates,
            selectedSubfilterKey,
            selectedCertificateCategoryKey,
          );
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
            children: [
              _CertificateSearchControls(
                controller: _searchController,
                selectedScope: _selectedScope,
                subfilters: subfilters,
                selectedSubfilterKey: selectedSubfilterKey,
                certificateCategories: certificateCategories,
                selectedCertificateCategoryKey: selectedCertificateCategoryKey,
                onSearchChanged: (_) => setState(() {}),
                onScopeChanged: (scope) {
                  setState(() {
                    _selectedScope = scope;
                    _selectedSubfilterKey = _CertificateSubfilterOption.allKey;
                    _selectedCertificateCategoryKey =
                        _CertificateCategoryOption.allKey;
                  });
                },
                onSubfilterChanged: (key) {
                  setState(() {
                    _selectedSubfilterKey = key;
                    _selectedCertificateCategoryKey =
                        _CertificateCategoryOption.allKey;
                  });
                },
                onCertificateCategoryChanged: (key) {
                  setState(() => _selectedCertificateCategoryKey = key);
                },
              ),
              const SizedBox(height: 18),
              Text(
                '조회 자격증 ${certificates.length}개',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (certificates.isEmpty)
                _CertificateMessageView(
                  icon: Icons.search_off_rounded,
                  message: '검색 조건에 맞는 자격증이 없습니다.',
                )
              else
                ...certificates.map(
                  (certificate) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CertificateCard(
                      certificate: certificate,
                      onTap: () async {
                        await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => AdminCertificateDetailScreen(
                              certificate: certificate,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<AdminCertificate> _filteredCertificates(
    List<AdminCertificate> certificates,
    String selectedSubfilterKey,
    String selectedCertificateCategoryKey,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return certificates.where((certificate) {
      final matchesName =
          query.isEmpty || certificate.name.toLowerCase().contains(query);
      return matchesName &&
          _selectedScope.matches(certificate) &&
          _matchesSubfilter(certificate, selectedSubfilterKey) &&
          _matchesCertificateCategory(
            certificate,
            selectedCertificateCategoryKey,
          );
    }).toList();
  }

  List<_CertificateCategoryOption> _certificateCategoryOptions(
    List<AdminCertificate> certificates,
    String selectedSubfilterKey,
  ) {
    if (_selectedScope != AdminCertificateScope.other ||
        selectedSubfilterKey == _CertificateSubfilterOption.allKey) {
      return const [];
    }

    final categories = <String, String>{
      for (final certificate in certificates)
        if (_selectedScope.matches(certificate) &&
            _matchesSubfilter(certificate, selectedSubfilterKey) &&
            certificate.qualificationCode.isNotEmpty)
          certificate.qualificationCode: certificate.qualificationName.isEmpty
              ? certificate.qualificationCode
              : certificate.qualificationName,
    };
    final options = categories.entries
        .map(
          (entry) => _CertificateCategoryOption(
            key: entry.key,
            label: entry.value,
          ),
        )
        .toList()
      ..sort((first, second) => first.label.compareTo(second.label));

    return [
      const _CertificateCategoryOption(
        key: _CertificateCategoryOption.allKey,
        label: '전체 자격증 카테고리',
      ),
      ...options,
    ];
  }

  List<_CertificateSubfilterOption> _subfilterOptions(
    List<AdminCertificate> certificates,
  ) {
    final options = <_CertificateSubfilterOption>[
      const _CertificateSubfilterOption(
        key: _CertificateSubfilterOption.allKey,
        label: '전체 직무 분야',
      ),
    ];

    switch (_selectedScope) {
      case AdminCertificateScope.all:
        return options;
      case AdminCertificateScope.technical:
        final categories = <String>{
          for (final certificate in certificates)
            if (certificate.isTechnical && certificate.fieldName.isNotEmpty)
              certificate.fieldName,
        }.toList()
          ..sort();
        options.addAll(
          categories.map(
            (category) => _CertificateSubfilterOption(
              key: 'field:$category',
              label: category,
            ),
          ),
        );
        return options;
      case AdminCertificateScope.professional:
        final categories = <String>{
          for (final certificate in certificates)
            if (certificate.isProfessional && certificate.seriesName.isNotEmpty)
              certificate.seriesName,
        }.toList()
          ..sort();
        options.addAll(
          categories.map(
            (category) => _CertificateSubfilterOption(
              key: 'field:$category',
              label: category,
            ),
          ),
        );
        return options;
      case AdminCertificateScope.other:
        final fields = <String>{
          for (final certificate in certificates)
            if (_selectedScope.matches(certificate) &&
                certificate.fieldName.isNotEmpty)
              certificate.fieldName,
        }.toList()
          ..sort();
        options.addAll(
          fields.map(
            (field) => _CertificateSubfilterOption(
              key: 'field:$field',
              label: field,
            ),
          ),
        );
        return options;
    }
  }

  bool _matchesSubfilter(
    AdminCertificate certificate,
    String selectedSubfilterKey,
  ) {
    if (selectedSubfilterKey == _CertificateSubfilterOption.allKey) {
      return true;
    }
    if (selectedSubfilterKey.startsWith('field:')) {
      final field = selectedSubfilterKey.substring('field:'.length);
      return certificate.isProfessional
          ? certificate.seriesName == field
          : certificate.fieldName == field;
    }
    return true;
  }

  bool _matchesCertificateCategory(
    AdminCertificate certificate,
    String selectedCategoryKey,
  ) {
    return selectedCategoryKey == _CertificateCategoryOption.allKey ||
        certificate.qualificationCode == selectedCategoryKey;
  }

  Widget _buildLoading() => const Center(child: CircularProgressIndicator());

  Widget _buildError() {
    return const _CertificateMessageView(
      icon: Icons.error_outline_rounded,
      message: '자격증 목록을 불러오지 못했습니다.',
    );
  }
}

enum AdminCertificateScope { all, technical, professional, other }

extension on AdminCertificateScope {
  String get label => switch (this) {
        AdminCertificateScope.all => '전체 자격증',
        AdminCertificateScope.technical => '국가기술자격',
        AdminCertificateScope.professional => '국가전문자격',
        AdminCertificateScope.other => '그외',
      };

  bool matches(AdminCertificate certificate) => switch (this) {
        AdminCertificateScope.all => true,
        AdminCertificateScope.technical =>
          !certificate.isOther && certificate.isTechnical,
        AdminCertificateScope.professional =>
          !certificate.isOther && certificate.isProfessional,
        AdminCertificateScope.other => certificate.isOther ||
            (!certificate.isTechnical && !certificate.isProfessional),
      };
}

class _CertificateSearchControls extends StatelessWidget {
  const _CertificateSearchControls({
    required this.controller,
    required this.selectedScope,
    required this.subfilters,
    required this.selectedSubfilterKey,
    required this.certificateCategories,
    required this.selectedCertificateCategoryKey,
    required this.onSearchChanged,
    required this.onScopeChanged,
    required this.onSubfilterChanged,
    required this.onCertificateCategoryChanged,
  });

  final TextEditingController controller;
  final AdminCertificateScope selectedScope;
  final List<_CertificateSubfilterOption> subfilters;
  final String selectedSubfilterKey;
  final List<_CertificateCategoryOption> certificateCategories;
  final String selectedCertificateCategoryKey;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AdminCertificateScope> onScopeChanged;
  final ValueChanged<String> onSubfilterChanged;
  final ValueChanged<String> onCertificateCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: context.colors.border),
    );
    return Column(
      children: [
        _AnchoredFilterDropdown<AdminCertificateScope>(
          label: '자격증 분류',
          value: selectedScope,
          items: AdminCertificateScope.values
              .map(
                (scope) => _FilterDropdownItem(
                  value: scope,
                  label: scope.label,
                ),
              )
              .toList(),
          onChanged: onScopeChanged,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: selectedScope == AdminCertificateScope.all
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _AnchoredFilterDropdown<String>(
                    label: '직무 분야',
                    value: selectedSubfilterKey,
                    items: subfilters
                        .map(
                          (subfilter) => _FilterDropdownItem(
                            value: subfilter.key,
                            label: subfilter.label,
                          ),
                        )
                        .toList(),
                    onChanged: onSubfilterChanged,
                  ),
                ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: certificateCategories.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _AnchoredFilterDropdown<String>(
                    label: '자격증 카테고리',
                    value: selectedCertificateCategoryKey,
                    items: certificateCategories
                        .map(
                          (category) => _FilterDropdownItem(
                            value: category.key,
                            label: category.label,
                          ),
                        )
                        .toList(),
                    onChanged: onCertificateCategoryChanged,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '자격증 이름으로 검색',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '검색어 지우기',
                    onPressed: () {
                      controller.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: context.colors.surfaceTransparent,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(
                color: context.colors.lavenderAccent,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CertificateSubfilterOption {
  const _CertificateSubfilterOption({required this.key, required this.label});

  static const allKey = 'all';

  final String key;
  final String label;
}

class _CertificateCategoryOption {
  const _CertificateCategoryOption({
    required this.key,
    required this.label,
  });

  static const allKey = 'all';

  final String key;
  final String label;
}

class _FilterDropdownItem<T> {
  const _FilterDropdownItem({required this.value, required this.label});

  final T value;
  final String label;
}

class _AnchoredFilterDropdown<T> extends StatefulWidget {
  const _AnchoredFilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<_FilterDropdownItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  State<_AnchoredFilterDropdown<T>> createState() =>
      _AnchoredFilterDropdownState<T>();
}

class _AnchoredFilterDropdownState<T>
    extends State<_AnchoredFilterDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _targetKey = GlobalKey();
  OverlayEntry? _menuEntry;

  bool get _isOpen => _menuEntry != null;

  @override
  void dispose() {
    _menuEntry?.remove();
    _menuEntry = null;
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
                constraints: BoxConstraints(maxWidth: width, maxHeight: 280),
                child: SizedBox(
                  width: width,
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: widget.items.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: context.colors.divider,
                    ),
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final selected = item.value == widget.value;
                      return ListTile(
                        dense: true,
                        selected: selected,
                        selectedTileColor: context.colors.lavender,
                        title: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                        trailing: selected
                            ? Icon(
                                Icons.check_rounded,
                                color: context.colors.lavenderAccent,
                              )
                            : null,
                        onTap: () {
                          _closeMenu();
                          widget.onChanged(item.value);
                        },
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
    final borderColor =
        _isOpen ? context.colors.lavenderAccent : context.colors.border;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Material(
        key: _targetKey,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _toggleMenu,
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.label,
              filled: true,
              fillColor: context.colors.surfaceTransparent,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({required this.certificate, required this.onTap});

  final AdminCertificate certificate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.surfaceTransparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.lavender,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.workspace_premium_outlined,
              color: context.colors.lavenderAccent,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  certificate.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (certificate.detailText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    certificate.detailText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _CategoryChip(certificate: certificate),
        ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.certificate});

  final AdminCertificate certificate;

  @override
  Widget build(BuildContext context) {
    final isOther = certificate.isOther ||
        (!certificate.isTechnical && !certificate.isProfessional);
    final label = isOther
        ? '그 외'
        : certificate.isTechnical
        ? '국가기술자격'
        : '국가전문자격';
    final backgroundColor = isOther
        ? context.colors.otherCertificateSoft
        : certificate.isTechnical
        ? context.colors.softBlue
        : context.colors.mint;
    final foregroundColor = isOther
        ? context.colors.otherCertificateAccent
        : certificate.isTechnical
        ? context.colors.info
        : context.colors.correct;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CertificateMessageView extends StatelessWidget {
  const _CertificateMessageView({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 42, color: context.colors.textMuted),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
