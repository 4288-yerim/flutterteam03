import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';

import '../home/services/home_service.dart';

class TodayTodoAppWidget {
  TodayTodoAppWidget._();

  static const String androidProviderName = 'TodayTodoWidgetProvider';

  static const String qualifiedAndroidProviderName =
      'com.example.flutterteam03.appwidgets.'
      'TodayTodoWidgetProvider';

  static const String _itemsKey = 'today_todo_items';
  static const String _completedCountKey = 'today_todo_completed_count';
  static const String _totalCountKey = 'today_todo_total_count';
  static const String _progressPercentKey = 'today_todo_progress_percent';
  static const String _updatedAtKey = 'today_todo_updated_at';
  static Future<void> _localWidgetOperation = Future<void>.value();

  static Future<void> sync() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      await clear();
      return;
    }

    final List<HomeTodo> todayTodos = await HomeService()
        .watchTodayTodos()
        .first;

    final List<_TodayTodoWidgetItem> items =
        todayTodos.map(_TodayTodoWidgetItem.fromHomeTodo).toList()..sort(
          (first, second) =>
              first.startPlannedAt.compareTo(second.startPlannedAt),
        );

    final int completedCount = items.where((item) => item.isCompleted).length;
    final int totalCount = items.length;
    final int progressPercent = totalCount == 0
        ? 0
        : ((completedCount / totalCount) * 100).round();

    await Future.wait<void>([
      HomeWidget.saveWidgetData<String>(
        _itemsKey,
        jsonEncode(items.map((item) => item.toJson()).toList()),
      ),
      HomeWidget.saveWidgetData<int>(_completedCountKey, completedCount),
      HomeWidget.saveWidgetData<int>(_totalCountKey, totalCount),
      HomeWidget.saveWidgetData<int>(_progressPercentKey, progressPercent),
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

    final String todoId = uri.queryParameters['todoId']?.trim() ?? '';
    final String sourceDocumentId =
        uri.queryParameters['sourceDocumentId']?.trim() ?? todoId;
    final int? aiStepIndex = int.tryParse(
      uri.queryParameters['aiStepIndex']?.trim() ?? '',
    );

    final String statusText = uri.queryParameters['status']?.trim() ?? '';

    if (todoId.isEmpty || (statusText != 'true' && statusText != 'false')) {
      return;
    }

    final bool newStatus = statusText == 'true';

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      await clear();
      return;
    }

    final DocumentReference<Map<String, dynamic>> reference = FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid)
        .collection('studyPlans')
        .doc(sourceDocumentId);

    bool saved = false;

    try {
      if (aiStepIndex == null) {
        await reference.update(<String, dynamic>{
          'status': newStatus,
          'completedat': newStatus ? FieldValue.serverTimestamp() : null,
          'updatedat': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> snapshot =
              await transaction.get(reference);
          final Map<String, dynamic>? data = snapshot.data();
          final Object? rawSteps = data?['steps'];

          if (rawSteps is! List ||
              aiStepIndex < 0 ||
              aiStepIndex >= rawSteps.length) {
            throw StateError('AI 학습 단계를 찾을 수 없습니다.');
          }

          final List<Map<String, dynamic>> steps = rawSteps.map((rawStep) {
            if (rawStep is Map) {
              return Map<String, dynamic>.from(rawStep);
            }
            return <String, dynamic>{};
          }).toList();

          steps[aiStepIndex] = <String, dynamic>{
            ...steps[aiStepIndex],
            'isCompleted': newStatus,
            'completedAt': newStatus ? Timestamp.now() : null,
          };

          final int completedStepCount = steps
              .where((step) => step['isCompleted'] == true)
              .length;
          final int totalStepCount = steps.length;
          final int completionRate = totalStepCount == 0
              ? 0
              : ((completedStepCount / totalStepCount) * 100).round();
          final String planStatus = completedStepCount == totalStepCount
              ? 'COMPLETED'
              : completedStepCount > 0
              ? 'IN_PROGRESS'
              : 'NOT_STARTED';

          transaction.update(reference, <String, dynamic>{
            'steps': steps,
            'completedStepCount': completedStepCount,
            'totalStepCount': totalStepCount,
            'completionRate': completionRate,
            'status': planStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      }
      saved = true;
    } finally {
      if (saved) {
        await _completeLocalToggle(todoId: todoId, newStatus: newStatus);
      } else {
        await sync();
      }
    }
  }

  static Future<void> _completeLocalToggle({
    required String todoId,
    required bool newStatus,
  }) async {
    final Future<void> operation = _localWidgetOperation.then((_) async {
      final String rawItems =
          await HomeWidget.getWidgetData<String>(
            _itemsKey,
            defaultValue: '[]',
          ) ??
          '[]';

      Object? decodedItems;

      try {
        decodedItems = jsonDecode(rawItems);
      } on FormatException {
        await sync();
        return;
      }

      if (decodedItems is! List) {
        await sync();
        return;
      }

      final List<Map<String, dynamic>> items = decodedItems.map((rawItem) {
        if (rawItem is! Map) {
          return <String, dynamic>{};
        }

        final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);

        if (item['id'] == todoId) {
          item['isCompleted'] = newStatus;
          item.remove('isLoading');
        }

        return item;
      }).toList();

      final int completedCount = items
          .where((item) => item['isCompleted'] == true)
          .length;
      final int totalCount = items.length;
      final int progressPercent = totalCount == 0
          ? 0
          : ((completedCount / totalCount) * 100).round();

      await Future.wait<void>([
        HomeWidget.saveWidgetData<String>(_itemsKey, jsonEncode(items)),
        HomeWidget.saveWidgetData<int>(_completedCountKey, completedCount),
        HomeWidget.saveWidgetData<int>(_totalCountKey, totalCount),
        HomeWidget.saveWidgetData<int>(_progressPercentKey, progressPercent),
      ]);

      await HomeWidget.updateWidget(
        name: androidProviderName,
        androidName: androidProviderName,
        qualifiedAndroidName: qualifiedAndroidProviderName,
      );
    });

    _localWidgetOperation = operation.catchError((Object _) {});
    await operation;
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
  final String sourceDocumentId;
  final int? aiStepIndex;
  final String title;
  final String planType;
  final DateTime startPlannedAt;
  final DateTime endPlannedAt;
  final bool isCompleted;

  const _TodayTodoWidgetItem({
    required this.id,
    required this.sourceDocumentId,
    required this.aiStepIndex,
    required this.title,
    required this.planType,
    required this.startPlannedAt,
    required this.endPlannedAt,
    required this.isCompleted,
  });

  factory _TodayTodoWidgetItem.fromHomeTodo(HomeTodo todo) {
    return _TodayTodoWidgetItem(
      id: todo.id,
      sourceDocumentId: todo.sourceDocumentId,
      aiStepIndex: todo.aiStepIndex,
      title: todo.title,
      planType: todo.planType,
      startPlannedAt: todo.startPlannedAt ?? todo.planDate,
      endPlannedAt: todo.endPlannedAt ?? todo.planDate,
      isCompleted: todo.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sourceDocumentId': sourceDocumentId,
      'aiStepIndex': aiStepIndex,
      'title': title.isEmpty ? '할 일 이름 없음' : title,
      'planType': planType,
      'startPlannedAt': startPlannedAt.toIso8601String(),
      'endPlannedAt': endPlannedAt.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }
}
