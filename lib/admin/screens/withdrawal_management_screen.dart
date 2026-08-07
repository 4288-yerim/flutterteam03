import 'package:flutter/material.dart';

import '../../theme.dart';
import '../services/admin_withdrawal_service.dart';

class WithdrawalManagementScreen extends StatefulWidget {
  const WithdrawalManagementScreen({super.key});

  @override
  State<WithdrawalManagementScreen> createState() =>
      _WithdrawalManagementScreenState();
}

class _WithdrawalManagementScreenState
    extends State<WithdrawalManagementScreen> {
  final AdminWithdrawalService _service = AdminWithdrawalService();

  late Stream<List<AdminWithdrawalRequest>> _pendingRequests;

  final TextEditingController _searchController = TextEditingController();

  String _selectedReasonCode = 'ALL';

  static const List<_WithdrawalReasonFilter> _reasonFilters =
  <_WithdrawalReasonFilter>[
    _WithdrawalReasonFilter(code: 'ALL', label: '전체'),
    _WithdrawalReasonFilter(code: 'NOT_USED_OFTEN', label: '사용 빈도'),
    _WithdrawalReasonFilter(code: 'LACK_OF_FEATURES', label: '기능 부족'),
    _WithdrawalReasonFilter(code: 'INCONVENIENT', label: '사용 불편'),
    _WithdrawalReasonFilter(code: 'TOO_MANY_NOTIFICATIONS', label: '알림'),
    _WithdrawalReasonFilter(code: 'PRIVACY_CONCERN', label: '개인정보'),
    _WithdrawalReasonFilter(code: 'USE_OTHER_SERVICE', label: '타 서비스'),
    _WithdrawalReasonFilter(code: 'OTHER', label: '기타'),
  ];

  @override
  void initState() {
    super.initState();
    _pendingRequests = _service.watchPendingRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reloadRequests() {
    setState(() {
      _pendingRequests = _service.watchPendingRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: StreamBuilder<List<AdminWithdrawalRequest>>(
        stream: _pendingRequests,
        builder:
            (
            BuildContext context,
            AsyncSnapshot<List<AdminWithdrawalRequest>> snapshot,
            ) {
          if (snapshot.hasError) {
            return _WithdrawalMessageView(
              icon: Icons.error_outline_rounded,
              title: '탈퇴 신청 목록을 불러오지 못했습니다.',
              description: _withdrawalErrorDescription(snapshot.error),
              buttonLabel: '다시 시도',
              onPressed: _reloadRequests,
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: context.colors.lavenderAccent,
              ),
            );
          }

          final List<AdminWithdrawalRequest> allRequests = snapshot.data!;

          final String query = _searchController.text.trim().toLowerCase();

          final List<AdminWithdrawalRequest> visibleRequests = allRequests
              .where((AdminWithdrawalRequest request) {
            return request.matchesSearch(query) &&
                request.matchesReason(_selectedReasonCode);
          })
              .toList();

          final bool hasFilter =
              query.isNotEmpty || _selectedReasonCode != 'ALL';

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
            children: [
              _buildHeaderCard(allRequests.length),
              const SizedBox(height: 16),
              _buildSearchAndFilter(),
              const SizedBox(height: 18),
              _buildResultHeader(visibleRequests.length),
              const SizedBox(height: 12),
              if (visibleRequests.isEmpty)
                _buildEmptyView(
                  hasAnyRequest: allRequests.isNotEmpty,
                  hasFilter: hasFilter,
                )
              else
                ...visibleRequests.map((AdminWithdrawalRequest request) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _WithdrawalRequestCard(request: request),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(int totalCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.lavender,
            Color.lerp(context.colors.lavender, context.colors.surface, 0.55)!,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.surfaceTransparent,
            ),
            child: Icon(
              Icons.person_off_outlined,
              color: context.colors.lavenderAccent,
              size: 29,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '탈퇴 신청 현황',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '현재 탈퇴 대기 중인 회원 '
                      '$totalCount명의 신청 사유를 확인합니다.',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
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
          TextField(
            controller: _searchController,
            onChanged: (String value) {
              setState(() {});
            },
            decoration: const InputDecoration(
              hintText: '닉네임 또는 탈퇴 사유 검색',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '탈퇴 사유 필터',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _reasonFilters.map((_WithdrawalReasonFilter filter) {
                final bool isSelected = _selectedReasonCode == filter.code;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter.label),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      if (!selected) {
                        return;
                      }

                      setState(() {
                        _selectedReasonCode = filter.code;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultHeader(int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '조회 결과 $count건',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (_searchController.text.trim().isNotEmpty ||
            _selectedReasonCode != 'ALL')
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('초기화'),
          ),
      ],
    );
  }

  Widget _buildEmptyView({
    required bool hasAnyRequest,
    required bool hasFilter,
  }) {
    final String title;

    final String description;

    if (!hasAnyRequest) {
      title = '탈퇴 대기 회원이 없습니다.';
      description = '새로운 탈퇴 신청이 접수되면 이곳에 표시됩니다.';
    } else if (hasFilter) {
      title = '검색 조건에 맞는 신청이 없습니다.';
      description = '검색어나 탈퇴 사유 필터를 변경해 주세요.';
    } else {
      title = '표시할 탈퇴 신청이 없습니다.';
      description = '잠시 후 다시 확인해 주세요.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 64),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 50,
            color: context.colors.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary, height: 1.45),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('검색 조건 초기화'),
            ),
          ],
        ],
      ),
    );
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _selectedReasonCode = 'ALL';
    });
  }
}

class _WithdrawalRequestCard extends StatelessWidget {
  const _WithdrawalRequestCard({required this.request});

  final AdminWithdrawalRequest request;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = request.isExpired
        ? context.colors.incorrect
        : context.colors.lavenderAccent;

    final Color statusBackground = request.isExpired
        ? context.colors.incorrectSoft
        : context.colors.lavender;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.lavender,
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: context.colors.lavenderAccent,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.nickname,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      request.reasonLabel,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  request.remainingLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: context.colors.border),
          const SizedBox(height: 15),
          _WithdrawalInfoRow(
            icon: Icons.schedule_rounded,
            label: '신청일',
            value: _formatDateTime(request.requestedAt),
          ),
          const SizedBox(height: 10),
          _WithdrawalInfoRow(
            icon: Icons.event_busy_outlined,
            label: '탈퇴 예정일',
            value: _formatDateTime(request.scheduledAt),
          ),
          const SizedBox(height: 16),
          Text(
            '상세 사유',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              request.reasonDetail.isEmpty
                  ? '작성된 상세 사유가 없습니다.'
                  : request.reasonDetail,
              style: TextStyle(
                color: request.reasonDetail.isEmpty
                    ? context.colors.textMuted
                    : context.colors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalInfoRow extends StatelessWidget {
  const _WithdrawalInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _WithdrawalMessageView extends StatelessWidget {
  const _WithdrawalMessageView({
    required this.icon,
    required this.title,
    required this.description,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: context.colors.textMuted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textSecondary,
                height: 1.45,
              ),
            ),
            if (buttonLabel != null && onPressed != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.refresh_rounded, size: 19),
                label: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _withdrawalErrorDescription(Object? error) {
  final String errorText = error?.toString().toLowerCase() ?? '';

  if (errorText.contains('permission-denied')) {
    return '관리자의 users 조회 권한이 없습니다. '
        'Firestore Rules에서 관리자 조회 권한을 확인해 주세요.';
  }

  if (errorText.contains('unavailable') || errorText.contains('network')) {
    return '네트워크 연결이 불안정합니다. '
        '연결을 확인한 뒤 다시 시도해 주세요.';
  }

  return '잠시 후 다시 시도해 주세요.';
}

class _WithdrawalReasonFilter {
  const _WithdrawalReasonFilter({required this.code, required this.label});

  final String code;
  final String label;
}

String _formatDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return '확인할 수 없음';
  }

  final String month = dateTime.month.toString().padLeft(2, '0');

  final String day = dateTime.day.toString().padLeft(2, '0');

  final String hour = dateTime.hour.toString().padLeft(2, '0');

  final String minute = dateTime.minute.toString().padLeft(2, '0');

  return '${dateTime.year}.$month.$day '
      '$hour:$minute';
}
