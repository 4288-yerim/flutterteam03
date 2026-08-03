import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../services/admin_notification_service.dart';

class NotificationSendScreen extends StatefulWidget {
  const NotificationSendScreen({super.key});

  @override
  State<NotificationSendScreen> createState() => _NotificationSendScreenState();
}

class _NotificationSendScreenState extends State<NotificationSendScreen> {
  final AdminNotificationService _service = AdminNotificationService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedUids = <String>{};
  bool _sendToAll = true;
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _send(List<AdminNotificationUser> users) async {
    FocusScope.of(context).unfocus();
    final targetLabel = _sendToAll ? '활성 회원 전체' : '${_selectedUids.length}명';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('알림 발송'),
        content: Text('$targetLabel에게 알림을 발송하시겠습니까?\n발송한 푸시는 취소할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('발송'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSending = true);
    try {
      final result = await _service.sendNotification(
        title: _titleController.text,
        body: _bodyController.text,
        sendToAll: _sendToAll,
        selectedUids: _selectedUids,
      );
      if (!mounted) return;
      _titleController.clear();
      _bodyController.clear();
      setState(() => _selectedUids.clear());
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('발송 완료'),
          content: Text(
            '대상 회원 ${result.recipientCount}명\n'
                '앱 내부 알림 ${result.storedCount}건\n'
                '푸시 성공 ${result.pushSuccessCount}건\n'
                '푸시 실패 ${result.pushFailureCount}건\n'
                '푸시 설정으로 생략 ${result.pushSkippedCount}명',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminNotificationUser>>(
      stream: _service.watchActiveUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _MessageView(
            icon: Icons.error_outline_rounded,
            title: '회원 목록을 불러오지 못했습니다.',
          );
        }
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: context.colors.lavenderAccent,
            ),
          );
        }

        final users = snapshot.data!;
        final query = _searchController.text.trim().toLowerCase();
        final visibleUsers = users.where((user) {
          return query.isEmpty ||
              user.nickname.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query);
        }).toList();

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
              children: [
                _HeaderCard(totalUsers: users.length),
                const SizedBox(height: 16),
                _FormCard(
                  titleController: _titleController,
                  bodyController: _bodyController,
                  sendToAll: _sendToAll,
                  onTargetChanged: (value) {
                    setState(() => _sendToAll = value);
                  },
                ),
                if (!_sendToAll) ...[
                  const SizedBox(height: 16),
                  _UserSelector(
                    users: visibleUsers,
                    selectedUids: _selectedUids,
                    searchController: _searchController,
                    onSearchChanged: (_) => setState(() {}),
                    onToggle: (uid) {
                      setState(() {
                        if (!_selectedUids.add(uid)) _selectedUids.remove(uid);
                      });
                    },
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _isSending ? null : () => _send(users),
                  icon: const Icon(Icons.send_rounded),
                  label: Text(
                    _isSending
                        ? '발송 중...'
                        : _sendToAll
                        ? '전체 회원에게 발송'
                        : '${_selectedUids.length}명에게 발송',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ),
            if (_isSending)
              Positioned.fill(
                child: ColoredBox(
                  color: context.colors.overlay,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.totalUsers});
  final int totalUsers;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Icon(
            Icons.notifications_active_outlined,
            color: context.colors.lavenderAccent,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '관리자 알림 발송',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  '발송 가능한 활성 회원 $totalUsers명 · 앱 내부 알림과 FCM 푸시를 함께 전송합니다.',
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.titleController,
    required this.bodyController,
    required this.sendToAll,
    required this.onTargetChanged,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final bool sendToAll;
  final ValueChanged<bool> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('발송 대상', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('전체 회원')),
              ButtonSegment(value: false, label: Text('특정 회원')),
            ],
            selected: {sendToAll},
            onSelectionChanged: (values) => onTargetChanged(values.first),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: titleController,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: '알림 제목',
              hintText: '예: 서비스 점검 안내',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: bodyController,
            minLines: 5,
            maxLines: 9,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: '알림 내용',
              hintText: '회원에게 전달할 내용을 입력해 주세요.',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserSelector extends StatelessWidget {
  const _UserSelector({
    required this.users,
    required this.selectedUids,
    required this.searchController,
    required this.onSearchChanged,
    required this.onToggle,
  });

  final List<AdminNotificationUser> users;
  final Set<String> selectedUids;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '회원 선택 · ${selectedUids.length}명 선택됨',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: '닉네임 또는 이메일 검색',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          if (users.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '검색 결과가 없습니다.',
                  style: TextStyle(color: context.colors.textMuted),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 330),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: users.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selectedUids.contains(user.uid),
                    onChanged: (_) => onToggle(user.uid),
                    title: Text(user.nickname),
                    subtitle: Text(user.email),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: child,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: context.colors.textMuted),
          const SizedBox(height: 12),
          Text(title),
        ],
      ),
    );
  }
}

String _errorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    return error.message ?? '알림 발송에 실패했습니다.';
  }
  if (error is ArgumentError) return error.message?.toString() ?? '$error';
  if (error is StateError) return error.message;
  return '알림 발송에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}
