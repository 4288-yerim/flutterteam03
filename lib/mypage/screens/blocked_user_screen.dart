import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/user_profile_cache_service.dart';
import '../../theme.dart';

import '../../widgets/app_dialog.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../profile/user_profile_screen.dart';

class BlockedUserScreen extends StatefulWidget {
  const BlockedUserScreen({super.key});

  @override
  State<BlockedUserScreen> createState() => _BlockedUserScreenState();
}

class _BlockedUserScreenState extends State<BlockedUserScreen> {
  bool _isLoading = true;
  List<BlockedUserItem> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers({bool forceRefresh = false}) async {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _blockedUsers = [];
        _isLoading = false;
      });

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot<Map<String, dynamic>> blockedSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .collection('blockedUsers')
              .orderBy('createdAt', descending: true)
              .get();

      final List<BlockedUserItem> blockedUsers = [];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> blockedDocument
          in blockedSnapshot.docs) {
        final profile = await UserProfileCacheService.instance.getProfile(
          blockedDocument.id,
          forceRefresh: forceRefresh,
        );

        final Map<String, dynamic> blockedData = blockedDocument.data();

        final String nickname = profile?.isDeleted == true
            ? '탈퇴한 사용자'
            : (profile?.nickname.trim() ?? '알 수 없는 사용자');

        final String savedProfileImageUrl =
            profile?.profileImageUrl.trim() ?? '';

        final Timestamp? createdAt = blockedData['createdAt'] as Timestamp?;

        final String reason = (blockedData['reason'] as String? ?? 'OTHER')
            .trim()
            .toUpperCase();

        blockedUsers.add(
          BlockedUserItem(
            uid: blockedDocument.id,
            nickname: nickname.isEmpty ? '알 수 없는 사용자' : nickname,
            profileImageUrl: savedProfileImageUrl.isNotEmpty
                ? savedProfileImageUrl
                : null,
            createdAt: createdAt?.toDate(),
            reason: reason,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _blockedUsers = blockedUsers;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _blockedUsers = [];
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('차단 사용자 목록을 불러오지 못했습니다.')));
    }
  }

  Future<void> _unblockUser(BlockedUserItem user) async {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      return;
    }

    final bool? shouldUnblock = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppAlertDialog(
          title: const Text(
            '차단 해제',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text('${user.nickname}님의 차단을 해제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                '취소',
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                '차단 해제',
                style: TextStyle(
                  color: context.colors.pinkStart,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldUnblock != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('blockedUsers')
          .doc(user.uid)
          .delete();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${user.nickname}님의 차단을 해제했습니다.')));

      await _loadBlockedUsers();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('차단을 해제하지 못했습니다.')));
    }
  }

  Future<void> _openUserProfile(BlockedUserItem user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userUid: user.uid)),
    );

    await _loadBlockedUsers();
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '차단 일시 없음';
    }

    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '${date.year}.$month.$day';
  }

  String _getReasonText(String reason) {
    if (reason == 'SPAM') {
      return '스팸 또는 광고';
    }

    if (reason == 'HARASSMENT') {
      return '괴롭힘 또는 불쾌한 행동';
    }

    if (reason == 'UNWANTED') {
      return '원하지 않는 사용자';
    }

    return '기타';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppTopBar(title: '차단 사용자 관리'),
      body: AppMainBackground(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.pinkStart),
      );
    }

    return RefreshIndicator(
      color: context.colors.pinkStart,
      onRefresh: () => _loadBlockedUsers(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _buildNoticeCard(),
          const SizedBox(height: 20),
          _buildHeader(),
          const SizedBox(height: 12),

          if (_blockedUsers.isEmpty)
            _buildEmptyCard()
          else
            ..._blockedUsers.map((user) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildBlockedUserCard(user),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.warningSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.warningSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: context.colors.warning,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '차단한 사용자는 친구 요청을 주고받을 수 없습니다. 차단 해제 후 다시 친구를 추가할 수 있습니다.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: context.colors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            '차단한 사용자',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        Text(
          '${_blockedUsers.length}명',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.colors.pinkStart,
          ),
        ),
      ],
    );
  }

  Widget _buildBlockedUserCard(BlockedUserItem user) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          _openUserProfile(user);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
          child: Row(
            children: [
              _buildProfileImage(user),
              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nickname,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '차단 사유: ${_getReasonText(user.reason)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '차단일: ${_formatDate(user.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              OutlinedButton(
                onPressed: () {
                  _unblockUser(user);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.pinkStart,
                  side: BorderSide(color: context.colors.pinkBorder),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '차단 해제',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(BlockedUserItem user) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.pinkSoft,
      ),
      clipBehavior: Clip.antiAlias,
      child: user.profileImageUrl != null
          ? Image.network(
              user.profileImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildProfileInitial(user.nickname);
              },
            )
          : _buildProfileInitial(user.nickname),
    );
  }

  Widget _buildProfileInitial(String nickname) {
    return Center(
      child: Text(
        nickname.isEmpty ? '?' : nickname.substring(0, 1),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: context.colors.pinkStart,
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return AppCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 46,
              color: context.colors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              '차단한 사용자가 없습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '상대방 프로필의 메뉴에서\n사용자를 차단할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BlockedUserItem {
  final String uid;
  final String nickname;
  final String? profileImageUrl;
  final DateTime? createdAt;
  final String reason;

  const BlockedUserItem({
    required this.uid,
    required this.nickname,
    required this.profileImageUrl,
    required this.createdAt,
    required this.reason,
  });
}
