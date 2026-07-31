import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutterteam03/widgets/app_state_views.dart';

import '../firebase_options.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import 'study_add.dart';
import 'study_detail.dart';
import 'study_join_requests.dart';
import 'study_room.dart';

/// 스터디 목록 페이지만 단독 실행할 때 사용
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: StudyListApp(),
    ),
  );
}

/// main_page.dart에서 사용하는 스터디 화면

Brightness get _studyBrightness {
  return WidgetsBinding.instance.platformDispatcher.platformBrightness;
}

AppColors get _studyColors {
  if (_studyBrightness == Brightness.dark) {
    return AppColors.dark;
  }

  return AppColors.light;
}

ColorScheme get _studyColorScheme {
  if (_studyBrightness == Brightness.dark) {
    return darkTheme.colorScheme;
  }

  return lightTheme.colorScheme;
}

class StudyListApp extends StatelessWidget {
  const StudyListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StudyListPage();
  }
}

class StudyListPage extends StatefulWidget {
  // 기존 다른 파일과 연결이 끊기지 않도록 유지
  final bool showBottomBar;

  const StudyListPage({
    super.key,
    this.showBottomBar = false,
  });

  @override
  State<StudyListPage> createState() {
    return _StudyListPageState();
  }
}

class _StudyListPageState extends State<StudyListPage> {
  final TextEditingController _searchController = TextEditingController();

  // 검색어를 입력할 때마다 새로운 Firestore Stream이 생성되면
  // StreamBuilder가 다시 로딩 상태가 되면서 검색창이 사라지고
  // 키보드 포커스가 끊길 수 있다.
  // 같은 Stream을 계속 사용하도록 변수에 한 번만 저장한다.
  Stream<QuerySnapshot<Map<String, dynamic>>>? _studyGroupStream;

  String _selectedTab = '내 스터디';
  String _selectedFindFilter = '전체';
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getStudyGroupStream() {
    if (_studyGroupStream == null) {
      _studyGroupStream = FirebaseFirestore.instance
          .collection('studyGroups')
          .snapshots();
    }

    return _studyGroupStream!;
  }

