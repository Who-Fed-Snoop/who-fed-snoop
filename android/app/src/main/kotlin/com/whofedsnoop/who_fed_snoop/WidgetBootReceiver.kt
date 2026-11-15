package com.whofedsnoop.who_fed_snoop

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-arms the Home Widget window-cutoff alarm and triggers a background
 * refresh when the device reboots or the app package is replaced.
 */
class WidgetBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }
        if (!WidgetAlarmScheduler.hasActiveWidgets(context)) {
            return
        }
        WhoFedSnoopWidgetProvider.renderAllWidgetsFromPrefs(context)
        WidgetAlarmScheduler.rescheduleFromPrefs(context)
    }
}
