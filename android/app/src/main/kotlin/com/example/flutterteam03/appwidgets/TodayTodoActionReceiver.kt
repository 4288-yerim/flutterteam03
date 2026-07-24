package com.example.flutterteam03.appwidgets

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class TodayTodoActionReceiver : BroadcastReceiver() {

    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        if (intent.action != ACTION_TOGGLE) {
            return
        }

        val todoId = intent
            .getStringExtra(EXTRA_TODO_ID)
            ?.trim()
            .orEmpty()

        if (todoId.isEmpty()) {
            return
        }

        // 1. 위젯 로컬 상태를 먼저 즉시 변경
        val newStatus = toggleLocalTodo(
            context = context,
            todoId = todoId,
        )

        // 2. 변경된 로컬 상태로 위젯 즉시 갱신
        refreshWidget(context)

        // 3. Firestore 저장은 Flutter 백그라운드에서 처리
        val callbackIntent =
            HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse(
                    "ddait://today-todo/toggle" +
                            "?todoId=${Uri.encode(todoId)}" +
                            "&status=$newStatus",
                ),
            )

        callbackIntent.send()
    }

    private fun toggleLocalTodo(
        context: Context,
        todoId: String,
    ): Boolean {
        val preferences = HomeWidgetPlugin.getData(context)

        val rawItems = preferences.getString(
            KEY_TODO_ITEMS,
            "[]",
        ) ?: "[]"

        val originalArray = try {
            JSONArray(rawItems)
        } catch (_: Exception) {
            JSONArray()
        }

        val updatedArray = JSONArray()

        var completedCount = 0
        var changedStatus = false

        for (index in 0 until originalArray.length()) {
            val originalItem =
                originalArray.optJSONObject(index) ?: continue

            // 원본 JSON 객체를 복사
            val updatedItem = JSONObject(
                originalItem.toString(),
            )

            val itemId = updatedItem.optString("id")
            var isCompleted = updatedItem.optBoolean(
                "isCompleted",
                false,
            )

            if (itemId == todoId) {
                isCompleted = !isCompleted

                updatedItem.put(
                    "isCompleted",
                    isCompleted,
                )

                changedStatus = isCompleted
            }

            if (isCompleted) {
                completedCount++
            }

            updatedArray.put(updatedItem)
        }

        val totalCount = updatedArray.length()

        val progressPercent =
            if (totalCount == 0) {
                0
            } else {
                ((completedCount.toDouble() / totalCount) * 100)
                    .toInt()
                    .coerceIn(0, 100)
            }

        preferences.edit()
            .putString(
                KEY_TODO_ITEMS,
                updatedArray.toString(),
            )
            .putInt(
                KEY_COMPLETED_COUNT,
                completedCount,
            )
            .putInt(
                KEY_TOTAL_COUNT,
                totalCount,
            )
            .putInt(
                KEY_PROGRESS_PERCENT,
                progressPercent,
            )
            .apply()

        return changedStatus
    }

    private fun refreshWidget(context: Context) {
        val appWidgetManager =
            AppWidgetManager.getInstance(context)

        val componentName = ComponentName(
            context,
            TodayTodoWidgetProvider::class.java,
        )

        val appWidgetIds =
            appWidgetManager.getAppWidgetIds(componentName)

        if (appWidgetIds.isEmpty()) {
            return
        }

        // 목록 행 다시 읽기
        appWidgetManager.notifyAppWidgetViewDataChanged(
            appWidgetIds,
            com.example.flutterteam03.R.id.today_todo_list,
        )

        // 상단 완료 개수와 진행률도 다시 표시
        TodayTodoWidgetProvider().onUpdate(
            context,
            appWidgetManager,
            appWidgetIds,
            HomeWidgetPlugin.getData(context),
        )
    }

    companion object {
        const val ACTION_TOGGLE =
            "com.example.flutterteam03.action.TOGGLE_TODAY_TODO"

        const val EXTRA_TODO_ID = "todoId"

        private const val KEY_TODO_ITEMS =
            "today_todo_items"

        private const val KEY_COMPLETED_COUNT =
            "today_todo_completed_count"

        private const val KEY_TOTAL_COUNT =
            "today_todo_total_count"

        private const val KEY_PROGRESS_PERCENT =
            "today_todo_progress_percent"
    }
}