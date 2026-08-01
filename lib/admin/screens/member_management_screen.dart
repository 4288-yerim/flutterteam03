import 'package:flutter/material.dart';

import '../../theme.dart';

import '../services/admin_member_service.dart';
import '../widgets/member_management_widgets.dart';
import 'member_detail_screen.dart';

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  AdminMemberStatusFilter _statusFilter = AdminMemberStatusFilter.all;
  AdminMemberViewFilter _viewFilter = AdminMemberViewFilter.defaultOrder;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = AdminMemberService();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: StreamBuilder<List<AdminMember>>(
        stream: service.watchMembers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const AdminMemberMessageView(
              icon: Icons.error_outline_rounded,
              message: '회원 목록을 불러오지 못했습니다.',
            );
          }
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: context.colors.lavenderAccent,
              ),
            );
          }

          final allMembers = snapshot.data!;
          final query = _searchController.text.trim().toLowerCase();
          final statusMembers = allMembers.where((member) {
            final matchesNickname =
                query.isEmpty || member.nickname.toLowerCase().contains(query);
            return matchesNickname &&
                adminMemberMatchesFilter(member, _statusFilter);
          }).toList();
          final members = adminApplyViewFilter(statusMembers, _viewFilter);

          final controls = AdminMemberSearchControls(
            controller: _searchController,
            selectedFilter: _statusFilter,
            selectedViewFilter: _viewFilter,
            counts: adminMemberFilterCounts(allMembers),
            onSearchChanged: (_) => setState(() {}),
            onFilterChanged: (filter) {
              setState(() => _statusFilter = filter);
            },
            onViewFilterChanged: (filter) {
              setState(() => _viewFilter = filter);
            },
          );

          if (members.isEmpty) {
            return RefreshIndicator(
              color: context.colors.lavenderAccent,
              onRefresh: service.refreshMembers,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  controls,
                  const SizedBox(height: 120),
                  const AdminMemberMessageView(
                    icon: Icons.people_outline,
                    message: '검색 조건에 맞는 회원이 없습니다.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: context.colors.lavenderAccent,
            onRefresh: service.refreshMembers,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
              children: [
                controls,
                const SizedBox(height: 18),
                Text(
                  '조회 회원 ${members.length}명',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ...members.map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AdminMemberCard(
                      member: member,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MemberDetailScreen(member: member),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
