import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class FriendScreen extends StatefulWidget {
  const FriendScreen({super.key});

  @override
  State<FriendScreen> createState() =>
      _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  // Firebase 연결 전 검색 가능한 임시 사용자 데이터
  final List<FriendUserItem> _allUsers = [
    const FriendUserItem(
      uid: 'user_001',
      nickname: '합격가자',
      targetCertificate: '정보처리기사',
      introduction: '정보처리기사 실기를 공부하고 있어요.',
    ),
    const FriendUserItem(
      uid: 'user_002',
      nickname: '데이터초보',
      targetCertificate: 'SQLD',
      introduction: 'SQL과 데이터베이스를 공부 중입니다.',
    ),
    const FriendUserItem(
      uid: 'user_003',
      nickname: '공부하는직장인',
      targetCertificate: '컴퓨터활용능력 1급',
      introduction: '퇴근 후 자격증 공부를 하고 있어요.',
    ),
    const FriendUserItem(
      uid: 'user_004',
      nickname: '실기한번에',
      targetCertificate: '정보처리기사',
      introduction: '기출문제를 중심으로 공부하고 있습니다.',
    ),
    const FriendUserItem(
      uid: 'user_005',
      nickname: '자격증마스터',
      targetCertificate: '한국사능력검정시험',
      introduction: '함께 꾸준히 공부해요.',
    ),
  ];

  // Firebase 연결 전 임시 친구 목록
  final List<FriendUserItem> _friends = [
    const FriendUserItem(
      uid: 'user_002',
      nickname: '데이터초보',
      targetCertificate: 'SQLD',
      introduction: 'SQL과 데이터베이스를 공부 중입니다.',
    ),
    const FriendUserItem(
      uid: 'user_003',
      nickname: '공부하는직장인',
      targetCertificate: '컴퓨터활용능력 1급',
      introduction: '퇴근 후 자격증 공부를 하고 있어요.',
    ),
  ];

  List<FriendUserItem> _searchResults = [];

  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '친구',
      ),
      body: AppMainBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            40,
          ),
          children: [
            _buildSearchCard(),
            const SizedBox(height: 22),

            if (_hasSearched) ...[
              _buildSearchResultSection(),
              const SizedBox(height: 26),
            ],

            _buildFriendHeader(),
            const SizedBox(height: 12),

            if (_friends.isEmpty)
              _buildEmptyFriendCard()
            else
              ..._friends.map(
                    (friend) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: _buildFriendCard(friend),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.person_search_outlined,
                color: Color(0xFFF0788F),
              ),
              SizedBox(width: 8),
              Text(
                '친구 찾기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '사용자 닉네임을 검색해 친구를 추가할 수 있습니다.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF9AA0AC),
            ),
          ),
          const SizedBox(height: 16),

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
                    FocusManager.instance.primaryFocus
                        ?.unfocus();
                  },
                  decoration: InputDecoration(
                    hintText: '닉네임을 입력해주세요.',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                    ),
                    suffixIcon:
                    _searchController.text.isEmpty
                        ? null
                        : IconButton(
                      tooltip: '검색어 지우기',
                      onPressed: _clearSearch,
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F6F7),
                    contentPadding:
                    const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFF0788F),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 10),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _searchUsers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    const Color(0xFFF0788F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '검색',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
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
            const Expanded(
              child: Text(
                '검색 결과',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            Text(
              '${_searchResults.length}명',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF0788F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_searchResults.isEmpty)
          _buildEmptySearchCard()
        else
          ..._searchResults.map(
                (user) {
              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: _buildSearchResultCard(user),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSearchResultCard(
      FriendUserItem user,
      ) {
    final bool isFriend = _isFriend(user.uid);

    return AppCard(
      child: Row(
        children: [
          _buildProfileImage(
            nickname: user.nickname,
          ),
          const SizedBox(width: 13),

          Expanded(
            child: _buildUserInformation(user),
          ),

          const SizedBox(width: 10),

          SizedBox(
            height: 38,
            child: isFriend
                ? OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                disabledForegroundColor:
                const Color(0xFF9AA0AC),
                side: const BorderSide(
                  color: Color(0xFFD9D9DF),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
              ),
              child: const Text('친구'),
            )
                : ElevatedButton(
              onPressed: () {
                _addFriend(user);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xFFF0788F),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '추가',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '친구 목록',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        Text(
          '${_friends.length}명',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF0788F),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendCard(
      FriendUserItem friend,
      ) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          _openFriendProfile(friend);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            15,
            7,
            15,
          ),
          child: Row(
            children: [
              _buildProfileImage(
                nickname: friend.nickname,
              ),
              const SizedBox(width: 13),

              Expanded(
                child: _buildUserInformation(friend),
              ),

              PopupMenuButton<String>(
                tooltip: '친구 메뉴',
                color: Colors.white,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF9AA0AC),
                ),
                onSelected: (value) {
                  if (value == 'profile') {
                    _openFriendProfile(friend);
                  }

                  if (value == 'delete') {
                    _showDeleteFriendDialog(friend);
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 20,
                            color: Color(0xFF666A73),
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
                            color: Colors.redAccent,
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

  Widget _buildProfileImage({
    required String nickname,
  }) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFCE1E8),
      ),
      alignment: Alignment.center,
      child: Text(
        nickname.isEmpty
            ? '?'
            : nickname.substring(0, 1),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFFF0788F),
        ),
      ),
    );
  }

  Widget _buildUserInformation(
      FriendUserItem user,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.nickname,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 4),

        Row(
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              size: 15,
              color: Color(0xFFF0788F),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                user.targetCertificate,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666A73),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        Text(
          user.introduction,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9AA0AC),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySearchCard() {
    return AppCard(
      child: const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 26,
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 42,
              color: Color(0xFFB4B8C2),
            ),
            SizedBox(height: 10),
            Text(
              '검색 결과가 없습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 5),
            Text(
              '닉네임을 다시 확인해주세요.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9AA0AC),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFriendCard() {
    return AppCard(
      child: const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 30,
        ),
        child: Column(
          children: [
            Icon(
              Icons.group_add_outlined,
              size: 44,
              color: Color(0xFFB4B8C2),
            ),
            SizedBox(height: 12),
            Text(
              '추가된 친구가 없습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 6),
            Text(
              '닉네임을 검색해서\n함께 공부할 친구를 추가해보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF9AA0AC),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _searchUsers() {
    final String keyword =
    _searchController.text.trim();

    FocusManager.instance.primaryFocus?.unfocus();

    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '검색할 닉네임을 입력해주세요.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _hasSearched = true;

      _searchResults = _allUsers.where(
            (user) {
          return user.nickname
              .toLowerCase()
              .contains(keyword.toLowerCase());
        },
      ).toList();
    });
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _hasSearched = false;
      _searchResults = [];
    });
  }

  bool _isFriend(String uid) {
    return _friends.any(
          (friend) => friend.uid == uid,
    );
  }

  void _addFriend(
      FriendUserItem user,
      ) {
    if (_isFriend(user.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '이미 추가된 친구입니다.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _friends.add(user);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${user.nickname}님을 친구로 추가했습니다.',
        ),
      ),
    );
  }

  Future<void> _showDeleteFriendDialog(
      FriendUserItem friend,
      ) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '친구 삭제',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '${friend.nickname}님을 친구 목록에서 삭제하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF9AA0AC),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != true) {
      return;
    }

    setState(() {
      _friends.removeWhere(
            (item) => item.uid == friend.uid,
      );
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${friend.nickname}님을 친구 목록에서 삭제했습니다.',
        ),
      ),
    );
  }

  void _openFriendProfile(
      FriendUserItem friend,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return TemporaryFriendProfileScreen(
            friend: friend,
          );
        },
      ),
    );
  }
}

class FriendUserItem {
  final String uid;
  final String nickname;
  final String targetCertificate;
  final String introduction;

  const FriendUserItem({
    required this.uid,
    required this.nickname,
    required this.targetCertificate,
    required this.introduction,
  });
}

class TemporaryFriendProfileScreen
    extends StatelessWidget {
  final FriendUserItem friend;

  const TemporaryFriendProfileScreen({
    super.key,
    required this.friend,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '친구 프로필',
      ),
      body: AppMainBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            40,
          ),
          child: AppCard(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFCE1E8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    friend.nickname.isEmpty
                        ? '?'
                        : friend.nickname.substring(
                      0,
                      1,
                    ),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF0788F),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  friend.nickname,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCEFF3),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: Text(
                    friend.targetCertificate,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF0788F),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '자기소개',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6F7),
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                  child: Text(
                    friend.introduction,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF666A73),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  '실제 사용자 프로필 화면이 완성되면\n해당 화면으로 교체할 예정입니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF9AA0AC),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}