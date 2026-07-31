import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationSection {
  all('전체'),
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
}
