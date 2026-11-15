package com.whofedsnoop.who_fed_snoop

import android.content.Context

/**
 * Typed snapshot of the Home Widget display & sync state persisted in
 * `who_fed_snoop_widget_prefs`.
 */
data class WidgetDisplaySnapshot(
    val petName: String = "Snoop",
    val headline: String = "🥣 Snoop needs Breakfast",
    val subheadline: String = "Tap to log & notify partner",
    val isFed: Boolean = false,
    val mealPeriod: String = "Breakfast",
    val windowEmoji: String = "🐾",
    val windowId: String = "breakfast",
    val windowDate: String = "",
    val nextTransitionEpochMs: Long = 0L,
    val nextWindowLabel: String = "",
    val nextWindowEmoji: String = "🐾",
    val householdId: String = "household_snoop_01",
    val scheduleJson: String = "",
    val useEmulator: Boolean = false,
    val dailyTreatLimit: Int = 4,
    val todayTreatCount: Int = 0,
    val treatLogicalDate: String = "",
    val lastSyncEpochMs: Long = 0L
)

/**
 * Single source of truth for reading and writing `who_fed_snoop_widget_prefs`
 * across [MainActivity], [WidgetFirestoreSync], [WidgetAlarmScheduler], and
 * [WhoFedSnoopWidgetProvider].
 */
object WidgetPrefsStore {
    const val PREFS_NAME = "who_fed_snoop_widget_prefs"

    const val KEY_PET_NAME = "petName"
    const val KEY_HEADLINE = "headline"
    const val KEY_SUBHEADLINE = "subheadline"
    const val KEY_IS_FED = "isFed"
    const val KEY_MEAL_PERIOD = "mealPeriod"
    const val KEY_WINDOW_EMOJI = "windowEmoji"
    const val KEY_WINDOW_ID = "windowId"
    const val KEY_WINDOW_DATE = "windowDate"
    const val KEY_NEXT_TRANSITION_EPOCH_MS = "nextTransitionEpochMs"
    const val KEY_NEXT_WINDOW_LABEL = "nextWindowLabel"
    const val KEY_NEXT_WINDOW_EMOJI = "nextWindowEmoji"
    const val KEY_HOUSEHOLD_ID = "householdId"
    const val KEY_SCHEDULE_JSON = "scheduleJson"
    const val KEY_USE_EMULATOR = "useEmulator"
    const val KEY_DAILY_TREAT_LIMIT = "dailyTreatLimit"
    const val KEY_TODAY_TREAT_COUNT = "todayTreatCount"
    const val KEY_TREAT_LOGICAL_DATE = "treatLogicalDate"
    const val KEY_LAST_SYNC_EPOCH_MS = "lastSyncEpochMs"

    const val DEFAULT_HOUSEHOLD_ID = "household_snoop_01"

    fun read(context: Context): WidgetDisplaySnapshot {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val petName = (prefs.getString(KEY_PET_NAME, "Snoop") ?: "Snoop").ifBlank { "Snoop" }
        val headline = prefs.getString(KEY_HEADLINE, "🥣 $petName needs Breakfast")
            ?: "🥣 $petName needs Breakfast"
        val subheadline = prefs.getString(KEY_SUBHEADLINE, "Tap to log & notify partner")
            ?: "Tap to log & notify partner"
        val mealPeriod =
            (prefs.getString(KEY_MEAL_PERIOD, "Breakfast") ?: "Breakfast").ifBlank { "Breakfast" }
        val windowEmoji =
            (prefs.getString(KEY_WINDOW_EMOJI, "🐾") ?: "🐾").ifBlank { "🐾" }
        val windowId =
            (prefs.getString(KEY_WINDOW_ID, "breakfast") ?: "breakfast").ifBlank { "breakfast" }
        val windowDate = prefs.getString(KEY_WINDOW_DATE, "") ?: ""
        val nextWindowEmoji =
            (prefs.getString(KEY_NEXT_WINDOW_EMOJI, "🐾") ?: "🐾").ifBlank { "🐾" }
        val householdId = (prefs.getString(KEY_HOUSEHOLD_ID, DEFAULT_HOUSEHOLD_ID)
            ?: DEFAULT_HOUSEHOLD_ID).ifBlank { DEFAULT_HOUSEHOLD_ID }

        return WidgetDisplaySnapshot(
            petName = petName,
            headline = headline,
            subheadline = subheadline,
            isFed = prefs.getBoolean(KEY_IS_FED, false),
            mealPeriod = mealPeriod,
            windowEmoji = windowEmoji,
            windowId = windowId,
            windowDate = windowDate,
            nextTransitionEpochMs = prefs.getLong(KEY_NEXT_TRANSITION_EPOCH_MS, 0L),
            nextWindowLabel = prefs.getString(KEY_NEXT_WINDOW_LABEL, "") ?: "",
            nextWindowEmoji = nextWindowEmoji,
            householdId = householdId,
            scheduleJson = prefs.getString(KEY_SCHEDULE_JSON, "") ?: "",
            useEmulator = prefs.getBoolean(KEY_USE_EMULATOR, false),
            dailyTreatLimit = prefs.getInt(KEY_DAILY_TREAT_LIMIT, 4).coerceIn(1, 50),
            todayTreatCount = prefs.getInt(KEY_TODAY_TREAT_COUNT, 0).coerceAtLeast(0),
            treatLogicalDate = prefs.getString(KEY_TREAT_LOGICAL_DATE, "") ?: "",
            lastSyncEpochMs = prefs.getLong(KEY_LAST_SYNC_EPOCH_MS, 0L)
        )
    }

    fun write(context: Context, snapshot: WidgetDisplaySnapshot) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_PET_NAME, snapshot.petName.ifBlank { "Snoop" })
            .putString(KEY_HEADLINE, snapshot.headline)
            .putString(KEY_SUBHEADLINE, snapshot.subheadline)
            .putBoolean(KEY_IS_FED, snapshot.isFed)
            .putString(KEY_MEAL_PERIOD, snapshot.mealPeriod.ifBlank { "Breakfast" })
            .putString(KEY_WINDOW_EMOJI, snapshot.windowEmoji.ifBlank { "🐾" })
            .putString(KEY_WINDOW_ID, snapshot.windowId.ifBlank { "breakfast" })
            .putString(KEY_WINDOW_DATE, snapshot.windowDate)
            .putLong(KEY_NEXT_TRANSITION_EPOCH_MS, snapshot.nextTransitionEpochMs)
            .putString(KEY_NEXT_WINDOW_LABEL, snapshot.nextWindowLabel)
            .putString(KEY_NEXT_WINDOW_EMOJI, snapshot.nextWindowEmoji.ifBlank { "🐾" })
            .putString(KEY_HOUSEHOLD_ID, snapshot.householdId.ifBlank { DEFAULT_HOUSEHOLD_ID })
            .putString(KEY_SCHEDULE_JSON, snapshot.scheduleJson)
            .putBoolean(KEY_USE_EMULATOR, snapshot.useEmulator)
            .putInt(KEY_DAILY_TREAT_LIMIT, snapshot.dailyTreatLimit.coerceIn(1, 50))
            .putInt(KEY_TODAY_TREAT_COUNT, snapshot.todayTreatCount.coerceAtLeast(0))
            .putString(KEY_TREAT_LOGICAL_DATE, snapshot.treatLogicalDate)
            .putLong(KEY_LAST_SYNC_EPOCH_MS, snapshot.lastSyncEpochMs)
            .apply()
    }
}
