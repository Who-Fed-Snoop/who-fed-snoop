package com.whofedsnoop.who_fed_snoop

import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

/**
 * Pure Kotlin port of Dart's `MealPeriod`, `MealWindowConfig`, `MealSchedule`,
 * and `ActiveMealWindow.forTime`.
 *
 * Intentionally free of Android/Firebase SDK dependencies so schedule parsing
 * and boundary transitions run in fast JVM unit tests (`testDebugUnitTest`).
 */
enum class MealPeriod(
    val wireName: String,
    val defaultLabel: String,
    val defaultEmoji: String,
    val defaultHour: Int,
    val defaultMinute: Int
) {
    BREAKFAST("breakfast", "Breakfast", "🥣", 4, 0),
    LUNCH("lunch", "Lunch", "🍲", 12, 0),
    DINNER("dinner", "Dinner", "🍖", 14, 0),
    LATE_SNACK("lateSnack", "Late Snack", "🌙", 20, 30),
    CUSTOM("custom", "Meal", "🐾", 12, 0);

    companion object {
        fun fromString(value: String?): MealPeriod {
            val normalized = value?.trim().orEmpty()
            if (normalized == "late_snack") return LATE_SNACK
            return entries.firstOrNull { it.wireName == normalized } ?: CUSTOM
        }
    }
}

data class MealWindowConfig(
    val id: String,
    val period: MealPeriod,
    val label: String,
    val emoji: String,
    val startHour: Int,
    val startMinute: Int = 0,
    val enabled: Boolean = true
) {
    val startMinutesOfDay: Int
        get() = startHour * 60 + startMinute

    fun toJsonObject(): JSONObject = JSONObject().apply {
        put("id", id.trim())
        put("period", period.wireName)
        put("label", label.trim())
        put("emoji", emoji.trim())
        put("startHour", startHour)
        put("startMinute", startMinute)
        put("enabled", enabled)
    }

    companion object {
        fun fromMap(map: Map<*, *>): MealWindowConfig {
            val rawPeriod = (map["period"] as? String) ?: (map["id"] as? String) ?: "breakfast"
            val period = MealPeriod.fromString(rawPeriod)
            val id = (map["id"] as? String)?.trim()?.takeIf { it.isNotEmpty() } ?: period.wireName
            val label =
                (map["label"] as? String)?.trim()?.takeIf { it.isNotEmpty() } ?: period.defaultLabel
            val emoji =
                (map["emoji"] as? String)?.trim()?.takeIf { it.isNotEmpty() } ?: period.defaultEmoji
            val startHour = (map["startHour"] as? Number)?.toInt() ?: period.defaultHour
            val startMinute = (map["startMinute"] as? Number)?.toInt() ?: 0
            val enabled = (map["enabled"] as? Boolean) ?: true
            return MealWindowConfig(id, period, label, emoji, startHour, startMinute, enabled)
        }

        fun fromJsonObject(json: JSONObject): MealWindowConfig {
            val rawPeriod = json.optString("period").takeIf { it.isNotEmpty() }
                ?: json.optString("id").takeIf { it.isNotEmpty() }
                ?: "breakfast"
            val period = MealPeriod.fromString(rawPeriod)
            val id = json.optString("id").trim().takeIf { it.isNotEmpty() } ?: period.wireName
            val label =
                json.optString("label").trim().takeIf { it.isNotEmpty() } ?: period.defaultLabel
            val emoji =
                json.optString("emoji").trim().takeIf { it.isNotEmpty() } ?: period.defaultEmoji
            val startHour =
                if (json.has("startHour") && !json.isNull("startHour")) json.optInt("startHour") else period.defaultHour
            val startMinute =
                if (json.has("startMinute") && !json.isNull("startMinute")) json.optInt("startMinute") else 0
            val enabled = if (json.has("enabled") && !json.isNull("enabled")) json.optBoolean("enabled", true) else true
            return MealWindowConfig(id, period, label, emoji, startHour, startMinute, enabled)
        }
    }
}

