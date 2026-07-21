class CertificateScheduleService {
  Future<List<CertificateSchedule>> getSchedules() async {
    // TODO: 추후 공공데이터 API 또는 Firestore 조회로 교체
    return [
      CertificateSchedule(
        certificateName: '정보처리기사',
        scheduleType: '필기시험',
        date: DateTime(2026, 7, 13),
        description: '2026년 정기 기사 2회 필기시험',
      ),
      CertificateSchedule(
        certificateName: '컴퓨터활용능력 1급',
        scheduleType: '원서접수 시작',
        date: DateTime(2026, 7, 13),
        description: '필기시험 원서접수',
      ),
      CertificateSchedule(
        certificateName: 'SQLD',
        scheduleType: '원서접수 마감',
        date: DateTime(2026, 7, 18),
        description: '제58회 SQL 개발자 시험',
      ),
      CertificateSchedule(
        certificateName: '정보처리기사',
        scheduleType: '실기시험',
        date: DateTime(2026, 7, 20),
        description: '2026년 정기 기사 2회 실기시험',
      ),
      CertificateSchedule(
        certificateName: '한국사능력검정시험',
        scheduleType: '시험일',
        date: DateTime(2026, 7, 25),
        description: '제79회 한국사능력검정시험',
      ),
      CertificateSchedule(
        certificateName: '산업안전기사',
        scheduleType: '합격자 발표',
        date: DateTime(2026, 7, 29),
        description: '최종 합격자 발표',
      ),
      CertificateSchedule(
        certificateName: '네트워크관리사 2급',
        scheduleType: '필기시험',
        date: DateTime(2026, 8, 9),
        description: '2026년 제3회 필기시험',
      ),
    ];
  }
}

class CertificateSchedule {
  final String certificateName;
  final String scheduleType;
  final DateTime date;
  final String description;

  const CertificateSchedule({
    required this.certificateName,
    required this.scheduleType,
    required this.date,
    required this.description,
  });
}