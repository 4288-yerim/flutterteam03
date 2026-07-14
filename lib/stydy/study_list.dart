import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'study_add.dart';
import 'study_detail.dart';

/// 스터디 목록 페이지만 단독 실행
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 단독 실행 확인용 익명 로그인
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  runApp(const StudyListApp());
}

class StudyListApp extends StatelessWidget {
  const StudyListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StudyListPage(
        showBottomBar: true,
      ),
    );
  }
}

class StudyListPage extends StatefulWidget {
  // 단독 실행할 때 하단 메뉴 표시
  final bool showBottomBar;

  const StudyListPage({
    super.key,
    this.showBottomBar = false,
  });

  @override
  State<StudyListPage> createState() => _StudyListPageState();
}

class _StudyListPageState extends State<StudyListPage> {
  final TextEditingController _searchController =
  TextEditingController();

  int currentIndex = 1;

  String _selectedMenu = '전체';
  String _searchText = '';

  final List<String> _menuList = [
    '전체',
    '모집 중',
    '내 스터디',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Firestore 숫자 필드 가져오기
  int _getInt(
      Map<String, dynamic> data,
      String fieldName,
      ) {
    final value = data[fieldName];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  /// 현재 모집 중인지 확인
  bool _isRecruiting(Map<String, dynamic> data) {
    final status =
        data['status']?.toString() ?? 'RECRUITING';

    final currentMemberCount =
    _getInt(data, 'currentMemberCount');

    final maxMemberCount =
    _getInt(data, 'maxMemberCount');

    if (status == 'CLOSED' || status == 'COMPLETED') {
      return false;
    }

    if (maxMemberCount > 0 &&
        currentMemberCount >= maxMemberCount) {
      return false;
    }

    return true;
  }

  /// 검색어와 선택 메뉴에 맞는 스터디인지 확인
  bool _isVisibleStudy(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    final groupName =
        data['groupName']?.toString().toLowerCase() ?? '';

    final description =
        data['description']?.toString().toLowerCase() ?? '';

    final certificateName =
        data['certificateName']?.toString().toLowerCase() ?? '';

    final searchText = _searchText.toLowerCase();

    final matchesSearch =
        groupName.contains(searchText) ||
            description.contains(searchText) ||
            certificateName.contains(searchText);

    if (!matchesSearch) {
      return false;
    }

    if (_selectedMenu == '모집 중') {
      return _isRecruiting(data);
    }

    if (_selectedMenu == '내 스터디') {
      final currentUserUid =
          FirebaseAuth.instance.currentUser?.uid;

      return data['ownerUid'] == currentUserUid;
    }

    return true;
  }

  /// 스터디 만들기 페이지로 이동
  Future<void> _openCreatePage() async {
    // 검색 키보드가 열려 있으면 먼저 닫기
    FocusScope.of(context).unfocus();

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const StudyCreatePage(),
      ),
    );

    // snapshots()가 실시간으로 목록을 갱신하므로
    // 별도의 새로고침은 필요 없음
  }

