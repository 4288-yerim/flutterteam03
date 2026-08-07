import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';

class TodayTodoAppWidget {
  TodayTodoAppWidget._();

  static const String androidProviderName =
      'TodayTodoWidgetProvider';

  static const String qualifiedAndroidProviderName =
      'com.example.flutterteam03.appwidgets.'
      'TodayTodoWidgetProvider';

  static const String _itemsKey = 'today_todo_items';
  static const String _completedCountKey = 'today_todo_completed_count';
  static const String _totalCountKey = 'today_todo_total_count';
  static const String _progressPercentKey = 'today_todo_progress_percent';
  static const String _updatedAtKey = 'today_todo_updated_at';

  static Future<void> sync() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      await clear();
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final DateTime tomorrowStart = todayStart.add(const Duration(days: 1));

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('studyPlans')
            .where(
              'planday',
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
            )
            .where(
              'planday',
              isLessThan: Timestamp.fromDate(tomorrowStart),
            )
            .get();

    final List<_TodayTodoWidgetItem> items = snapshot.docs
        .map(_TodayTodoWidgetItem.fromFirestore)
        .toList()
      ..sort(
        (first, second) =>
            first.startPlannedAt.compareTo(second.startPlannedAt),
      );

    final int completedCount =
        items.where((item) => item.isCompleted).length;
    final int totalCount = items.length;
    final int progressPercent = totalCount == 0
        ? 0
        : ((completedCount / totalCount) * 100).round();

    await Future.wait<void>([
      HomeWidget.saveWidgetData<String>(
        _itemsKey,
        jsonEncode(items.map((item) => item.toJson()).toList()),
      ),
      HomeWidget.saveWidgetData<int>(
        _completedCountKey,
        completedCount,
      ),
      HomeWidget.saveWidgetData<int>(
        _totalCountKey,
        totalCount,
      ),
      HomeWidget.saveWidgetData<int>(
        _progressPercentKey,
        progressPercent,
      ),
      HomeWidget.saveWidgetData<String>(
        _updatedAtKey,
        DateTime.now().toIso8601String(),
      ),
    ]);

    await HomeWidget.updateWidget(
      name: androidProviderName,
      androidName: androidProviderName,
      qualifiedAndroidName: qualifiedAndroidProviderName,
    );
  }

  static Future<void> toggleFromWidget(Uri uri) async {
    if (uri.scheme != 'ddait' ||
        uri.host != 'today-todo' ||
        uri.path != '/toggle') {
      return;
    }

    final String todoId =
        uri.queryParameters['todoId']?.trim() ?? '';

    final String statusText =
        uri.queryParameters['status']?.trim() ?? '';

    if (todoId.isEmpty ||
        (statusText != 'true' && statusText != 'false')) {
      return;
    }

    final bool newStatus = statusText == 'true';

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      await clear();
      return;
    }

    final DocumentReference<Map<String, dynamic>> reference =
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('studyPlans')
        .doc(todoId);

    await reference.update(<String, dynamic>{
      'status': newStatus,
      'completedat':
      newStatus ? FieldValue.serverTimestamp() : null,
      'updatedat': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> clear() async {
    await Future.wait<void>([
      HomeWidget.saveWidgetData<String>(_itemsKey, '[]'),
      HomeWidget.saveWidgetData<int>(_completedCountKey, 0),
      HomeWidget.saveWidgetData<int>(_totalCountKey, 0),
      HomeWidget.saveWidgetData<int>(_progressPercentKey, 0),
      HomeWidget.saveWidgetData<String>(
        _updatedAtKey,
        DateTime.now().toIso8601String(),
      ),
    ]);

    await HomeWidget.updateWidget(
      name: androidProviderName,
      androidName: androidProviderName,
      qualifiedAndroidName: qualifiedAndroidProviderName, // 추가
    );
  }
}

class _TodayTodoWidgetItem {
  final String id;
  final String title;
  final String planType;
  final DateTime startPlannedAt;
  final DateTime endPlannedAt;
  final bool isCompleted;

  const _TodayTodoWidgetItem({
    required this.id,
    required this.title,
    required this.planType,
    required this.startPlannedAt,
    required this.endPlannedAt,
    required this.isCompleted,
  });

  factory _TodayTodoWidgetItem.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();

    final DateTime fallbackDate =
        (data['planday'] as Timestamp?)?.toDate() ?? DateTime.now();

    return _TodayTodoWidgetItem(
      id: document.id,
      title: (data['title'] as String? ?? '').trim(),
      planType: (data['plantype'] as String? ?? '').trim().toUpperCase(),
      startPlannedAt:
          (data['startplannedat'] as Timestamp?)?.toDate() ?? fallbackDate,
      endPlannedAt:
          (data['endplannedat'] as Timestamp?)?.toDate() ?? fallbackDate,
      isCompleted: data['status'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title.isEmpty ? '할 일 이름 없음' : title,
      'planType': planType,
      'startPlannedAt': startPlannedAt.toIso8601String(),
      'endPlannedAt': endPlannedAt.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }
}
