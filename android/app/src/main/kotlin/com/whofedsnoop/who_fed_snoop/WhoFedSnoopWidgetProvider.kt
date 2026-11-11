package com.whofedsnoop.who_fed_snoop

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews

class WhoFedSnoopWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        const val PREFS_NAME = "who_fed_snoop_widget_prefs"
        const val KEY_PET_NAME = "petName"
        const val KEY_HEADLINE = "headline"
        const val KEY_SUBHEADLINE = "subheadline"
        const val KEY_IS_FED = "isFed"
        const val KEY_MEAL_PERIOD = "mealPeriod"
        const val KEY_WINDOW_EMOJI = "windowEmoji"
        const val KEY_NEXT_TRANSITION_EPOCH_MS = "nextTransitionEpochMs"
        const val KEY_NEXT_WINDOW_LABEL = "nextWindowLabel"
        const val KEY_NEXT_WINDOW_EMOJI = "nextWindowEmoji"
        const val KEY_HOUSEHOLD_ID = "householdId"

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, WhoFedSnoopWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(componentName)
            for (id in ids) {
                updateWidget(context, manager, id)
            }
        }

        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val petName = prefs.getString(KEY_PET_NAME, "Snoop") ?: "Snoop"
            val storedHeadline = prefs.getString(KEY_HEADLINE, "🥣 $petName needs Breakfast")
                ?: "🥣 $petName needs Breakfast"
            val storedSubheadline = prefs.getString(
                KEY_SUBHEADLINE,
                "Tap to log & notify partner"
            ) ?: "Tap to log & notify partner"
            val storedIsFed = prefs.getBoolean(KEY_IS_FED, false)
            val storedMealPeriod =
                (prefs.getString(KEY_MEAL_PERIOD, "Breakfast") ?: "Breakfast").ifBlank { "Breakfast" }
            val storedWindowEmoji =
                (prefs.getString(KEY_WINDOW_EMOJI, "🐾") ?: "🐾").ifBlank { "🐾" }
            val nextTransitionEpochMs = prefs.getLong(KEY_NEXT_TRANSITION_EPOCH_MS, 0L)
            val storedNextWindowLabel = prefs.getString(KEY_NEXT_WINDOW_LABEL, "") ?: ""
            val storedNextWindowEmoji =
                (prefs.getString(KEY_NEXT_WINDOW_EMOJI, "🐾") ?: "🐾").ifBlank { "🐾" }
            val householdId = prefs.getString(KEY_HOUSEHOLD_ID, "household_snoop_01")
                ?: "household_snoop_01"

            val hasWindowRolledOver =
                nextTransitionEpochMs > 0L && System.currentTimeMillis() >= nextTransitionEpochMs

            val isFed: Boolean
            val windowLabel: String
            val windowEmoji: String
            val headline: String
            val subheadline: String

            if (hasWindowRolledOver) {
                isFed = false
                windowLabel = storedNextWindowLabel.ifBlank { storedMealPeriod }
                windowEmoji = storedNextWindowEmoji
                headline = "$windowEmoji $petName needs $windowLabel"
                subheadline = "Tap to log ${windowLabel.lowercase()} & notify partner"
            } else {
                isFed = storedIsFed
                windowLabel = storedMealPeriod
                windowEmoji = storedWindowEmoji
                headline = storedHeadline
                subheadline = storedSubheadline
            }

            val views = RemoteViews(context.packageName, R.layout.who_fed_snoop_widget)

            views.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                if (isFed) R.drawable.widget_background_fed else R.drawable.widget_background_hungry
            )
            views.setTextViewText(R.id.widget_badge, "$windowEmoji ${windowLabel.uppercase()} WINDOW")
            views.setTextColor(
                R.id.widget_badge,
                Color.parseColor(if (isFed) "#059669" else "#D97706")
            )
            views.setTextViewText(R.id.widget_headline, headline)
            views.setTextViewText(R.id.widget_subheadline, subheadline)

            if (isFed) {
                views.setViewVisibility(R.id.widget_action_button, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_action_button, View.VISIBLE)
                views.setTextViewText(R.id.widget_action_button, "I Fed $petName")
            }

            // Clicking the card opens the app
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openPendingIntent = PendingIntent.getActivity(
                context,
                0,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, openPendingIntent)

            // Clicking "I Fed Snoop" triggers the 1-tap /tap/{householdId} deep link
            val tapFeedIntent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("https://whofedsnoop.com/tap/$householdId"),
                context,
                MainActivity::class.java
            ).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val tapFeedPendingIntent = PendingIntent.getActivity(
                context,
                1,
                tapFeedIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_action_button, tapFeedPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
