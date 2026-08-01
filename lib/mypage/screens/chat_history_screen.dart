import 'package:flutter/material.dart';

import '../../theme.dart';

import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../models/inquiry_models.dart';
import '../services/help_service.dart';
import '../utils/relative_time.dart';
import 'chatbot_screen.dart';

class ChatHistoryScreen extends StatefulWidget {
  final List<FaqItem> faqItems;

  const ChatHistoryScreen({super.key, required this.faqItems});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final HelpService _helpService = HelpService();

  late final Stream<List<ChatSessionSummary>> _sessionsStream = _helpService
      .watchChatSessions()
      .asBroadcastStream();

  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      // 아무것도 선택 안 된 상태로 돌아가면 선택 모드 자동 해제
      if (_selectedIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _toggleSelectAll(List<ChatSessionSummary> sessions) {
    setState(() {
      final allIds = sessions.map((s) => s.id).toSet();
      final allSelected =
          allIds.isNotEmpty && _selectedIds.length == allIds.length;
      if (allSelected) {
        _selectedIds.clear();
        _selectionMode = false;
      } else {
        _selectedIds
          ..clear()
          ..addAll(allIds);
      }
    });
  }

  Future<void> _confirmDeleteSession(ChatSessionSummary session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: context.colors.overlay,
      builder: (_) => _DeleteSessionDialog(count: 1),
    );

    if (confirmed != true) return;

    try {
      await _helpService.deleteChatSession(session.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('대화가 삭제되었습니다.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제에 실패했어요. 다시 시도해주세요.')));
      }
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final count = _selectedIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: context.colors.overlay,
      builder: (_) => _DeleteSessionDialog(count: count),
    );

    if (confirmed != true) return;

    try {
      await _helpService.deleteChatSessions(_selectedIds.toList());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$count개의 대화가 삭제되었습니다.')));
        _exitSelectionMode();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제에 실패했어요. 다시 시도해주세요.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatSessionSummary>>(
      stream: _sessionsStream,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? [];
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _selectionMode
              ? AppBar(
                  backgroundColor: context.colors.surface,
                  elevation: 0,
                  leading: IconButton(
                    onPressed: _exitSelectionMode,
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.colors.iconPrimary,
                    ),
                  ),
                  title: Text(
                    '${_selectedIds.length}개 선택',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => _toggleSelectAll(sessions),
                      child: Text(
                        (sessions.isNotEmpty &&
                                _selectedIds.length == sessions.length)
                            ? '전체해제'
                            : '전체선택',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: context.colors.pinkStart,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : _confirmDeleteSelected,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: _selectedIds.isEmpty
                            ? context.colors.textDisabled
                            : context.colors.incorrect,
                      ),
                    ),
                    SizedBox(width: 4),
                  ],
                )
              : AppTopBar(title: '챗봇 대화 기록'),
          body: AppMainBackground(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: context.colors.pinkStart,
                    ),
                  )
                : sessions.isEmpty
                ? _EmptyHistory()
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 40),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isSelected = _selectedIds.contains(session.id);
                      return Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: _SessionCard(
                          session: session,
                          selectionMode: _selectionMode,
                          isSelected: isSelected,
                          onTap: () {
                            if (_selectionMode) {
                              _toggleSelection(session.id);
                              return;
                            }
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatbotScreen(
                                  faqItems: widget.faqItems,
                                  sessionId: session.id,
                                ),
                              ),
                            );
                          },
                          onLongPress: () {
                            if (_selectionMode) {
                              _toggleSelection(session.id);
                            } else {
                              _enterSelectionMode(session.id);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ChatSessionSummary session;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SessionCard({
    required this.session,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? context.colors.pinkSoft : context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(color: context.colors.pinkStart, width: 1.4)
                : null,
          ),
          child: Row(
            children: [
              // 선택 모드일 때만 체크박스가 나타나도록 애니메이션 처리
              AnimatedSize(
                duration: Duration(milliseconds: 150),
                child: selectionMode
                    ? Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? context.colors.pinkStart
                                : context.colors.onPrimary,
                            border: Border.all(
                              color: isSelected
                                  ? context.colors.pinkStart
                                  : context.colors.textDisabled,
                              width: 1.6,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: context.colors.onPrimary,
                                )
                              : null,
                        ),
                      )
                    : SizedBox(width: 0),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colors.surface,
                      border: Border.all(
                        color: context.colors.pinkBorder,
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.shadow,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: context.colors.pinkSoft,
                      backgroundImage: AssetImage('assets/images/cloud_it.png'),
                    ),
                  ),
                  if (session.hasUnreadBotReply)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: context.colors.pinkStart,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.colors.onPrimary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.preview.isEmpty ? '대화 내용 없음' : session.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      formatRelativeTime(session.updatedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!selectionMode)
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 46,
              color: context.colors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              '아직 챗봇과 나눈 대화가 없어요.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteSessionDialog extends StatelessWidget {
  final int count;
  const _DeleteSessionDialog({required this.count});

  @override
  Widget build(BuildContext context) {
    final isMultiple = count > 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 36),
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    context.colors.pinkStart.withOpacity(0.14),
                    context.colors.pinkDeep.withOpacity(0.14),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.delete_outline_rounded,
                size: 30,
                color: context.colors.pinkDeep,
              ),
            ),
            SizedBox(height: 18),
            Text(
              isMultiple ? '대화 $count개를 삭제할까요?' : '대화를 삭제할까요?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '삭제하면 대화 내용을\n다시 복구할 수 없어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: context.colors.textSecondary,
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.colors.pinkStart,
                            context.colors.pinkDeep,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.pinkDeep.withOpacity(0.28),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(context, true),
                          child: Center(
                            child: Text(
                              '삭제',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: context.colors.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
