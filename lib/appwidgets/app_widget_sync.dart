import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'goal_schedule_app_widget.dart';
import 'today_todo_app_widget.dart';

class AppWidgetSync {
  AppWidgetSync._();

  static StreamSubscription<User?>? _authSubscription;
  static Future<void> _authSyncOperation = Future<void>.value();
  static String? _activeUid;

  static void startAuthSync() {
    if (_authSubscription != null) {
      return;
    }

    _activeUid = FirebaseAuth.instance.currentUser?.uid;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      final String? nextUid = user?.uid;

      if (_activeUid == nextUid) {
        return;
      }

      _activeUid = nextUid;
      _authSyncOperation = _authSyncOperation
          .catchError((Object _) {})
          .then((_) => _replaceWidgetOwner(nextUid));
    });
  }

  static Future<void> _replaceWidgetOwner(String? uid) async {
    await clearAll();

    if (uid == null || FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }

    await syncAll();
  }

  static Future<void> syncAll() async {
    await Future.wait<void>([
      GoalScheduleAppWidget.sync(),
      TodayTodoAppWidget.sync(),
    ]);
  }

  static Future<void> clearAll() async {
    await Future.wait<void>([
      GoalScheduleAppWidget.clear(),
      TodayTodoAppWidget.clear(),
    ]);
  }
}
