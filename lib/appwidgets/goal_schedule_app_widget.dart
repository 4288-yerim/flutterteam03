import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../home/services/home_service.dart';

class GoalScheduleAppWidget {
  GoalScheduleAppWidget._();

  static const String androidProviderName =
      'GoalScheduleWidgetProvider';

  static const String qualifiedAndroidProviderName =
      'com.example.flutterteam03.appwidgets.'
      'GoalScheduleWidgetProvider';

  static const String _itemsKey = 'goal_schedule_items';
  static const String _updatedAtKey = 'goal_schedule_updated_at';

  static Future<void> sync() async {
    final List<HomeGoal> goals =
        await HomeService().watchActiveGoals().first;

    final List<Map<String, dynamic>> items = goals
        .map(
          (goal) => <String, dynamic>{
            'id': goal.id,
            'certificateId': goal.certificateId,
            'certificateName': goal.certificateName,
            'qualificationLabel': goal.qualificationLabel,
            'targetRound': goal.targetRound,
            'targetExamType': goal.targetExamType,
            'targetExamDate': goal.targetExamDate.toIso8601String(),
            'targetPassAnnouncementDate':
                goal.targetPassAnnouncementDate?.toIso8601String(),
            'targetPassAnnouncementEndDate':
                goal.targetPassAnnouncementEndDate?.toIso8601String(),
            'isMainGoal': goal.isMainGoal,
          },
        )
        .toList();

    await Future.wait<void>([
      HomeWidget.saveWidgetData<String>(
        _itemsKey,
        jsonEncode(items),
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

  static Future<void> clear() async {
    await Future.wait<void>([
      HomeWidget.saveWidgetData<String>(_itemsKey, '[]'),
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
