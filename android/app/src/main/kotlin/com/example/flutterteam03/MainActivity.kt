package com.example.flutterteam03

import android.content.pm.ApplicationInfo
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppIconWorker.schedule(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "switchIcon" -> {
                        val target = call.argument<String>("alias")
                            ?: AppIconSwitcher.ALIAS_DEFAULT
                        if (AppIconSwitcher.prepareIconSwitch(this, target)) {
                            result.success(null)
                        } else {
                            result.error("INVALID_ALIAS", "Unknown launcher alias: $target", null)
                        }
                    }

                    "testInactiveDays" -> {
                        if (!isDebuggable()) {
                            result.notImplemented()
                            return@setMethodCallHandler
                        }

                        val days = call.argument<Int>("days") ?: 0
                        val target = AppIconSwitcher.aliasForInactiveDays(days.coerceAtLeast(0))
                        AppIconSwitcher.prepareIconSwitch(this, target)
                        result.success(target)
                    }

                    "testGoodIcon" -> {
                        if (!isDebuggable()) {
                            result.notImplemented()
                            return@setMethodCallHandler
                        }

                        AppIconSwitcher.prepareIconSwitch(this, AppIconSwitcher.ALIAS_GOOD)
                        result.success(AppIconSwitcher.ALIAS_GOOD)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onStop() {
        super.onStop()
        AppIconSwitcher.completePendingSwitch(this)
    }

    private fun isDebuggable(): Boolean =
        applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    companion object {
        private const val CHANNEL = "app_icon_switcher"
    }
}
