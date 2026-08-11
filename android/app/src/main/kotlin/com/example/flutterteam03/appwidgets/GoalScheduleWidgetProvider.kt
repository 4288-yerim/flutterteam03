package com.example.flutterteam03.appwidgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.example.flutterteam03.R
import es.antonborri.home_widget.HomeWidgetProvider

class GoalScheduleWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(
                context.packageName,
                R.layout.widget_goal_schedule,
            )

            views.setOnClickPendingIntent(
                R.id.goal_schedule_widget_root,
                null,
            )
            views.setPendingIntentTemplate(
                R.id.goal_schedule_list,
                null,
            )

            val rawItems = widgetData.getString(
                "goal_schedule_items",
                "[]",
            )
            val scheduleItems = parseJsonArray(rawItems)

            views.setTextViewText(
                R.id.goal_schedule_count,
                "${scheduleItems.size}개",
            )

            val serviceIntent = Intent(
                context,
                GoalScheduleWidgetService::class.java,
            ).apply {
                putExtra(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    appWidgetId,
                )

                data = android.net.Uri.parse(
                    "ddait://goal-schedule/list/$appWidgetId",
                )
            }

            views.setRemoteAdapter(
                R.id.goal_schedule_list,
                serviceIntent,
            )

            val isEmpty = scheduleItems.isEmpty()

            views.setViewVisibility(
                R.id.goal_schedule_empty,
                if (isEmpty) android.view.View.VISIBLE
                else android.view.View.GONE,
            )
            views.setViewVisibility(
                R.id.goal_schedule_list,
                if (isEmpty) android.view.View.GONE
                else android.view.View.VISIBLE,
            )

            appWidgetManager.updateAppWidget(
                appWidgetId,
                views,
            )
            appWidgetManager.notifyAppWidgetViewDataChanged(
                appWidgetId,
                R.id.goal_schedule_list,
            )
        }
    }
}
