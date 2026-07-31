import 'package:flutter/material.dart';

class AdminHomeService {
  Future<AdminHomeData> fetchHomeData() async {
    // UI 확인용 샘플 데이터입니다. 추후 관리자 API 데이터로 교체합니다.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    return AdminHomeData(
      administratorName: '관리자',
      todayLabel:
          '${now.year}.${_twoDigits(now.month)}.${_twoDigits(now.day)} '
          '${weekdays[now.weekday - 1]}요일',
      pendingReportCount: 12,
      pendingInquiryCount: 7,
      metrics: const [
        AdminMetric(
          label: '신규 회원',
          value: '24명',
          comparison: '어제보다 8명 증가',
          icon: Icons.person_add_alt_1_rounded,
          color: Color(0xFF5E72E4),
        ),
        AdminMetric(
          label: 'chatbot 사용 건수',
          value: '38개',
          comparison: 'chatbot 사용',
          icon: Icons.smart_toy_rounded,
          color: Color(0xFF8E66D5),
        ),
        AdminMetric(
          label: '오늘 신고 건수',
          value: '12건',
          comparison: '오늘 접수된 신고',
          icon: Icons.report_problem_rounded,
          color: Color(0xFFE85D68),
        ),
        AdminMetric(
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
