import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutterteam03/widgets/app_state_views.dart';

import '../firebase_options.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'study_add.dart';
import 'study_detail.dart';
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
      home: StudyListApp(),
    ),
  );
}

/// main_page.dart에서 사용하는 스터디 화면
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

    return myStudyList;
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

    Color backgroundColor = Colors.white;
    Color textColor = Color(0xFF777C86);
    Color borderColor = Color(0xFFE5E5EA);

    if (isSelected) {
      backgroundColor = Color(0xFFFCE1E8);
      textColor = Color(0xFFD85F82);
      borderColor = Color(0xFFF0788F);
    }

    return Expanded(
      child: SizedBox(
        height: 42,
        child: OutlinedButton(
          onPressed: () {
            setState(() {
              _selectedTab = title;
            });
          },
          style: OutlinedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: textColor,
            side: BorderSide(
              color: borderColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight:
              isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFindFilter(String title) {
    bool isSelected = _selectedFindFilter == title;

    Color backgroundColor = Colors.white;
    Color textColor = Color(0xFF777C86);
    Color borderColor = Color(0xFFE4E5E9);

    if (isSelected) {
      backgroundColor = Color(0xFFE6E1FB);
      textColor = Color(0xFF6F58C9);
      borderColor = Color(0xFF8068D8);
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
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: FontWeight.w600,
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
        backgroundColor: Color(0xFFF0ECFF),
        backgroundImage: NetworkImage(thumbnailUrl),
      );
    }

    String firstLetter = 'S';

    if (certificateName.isNotEmpty) {
      firstLetter = certificateName.substring(0, 1);
    }

    return CircleAvatar(
      radius: 27,
      backgroundColor: Color(0xFFE6E1FB),
      child: Text(
        firstLetter,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6F58C9),
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
    Color roleBackgroundColor = Color(0xFFDFF5EA);
    Color roleTextColor = Color(0xFF3F9C72);

    if (isOwner) {
      roleText = '방장';
      roleBackgroundColor = Color(0xFFFCE1E8);
      roleTextColor = Color(0xFFD85F82);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          _openStudyRoom(
            studyDocument.id,
            groupName,
          );
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(14),
          margin: EdgeInsets.only(bottom: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Color(0xFFE8E7EB),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStudyCircle(
                certificateName,
                thumbnailUrl,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: _buildBadge(
                            certificateName,
                            Color(0xFFE6E1FB),
                            Color(0xFF6F58C9),
                          ),
                        ),
                        SizedBox(width: 6),
                        _buildBadge(
                          roleText,
                          roleBackgroundColor,
                          roleTextColor,
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF29272E),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777C86),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 17,
                          color: Color(0xFF8C919C),
                        ),
                        SizedBox(width: 5),
                        Text(
                          memberText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF737782),
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
                            minimumSize: Size(0, 30),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            '정보',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF777C86),
                            ),
                          ),
                        ),
                        SizedBox(width: 2),
                        Text(
                          '스터디방',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD85F82),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: Color(0xFFD85F82),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
    Color recruitingBackgroundColor = Color(0xFFF1F2F5);
    Color recruitingTextColor = Color(0xFF858994);

    if (isRecruiting) {
      recruitingText = '모집 중';
      recruitingBackgroundColor = Color(0xFFDFF5EA);
      recruitingTextColor = Color(0xFF3F9C72);
    }

    if (description.isEmpty) {
      description = '등록된 스터디 소개가 없습니다.';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          _openStudyDetail(
            studyDocument.id,
            studyData,
          );
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(14),
          margin: EdgeInsets.only(bottom: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Color(0xFFE8E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: _buildBadge(
                      certificateName,
                      Color(0xFFE6E1FB),
                      Color(0xFF6F58C9),
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
              Text(
                groupName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF29272E),
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7B7F89),
                ),
              ),
              SizedBox(height: 9),
              Row(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 17,
                    color: Color(0xFF8C919C),
                  ),
                  SizedBox(width: 5),
                  Text(
                    '$currentMemberCount / $maxMemberCount명',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF737782),
                    ),
                  ),
                  Spacer(),
                  Text(
                    '상세 보기',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD85F82),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFFD85F82),
                  ),
                ],
              ),
            ],
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
              padding: EdgeInsets.only(
                left: 2,
                bottom: 7,
              ),
              child: Text(
                '참여 중인 스터디 ${myStudyList.length}개',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF777C86),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: myStudyList.length,
                itemBuilder: (context, index) {
                  return _buildMyStudyCard(
                    myStudyList[index],
                  );
                },
              ),
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
        SizedBox(
          height: 44,
          child: TextField(
            controller: _searchController,
            enabled: true,
            readOnly: false,
            keyboardType: TextInputType.text,
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
                color: Color(0xFF989AA2),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 21,
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
                icon: Icon(
                  Icons.close_rounded,
                  size: 19,
                ),
              )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                vertical: 9,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Color(0xFFE8E7EB),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Color(0xFFF0788F),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 7),
        Row(
          children: [
            _buildFindFilter('전체'),
            SizedBox(width: 6),
            _buildFindFilter('모집 중'),
            SizedBox(width: 6),
            _buildFindFilter('모집 마감'),
          ],
        ),
        SizedBox(height: 7),
        Expanded(
          child: visibleStudyList.isEmpty
              ? _buildFindEmptyScreen()
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: 2,
                  bottom: 7,
                ),
                child: Text(
                  '스터디 ${visibleStudyList.length}개',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF777C86),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.zero,
                  itemCount: visibleStudyList.length,
                  itemBuilder: (context, index) {
                    return _buildFindStudyCard(
                      visibleStudyList[index],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
        actions: [
          IconButton(
            tooltip: '스터디 만들기',
            onPressed: _openCreatePage,
            icon: Icon(
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
            16,
            8,
            16,
            bottomPadding,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _buildTopTab('내 스터디'),
                  SizedBox(width: 8),
                  _buildTopTab('스터디 찾기'),
                ],
              ),
              SizedBox(height: 9),
              Expanded(
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: _getStudyGroupStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return AppLoadingView(
                        message: '스터디 목록을 불러오는 중입니다.',
                      );
                    }

                    if (snapshot.hasError) {
                      debugPrint(
                        '스터디 목록 조회 오류: ${snapshot.error}',
                      );

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
                        message: '스터디 목록을 불러오지 못했습니다.',
                        description: '잠시 후 다시 시도해 주세요.',
                        retryButtonText: '다시 시도',
                        onRetryPressed: _reloadStudyList,
                      );
                    }

                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    allStudyList = [];

                    if (snapshot.data != null) {
                      allStudyList = snapshot.data!.docs.toList();
                    }

                    allStudyList.sort((a, b) {
                      dynamic aCreatedAt = a.data()['createdAt'];
                      dynamic bCreatedAt = b.data()['createdAt'];

                      int aTime = 0;
                      int bTime = 0;

                      if (aCreatedAt is Timestamp) {
                        aTime = aCreatedAt.millisecondsSinceEpoch;
                      }

                      if (bCreatedAt is Timestamp) {
                        bTime = bCreatedAt.millisecondsSinceEpoch;
                      }

                      return bTime.compareTo(aTime);
                    });

                    if (_selectedTab == '내 스터디') {
                      return _buildMyStudyBody(allStudyList);
                    }

                    return _buildFindStudyBody(allStudyList);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
