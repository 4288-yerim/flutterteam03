import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationSection {
  all('전체'),
  admin('운영'),
  certificate('자격증'),
  study('학습'),
  studyGroup('스터디'),
  community('커뮤니티'),
  friend('친구');

  const NotificationSection(this.label);

  final String label;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.category,
    required this.refType,
    required this.planDate,
    required this.studyId,
    required this.groupName,
    required this.postId,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? createdAt;
  final String category;
  final String? refType;
  final DateTime? planDate;
  final String? studyId;
  final String? groupName;
  final String? postId;

  bool get opensStudyPlan => category == 'STUDY' || refType == 'STUDY_PLAN';

  bool get opensStudyGroup =>
      refType == 'STUDY_ROOM' ||
      refType == 'STUDY_JOIN_REQUESTS' ||
      refType == 'STUDY_CHAT';

  bool get opensCommunityPost => refType == 'COMMUNITY_POST';

  bool get opensFriends => refType == 'FRIENDS';

  bool get isNavigable =>
      opensStudyPlan || opensStudyGroup || opensCommunityPost || opensFriends;

  NotificationSection? get section {
    switch (category.toUpperCase()) {
      case 'ADMIN':
        return NotificationSection.admin;
      case 'CERTIFICATE':
        return NotificationSection.certificate;
      case 'STUDY':
        return NotificationSection.study;
      case 'STUDY_GROUP':
        return NotificationSection.studyGroup;
      case 'COMMUNITY':
        return NotificationSection.community;
      case 'FRIEND':
      case 'FRIENDS':
        return NotificationSection.friend;
    }

    if (refType == 'STUDY_PLAN') {
      return NotificationSection.study;
    }
    if (opensStudyGroup) {
      return NotificationSection.studyGroup;
    }
    if (opensCommunityPost) {
      return NotificationSection.community;
    }
    if (opensFriends) {
      return NotificationSection.friend;
    }
    return null;
  }

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final createdAt = data['createdAt'];
    final planDate = data['planDate'];

    return AppNotification(
      id: document.id,
      title: data['title'] is String ? data['title'] as String : '',
      body: data['body'] is String ? data['body'] as String : '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      category: data['category'] is String ? data['category'] as String : '',
      refType: data['refType'] is String ? data['refType'] as String : null,
      planDate: _readPlanDate(planDate),
      studyId: data['studyId'] is String ? data['studyId'] as String : null,
      groupName: data['groupName'] is String
          ? data['groupName'] as String
          : null,
      postId: data['postId'] is String ? data['postId'] as String : null,
    );
  }

  static DateTime? _readPlanDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is! String) {
      return null;
    }

    final parsed = DateTime.tryParse(value);

    if (parsed == null) {
      return null;
    }

    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AppNotification>> watchNotifications(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AppNotification.fromFirestore)
              .where(
                (notification) =>
                    notification.title.isNotEmpty ||
                    notification.body.isNotEmpty,
              )
              .toList(growable: false),
        );
  }

  Stream<bool> watchHasNewNotifications(String uid) {
    late final StreamController<bool> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    notificationSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    settingsSubscription;
    DateTime? latestNotificationAt;
    DateTime? lastViewedAt;
    bool hasNotificationSnapshot = false;
    bool hasSettingsSnapshot = false;
    bool? lastEmittedValue;

    void emitStatus() {
      if (!hasNotificationSnapshot || !hasSettingsSnapshot) {
        return;
      }

      final latest = latestNotificationAt;
      final hasNew =
          latest != null &&
          (lastViewedAt == null || latest.isAfter(lastViewedAt!));

      if (!controller.isClosed && lastEmittedValue != hasNew) {
        lastEmittedValue = hasNew;
        controller.add(hasNew);
      }
    }

    controller = StreamController<bool>.broadcast(
      onListen: () {
        hasNotificationSnapshot = false;
        hasSettingsSnapshot = false;
        lastEmittedValue = null;
        notificationSubscription = _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .snapshots()
            .listen((snapshot) {
              hasNotificationSnapshot = true;
              latestNotificationAt = snapshot.docs.isEmpty
                  ? null
                  : _readTimestamp(snapshot.docs.first.data()['createdAt']);
              emitStatus();
            }, onError: controller.addError);

        settingsSubscription = _firestore
            .collection('users')
            .doc(uid)
            .collection('settings')
            .doc('app')
            .snapshots()
            .listen((snapshot) {
              hasSettingsSnapshot = true;
              lastViewedAt = _readTimestamp(
                snapshot.data()?['notificationLastViewedAt'],
              );
              emitStatus();
            }, onError: controller.addError);
      },
      onCancel: () async {
        await notificationSubscription?.cancel();
        await settingsSubscription?.cancel();
        notificationSubscription = null;
        settingsSubscription = null;
      },
    );

    return controller.stream;
  }

  Future<void> markNotificationsViewed(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('app')
        .set({
          'notificationLastViewedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  DateTime? _readTimestamp(Object? value) {
    return value is Timestamp ? value.toDate() : null;
  }
}
