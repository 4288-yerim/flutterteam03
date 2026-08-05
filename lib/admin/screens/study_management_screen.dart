import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/cached_user_profile_builder.dart';
import '../services/admin_study_service.dart';

class StudyManagementScreen extends StatefulWidget {
  const StudyManagementScreen({super.key, required this.onReportTap});

  final VoidCallback onReportTap;

  @override
  State<StudyManagementScreen> createState() => _StudyManagementScreenState();
}

class _StudyManagementScreenState extends State<StudyManagementScreen> {
  final AdminStudyService _service = AdminStudyService();
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<AdminStudyGroup>> _groups = _service.watchGroups();
  late final Stream<Map<String, int>> _reportCounts = _service
      .watchStudyReportCounts();
  _StudyFilter _filter = _StudyFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminStudyGroup>>(
      stream: _groups,
      builder: (context, groupSnapshot) {
        if (groupSnapshot.hasError) {
          return const _MessageView(
            icon: Icons.error_outline_rounded,
            title: '스터디 목록을 불러오지 못했습니다.',
          );
        }
        if (!groupSnapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: context.colors.lavenderAccent,
            ),
          );
        }

        return StreamBuilder<Map<String, int>>(
          stream: _reportCounts,
          builder: (context, reportSnapshot) {
            final reportCounts = reportSnapshot.data ?? const <String, int>{};
            final allGroups = groupSnapshot.data!;
            final visibleGroups = _applyFilter(allGroups);
            final totalReports = reportCounts.values.fold<int>(
              0,
              (sum, count) => sum + count,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
              children: [
                _StudyHeader(
                  totalCount: allGroups.length,
                  privateCount: allGroups
                      .where((group) => !group.isPublic)
                      .length,
                  totalReports: totalReports,
                  searchController: _searchController,
                  selectedFilter: _filter,
                  onSearchChanged: (_) => setState(() {}),
                  onFilterChanged: (filter) => setState(() => _filter = filter),
                  onReportTap: widget.onReportTap,
                ),
                const SizedBox(height: 18),
                if (visibleGroups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: _MessageView(
                      icon: Icons.groups_outlined,
                      title: '표시할 스터디가 없습니다.',
                    ),
                  )
                else
                  ...visibleGroups.map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StudyCard(
                        group: group,
                        reportCount: reportCounts[group.id] ?? 0,
                        onReportTap: widget.onReportTap,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  List<AdminStudyGroup> _applyFilter(List<AdminStudyGroup> groups) {
    final query = _searchController.text.trim().toLowerCase();
    return groups
        .where((group) {
          final matchesFilter = switch (_filter) {
            _StudyFilter.all => true,
            _StudyFilter.public => group.isPublic,
            _StudyFilter.private => !group.isPublic,
          };
          final matchesSearch =
              query.isEmpty ||
              group.groupName.toLowerCase().contains(query) ||
              group.ownerNickname.toLowerCase().contains(query);
          return matchesFilter && matchesSearch;
        })
        .toList(growable: false);
  }
}

enum _StudyFilter { all, public, private }

class _StudyHeader extends StatelessWidget {
  const _StudyHeader({
    required this.totalCount,
    required this.privateCount,
    required this.totalReports,
    required this.searchController,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onReportTap,
  });

  final int totalCount;
  final int privateCount;
  final int totalReports;
  final TextEditingController searchController;
  final _StudyFilter selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_StudyFilter> onFilterChanged;
  final VoidCallback onReportTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '스터디 운영 현황',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onReportTap,
                icon: const Icon(Icons.report_outlined, size: 18),
                label: const Text('신고 관리'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '전체 $totalCount개 · 비공개 $privateCount개 · 누적 신고 $totalReports건',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: '스터디명, 그룹장 닉네임 검색',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                const [
                  _FilterData(_StudyFilter.all, '전체'),
                  _FilterData(_StudyFilter.public, '공개'),
                  _FilterData(_StudyFilter.private, '비공개'),
                ].map((data) {
                  return FilterChip(
                    selected: selectedFilter == data.filter,
                    label: Text(data.label),
                    onSelected: (_) => onFilterChanged(data.filter),
                    selectedColor: context.colors.lavender,
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FilterData {
  const _FilterData(this.filter, this.label);

  final _StudyFilter filter;
  final String label;
}

class _StudyCard extends StatelessWidget {
  const _StudyCard({
    required this.group,
    required this.reportCount,
    required this.onReportTap,
  });

  final AdminStudyGroup group;
  final int reportCount;
  final VoidCallback onReportTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _VisibilityBadge(isPublic: group.isPublic),
              const SizedBox(width: 8),
              if (reportCount > 0)
                _ReportBadge(count: reportCount, onTap: onReportTap),
              const Spacer(),
              Text(
                _formatDate(group.createdAt),
                style: TextStyle(color: context.colors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            group.groupName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          if (group.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              group.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 13),
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 17,
                color: context.colors.textMuted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: CachedNicknameText(
                  uid: group.ownerUid,
                  fallback: group.ownerNickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(
                Icons.groups_outlined,
                size: 17,
                color: context.colors.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                '${group.currentMemberCount} / ${group.maxMemberCount}명',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            group.certificateName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.isPublic});

  final bool isPublic;

  @override
  Widget build(BuildContext context) {
    final color = isPublic ? context.colors.correct : context.colors.textMuted;
    final background = isPublic
        ? context.colors.correctSoft
        : context.colors.surfaceMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPublic ? '공개' : '비공개',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReportBadge extends StatelessWidget {
  const _ReportBadge({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: context.colors.warningSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '신고 $count건',
          style: TextStyle(
            color: context.colors.warning,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.colors.textMuted),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return '날짜 없음';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}.${two(date.month)}.${two(date.day)}';
}
