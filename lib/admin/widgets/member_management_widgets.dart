import 'package:flutter/material.dart';

import '../services/admin_member_service.dart';

enum AdminMemberStatusFilter { all, active, suspended, dormant, withdrawn }

enum AdminMemberViewFilter {
  defaultOrder,
  reportCount,
  recentJoin,
  longInactive,
}

class AdminMemberSearchControls extends StatelessWidget {
  const AdminMemberSearchControls({
    super.key,
    required this.controller,
    required this.selectedFilter,
    required this.selectedViewFilter,
    required this.counts,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onViewFilterChanged,
  });

  final TextEditingController controller;
  final AdminMemberStatusFilter selectedFilter;
  final AdminMemberViewFilter selectedViewFilter;
  final Map<AdminMemberStatusFilter, int> counts;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AdminMemberStatusFilter> onFilterChanged;
  final ValueChanged<AdminMemberViewFilter> onViewFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '닉네임으로 회원 검색',
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
            fillColor: Colors.white.withValues(alpha: 0.95),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2DFE6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2DFE6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF6C63FF),
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<AdminMemberStatusFilter>(
                initialValue: selectedFilter,
                decoration: _dropdownDecoration('회원 상태'),
                items: AdminMemberStatusFilter.values.map((filter) {
                  return DropdownMenuItem(
                    value: filter,
                    child: Text(
                      '${adminMemberFilterLabel(filter)} '
                      '(${counts[filter] ?? 0})',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) onFilterChanged(value);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<AdminMemberViewFilter>(
                initialValue: selectedViewFilter,
                decoration: _dropdownDecoration('정렬·조건'),
                items: AdminMemberViewFilter.values.map((filter) {
                  return DropdownMenuItem(
                    value: filter,
                    child: Text(adminMemberViewFilterLabel(filter)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) onViewFilterChanged(value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.95),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2DFE6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2DFE6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6C63FF)),
      ),
    );
  }
}

List<AdminMember> adminApplyViewFilter(
  List<AdminMember> members,
  AdminMemberViewFilter filter,
) {
  final result = List<AdminMember>.from(members);
  final now = DateTime.now();
  switch (filter) {
    case AdminMemberViewFilter.defaultOrder:
      return result;
    case AdminMemberViewFilter.reportCount:
      result.sort((a, b) => b.reportCount.compareTo(a.reportCount));
      return result;
    case AdminMemberViewFilter.recentJoin:
      final threshold = now.subtract(const Duration(days: 14));
      return result.where((member) {
        return member.createdAt != null && member.createdAt!.isAfter(threshold);
      }).toList();
    case AdminMemberViewFilter.longInactive:
      final threshold = DateTime(now.year - 1, now.month, now.day);
      return result.where((member) {
        return !member.hasPersistentLogin &&
            member.lastLoginAt != null &&
            member.lastLoginAt!.isBefore(threshold);
      }).toList();
  }
}

String adminMemberViewFilterLabel(AdminMemberViewFilter filter) {
  return switch (filter) {
    AdminMemberViewFilter.defaultOrder => '기본',
    AdminMemberViewFilter.reportCount => '신고 많은 순',
    AdminMemberViewFilter.recentJoin => '최근 14일 가입',
    AdminMemberViewFilter.longInactive => '1년 이상 미접속',
  };
}

Map<AdminMemberStatusFilter, int> adminMemberFilterCounts(
  List<AdminMember> members,
) {
  return {
    for (final filter in AdminMemberStatusFilter.values)
      filter: members
          .where((member) => adminMemberMatchesFilter(member, filter))
          .length,
  };
}

bool adminMemberMatchesFilter(
  AdminMember member,
  AdminMemberStatusFilter filter,
) {
  return switch (filter) {
    AdminMemberStatusFilter.all => true,
    AdminMemberStatusFilter.active => member.status == 'ACTIVE',
    AdminMemberStatusFilter.suspended => member.status == 'SUSPENDED',
    AdminMemberStatusFilter.dormant => member.status == 'DORMANT',
    AdminMemberStatusFilter.withdrawn =>
      member.status == 'WITHDRAWN' || member.status == 'WITHDRAWAL_PENDING',
  };
}

String adminMemberFilterLabel(AdminMemberStatusFilter filter) {
  return switch (filter) {
    AdminMemberStatusFilter.all => '전체',
    AdminMemberStatusFilter.active => '활성',
    AdminMemberStatusFilter.suspended => '정지',
    AdminMemberStatusFilter.dormant => '휴면',
    AdminMemberStatusFilter.withdrawn => '탈퇴',
  };
}

class AdminMemberCard extends StatelessWidget {
  const AdminMemberCard({super.key, required this.member, required this.onTap});

  final AdminMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AdminMemberProfileImage(url: member.profileImageUrl, size: 52),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.nickname,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      member.identifier.isEmpty
                          ? '아이디 정보 없음'
                          : member.identifier,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF77747E),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AdminMemberStatusChip(member: member),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF99949E)),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminMemberStatusChip extends StatelessWidget {
  const AdminMemberStatusChip({super.key, required this.member});

  final AdminMember member;

  @override
  Widget build(BuildContext context) {
    final color = switch (member.status) {
      'ACTIVE' => const Color(0xFF35A982),
      'DORMANT' => const Color(0xFFE59831),
      'SUSPENDED' => const Color(0xFFE85D68),
      _ => const Color(0xFF77747E),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        member.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class AdminMemberProfileImage extends StatelessWidget {
  const AdminMemberProfileImage({
    super.key,
    required this.url,
    required this.size,
  });

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFF0EDFF),
      child: Icon(
        Icons.person_rounded,
        color: const Color(0xFF6C63FF),
        size: size * 0.55,
      ),
    );
    if (url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class AdminMemberMessageView extends StatelessWidget {
  const AdminMemberMessageView({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: const Color(0xFF99949E)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Color(0xFF77747E))),
        ],
      ),
    );
  }
}
