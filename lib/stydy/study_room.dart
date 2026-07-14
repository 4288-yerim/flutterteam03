import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutterteam03/widgets/app_state_views.dart';

import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import 'study_chat.dart';
import 'study_quiz.dart';
import 'study_timer.dart';

class StudyRoomPage extends StatelessWidget {
  final String studyId;
  final String groupName;

  const StudyRoomPage({
    super.key,
    required this.studyId,
    required this.groupName,
  });

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

  String _formatStudyTime(int totalMinutes) {
    if (totalMinutes <= 0) {
      return '0분';
    }

    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;

    if (hours == 0) {
      return '$minutes분';
    }

    if (minutes == 0) {
      return '$hours시간';
    }

    return '$hours시간 $minutes분';
  }

  String _formatChatTime(dynamic createdAt) {
    if (createdAt is! Timestamp) {
      return '';
    }

    DateTime dateTime = createdAt.toDate().toLocal();
    DateTime now = DateTime.now();

    bool isToday =
        dateTime.year == now.year &&
            dateTime.month == now.month &&
            dateTime.day == now.day;

    if (isToday) {
      String hour = dateTime.hour.toString().padLeft(2, '0');
      String minute = dateTime.minute.toString().padLeft(2, '0');

      return '$hour:$minute';
    }

    if (dateTime.year == now.year) {
      return '${dateTime.month}/${dateTime.day}';
    }

    return '${dateTime.year}.${dateTime.month}.${dateTime.day}';
  }

  String _getFirstLetter(String nickname) {
    if (nickname.isEmpty) {
      return '?';
    }

    return nickname.substring(0, 1).toUpperCase();
  }

