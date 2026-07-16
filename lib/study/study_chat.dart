import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutter/services.dart';
import 'package:flutterteam03/widgets/app_state_views.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';


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

class StudyChatPage extends StatefulWidget {
  final String studyId;
  final String groupName;

  const StudyChatPage({
    super.key,
    required this.studyId,
    required this.groupName,
  });

  @override
  State<StudyChatPage> createState() {
    return _StudyChatPageState();
  }
}

class _StudyChatPageState extends State<StudyChatPage> {
  TextEditingController _messageController = TextEditingController();

  bool _isSending = false;
  bool _isMarkingRead = false;
  bool _isOwner = false;

  String _myNickname = '사용자';
  String _myProfileImageUrl = '';

  String _replyMessageId = '';
  String _replySenderNickname = '';
  String _replyMessage = '';

  @override
  void initState() {
    super.initState();

    _createChatRoom();
    _loadMyMemberInfo();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }


  /// 채팅 화면 다시 불러오기
  void _reloadChat() {
    setState(() {});
  }

  bool _isNetworkError(Object? error) {
    if (error is FirebaseException) {
      if (error.code == 'unavailable' ||
          error.code == 'network-request-failed' ||
          error.code == 'deadline-exceeded') {
        return true;
      }
    }

    return false;
  }

