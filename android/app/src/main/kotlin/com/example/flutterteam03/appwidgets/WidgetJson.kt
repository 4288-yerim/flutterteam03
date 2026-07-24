package com.example.flutterteam03.appwidgets

import org.json.JSONArray
import org.json.JSONObject

internal fun parseJsonArray(raw: String?): List<JSONObject> {
    if (raw.isNullOrBlank()) {
        return emptyList()
    }

    return try {
        val array = JSONArray(raw)
        buildList {
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index)
                if (item != null) {
                    add(item)
                }
            }
        }
    } catch (_: Exception) {
        emptyList()
    }
}
