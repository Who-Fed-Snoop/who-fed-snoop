package com.whofedsnoop.who_fed_snoop

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle

/**
 * Android Home Screen AppWidget provider for Who Fed Snoop?
 *
 * Uses a render-first pipeline on every `onUpdate` / window-cutoff alarm:
 * 1. Immediately renders from [WidgetPrefsStore] + [MealWindowResolver] rollover.
 * 2. Arms [WidgetAlarmScheduler] for the resolved `nextTransitionEpochMs`.
 * 3. Runs [WidgetFirestoreSync] (`goAsync()`, 1 Firestore read) to pick up
 *    partner feedings or schedule changes logged from other devices.
 */
class WhoFedSnoopWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == WidgetAlarmScheduler.ACTION_WINDOW_TRANSITION) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, WhoFedSnoopWidgetProvider::class.java)
            )
            if (ids.isEmpty()) {
                WidgetAlarmScheduler.cancel(context)
                return
            }
            val nextTransition = renderWidgetsFromPrefs(context, manager, ids, null)
            WidgetAlarmScheduler.scheduleWindowCutoff(context, nextTransition)
            WidgetFirestoreSync.syncAsync(context, goAsync())
            return
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val nextTransition = renderWidgetsFromPrefs(context, appWidgetManager, appWidgetIds, null)
        WidgetAlarmScheduler.scheduleWindowCutoff(context, nextTransition)
        WidgetFirestoreSync.syncAsync(context, goAsync())
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        renderWidgetsFromPrefs(context, appWidgetManager, intArrayOf(appWidgetId), newOptions)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetAlarmScheduler.cancel(context)
    }

    companion object {
        /**
         * Called by [MainActivity] when Flutter pushes a fresh snapshot over the
         * platform channel: re-renders immediately and re-arms the cutoff alarm
         * without issuing a redundant Firestore read.
         */
        fun updateAllWidgets(context: Context) {
            val nextTransition = renderAllWidgetsFromPrefs(context)
            WidgetAlarmScheduler.scheduleWindowCutoff(context, nextTransition)
        }

        /**
         * Re-renders every active widget instance from [WidgetPrefsStore] with
         * [MealWindowResolver] rollover applied, returning the resolved
         * `nextTransitionEpochMs`.
         */
        fun renderAllWidgetsFromPrefs(context: Context): Long {
            val manager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, WhoFedSnoopWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(componentName)
            if (ids.isEmpty()) {
                return 0L
            }
            return renderWidgetsFromPrefs(context, manager, ids, null)
        }

        private fun renderWidgetsFromPrefs(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray,
            appWidgetOptions: Bundle?
        ): Long {
            val snapshot = WidgetPrefsStore.read(context)
            val nowMs = System.currentTimeMillis()
            val resolved = MealWindowResolver.resolveFromCachedSnapshot(
                snapshot = snapshot,
                nowEpochMs = nowMs
            )

            // If we rolled forward using scheduleJson, persist the rolled state so
            // subsequent reads and alarm reschedules stay aligned even while offline.
            if (snapshot.nextTransitionEpochMs > 0L &&
                nowMs >= snapshot.nextTransitionEpochMs &&
                resolved.nextTransitionEpochMs > nowMs
            ) {
                WidgetPrefsStore.write(
                    context,
                    snapshot.copy(
                        headline = resolved.headline,
                        subheadline = resolved.subheadline,
                        isFed = resolved.isFed,
                        mealPeriod = resolved.windowLabel,
                        windowEmoji = resolved.windowEmoji,
                        windowId = resolved.windowId,
                        windowDate = resolved.windowDate,
                        nextTransitionEpochMs = resolved.nextTransitionEpochMs,
                        nextWindowLabel = resolved.nextWindowLabel,
                        nextWindowEmoji = resolved.nextWindowEmoji,
                        todayTreatCount = resolved.todayTreatCount,
                        treatLogicalDate = resolved.windowDate
                    )
                )
            }

            for (appWidgetId in appWidgetIds) {
                WidgetContentFormatter.bindAndApplyWidget(
                    context = context,
                    appWidgetManager = appWidgetManager,
                    appWidgetId = appWidgetId,
                    state = resolved,
                    householdId = snapshot.householdId,
                    appWidgetOptions = appWidgetOptions
                )
            }
            return resolved.nextTransitionEpochMs
        }
    }
}
