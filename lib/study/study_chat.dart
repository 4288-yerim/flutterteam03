import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterteam03/widgets/app_state_views.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'study_quiz.dart';

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
  final TextEditingController _messageController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  late Stream<QuerySnapshot<Map<String, dynamic>>> _memberStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _messageStream;

  bool _isSending = false;
  bool _isUploadingImage = false;
  bool _isUploadingFile = false;
  bool _isMarkingRead = false;
  bool _isOwner = false;

  double _uploadProgress = 0;

  String _myNickname = '사용자';
  String _myProfileImageUrl = '';

  String _replyMessageId = '';
  String _replySenderNickname = '';
  String _replyMessage = '';
  String _pendingMessageId = '';
  String _pendingMessage = '';
  String _pendingReplySenderNickname = '';
  String _pendingReplyMessage = '';

  @override
  void initState() {
    super.initState();

    _initializeChatStreams();

    _createChatRoom();
    _loadMyMemberInfo();
    _recoverLostCameraImage();
  }

  void _initializeChatStreams() {
    _memberStream = FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(widget.studyId)
        .collection('members')
        .snapshots();
    _messageStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.studyId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  @override
  void dispose() {
    _messageController.dispose();

    super.dispose();
  }

  void _reloadChat() {
    setState(_initializeChatStreams);
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

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Map<String, String>> _getUserProfile(User currentUser) async {
    String nickname = '';
    String profileImageUrl = '';

    DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
        await FirebaseFirestore.instance
            .collection('studyGroups')
            .doc(widget.studyId)
            .collection('members')
            .doc(currentUser.uid)
            .get();

    if (memberSnapshot.exists) {
      Map<String, dynamic> memberData = memberSnapshot.data() ?? {};

      nickname = memberData['nickname']?.toString().trim() ?? '';

      profileImageUrl = memberData['profileImageUrl']?.toString().trim() ?? '';
    }

    if (nickname.isEmpty || profileImageUrl.isEmpty) {
      DocumentSnapshot<Map<String, dynamic>> directUserSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      Map<String, dynamic> userData = {};

      if (directUserSnapshot.exists) {
        userData = directUserSnapshot.data() ?? {};
      } else {
        QuerySnapshot<Map<String, dynamic>> userSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .where('uid', isEqualTo: currentUser.uid)
                .limit(1)
                .get();

        if (userSnapshot.docs.isNotEmpty) {
          userData = userSnapshot.docs.first.data();
        }
      }

      if (nickname.isEmpty) {
        nickname = userData['nickname']?.toString().trim() ?? '';
      }

      if (profileImageUrl.isEmpty) {
        profileImageUrl = userData['profileImageUrl']?.toString().trim() ?? '';

        if (profileImageUrl.isEmpty) {
          profileImageUrl = userData['photoUrl']?.toString().trim() ?? '';
        }
      }
    }

    if (nickname.isEmpty) {
      nickname = currentUser.displayName?.trim() ?? '';
    }

    if (profileImageUrl.isEmpty) {
      profileImageUrl = currentUser.photoURL?.trim() ?? '';
    }

    if (nickname.isEmpty) {
      nickname = '사용자';
    }

    return {'nickname': nickname, 'profileImageUrl': profileImageUrl};
  }

  Future<void> _createChatRoom() async {
    try {
      DocumentReference<Map<String, dynamic>> chatDocument = FirebaseFirestore
          .instance
          .collection('chats')
          .doc(widget.studyId);

      await chatDocument.set({
        'chatType': 'GROUP',
        'groupId': widget.studyId,
        'groupName': widget.groupName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('채팅방 생성 오류: $error');
    }
  }

  Future<void> _loadMyMemberInfo() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    try {
      Map<String, String> profile = await _getUserProfile(currentUser);

      DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
          await FirebaseFirestore.instance
              .collection('studyGroups')
              .doc(widget.studyId)
              .collection('members')
              .doc(currentUser.uid)
              .get();

      bool isOwner = false;

      if (memberSnapshot.exists) {
        String role = memberSnapshot.data()?['role']?.toString() ?? 'MEMBER';

        isOwner = role == 'OWNER';
      }

      if (!isOwner) {
        DocumentSnapshot<Map<String, dynamic>> groupSnapshot =
            await FirebaseFirestore.instance
                .collection('studyGroups')
                .doc(widget.studyId)
                .get();

        String ownerUid = groupSnapshot.data()?['ownerUid']?.toString() ?? '';

        isOwner = ownerUid == currentUser.uid;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _myNickname = profile['nickname'] ?? '사용자';

        _myProfileImageUrl = profile['profileImageUrl'] ?? '';

        _isOwner = isOwner;
      });
    } catch (error) {
      debugPrint('그룹원 정보 불러오기 오류: $error');
    }
  }

  void _showNoticeDialog(String currentNotice) {
    TextEditingController noticeController = TextEditingController(
      text: currentNotice,
    );

    String title = currentNotice.isEmpty ? '공지 작성' : '공지 수정';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: appDialogShape,
          title: AppDialogTitle(icon: Icons.campaign_outlined, title: title),
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
                FocusScope.of(dialogContext).unfocus();
                Navigator.pop(dialogContext);
              },
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                FocusScope.of(dialogContext).unfocus();
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

                  if (dialogContext.mounted) {
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
    ).whenComplete(() {
      Future<void>.delayed(
        const Duration(milliseconds: 400),
        noticeController.dispose,
      );
    });
  }

  String _getReplyText(Map<String, dynamic> messageData) {
    String messageType = messageData['messageType']?.toString() ?? 'TEXT';

    if (messageType == 'IMAGE') {
      return '사진';
    }

    if (messageType == 'FILE') {
      String fileName = messageData['fileName']?.toString() ?? '파일';

      return '파일: $fileName';
    }

    if (messageType == 'QUIZ') {
      String quizTitle = messageData['quizTitle']?.toString() ?? '발송 문제';

      return '퀴즈: $quizTitle';
    }

    return messageData['message']?.toString() ?? '';
  }

  void _selectReplyMessage(String messageId, Map<String, dynamic> messageData) {
    if (messageData['isDeleted'] == true) {
      return;
    }

    setState(() {
      _replyMessageId = messageId;

      _replySenderNickname = messageData['senderNickname']?.toString() ?? '사용자';

      _replyMessage = _getReplyText(messageData);
    });
  }

  void _cancelReply() {
    setState(() {
      _replyMessageId = '';
      _replySenderNickname = '';
      _replyMessage = '';
    });
  }

  Future<void> _updateChatLastMessage({
    required String messageId,
    required String lastMessage,
    required User currentUser,
  }) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.studyId)
        .set({
          'chatType': 'GROUP',
          'groupId': widget.studyId,
          'groupName': widget.groupName,
          'lastMessage': lastMessage,
          'lastMessageId': messageId,
          'lastSenderUid': currentUser.uid,
          'lastSenderNickname': _myNickname,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    String message = _messageController.text.trim();

    if (message.isEmpty ||
        _isSending ||
        _isUploadingImage ||
        _isUploadingFile) {
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
      DocumentReference<Map<String, dynamic>> chatDocument = FirebaseFirestore
          .instance
          .collection('chats')
          .doc(widget.studyId);

      DocumentReference<Map<String, dynamic>> messageDocument = chatDocument
          .collection('messages')
          .doc();

      String pendingReplyMessageId = _replyMessageId;
      String pendingReplySenderNickname = _replySenderNickname;
      String pendingReplyMessage = _replyMessage;

      setState(() {
        _pendingMessageId = messageDocument.id;
        _pendingMessage = message;
        _pendingReplySenderNickname = pendingReplySenderNickname;
        _pendingReplyMessage = pendingReplyMessage;
        _replyMessageId = '';
        _replySenderNickname = '';
        _replyMessage = '';
      });
      _messageController.clear();

      await messageDocument.set({
        'senderUid': currentUser.uid,
        'senderNickname': _myNickname,
        'senderProfileImageUrl': _myProfileImageUrl,
        'message': message,
        'messageType': 'TEXT',
        'imageUrl': '',
        'imagePath': '',
        'imageName': '',
        'fileUrl': '',
        'filePath': '',
        'fileName': '',
        'fileSize': 0,
        'replyMessageId': pendingReplyMessageId,
        'replySenderNickname': pendingReplySenderNickname,
        'replyMessage': pendingReplyMessage,
        'readBy': [currentUser.uid],
        'hiddenFor': [],
        'isDeleted': false,
        'isEdited': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _updateChatLastMessage(
        messageId: messageDocument.id,
        lastMessage: message,
        currentUser: currentUser,
      );
    } catch (error) {
      debugPrint('메시지 전송 오류: $error');

      _showSnackBar('메시지를 보내지 못했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _pendingMessageId = '';
          _pendingMessage = '';
          _pendingReplySenderNickname = '';
          _pendingReplyMessage = '';
        });
      }
    }
  }

  String _getFileExtension(String fileName) {
    int dotIndex = fileName.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return 'jpg';
    }

    String extension = fileName.substring(dotIndex + 1).toLowerCase();

    if (extension == 'jpeg') {
      return 'jpg';
    }

    if (extension != 'jpg' && extension != 'png' && extension != 'webp') {
      return 'jpg';
    }

    return extension;
  }

  String _getContentType(String extension) {
    if (extension == 'png') {
      return 'image/png';
    }

    if (extension == 'webp') {
      return 'image/webp';
    }

    return 'image/jpeg';
  }

  void _showImageSourceSheet() {
    if (_isSending || _isUploadingImage || _isUploadingFile) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: context.colors.pinkStart,
                ),
                title: Text('갤러리에서 선택'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);

                  _pickAndSendImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt_outlined,
                  color: context.colors.pinkStart,
                ),
                title: Text('카메라로 촬영'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);

                  _pickAndSendImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.attach_file_rounded,
                  color: context.colors.pinkStart,
                ),
                title: Text('파일 선택'),
                subtitle: Text('최대 20MB'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);

                  _pickAndSendFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _recoverLostCameraImage() async {
    try {
      LostDataResponse response = await _imagePicker.retrieveLostData();

      if (response.isEmpty) {
        return;
      }

      XFile? recoveredImage;

      if (response.files != null && response.files!.isNotEmpty) {
        recoveredImage = response.files!.first;
      } else if (response.file != null) {
        recoveredImage = response.file;
      }

      if (recoveredImage != null) {
        await _pickAndSendImage(
          ImageSource.camera,
          recoveredImage: recoveredImage,
        );
      } else if (response.exception != null) {
        debugPrint(
          '카메라 촬영 결과 복구 오류: '
          '${response.exception}',
        );
      }
    } catch (error) {
      debugPrint('카메라 촬영 결과 확인 오류: $error');
    }
  }

  Future<void> _pickAndSendImage(
    ImageSource source, {
    XFile? recoveredImage,
  }) async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showSnackBar('로그인 정보가 없습니다.');

      return;
    }

    XFile? pickedFile = recoveredImage;

    if (pickedFile == null) {
      try {
        pickedFile = await _imagePicker.pickImage(
          source: source,
          imageQuality: 75,
          maxWidth: 1600,
          maxHeight: 1600,
        );
      } catch (error) {
        debugPrint('사진 선택 오류: $error');

        _showSnackBar(
          source == ImageSource.camera
              ? '카메라 촬영 사진을 가져오지 못했습니다.'
              : '사진을 선택하지 못했습니다.',
        );

        return;
      }
    }

    if (pickedFile == null) {
      return;
    }

    Uint8List imageBytes;

    try {
      imageBytes = await pickedFile.readAsBytes();
    } catch (error) {
      debugPrint('사진 읽기 오류: $error');

      _showSnackBar('사진 파일을 읽지 못했습니다.');

      return;
    }

    if (imageBytes.lengthInBytes > 5 * 1024 * 1024) {
      _showSnackBar('사진은 5MB 이하만 보낼 수 있습니다.');

      return;
    }

    setState(() {
      _isUploadingImage = true;
      _uploadProgress = 0;
    });

    DocumentReference<Map<String, dynamic>> chatDocument = FirebaseFirestore
        .instance
        .collection('chats')
        .doc(widget.studyId);

    DocumentReference<Map<String, dynamic>> messageDocument = chatDocument
        .collection('messages')
        .doc();

    String extension = _getFileExtension(pickedFile.name);

    String storagePath =
        'study_chats/'
        '${widget.studyId}/'
        '${currentUser.uid}/'
        '${messageDocument.id}.$extension';

    Reference storageReference = FirebaseStorage.instance.ref().child(
      storagePath,
    );

    try {
      UploadTask uploadTask = storageReference.putData(
        imageBytes,
        SettableMetadata(
          contentType: _getContentType(extension),
          customMetadata: {
            'studyId': widget.studyId,
            'senderUid': currentUser.uid,
            'messageId': messageDocument.id,
          },
        ),
      );

      StreamSubscription<TaskSnapshot> subscription = uploadTask.snapshotEvents
          .listen((snapshot) {
            if (!mounted || snapshot.totalBytes == 0) {
              return;
            }

            setState(() {
              _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
            });
          });

      TaskSnapshot uploadSnapshot = await uploadTask;

      await subscription.cancel();

      String imageUrl = await uploadSnapshot.ref.getDownloadURL();

      await messageDocument.set({
        'senderUid': currentUser.uid,
        'senderNickname': _myNickname,
        'senderProfileImageUrl': _myProfileImageUrl,
        'message': '사진',
        'messageType': 'IMAGE',
        'imageUrl': imageUrl,
        'imagePath': storagePath,
        'imageName': pickedFile!.name,
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

      await _updateChatLastMessage(
        messageId: messageDocument.id,
        lastMessage: '사진',
        currentUser: currentUser,
      );

      if (mounted) {
        setState(() {
          _replyMessageId = '';
          _replySenderNickname = '';
          _replyMessage = '';
        });
      }
    } on FirebaseException catch (error) {
      debugPrint(
        '사진 업로드 오류: '
        '${error.code} / ${error.message}',
      );

      try {
        await storageReference.delete();
      } catch (_) {}

      if (error.code == 'unauthorized') {
        _showSnackBar('사진 업로드 권한이 없습니다. Storage 규칙을 확인해 주세요.');
      } else if (error.code == 'object-not-found') {
        _showSnackBar('사진 저장 위치를 찾지 못했습니다.');
      } else {
        _showSnackBar('사진을 보내지 못했습니다.');
      }
    } catch (error) {
      debugPrint('사진 메시지 전송 오류: $error');

      try {
        await storageReference.delete();
      } catch (_) {}

      _showSnackBar('사진을 보내지 못했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  String _getGeneralFileExtension(String fileName) {
    int dotIndex = fileName.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return 'file';
    }

    return fileName
        .substring(dotIndex + 1)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _getFileContentType(String extension) {
    if (extension == 'pdf') {
      return 'application/pdf';
    }

    if (extension == 'txt') {
      return 'text/plain';
    }

    if (extension == 'doc') {
      return 'application/msword';
    }

    if (extension == 'docx') {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }

    if (extension == 'xls') {
      return 'application/vnd.ms-excel';
    }

    if (extension == 'xlsx') {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }

    if (extension == 'ppt') {
      return 'application/vnd.ms-powerpoint';
    }

    if (extension == 'pptx') {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }

    if (extension == 'zip') {
      return 'application/zip';
    }

    return 'application/octet-stream';
  }

  Future<void> _pickAndSendFile() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showSnackBar('로그인 정보가 없습니다.');

      return;
    }

    FilePickerResult? result;

    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'hwp',
          'hwpx',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
          'zip',
        ],
        allowMultiple: false,
        withData: true,
      );
    } catch (error) {
      debugPrint('파일 선택 오류: $error');

      _showSnackBar('파일을 선택하지 못했습니다.');

      return;
    }

    if (result == null || result.files.isEmpty) {
      return;
    }

    PlatformFile pickedFile = result.files.single;

    Uint8List? fileBytes = pickedFile.bytes;

    if (fileBytes == null) {
      _showSnackBar('파일을 읽지 못했습니다.');

      return;
    }

    if (fileBytes.lengthInBytes > 20 * 1024 * 1024) {
      _showSnackBar('파일은 20MB 이하만 보낼 수 있습니다.');

      return;
    }

    setState(() {
      _isUploadingFile = true;
      _uploadProgress = 0;
    });

    DocumentReference<Map<String, dynamic>> chatDocument = FirebaseFirestore
        .instance
        .collection('chats')
        .doc(widget.studyId);

    DocumentReference<Map<String, dynamic>> messageDocument = chatDocument
        .collection('messages')
        .doc();

    String extension = _getGeneralFileExtension(pickedFile.name);

    String storagePath =
        'study_chats/'
        '${widget.studyId}/'
        '${currentUser.uid}/'
        '${messageDocument.id}_file.$extension';

    Reference storageReference = FirebaseStorage.instance.ref().child(
      storagePath,
    );

    try {
      UploadTask uploadTask = storageReference.putData(
        fileBytes,
        SettableMetadata(
          contentType: _getFileContentType(extension),
          customMetadata: {
            'studyId': widget.studyId,
            'senderUid': currentUser.uid,
            'messageId': messageDocument.id,
            'originalFileName': pickedFile.name,
          },
        ),
      );

      StreamSubscription<TaskSnapshot> subscription = uploadTask.snapshotEvents
          .listen((snapshot) {
            if (!mounted || snapshot.totalBytes == 0) {
              return;
            }

            setState(() {
              _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
            });
          });

      TaskSnapshot uploadSnapshot = await uploadTask;

      await subscription.cancel();

      String fileUrl = await uploadSnapshot.ref.getDownloadURL();

      await messageDocument.set({
        'senderUid': currentUser.uid,
        'senderNickname': _myNickname,
        'senderProfileImageUrl': _myProfileImageUrl,
        'message': pickedFile.name,
        'messageType': 'FILE',
        'imageUrl': '',
        'imagePath': '',
        'imageName': '',
        'fileUrl': fileUrl,
        'filePath': storagePath,
        'fileName': pickedFile.name,
        'fileSize': fileBytes.lengthInBytes,
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

      await _updateChatLastMessage(
        messageId: messageDocument.id,
        lastMessage: '파일: ${pickedFile.name}',
        currentUser: currentUser,
      );

      if (mounted) {
        setState(() {
          _replyMessageId = '';
          _replySenderNickname = '';
          _replyMessage = '';
        });
      }
    } on FirebaseException catch (error) {
      debugPrint(
        '파일 업로드 오류: '
        '${error.code} / ${error.message}',
      );

      try {
        await storageReference.delete();
      } catch (_) {}

      if (error.code == 'unauthorized') {
        _showSnackBar('파일 업로드 권한이 없습니다. Storage 규칙을 확인해 주세요.');
      } else {
        _showSnackBar('파일을 보내지 못했습니다.');
      }
    } catch (error) {
      debugPrint('파일 메시지 전송 오류: $error');

      try {
        await storageReference.delete();
      } catch (_) {}

      _showSnackBar('파일을 보내지 못했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFile = false;
          _uploadProgress = 0;
        });
      }
    }
  }

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
      WriteBatch batch = FirebaseFirestore.instance.batch();

      int updateCount = 0;

      for (int i = 0; i < messageList.length; i++) {
        QueryDocumentSnapshot<Map<String, dynamic>> messageDocument =
            messageList[i];

        Map<String, dynamic> messageData = messageDocument.data();

        String senderUid = messageData['senderUid']?.toString() ?? '';

        List<dynamic> readBy = [];

        if (messageData['readBy'] is List) {
          readBy = List<dynamic>.from(messageData['readBy']);
        }

        if (senderUid != currentUser.uid && !readBy.contains(currentUser.uid)) {
          batch.update(messageDocument.reference, {
            'readBy': FieldValue.arrayUnion([currentUser.uid]),
          });

          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
      }
    } catch (error) {
      debugPrint('메시지 읽음 처리 오류: $error');
    } finally {
      _isMarkingRead = false;
    }
  }

  Future<void> _copyMessage(String message) async {
    await Clipboard.setData(ClipboardData(text: message));

    _showSnackBar('메시지를 복사했습니다.');
  }

  void _showEditMessageDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> messageDocument,
  ) {
    Map<String, dynamic> messageData = messageDocument.data();

    TextEditingController editController = TextEditingController(
      text: messageData['message']?.toString() ?? '',
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: appDialogShape,
          title: AppDialogTitle(icon: Icons.edit_outlined, title: '메시지 수정'),
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
                FocusScope.of(dialogContext).unfocus();
                Navigator.pop(dialogContext);
              },
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                FocusScope.of(dialogContext).unfocus();
                String editedMessage = editController.text.trim();

                if (editedMessage.isEmpty) {
                  _showSnackBar('메시지를 입력해 주세요.');

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

                  if (chatSnapshot.data()?['lastMessageId'] ==
                      messageDocument.id) {
                    await chatSnapshot.reference.update({
                      'lastMessage': editedMessage,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  }

                  if (dialogContext.mounted) {
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
    ).whenComplete(() {
      Future<void>.delayed(
        const Duration(milliseconds: 400),
        editController.dispose,
      );
    });
  }

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

  void _showDeleteForEveryoneDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> messageDocument,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: appDialogShape,
          title: AppDialogTitle(
            icon: Icons.delete_outline,
            title: '모두에게서 삭제',
            isDestructive: true,
          ),
          content: Text('이 메시지를 모든 그룹원의 채팅방에서 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                _deleteMessageForEveryone(messageDocument);
              },
              child: Text(
                '삭제',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMessageForEveryone(
    QueryDocumentSnapshot<Map<String, dynamic>> messageDocument,
  ) async {
    Map<String, dynamic> messageData = messageDocument.data();

    String messageType = messageData['messageType']?.toString() ?? 'TEXT';

    String imagePath = messageData['imagePath']?.toString() ?? '';

    String filePath = messageData['filePath']?.toString() ?? '';

    try {
      if (messageType == 'IMAGE' && imagePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref().child(imagePath).delete();
        } catch (error) {
          debugPrint('Storage 사진 삭제 오류: $error');
        }
      }

      if (messageType == 'FILE' && filePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref().child(filePath).delete();
        } catch (error) {
          debugPrint('Storage 파일 삭제 오류: $error');
        }
      }

      await messageDocument.reference.update({
        'message': '삭제된 메시지입니다.',
        'messageType': 'DELETED',
        'imageUrl': '',
        'imagePath': '',
        'imageName': '',
        'fileUrl': '',
        'filePath': '',
        'fileName': '',
        'fileSize': 0,
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

      if (chatSnapshot.data()?['lastMessageId'] == messageDocument.id) {
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

    bool canReply = !isDeleted && messageType != 'DELETED';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canReply)
                ListTile(
                  leading: Icon(Icons.reply_rounded),
                  title: Text('답장'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);

                    _selectReplyMessage(messageDocument.id, messageData);
                  },
                ),
              if (!isDeleted && messageType == 'TEXT')
                ListTile(
                  leading: Icon(Icons.copy_rounded),
                  title: Text('복사'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);

                    _copyMessage(message);
                  },
                ),
              if (isMyMessage && !isDeleted && messageType == 'TEXT')
                ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('수정'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);

                    _showEditMessageDialog(messageDocument);
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('나에게서만 삭제'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);

                  _deleteMessageForMe(messageDocument);
                },
              ),
              if (isMyMessage && !isDeleted)
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    '모두에게서 삭제',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);

                    _showDeleteForEveryoneDialog(messageDocument);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(dynamic createdAt) {
    if (createdAt is! Timestamp) {
      return '';
    }

    DateTime dateTime = createdAt.toDate().toLocal();

    String hour = dateTime.hour.toString().padLeft(2, '0');

    String minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt is! Timestamp) {
      return '';
    }

    DateTime dateTime = createdAt.toDate().toLocal();

    return '${dateTime.year}년 '
        '${dateTime.month}월 '
        '${dateTime.day}일';
  }

  bool _isSameDate(dynamic first, dynamic second) {
    if (first is! Timestamp || second is! Timestamp) {
      return false;
    }

    DateTime firstDate = first.toDate().toLocal();

    DateTime secondDate = second.toDate().toLocal();

    return firstDate.year == secondDate.year &&
        firstDate.month == secondDate.month &&
        firstDate.day == secondDate.day;
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
    double radius,
  ) {
    if (profileImageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: context.colors.lavender,
        backgroundImage: NetworkImage(profileImageUrl),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: context.colors.lavender,
      child: Text(
        _getFirstLetter(nickname),
        style: TextStyle(
          color: context.colors.pinkStart,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

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

  void _showReadStatus(Map<String, dynamic> messageData) {
    List<dynamic> readBy = [];

    if (messageData['readBy'] is List) {
      readBy = List<dynamic>.from(messageData['readBy']);
    }

    String senderUid = messageData['senderUid']?.toString() ?? '';

    if (senderUid.isNotEmpty && !readBy.contains(senderUid)) {
      readBy.add(senderUid);
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0),
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              SizedBox(height: 10),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
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
                          color: context.colors.textPrimary,
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return AppLoadingView(message: '읽음 상태를 불러오는 중입니다.');
                    }

                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    memberList = _getActiveMemberList(snapshot.data);

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(18, 14, 18, 30),
                      itemCount: memberList.length,
                      itemBuilder: (context, index) {
                        QueryDocumentSnapshot<Map<String, dynamic>>
                        memberDocument = memberList[index];

                        Map<String, dynamic> memberData = memberDocument.data();

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
                                    ? Theme.of(context).colorScheme.tertiary
                                    : context.colors.textSecondary,
                              ),
                              SizedBox(width: 5),
                              Text(
                                isRead ? '읽음' : '안 읽음',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isRead
                                      ? Theme.of(context).colorScheme.tertiary
                                      : context.colors.textSecondary,
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

  void _showMemberList() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0),
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              SizedBox(height: 10),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
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
                          color: context.colors.textPrimary,
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return AppLoadingView(message: '그룹원을 불러오는 중입니다.');
                    }

                    if (snapshot.hasError) {
                      return AppErrorView(
                        message: '그룹원을 불러오지 못했습니다.',
                        description: '잠시 후 다시 시도해 주세요.',
                      );
                    }

                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    memberList = _getActiveMemberList(snapshot.data);

                    if (memberList.isEmpty) {
                      return AppEmptyView(
                        message: '현재 활동 중인 그룹원이 없습니다.',
                        description: '그룹원이 참여하면 표시됩니다.',
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(18, 14, 18, 30),
                      itemCount: memberList.length,
                      itemBuilder: (context, index) {
                        Map<String, dynamic> memberData = memberList[index]
                            .data();

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
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(role == 'OWNER' ? '방장' : '그룹원'),
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

  Widget _buildReplyPreview(
    String replySenderNickname,
    String replyMessage,
    bool isMyMessage,
  ) {
    if (replyMessage.isEmpty) {
      return SizedBox();
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 7),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMyMessage
            ? context.colors.pinkSoft
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: context.colors.pinkStart,
              borderRadius: BorderRadius.circular(3),
            ),
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
                    color: context.colors.pinkStart,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  replyMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInfo(
    Map<String, dynamic> messageData,
    List<String> activeMemberUidList,
    bool isMyMessage,
  ) {
    dynamic createdAt = messageData['createdAt'];

    bool isEdited = messageData['isEdited'] == true;

    List<dynamic> readBy = [];

    if (messageData['readBy'] is List) {
      readBy = List<dynamic>.from(messageData['readBy']);
    }

    String senderUid = messageData['senderUid']?.toString() ?? '';

    if (senderUid.isNotEmpty && !readBy.contains(senderUid)) {
      readBy.add(senderUid);
    }

    int unreadCount = 0;

    for (int i = 0; i < activeMemberUidList.length; i++) {
      if (!readBy.contains(activeMemberUidList[i])) {
        unreadCount++;
      }
    }

    String readText = unreadCount > 0 ? '안 읽음 $unreadCount' : '모두 읽음';

    return Column(
      crossAxisAlignment: isMyMessage
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (isEdited)
          Text(
            '수정됨',
            style: TextStyle(fontSize: 9, color: context.colors.textSecondary),
          ),
        GestureDetector(
          onTap: () {
            _showReadStatus(messageData);
          },
          child: Text(
            readText,
            style: TextStyle(fontSize: 9, color: context.colors.pinkStart),
          ),
        ),
        Text(
          _formatTime(createdAt),
          style: TextStyle(fontSize: 9, color: context.colors.textSecondary),
        ),
      ],
    );
  }

  void _showFullImage(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: EdgeInsets.all(16),
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.75,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(child: Text('사진을 불러오지 못했습니다.'));
                    },
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  icon: Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageMessage(String imageUrl) {
    return GestureDetector(
      onTap: imageUrl.isEmpty
          ? null
          : () {
              _showFullImage(imageUrl);
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: 140,
            maxWidth: 210,
            maxHeight: 280,
          ),
          color: context.colors.lavender,
          child: imageUrl.isEmpty
              ? Center(
                  child: Text(
                    '삭제된 사진입니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: context.colors.textSecondary,
                          ),
                          SizedBox(height: 6),
                          Text(
                            '사진을 불러오지 못했습니다.',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  String _formatFileSize(int fileSize) {
    if (fileSize < 1024) {
      return '$fileSize B';
    }

    if (fileSize < 1024 * 1024) {
      double sizeInKb = fileSize / 1024;

      return '${sizeInKb.toStringAsFixed(1)} KB';
    }

    double sizeInMb = fileSize / (1024 * 1024);

    return '${sizeInMb.toStringAsFixed(1)} MB';
  }

  Future<void> _openFile(String fileUrl) async {
    if (fileUrl.isEmpty) {
      _showSnackBar('파일 주소가 없습니다.');

      return;
    }

    try {
      bool opened = await launchUrl(
        Uri.parse(fileUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showSnackBar('파일을 열지 못했습니다.');
      }
    } catch (error) {
      debugPrint('파일 열기 오류: $error');

      _showSnackBar('파일을 열지 못했습니다.');
    }
  }

  Widget _buildFileMessage(String fileUrl, String fileName, int fileSize) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        _openFile(fileUrl);
      },
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: 240),
        padding: EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: context.colors.lavender,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.colors.pinkSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.insert_drive_file_outlined,
                color: context.colors.pinkStart,
              ),
            ),
            SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName.isEmpty ? '파일' : fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    fileSize > 0 ? _formatFileSize(fileSize) : '파일 열기',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 6),
            Icon(
              Icons.open_in_new_rounded,
              size: 19,
              color: context.colors.pinkStart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizMessage(Map<String, dynamic> messageData) {
    String quizTitle = messageData['quizTitle']?.toString() ?? '새 문제';

    String quizSubject = messageData['quizSubject']?.toString() ?? '과목 미지정';

    int timeLimitSeconds = 0;

    dynamic timeLimitValue = messageData['quizTimeLimitSeconds'];

    if (timeLimitValue is int) {
      timeLimitSeconds = timeLimitValue;
    } else if (timeLimitValue is num) {
      timeLimitSeconds = timeLimitValue.toInt();
    }

    String limitText = timeLimitSeconds < 60
        ? '$timeLimitSeconds초'
        : '${timeLimitSeconds ~/ 60}분';

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return StudyQuizPage(
                studyId: widget.studyId,
                groupName: widget.groupName,
              );
            },
          ),
        );
      },
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: 230),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.lavender,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.quiz_rounded,
                  color: context.colors.pinkStart,
                  size: 20,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '새 퀴즈',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.colors.pinkStart,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              quizTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: 7),
            Text(
              '$quizSubject · 제한시간 $limitText',
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textSecondary,
              ),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '문제 풀기',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: context.colors.pinkStart,
                  ),
                ),
                SizedBox(width: 3),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: context.colors.pinkStart,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    QueryDocumentSnapshot<Map<String, dynamic>> messageDocument,
    List<String> activeMemberUidList,
  ) {
    Map<String, dynamic> messageData = messageDocument.data();

    User? currentUser = FirebaseAuth.instance.currentUser;

    String currentUserUid = currentUser?.uid ?? '';

    String senderUid = messageData['senderUid']?.toString() ?? '';

    String senderNickname = messageData['senderNickname']?.toString() ?? '사용자';

    String senderProfileImageUrl =
        messageData['senderProfileImageUrl']?.toString() ?? '';

    String message = messageData['message']?.toString() ?? '';

    String messageType = messageData['messageType']?.toString() ?? 'TEXT';

    String imageUrl = messageData['imageUrl']?.toString() ?? '';

    String fileUrl = messageData['fileUrl']?.toString() ?? '';

    String fileName = messageData['fileName']?.toString() ?? '';

    int fileSize = 0;

    dynamic fileSizeValue = messageData['fileSize'];

    if (fileSizeValue is int) {
      fileSize = fileSizeValue;
    } else if (fileSizeValue is num) {
      fileSize = fileSizeValue.toInt();
    }

    String replySenderNickname =
        messageData['replySenderNickname']?.toString() ?? '';

    String replyMessage = messageData['replyMessage']?.toString() ?? '';

    bool isMyMessage = senderUid == currentUserUid;

    bool isDeleted = messageData['isDeleted'] == true;

    Color bubbleColor = isMyMessage
        ? context.colors.pinkSoft
        : Theme.of(context).colorScheme.surface;

    Widget messageContent;

    if (isDeleted || messageType == 'DELETED') {
      messageContent = Text(
        '삭제된 메시지입니다.',
        style: TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: context.colors.textSecondary,
        ),
      );
    } else if (messageType == 'IMAGE') {
      messageContent = _buildImageMessage(imageUrl);
    } else if (messageType == 'FILE') {
      messageContent = _buildFileMessage(fileUrl, fileName, fileSize);
    } else if (messageType == 'QUIZ') {
      messageContent = _buildQuizMessage(messageData);
    } else {
      messageContent = Text(
        message,
        style: TextStyle(
          fontSize: 14,
          height: 1.35,
          color: context.colors.textPrimary,
        ),
      );
    }

    Widget bubble = GestureDetector(
      onLongPress: () {
        _showMessageMenu(messageDocument);
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding:
            messageType == 'IMAGE' ||
                messageType == 'FILE' ||
                messageType == 'QUIZ'
            ? EdgeInsets.all(5)
            : EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: isMyMessage
              ? null
              : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replyMessage.isNotEmpty && !isDeleted)
              _buildReplyPreview(
                replySenderNickname,
                replyMessage,
                isMyMessage,
              ),
            messageContent,
          ],
        ),
      ),
    );

    if (isMyMessage) {
      return Padding(
        padding: EdgeInsets.only(left: 24, bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildMessageInfo(messageData, activeMemberUidList, true),
            SizedBox(width: 6),
            Flexible(child: bubble),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(right: 45, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileImage(senderNickname, senderProfileImageUrl, 18),
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
                    color: context.colors.textSecondary,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(child: bubble),
                    SizedBox(width: 6),
                    _buildMessageInfo(messageData, activeMemberUidList, false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingMessageBubble() {
    Widget bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.7,
      ),
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.pinkSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pendingReplyMessage.isNotEmpty)
            _buildReplyPreview(
              _pendingReplySenderNickname,
              _pendingReplyMessage,
              true,
            ),
          Text(
            _pendingMessage,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(left: 24, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: context.colors.pinkStart,
            ),
          ),
          SizedBox(width: 6),
          Flexible(child: bubble),
        ],
      ),
    );
  }

  Widget _buildNoticeArea() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .snapshots(),
      builder: (context, snapshot) {
        String notice = snapshot.data?.data()?['notice']?.toString() ?? '';

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: context.colors.pinkSoft,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 21,
                color: context.colors.pinkStart,
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
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              if (_isOwner)
                TextButton(
                  onPressed: () {
                    _showNoticeDialog(notice);
                  },
                  child: Text(
                    notice.isEmpty ? '작성' : '수정',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.pinkStart,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyInputPreview() {
    if (_replyMessageId.isEmpty) {
      return SizedBox();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(15, 10, 10, 9),
      decoration: BoxDecoration(
        color: context.colors.lavender,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, color: context.colors.pinkStart, size: 19),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_replySenderNickname 님에게 답장',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: context.colors.pinkStart,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _replyMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _cancelReply,
            icon: Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadProgress() {
    if (!_isUploadingImage && !_isUploadingFile) {
      return SizedBox();
    }

    int percent = (_uploadProgress * 100).round();

    return Container(
      padding: EdgeInsets.fromLTRB(15, 9, 15, 9),
      decoration: BoxDecoration(
        color: context.colors.lavender,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: 18,
                color: context.colors.pinkStart,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isUploadingFile ? '파일을 보내는 중입니다.' : '사진을 보내는 중입니다.',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: context.colors.pinkStart,
                ),
              ),
            ],
          ),
          SizedBox(height: 7),
          LinearProgressIndicator(
            value: _uploadProgress,
            minHeight: 6,
            backgroundColor: context.colors.pinkSoft,
            valueColor: AlwaysStoppedAnimation<Color>(context.colors.pinkStart),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        10,
        9,
        10,
        MediaQuery.of(context).padding.bottom + 9,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: '사진 또는 파일 보내기',
              onPressed: _isSending || _isUploadingImage || _isUploadingFile
                  ? null
                  : _showImageSourceSheet,
              icon: Icon(
                Icons.attach_file_rounded,
                color: context.colors.pinkStart,
              ),
            ),
          ),
          SizedBox(width: 5),
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
                fillColor: context.colors.lavender,
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
              onPressed: _isSending || _isUploadingImage || _isUploadingFile
                  ? null
                  : _sendMessage,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: context.colors.pinkStart,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: CircleBorder(),
              ),
              child: Icon(Icons.send_rounded, size: 21),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentUserUid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
                stream: _memberStream,
                builder: (context, memberSnapshot) {
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  activeMemberList = _getActiveMemberList(memberSnapshot.data);

                  List<String> activeMemberUidList = [];

                  for (int i = 0; i < activeMemberList.length; i++) {
                    activeMemberUidList.add(activeMemberList[i].id);
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _messageStream,
                    builder: (context, messageSnapshot) {
                      if (messageSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return AppLoadingView(message: '채팅 내용을 불러오는 중입니다.');
                      }

                      if (messageSnapshot.hasError) {
                        if (_isNetworkError(messageSnapshot.error)) {
                          return AppNetworkErrorView(
                            message: '인터넷 연결을 확인해 주세요.',
                            description: '네트워크 연결 후 채팅 내용을 다시 불러와 주세요.',
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
                      allMessageList =
                          messageSnapshot.data?.docs.toList() ?? [];

                      if (allMessageList.isNotEmpty && !_isMarkingRead) {
                        WidgetsBinding.instance.addPostFrameCallback((
                          timeStamp,
                        ) {
                          _markMessagesAsRead(allMessageList);
                        });
                      }

                      List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      visibleMessageList = [];

                      for (int i = 0; i < allMessageList.length; i++) {
                        Map<String, dynamic> messageData = allMessageList[i]
                            .data();

                        List<dynamic> hiddenFor = [];

                        if (messageData['hiddenFor'] is List) {
                          hiddenFor = messageData['hiddenFor'];
                        }

                        if (!hiddenFor.contains(currentUserUid) &&
                            allMessageList[i].id != _pendingMessageId) {
                          visibleMessageList.add(allMessageList[i]);
                        }
                      }

                      if (visibleMessageList.isEmpty &&
                          _pendingMessage.isEmpty) {
                        return AppEmptyView(
                          message: '아직 작성된 메시지가 없습니다.',
                          description: '첫 메시지나 사진을 보내 대화를 시작해 보세요.',
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        padding: EdgeInsets.fromLTRB(14, 15, 14, 15),
                        itemCount:
                            visibleMessageList.length +
                            (_pendingMessage.isEmpty ? 0 : 1),
                        itemBuilder: (context, index) {
                          if (_pendingMessage.isNotEmpty && index == 0) {
                            return _buildPendingMessageBubble();
                          }

                          int messageIndex =
                              index - (_pendingMessage.isEmpty ? 0 : 1);

                          QueryDocumentSnapshot<Map<String, dynamic>>
                          messageDocument = visibleMessageList[messageIndex];

                          Map<String, dynamic> messageData = messageDocument
                              .data();

                          dynamic currentCreatedAt = messageData['createdAt'];

                          bool showDate = false;

                          if (messageIndex == visibleMessageList.length - 1) {
                            showDate = true;
                          } else {
                            dynamic olderCreatedAt =
                                visibleMessageList[messageIndex + 1]
                                    .data()['createdAt'];

                            showDate = !_isSameDate(
                              currentCreatedAt,
                              olderCreatedAt,
                            );
                          }

                          return Column(
                            children: [
                              if (showDate)
                                Container(
                                  margin: EdgeInsets.only(top: 6, bottom: 15),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    _formatDate(currentCreatedAt),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: context.colors.textSecondary,
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
            _buildUploadProgress(),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }
}
