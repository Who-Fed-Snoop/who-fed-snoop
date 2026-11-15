package com.whofedsnoop.who_fed_snoop

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class MealWindowResolverTest {
    private val tz = TimeZone.getTimeZone("America/Los_Angeles")

    private fun epochAt(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int = 0
    ): Long {
        return Calendar.getInstance(tz).apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month - 1)
            set(Calendar.DAY_OF_MONTH, day)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, second)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    @Test
    fun beforeFirstMorningWindow_belongsToYesterdaysFinalWindow() {
        val schedule = MealSchedule(breakfastStartHour = 4, dinnerStartHour = 14)
        val at130am = epochAt(2026, 11, 9, 1, 30)

        val active = ActiveMealWindow.forTime(at130am, schedule, tz)

        assertEquals(MealPeriod.DINNER, active.period)
        assertEquals("dinner", active.windowId)
        assertEquals("2026-11-08", active.windowDate)
        assertEquals(epochAt(2026, 11, 9, 4, 0), active.nextTransitionEpochMs)
        assertEquals("Breakfast", active.nextWindowLabel)
        assertEquals("🥣", active.nextWindowEmoji)
    }

    @Test
    fun exactBoundary_transitionsToNewWindow() {
        val schedule = MealSchedule(breakfastStartHour = 4, dinnerStartHour = 14)
        val at400am = epochAt(2026, 11, 9, 4, 0)

        val active = ActiveMealWindow.forTime(at400am, schedule, tz)

        assertEquals("breakfast", active.windowId)
        assertEquals("2026-11-09", active.windowDate)
        assertEquals(epochAt(2026, 11, 9, 14, 0), active.nextTransitionEpochMs)
        assertEquals("Dinner", active.nextWindowLabel)
    }

    @Test
    fun customMultiWindowSchedule_jsonRoundTripAndMinutePrecision() {
        val json = """
            {
              "breakfastStartHour": 6,
              "dinnerStartHour": 18,
              "windows": [
                {"id": "breakfast", "period": "breakfast", "label": "Morning", "emoji": "☀️", "startHour": 6, "startMinute": 30, "enabled": true},
                {"id": "lunch", "period": "lunch", "label": "Midday", "emoji": "🍲", "startHour": 12, "startMinute": 15, "enabled": false},
                {"id": "custom_tea", "period": "custom", "label": "Tea Time", "emoji": "🫖", "startHour": 15, "startMinute": 45, "enabled": true},
                {"id": "dinner", "period": "dinner", "label": "Supper", "emoji": "🍖", "startHour": 18, "startMinute": 30, "enabled": true}
              ]
            }
        """.trimIndent()

        val schedule = MealSchedule.fromJsonString(json)
        assertEquals(3, schedule.enabledWindows.size)

        // At 15:44 -> still Morning; next transition at 15:45 Tea Time
        val beforeTea = ActiveMealWindow.forTime(epochAt(2026, 11, 9, 15, 44), schedule, tz)
        assertEquals("breakfast", beforeTea.windowId)
        assertEquals("Morning", beforeTea.label)
        assertEquals(epochAt(2026, 11, 9, 15, 45), beforeTea.nextTransitionEpochMs)
        assertEquals("Tea Time", beforeTea.nextWindowLabel)

        // At 19:00 -> Supper; wraps to tomorrow 06:30 Morning
        val evening = ActiveMealWindow.forTime(epochAt(2026, 11, 9, 19, 0), schedule, tz)
        assertEquals("dinner", evening.windowId)
        assertEquals("Supper", evening.label)
        assertEquals("2026-11-09", evening.windowDate)
        assertEquals(epochAt(2026, 11, 10, 6, 30), evening.nextTransitionEpochMs)
        assertEquals("Morning", evening.nextWindowLabel)
    }

    @Test
    fun malformedOrAllDisabledSchedule_fallsBackSafelyToDefaults() {
        val disabledJson = """
            {
              "windows": [
                {"id": "breakfast", "enabled": false, "startHour": 7},
                {"id": "dinner", "enabled": false, "startHour": 19}
              ]
            }
        """.trimIndent()

        val disabledSchedule = MealSchedule.fromJsonString(disabledJson)
        assertEquals(2, disabledSchedule.enabledWindows.size)
        assertEquals("breakfast", disabledSchedule.enabledWindows[0].id)
        assertEquals(4, disabledSchedule.enabledWindows[0].startHour)

        val broken = MealSchedule.fromJsonString("{not valid json")
        assertEquals(2, broken.enabledWindows.size)
    }

    @Test
    fun resolveFromCachedSnapshot_handlesMultipleMissedRolloversAndTreatDateRollover() {
        val schedule = MealSchedule(
            windows = listOf(
                MealWindowConfig("breakfast", MealPeriod.BREAKFAST, "Breakfast", "🥣", 4, 0, true),
                MealWindowConfig("lunch", MealPeriod.LUNCH, "Lunch", "🍲", 12, 0, true),
                MealWindowConfig("dinner", MealPeriod.DINNER, "Dinner", "🍖", 18, 0, true)
            )
        )
        val cachedSnapshot = WidgetDisplaySnapshot(
            petName = "Snoop",
            headline = "✅ Ashley fed Snoop Breakfast",
            subheadline = "Logged at 8:00 AM • 🦴 2/4 treats",
            isFed = true,
            mealPeriod = "Breakfast",
            windowEmoji = "🥣",
            windowId = "breakfast",
            windowDate = "2026-11-08",
            nextTransitionEpochMs = epochAt(2026, 11, 8, 12, 0),
            nextWindowLabel = "Lunch",
            nextWindowEmoji = "🍲",
            scheduleJson = schedule.toJsonString(),
            dailyTreatLimit = 4,
            todayTreatCount = 2,
            treatLogicalDate = "2026-11-08"
        )

        // Same logical day, skipped Lunch and woke up at 7:00 PM (Dinner) -> preserves same-day treats!
        val eveningSameDay = MealWindowResolver.resolveFromCachedSnapshot(
            snapshot = cachedSnapshot,
            nowEpochMs = epochAt(2026, 11, 8, 19, 0),
            timeZone = tz
        )
        assertFalse(eveningSameDay.isFed)
        assertEquals("dinner", eveningSameDay.windowId)
        assertEquals("2026-11-08", eveningSameDay.windowDate)
        assertEquals("🍖 Snoop needs Dinner", eveningSameDay.headline)
        assertEquals("Tap to log dinner • 🦴 2/4 treats", eveningSameDay.subheadline)
        assertEquals(2, eveningSameDay.todayTreatCount)
        assertEquals(epochAt(2026, 11, 9, 4, 0), eveningSameDay.nextTransitionEpochMs)

        // Next logical day at 9:00 AM -> treat count resets to 0!
        val nextMorning = MealWindowResolver.resolveFromCachedSnapshot(
            snapshot = cachedSnapshot,
            nowEpochMs = epochAt(2026, 11, 9, 9, 0),
            timeZone = tz
        )
        assertFalse(nextMorning.isFed)
        assertEquals("breakfast", nextMorning.windowId)
        assertEquals("2026-11-09", nextMorning.windowDate)
        assertEquals(0, nextMorning.todayTreatCount)
        assertEquals("Tap to log breakfast", nextMorning.subheadline)
    }

    @Test
    fun resolveWidgetDisplayFromHousehold_matchesFedAndExtraMealAndTreatCounts() {
        val schedule = MealSchedule(breakfastStartHour = 4, dinnerStartHour = 14)
        val nowMs = epochAt(2026, 11, 8, 15, 30)
        val breakfastFedAt = epochAt(2026, 11, 8, 7, 15)
        val dinnerExtraAt = epochAt(2026, 11, 8, 14, 45)

        val todayMeals = mapOf(
            "2026-11-08_breakfast" to FeedingRecord(
                id = "2026-11-08_breakfast",
                mealPeriod = MealPeriod.BREAKFAST,
                windowDate = "2026-11-08",
                fedByUid = "u1",
                fedByName = "Keni",
                fedAtEpochMs = breakfastFedAt,
                isExtraMeal = false,
                windowId = "breakfast"
            )
        )
        val extraDinner = FeedingRecord(
            id = "extra_1",
            mealPeriod = MealPeriod.DINNER,
            windowDate = "2026-11-08",
            fedByUid = "u2",
            fedByName = "Ashley",
            fedAtEpochMs = dinnerExtraAt,
            isExtraMeal = true,
            windowId = "dinner",
            windowLabel = "Dinner"
        )
        val treats = listOf(
            TreatRecord(logicalDate = "2026-11-08", quantity = 2),
            TreatRecord(logicalDate = "2026-11-08", quantity = 1),
            TreatRecord(logicalDate = "2026-11-07", quantity = 3)
        )

        // Extra meal must NOT mark Dinner window as fed
        val hungryDinner = MealWindowResolver.resolveWidgetDisplayFromHousehold(
            petName = "Snoop",
            schedule = schedule,
            lastFeeding = extraDinner,
            todayMeals = todayMeals,
            todayTreats = treats,
            dailyTreatLimit = 4,
            nowEpochMs = nowMs,
            timeZone = tz
        )
        assertFalse(hungryDinner.isFed)
        assertEquals("🍖 Snoop needs Dinner", hungryDinner.headline)
        assertEquals(
            "Last fed: Dinner by Ashley (2:45 PM) • 🦴 3/4 treats",
            hungryDinner.subheadline
        )

        // Regular meal in todayMeals marks Dinner as fed
        val regularDinner = extraDinner.copy(id = "2026-11-08_dinner", isExtraMeal = false)
        val fedDinner = MealWindowResolver.resolveWidgetDisplayFromHousehold(
            petName = "Snoop",
            schedule = schedule,
            lastFeeding = regularDinner,
            todayMeals = todayMeals + ("2026-11-08_dinner" to regularDinner),
            todayTreats = treats,
            dailyTreatLimit = 4,
            nowEpochMs = nowMs,
            timeZone = tz
        )
        assertTrue(fedDinner.isFed)
        assertEquals("✅ Ashley fed Snoop Dinner", fedDinner.headline)
        assertEquals("Logged at 2:45 PM • 🦴 3/4 treats", fedDinner.subheadline)
    }

    @Test
    fun parseIsoTimestampMs_handlesMicrosecondsAndOffsets() {
        val parsed = MealWindowResolver.parseIsoTimestampMs("2026-11-08T16:15:30.123456Z")
        val utcCal = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            timeInMillis = parsed
        }
        assertEquals(2026, utcCal.get(Calendar.YEAR))
        assertEquals(Calendar.NOVEMBER, utcCal.get(Calendar.MONTH))
        assertEquals(8, utcCal.get(Calendar.DAY_OF_MONTH))
        assertEquals(16, utcCal.get(Calendar.HOUR_OF_DAY))
        assertEquals(15, utcCal.get(Calendar.MINUTE))
        assertEquals(30, utcCal.get(Calendar.SECOND))
        assertEquals(123, utcCal.get(Calendar.MILLISECOND))
    }

    @Test
    fun widgetFirestoreSyncParseAndResolve_parsesHouseholdDocumentMap() {
        val doc = mapOf<String, Any?>(
            "petName" to "Snoop",
            "dailyTreatLimit" to 5,
            "schedule" to mapOf(
                "breakfastStartHour" to 5,
                "dinnerStartHour" to 16,
                "windows" to listOf(
                    mapOf(
                        "id" to "breakfast",
                        "period" to "breakfast",
                        "label" to "Breakfast",
                        "emoji" to "🥣",
                        "startHour" to 5,
                        "startMinute" to 0,
                        "enabled" to true
                    ),
                    mapOf(
                        "id" to "dinner",
                        "period" to "dinner",
                        "label" to "Dinner",
                        "emoji" to "🍖",
                        "startHour" to 16,
                        "startMinute" to 30,
                        "enabled" to true
                    )
                )
            ),
            "lastFeeding" to mapOf(
                "id" to "2026-11-09_breakfast",
                "mealPeriod" to "breakfast",
                "windowId" to "breakfast",
                "windowDate" to "2026-11-09",
                "fedByUid" to "ashley_uid",
                "fedByName" to "Ashley",
                "fedAt" to epochAt(2026, 11, 9, 7, 10),
                "isExtraMeal" to false
            ),
            "todayMeals" to mapOf(
                "2026-11-09_breakfast" to mapOf(
                    "id" to "2026-11-09_breakfast",
                    "mealPeriod" to "breakfast",
                    "windowId" to "breakfast",
                    "windowDate" to "2026-11-09",
                    "fedByUid" to "ashley_uid",
                    "fedByName" to "Ashley",
                    "fedAt" to epochAt(2026, 11, 9, 7, 10),
                    "isExtraMeal" to false
                )
            ),
            "todayTreats" to listOf(
                mapOf("logicalDate" to "2026-11-09", "quantity" to 2)
            )
        )

        val resolved = WidgetFirestoreSync.parseAndResolve(
            data = doc,
            nowEpochMs = epochAt(2026, 11, 9, 10, 0),
            timeZone = tz
        )

        // Compare against local TZ expectation
        assertTrue(resolved.isFed)
        assertEquals("✅ Ashley fed Snoop Breakfast", resolved.headline)
        assertTrue(resolved.subheadline.contains("🦴 2/5 treats"))
    }
}
