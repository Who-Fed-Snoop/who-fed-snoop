package com.whofedsnoop.who_fed_snoop

import android.content.Context
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
                    val prefs = applicationContext.getSharedPreferences(
                        WhoFedSnoopWidgetProvider.PREFS_NAME,
                        Context.MODE_PRIVATE
                    )
                    val nextTransitionEpochMs =
                        (call.argument<Number>("nextTransitionEpochMs"))?.toLong() ?: 0L

                    prefs.edit()
                        .putString(
                            WhoFedSnoopWidgetProvider.KEY_PET_NAME,
                            call.argument<String>("petName") ?: "Snoop"
                        )
                        .putString(
                            WhoFedSnoopWidgetProvider.KEY_HEADLINE,
                            call.argument<String>("headline") ?: ""
                        )
                        .putString(
                            WhoFedSnoopWidgetProvider.KEY_SUBHEADLINE,
                            call.argument<String>("subheadline") ?: ""
                        )
                        .putBoolean(
                            WhoFedSnoopWidgetProvider.KEY_IS_FED,
                            call.argument<Boolean>("isFed") ?: false
                        )
                        .putString(
                            WhoFedSnoopWidgetProvider.KEY_MEAL_PERIOD,
                            call.argument<String>("mealPeriod") ?: "Breakfast"
                        )
                        .putString(
                            WhoFedSnoopWidgetProvider.KEY_WINDOW_EMOJI,
                            call.argument<String>("windowEmoji") ?: "🐾"
                        )
                        .putLong(
                            WhoFedSnoopWidgetProvider.KEY_NEXT_TRANSITION_EPOCH_MS,
                            nextTransitionEpochMs
                        )
                        .putString(
                            WhoFedSnoopWidgetProvider.KEY_NEXT_WINDOW_LABEL,
                            call.argument<String>("nextWindowLabel") ?: ""
                        )
                        .putString(
                            WhoFedSnoopWidgetProvider.KEY_NEXT_WINDOW_EMOJI,
                            call.argument<String>("nextWindowEmoji") ?: "🐾"
                        )
                        .putString(
                            WhoFedSnoopWidgetProvider.KEY_HOUSEHOLD_ID,
                            call.argument<String>("householdId") ?: "household_snoop_01"
                        )
                        .apply()

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
