/// "3분 전", "2일 전", "3주 전", "2달 전", "1년 전" 형식으로 변환합니다.
/// 1분 미만은 "방금 전"으로 표시합니다.
String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inSeconds < 60) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}주 전';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}달 전';
  return '${(diff.inDays / 365).floor()}년 전';
}

/// 채팅창 안 날짜 구분선용. 올해면 "7월 31일", 다른 해면 "2025년 7월 31일".
String formatDateDivider(DateTime dateTime) {
  final now = DateTime.now();
  if (dateTime.year == now.year) {
    return '${dateTime.month}월 ${dateTime.day}일';
  }
  return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일';
}

/// 말풍선 아래 작은 시간 표시용. "14:32"
String formatBubbleTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

bool isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}