  /// 스터디 상세 페이지로 이동
  void _openStudyDetail(
      String studyId,
      Map<String, dynamic> studyData,
      ) {
    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudyDetailPage(
          studyId: studyId,
          studyData: studyData,
        ),
      ),
    );
  }

  /// 검색창 위 안내 배너
  Widget _buildStudyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE8E1FF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.groups_rounded,
              size: 29,
              color: Color(0xFF8068D8),
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '함께 공부할 스터디를 찾아보세요',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF302D39),
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  '관심 있는 자격증 스터디에 참여하거나\n'
                      '새로운 스터디를 직접 만들 수 있어요.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Color(0xFF777383),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 전체 / 모집 중 / 내 스터디 메뉴
  Widget _buildMenuChip(String menu) {
    final isSelected = _selectedMenu == menu;

    return ChoiceChip(
      label: Text(menu),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: const Color(0xFFE7E1FF),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF8068D8)
            : const Color(0xFFE1E3E8),
      ),
      labelStyle: TextStyle(
        color: isSelected
            ? const Color(0xFF6C54C8)
            : const Color(0xFF777C86),
        fontWeight: isSelected
            ? FontWeight.bold
            : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 9,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
      ),
      onSelected: (_) {
        setState(() {
          _selectedMenu = menu;
        });
      },
    );
  }

  /// 카드 위 작은 표시
  Widget _smallBadge(
      String text,
      Color backgroundColor,
      Color textColor,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 키보드가 열려 있는지 확인
    final bool isKeyboardOpen =
        MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      // 키보드가 열리면 본문 높이를 자동 조절
      resizeToAvoidBottomInset: true,

      // 키보드가 열려 있을 때는 하단 메뉴가 없으므로
      // 본문을 하단 메뉴 뒤까지 확장하지 않음
      extendBody: !isKeyboardOpen,

      appBar: AppTopBar(
        title: '스터디',
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '스터디 만들기',
            onPressed: _openCreatePage,
            icon: const Icon(
              Icons.add_rounded,
              size: 30,
            ),
          ),
        ],
      ),

      body: AppMainBackground(
        applySafeArea: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,

            // 키보드가 열리면 위쪽 간격 축소
            isKeyboardOpen ? 10 : 18,

            20,

            // 키보드가 열리면 하단 메뉴 여백 제거
            isKeyboardOpen
                ? 12
                : widget.showBottomBar
                ? 100
                : 25,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 키보드가 닫혀 있을 때만 안내 배너 표시
              if (!isKeyboardOpen) ...[
                _buildStudyBanner(),
                const SizedBox(height: 16),
              ],

              // 검색창
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  setState(() {
                    _searchText = value.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: '스터디 이름이나 자격증을 검색하세요',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF989AA2),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF66636E),
                  ),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                    onPressed: () {
                      _searchController.clear();

                      setState(() {
                        _searchText = '';
                      });
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                    ),
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(
                      color: Color(0xFFE8E7EB),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(
                      color: Color(0xFF8068D8),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              SizedBox(
                height: isKeyboardOpen ? 8 : 14,
              ),

              // 전체 / 모집 중 / 내 스터디
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _menuList
                      .map(
                        (menu) => Padding(
                      padding: const EdgeInsets.only(
                        right: 8,
                      ),
                      child: _buildMenuChip(menu),
                    ),
                  )
                      .toList(),
                ),
              ),

              SizedBox(
                height: isKeyboardOpen ? 8 : 18,
              ),

              Expanded(
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studyGroups')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      debugPrint(
                        'Firestore 오류: ${snapshot.error}',
                      );

                      return const Center(
                        child: Text(
                          '스터디 목록을 불러오지 못했습니다.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final allStudyList =
                        snapshot.data?.docs.toList() ?? [];

                    // 최근 등록한 스터디가 위로 오도록 정렬
                    allStudyList.sort((a, b) {
                      final aCreatedAt =
                      a.data()['createdAt'];

                      final bCreatedAt =
                      b.data()['createdAt'];

                      final aTime = aCreatedAt is Timestamp
                          ? aCreatedAt.millisecondsSinceEpoch
                          : 0;

                      final bTime = bCreatedAt is Timestamp
                          ? bCreatedAt.millisecondsSinceEpoch
                          : 0;

                      return bTime.compareTo(aTime);
                    });

                    final visibleStudyList = allStudyList
                        .where(_isVisibleStudy)
                        .toList();

                    if (visibleStudyList.isEmpty) {
                      return Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 78,
                                height: 78,
                                decoration:
                                const BoxDecoration(
                                  color: Color(0xFFF0ECFF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.groups_outlined,
                                  size: 38,
                                  color: Color(0xFF8068D8),
                                ),
                              ),

                              const SizedBox(height: 18),

                              Text(
                                _selectedMenu == '내 스터디'
                                    ? '내가 만든 스터디가 없습니다.'
                                    : _searchText.isNotEmpty
                                    ? '검색 결과가 없습니다.'
                                    : '등록된 스터디가 없습니다.',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 8),

                              const Text(
                                '새로운 스터디를 직접 만들어보세요.',
                                style: TextStyle(
                                  color: Color(0xFF858994),
                                ),
                              ),

                              const SizedBox(height: 20),

                              ElevatedButton.icon(
                                onPressed: _openCreatePage,
                                icon: const Icon(Icons.add),
                                label: const Text(
                                  '스터디 만들기',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  const Color(0xFF8068D8),
                                  foregroundColor: Colors.white,
                                  padding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          '총 ${visibleStudyList.length}개의 스터디',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF777C86),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Expanded(
                          child: ListView.builder(
                            keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior
                                .onDrag,
                            padding: EdgeInsets.zero,
                            itemCount:
                            visibleStudyList.length,
                            itemBuilder: (context, index) {
                              final studyDocument =
                              visibleStudyList[index];

                              final studyData =
                              studyDocument.data();

                              final groupName =
                                  studyData['groupName']
                                      ?.toString() ??
                                      '그룹명 없음';

                              final description =
                                  studyData['description']
                                      ?.toString() ??
                                      '';

                              final certificateName =
                                  studyData[
                                  'certificateName']
                                      ?.toString() ??
                                      '공통 스터디';

                              final currentMemberCount =
                              _getInt(
                                studyData,
                                'currentMemberCount',
                              );

                              final maxMemberCount = _getInt(
                                studyData,
                                'maxMemberCount',
                              );

                              final isPublic =
                              studyData['isPublic'] is bool
                                  ? studyData['isPublic']
                              as bool
                                  : true;

                              final isRecruiting =
                              _isRecruiting(studyData);

                              final double progress =
                              maxMemberCount > 0
                                  ? currentMemberCount /
                                  maxMemberCount
                                  : 0.0;

                              return Padding(
                                padding:
                                const EdgeInsets.only(
                                  bottom: 15,
                                ),
                                child: AppCard(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 7,
                                        runSpacing: 7,
                                        children: [
                                          _smallBadge(
                                            certificateName,
                                            const Color(
                                              0xFFE9E4FF,
                                            ),
                                            const Color(
                                              0xFF6F58C9,
                                            ),
                                          ),

                                          _smallBadge(
                                            isRecruiting
                                                ? '모집 중'
                                                : '모집 완료',
                                            isRecruiting
                                                ? const Color(
                                              0xFFDFF5EA,
                                            )
                                                : const Color(
                                              0xFFF1F2F5,
                                            ),
                                            isRecruiting
                                                ? const Color(
                                              0xFF3F9C72,
                                            )
                                                : const Color(
                                              0xFF858994,
                                            ),
                                          ),

                                          _smallBadge(
                                            isPublic
                                                ? '공개'
                                                : '비공개',
                                            const Color(
                                              0xFFF3F4F7,
                                            ),
                                            const Color(
                                              0xFF737782,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 15),

                                      Text(
                                        groupName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight:
                                          FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      Text(
                                        description.isEmpty
                                            ? '등록된 스터디 소개가 없습니다.'
                                            : description,
                                        maxLines: 2,
                                        overflow:
                                        TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                          color: Color(
                                            0xFF7B7F89,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 17),

                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.groups_outlined,
                                            size: 18,
                                            color: Color(
                                              0xFF8C919C,
                                            ),
                                          ),

                                          const SizedBox(width: 6),

                                          Text(
                                            '$currentMemberCount / '
                                                '$maxMemberCount명',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(
                                                0xFF737782,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 9),

                                      ClipRRect(
                                        borderRadius:
                                        BorderRadius.circular(
                                          10,
                                        ),
                                        child:
                                        LinearProgressIndicator(
                                          value: progress
                                              .clamp(
                                            0.0,
                                            1.0,
                                          )
                                              .toDouble(),
                                          minHeight: 6,
                                          backgroundColor:
                                          const Color(
                                            0xFFECEEF2,
                                          ),
                                          valueColor:
                                          const AlwaysStoppedAnimation<
                                              Color>(
                                            Color(0xFF8068D8),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      SizedBox(
                                        width: double.infinity,
                                        height: 46,
                                        child:
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            _openStudyDetail(
                                              studyDocument.id,
                                              studyData,
                                            );
                                          },
                                          icon: const Icon(
                                            Icons
                                                .arrow_forward_rounded,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            '상세 보기',
                                            style: TextStyle(
                                              fontWeight:
                                              FontWeight.w600,
                                            ),
                                          ),
                                          style: OutlinedButton
                                              .styleFrom(
                                            foregroundColor:
                                            const Color(
                                              0xFF6C54C8,
                                            ),
                                            side: const BorderSide(
                                              color: Color(
                                                0xFF8B8792,
                                              ),
                                            ),
                                            shape:
                                            RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius
                                                  .circular(16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // 키보드가 닫혀 있을 때만 하단 메뉴 표시
      bottomNavigationBar:
      widget.showBottomBar && !isKeyboardOpen
          ? AppBottomBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
      )
          : null,
    );
  }
}