data class MealSchedule(
    val breakfastStartHour: Int = 4,
    val dinnerStartHour: Int = 14,
    val windows: List<MealWindowConfig>? = null
) {
    val allWindows: List<MealWindowConfig>
        get() {
            val explicit = windows
            if (!explicit.isNullOrEmpty()) {
                return explicit.sortedBy { it.startMinutesOfDay }
            }
            return listOf(
                MealWindowConfig(
                    id = MealPeriod.BREAKFAST.wireName,
                    period = MealPeriod.BREAKFAST,
                    label = MealPeriod.BREAKFAST.defaultLabel,
                    emoji = MealPeriod.BREAKFAST.defaultEmoji,
                    startHour = breakfastStartHour
                ),
                MealWindowConfig(
                    id = MealPeriod.DINNER.wireName,
                    period = MealPeriod.DINNER,
                    label = MealPeriod.DINNER.defaultLabel,
                    emoji = MealPeriod.DINNER.defaultEmoji,
                    startHour = dinnerStartHour
                )
            ).sortedBy { it.startMinutesOfDay }
        }

    val enabledWindows: List<MealWindowConfig>
        get() {
            val candidates = allWindows
                .filter { it.enabled }
                .map { w ->
                    w.copy(
                        id = w.id.trim().ifEmpty { w.period.wireName },
                        label = w.label.trim().ifEmpty { w.period.defaultLabel },
                        emoji = w.emoji.trim().ifEmpty { w.period.defaultEmoji },
                        startHour = w.startHour.coerceIn(0, 23),
                        startMinute = w.startMinute.coerceIn(0, 59)
                    )
                }
                .sortedBy { it.startMinutesOfDay }

            val deduped = mutableListOf<MealWindowConfig>()
            for (win in candidates) {
                if (deduped.isEmpty() || deduped.last().startMinutesOfDay != win.startMinutesOfDay) {
                    deduped.add(win)
                }
            }

            if (deduped.isEmpty()) {
                return listOf(
                    MealWindowConfig("breakfast", MealPeriod.BREAKFAST, "Breakfast", "🥣", 4),
                    MealWindowConfig("dinner", MealPeriod.DINNER, "Dinner", "🍖", 14)
                )
            }
            return deduped
        }

    fun toJsonString(): String {
        val list = allWindows
        val breakfastWin = list.firstOrNull { it.period == MealPeriod.BREAKFAST }
        val dinnerWin = list.firstOrNull { it.period == MealPeriod.DINNER }
        val safeBreakfast = (breakfastWin?.startHour ?: breakfastStartHour).coerceIn(0, 23)
        val safeDinner = (dinnerWin?.startHour ?: dinnerStartHour).coerceIn(0, 23)
        val array = JSONArray()
        for (w in list) {
            array.put(w.toJsonObject())
        }
        return JSONObject().apply {
            put("breakfastStartHour", safeBreakfast)
            put("dinnerStartHour", safeDinner)
            put("windows", array)
        }.toString()
    }

    companion object {
        fun fromJsonString(raw: String?): MealSchedule {
            if (raw.isNullOrBlank()) return MealSchedule()
            return try {
                fromJsonObject(JSONObject(raw))
            } catch (_: Throwable) {
                MealSchedule()
            }
        }

        fun fromJsonObject(json: JSONObject): MealSchedule {
            val bHour = (if (json.has("breakfastStartHour")) json.optInt("breakfastStartHour", 4) else 4).coerceIn(0, 23)
            val dHour = (if (json.has("dinnerStartHour")) json.optInt("dinnerStartHour", 14) else 14).coerceIn(0, 23)
            val rawWindows = json.optJSONArray("windows")
            if (rawWindows != null && rawWindows.length() > 0) {
                val parsed = mutableListOf<MealWindowConfig>()
                for (i in 0 until rawWindows.length()) {
                    val obj = rawWindows.optJSONObject(i) ?: continue
                    parsed.add(MealWindowConfig.fromJsonObject(obj))
                }
                if (parsed.isNotEmpty()) {
                    return MealSchedule(bHour, dHour, parsed)
                }
            }
            return MealSchedule(bHour, dHour)
        }

        fun fromMap(map: Map<*, *>?): MealSchedule {
            if (map == null) return MealSchedule()
            val bHour = ((map["breakfastStartHour"] as? Number)?.toInt() ?: 4).coerceIn(0, 23)
            val dHour = ((map["dinnerStartHour"] as? Number)?.toInt() ?: 14).coerceIn(0, 23)
            val rawWindows = map["windows"] as? List<*>
            if (!rawWindows.isNullOrEmpty()) {
                val parsed = rawWindows.mapNotNull { item ->
                    (item as? Map<*, *>)?.let { MealWindowConfig.fromMap(it) }
                }
                if (parsed.isNotEmpty()) {
                    return MealSchedule(bHour, dHour, parsed)
                }
            }
            return MealSchedule(bHour, dHour)
        }
    }
}

