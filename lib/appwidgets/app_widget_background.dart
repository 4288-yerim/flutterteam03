import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import 'today_todo_app_widget.dart';

@pragma('vm:entry-point')
FutureOr<void> appWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null) {
    return;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await TodayTodoAppWidget.toggleFromWidget(uri);
}
