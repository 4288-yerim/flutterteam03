import 'package:cloud_firestore/cloud_firestore.dart';

class AdminStatisticsService {
  AdminStatisticsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<AdminStatisticsData> fetchStatistics() async {
    final results = await Future.wait([
      _firestore.collection('users').get(),
      _firestore.collection('posts').get(),
      _firestore.collection('reports').get(),
      _firestore.collection('inquiries').get(),
      _firestore.collection('notices').get(),
      _firestore.collection('studyGroups').get(),
    ]);

    final users = results[0].docs;
    final posts = results[1].docs;
    final reports = results[2].docs;
    final inquiries = results[3].docs;
    final notices = results[4].docs;
    final groups = results[5].docs;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final members = users.where(
      (document) => _text(document.data()['role']).toUpperCase() == 'USER',
    );
    final activeMembers = members.where(
      (document) =>
          _text(document.data()['status'], fallback: 'ACTIVE').toUpperCase() ==
          'ACTIVE',
    );
    final visiblePosts = posts.where((document) {
      final data = document.data();
      return _text(data['postStatus'], fallback: 'NORMAL').toUpperCase() ==
              'NORMAL' &&
          _text(data['visibility'], fallback: 'PUBLIC').toUpperCase() ==
              'PUBLIC';
    });

    return AdminStatisticsData(
      totalMembers: members.length,
      activeMembers: activeMembers.length,
      todayMembers: members.where((document) {
        return _isSameDay(_date(document.data()['createdAt']), today);
      }).length,
      totalPosts: posts.length,
      visiblePosts: visiblePosts.length,
      hiddenPosts: posts.length - visiblePosts.length,
      totalComments: posts.fold<int>(
        0,
        (total, document) => total + _integer(document.data()['commentCount']),
      ),
      pendingReports: reports.where((document) {
        return _text(
              document.data()['status'],
              fallback: 'PENDING',
            ).toUpperCase() ==
            'PENDING';
      }).length,
      processedReportsToday: reports.where((document) {
        return _isSameDay(_date(document.data()['processedAt']), today);
      }).length,
      pendingInquiries: inquiries.where((document) {
        return _text(
              document.data()['status'],
              fallback: 'PENDING',
            ).toUpperCase() ==
            'PENDING';
      }).length,
      publishedNotices: notices.where((document) {
        return _text(document.data()['status']).toUpperCase() == 'PUBLISHED';
      }).length,
      totalStudyGroups: groups.length,
      totalStudyMembers: groups.fold<int>(
        0,
        (total, document) =>
            total + _integer(document.data()['currentMemberCount']),
      ),
      dailyActivity: List.generate(7, (index) {
        final day = today.subtract(Duration(days: 6 - index));
        return AdminDailyActivity(
          date: day,
          members: members.where((document) {
            return _isSameDay(_date(document.data()['createdAt']), day);
          }).length,
          posts: posts.where((document) {
            return _isSameDay(_date(document.data()['createdAt']), day);
          }).length,
          reports: reports.where((document) {
            return _isSameDay(_date(document.data()['createdAt']), day);
          }).length,
          inquiries: inquiries.where((document) {
            return _isSameDay(_date(document.data()['createdAt']), day);
          }).length,
        );
      }),
      loadedAt: now,
    );
  }
}

class AdminStatisticsData {
  const AdminStatisticsData({
    required this.totalMembers,
    required this.activeMembers,
    required this.todayMembers,
    required this.totalPosts,
    required this.visiblePosts,
    required this.hiddenPosts,
    required this.totalComments,
    required this.pendingReports,
    required this.processedReportsToday,
    required this.pendingInquiries,
    required this.publishedNotices,
    required this.totalStudyGroups,
    required this.totalStudyMembers,
    required this.dailyActivity,
    required this.loadedAt,
  });

  final int totalMembers;
  final int activeMembers;
  final int todayMembers;
  final int totalPosts;
  final int visiblePosts;
  final int hiddenPosts;
  final int totalComments;
  final int pendingReports;
  final int processedReportsToday;
  final int pendingInquiries;
  final int publishedNotices;
  final int totalStudyGroups;
  final int totalStudyMembers;
  final List<AdminDailyActivity> dailyActivity;
  final DateTime loadedAt;
}

class AdminDailyActivity {
  const AdminDailyActivity({
    required this.date,
    required this.members,
    required this.posts,
    required this.reports,
    required this.inquiries,
  });

  final DateTime date;
  final int members;
  final int posts;
  final int reports;
  final int inquiries;

  int get total => members + posts + reports + inquiries;
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

bool _isSameDay(DateTime? value, DateTime day) {
  if (value == null) return false;
  final local = value.toLocal();
  return local.year == day.year &&
      local.month == day.month &&
      local.day == day.day;
}