data class ActiveMealWindow(
    val period: MealPeriod,
    val windowId: String,
    val label: String,
    val emoji: String,
    val windowDate: String,
    val nextTransitionEpochMs: Long,
    val nextWindowLabel: String,
    val nextWindowEmoji: String
) {
    val deterministicId: String
        get() = "${windowDate}_$windowId"

    companion object {
        fun forTime(
            epochMs: Long,
            schedule: MealSchedule = MealSchedule(),
            timeZone: TimeZone = TimeZone.getDefault()
        ): ActiveMealWindow {
            val local = Calendar.getInstance(timeZone).apply { timeInMillis = epochMs }
            val nowMinutes = local.get(Calendar.HOUR_OF_DAY) * 60 + local.get(Calendar.MINUTE)
            val enabled = schedule.enabledWindows
            val firstWindow = enabled.first()

            if (nowMinutes < firstWindow.startMinutesOfDay) {
                val activeConfig = enabled.last()
                val yesterday = (local.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -1) }
                val nextTransition = atClock(local, firstWindow.startHour, firstWindow.startMinute)
                return ActiveMealWindow(
                    period = activeConfig.period,
                    windowId = activeConfig.id,
                    label = activeConfig.label,
                    emoji = activeConfig.emoji,
                    windowDate = formatDate(yesterday),
                    nextTransitionEpochMs = nextTransition.timeInMillis,
                    nextWindowLabel = firstWindow.label,
                    nextWindowEmoji = firstWindow.emoji
                )
            }

            var activeIndex = 0
            for (i in enabled.indices) {
                if (nowMinutes >= enabled[i].startMinutesOfDay) {
                    activeIndex = i
                } else {
                    break
                }
            }

            val activeConfig = enabled[activeIndex]
            val windowDate = formatDate(local)

            if (activeIndex + 1 < enabled.size) {
                val nextConfig = enabled[activeIndex + 1]
                val nextTransition = atClock(local, nextConfig.startHour, nextConfig.startMinute)
                return ActiveMealWindow(
                    period = activeConfig.period,
                    windowId = activeConfig.id,
                    label = activeConfig.label,
                    emoji = activeConfig.emoji,
                    windowDate = windowDate,
                    nextTransitionEpochMs = nextTransition.timeInMillis,
                    nextWindowLabel = nextConfig.label,
                    nextWindowEmoji = nextConfig.emoji
                )
            }

            val tomorrow = (local.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }
            val nextTransition = atClock(tomorrow, firstWindow.startHour, firstWindow.startMinute)
            return ActiveMealWindow(
                period = activeConfig.period,
                windowId = activeConfig.id,
                label = activeConfig.label,
                emoji = activeConfig.emoji,
                windowDate = windowDate,
                nextTransitionEpochMs = nextTransition.timeInMillis,
                nextWindowLabel = firstWindow.label,
                nextWindowEmoji = firstWindow.emoji
            )
        }

        private fun atClock(base: Calendar, hour: Int, minute: Int): Calendar {
            return (base.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
        }

        fun formatDate(cal: Calendar): String {
            val y = cal.get(Calendar.YEAR).toString().padStart(4, '0')
            val m = (cal.get(Calendar.MONTH) + 1).toString().padStart(2, '0')
            val d = cal.get(Calendar.DAY_OF_MONTH).toString().padStart(2, '0')
            return "$y-$m-$d"
        }
    }
}