  Widget _buildProfileImage(
      String nickname,
      String profileImageUrl,
      bool isOwner,
      ) {
    Widget profile;

    if (profileImageUrl.isNotEmpty) {
      profile = CircleAvatar(
        radius: 28,
        backgroundColor: Color(0xFFF0ECFF),
        backgroundImage: NetworkImage(profileImageUrl),
      );
    } else {
      profile = CircleAvatar(
        radius: 28,
        backgroundColor: Color(0xFFF0ECFF),
        child: Text(
          _getFirstLetter(nickname),
          style: TextStyle(
            color: Color(0xFF6F58C9),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        profile,
        Visibility(
          visible: isOwner,
          child: Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                color: Color(0xFFF0788F),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.star_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberProfiles(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyId)
          .collection('members')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 95,
            alignment: Alignment.center,
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Container(
            height: 70,
            alignment: Alignment.centerLeft,
            child: Text(
              '그룹원 정보를 불러오지 못했습니다.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF858994),
              ),
            ),
          );
        }

        List<QueryDocumentSnapshot<Map<String, dynamic>>> memberList = [];

        if (snapshot.data != null) {
          for (int i = 0; i < snapshot.data!.docs.length; i++) {
            QueryDocumentSnapshot<Map<String, dynamic>> memberDocument =
            snapshot.data!.docs[i];

            Map<String, dynamic> memberData = memberDocument.data();

            String status = memberData['status']?.toString() ?? '';
            String role = memberData['role']?.toString() ?? 'MEMBER';

            if (status == 'ACTIVE' || role == 'OWNER') {
              memberList.add(memberDocument);
            }
          }
        }

        memberList.sort((a, b) {
          String aRole = a.data()['role']?.toString() ?? 'MEMBER';
          String bRole = b.data()['role']?.toString() ?? 'MEMBER';

          if (aRole == 'OWNER' && bRole != 'OWNER') {
            return -1;
          }

          if (aRole != 'OWNER' && bRole == 'OWNER') {
            return 1;
          }

          return 0;
        });

        if (memberList.isEmpty) {
          return Container(
            height: 70,
            alignment: Alignment.centerLeft,
            child: Text(
              '아직 참여 중인 그룹원이 없습니다.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF858994),
              ),
            ),
          );
        }

        return SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: memberList.length,
            itemBuilder: (context, index) {
              Map<String, dynamic> memberData = memberList[index].data();

              String nickname =
                  memberData['nickname']?.toString() ?? '스터디원';

              String role =
                  memberData['role']?.toString() ?? 'MEMBER';

              String profileImageUrl =
                  memberData['profileImageUrl']?.toString() ?? '';

              bool isOwner = role == 'OWNER';

              return Container(
                width: 76,
                margin: EdgeInsets.only(right: 8),
                child: Column(
                  children: [
                    _buildProfileImage(
                      nickname,
                      profileImageUrl,
                      isOwner,
                    ),
                    SizedBox(height: 7),
                    Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF555A64),
                        fontWeight:
                        isOwner ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildChatActivityButton(
      BuildContext context,
      String displayGroupName,
      ) {
    User? currentUser = FirebaseAuth.instance.currentUser;
    String currentUserUid = '';

    if (currentUser != null) {
      currentUserUid = currentUser.uid;
    }

    return Expanded(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc(studyId)
            .collection('messages')
            .orderBy(
          'createdAt',
          descending: true,
        )
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          String lastMessage = '아직 메시지가 없습니다.';
          String lastMessageTime = '';
          int unreadCount = 0;

          if (snapshot.connectionState == ConnectionState.waiting) {
            lastMessage = '채팅을 불러오는 중입니다.';
          } else if (snapshot.hasError) {
            lastMessage = '채팅을 불러오지 못했습니다.';
          } else if (snapshot.data != null) {
            bool foundLastMessage = false;

            for (int i = 0; i < snapshot.data!.docs.length; i++) {
              QueryDocumentSnapshot<Map<String, dynamic>> messageDocument =
              snapshot.data!.docs[i];

              Map<String, dynamic> messageData = messageDocument.data();

              List<dynamic> hiddenFor = [];

              if (messageData['hiddenFor'] is List) {
                hiddenFor = messageData['hiddenFor'];
              }

              if (hiddenFor.contains(currentUserUid)) {
                continue;
              }

              String senderUid =
                  messageData['senderUid']?.toString() ?? '';

              List<dynamic> readBy = [];

              if (messageData['readBy'] is List) {
                readBy = messageData['readBy'];
              }

              if (senderUid != currentUserUid &&
                  readBy.contains(currentUserUid) == false) {
                unreadCount++;
              }

              if (foundLastMessage == false) {
                String senderNickname =
                    messageData['senderNickname']?.toString() ?? '스터디원';

                String message =
                    messageData['message']?.toString() ?? '';

                bool isDeleted = messageData['isDeleted'] == true;

                if (isDeleted) {
                  lastMessage = '삭제된 메시지입니다.';
                } else if (senderUid == currentUserUid) {
                  lastMessage = '나: $message';
                } else {
                  lastMessage = '$senderNickname: $message';
                }

                lastMessageTime = _formatChatTime(
                  messageData['createdAt'],
                );

                foundLastMessage = true;
              }
            }
          }

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return StudyChatPage(
                      studyId: studyId,
                      groupName: displayGroupName,
                    );
                  },
                ),
              );
            },
            child: Container(
              height: 135,
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Color(0xFFECEAF0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color: Color(0xFFE1E9FB),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline,
                          color: Color(0xFF5576B7),
                          size: 22,
                        ),
                      ),
                      Spacer(),
                      Visibility(
                        visible: unreadCount > 0,
                        child: Container(
                          constraints: BoxConstraints(
                            minWidth: 23,
                            minHeight: 23,
                          ),
                          alignment: Alignment.center,
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFF0788F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    '그룹 채팅',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF858994),
                          ),
                        ),
                      ),
                      Visibility(
                        visible: lastMessageTime.isNotEmpty,
                        child: Padding(
                          padding: EdgeInsets.only(left: 5),
                          child: Text(
                            lastMessageTime,
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFFA1A4AC),
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
        },
      ),
    );
  }

