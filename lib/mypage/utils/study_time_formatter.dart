/// 학습시간을 화면 전체에서 동일한 규칙으로 표시합니다.
///
/// - 0초 이하: 0분
/// - 1초 이상 1분 미만: n초
/// - 1분 이상: 초를 버리고 n분
String formatStudyTime(int totalSeconds) {
  if (totalSeconds <= 0) {
    return '0분';
  }

  if (totalSeconds < 60) {
    return '$totalSeconds초';
  }

  return '${totalSeconds ~/ 60}분';
}
