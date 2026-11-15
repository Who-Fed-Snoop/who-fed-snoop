package com.whofedsnoop.who_fed_snoop

import java.util.Calendar
import java.util.TimeZone

/**
 * Pure Kotlin port of Dart's `Household.feedingForWindow`,
 * `Household.treatCountForDate`, and `WidgetSyncService` headline formatting.
 *
 * Intentionally free of Android/Firebase SDK dependencies so feeding/treat
 * matching, offline rollover, and ISO-8601 parsing run in fast JVM unit tests.
 */
data class FeedingRecord(
    val id: String,
    val mealPeriod: MealPeriod,
    val windowDate: String,
    val fedByUid: String,
    val fedByName: String,
    val fedAtEpochMs: Long,
    val isExtraMeal: Boolean = false,
    val windowId: String? = null,
    val windowLabel: String? = null,
    val windowEmoji: String? = null
) {
    val effectiveWindowId: String
        get() = windowId?.takeIf { it.isNotEmpty() } ?: mealPeriod.wireName

    val effectiveLabel: String
        get() = windowLabel?.takeIf { it.isNotEmpty() } ?: mealPeriod.defaultLabel

    fun matchesWindow(window: ActiveMealWindow): Boolean {
        if (isExtraMeal) return false
        return windowDate == window.windowDate && effectiveWindowId == window.windowId
    }
}

data class TreatRecord(
    val logicalDate: String,
    val quantity: Int = 1
)

data class ResolvedWidgetState(
    val petName: String,
    val isFed: Boolean,
    val windowId: String,
    val windowDate: String,
    val windowLabel: String,
    val windowEmoji: String,
    val headline: String,
    val subheadline: String,
    val nextTransitionEpochMs: Long,
    val nextWindowLabel: String,
    val nextWindowEmoji: String,
    val todayTreatCount: Int,
    val dailyTreatLimit: Int
)

object MealWindowResolver {
    private val ISO_REGEX = Regex(
        """^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|[+-]\d{2}:?\d{2})?$"""
    )

    fun feedingForWindow(
        window: ActiveMealWindow,
        todayMeals: Map<String, FeedingRecord>,
        lastFeeding: FeedingRecord?
    ): FeedingRecord? {
        val fromMap = todayMeals[window.deterministicId]
        if (fromMap != null && fromMap.matchesWindow(window)) {
            return fromMap
        }
        if (lastFeeding != null && lastFeeding.matchesWindow(window)) {
            return lastFeeding
        }
        return null
    }

    fun treatCountForDate(treats: List<TreatRecord>, logicalDate: String): Int {
        return treats.filter { it.logicalDate == logicalDate }.sumOf { it.quantity.coerceIn(1, 20) }
    }

    fun resolveWidgetDisplayFromHousehold(
        petName: String,
        schedule: MealSchedule,
        lastFeeding: FeedingRecord?,
        todayMeals: Map<String, FeedingRecord>,
        todayTreats: List<TreatRecord>,
        dailyTreatLimit: Int,
        nowEpochMs: Long,
        timeZone: TimeZone = TimeZone.getDefault()
    ): ResolvedWidgetState {
        val safePetName = petName.trim().ifEmpty { "Snoop" }
        val safeTreatLimit = dailyTreatLimit.coerceIn(1, 50)
        val activeWindow = ActiveMealWindow.forTime(nowEpochMs, schedule, timeZone)
        val currentFeeding = feedingForWindow(activeWindow, todayMeals, lastFeeding)
        val isFed = currentFeeding != null
        val todayTreatCount = treatCountForDate(todayTreats, activeWindow.windowDate)
        val treatSuffix = formatTreatSuffix(todayTreatCount, safeTreatLimit)

        val headline: String
        val subheadline: String
        if (currentFeeding != null) {
            val formattedTime = formatClockTime(currentFeeding.fedAtEpochMs, timeZone)
            headline = "✅ ${currentFeeding.fedByName} fed $safePetName ${activeWindow.label}"
            subheadline = "Logged at $formattedTime$treatSuffix"
        } else {
            headline = "${activeWindow.emoji} $safePetName needs ${activeWindow.label}"
            subheadline = if (lastFeeding != null) {
                val formattedTime = formatClockTime(lastFeeding.fedAtEpochMs, timeZone)
                "Last fed: ${lastFeeding.effectiveLabel} by ${lastFeeding.fedByName} ($formattedTime)$treatSuffix"
            } else {
                "Tap to log ${activeWindow.label.lowercase()}$treatSuffix"
            }
        }

        return ResolvedWidgetState(
            petName = safePetName,
            isFed = isFed,
            windowId = activeWindow.windowId,
            windowDate = activeWindow.windowDate,
            windowLabel = activeWindow.label,
            windowEmoji = activeWindow.emoji,
            headline = headline,
            subheadline = subheadline,
            nextTransitionEpochMs = activeWindow.nextTransitionEpochMs,
            nextWindowLabel = activeWindow.nextWindowLabel,
            nextWindowEmoji = activeWindow.nextWindowEmoji,
            todayTreatCount = todayTreatCount,
            dailyTreatLimit = safeTreatLimit
        )
    }

