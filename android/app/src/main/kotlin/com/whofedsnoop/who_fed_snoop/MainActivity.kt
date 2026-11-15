package com.whofedsnoop.who_fed_snoop

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.whofedsnoop.who_fed_snoop/platform"
    }

    private var methodChannel: MethodChannel? = null
    private var initialDeepLink: String? = null

    /**
     * Extracts any incoming deep-link / NFC URI (`/tap`, `/join`, `/s`) and clears
     * `intent.data` immediately so configuration changes or engine recreations
     * never re-fire a one-shot action like `/tap`.
     */
    private fun consumeDeepLinkIntent(targetIntent: Intent?): String? {
        val dataString = targetIntent?.dataString
        if (!dataString.isNullOrEmpty()) {
            targetIntent.data = null
            setIntent(targetIntent)
            return dataString
        }
        return null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val launchedLink = consumeDeepLinkIntent(intent)
        if (!launchedLink.isNullOrEmpty()) {
            initialDeepLink = launchedLink
        }

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateHomeWidget" -> {
                    val existing = WidgetPrefsStore.read(applicationContext)
                    val nextTransitionEpochMs =
                        (call.argument<Number>("nextTransitionEpochMs"))?.toLong() ?: 0L
                    val snapshot = WidgetDisplaySnapshot(
                        petName = call.argument<String>("petName") ?: "Snoop",
                        headline = call.argument<String>("headline") ?: "",
                        subheadline = call.argument<String>("subheadline") ?: "",
                        isFed = call.argument<Boolean>("isFed") ?: false,
                        mealPeriod = call.argument<String>("mealPeriod") ?: "Breakfast",
                        windowEmoji = call.argument<String>("windowEmoji") ?: "🐾",
                        windowId = call.argument<String>("windowId") ?: existing.windowId,
                        windowDate = call.argument<String>("windowDate") ?: existing.windowDate,
                        nextTransitionEpochMs = nextTransitionEpochMs,
                        nextWindowLabel = call.argument<String>("nextWindowLabel") ?: "",
                        nextWindowEmoji = call.argument<String>("nextWindowEmoji") ?: "🐾",
                        householdId = call.argument<String>("householdId")
                            ?: WidgetPrefsStore.DEFAULT_HOUSEHOLD_ID,
                        scheduleJson = call.argument<String>("scheduleJson")
                            ?: existing.scheduleJson,
                        useEmulator = call.argument<Boolean>("useEmulator") ?: false,
                        dailyTreatLimit = (call.argument<Number>("dailyTreatLimit"))?.toInt()
                            ?: existing.dailyTreatLimit,
                        todayTreatCount = (call.argument<Number>("todayTreatCount"))?.toInt()
                            ?: 0,
                        treatLogicalDate = call.argument<String>("treatLogicalDate")
                            ?: existing.treatLogicalDate,
                        lastSyncEpochMs = System.currentTimeMillis()
                    )

                    WidgetPrefsStore.write(applicationContext, snapshot)
                    WhoFedSnoopWidgetProvider.updateAllWidgets(applicationContext)
                    result.success(true)
                }
                "getInitialDeepLink" -> {
                    val link = initialDeepLink
                    initialDeepLink = null
                    result.success(link)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val dataString = consumeDeepLinkIntent(intent)
        if (!dataString.isNullOrEmpty()) {
            val channel = methodChannel
            if (channel != null) {
                channel.invokeMethod("onDeepLink", dataString)
            } else {
                initialDeepLink = dataString
            }
        } else {
            setIntent(intent)
        }
    }
}
