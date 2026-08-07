import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/user_profile_cache_service.dart';
import '../../widgets/app_dialog.dart';

import '../../theme.dart';

import '../../profile/user_profile_screen.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class FriendScreen extends StatefulWidget {
  const FriendScreen({super.key});

  @override
  State<FriendScreen> createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<FriendUserItem> _searchResults = [];
  List<FriendUserItem> _receivedRequests = [];
  List<FriendUserItem> _friends = [];

  bool _hasSearched = false;
  bool _isSearching = false;
  bool _isLoadingRelations = true;

  @override
  void initState() {
    super.initState();
    _loadFriendData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendData({bool forceRefresh = false}) async {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _receivedRequests = [];
        _friends = [];
        _isLoadingRelations = false;
      });
      return;
    }

    setState(() {
      _isLoadingRelations = true;
    });

    try {
      final QuerySnapshot<Map<String, dynamic>> receivedSnapshot =
          await FirebaseFirestore.instance
              .collection('friendRequests')
              .where('receiverUid', isEqualTo: currentUid)
              .get();

      final QuerySnapshot<Map<String, dynamic>> sentSnapshot =
          await FirebaseFirestore.instance
              .collection('friendRequests')
              .where('senderUid', isEqualTo: currentUid)
              .get();

      final List<FriendUserItem> receivedRequests = [];
      final List<FriendUserItem> friends = [];

      for (final document in receivedSnapshot.docs) {
        final Map<String, dynamic> data = document.data();
        final String status = (data['status'] as String? ?? '')
            .trim()
            .toUpperCase();
        final String senderUid = (data['senderUid'] as String? ?? '').trim();

        if (senderUid.isEmpty) {
          continue;
        }

        if (status == 'PENDING') {
          final FriendUserItem? user = await _loadUserItem(
            userUid: senderUid,
            relationId: document.id,
            forceRefresh: forceRefresh,
          );
          if (user != null) {
            receivedRequests.add(user);
          }
        }

        if (status == 'ACCEPTED') {
          final FriendUserItem? user = await _loadUserItem(
            userUid: senderUid,
            relationId: document.id,
            forceRefresh: forceRefresh,
          );
          if (user != null) {
            friends.add(user);
          }
        }
      }

      for (final document in sentSnapshot.docs) {
        final Map<String, dynamic> data = document.data();
        final String status = (data['status'] as String? ?? '')
            .trim()
            .toUpperCase();
        final String receiverUid = (data['receiverUid'] as String? ?? '')
            .trim();

        if (receiverUid.isEmpty || status != 'ACCEPTED') {
          continue;
        }

        if (friends.any((friend) => friend.uid == receiverUid)) {
          continue;
        }

        final FriendUserItem? user = await _loadUserItem(
          userUid: receiverUid,
          relationId: document.id,
          forceRefresh: forceRefresh,
        );
        if (user != null) {
          friends.add(user);
        }
      }

      receivedRequests.sort(
        (first, second) => first.nickname.compareTo(second.nickname),
      );
      friends.sort(
        (first, second) => first.nickname.compareTo(second.nickname),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _receivedRequests = receivedRequests;
        _friends = friends;
        _isLoadingRelations = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _receivedRequests = [];
        _friends = [];
        _isLoadingRelations = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('친구 정보를 불러오지 못했습니다.')));
    }
  }

  Future<FriendUserItem?> _loadUserItem({
    required String userUid,
    required String relationId,
    bool forceRefresh = false,
  }) async {
    final profile = await UserProfileCacheService.instance.getProfile(
      userUid,
      forceRefresh: forceRefresh,
    );
    if (profile == null || profile.isDeleted) {
      return null;
    }

    final String nickname = profile.nickname.trim();
    if (nickname.isEmpty) {
      return null;
    }

    final String bio = profile.introduction.trim();
    final String savedProfileImageUrl = profile.profileImageUrl.trim();
    final String targetCertificate = await _loadMainGoalCertificate(userUid);

    return FriendUserItem(
      uid: userUid,
      nickname: nickname,
      bio: bio,
      targetCertificate: targetCertificate,
      profileImageUrl: savedProfileImageUrl.isNotEmpty
          ? savedProfileImageUrl
          : null,
      relationId: relationId,
    );
  }

  Future<void> _searchUsers() async {
    final String keyword = _searchController.text.trim();
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    FocusManager.instance.primaryFocus?.unfocus();

    if (keyword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('검색할 닉네임을 입력해주세요.')));
      return;
    }

    if (currentUid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchResults = [];
    });

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection('users').get();

      final List<FriendUserItem> results = [];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in snapshot.docs) {
        if (document.id == currentUid) {
          continue;
        }

        final Map<String, dynamic> data = document.data();

        final String nickname = (data['nickname'] as String? ?? '').trim();

        if (nickname.isEmpty) {
          continue;
        }

        if (!nickname.toLowerCase().contains(keyword.toLowerCase())) {
          continue;
        }

        // 상대방이 현재 사용자를 차단했다면 검색 결과에 노출하지 않습니다.
        final DocumentSnapshot<Map<String, dynamic>> blockedByOtherDocument =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(document.id)
                .collection('blockedUsers')
                .doc(currentUid)
                .get();

        if (blockedByOtherDocument.exists) {
          continue;
        }

        final String bio = (data['bio'] as String? ?? '').trim();

        final String? profileImageUrl = (data['profileImageUrl'] as String?)
            ?.trim();

        final String targetCertificate = await _loadMainGoalCertificate(
          document.id,
        );

        results.add(
          FriendUserItem(
            uid: document.id,
            nickname: nickname,
            bio: bio,
            targetCertificate: targetCertificate,
            profileImageUrl:
                profileImageUrl != null && profileImageUrl.isNotEmpty
                ? profileImageUrl
                : null,
            relationId: null,
          ),
        );
      }

      results.sort(
        (first, second) => first.nickname.compareTo(second.nickname),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSearching = false;
        _searchResults = [];
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('사용자를 검색하지 못했습니다.')));
    }
  }

  Future<String> _loadMainGoalCertificate(String userUid) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userUid)
              .collection('goals')
              .where('isMainGoal', isEqualTo: true)
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        return '등록된 목표 없음';
      }

      final String certificateName =
          (snapshot.docs.first.data()['certificateName'] as String? ?? '')
              .trim();

      if (certificateName.isEmpty) {
        return '등록된 목표 없음';
      }

      return certificateName;
    } catch (error) {
      return '등록된 목표 없음';
    }
  }

  void _clearSearch() {
    _searchController.clear();

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _hasSearched = false;
      _isSearching = false;
      _searchResults = [];
    });
  }

  Future<bool> _hasBlockRelation(String otherUid) async {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null || currentUid == otherUid) {
      return false;
    }

    final DocumentSnapshot<Map<String, dynamic>> blockedByMeDocument =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .collection('blockedUsers')
            .doc(otherUid)
            .get();

    final DocumentSnapshot<Map<String, dynamic>> blockedByOtherDocument =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUid)
            .collection('blockedUsers')
            .doc(currentUid)
            .get();

    return blockedByMeDocument.exists || blockedByOtherDocument.exists;
  }

  Future<void> _acceptFriendRequest(FriendUserItem user) async {
    final String? relationId = user.relationId;
    if (relationId == null) {
      return;
    }

    try {
      // 수락 버튼을 누른 시점에 차단 관계가 생겼을 수도 있으므로
      // 친구 관계로 변경하기 직전에 다시 확인합니다.
      final bool hasBlockRelation = await _hasBlockRelation(user.uid);

      if (hasBlockRelation) {
        await FirebaseFirestore.instance
            .collection('friendRequests')
            .doc(relationId)
            .delete();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('차단 관계에 있는 사용자의 친구 요청은 수락할 수 없습니다.')),
        );

        await _loadFriendData();
        return;
      }

      await FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(relationId)
          .update({
            'status': 'ACCEPTED',
            'acceptedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${user.nickname}님과 친구가 되었습니다.')));
      await _loadFriendData();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('친구 요청을 수락하지 못했습니다.')));
    }
  }

  Future<void> _rejectFriendRequest(FriendUserItem user) async {
    final String? relationId = user.relationId;
    if (relationId == null) {
      return;
    }

    final bool? shouldReject = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppAlertDialog(
          title: Text(
            '친구 요청 거절',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text('${user.nickname}님의 친구 요청을 거절하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                '취소',
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                '거절',
                style: TextStyle(
                  color: context.colors.incorrect,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldReject != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(relationId)
          .delete();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('친구 요청을 거절했습니다.')));
      await _loadFriendData();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('친구 요청을 거절하지 못했습니다.')));
    }
  }

  Future<void> _showDeleteFriendDialog(FriendUserItem friend) async {
    final String? relationId = friend.relationId;
    if (relationId == null) {
      return;
    }

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppAlertDialog(
          title: Text('친구 삭제', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text('${friend.nickname}님을 친구 목록에서 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                '취소',
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                '삭제',
                style: TextStyle(
                  color: context.colors.incorrect,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(relationId)
          .delete();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${friend.nickname}님을 친구 목록에서 삭제했습니다.')),
      );
      await _loadFriendData();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('친구를 삭제하지 못했습니다.')));
    }
  }

  Future<void> _openUserProfile(FriendUserItem user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userUid: user.uid)),
    );

    await _loadFriendData(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(title: '친구'),
      body: AppMainBackground(
        child: RefreshIndicator(
          color: context.colors.pinkStart,
          onRefresh: () => _loadFriendData(forceRefresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              _buildSearchCard(),
              SizedBox(height: 22),

              if (_hasSearched) ...[
                _buildSearchResultSection(),
                SizedBox(height: 26),
              ],

              if (_isLoadingRelations)
                AppCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: context.colors.pinkStart,
                      ),
                    ),
                  ),
                )
              else ...[
                if (_receivedRequests.isNotEmpty) ...[
                  _buildReceivedRequestHeader(),
                  SizedBox(height: 12),
                  ..._receivedRequests.map(
                    (requestUser) => Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _buildReceivedRequestCard(requestUser),
                    ),
                  ),
                  SizedBox(height: 14),
                ],
                _buildFriendHeader(),
                SizedBox(height: 12),
                if (_friends.isEmpty)
                  _buildEmptyFriendCard()
                else
                  ..._friends.map(
                    (friend) => Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _buildFriendCard(friend),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_search_outlined,
                color: context.colors.pinkStart,
              ),
              SizedBox(width: 8),
              Text(
                '친구 찾기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '사용자 닉네임을 검색하고 프로필을 확인할 수 있습니다.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: context.colors.textSecondary,
            ),
          ),
          SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    _searchUsers();
                  },
                  onTapOutside: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: '닉네임을 입력해주세요.',
                    prefixIcon: Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '검색어 지우기',
                            onPressed: _clearSearch,
                            icon: Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: context.colors.surfaceMuted,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: context.colors.pinkStart,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSearching ? null : _searchUsers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.pinkStart,
                    foregroundColor: context.colors.onPrimary,
                    disabledBackgroundColor: context.colors.pinkSoft,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _isSearching ? '검색 중' : '검색',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '검색 결과',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            Text(
              '${_searchResults.length}명',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.pinkStart,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),

        if (_isSearching)
          AppCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  color: context.colors.pinkStart,
                ),
              ),
            ),
          )
        else if (_searchResults.isEmpty)
          _buildEmptySearchCard()
        else
          ..._searchResults.map((user) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _buildSearchResultCard(user),
            );
          }),
      ],
    );
  }

  Widget _buildSearchResultCard(FriendUserItem user) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          _openUserProfile(user);
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 15, 12, 15),
          child: Row(
            children: [
              _buildProfileImage(user),
              SizedBox(width: 13),

              Expanded(child: _buildUserInformation(user)),

              SizedBox(width: 8),

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

  Widget _buildProfileImage(FriendUserItem user) {
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

  Widget _buildUserInformation(FriendUserItem user) {
    return Column(
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
        SizedBox(height: 4),

        Row(
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              size: 15,
              color: context.colors.pinkStart,
            ),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                user.targetCertificate,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),

        if (user.bio.isNotEmpty) ...[
          SizedBox(height: 4),
          Text(
            user.bio,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _buildReceivedRequestHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            '받은 친구 요청',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        Text(
          '${_receivedRequests.length}명',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.pinkStart,
          ),
        ),
      ],
    );
  }

  Widget _buildReceivedRequestCard(FriendUserItem user) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 15, 12, 15),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _openUserProfile(user),
              child: _buildProfileImage(user),
            ),
            SizedBox(width: 13),
            Expanded(
              child: GestureDetector(
                onTap: () => _openUserProfile(user),
                behavior: HitTestBehavior.opaque,
                child: _buildUserInformation(user),
              ),
            ),
            SizedBox(width: 8),
            Column(
              children: [
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => _acceptFriendRequest(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.pinkStart,
                      foregroundColor: context.colors.onPrimary,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: Text(
                      '수락',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: TextButton(
                    onPressed: () => _rejectFriendRequest(user),
                    child: Text(
                      '거절',
                      style: TextStyle(color: context.colors.textSecondary),
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

  Widget _buildFriendHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            '친구 목록',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        Text(
          '${_friends.length}명',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.pinkStart,
          ),
        ),
      ],
    );
  }

  Widget _buildFriendCard(FriendUserItem friend) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openUserProfile(friend),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 15, 7, 15),
          child: Row(
            children: [
              _buildProfileImage(friend),
              SizedBox(width: 13),
              Expanded(child: _buildUserInformation(friend)),
              PopupMenuButton<String>(
                tooltip: '친구 메뉴',
                color: context.colors.surface,
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: context.colors.textSecondary,
                ),
                onSelected: (value) {
                  if (value == 'profile') {
                    _openUserProfile(friend);
                  }
                  if (value == 'delete') {
                    _showDeleteFriendDialog(friend);
                  }
                },
                itemBuilder: (context) {
                  return [
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 20,
                            color: context.colors.textSecondary,
                          ),
                          SizedBox(width: 10),
                          Text('프로필 보기'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_remove_outlined,
                            size: 20,
                            color: context.colors.incorrect,
                          ),
                          SizedBox(width: 10),
                          Text('친구 삭제'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearchCard() {
    return AppCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 26),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 42,
              color: context.colors.textMuted,
            ),
            SizedBox(height: 10),
            Text(
              '검색 결과가 없습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: 5),
            Text(
              '닉네임을 다시 확인해주세요.',
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFriendCard() {
    return AppCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Icon(
              Icons.group_add_outlined,
              size: 44,
              color: context.colors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              '추가된 친구가 없습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '검색 결과에서 프로필을 확인한 후\n친구 요청을 보낼 수 있습니다.',
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

class FriendUserItem {
  final String uid;
  final String nickname;
  final String bio;
  final String targetCertificate;
  final String? profileImageUrl;
  final String? relationId;

  FriendUserItem({
    required this.uid,
    required this.nickname,
    required this.bio,
    required this.targetCertificate,
    required this.profileImageUrl,
    required this.relationId,
  });
}
