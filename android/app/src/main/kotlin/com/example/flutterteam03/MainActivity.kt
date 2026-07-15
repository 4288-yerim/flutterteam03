package com.example.flutterteam03  // 실제 패키지명으로

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app_icon_switcher"

    private val aliases = listOf(
        ".IconDefault", ".Icon3", ".Icon7", ".Icon14",
        ".Icon21", ".Icon30", ".Icon60", ".IconGood"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "switchIcon") {
                val target = call.argument<String>("alias") ?: ".IconDefault"
                switchIcon(target)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun switchIcon(targetAlias: String) {
        val pm = packageManager
        for (alias in aliases) {
            val state = if (alias == targetAlias) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            pm.setComponentEnabledSetting(
                ComponentName(packageName, "$packageName$alias"),
                state,
                PackageManager.DONT_KILL_APP
            )
        }
    }
}