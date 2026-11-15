package com.whofedsnoop.who_fed_snoop

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * Schedules and cancels the Home Widget window-cutoff wakeup using
 * `AlarmManager.setAndAllowWhileIdle(RTC_WAKEUP, ...)` so meal window transitions
 * flip promptly without waiting on coarse 30-minute OS widget ticks or requiring
 * restricted exact-alarm permissions (`USE_EXACT_ALARM` / `SCHEDULE_EXACT_ALARM`).
 */
object WidgetAlarmScheduler {
    const val ACTION_WINDOW_TRANSITION =
        "com.whofedsnoop.who_fed_snoop.ACTION_WINDOW_TRANSITION"
    private const val REQUEST_CODE_WINDOW_TRANSITION = 4201

    fun scheduleWindowCutoff(context: Context, nextTransitionEpochMs: Long) {
        val nowMs = System.currentTimeMillis()
        if (nextTransitionEpochMs <= nowMs) {
            return
        }
        if (!hasActiveWidgets(context)) {
            cancel(context)
            return
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pendingIntent = buildPendingIntent(context) ?: return
        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            nextTransitionEpochMs,
            pendingIntent
        )
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pendingIntent = buildExistingPendingIntent(context) ?: return
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    fun rescheduleFromPrefs(context: Context) {
        if (!hasActiveWidgets(context)) {
            cancel(context)
            return
        }
        val snapshot = WidgetPrefsStore.read(context)
        val resolved = MealWindowResolver.resolveFromCachedSnapshot(
            snapshot = snapshot,
            nowEpochMs = System.currentTimeMillis()
        )
        scheduleWindowCutoff(context, resolved.nextTransitionEpochMs)
    }

    fun hasActiveWidgets(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, WhoFedSnoopWidgetProvider::class.java)
        )
        return ids.isNotEmpty()
    }

    private fun buildPendingIntent(context: Context): PendingIntent? {
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_WINDOW_TRANSITION,
            buildAlarmIntent(context),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildExistingPendingIntent(context: Context): PendingIntent? {
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_WINDOW_TRANSITION,
            buildAlarmIntent(context),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildAlarmIntent(context: Context): Intent {
        return Intent(context, WhoFedSnoopWidgetProvider::class.java).apply {
            action = ACTION_WINDOW_TRANSITION
        }
    }
}
