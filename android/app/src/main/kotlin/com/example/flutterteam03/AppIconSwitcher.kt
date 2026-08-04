package com.example.flutterteam03

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

object AppIconSwitcher {
    const val ALIAS_DEFAULT = ".IconDefault"
    const val ALIAS_GOOD = ".IconGood"

    private val aliases = listOf(
        ALIAS_DEFAULT,
        ".Icon3",
        ".Icon7",
        ".Icon14",
        ".Icon21",
        ".Icon30",
        ".Icon60",
        ALIAS_GOOD,
    )

    fun aliasForInactiveDays(days: Int): String = when {
        days >= 60 -> ".Icon60"
        days >= 30 -> ".Icon30"
        days >= 21 -> ".Icon21"
        days >= 14 -> ".Icon14"
        days >= 7 -> ".Icon7"
        days >= 3 -> ".Icon3"
        else -> ALIAS_DEFAULT
    }

    @Synchronized
    fun prepareIconSwitch(context: Context, targetAlias: String): Boolean {
        if (targetAlias !in aliases) return false

        val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        if (aliases.all { alias ->
                isEnabled(context, alias) == (alias == targetAlias)
            }) {
            saveActiveAlias(preferences, targetAlias)
            clearPendingSwitch(context)
            return true
        }

        preferences.edit()
            .putString(PENDING_TARGET_KEY, targetAlias)
            .commit()
        return true
    }

    @Synchronized
    fun completePendingSwitch(context: Context) {
        val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val targetAlias = preferences.getString(PENDING_TARGET_KEY, null)
        if (targetAlias == null || targetAlias !in aliases) {
            clearPendingSwitch(context)
            return
        }

        applyExclusiveIcon(context, targetAlias)
        saveActiveAlias(preferences, targetAlias)
        clearPendingSwitch(context)
    }

    @Synchronized
    fun switchIcon(context: Context, targetAlias: String): Boolean {
        if (targetAlias !in aliases) return false

        applyExclusiveIcon(context, targetAlias)
        saveActiveAlias(
            context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE),
            targetAlias,
        )
        clearPendingSwitch(context)
        return true
    }

    private fun applyExclusiveIcon(context: Context, targetAlias: String) {
        val changes = aliases.mapNotNull { alias ->
            val shouldEnable = alias == targetAlias
            if (isEnabled(context, alias) == shouldEnable) return@mapNotNull null

            val state = if (shouldEnable) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            ComponentChange(component(context, alias), state)
        }
        if (changes.isEmpty()) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.setComponentEnabledSettings(
                changes.map { change ->
                    PackageManager.ComponentEnabledSetting(
                        change.component,
                        change.state,
                        PackageManager.DONT_KILL_APP,
                    )
                },
            )
            return
        }

        changes
            .filter { it.state == PackageManager.COMPONENT_ENABLED_STATE_DISABLED }
            .forEach { change -> setEnabled(context, change.component, false) }
        changes
            .filter { it.state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED }
            .forEach { change -> setEnabled(context, change.component, true) }
    }

    private fun saveActiveAlias(
        preferences: android.content.SharedPreferences,
        alias: String,
    ) {
        preferences.edit().putString(ACTIVE_ALIAS_KEY, alias).apply()
    }

    private fun clearPendingSwitch(context: Context) {
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(PENDING_TARGET_KEY)
            .apply()
    }

    private fun isEnabled(context: Context, alias: String): Boolean {
        val packageManager = context.packageManager
        val component = component(context, alias)
        return when (packageManager.getComponentEnabledSetting(component)) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED_USER,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED_UNTIL_USED,
            -> false
            else -> packageManager.getActivityInfo(
                component,
                PackageManager.MATCH_DISABLED_COMPONENTS,
            ).enabled
        }
    }

    private fun setEnabled(context: Context, component: ComponentName, enabled: Boolean) {
        context.packageManager.setComponentEnabledSetting(
            component,
            if (enabled) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            },
            PackageManager.DONT_KILL_APP,
        )
    }

    private fun component(context: Context, alias: String): ComponentName =
        ComponentName(context.packageName, "${context.packageName}$alias")

    private data class ComponentChange(
        val component: ComponentName,
        val state: Int,
    )

    private const val PREFERENCES_NAME = "AppIconSwitcher"
    private const val PENDING_TARGET_KEY = "pendingTargetAlias"
    private const val ACTIVE_ALIAS_KEY = "activeAlias"
}
