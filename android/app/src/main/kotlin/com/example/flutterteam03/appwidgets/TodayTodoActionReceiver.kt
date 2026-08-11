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
        val toggleResult = toggleLocalTodo(
            context = context,
            todoId = todoId,
        ) ?: return

        // 2. 변경된 로컬 상태로 위젯 즉시 갱신
        refreshWidget(
            context = context,
            toggleResult = toggleResult,
        )

        // 3. Firestore 저장은 Flutter 백그라운드에서 처리
        val callbackIntent =
            HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse(
                    "ddait://today-todo/toggle" +
                            "?todoId=${Uri.encode(todoId)}" +
                            "&sourceDocumentId=${Uri.encode(toggleResult.sourceDocumentId)}" +
                            (toggleResult.aiStepIndex?.let {
                                "&aiStepIndex=$it"
                            } ?: "") +
                            "&status=${toggleResult.newStatus}",
                ),
            )

        callbackIntent.send()
    }

    private fun toggleLocalTodo(
        context: Context,
        todoId: String,
    ): TodoToggleResult? {
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
        var toggleResult: TodoToggleResult? = null

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
                if (updatedItem.optBoolean("isLoading", false)) {
                    return null
                }

                isCompleted = !isCompleted

                updatedItem.put(
                    "isCompleted",
                    isCompleted,
                )
                updatedItem.put(
                    "isLoading",
                    true,
                )

                val sourceDocumentId = updatedItem
                    .optString("sourceDocumentId", todoId)
                    .ifBlank { todoId }
                val aiStepIndex = if (
                    updatedItem.has("aiStepIndex") &&
                    !updatedItem.isNull("aiStepIndex")
                ) {
                    updatedItem.optInt("aiStepIndex")
                } else {
                    null
                }

                toggleResult = TodoToggleResult(
                    sourceDocumentId = sourceDocumentId,
                    aiStepIndex = aiStepIndex,
                    newStatus = isCompleted,
                    completedCount = 0,
                    totalCount = 0,
                )
            }

            if (isCompleted) {
                completedCount++
            }

            updatedArray.put(updatedItem)
        }

        val totalCount = updatedArray.length()

        toggleResult = toggleResult?.copy(
            completedCount = completedCount,
            totalCount = totalCount,
        )

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
            .commit()

        return toggleResult
    }

    private data class TodoToggleResult(
        val sourceDocumentId: String,
        val aiStepIndex: Int?,
        val newStatus: Boolean,
        val completedCount: Int,
        val totalCount: Int,
    )

    private fun refreshWidget(
        context: Context,
        toggleResult: TodoToggleResult,
    ) {
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

        val partialViews = android.widget.RemoteViews(
            context.packageName,
            com.example.flutterteam03.R.layout.widget_today_todo,
        ).apply {
            setTextViewText(
                com.example.flutterteam03.R.id.today_todo_count,
                "${toggleResult.completedCount} / ${toggleResult.totalCount}",
            )
        }

        appWidgetManager.partiallyUpdateAppWidget(
            appWidgetIds,
            partialViews,
        )

        appWidgetManager.notifyAppWidgetViewDataChanged(
            appWidgetIds,
            com.example.flutterteam03.R.id.today_todo_list,
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
