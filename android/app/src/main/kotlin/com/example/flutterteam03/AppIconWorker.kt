package com.example.flutterteam03

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.Calendar
import java.util.concurrent.TimeUnit

class AppIconWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    override fun doWork(): Result {
        val preferences = applicationContext.getSharedPreferences(
            FLUTTER_PREFERENCES,
            Context.MODE_PRIVATE,
        )
        if (!preferences.contains(LAST_OPENED_DATE_KEY)) return Result.success()

        val lastOpenedDay = preferences.getLong(LAST_OPENED_DATE_KEY, 0L)
        val inactiveDays = (todayEpochDay() - lastOpenedDay).toInt()
        if (inactiveDays <= 1) return Result.success()

        preferences.edit().putLong(CURRENT_STREAK_KEY, 0L).apply()
        AppIconSwitcher.switchIcon(
            applicationContext,
            AppIconSwitcher.aliasForInactiveDays(inactiveDays),
        )
        return Result.success()
    }

    private fun todayEpochDay(): Long {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return calendar.timeInMillis / TimeUnit.DAYS.toMillis(1)
    }

    companion object {
        private const val WORK_NAME = "checkInactivityIconTask"
        private const val FLUTTER_PREFERENCES = "FlutterSharedPreferences"
        private const val LAST_OPENED_DATE_KEY = "flutter.lastOpenedDateEpochDay"
        private const val CURRENT_STREAK_KEY = "flutter.currentStreak"

        fun schedule(context: Context) {
            val request = PeriodicWorkRequest.Builder(
                AppIconWorker::class.java,
                24,
                TimeUnit.HOURS,
            ).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.REPLACE,
                request,
            )
        }
    }
}
