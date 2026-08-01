import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminHomeService {
  AdminHomeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<AdminHomeData> fetchHomeData() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    final results = await Future.wait<dynamic>([
      _firestore
          .collection('reports')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get(),
      _firestore
          .collection('reports')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(tomorrowStart))
          .count()
          .get(),
      _firestore
          .collection('users')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(tomorrowStart))
          .get(),
    ]);

    final pendingReportCount =
        (results[0] as AggregateQuerySnapshot).count ?? 0;
    final todayReportCount =
        (results[1] as AggregateQuerySnapshot).count ?? 0;
    final todayNewMemberCount = _userCount(
      results[2] as QuerySnapshot<Map<String, dynamic>>,
    );

    return AdminHomeData(
      administratorName: '관리자',
      todayLabel:
          '${now.year}.${_twoDigits(now.month)}.${_twoDigits(now.day)} '
          '${weekdays[now.weekday - 1]}요일',
      pendingReportCount: pendingReportCount,
      pendingInquiryCount: 7,
      metrics: [
        AdminMetric(
          label: '신규 회원',
          value: '$todayNewMemberCount명',
          comparison: '오늘 가입한 신규 회원 수',
          icon: Icons.person_add_alt_1_rounded,
          color: const Color(0xFF5E72E4),
        ),
        const AdminMetric(
          label: 'chatbot 사용 건수',
          value: '38개',
          comparison: '오늘 chatbot 사용 건수',
          icon: Icons.smart_toy_rounded,
          color: Color(0xFF8E66D5),
        ),
        AdminMetric(
          label: '오늘 신고 건수',
          value: '$todayReportCount건',
          comparison: '오늘 접수된 신고',
          icon: Icons.report_problem_rounded,
          color: const Color(0xFFE85D68),
        ),
        const AdminMetric(
          label: '오늘 문의 건수',
          value: '7건',
          comparison: '오늘 접수된 문의',
          icon: Icons.mark_unread_chat_alt_rounded,
          color: Color(0xFFE59831),
        ),
      ],
      weeklyStatuses: const [
        AdminWeeklyStatus(label: '신고 처리율', value: 0.78, detail: '35 / 45건'),
        AdminWeeklyStatus(label: '문의 응답률', value: 0.86, detail: '43 / 50건'),
      ],
    );
  }

  int _userCount(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.where((document) {
      return document.data()['role']?.toString().toUpperCase() == 'USER';
    }).length;
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
