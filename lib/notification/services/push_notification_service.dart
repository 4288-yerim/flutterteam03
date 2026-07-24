import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'local_notification_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance =
  PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  String? _registeredUid;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await LocalNotificationService.instance.initialize();
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

    debugPrint(
      'FCM 알림 권한 상태: ${settings.authorizationStatus}',
    );
  }

  void _listenAuthState() {
    _authSubscription?.cancel();

    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        await _removeCurrentToken();
        _registeredUid = null;
        return;
      }

      _registeredUid = user.uid;

      await _registerCurrentToken(user.uid);
      _listenTokenRefresh(user.uid);
    });
  }

  Future<void> _registerCurrentToken(String uid) async {
    try {
      final token = await _messaging.getToken();

      if (token == null || token.isEmpty) {
        debugPrint('FCM 토큰을 가져오지 못했습니다.');
        return;
      }

      await _firestore.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('FCM 토큰 저장 완료');
      debugPrint('FCM token: $token');
    } catch (error, stackTrace) {
      debugPrint('FCM 토큰 저장 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _listenTokenRefresh(String uid) {
    _tokenRefreshSubscription?.cancel();

    _tokenRefreshSubscription =
        _messaging.onTokenRefresh.listen((newToken) async {
          try {
            await _firestore.collection('users').doc(uid).set({
              'fcmTokens': FieldValue.arrayUnion([newToken]),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            debugPrint('갱신된 FCM 토큰 저장 완료');
          } catch (error, stackTrace) {
            debugPrint('갱신된 FCM 토큰 저장 실패: $error');
            debugPrintStack(stackTrace: stackTrace);
          }
        });
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

      debugPrint('로그아웃 사용자 FCM 토큰 제거 완료');
    } catch (error, stackTrace) {
      debugPrint('로그아웃 사용자 FCM 토큰 제거 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _configureForegroundNotification() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    _foregroundMessageSubscription?.cancel();

    _foregroundMessageSubscription =
        FirebaseMessaging.onMessage.listen((message) async {
          final title =
              message.notification?.title ??
                  message.data['title']?.toString() ??
                  '';

          final body =
              message.notification?.body ??
                  message.data['body']?.toString() ??
                  '';

          if (title.isEmpty && body.isEmpty) {
            return;
          }

          final refType = message.data['refType']?.toString();
          final refId = message.data['refId']?.toString();

          final payload = refType == null || refType.isEmpty
              ? null
              : '$refType:${refId ?? ''}';

          await LocalNotificationService.instance.showNotification(
            id: message.messageId?.hashCode ??
                DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
            title: title,
            body: body,
            payload: payload,
          );
        });
  }

  void _listenMessageOpened() {
    _messageOpenedSubscription?.cancel();

    _messageOpenedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
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
    final refId = message.data['refId']?.toString();

    debugPrint(
      'FCM 알림 클릭: refType=$refType, refId=$refId',
    );

    // 실제 화면 이동은 각 화면 경로를 확인한 후 추가합니다.
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();

    _initialized = false;
  }
}