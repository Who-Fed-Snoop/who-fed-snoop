package com.whofedsnoop.who_fed_snoop

import android.content.BroadcastReceiver
import android.content.Context
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import java.util.Date
import java.util.TimeZone
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Fetches the single `households/{id}` document (1 Firestore read) during
 * background widget updates / window-cutoff alarms so partner feedings and
 * schedule updates appear without opening the Flutter UI.
 */
object WidgetFirestoreSync {
    private const val TAG = "WidgetFirestoreSync"
    private const val FIRESTORE_TIMEOUT_SECONDS = 7L

    private val syncExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "wfs-widget-sync").apply { isDaemon = true }
    }

    @Volatile
    private var emulatorConfigured = false

    enum class SyncOutcome {
        UPDATED,
        SKIPPED_FIREBASE_UNINITIALIZED,
        SKIPPED_UNAUTHENTICATED,
        NOT_FOUND
    }

    fun syncAsync(context: Context, pendingResult: BroadcastReceiver.PendingResult) {
        val appContext = context.applicationContext
        try {
            syncExecutor.execute {
                try {
                    syncNow(appContext)
                } catch (t: Throwable) {
                    Log.w(TAG, "Background widget sync failed; keeping cached state", t)
                } finally {
                    pendingResult.finish()
                }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Unable to enqueue background widget sync", t)
            pendingResult.finish()
        }
    }

    fun syncNow(context: Context): SyncOutcome {
        if (!ensureFirebaseInitialized(context)) {
            return SyncOutcome.SKIPPED_FIREBASE_UNINITIALIZED
        }

        val cached = WidgetPrefsStore.read(context)
        val auth = FirebaseAuth.getInstance()
        val firestore = FirebaseFirestore.getInstance()

        if (cached.useEmulator && !emulatorConfigured) {
            configureEmulators(auth, firestore)
        }

        // Cold-install / deferred-auth guard: never mint anonymous accounts from the background.
        if (auth.currentUser == null) {
            return SyncOutcome.SKIPPED_UNAUTHENTICATED
        }

        val snapshot = Tasks.await(
            firestore.collection("households").document(cached.householdId).get(),
            FIRESTORE_TIMEOUT_SECONDS,
            TimeUnit.SECONDS
        )

        val data = snapshot.data
        if (!snapshot.exists() || data == null) {
            return SyncOutcome.NOT_FOUND
        }

        val nowMs = System.currentTimeMillis()
        val resolved = parseAndResolve(
            data = data,
            nowEpochMs = nowMs
        )
        val schedule = MealSchedule.fromMap(data["schedule"] as? Map<*, *>)

        val updatedSnapshot = cached.copy(
            petName = resolved.petName,
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
            scheduleJson = schedule.toJsonString(),
            dailyTreatLimit = resolved.dailyTreatLimit,
            todayTreatCount = resolved.todayTreatCount,
            treatLogicalDate = resolved.windowDate,
            lastSyncEpochMs = nowMs
        )

        WidgetPrefsStore.write(context, updatedSnapshot)
        WhoFedSnoopWidgetProvider.renderAllWidgetsFromPrefs(context)
        WidgetAlarmScheduler.scheduleWindowCutoff(context, resolved.nextTransitionEpochMs)
        return SyncOutcome.UPDATED
    }

    private fun ensureFirebaseInitialized(context: Context): Boolean {
        if (FirebaseApp.getApps(context).isNotEmpty()) {
            return true
        }
        return try {
            FirebaseApp.initializeApp(context) != null ||
                FirebaseApp.getApps(context).isNotEmpty()
        } catch (t: Throwable) {
            Log.w(TAG, "FirebaseApp initialization failed in widget background", t)
            false
        }
    }

    private fun configureEmulators(auth: FirebaseAuth, firestore: FirebaseFirestore) {
        try {
            auth.useEmulator("10.0.2.2", 9099)
        } catch (_: IllegalStateException) {
            // Already configured in this process.
        }
        try {
            firestore.useEmulator("10.0.2.2", 8080)
        } catch (_: IllegalStateException) {
            // Already configured in this process.
        }
        emulatorConfigured = true
    }

    internal fun parseAndResolve(
        data: Map<String, Any?>,
        nowEpochMs: Long,
        timeZone: TimeZone = TimeZone.getDefault()
    ): ResolvedWidgetState {
        val petName = (data["petName"] as? String)?.trim()?.ifEmpty { "Snoop" } ?: "Snoop"
        val dailyTreatLimit =
            ((data["dailyTreatLimit"] as? Number)?.toInt() ?: 4).coerceIn(1, 50)
        val schedule = MealSchedule.fromMap(data["schedule"] as? Map<*, *>)

        val lastFeeding = (data["lastFeeding"] as? Map<*, *>)?.let { raw ->
            parseFeeding(raw, fallbackId = (raw["id"] as? String) ?: "", fallbackMs = nowEpochMs)
        }

        val todayMeals = mutableMapOf<String, FeedingRecord>()
        val rawTodayMeals = data["todayMeals"] as? Map<*, *>
        if (rawTodayMeals != null) {
            for ((k, v) in rawTodayMeals) {
                if (k is String && v is Map<*, *>) {
                    todayMeals[k] = parseFeeding(v, fallbackId = k, fallbackMs = nowEpochMs)
                }
            }
        }

        val todayTreats = mutableListOf<TreatRecord>()
        val rawTodayTreats = data["todayTreats"] as? List<*>
        if (rawTodayTreats != null) {
            for (item in rawTodayTreats) {
                val map = item as? Map<*, *> ?: continue
                val logicalDate = (map["logicalDate"] as? String).orEmpty()
                val quantity = ((map["quantity"] as? Number)?.toInt() ?: 1).coerceIn(1, 20)
                todayTreats.add(TreatRecord(logicalDate = logicalDate, quantity = quantity))
            }
        }

        return MealWindowResolver.resolveWidgetDisplayFromHousehold(
            petName = petName,
            schedule = schedule,
            lastFeeding = lastFeeding,
            todayMeals = todayMeals,
            todayTreats = todayTreats,
            dailyTreatLimit = dailyTreatLimit,
            nowEpochMs = nowEpochMs,
            timeZone = timeZone
        )
    }

    private fun parseFeeding(
        map: Map<*, *>,
        fallbackId: String,
        fallbackMs: Long
    ): FeedingRecord {
        val rawPeriod = (map["mealPeriod"] as? String) ?: "breakfast"
        val rawWindowId = (map["windowId"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
        val rawWindowLabel = (map["windowLabel"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
        val rawWindowEmoji = (map["windowEmoji"] as? String)?.trim()?.takeIf { it.isNotEmpty() }

        return FeedingRecord(
            id = (map["id"] as? String) ?: fallbackId,
            mealPeriod = MealPeriod.fromString(rawPeriod),
            windowDate = (map["windowDate"] as? String) ?: "",
            fedByUid = (map["fedByUid"] as? String) ?: "",
            fedByName = (map["fedByName"] as? String) ?: "Someone",
            fedAtEpochMs = parseTimestampEpochMs(map["fedAt"], fallbackMs),
            isExtraMeal = (map["isExtraMeal"] as? Boolean) ?: false,
            windowId = rawWindowId,
            windowLabel = rawWindowLabel,
            windowEmoji = rawWindowEmoji
        )
    }

    private fun parseTimestampEpochMs(raw: Any?, fallbackMs: Long): Long = when (raw) {
        is Timestamp -> raw.toDate().time
        is Date -> raw.time
        is Number -> raw.toLong()
        is String -> MealWindowResolver.parseIsoTimestampMs(raw, fallbackMs)
        else -> fallbackMs
    }
}