  int _getInt(
      Map<String, dynamic> data,
      String fieldName,
      ) {
    dynamic value = data[fieldName];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  bool _isRecruiting(Map<String, dynamic> data) {
    String recruitmentStatus =
        data['recruitmentStatus']?.toString() ?? '';

    String groupStatus = data['status']?.toString() ?? '';

    int currentMemberCount = _getInt(
      data,
      'currentMemberCount',
    );

    int maxMemberCount = _getInt(
      data,
      'maxMemberCount',
    );

    if (groupStatus == 'COMPLETED') {
      return false;
    }

    if (recruitmentStatus == 'CLOSED') {
      return false;
    }

    if (recruitmentStatus.isEmpty && groupStatus == 'CLOSED') {
      return false;
    }

    if (maxMemberCount > 0 &&
        currentMemberCount >= maxMemberCount) {
      return false;
    }

    return true;
  }

  bool _isNetworkError(Object? error) {
    if (error is FirebaseException) {
      if (error.code == 'unavailable') {
        return true;
      }

      if (error.code == 'network-request-failed') {
        return true;
      }
    }

    return false;
  }

  void _reloadStudyList() {
    setState(() {});
  }

  Future<void> _refreshStudyList() async {
    setState(() {
      _studyGroupStream = null;
    });

    await Future<void>.delayed(
      Duration(milliseconds: 300),
    );
  }

  Future<void> _openCreatePage() async {
    FocusScope.of(context).unfocus();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return StudyCreatePage();
        },
      ),
    );
  }

  void _openStudyDetail(
      String studyId,
      Map<String, dynamic> studyData,
      ) {
    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return StudyDetailPage(
            studyId: studyId,
            studyData: studyData,
          );
        },
      ),
    );
  }

  void _openStudyRoom(
      String studyId,
      String groupName,
      ) {
    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return StudyRoomPage(
            studyId: studyId,
            groupName: groupName,
          );
        },
      ),
    );
  }

  void _openJoinRequests(String studyId) {
    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return StudyJoinRequestsPage(
            studyId: studyId,
          );
        },
      ),
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _loadMyStudyList(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> allStudyList,
      ) async {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> myStudyList = [];

    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return myStudyList;
    }

    for (int i = 0; i < allStudyList.length; i++) {
      QueryDocumentSnapshot<Map<String, dynamic>> studyDocument =
      allStudyList[i];

      Map<String, dynamic> studyData = studyDocument.data();

      String ownerUid = studyData['ownerUid']?.toString() ?? '';

      if (ownerUid == currentUser.uid) {
        myStudyList.add(studyDocument);
        continue;
      }

      DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
      await FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyDocument.id)
          .collection('members')
          .doc(currentUser.uid)
          .get();

      if (memberSnapshot.exists) {
        Map<String, dynamic> memberData = memberSnapshot.data() ?? {};
        String memberStatus = memberData['status']?.toString() ?? '';

        if (memberStatus == 'ACTIVE') {
          myStudyList.add(studyDocument);
        }
      }
    }

    if (_searchText.trim().isEmpty) {
      return myStudyList;
    }

    return myStudyList.where((studyDocument) {
      return _matchesStudySearch(studyDocument.data());
    }).toList();
  }

  bool _matchesStudySearch(
      Map<String, dynamic> studyData,
      ) {
    String keyword = _searchText.trim().toLowerCase();

    if (keyword.isEmpty) {
      return true;
    }

    String groupName =
        studyData['groupName']?.toString().toLowerCase() ?? '';
    String description =
        studyData['description']?.toString().toLowerCase() ?? '';
    String certificateName =
        studyData['certificateName']?.toString().toLowerCase() ?? '';

    return groupName.contains(keyword) ||
        description.contains(keyword) ||
        certificateName.contains(keyword);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterFindStudyList(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> allStudyList,
      ) {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> visibleStudyList = [];

    String searchText = _searchText.toLowerCase();

    for (int i = 0; i < allStudyList.length; i++) {
      QueryDocumentSnapshot<Map<String, dynamic>> studyDocument =
      allStudyList[i];

      Map<String, dynamic> studyData = studyDocument.data();

      bool isPublic = true;

      if (studyData['isPublic'] is bool) {
        isPublic = studyData['isPublic'];
      }

      // 비공개 스터디는 공개 검색 목록에 노출하지 않는다.
      // 방장과 승인된 그룹원은 '내 스터디' 탭에서 확인할 수 있다.
      if (!isPublic) {
        continue;
      }

      String groupName =
          studyData['groupName']?.toString().toLowerCase() ?? '';

      String description =
          studyData['description']?.toString().toLowerCase() ?? '';

      String certificateName =
          studyData['certificateName']?.toString().toLowerCase() ?? '';

      bool matchesSearch =
          groupName.contains(searchText) ||
              description.contains(searchText) ||
              certificateName.contains(searchText);

      if (matchesSearch == false) {
        continue;
      }

      if (_selectedFindFilter == '모집 중') {
        if (_isRecruiting(studyData) == false) {
          continue;
        }
      }

      if (_selectedFindFilter == '모집 마감') {
        if (_isRecruiting(studyData)) {
          continue;
        }
      }

      visibleStudyList.add(studyDocument);
    }

    return visibleStudyList;
  }

  Widget _buildTopTab(String title) {
    bool isSelected = _selectedTab == title;

    Color backgroundColor = _studyColorScheme.surface;
    Color textColor = _studyColors.textSecondary;

    if (isSelected) {
      backgroundColor = _studyColors.pinkStart;
      textColor = Colors.white;
    }

    return Expanded(
      child: SizedBox(
        height: 38,
        child: OutlinedButton(
          onPressed: () {
            setState(() {
              _selectedTab = title;
            });
          },
          style: OutlinedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: textColor,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(19),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight:
              isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudySearchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          setState(() {
            _searchText = value.trim();
          });
        },
        decoration: InputDecoration(
          hintText: '스터디 이름 또는 자격증 검색',
          hintStyle: TextStyle(
            fontSize: 13,
            color: _studyColors.textSecondary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 21,
            color: _studyColors.textSecondary,
          ),
          suffixIcon: _searchText.isEmpty
              ? null
              : IconButton(
            tooltip: '검색어 지우기',
            onPressed: () {
              _searchController.clear();

              setState(() {
                _searchText = '';
              });
            },
            icon: Icon(
              Icons.close_rounded,
              size: 19,
            ),
          ),
          filled: true,
          fillColor: _studyColorScheme.surface,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: _studyColors.pinkSoft,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: _studyColors.pinkStart,
              width: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFindFilter(String title) {
    bool isSelected = _selectedFindFilter == title;

    Color backgroundColor = _studyColorScheme.surface;
    Color textColor = _studyColors.textSecondary;
    Color borderColor = _studyColorScheme.outlineVariant;

    if (isSelected) {
      backgroundColor = _studyColors.lavender;
      textColor = _studyColors.pinkStart;
      borderColor = _studyColors.pinkStart;
    }

    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: backgroundColor,
      backgroundColor: backgroundColor,
      side: BorderSide(
        color: borderColor,
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        color: textColor,
        fontWeight:
        isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (value) {
        setState(() {
          _selectedFindFilter = title;
        });
      },
    );
  }

  Widget _buildBadge(
      String text,
      Color backgroundColor,
      Color textColor,
      ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStudyCircle(
      String certificateName,
      String thumbnailUrl,
      ) {
    if (thumbnailUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 27,
        backgroundColor: _studyColors.lavender,
        backgroundImage: NetworkImage(thumbnailUrl),
      );
    }

    String firstLetter = 'S';

    if (certificateName.isNotEmpty) {
      firstLetter = certificateName.substring(0, 1);
    }

    return CircleAvatar(
      radius: 27,
      backgroundColor: _studyColors.lavender,
      child: Text(
        firstLetter,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: _studyColors.pinkStart,
        ),
      ),
    );
  }

  Widget _buildMyStudyCard(
      QueryDocumentSnapshot<Map<String, dynamic>> studyDocument,
      ) {
    Map<String, dynamic> studyData = studyDocument.data();

    String groupName =
        studyData['groupName']?.toString() ?? '스터디';

    String description =
        studyData['description']?.toString() ?? '';

    String certificateName =
        studyData['certificateName']?.toString() ?? '공통';

    String thumbnailUrl =
        studyData['thumbnailUrl']?.toString() ?? '';

    String ownerUid =
        studyData['ownerUid']?.toString() ?? '';

    int currentMemberCount = _getInt(
      studyData,
      'currentMemberCount',
    );

    int maxMemberCount = _getInt(
      studyData,
      'maxMemberCount',
    );

    User? currentUser = FirebaseAuth.instance.currentUser;
    String currentUserUid = '';

    if (currentUser != null) {
      currentUserUid = currentUser.uid;
    }

    bool isOwner = ownerUid == currentUserUid;

    String memberText = '$currentMemberCount명 참여';

    if (maxMemberCount > 0) {
      memberText = '$currentMemberCount / $maxMemberCount명';
    }

    if (description.isEmpty) {
      description = '등록된 스터디 소개가 없습니다.';
    }

    String roleText = '참여 중';
    Color roleBackgroundColor = _studyColors.mint;
    Color roleTextColor = _studyColorScheme.tertiary;

    if (isOwner) {
      roleText = '방장';
      roleBackgroundColor = _studyColors.pinkSoft;
      roleTextColor = _studyColors.pinkStart;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _openStudyRoom(
            studyDocument.id,
            groupName,
          );
        },
        child: Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: AppCard(
            borderRadius: 16,
            padding: EdgeInsets.all(14),
            backgroundColor: _studyColorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: _buildBadge(
                        certificateName,
                        _studyColors.pinkSoft,
                        _studyColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 7),
                    _buildBadge(
                      roleText,
                      roleBackgroundColor,
                      roleTextColor,
                    ),
                  ],
                ),
                if (isOwner)
                  _buildJoinRequestNotice(
                    studyDocument.id,
                  ),
                SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: _studyColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color:
                              _studyColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (thumbnailUrl.isNotEmpty) ...[
                      SizedBox(width: 11),
                      ClipRRect(
                        borderRadius:
                        BorderRadius.circular(12),
                        child: Image.network(
                          thumbnailUrl,
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (
                              context,
                              error,
                              stackTrace,
                              ) {
                            return Container(
                              width: 68,
                              height: 68,
                              color: _studyColors.pinkSoft,
                              child: Icon(
                                Icons
                                    .image_not_supported_outlined,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 11),
                Row(
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 15,
                      color: _studyColors.textSecondary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      memberText,
                      style: TextStyle(
                        fontSize: 11,
                        color: _studyColors.textSecondary,
                      ),
                    ),
                    Spacer(),
                    TextButton(
                      onPressed: () {
                        _openStudyDetail(
                          studyDocument.id,
                          studyData,
                        );
                      },
                      style: TextButton.styleFrom(
                        minimumSize: Size(0, 28),
                        padding: EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        '정보',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _studyColors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(width: 2),
                    Text(
                      '스터디방',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _studyColors.pinkStart,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 19,
                      color: _studyColors.pinkStart,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinRequestNotice(
      String studyId,
      ) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyId)
          .collection('members')
          .where(
        'status',
        isEqualTo: 'PENDING',
      )
          .snapshots(),
      builder: (context, snapshot) {
        int pendingCount = 0;

        if (snapshot.hasData) {
          pendingCount = snapshot.data!.docs.length;
        }

        if (pendingCount == 0) {
          return SizedBox();
        }

        return Padding(
          padding: EdgeInsets.only(top: 9),
          child: Material(
            color: _studyColors.pinkSoft,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                _openJoinRequests(studyId);
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 21,
                          color: _studyColors.pinkStart,
                        ),
                        Positioned(
                          right: -5,
                          top: -6,
                          child: Container(
                            constraints: BoxConstraints(
                              minWidth: 17,
                              minHeight: 17,
                            ),
                            alignment: Alignment.center,
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _studyColors.pinkStart,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$pendingCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '새 참여 신청이 $pendingCount건 있어요.',
                        style: TextStyle(
                          color: _studyColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '확인',
                      style: TextStyle(
                        color: _studyColors.pinkStart,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 19,
                      color: _studyColors.pinkStart,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFindStudyCard(
      QueryDocumentSnapshot<Map<String, dynamic>> studyDocument,
      ) {
    Map<String, dynamic> studyData = studyDocument.data();

    String groupName =
        studyData['groupName']?.toString() ?? '그룹명 없음';

    String description =
        studyData['description']?.toString() ?? '';

    String certificateName =
        studyData['certificateName']?.toString() ?? '공통 스터디';

    String thumbnailUrl =
        studyData['thumbnailUrl']?.toString() ?? '';

    int currentMemberCount = _getInt(
      studyData,
      'currentMemberCount',
    );

    int maxMemberCount = _getInt(
      studyData,
      'maxMemberCount',
    );

    bool isRecruiting = _isRecruiting(studyData);

    String recruitingText = '모집 마감';
    Color recruitingBackgroundColor = _studyColorScheme.outlineVariant;
    Color recruitingTextColor = _studyColors.textSecondary;

    if (isRecruiting) {
      recruitingText = '모집 중';
      recruitingBackgroundColor = _studyColors.mint;
      recruitingTextColor = _studyColorScheme.tertiary;
    }

    if (description.isEmpty) {
      description = '등록된 스터디 소개가 없습니다.';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _openStudyDetail(
            studyDocument.id,
            studyData,
          );
        },
        child: Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: AppCard(
            borderRadius: 16,
            padding: EdgeInsets.all(14),
            backgroundColor: _studyColorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: _buildBadge(
                        certificateName,
                        _studyColors.lavender,
                        _studyColors.pinkStart,
                      ),
                    ),
                    SizedBox(width: 6),
                    _buildBadge(
                      recruitingText,
                      recruitingBackgroundColor,
                      recruitingTextColor,
                    ),
                  ],
                ),
                SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: _studyColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color:
                              _studyColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (thumbnailUrl.isNotEmpty) ...[
                      SizedBox(width: 11),
                      ClipRRect(
                        borderRadius:
                        BorderRadius.circular(12),
                        child: Image.network(
                          thumbnailUrl,
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (
                              context,
                              error,
                              stackTrace,
                              ) {
                            return Container(
                              width: 68,
                              height: 68,
                              color: _studyColors.pinkSoft,
                              child: Icon(
                                Icons
                                    .image_not_supported_outlined,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 11),
                Row(
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 15,
                      color: _studyColors.textSecondary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '$currentMemberCount / $maxMemberCount명',
                      style: TextStyle(
                        fontSize: 11,
                        color: _studyColors.textSecondary,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '상세 보기',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _studyColors.pinkStart,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 19,
                      color: _studyColors.pinkStart,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyStudyBody(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> allStudyList,
      ) {
    return FutureBuilder<
        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _loadMyStudyList(allStudyList),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppLoadingView(
            message: '참여 중인 스터디를 불러오는 중입니다.',
          );
        }

        if (snapshot.hasError) {
          if (_isNetworkError(snapshot.error)) {
            return AppNetworkErrorView(
              message: '인터넷 연결을 확인해 주세요.',
              description:
              'Wi-Fi 또는 모바일 데이터를 확인한 뒤 다시 시도해 주세요.',
              retryButtonText: '다시 시도',
              onRetryPressed: _reloadStudyList,
            );
          }

          return AppErrorView(
            message: '참여 중인 스터디를 불러오지 못했습니다.',
            description: '잠시 후 다시 시도해 주세요.',
            retryButtonText: '다시 시도',
            onRetryPressed: _reloadStudyList,
          );
        }

        List<QueryDocumentSnapshot<Map<String, dynamic>>> myStudyList = [];

        if (snapshot.data != null) {
          myStudyList = snapshot.data!;
        }

        if (myStudyList.isEmpty) {
          return AppEmptyView(
            message: '참여 중인 스터디가 없습니다.',
            description: '함께 공부할 스터디를 찾아보세요.',
            buttonText: '스터디 찾아보기',
            onButtonPressed: () {
              setState(() {
                _selectedTab = '스터디 찾기';
              });
            },
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 2, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '내 스터디',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _studyColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '${myStudyList.length}개의 스터디',
                    style: TextStyle(
                      fontSize: 12,
                      color: _studyColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: myStudyList.length,
              itemBuilder: (context, index) {
                return _buildMyStudyCard(
                  myStudyList[index],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFindStudyBody(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> allStudyList,
      ) {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> visibleStudyList =
    _filterFindStudyList(allStudyList);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildFindFilter('전체'),
            SizedBox(width: 6),
            _buildFindFilter('모집 중'),
            SizedBox(width: 6),
            _buildFindFilter('모집 마감'),
          ],
        ),
        SizedBox(height: 14),
        if (visibleStudyList.isEmpty)
          SizedBox(
            height: 390,
            child: _buildFindEmptyScreen(),
          )
        else ...[
          Padding(
            padding: EdgeInsets.only(left: 2, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '스터디 찾기',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _studyColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '${visibleStudyList.length}개의 스터디',
                  style: TextStyle(
                    fontSize: 12,
                    color: _studyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: visibleStudyList.length,
            itemBuilder: (context, index) {
              return _buildFindStudyCard(
                visibleStudyList[index],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildFindEmptyScreen() {
    if (_searchText.isNotEmpty) {
      return AppEmptyView(
        message: '검색 결과가 없습니다.',
        description: '다른 검색어로 다시 검색해 주세요.',
      );
    }

    if (_selectedFindFilter == '모집 중') {
      return AppEmptyView(
        message: '현재 모집 중인 스터디가 없습니다.',
        description: '새로운 스터디가 등록되면 이곳에 표시됩니다.',
      );
    }

    if (_selectedFindFilter == '모집 마감') {
      return AppEmptyView(
        message: '모집이 마감된 스터디가 없습니다.',
        description: '모집이 끝난 스터디가 생기면 이곳에 표시됩니다.',
      );
    }

    return AppEmptyView(
      message: '등록된 스터디가 없습니다.',
      description: '새로운 스터디를 직접 만들어 보세요.',
      buttonText: '스터디 만들기',
      onButtonPressed: _openCreatePage,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isKeyboardOpen =
        MediaQuery.of(context).viewInsets.bottom > 0;

    double bottomPadding = 12;

    if (isKeyboardOpen) {
      bottomPadding = 6;
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppTopBar(
        title: '스터디',
        centerTitle: false,
      ),
      body: AppMainBackground(
        applySafeArea: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            bottomPadding,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              double bodyMinHeight =
                  constraints.maxHeight - 99;

              if (bodyMinHeight < 0) {
                bodyMinHeight = 0;
              }

              return RefreshIndicator(
                color: _studyColors.pinkStart,
                onRefresh: _refreshStudyList,
                child: ListView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  physics:
                  AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: 100),
                  children: [
                    _buildStudySearchField(),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        _buildTopTab('내 스터디'),
                        SizedBox(width: 8),
                        _buildTopTab('스터디 찾기'),
                      ],
                    ),
                    SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: bodyMinHeight,
                      ),
                      child: StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>>(
                        stream: _getStudyGroupStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return AppLoadingView(
                              message:
                              '스터디 목록을 불러오는 중입니다.',
                            );
                          }

                          if (snapshot.hasError) {
                            debugPrint(
                              '스터디 목록 조회 오류: '
                                  '${snapshot.error}',
                            );

                            if (_isNetworkError(
                              snapshot.error,
                            )) {
                              return AppNetworkErrorView(
                                message:
                                '인터넷 연결을 확인해 주세요.',
                                description:
                                'Wi-Fi 또는 모바일 데이터를 확인한 뒤 다시 시도해 주세요.',
                                retryButtonText: '다시 시도',
                                onRetryPressed:
                                _reloadStudyList,
                              );
                            }

                            return AppErrorView(
                              message:
                              '스터디 목록을 불러오지 못했습니다.',
                              description:
                              '잠시 후 다시 시도해 주세요.',
                              retryButtonText: '다시 시도',
                              onRetryPressed:
                              _reloadStudyList,
                            );
                          }

                          List<QueryDocumentSnapshot<
                              Map<String, dynamic>>>
                          allStudyList = [];

                          if (snapshot.data != null) {
                            allStudyList =
                                snapshot.data!.docs.toList();
                          }

                          allStudyList.sort((a, b) {
                            dynamic aCreatedAt =
                            a.data()['createdAt'];
                            dynamic bCreatedAt =
                            b.data()['createdAt'];

                            int aTime = 0;
                            int bTime = 0;

                            if (aCreatedAt is Timestamp) {
                              aTime = aCreatedAt
                                  .millisecondsSinceEpoch;
                            }

                            if (bCreatedAt is Timestamp) {
                              bTime = bCreatedAt
                                  .millisecondsSinceEpoch;
                            }

                            return bTime.compareTo(aTime);
                          });

                          if (_selectedTab == '내 스터디') {
                            return _buildMyStudyBody(
                              allStudyList,
                            );
                          }

                          return _buildFindStudyBody(
                            allStudyList,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: isKeyboardOpen
          ? null
          : FloatingActionButton.extended(
        heroTag: 'study_list_fab',
        onPressed: _openCreatePage,
        backgroundColor: _studyColors.pinkStart,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add_rounded),
        label: Text(
          '스터디 만들기',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}