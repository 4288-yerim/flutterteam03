package com.example.flutterteam03.appwidgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.example.flutterteam03.R
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

class TodayTodoWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(
                context.packageName,
                R.layout.widget_today_todo,
            )

            val completedCount = widgetData.getInt(
                "today_todo_completed_count",
                0,
            )
            val totalCount = widgetData.getInt(
                "today_todo_total_count",
                0,
            )
            val progressPercent = widgetData.getInt(
                "today_todo_progress_percent",
                0,
            ).coerceIn(0, 100)

            views.setTextViewText(
                R.id.today_todo_count,
                "$completedCount / $totalCount",
            )
            views.setTextViewText(
                R.id.today_todo_progress_text,
                "진행률 $progressPercent%",
            )
            views.setProgressBar(
                R.id.today_todo_progress_bar,
                100,
                progressPercent,
                false,
            )

            val serviceIntent = Intent(
                context,
                TodayTodoWidgetService::class.java,
            ).apply {
                putExtra(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    appWidgetId,
                )
                data = android.net.Uri.parse(
                    "ddait://today-todo/list/$appWidgetId",
                )
            }

            views.setRemoteAdapter(
                R.id.today_todo_list,
                serviceIntent,
            )

            val clickTemplateIntent = Intent(
                context,
                TodayTodoActionReceiver::class.java,
            ).apply {
                action = TodayTodoActionReceiver.ACTION_TOGGLE
                putExtra(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    appWidgetId,
                )
            }

            val clickTemplate = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                clickTemplateIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_MUTABLE,
            )

            views.setPendingIntentTemplate(
                R.id.today_todo_list,
                clickTemplate,
            )

            val rawItems = HomeWidgetPlugin
                .getData(context)
                .getString("today_todo_items", "[]")
            val isEmpty = parseJsonArray(rawItems).isEmpty()

            views.setViewVisibility(
                R.id.today_todo_empty,
                if (isEmpty) android.view.View.VISIBLE
                else android.view.View.GONE,
            )
            views.setViewVisibility(
                R.id.today_todo_list,
                if (isEmpty) android.view.View.GONE
                else android.view.View.VISIBLE,
            )

            appWidgetManager.updateAppWidget(
                appWidgetId,
                views,
            )
            appWidgetManager.notifyAppWidgetViewDataChanged(
                appWidgetId,
                R.id.today_todo_list,
            )
        }
    }
}
