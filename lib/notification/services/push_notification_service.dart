import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../community/community_post_detail.dart';
import '../../mypage/screens/friend_screen.dart';
import '../../mypage/screens/study_plan_screen.dart';
import '../../study/study_chat.dart';
import '../../study/study_join_requests.dart';
import '../../study/study_room.dart';
import '../screens/notification.dart';
import 'local_notification_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  String? _registeredUid;
  bool _initialized = false;
  bool _isUnregistering = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await LocalNotificationService.instance.initialize(
      onPayload: handlePayload,
    );
    await _requestPermission();
    await _configureForegroundNotification();
    _listenAuthState();
    _listenMessageOpened();

    _initialized = true;
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
  }

  void _listenAuthState() {
    _authSubscription?.cancel();

    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        await _tokenRefreshSubscription?.cancel();
        _tokenRefreshSubscription = null;
        await _removeCurrentToken();
        _registeredUid = null;
        return;
      }

      _isUnregistering = false;
      _registeredUid = user.uid;

      await _registerCurrentToken(user.uid);
      _listenTokenRefresh(user.uid);
    });
  }

  Future<void> _registerCurrentToken(String uid) async {
    try {
      final token = await _messaging.getToken();

      if (token == null || token.isEmpty) {
        return;
      }

      if (_isUnregistering || _registeredUid != uid) {
        return;
      }

      await _firestore.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (error, stackTrace) {
    }
  }

  void _listenTokenRefresh(String uid) {
    _tokenRefreshSubscription?.cancel();

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((
      newToken,
    ) async {
      try {
        if (_isUnregistering || _registeredUid != uid) {
          return;
        }

        await _firestore.collection('users').doc(uid).set({
          'fcmTokens': FieldValue.arrayUnion([newToken]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

      } catch (error, stackTrace) {
      }
    });
  }

  Future<void> unregisterCurrentDevice() async {
    _isUnregistering = true;
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;

    final uid = _registeredUid ?? _auth.currentUser?.uid;
    final token = await _messaging.getToken();

    if (uid != null && token != null && token.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await _messaging.deleteToken();
    _registeredUid = null;
  }

  Future<void> _removeCurrentToken() async {
    final uid = _registeredUid;

    if (uid == null) {
      return;
    }

    try {
      final token = await _messaging.getToken();

      if (token == null || token.isEmpty) {
        return;
      }

      await _firestore.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stackTrace) {
    }
  }

  Future<void> _configureForegroundNotification() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    _foregroundMessageSubscription?.cancel();

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((
      message,
    ) async {
      final title =
          message.notification?.title ??
          message.data['title']?.toString() ??
          '';

      final body =
          message.notification?.body ?? message.data['body']?.toString() ?? '';

      if (title.isEmpty && body.isEmpty) {
        return;
      }

      final refType = message.data['refType']?.toString();
      final planDate = message.data['planDate']?.toString();

      final payload = refType == null || refType.isEmpty
          ? null
          : jsonEncode({
              'refType': refType,
              'planDate': planDate ?? '',
              'studyId': message.data['studyId']?.toString() ?? '',
              'groupName': message.data['groupName']?.toString() ?? '',
              'postId': message.data['postId']?.toString() ?? '',
            });

      await LocalNotificationService.instance.showNotification(
        id:
            message.messageId?.hashCode ??
            DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
        title: title,
        body: body,
        payload: payload,
      );
    });
  }

  void _listenMessageOpened() {
    _messageOpenedSubscription?.cancel();

    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      _handleMessageNavigation(message);
    });
  }

  Future<void> handleInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage == null) {
      return;
    }

    _handleMessageNavigation(initialMessage);
  }

  void _handleMessageNavigation(RemoteMessage message) {
    final refType = message.data['refType']?.toString();
    final planDate = message.data['planDate']?.toString();

    if (refType == null || refType.isEmpty) {
      return;
    }

    handlePayload(
      jsonEncode({
        'refType': refType,
        'planDate': planDate ?? '',
        'studyId': message.data['studyId']?.toString() ?? '',
        'groupName': message.data['groupName']?.toString() ?? '',
        'postId': message.data['postId']?.toString() ?? '',
      }),
    );
  }

  void handlePayload(String payload) {
    if (payload.startsWith('{')) {
      _handleStructuredPayload(payload);
      return;
    }

    final separatorIndex = payload.indexOf(':');
    final refType = separatorIndex < 0
        ? payload
        : payload.substring(0, separatorIndex);
    final rawPlanDate = separatorIndex < 0
        ? ''
        : payload.substring(separatorIndex + 1);

    if (refType != 'STUDY_PLAN') {
      return;
    }

    final parsedDate = DateTime.tryParse(rawPlanDate);
    final initialDate = parsedDate == null
        ? DateTime.now()
        : DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;

      if (navigator == null) {
        return;
      }

      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => StudyPlanScreen(initialDate: initialDate),
        ),
      );
    });
  }

  void _handleStructuredPayload(String payload) {
    final Object? decoded;

    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return;
    }

    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final refType = decoded['refType']?.toString() ?? '';
    final rawPlanDate = decoded['planDate']?.toString() ?? '';
    final studyId = decoded['studyId']?.toString() ?? '';
    final groupName = decoded['groupName']?.toString() ?? '';
    final postId = decoded['postId']?.toString() ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;
      if (navigator == null) {
        return;
      }

      if (refType == 'ADMIN_NOTIFICATION') {
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const NotificationPage(),
          ),
        );
        return;
      }

      if (refType == 'STUDY_PLAN') {
        final parsedDate = DateTime.tryParse(rawPlanDate);
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                StudyPlanScreen(initialDate: parsedDate ?? DateTime.now()),
          ),
        );
        return;
      }

      if (refType == 'COMMUNITY_POST') {
        if (postId.isEmpty) {
          return;
        }
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityPostDetailPage(postId: postId),
          ),
        );
        return;
      }

      if (refType == 'FRIENDS') {
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const FriendScreen()),
        );
        return;
      }

      if (studyId.isEmpty) {
        return;
      }

      Widget? destination;
      switch (refType) {
        case 'STUDY_ROOM':
          destination = StudyRoomPage(
            studyId: studyId,
            groupName: groupName.isEmpty ? '스터디' : groupName,
          );
        case 'STUDY_JOIN_REQUESTS':
          destination = StudyJoinRequestsPage(studyId: studyId);
        case 'STUDY_CHAT':
          destination = StudyChatPage(
            studyId: studyId,
            groupName: groupName.isEmpty ? '스터디' : groupName,
          );
      }

      if (destination != null) {
        navigator.push(MaterialPageRoute<void>(builder: (_) => destination!));
      }
    });
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();

    _initialized = false;
  }
}
