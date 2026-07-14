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

/// main_page.dart에서 불러오는 스터디 화면
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
  TextEditingController _searchController = TextEditingController();

  String _selectedMenu = '전체';
  String _searchText = '';

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
    dynamic value = data[fieldName];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  /// 모집 중인지 확인
  bool _isRecruiting(Map<String, dynamic> data) {
    String status = data['status']?.toString() ?? 'RECRUITING';

    int currentMemberCount = _getInt(
      data,
      'currentMemberCount',
    );

    int maxMemberCount = _getInt(
      data,
      'maxMemberCount',
    );

    if (status == 'CLOSED') {
      return false;
    }

    if (status == 'COMPLETED') {
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
    Map<String, dynamic> data = document.data();

    String groupName =
        data['groupName']?.toString().toLowerCase() ?? '';

    String description =
        data['description']?.toString().toLowerCase() ?? '';

    String certificateName =
        data['certificateName']?.toString().toLowerCase() ?? '';

    String searchText = _searchText.toLowerCase();

    bool matchesSearch =
        groupName.contains(searchText) ||
            description.contains(searchText) ||
            certificateName.contains(searchText);

    if (matchesSearch == false) {
      return false;
    }

    if (_selectedMenu == '모집 중') {
      return _isRecruiting(data);
    }

    if (_selectedMenu == '내 스터디') {
      String? currentUserUid =
          FirebaseAuth.instance.currentUser?.uid;

      return data['ownerUid'] == currentUserUid;
    }

    return true;
  }

  /// 스터디 만들기 화면으로 이동
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

  /// 스터디 상세 화면으로 이동
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

  /// 목록 다시 불러오기
  void _reloadStudyList() {
    setState(() {});
  }

  /// 네트워크 오류인지 확인
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

  /// 전체 / 모집 중 / 내 스터디 메뉴
  Widget _buildMenuChip(String menu) {
    bool isSelected = _selectedMenu == menu;

    Color backgroundColor = Colors.white;
    Color borderColor = Color(0xFFE4E5E9);
    Color textColor = Color(0xFF727680);
    FontWeight fontWeight = FontWeight.normal;

    if (isSelected) {
      backgroundColor = Color(0xFFE9E4FF);
      borderColor = Color(0xFF8068D8);
      textColor = Color(0xFF6C54C8);
      fontWeight = FontWeight.bold;
    }

    return ChoiceChip(
      label: Text(menu),
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
        fontWeight: fontWeight,
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
          _selectedMenu = menu;
        });
      },
    );
  }

  /// 카드 위 작은 표시
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

  /// 데이터가 없을 때 공통 상태 화면
  Widget _buildEmptyScreen() {
    if (_searchText.isNotEmpty) {
      return AppEmptyView(
        message: '검색 결과가 없습니다.',
        description: '다른 검색어로 다시 검색해 주세요.',
      );
    }

    if (_selectedMenu == '모집 중') {
      return AppEmptyView(
        message: '현재 모집 중인 스터디가 없습니다.',
        description: '새로운 스터디가 등록되면 이곳에 표시됩니다.',
      );
    }

    if (_selectedMenu == '내 스터디') {
      return AppEmptyView(
        message: '내가 만든 스터디가 없습니다.',
        description: '새로운 스터디를 직접 만들어 보세요.',
        buttonText: '스터디 만들기',
        onButtonPressed: _openCreatePage,
      );
    }

    return AppEmptyView(
      message: '등록된 스터디가 없습니다.',
      description: '함께 공부할 스터디를 직접 만들어 보세요.',
      buttonText: '스터디 만들기',
      onButtonPressed: _openCreatePage,
    );
  }

  /// 스터디 카드 하나
  Widget _buildStudyCard(
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

    String recruitingText = '모집 완료';
    Color recruitingBackgroundColor = Color(0xFFF1F2F5);
    Color recruitingTextColor = Color(0xFF858994);

    if (isRecruiting) {
      recruitingText = '모집 중';
      recruitingBackgroundColor = Color(0xFFDFF5EA);
      recruitingTextColor = Color(0xFF3F9C72);
    }

    String descriptionText = description;

    if (descriptionText.isEmpty) {
      descriptionText = '등록된 스터디 소개가 없습니다.';
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 10),
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
                      Color(0xFFE9E4FF),
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
                descriptionText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7B7F89),
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
                    '$currentMemberCount / $maxMemberCount명',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF737782),
                    ),
                  ),
                  Spacer(),
                  Text(
                    '자세히',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6C54C8),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF6C54C8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
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
                        color: Color(0xFF8068D8),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 7),
              Row(
                children: [
                  _buildMenuChip('전체'),
                  SizedBox(width: 6),
                  _buildMenuChip('모집 중'),
                  SizedBox(width: 6),
                  _buildMenuChip('내 스터디'),
                ],
              ),
              SizedBox(height: 7),
              Expanded(
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studyGroups')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return AppLoadingView(
                        message: '스터디 목록을 불러오는 중입니다.',
                      );
                    }

                    if (snapshot.hasError) {
                      debugPrint(
                        'Firestore 오류: ${snapshot.error}',
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

                    List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
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

                    List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    visibleStudyList = [];

                    for (int i = 0;
                    i < allStudyList.length;
                    i++) {
                      bool isVisible = _isVisibleStudy(
                        allStudyList[i],
                      );

                      if (isVisible) {
                        visibleStudyList.add(
                          allStudyList[i],
                        );
                      }
                    }

                    if (visibleStudyList.isEmpty) {
                      return _buildEmptyScreen();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            left: 2,
                            bottom: 6,
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
                            ScrollViewKeyboardDismissBehavior
                                .onDrag,
                            padding: EdgeInsets.zero,
                            itemCount: visibleStudyList.length,
                            itemBuilder: (context, index) {
                              return _buildStudyCard(
                                visibleStudyList[index],
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
    );
  }
}
