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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initialDeepLink = intent?.dataString

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateHomeWidget" -> {
                    val prefs = applicationContext.getSharedPreferences(
                        WhoFedSnoopWidgetProvider.PREFS_NAME,
                        Context.MODE_PRIVATE
                    )
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
                            call.argument<String>("mealPeriod") ?: "breakfast"
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
        setIntent(intent)
        val dataString = intent.dataString
        if (!dataString.isNullOrEmpty()) {
            methodChannel?.invokeMethod("onDeepLink", dataString)
        }
    }
}
