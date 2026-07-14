import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_main_background.dart';

class StudyChatPage extends StatefulWidget {
  final String studyId;
  final String groupName;

  const StudyChatPage({
    super.key,
    required this.studyId,
    required this.groupName,
  });

  @override
  State<StudyChatPage> createState() => _StudyChatPageState();
}

class _StudyChatPageState extends State<StudyChatPage> {
  final TextEditingController _messageController =
  TextEditingController();

  bool _isSending = false;

  @override
  void initState() {
    super.initState();

    // 채팅방 문서가 없으면 처음 한 번 생성
    _createChatRoom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// 채팅방 문서 생성
  Future<void> _createChatRoom() async {
    try {
      final chatDocument = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.studyId);

      final chatSnapshot = await chatDocument.get();

      if (!chatSnapshot.exists) {
        await chatDocument.set({
          'chatType': 'GROUP',
          'groupId': widget.studyId,
          'groupName': widget.groupName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      debugPrint('채팅방 생성 오류: $error');
    }
  }

  /// 메시지 전송
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();

    if (message.isEmpty || _isSending) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 정보가 없습니다.'),
        ),
      );

      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final senderNickname =
      currentUser.displayName?.trim().isNotEmpty == true
          ? currentUser.displayName!.trim()
          : '익명 사용자';

      final chatDocument = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.studyId);

      await chatDocument
          .collection('messages')
          .add({
        'senderUid': currentUser.uid,
        'senderNickname': senderNickname,
        'message': message,
        'messageType': 'TEXT',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await chatDocument.set({
        'chatType': 'GROUP',
        'groupId': widget.studyId,
        'groupName': widget.groupName,
        'lastMessage': message,
        'lastSenderUid': currentUser.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _messageController.clear();
    } catch (error) {
      debugPrint('메시지 전송 오류: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('메시지를 보내지 못했습니다.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  /// 메시지 전송 시간 표시
  String _formatTime(dynamic createdAt) {
    if (createdAt is! Timestamp) {
      return '';
    }

    final dateTime = createdAt.toDate().toLocal();

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute =
    dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  /// 메시지 말풍선
  Widget _buildMessageBubble(
      Map<String, dynamic> messageData,
      ) {
    final currentUserUid =
        FirebaseAuth.instance.currentUser?.uid;

    final senderUid =
        messageData['senderUid']?.toString() ?? '';

    final senderNickname =
        messageData['senderNickname']?.toString() ??
            '사용자';

    final message =
        messageData['message']?.toString() ?? '';

    final createdAt = messageData['createdAt'];

    final isMyMessage =
        currentUserUid != null &&
            currentUserUid == senderUid;

    return Align(
      alignment: isMyMessage
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: isMyMessage
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMyMessage)
              Padding(
                padding: const EdgeInsets.only(
                  left: 4,
                  bottom: 5,
                ),
                child: Text(
                  senderNickname,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF696E78),
                  ),
                ),
              ),

            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [
                if (isMyMessage) ...[
                  Text(
                    _formatTime(createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF92969F),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth:
                      MediaQuery.of(context).size.width *
                          0.68,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isMyMessage
                          ? const Color(0xFF8068D8)
                          : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft:
                        const Radius.circular(16),
                        topRight:
                        const Radius.circular(16),
                        bottomLeft: Radius.circular(
                          isMyMessage ? 16 : 4,
                        ),
                        bottomRight: Radius.circular(
                          isMyMessage ? 4 : 16,
                        ),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: isMyMessage
                            ? Colors.white
                            : const Color(0xFF33353B),
                      ),
                    ),
                  ),
                ),

                if (!isMyMessage) ...[
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF92969F),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 메시지 입력창
  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              textInputAction:
              TextInputAction.newline,
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요',
                filled: true,
                fillColor: const Color(0xFFF5F3FA),
                contentPadding:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(width: 9),

          SizedBox(
            width: 46,
            height: 46,
            child: ElevatedButton(
              onPressed:
              _isSending ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor:
                const Color(0xFF8068D8),
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
              ),
              child: _isSending
                  ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(
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
    return Scaffold(
      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        title: Text(widget.groupName),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),

      body: AppMainBackground(
        applySafeArea: false,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<
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
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child:
                      CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    debugPrint(
                      '채팅 목록 오류: ${snapshot.error}',
                    );

                    return const Center(
                      child: Text(
                        '채팅 내용을 불러오지 못했습니다.',
                      ),
                    );
                  }

                  final messageList =
                      snapshot.data?.docs ?? [];

                  if (messageList.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 45,
                            color: Color(0xFFAAAEB7),
                          ),
                          SizedBox(height: 14),
                          Text(
                            '아직 작성된 메시지가 없습니다.',
                            style: TextStyle(
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '첫 메시지를 보내보세요.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF858994),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      20,
                      18,
                      20,
                    ),
                    itemCount: messageList.length,
                    itemBuilder: (context, index) {
                      final messageData =
                      messageList[index].data();

                      return _buildMessageBubble(
                        messageData,
                      );
                    },
                  );
                },
              ),
            ),

            _buildMessageInput(),
          ],
        ),
      ),
    );
  }
}