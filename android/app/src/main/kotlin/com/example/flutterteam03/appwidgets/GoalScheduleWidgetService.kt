package com.example.flutterteam03.appwidgets

import android.content.Intent
import android.widget.RemoteViewsService

class GoalScheduleWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(
        intent: Intent,
    ): RemoteViewsFactory {
        return GoalScheduleWidgetFactory(
            applicationContext,
        )
    }
}
