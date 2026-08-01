import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전체의 테마 모드를 관리하고 기기에 저장합니다.
///
/// 화면에서는 [setThemeModeName]을 호출하고, 최상위 MaterialApp은
/// [themeMode]를 구독해 시스템/라이트/다크 모드를 즉시 반영합니다.
class ThemeModeService {
  ThemeModeService._();

  static final ThemeModeService instance = ThemeModeService._();

  static const String _preferenceKey = 'app_theme_mode';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _settingsSubscription;
  String? _activeUid;

  /// 앱 실행 시 기기에 저장된 테마 설정을 불러옵니다.
  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    themeMode.value = fromName(preferences.getString(_preferenceKey));
  }

  void startAuthSync() {
    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthStateChanged,
    );
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    await _settingsSubscription?.cancel();
    _settingsSubscription = null;
    _activeUid = user?.uid;

    if (user == null) {
      await setThemeModeName('SYSTEM');
      return;
    }

    final uid = user.uid;
    _settingsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('app')
        .snapshots()
        .listen((snapshot) {
          if (_activeUid != uid) {
            return;
          }

          final value = snapshot.data()?['themeMode']?.toString() ?? 'SYSTEM';
          setThemeModeName(value);
        });
  }

  /// 설정 화면과 Firestore에서 사용하는 문자열을 ThemeMode로 변환합니다.
  static ThemeMode fromName(String? value) {
    switch (value?.toUpperCase()) {
      case 'LIGHT':
        return ThemeMode.light;
      case 'DARK':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// 현재 ThemeMode를 설정 문서에서 사용하는 문자열로 변환합니다.
  static String toName(ThemeMode value) {
    switch (value) {
      case ThemeMode.light:
        return 'LIGHT';
      case ThemeMode.dark:
        return 'DARK';
      case ThemeMode.system:
        return 'SYSTEM';
    }
  }

  String get modeName => toName(themeMode.value);

  /// 테마를 즉시 변경한 뒤 기기에 저장합니다.
  Future<void> setThemeModeName(String value) async {
    final normalizedMode = fromName(value);
    themeMode.value = normalizedMode;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, toName(normalizedMode));
  }
}
