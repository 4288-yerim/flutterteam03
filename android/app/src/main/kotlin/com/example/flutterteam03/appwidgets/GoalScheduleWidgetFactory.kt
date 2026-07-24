package com.example.flutterteam03.appwidgets

import android.content.Context
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.example.flutterteam03.R
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

class GoalScheduleWidgetFactory(
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
                R.layout.widget_goal_schedule_item,
            )
        }

        val item = items[position]
        val certificateName = item.optString(
            "certificateName",
            "자격증 이름 없음",
        )
        val qualificationLabel = item.optString(
            "qualificationLabel",
        )
        val targetRound = item.optString(
            "targetRound",
        )
        val targetExamType = item.optString(
            "targetExamType",
        )
        val targetExamDateRaw = item.optString(
            "targetExamDate",
        )
        val isMainGoal = item.optBoolean(
            "isMainGoal",
            false,
        )

        val examDate = parseLocalDate(targetExamDateRaw)
        val dDay = buildDDay(examDate)
        val formattedDate = examDate?.format(
            DateTimeFormatter.ofPattern("yyyy.MM.dd"),
        ) ?: "-"

        return RemoteViews(
            context.packageName,
            R.layout.widget_goal_schedule_item,
        ).apply {
            setTextViewText(
                R.id.goal_main_badge,
                if (isMainGoal) "★ 대표 목표" else "",
            )
            setViewVisibility(
                R.id.goal_main_badge,
                if (isMainGoal) android.view.View.VISIBLE
                else android.view.View.GONE,
            )

            setTextViewText(
                R.id.goal_qualification,
                qualificationLabel.ifBlank { "목표 자격증" },
            )
            setTextViewText(
                R.id.goal_certificate_name,
                certificateName,
            )
            setTextViewText(
                R.id.goal_round,
                targetRound.ifBlank { "-" },
            )
            setTextViewText(
                R.id.goal_dday,
                dDay,
            )
            setTextViewText(
                R.id.goal_exam_info,
                listOf(
                    targetExamType,
                    formattedDate,
                ).filter { it.isNotBlank() }
                    .joinToString(" · "),
            )

            setTextColor(
                R.id.goal_dday,
                if (isMainGoal) Color.rgb(233, 99, 135)
                else Color.rgb(113, 145, 216),
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
            .getString("goal_schedule_items", "[]")

        items = parseJsonArray(raw)
    }

    private fun parseLocalDate(raw: String): LocalDate? {
        if (raw.isBlank()) {
            return null
        }

        return try {
            OffsetDateTime
                .parse(raw)
                .atZoneSameInstant(ZoneId.systemDefault())
                .toLocalDate()
        } catch (_: Exception) {
            try {
                java.time.LocalDateTime
                    .parse(raw)
                    .atZone(ZoneId.systemDefault())
                    .toLocalDate()
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun buildDDay(examDate: LocalDate?): String {
        if (examDate == null) {
            return "-"
        }

        val difference = ChronoUnit.DAYS.between(
            LocalDate.now(),
            examDate,
        )

        return when {
            difference == 0L -> "D-Day"
            difference > 0L -> "D-$difference"
            else -> "D+${kotlin.math.abs(difference)}"
        }
    }
}
