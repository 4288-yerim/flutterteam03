import 'package:flutter/material.dart';

import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class StudyRecordScreen extends StatelessWidget {
  const StudyRecordScreen({super.key});

  static const List<_WeeklyStudyData> _weeklyStudyData = [
    _WeeklyStudyData(
      day: '월',
      minutes: 50,
    ),
    _WeeklyStudyData(
      day: '화',
      minutes: 80,
    ),
    _WeeklyStudyData(
      day: '수',
      minutes: 30,
    ),
    _WeeklyStudyData(
      day: '목',
      minutes: 60,
    ),
    _WeeklyStudyData(
      day: '금',
      minutes: 40,
    ),
    _WeeklyStudyData(
      day: '토',
      minutes: 45,
    ),
    _WeeklyStudyData(
      day: '일',
      minutes: 15,
    ),
  ];

  static const List<_StudyRecordData> _studyRecords = [
    _StudyRecordData(
      date: '7월 13일',
      dayOfWeek: '월요일',
      subject: '정보처리기사 필기',
      description: '소프트웨어 설계 핵심 개념 복습',
      minutes: 50,
      icon: Icons.menu_book_outlined,
    ),
    _StudyRecordData(
      date: '7월 12일',
      dayOfWeek: '일요일',
      subject: '정보처리기사 기출문제',
      description: '2025년 3회 기출문제 풀이',
      minutes: 15,
      icon: Icons.edit_note_outlined,
    ),
    _StudyRecordData(
      date: '7월 11일',
      dayOfWeek: '토요일',
      subject: '데이터베이스',
      description: '정규화와 트랜잭션 복습',
      minutes: 45,
      icon: Icons.storage_outlined,
    ),
    _StudyRecordData(
      date: '7월 10일',
      dayOfWeek: '금요일',
      subject: '프로그래밍 언어',
      description: 'Java 객체지향 개념 정리',
      minutes: 40,
      icon: Icons.code_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppTopBar(
        title: '학습 기록',
        leading: IconButton(
          tooltip: '뒤로 가기',
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),

      body: AppMainBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            110,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StudySummaryCard(),
              const SizedBox(height: 24),

              const _SectionTitle(
                title: '이번 주 학습',
              ),
              const SizedBox(height: 12),

              _WeeklyStudyChart(
                weeklyData: _weeklyStudyData,
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  const Expanded(
                    child: _SectionTitle(
                      title: '최근 학습 기록',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '전체 기록 조회 기능은 Firebase 연결 후 적용됩니다.',
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      '전체 보기',
                      style: TextStyle(
                        color: Color(0xFFF0788F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (int index = 0;
                    index < _studyRecords.length;
                    index++) ...[
                      _StudyRecordTile(
                        record: _studyRecords[index],
                      ),
                      if (index < _studyRecords.length - 1)
                        const Divider(
                          height: 1,
                          indent: 72,
                          endIndent: 18,
                          color: Color(0xFFF0F0F2),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudySummaryCard extends StatelessWidget {
  const _StudySummaryCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘도 목표를 향해 공부하고 있어요!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '조금씩 꾸준히 공부하면 목표에 가까워집니다.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9AA0AC),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              const Expanded(
                child: _SummaryValue(
                  icon: Icons.today_outlined,
                  label: '오늘 학습',
                  value: '50분',
                ),
              ),
              Container(
                width: 1,
                height: 45,
                color: const Color(0xFFF0F0F2),
              ),
              const Expanded(
                child: _SummaryValue(
                  icon: Icons.date_range_outlined,
                  label: '이번 주',
                  value: '5시간 20분',
                ),
              ),
              Container(
                width: 1,
                height: 45,
                color: const Color(0xFFF0F0F2),
              ),
              const Expanded(
                child: _SummaryValue(
                  icon: Icons.local_fire_department_outlined,
                  label: '연속 학습',
                  value: '4일',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 21,
          color: const Color(0xFFF0788F),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9AA0AC),
          ),
        ),
      ],
    );
  }
}

class _WeeklyStudyChart extends StatelessWidget {
  final List<_WeeklyStudyData> weeklyData;

  const _WeeklyStudyChart({
    required this.weeklyData,
  });

  @override
  Widget build(BuildContext context) {
    final int maxMinutes = weeklyData
        .map((data) => data.minutes)
        .reduce((current, next) {
      return current > next ? current : next;
    });

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.bar_chart,
                size: 20,
                color: Color(0xFFF0788F),
              ),
              SizedBox(width: 8),
              Text(
                '총 5시간 20분',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Spacer(),
              Text(
                '지난주보다 40분 증가',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFF0788F),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyData.map((data) {
                final double heightRatio =
                maxMinutes == 0 ? 0 : data.minutes / maxMinutes;

                final double barHeight =
                data.minutes == 0 ? 4 : 100 * heightRatio;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${data.minutes}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9AA0AC),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 20,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6A9B8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.day,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666A73),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          const Center(
            child: Text(
              '단위: 분',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFFB4B8C2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyRecordTile extends StatelessWidget {
  final _StudyRecordData record;

  const _StudyRecordTile({
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFCEFF3),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              record.icon,
              size: 21,
              color: const Color(0xFFF0788F),
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.subject,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${record.minutes}분',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF0788F),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                Text(
                  record.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666A73),
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '${record.date} · ${record.dayOfWeek}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9AA0AC),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A1A),
      ),
    );
  }
}

class _WeeklyStudyData {
  final String day;
  final int minutes;

  const _WeeklyStudyData({
    required this.day,
    required this.minutes,
  });
}

class _StudyRecordData {
  final String date;
  final String dayOfWeek;
  final String subject;
  final String description;
  final int minutes;
  final IconData icon;

  const _StudyRecordData({
    required this.date,
    required this.dayOfWeek,
    required this.subject,
    required this.description,
    required this.minutes,
    required this.icon,
  });
}