  /// 채팅방 기본 문서 생성
  Future<void> _createChatRoom() async {
    try {
      DocumentReference<Map<String, dynamic>> chatDocument =
      FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.studyId);

      DocumentSnapshot<Map<String, dynamic>> chatSnapshot =
      await chatDocument.get();

      if (chatSnapshot.exists == false) {
        await chatDocument.set({
          'chatType': 'GROUP',
          'groupId': widget.studyId,
          'groupName': widget.groupName,
          'lastMessage': '',
          'lastMessageId': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      debugPrint('채팅방 생성 오류: $error');
    }
  }

  /// 현재 로그인한 사용자의 그룹원 정보 가져오기
  Future<void> _loadMyMemberInfo() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    try {
      DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
      await FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('members')
          .doc(currentUser.uid)
          .get();

      String nickname = currentUser.displayName ?? '사용자';
      String profileImageUrl = currentUser.photoURL ?? '';
      bool isOwner = false;

      if (memberSnapshot.exists) {
        Map<String, dynamic>? memberData = memberSnapshot.data();

        if (memberData != null) {
          if (memberData['nickname'] != null) {
            nickname = memberData['nickname'].toString();
          }

          if (memberData['profileImageUrl'] != null) {
            profileImageUrl =
                memberData['profileImageUrl'].toString();
          }

          String role = memberData['role']?.toString() ?? 'MEMBER';

          if (role == 'OWNER') {
            isOwner = true;
          }
        }
      }

      if (mounted) {
        setState(() {
          _myNickname = nickname;
          _myProfileImageUrl = profileImageUrl;
          _isOwner = isOwner;
        });
      }
    } catch (error) {
      debugPrint('그룹원 정보 불러오기 오류: $error');
    }
  }

  /// 스낵바 표시
  void _showSnackBar(String message) {
    if (mounted == false) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  /// 공지 작성 또는 수정
  void _showNoticeDialog(String currentNotice) {
    TextEditingController noticeController = TextEditingController();
    noticeController.text = currentNotice;

    String title = '공지 작성';

    if (currentNotice.isNotEmpty) {
      title = '공지 수정';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
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
                      .doc(widget.studyId)
                      .update({
                    'notice': notice,
                    'noticeWriterUid':
                    FirebaseAuth.instance.currentUser?.uid ?? '',
                    'noticeWriterNickname': _myNickname,
                    'noticeUpdatedAt': FieldValue.serverTimestamp(),
                  });

                  if (Navigator.canPop(dialogContext)) {
                    Navigator.pop(dialogContext);
                  }

                  _showSnackBar('공지가 저장되었습니다.');
                } catch (error) {
                  debugPrint('공지 저장 오류: $error');
                  _showSnackBar('공지를 저장하지 못했습니다.');
                }
              },
              child: Text('저장'),
            ),
          ],
        );
      },
    );
  }

  /// 답장할 메시지 선택
  void _selectReplyMessage(
      String messageId,
      Map<String, dynamic> messageData,
      ) {
    String senderNickname =
        messageData['senderNickname']?.toString() ?? '사용자';
    String message = messageData['message']?.toString() ?? '';

    if (messageData['isDeleted'] == true) {
      return;
    }

    setState(() {
      _replyMessageId = messageId;
      _replySenderNickname = senderNickname;
      _replyMessage = message;
    });
  }

  /// 답장 선택 취소
  void _cancelReply() {
    setState(() {
      _replyMessageId = '';
      _replySenderNickname = '';
      _replyMessage = '';
    });
  }

  /// 텍스트 메시지 전송
  Future<void> _sendMessage() async {
    String message = _messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    if (_isSending) {
      return;
    }

    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showSnackBar('로그인 정보가 없습니다.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      DocumentReference<Map<String, dynamic>> chatDocument =
      FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.studyId);

      DocumentReference<Map<String, dynamic>> messageDocument =
      await chatDocument.collection('messages').add({
        'senderUid': currentUser.uid,
        'senderNickname': _myNickname,
        'senderProfileImageUrl': _myProfileImageUrl,
        'message': message,
        'messageType': 'TEXT',
        'replyMessageId': _replyMessageId,
        'replySenderNickname': _replySenderNickname,
        'replyMessage': _replyMessage,
        'readBy': [currentUser.uid],
        'hiddenFor': [],
        'isDeleted': false,
        'isEdited': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await chatDocument.set({
        'chatType': 'GROUP',
        'groupId': widget.studyId,
        'groupName': widget.groupName,
        'lastMessage': message,
        'lastMessageId': messageDocument.id,
        'lastSenderUid': currentUser.uid,
        'lastSenderNickname': _myNickname,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _messageController.clear();

      if (mounted) {
        setState(() {
          _replyMessageId = '';
          _replySenderNickname = '';
          _replyMessage = '';
        });
      }
    } catch (error) {
      debugPrint('메시지 전송 오류: $error');
      _showSnackBar('메시지를 보내지 못했습니다.');
    }

    if (mounted) {
      setState(() {
        _isSending = false;
      });
    }
  }

  /// 채팅방을 보고 있는 사용자의 읽음 처리
  Future<void> _markMessagesAsRead(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> messageList,
      ) async {
    if (_isMarkingRead) {
      return;
    }

    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    _isMarkingRead = true;

    try {
      for (int i = 0; i < messageList.length; i++) {
        QueryDocumentSnapshot<Map<String, dynamic>> messageDocument =
        messageList[i];

        Map<String, dynamic> messageData = messageDocument.data();

        String senderUid = messageData['senderUid']?.toString() ?? '';

        List<dynamic> readBy = [];

        if (messageData['readBy'] is List) {
          readBy = messageData['readBy'];
        }

        bool alreadyRead = readBy.contains(currentUser.uid);

        if (senderUid != currentUser.uid && alreadyRead == false) {
          await messageDocument.reference.update({
            'readBy': FieldValue.arrayUnion([currentUser.uid]),
          });
        }
      }
    } catch (error) {
      debugPrint('메시지 읽음 처리 오류: $error');
    }

    _isMarkingRead = false;
  }

  /// 메시지 복사
  Future<void> _copyMessage(String message) async {
    await Clipboard.setData(
      ClipboardData(text: message),
    );

    _showSnackBar('메시지를 복사했습니다.');
  }

  /// 내 메시지 수정창
  void _showEditMessageDialog(
      QueryDocumentSnapshot<Map<String, dynamic>> messageDocument,
      ) {
    Map<String, dynamic> messageData = messageDocument.data();

    TextEditingController editController = TextEditingController();
    editController.text = messageData['message']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('메시지 수정'),
          content: TextField(
            controller: editController,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: '수정할 내용을 입력하세요.',
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
                String editedMessage = editController.text.trim();

                if (editedMessage.isEmpty) {
                  _showSnackBar('메시지를 입력해주세요.');
                  return;
                }

                try {
                  await messageDocument.reference.update({
                    'message': editedMessage,
                    'isEdited': true,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  DocumentSnapshot<Map<String, dynamic>> chatSnapshot =
                  await FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.studyId)
                      .get();

                  Map<String, dynamic>? chatData = chatSnapshot.data();

                  if (chatData != null &&
                      chatData['lastMessageId'] == messageDocument.id) {
                    await chatSnapshot.reference.update({
                      'lastMessage': editedMessage,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  }

                  if (Navigator.canPop(dialogContext)) {
                    Navigator.pop(dialogContext);
                  }

                  _showSnackBar('메시지를 수정했습니다.');
                } catch (error) {
                  debugPrint('메시지 수정 오류: $error');
                  _showSnackBar('메시지를 수정하지 못했습니다.');
                }
              },
              child: Text('수정'),
            ),
          ],
        );
      },
    );
  }

  /// 나에게서만 삭제
  Future<void> _deleteMessageForMe(
      QueryDocumentSnapshot<Map<String, dynamic>> messageDocument,
      ) async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    try {
      await messageDocument.reference.update({
        'hiddenFor': FieldValue.arrayUnion([currentUser.uid]),
      });

      _showSnackBar('내 채팅방에서 삭제했습니다.');
    } catch (error) {
      debugPrint('나에게서만 삭제 오류: $error');
      _showSnackBar('메시지를 삭제하지 못했습니다.');
    }
  }

  /// 모두에게서 삭제 확인창
  void _showDeleteForEveryoneDialog(
      QueryDocumentSnapshot<Map<String, dynamic>> messageDocument,
      ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('모두에게서 삭제'),
          content: Text(
            '이 메시지를 모든 그룹원의 채팅방에서 삭제할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deleteMessageForEveryone(messageDocument);
              },
              child: Text(
                '삭제',
                style: TextStyle(
                  color: _studyColorScheme.error,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 모두에게서 삭제
  Future<void> _deleteMessageForEveryone(
      QueryDocumentSnapshot<Map<String, dynamic>> messageDocument,
      ) async {
    try {
      await messageDocument.reference.update({
        'message': '삭제된 메시지입니다.',
        'messageType': 'DELETED',
        'replyMessageId': '',
        'replySenderNickname': '',
        'replyMessage': '',
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      DocumentSnapshot<Map<String, dynamic>> chatSnapshot =
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.studyId)
          .get();

      Map<String, dynamic>? chatData = chatSnapshot.data();

      if (chatData != null &&
          chatData['lastMessageId'] == messageDocument.id) {
        await chatSnapshot.reference.update({
          'lastMessage': '삭제된 메시지입니다.',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      _showSnackBar('모두에게서 삭제했습니다.');
    } catch (error) {
      debugPrint('모두에게서 삭제 오류: $error');
      _showSnackBar('메시지를 삭제하지 못했습니다.');
    }
  }

  /// 메시지를 길게 눌렀을 때 메뉴
  void _showMessageMenu(
      QueryDocumentSnapshot<Map<String, dynamic>> messageDocument,
      ) {
    Map<String, dynamic> messageData = messageDocument.data();

    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    String senderUid = messageData['senderUid']?.toString() ?? '';
    String message = messageData['message']?.toString() ?? '';
    String messageType = messageData['messageType']?.toString() ?? 'TEXT';

    bool isMyMessage = senderUid == currentUser.uid;
    bool isDeleted = messageData['isDeleted'] == true;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Visibility(
                visible: isDeleted == false,
                child: ListTile(
                  leading: Icon(Icons.reply_rounded),
                  title: Text('답장'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _selectReplyMessage(
                      messageDocument.id,
                      messageData,
                    );
                  },
                ),
              ),
              Visibility(
                visible: isDeleted == false && messageType == 'TEXT',
                child: ListTile(
                  leading: Icon(Icons.copy_rounded),
                  title: Text('복사'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _copyMessage(message);
                  },
                ),
              ),
              Visibility(
                visible: isMyMessage &&
                    isDeleted == false &&
                    messageType == 'TEXT',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('수정'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _showEditMessageDialog(messageDocument);
                  },
                ),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('나에게서만 삭제'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _deleteMessageForMe(messageDocument);
                },
              ),
              Visibility(
                visible: isMyMessage && isDeleted == false,
                child: ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: _studyColorScheme.error,
                  ),
                  title: Text(
                    '모두에게서 삭제',
                    style: TextStyle(
                      color: _studyColorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _showDeleteForEveryoneDialog(messageDocument);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 시간 표시
  String _formatTime(dynamic createdAt) {
    if (createdAt is! Timestamp) {
      return '';
    }

    DateTime dateTime = createdAt.toDate().toLocal();

    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  /// 날짜 표시
  String _formatDate(dynamic createdAt) {
    if (createdAt is! Timestamp) {
      return '';
    }

    DateTime dateTime = createdAt.toDate().toLocal();

    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일';
  }

  /// 같은 날짜인지 확인
  bool _isSameDate(dynamic first, dynamic second) {
    if (first is! Timestamp || second is! Timestamp) {
      return false;
    }

    DateTime firstDate = first.toDate().toLocal();
    DateTime secondDate = second.toDate().toLocal();

    if (firstDate.year != secondDate.year) {
      return false;
    }

    if (firstDate.month != secondDate.month) {
      return false;
    }

    if (firstDate.day != secondDate.day) {
      return false;
    }

    return true;
  }

  /// 닉네임 첫 글자
  String _getFirstLetter(String nickname) {
    if (nickname.isEmpty) {
      return '?';
    }

    return nickname.substring(0, 1).toUpperCase();
  }

  /// 프로필 이미지
  Widget _buildProfileImage(
      String nickname,
      String profileImageUrl,
      double radius,
      ) {
    if (profileImageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: _studyColors.lavender,
        backgroundImage: NetworkImage(profileImageUrl),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: _studyColors.lavender,
      child: Text(
        _getFirstLetter(nickname),
        style: TextStyle(
          color: _studyColors.pinkStart,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 활동 중인 그룹원 목록 만들기
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _getActiveMemberList(
      QuerySnapshot<Map<String, dynamic>>? memberSnapshot,
      ) {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> memberList = [];

    if (memberSnapshot == null) {
      return memberList;
    }

    for (int i = 0; i < memberSnapshot.docs.length; i++) {
      QueryDocumentSnapshot<Map<String, dynamic>> memberDocument =
      memberSnapshot.docs[i];

      Map<String, dynamic> memberData = memberDocument.data();

      String status = memberData['status']?.toString() ?? '';
      String role = memberData['role']?.toString() ?? 'MEMBER';

      if (status == 'ACTIVE' || role == 'OWNER') {
        memberList.add(memberDocument);
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

      String aNickname = a.data()['nickname']?.toString() ?? '';
      String bNickname = b.data()['nickname']?.toString() ?? '';

      return aNickname.compareTo(bNickname);
    });

    return memberList;
  }

  /// 읽음 상태 상세 보기
  void _showReadStatus(
      Map<String, dynamic> messageData,
      ) {
    List<dynamic> readBy = [];

    if (messageData['readBy'] is List) {
      readBy = messageData['readBy'];
    }

    String senderUid = messageData['senderUid']?.toString() ?? '';

    if (senderUid.isNotEmpty && readBy.contains(senderUid) == false) {
      readBy.add(senderUid);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: _studyColorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: 10),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: _studyColorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 17, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '메시지 읽음 상태',
                        style: TextStyle(
                          fontSize: 18,
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
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studyGroups')
                      .doc(widget.studyId)
                      .collection('members')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    memberList = _getActiveMemberList(snapshot.data);

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(18, 14, 18, 30),
                      itemCount: memberList.length,
                      itemBuilder: (context, index) {
                        QueryDocumentSnapshot<Map<String, dynamic>>
                        memberDocument = memberList[index];

                        Map<String, dynamic> memberData =
                        memberDocument.data();

                        String nickname =
                            memberData['nickname']?.toString() ?? '스터디원';

                        String profileImageUrl =
                            memberData['profileImageUrl']?.toString() ?? '';

                        bool isRead = readBy.contains(memberDocument.id);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _buildProfileImage(
                            nickname,
                            profileImageUrl,
                            21,
                          ),
                          title: Text(nickname),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isRead
                                    ? Icons.check_circle
                                    : Icons.schedule_rounded,
                                size: 18,
                                color: isRead
                                    ? _studyColorScheme.tertiary
                                    : _studyColors.textSecondary,
                              ),
                              SizedBox(width: 5),
                              Text(
                                isRead ? '읽음' : '안 읽음',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isRead
                                      ? _studyColorScheme.tertiary
                                      : _studyColors.textSecondary,
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

  /// 현재 그룹원 목록 보기
  void _showMemberList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: _studyColorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: 10),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: _studyColorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 17, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '그룹원 목록',
                        style: TextStyle(
                          fontSize: 18,
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
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studyGroups')
                      .doc(widget.studyId)
                      .collection('members')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    memberList = _getActiveMemberList(snapshot.data);

                    if (memberList.isEmpty) {
                      return Center(
                        child: Text('현재 활동 중인 그룹원이 없습니다.'),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(18, 14, 18, 30),
                      itemCount: memberList.length,
                      itemBuilder: (context, index) {
                        QueryDocumentSnapshot<Map<String, dynamic>>
                        memberDocument = memberList[index];

                        Map<String, dynamic> memberData =
                        memberDocument.data();

                        String nickname =
                            memberData['nickname']?.toString() ?? '스터디원';

                        String profileImageUrl =
                            memberData['profileImageUrl']?.toString() ?? '';

                        String role =
                            memberData['role']?.toString() ?? 'MEMBER';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _buildProfileImage(
                            nickname,
                            profileImageUrl,
                            23,
                          ),
                          title: Text(
                            nickname,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            role == 'OWNER' ? '방장' : '그룹원',
                          ),
                          trailing: Visibility(
                            visible: role == 'OWNER',
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _studyColors.pinkSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '방장',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _studyColors.pinkStart,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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

  /// 답장 미리보기
  Widget _buildReplyPreview(
      String replySenderNickname,
      String replyMessage,
      bool isMyMessage,
      ) {
    if (replyMessage.isEmpty) {
      return Container();
    }

    Color backgroundColor = _studyColorScheme.surface;
    Color lineColor = _studyColors.pinkStart;

    if (isMyMessage) {
      backgroundColor = _studyColors.pinkSoft;
      lineColor = _studyColors.pinkStart;
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 7),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            color: lineColor,
          ),
          SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  replySenderNickname,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: lineColor,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  replyMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: _studyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 메시지 아래 시간, 수정 여부, 읽음 상태
  Widget _buildMessageInfo(
      Map<String, dynamic> messageData,
      List<String> activeMemberUidList,
      bool isMyMessage,
      ) {
    dynamic createdAt = messageData['createdAt'];
    bool isEdited = messageData['isEdited'] == true;

    List<dynamic> readBy = [];

    if (messageData['readBy'] is List) {
      readBy = messageData['readBy'];
    }

    String senderUid = messageData['senderUid']?.toString() ?? '';

    if (senderUid.isNotEmpty && readBy.contains(senderUid) == false) {
      readBy.add(senderUid);
    }

    int unreadCount = 0;

    for (int i = 0; i < activeMemberUidList.length; i++) {
      if (readBy.contains(activeMemberUidList[i]) == false) {
        unreadCount++;
      }
    }

    String readText = '모두 읽음';

    if (unreadCount > 0) {
      readText = '안 읽음 $unreadCount';
    }

    return Column(
      crossAxisAlignment:
      isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Visibility(
          visible: isEdited,
          child: Text(
            '수정됨',
            style: TextStyle(
              fontSize: 9,
              color: _studyColors.textSecondary,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            _showReadStatus(messageData);
          },
          child: Text(
            readText,
            style: TextStyle(
              fontSize: 9,
              color: _studyColors.pinkStart,
            ),
          ),
        ),
        Text(
          _formatTime(createdAt),
          style: TextStyle(
            fontSize: 9,
            color: _studyColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// 메시지 말풍선
  Widget _buildMessageBubble(
      QueryDocumentSnapshot<Map<String, dynamic>> messageDocument,
      List<String> activeMemberUidList,
      ) {
    Map<String, dynamic> messageData = messageDocument.data();

    User? currentUser = FirebaseAuth.instance.currentUser;
    String currentUserUid = currentUser?.uid ?? '';

    String senderUid = messageData['senderUid']?.toString() ?? '';
    String senderNickname =
        messageData['senderNickname']?.toString() ?? '사용자';
    String senderProfileImageUrl =
        messageData['senderProfileImageUrl']?.toString() ?? '';
    String message = messageData['message']?.toString() ?? '';

    String replySenderNickname =
        messageData['replySenderNickname']?.toString() ?? '';
    String replyMessage = messageData['replyMessage']?.toString() ?? '';

    bool isMyMessage = senderUid == currentUserUid;
    bool isDeleted = messageData['isDeleted'] == true;

    Color bubbleColor = _studyColorScheme.surface;
    Color textColor = _studyColors.textPrimary;

    if (isMyMessage) {
      bubbleColor = _studyColors.pinkSoft;
      textColor = _studyColors.textPrimary;
    }

    Widget bubble = GestureDetector(
      onLongPress: () {
        _showMessageMenu(messageDocument);
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.66,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: isMyMessage
              ? null
              : Border.all(
            color: _studyColorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Visibility(
              visible: replyMessage.isNotEmpty && isDeleted == false,
              child: _buildReplyPreview(
                replySenderNickname,
                replyMessage,
                isMyMessage,
              ),
            ),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: isDeleted ? _studyColors.textSecondary : textColor,
                fontStyle:
                isDeleted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );

    if (isMyMessage) {
      return Padding(
        padding: EdgeInsets.only(
          left: 55,
          bottom: 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildMessageInfo(
              messageData,
              activeMemberUidList,
              true,
            ),
            SizedBox(width: 6),
            bubble,
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        right: 45,
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileImage(
            senderNickname,
            senderProfileImageUrl,
            18,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  senderNickname,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _studyColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(child: bubble),
                    SizedBox(width: 6),
                    _buildMessageInfo(
                      messageData,
                      activeMemberUidList,
                      false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 앱바 제목과 그룹원 수
  Widget _buildAppBarTitle() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('members')
          .snapshots(),
      builder: (context, snapshot) {
        List<QueryDocumentSnapshot<Map<String, dynamic>>> memberList =
        _getActiveMemberList(snapshot.data);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.groupName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _studyColors.textPrimary,
              ),
            ),
            Text(
              '${memberList.length}명 참여 중',
              style: TextStyle(
                fontSize: 11,
                color: _studyColors.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 채팅방 상단 공지
  Widget _buildNoticeArea() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .snapshots(),
      builder: (context, snapshot) {
        String notice = '';

        if (snapshot.data != null && snapshot.data!.data() != null) {
          notice = snapshot.data!.data()!['notice']?.toString() ?? '';
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: _studyColors.pinkSoft,
            border: Border(
              bottom: BorderSide(
                color: _studyColors.pinkSoft,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 21,
                color: _studyColors.pinkStart,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  notice.isEmpty ? '등록된 공지가 없습니다.' : notice,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: _studyColors.textSecondary,
                  ),
                ),
              ),
              Visibility(
                visible: _isOwner,
                child: TextButton(
                  onPressed: () {
                    _showNoticeDialog(notice);
                  },
                  child: Text(
                    notice.isEmpty ? '작성' : '수정',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 답장 중 표시
  Widget _buildReplyInputPreview() {
    if (_replyMessageId.isEmpty) {
      return Container();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 9, 8, 9),
      decoration: BoxDecoration(
        color: _studyColors.pinkSoft,
        border: Border(
          top: BorderSide(
            color: _studyColors.pinkSoft,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply_rounded,
            size: 20,
            color: _studyColors.pinkStart,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_replySenderNickname님에게 답장',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _studyColors.pinkStart,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _replyMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: _studyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _cancelReply,
            icon: Icon(
              Icons.close_rounded,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  /// 메시지 입력창
  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        9,
        12,
        MediaQuery.of(context).padding.bottom + 9,
      ),
      decoration: BoxDecoration(
        color: _studyColorScheme.surface,
        border: Border(
          top: BorderSide(
            color: _studyColorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              maxLength: 500,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요.',
                counterText: '',
                filled: true,
                fillColor: _studyColorScheme.surface,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 46,
            height: 46,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: _studyColors.pinkStart,
                foregroundColor: _studyColorScheme.onPrimary,
                shape: CircleBorder(),
              ),
              child: _isSending
                  ? SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _studyColorScheme.onPrimary,
                ),
              )
                  : Icon(
                Icons.send_rounded,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentUserUid =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppTopBar(
        title: widget.groupName,
        actions: [
          IconButton(
            tooltip: '그룹원 보기',
            onPressed: _showMemberList,
            icon: Icon(Icons.groups_outlined),
          ),
        ],
      ),
      body: AppMainBackground(
        applySafeArea: false,
        child: Column(
          children: [
            _buildNoticeArea(),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('studyGroups')
                    .doc(widget.studyId)
                    .collection('members')
                    .snapshots(),
                builder: (context, memberSnapshot) {
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  activeMemberList =
                  _getActiveMemberList(memberSnapshot.data);

                  List<String> activeMemberUidList = [];

                  for (int i = 0; i < activeMemberList.length; i++) {
                    activeMemberUidList.add(activeMemberList[i].id);
                  }

                  return StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(widget.studyId)
                        .collection('messages')
                        .orderBy(
                      'createdAt',
                      descending: true,
                    )
                        .limit(100)
                        .snapshots(),
                    builder: (context, messageSnapshot) {
                      if (messageSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return AppLoadingView(
                          message: '채팅 내용을 불러오는 중입니다.',
                        );
                      }

                      if (messageSnapshot.hasError) {
                        debugPrint(
                          '채팅 목록 오류: ${messageSnapshot.error}',
                        );

                        if (_isNetworkError(messageSnapshot.error)) {
                          return AppNetworkErrorView(
                            message: '인터넷 연결을 확인해 주세요.',
                            description:
                            '네트워크 연결 후 채팅 내용을 다시 불러와 주세요.',
                            onRetryPressed: _reloadChat,
                          );
                        }

                        return AppErrorView(
                          message: '채팅 내용을 불러오지 못했습니다.',
                          description: '잠시 후 다시 시도해 주세요.',
                          onRetryPressed: _reloadChat,
                        );
                      }

                      List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      allMessageList = [];

                      if (messageSnapshot.data != null) {
                        allMessageList =
                            messageSnapshot.data!.docs.toList();
                      }

                      if (allMessageList.isNotEmpty &&
                          _isMarkingRead == false) {
                        WidgetsBinding.instance.addPostFrameCallback((time) {
                          _markMessagesAsRead(allMessageList);
                        });
                      }

                      List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      visibleMessageList = [];

                      for (int i = 0; i < allMessageList.length; i++) {
                        Map<String, dynamic> messageData =
                        allMessageList[i].data();

                        List<dynamic> hiddenFor = [];

                        if (messageData['hiddenFor'] is List) {
                          hiddenFor = messageData['hiddenFor'];
                        }

                        if (hiddenFor.contains(currentUserUid) == false) {
                          visibleMessageList.add(allMessageList[i]);
                        }
                      }

                      if (visibleMessageList.isEmpty) {
                        return AppEmptyView(
                          message: '아직 작성된 메시지가 없습니다.',
                          description: '첫 메시지를 보내 대화를 시작해 보세요.',
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        padding: EdgeInsets.fromLTRB(
                          14,
                          15,
                          14,
                          15,
                        ),
                        itemCount: visibleMessageList.length,
                        itemBuilder: (context, index) {
                          QueryDocumentSnapshot<Map<String, dynamic>>
                          messageDocument =
                          visibleMessageList[index];

                          Map<String, dynamic> messageData =
                          messageDocument.data();

                          dynamic currentCreatedAt =
                          messageData['createdAt'];

                          bool showDate = false;

                          if (index == visibleMessageList.length - 1) {
                            showDate = true;
                          } else {
                            Map<String, dynamic> olderMessageData =
                            visibleMessageList[index + 1].data();

                            dynamic olderCreatedAt =
                            olderMessageData['createdAt'];

                            if (_isSameDate(
                              currentCreatedAt,
                              olderCreatedAt,
                            ) ==
                                false) {
                              showDate = true;
                            }
                          }

                          return Column(
                            children: [
                              Visibility(
                                visible: showDate,
                                child: Container(
                                  margin: EdgeInsets.only(
                                    top: 6,
                                    bottom: 15,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _studyColorScheme.outlineVariant,
                                    borderRadius:
                                    BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    _formatDate(currentCreatedAt),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _studyColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              _buildMessageBubble(
                                messageDocument,
                                activeMemberUidList,
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            _buildReplyInputPreview(),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }
}
