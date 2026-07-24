package com.example.flutterteam03.appwidgets

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.example.flutterteam03.R
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

class TodayTodoWidgetFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private var items: List<JSONObject> = emptyList()

    override fun onCreate() {
        loadItems()
    }

    override fun onDataSetChanged() {
        loadItems()
    }

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position !in items.indices) {
            return RemoteViews(
                context.packageName,
                R.layout.widget_today_todo_item,
            )
        }

        val item = items[position]
        val todoId = item.optString("id")
        val title = item.optString(
            "title",
            "할 일 이름 없음",
        )
        val isCompleted = item.optBoolean(
            "isCompleted",
            false,
        )
        val planType = item.optString("planType")

        return RemoteViews(
            context.packageName,
            R.layout.widget_today_todo_item,
        ).apply {
            setTextViewText(
                R.id.todo_status,
                if (isCompleted) "✓" else "○",
            )
            setTextColor(
                R.id.todo_status,
                if (isCompleted) Color.rgb(240, 111, 145)
                else Color.rgb(129, 123, 125),
            )

            setTextViewText(
                R.id.todo_title,
                title,
            )
            setTextColor(
                R.id.todo_title,
                if (isCompleted) Color.rgb(141, 135, 137)
                else Color.rgb(48, 44, 46),
            )

            val typeColor = when (planType) {
                "USERADD" -> Color.rgb(98, 190, 136)
                "AIADD" -> Color.rgb(155, 123, 234)
                else -> Color.rgb(179, 170, 173)
            }

            setTextColor(
                R.id.todo_plan_type_dot,
                typeColor,
            )

            val fillInIntent = Intent().apply {
                putExtra(
                    TodayTodoActionReceiver.EXTRA_TODO_ID,
                    todoId,
                )
            }

            setOnClickFillInIntent(
                R.id.todo_item_root,
                fillInIntent,
            )
        }
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long {
        return items
            .getOrNull(position)
            ?.optString("id")
            ?.hashCode()
            ?.toLong()
            ?: position.toLong()
    }

    override fun hasStableIds(): Boolean = true

    private fun loadItems() {
        val raw = HomeWidgetPlugin
            .getData(context)
            .getString("today_todo_items", "[]")

        items = parseJsonArray(raw)
    }
}
