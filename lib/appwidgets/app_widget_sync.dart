import 'goal_schedule_app_widget.dart';
import 'today_todo_app_widget.dart';

class AppWidgetSync {
  AppWidgetSync._();

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
