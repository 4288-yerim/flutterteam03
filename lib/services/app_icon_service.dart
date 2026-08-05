import 'package:flutter/foundation.dart';
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

  static Future<void>? _openUpdate;
  static int? _lastHandledOpenDay;

  static int _todayEpochDay() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/
        (1000 * 60 * 60 * 24);
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
    final today = _todayEpochDay();
    if (_lastHandledOpenDay == today) return;

    final pendingUpdate = _openUpdate;
    if (pendingUpdate != null) {
      await pendingUpdate;
      if (_lastHandledOpenDay == today) return;
    }

    final update = _updateForAppOpen(today);
    _openUpdate = update;
    try {
      await update;
      _lastHandledOpenDay = today;
    } finally {
      _openUpdate = null;
    }
  }

  static Future<String?> testInactiveDays(int days) async {
    if (!kDebugMode) return null;

    try {
      return await _channel.invokeMethod<String>('testInactiveDays', {
        'days': days,
      });
    } on PlatformException {
      return null;
    }
  }

  static Future<String?> testGoodIcon() async {
    if (!kDebugMode) return null;

    try {
      return await _channel.invokeMethod<String>('testGoodIcon');
    } on PlatformException {
      return null;
    }
  }

  static Future<void> _updateForAppOpen(int today) async {
    final prefs = await SharedPreferences.getInstance();
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

}