  Widget _buildActivityButton(
      IconData icon,
      String title,
      String description,
      Color backgroundColor,
      Color iconColor,
      VoidCallback onTap,
      ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 135,
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color(0xFFECEAF0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF858994),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMemberList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: Color(0xFFFAF9FD),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: 11),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Color(0xFFD8D5DE),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      color: Color(0xFF8068D8),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '그룹원 목록',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                      },
                      icon: Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              Expanded(
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studyGroups')
                      .doc(studyId)
                      .collection('members')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return AppLoadingView(
                        message: '그룹원 목록을 불러오는 중입니다.',
                      );
                    }

                    if (snapshot.hasError) {
                      return AppErrorView(
                        message: '그룹원 목록을 불러오지 못했습니다.',
                        description: '잠시 후 다시 시도해 주세요.',
                      );
                    }

                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    memberList = [];

                    if (snapshot.data != null) {
                      for (int i = 0;
                      i < snapshot.data!.docs.length;
                      i++) {
                        QueryDocumentSnapshot<Map<String, dynamic>>
                        memberDocument = snapshot.data!.docs[i];

                        Map<String, dynamic> memberData =
                        memberDocument.data();

                        String status =
                            memberData['status']?.toString() ?? '';

                        String role =
                            memberData['role']?.toString() ?? 'MEMBER';

                        if (status == 'ACTIVE' || role == 'OWNER') {
                          memberList.add(memberDocument);
                        }
                      }
                    }

                    memberList.sort((a, b) {
                      String aRole =
                          a.data()['role']?.toString() ?? 'MEMBER';
                      String bRole =
                          b.data()['role']?.toString() ?? 'MEMBER';

                      if (aRole == 'OWNER' && bRole != 'OWNER') {
                        return -1;
                      }

                      if (aRole != 'OWNER' && bRole == 'OWNER') {
                        return 1;
                      }

                      return 0;
                    });

                    if (memberList.isEmpty) {
                      return AppEmptyView(
                        message: '등록된 그룹원이 없습니다.',
                        description: '새로운 그룹원이 참여하면 이곳에 표시됩니다.',
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(18, 16, 18, 30),
                      itemCount: memberList.length,
                      itemBuilder: (context, index) {
                        Map<String, dynamic> memberData =
                        memberList[index].data();

                        String nickname =
                            memberData['nickname']?.toString() ??
                                '스터디원';

                        String role =
                            memberData['role']?.toString() ?? 'MEMBER';

                        String profileImageUrl =
                            memberData['profileImageUrl']?.toString() ?? '';

                        int totalStudyMinutes = _getInt(
                          memberData,
                          'totalStudyMinutes',
                        );

                        bool isOwner = role == 'OWNER';

                        return Container(
                          margin: EdgeInsets.only(bottom: 11),
                          padding: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Color(0xFFECEAF0),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildProfileImage(
                                nickname,
                                profileImageUrl,
                                isOwner,
                              ),
                              SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          nickname,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Visibility(
                                          visible: isOwner,
                                          child: Container(
                                            margin: EdgeInsets.only(left: 7),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Color(0xFFFFE7EE),
                                              borderRadius:
                                              BorderRadius.circular(11),
                                            ),
                                            child: Text(
                                              '방장',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFFD85F82),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      '누적 공부시간 '
                                          '${_formatStudyTime(totalStudyMinutes)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF92969F),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openStudyRanking(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: Color(0xFFFAF9FD),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: 11),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Color(0xFFD8D5DE),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      color: Color(0xFF8068D8),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '공부시간 순위',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                      },
                      icon: Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              Expanded(
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studyGroups')
                      .doc(studyId)
                      .collection('members')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return AppLoadingView(
                        message: '공부시간 순위를 불러오는 중입니다.',
                      );
                    }

                    if (snapshot.hasError) {
                      return AppErrorView(
                        message: '공부시간 순위를 불러오지 못했습니다.',
                        description: '잠시 후 다시 시도해 주세요.',
                      );
                    }

                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    memberList = [];

                    if (snapshot.data != null) {
                      for (int i = 0;
                      i < snapshot.data!.docs.length;
                      i++) {
                        QueryDocumentSnapshot<Map<String, dynamic>>
                        memberDocument = snapshot.data!.docs[i];

                        Map<String, dynamic> memberData =
                        memberDocument.data();

                        String status =
                            memberData['status']?.toString() ?? '';

                        String role =
                            memberData['role']?.toString() ?? 'MEMBER';

                        if (status == 'ACTIVE' || role == 'OWNER') {
                          memberList.add(memberDocument);
                        }
                      }
                    }

                    memberList.sort((a, b) {
                      int aMinutes = _getInt(
                        a.data(),
                        'totalStudyMinutes',
                      );

                      int bMinutes = _getInt(
                        b.data(),
                        'totalStudyMinutes',
                      );

                      return bMinutes.compareTo(aMinutes);
                    });

                    if (memberList.isEmpty) {
                      return AppEmptyView(
                        message: '아직 공부시간 기록이 없습니다.',
                        description: '공부시간을 기록하면 순위가 이곳에 표시됩니다.',
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(18, 16, 18, 30),
                      itemCount: memberList.length,
                      itemBuilder: (context, index) {
                        Map<String, dynamic> memberData =
                        memberList[index].data();

                        String nickname =
                            memberData['nickname']?.toString() ??
                                '스터디원';

                        int totalStudyMinutes = _getInt(
                          memberData,
                          'totalStudyMinutes',
                        );

                        return Container(
                          margin: EdgeInsets.only(bottom: 11),
                          padding: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Color(0xFFECEAF0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Color(0xFFF0ECFF),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Color(0xFF6F58C9),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 13),
                              Expanded(
                                child: Text(
                                  nickname,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                _formatStudyTime(totalStudyMinutes),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6F58C9),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 방장만 스터디 공지를 작성하거나 수정
  void _showNoticeDialog(
      BuildContext context,
      String currentNotice,
      ) {
    TextEditingController noticeController = TextEditingController();
    noticeController.text = currentNotice;

    String dialogTitle = '공지 등록';

    if (currentNotice.isNotEmpty) {
      dialogTitle = '공지 수정';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogTitle),
          content: TextField(
            controller: noticeController,
            maxLines: 6,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: '스터디원에게 전달할 공지를 입력하세요.',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                String notice = noticeController.text.trim();

                try {
                  await FirebaseFirestore.instance
                      .collection('studyGroups')
                      .doc(studyId)
                      .update({
                    'notice': notice,
                    'noticeUpdatedAt': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('스터디 공지가 저장되었습니다.'),
                    ),
                  );
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('공지 저장 중 오류가 발생했습니다.'),
                    ),
                  );
                }
              },
              child: Text('저장'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoomContent(
      BuildContext context,
      Map<String, dynamic> groupData,
      bool isOwner,
      ) {
    String displayGroupName =
        groupData['groupName']?.toString() ?? groupName;

    String description =
        groupData['description']?.toString() ?? '';

    String notice = groupData['notice']?.toString() ?? '';

    int currentMemberCount = _getInt(
      groupData,
      'currentMemberCount',
    );

    int maxMemberCount = _getInt(
      groupData,
      'maxMemberCount',
    );

    double bottomPadding =
        MediaQuery.of(context).padding.bottom + 40;

    return AppMainBackground(
      applySafeArea: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          bottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayGroupName,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              '$currentMemberCount / $maxMemberCount명 참여 중',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7B7F89),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Visibility(
                        visible: isOwner,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFE7EE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '방장',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFD85F82),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Visibility(
                    visible: description.isNotEmpty,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 12),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF686D78),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '함께 공부하는 멤버',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _openMemberList(context);
                        },
                        child: Text(
                          '전체보기',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8068D8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildMemberProfiles(context),
                ],
              ),
            ),
            SizedBox(height: 15),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(0xFFFFE7EE),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.campaign_outlined,
                          color: Color(0xFFD85F82),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '스터디 공지',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Visibility(
                        visible: isOwner,
                        child: TextButton(
                          onPressed: () {
                            _showNoticeDialog(
                              context,
                              notice,
                            );
                          },
                          child: Text(
                            notice.isEmpty ? '등록' : '수정',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFD85F82),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    notice.isEmpty ? '등록된 공지가 없습니다.' : notice,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF686D78),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 22),
            Text(
              '스터디 활동',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildChatActivityButton(
                  context,
                  displayGroupName,
                ),
                SizedBox(width: 11),
                _buildActivityButton(
                  Icons.timer_outlined,
                  '공부시간',
                  '기록하기',
                  Color(0xFFDFF5EA),
                  Color(0xFF3F9C72),
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return StudyTimerPage(
                            studyId: studyId,
                            groupName: displayGroupName,
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 11),
            Row(
              children: [
                _buildActivityButton(
                  Icons.emoji_events_outlined,
                  '공부 순위',
                  '순위 보기',
                  Color(0xFFE6E1FB),
                  Color(0xFF6F58C9),
                      () {
                    _openStudyRanking(context);
                  },
                ),
                SizedBox(width: 11),
                _buildActivityButton(
                  Icons.quiz_outlined,
                  '발송 문제',
                  '문제 풀기',
                  Color(0xFFFCE1E8),
                  Color(0xFFD85F82),
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return StudyQuizPage(
                            studyId: studyId,
                            groupName: displayGroupName,
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessDenied() {
    return AppErrorView(
      message: '스터디방에 들어갈 수 없습니다.',
      description: '참여 승인을 받은 그룹원만 이용할 수 있습니다.',
    );
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('스터디방'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('studyGroups')
            .doc(studyId)
            .snapshots(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState ==
              ConnectionState.waiting) {
            return AppLoadingView(
              message: '스터디방을 불러오는 중입니다.',
            );
          }

          if (groupSnapshot.hasError) {
            return AppErrorView(
              message: '스터디방을 불러오지 못했습니다.',
              description: '잠시 후 다시 시도해 주세요.',
            );
          }

          if (groupSnapshot.data == null ||
              groupSnapshot.data!.exists == false) {
            return AppErrorView(
              message: '존재하지 않는 스터디입니다.',
              description: '삭제되었거나 더 이상 이용할 수 없는 스터디입니다.',
            );
          }

          Map<String, dynamic> groupData =
              groupSnapshot.data!.data() ?? {};

          String ownerUid =
              groupData['ownerUid']?.toString() ?? '';

          bool isOwner =
              currentUser != null && currentUser.uid == ownerUid;

          if (isOwner) {
            return _buildRoomContent(
              context,
              groupData,
              true,
            );
          }

          if (currentUser == null) {
            return _buildAccessDenied();
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('studyGroups')
                .doc(studyId)
                .collection('members')
                .doc(currentUser.uid)
                .snapshots(),
            builder: (context, memberSnapshot) {
              if (memberSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return AppLoadingView(
                  message: '그룹원 정보를 확인하는 중입니다.',
                );
              }

              if (memberSnapshot.hasError) {
                return AppErrorView(
                  message: '그룹원 정보를 불러오지 못했습니다.',
                  description: '잠시 후 다시 시도해 주세요.',
                );
              }

              String memberStatus = '';

              if (memberSnapshot.data != null &&
                  memberSnapshot.data!.exists) {
                Map<String, dynamic> memberData =
                    memberSnapshot.data!.data() ?? {};

                memberStatus =
                    memberData['status']?.toString() ?? '';
              }

              if (memberStatus != 'ACTIVE') {
                return _buildAccessDenied();
              }

              return _buildRoomContent(
                context,
                groupData,
                false,
              );
            },
          );
        },
      ),
    );
  }
}
