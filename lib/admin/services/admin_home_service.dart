import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminHomeService {
  AdminHomeService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  Future<AdminHomeData> fetchHomeData() async {
    final adminUid = _firebaseAuth.currentUser?.uid;
    if (adminUid == null) {
      throw StateError('관리자 로그인이 필요합니다.');
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final weekStart = todayStart.subtract(const Duration(days: 6));

    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    final results = await Future.wait<dynamic>([
      // 0. 미처리 신고
      _firestore
          .collection('reports')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get(),

      // 1. 오늘 접수된 신고
      _firestore
          .collection('reports')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(tomorrowStart))
          .count()
          .get(),

      // 2. 오늘 가입한 회원
      _firestore
          .collection('users')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(tomorrowStart))
          .get(),

      // 3. 미답변 문의
      _firestore
          .collection('inquiries')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get(),

      // 4. 오늘 접수된 문의
      _firestore
          .collection('inquiries')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(tomorrowStart))
          .count()
          .get(),

      // 5. 최근 7일 신고
      _firestore
          .collection('reports')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(tomorrowStart))
          .get(),

      // 6. 최근 7일 문의
      _firestore
          .collection('inquiries')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(tomorrowStart))
          .get(),

      // 7. 현재 로그인한 관리자 정보
      _firestore.collection('users').doc(adminUid).get(),

      // 8. 오늘 처리한 신고
      _firestore
          .collection('reports')
          .where(
            'processedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .where('processedAt', isLessThan: Timestamp.fromDate(tomorrowStart))
          .count()
          .get(),
    ]);

    final pendingReportCount =
        (results[0] as AggregateQuerySnapshot).count ?? 0;

    final todayReportCount = (results[1] as AggregateQuerySnapshot).count ?? 0;

    final todayNewMemberCount = _userCount(
      results[2] as QuerySnapshot<Map<String, dynamic>>,
    );

    final pendingInquiryCount =
        (results[3] as AggregateQuerySnapshot).count ?? 0;

    final todayInquiryCount = (results[4] as AggregateQuerySnapshot).count ?? 0;

    final weeklyReports = results[5] as QuerySnapshot<Map<String, dynamic>>;

    final weeklyInquiries = results[6] as QuerySnapshot<Map<String, dynamic>>;

    final administratorDocument =
        results[7] as DocumentSnapshot<Map<String, dynamic>>;
    final administratorName = _text(
      administratorDocument.data()?['nickname'],
      fallback: '관리자',
    );

    final todayProcessedReportCount =
        (results[8] as AggregateQuerySnapshot).count ?? 0;

    final weeklyReportCount = weeklyReports.docs.length;
    final processedReportCount = weeklyReports.docs.where((document) {
      final status = document.data()['status']?.toString().toUpperCase() ?? '';

      return status == 'RESOLVED' || status == 'REJECTED';
    }).length;

    final weeklyInquiryCount = weeklyInquiries.docs.length;
    final answeredInquiryCount = weeklyInquiries.docs.where((document) {
      final status = document.data()['status']?.toString().toUpperCase() ?? '';

      return status == 'ANSWERED';
    }).length;

    final reportProcessRate = weeklyReportCount == 0
        ? 0.0
        : processedReportCount / weeklyReportCount;

    final inquiryAnswerRate = weeklyInquiryCount == 0
        ? 0.0
        : answeredInquiryCount / weeklyInquiryCount;

    return AdminHomeData(
      administratorName: administratorName,
      todayLabel:
          '${now.year}.${_twoDigits(now.month)}.${_twoDigits(now.day)} '
          '${weekdays[now.weekday - 1]}요일',
      pendingReportCount: pendingReportCount,
      pendingInquiryCount: pendingInquiryCount,
      metrics: [
        AdminMetric(
          label: '신규 회원',
          value: '$todayNewMemberCount명',
          comparison: '오늘 가입한 신규 회원 수',
          icon: Icons.person_add_alt_1_rounded,
          color: const Color(0xFF5E72E4),
        ),
        AdminMetric(
          label: '오늘 신고 처리',
          value: '$todayProcessedReportCount건',
          comparison: '오늘 승인 또는 반려한 신고',
          icon: Icons.task_alt_rounded,
          color: const Color(0xFF8E66D5),
        ),
        AdminMetric(
          label: '오늘 신고 건수',
          value: '$todayReportCount건',
          comparison: '오늘 접수된 신고',
          icon: Icons.report_problem_rounded,
          color: const Color(0xFFE85D68),
        ),
        AdminMetric(
          label: '오늘 문의 건수',
          value: '$todayInquiryCount건',
          comparison: '오늘 접수된 문의',
          icon: Icons.mark_unread_chat_alt_rounded,
          color: const Color(0xFFE59831),
        ),
      ],
      weeklyStatuses: [
        AdminWeeklyStatus(
          label: '신고 처리율',
          value: reportProcessRate,
          detail: '$processedReportCount / $weeklyReportCount건',
        ),
        AdminWeeklyStatus(
          label: '문의 응답률',
          value: inquiryAnswerRate,
          detail: '$answeredInquiryCount / $weeklyInquiryCount건',
        ),
      ],
    );
  }

  int _userCount(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.where((document) {
      return document.data()['role']?.toString().toUpperCase() == 'USER';
    }).length;
  }

  String _text(Object? value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class AdminHomeData {
  const AdminHomeData({
    required this.administratorName,
    required this.todayLabel,
    required this.pendingReportCount,
    required this.pendingInquiryCount,
    required this.metrics,
    required this.weeklyStatuses,
  });

  final String administratorName;
  final String todayLabel;
  final int pendingReportCount;
  final int pendingInquiryCount;
  final List<AdminMetric> metrics;
  final List<AdminWeeklyStatus> weeklyStatuses;
}

class AdminMetric {
  const AdminMetric({
    required this.label,
    required this.value,
    required this.comparison,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String comparison;
  final IconData icon;
  final Color color;
}

class AdminWeeklyStatus {
  const AdminWeeklyStatus({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final double value;
  final String detail;
}