    /**
     * Resolves current display state from cached [WidgetDisplaySnapshot],
     * accurately rolling forward across one or multiple missed window transitions
     * whenever `scheduleJson` is available.
     */
    fun resolveFromCachedSnapshot(
        snapshot: WidgetDisplaySnapshot,
        nowEpochMs: Long,
        timeZone: TimeZone = TimeZone.getDefault()
    ): ResolvedWidgetState {
        val hasRolledOver =
            snapshot.nextTransitionEpochMs > 0L && nowEpochMs >= snapshot.nextTransitionEpochMs
        if (!hasRolledOver) {
            return ResolvedWidgetState(
                petName = snapshot.petName,
                isFed = snapshot.isFed,
                windowId = snapshot.windowId,
                windowDate = snapshot.windowDate,
                windowLabel = snapshot.mealPeriod,
                windowEmoji = snapshot.windowEmoji,
                headline = snapshot.headline,
                subheadline = snapshot.subheadline,
                nextTransitionEpochMs = snapshot.nextTransitionEpochMs,
                nextWindowLabel = snapshot.nextWindowLabel,
                nextWindowEmoji = snapshot.nextWindowEmoji,
                todayTreatCount = snapshot.todayTreatCount,
                dailyTreatLimit = snapshot.dailyTreatLimit
            )
        }

        if (snapshot.scheduleJson.isNotBlank()) {
            val schedule = MealSchedule.fromJsonString(snapshot.scheduleJson)
            val activeWindow = ActiveMealWindow.forTime(nowEpochMs, schedule, timeZone)
            val preservedTreatCount =
                if (snapshot.treatLogicalDate == activeWindow.windowDate) snapshot.todayTreatCount else 0
            val treatSuffix = formatTreatSuffix(preservedTreatCount, snapshot.dailyTreatLimit)
            return ResolvedWidgetState(
                petName = snapshot.petName,
                isFed = false,
                windowId = activeWindow.windowId,
                windowDate = activeWindow.windowDate,
                windowLabel = activeWindow.label,
                windowEmoji = activeWindow.emoji,
                headline = "${activeWindow.emoji} ${snapshot.petName} needs ${activeWindow.label}",
                subheadline = "Tap to log ${activeWindow.label.lowercase()}$treatSuffix",
                nextTransitionEpochMs = activeWindow.nextTransitionEpochMs,
                nextWindowLabel = activeWindow.nextWindowLabel,
                nextWindowEmoji = activeWindow.nextWindowEmoji,
                todayTreatCount = preservedTreatCount,
                dailyTreatLimit = snapshot.dailyTreatLimit
            )
        }

        // Legacy fallback before first scheduleJson sync: flip once using nextWindowLabel.
        val label = snapshot.nextWindowLabel.ifBlank { snapshot.mealPeriod }
        val emoji = snapshot.nextWindowEmoji
        return ResolvedWidgetState(
            petName = snapshot.petName,
            isFed = false,
            windowId = snapshot.windowId,
            windowDate = snapshot.windowDate,
            windowLabel = label,
            windowEmoji = emoji,
            headline = "$emoji ${snapshot.petName} needs $label",
            subheadline = "Tap to log ${label.lowercase()} & notify partner",
            nextTransitionEpochMs = 0L,
            nextWindowLabel = "",
            nextWindowEmoji = "🐾",
            todayTreatCount = 0,
            dailyTreatLimit = snapshot.dailyTreatLimit
        )
    }

    fun formatClockTime(epochMs: Long, timeZone: TimeZone = TimeZone.getDefault()): String {
        val cal = Calendar.getInstance(timeZone).apply { timeInMillis = epochMs }
        val hour24 = cal.get(Calendar.HOUR_OF_DAY)
        val hour12 = if (hour24 % 12 == 0) 12 else hour24 % 12
        val minute = cal.get(Calendar.MINUTE).toString().padStart(2, '0')
        val suffix = if (hour24 >= 12) "PM" else "AM"
        return "$hour12:$minute $suffix"
    }

    fun parseIsoTimestampMs(raw: String?, fallbackMs: Long = 0L, defaultZone: TimeZone = TimeZone.getDefault()): Long {
        val trimmed = raw?.trim().orEmpty()
        if (trimmed.isEmpty()) return fallbackMs
        val match = ISO_REGEX.matchEntire(trimmed) ?: return fallbackMs
        val year = match.groupValues[1].toInt()
        val month = match.groupValues[2].toInt()
        val day = match.groupValues[3].toInt()
        val hour = match.groupValues[4].toInt()
        val minute = match.groupValues[5].toInt()
        val second = match.groupValues[6].toInt()
        val frac = match.groupValues[7]
        val millis = if (frac.isEmpty()) 0 else frac.padEnd(3, '0').substring(0, 3).toInt()
        val zoneToken = match.groupValues[8]

        val tz: TimeZone = when {
            zoneToken.isEmpty() -> defaultZone
            zoneToken == "Z" -> TimeZone.getTimeZone("UTC")
            else -> TimeZone.getTimeZone("GMT$zoneToken")
        }

        return Calendar.getInstance(tz).apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month - 1)
            set(Calendar.DAY_OF_MONTH, day)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, second)
            set(Calendar.MILLISECOND, millis)
        }.timeInMillis
    }

    private fun formatTreatSuffix(todayTreatCount: Int, dailyTreatLimit: Int): String {
        return if (todayTreatCount > 0) " • 🦴 $todayTreatCount/$dailyTreatLimit treats" else ""
    }
}
