import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppIconService {
  static const _channel = MethodChannel('app_icon_switcher');
  static const _lastOpenedDateKey = 'lastOpenedDateEpochDay';
  static const _streakKey = 'currentStreak';

  static const aliasDefault = '.IconDefault';
  static const alias3 = '.Icon3';
  static const alias7 = '.Icon7';
  static const alias14 = '.Icon14';
  static const alias21 = '.Icon21';
  static const alias30 = '.Icon30';
  static const alias60 = '.Icon60';
  static const aliasGood = '.IconGood';

  static int _todayEpochDay() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/
        (1000 * 60 * 60 * 24);
  }

  static String _aliasForInactiveDays(int days) {
    if (days >= 60) return alias60;
    if (days >= 30) return alias30;
    if (days >= 21) return alias21;
    if (days >= 14) return alias14;
    if (days >= 7) return alias7;
    if (days >= 3) return alias3;
    return aliasDefault;
  }

  static Future<void> _switchTo(String alias) async {
    try {
      await _channel.invokeMethod('switchIcon', {'alias': alias});
    } catch (e) {
      // 실패해도 앱 동작엔 지장 없으니 조용히 무시
    }
  }

  /// 앱이 열릴 때(resumed, 최초 실행 포함) 호출
  static Future<void> onAppOpened() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayEpochDay();
    final lastDay = prefs.getInt(_lastOpenedDateKey);
    int streak = prefs.getInt(_streakKey) ?? 0;

    if (lastDay == null) {
      // 최초 실행
      streak = 1;
    } else {
      final gap = today - lastDay;
      if (gap == 0) {
        // 오늘 이미 카운트됨, streak 유지
      } else if (gap == 1) {
        streak += 1; // 어제도 열었음 -> 연속 갱신
      } else {
        streak = 1; // 하루 이상 빠짐 -> streak 초기화
      }
    }

    await prefs.setInt(_lastOpenedDateKey, today);
    await prefs.setInt(_streakKey, streak);

    if (streak >= 2) {
      await _switchTo(aliasGood);
    } else {
      await _switchTo(aliasDefault);
    }
  }

  /// workmanager 백그라운드 작업에서 호출: 하루 이상 미접속이면 경과일수 아이콘으로 전환
  static Future<void> checkAndUpdateIcon() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayEpochDay();
    final lastDay = prefs.getInt(_lastOpenedDateKey);
    if (lastDay == null) return;

    final gap = today - lastDay;

    if (gap <= 1) {
      // 아직 오늘 열 기회가 남아있음 (어제까지는 정상 접속) -> 건드리지 않음
      return;
    }

    // 하루 이상 완전히 빠짐 -> streak 초기화 + 경과일수 아이콘 적용
    await prefs.setInt(_streakKey, 0);
    await _switchTo(_aliasForInactiveDays(gap));
  }
}