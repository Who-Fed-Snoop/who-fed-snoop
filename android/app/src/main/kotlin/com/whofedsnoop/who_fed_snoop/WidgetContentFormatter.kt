package com.whofedsnoop.who_fed_snoop

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import kotlin.math.roundToInt

/**
 * Formats responsive `2x1` / `3x1` / `4x1+` widget copy and binds [RemoteViews]
 * with API 31+ live dark-theme color resources and click [PendingIntent]s.
 */
object WidgetContentFormatter {

    internal enum class WidgetSizeTier {
        COMPACT, // 2x1 (< 190dp)
        MEDIUM,  // 3x1 (190dp..259dp)
        WIDE     // 4x1+ (>= 260dp)
    }

    internal data class WidgetDisplayContent(
        val badgeText: String,
        val headlineText: String,
        val subheadlineText: String,
        val showSubheadline: Boolean,
        val buttonText: String,
        val rootPaddingH: Int,
        val rootPaddingV: Int,
        val buttonPaddingH: Int,
        val buttonPaddingV: Int,
        val badgeTextSizeSp: Float,
        val headlineTextSizeSp: Float,
        val subheadlineTextSizeSp: Float,
        val buttonTextSizeSp: Float
    )

    private const val MEDIUM_MIN_WIDTH_DP = 190
    private const val WIDE_MIN_WIDTH_DP = 260

    internal fun resolveSizeTier(minWidthDp: Int): WidgetSizeTier = when {
        minWidthDp <= 0 || minWidthDp < MEDIUM_MIN_WIDTH_DP -> WidgetSizeTier.COMPACT
        minWidthDp < WIDE_MIN_WIDTH_DP -> WidgetSizeTier.MEDIUM
        else -> WidgetSizeTier.WIDE
    }

    internal fun compactFedHeadline(
        fullHeadline: String,
        windowLabel: String,
        petName: String
    ): String {
        val trimmed = fullHeadline.trim()
        if (trimmed.isEmpty()) {
            return "✅ $petName fed"
        }
        val suffix = " $windowLabel"
        if (trimmed.length > suffix.length && trimmed.endsWith(suffix, ignoreCase = true)) {
            return trimmed.dropLast(suffix.length).trimEnd()
        }
        return trimmed
    }

    internal fun buildWidgetContent(
        tier: WidgetSizeTier,
        petName: String,
        isFed: Boolean,
        windowLabel: String,
        windowEmoji: String,
        fullHeadline: String,
        fullSubheadline: String
    ): WidgetDisplayContent {
        val fallbackHeadline = if (isFed) {
            "✅ $petName fed"
        } else {
            "$windowEmoji $petName needs $windowLabel"
        }
        val resolvedHeadline = fullHeadline.ifBlank { fallbackHeadline }

        return when (tier) {
            WidgetSizeTier.COMPACT -> WidgetDisplayContent(
                badgeText = if (isFed) {
                    "$windowEmoji ${windowLabel.uppercase()} · FED"
                } else {
                    "$windowEmoji ${windowLabel.uppercase()}"
                },
                headlineText = if (isFed) {
                    compactFedHeadline(resolvedHeadline, windowLabel, petName)
                } else {
                    "$petName hungry"
                },
                subheadlineText = "",
                showSubheadline = false,
                buttonText = "Feed",
                rootPaddingH = 10,
                rootPaddingV = 8,
                buttonPaddingH = 10,
                buttonPaddingV = 7,
                badgeTextSizeSp = 11f,
                headlineTextSizeSp = 13f,
                subheadlineTextSizeSp = 11f,
                buttonTextSizeSp = 12f
            )
            WidgetSizeTier.MEDIUM -> WidgetDisplayContent(
                badgeText = "$windowEmoji ${windowLabel.uppercase()} WINDOW",
                headlineText = resolvedHeadline,
                subheadlineText = fullSubheadline,
                showSubheadline = fullSubheadline.isNotBlank(),
                buttonText = "Feed",
                rootPaddingH = 12,
                rootPaddingV = 8,
                buttonPaddingH = 12,
                buttonPaddingV = 8,
                badgeTextSizeSp = 11f,
                headlineTextSizeSp = 14f,
                subheadlineTextSizeSp = 11f,
                buttonTextSizeSp = 12.5f
            )
            WidgetSizeTier.WIDE -> WidgetDisplayContent(
                badgeText = "$windowEmoji ${windowLabel.uppercase()} WINDOW",
                headlineText = resolvedHeadline,
                subheadlineText = fullSubheadline,
                showSubheadline = fullSubheadline.isNotBlank(),
                buttonText = "I Fed $petName",
                rootPaddingH = 14,
                rootPaddingV = 10,
                buttonPaddingH = 14,
                buttonPaddingV = 9,
                badgeTextSizeSp = 11f,
                headlineTextSizeSp = 15.5f,
                subheadlineTextSizeSp = 12f,
                buttonTextSizeSp = 13f
            )
        }
    }

    fun bindAndApplyWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        state: ResolvedWidgetState,
        householdId: String,
        appWidgetOptions: Bundle?
    ) {
        val options = appWidgetOptions ?: appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val tier = resolveSizeTier(minWidthDp)
        val content = buildWidgetContent(
            tier = tier,
            petName = state.petName,
            isFed = state.isFed,
            windowLabel = state.windowLabel,
            windowEmoji = state.windowEmoji,
            fullHeadline = state.headline,
            fullSubheadline = state.subheadline
        )

        val views = RemoteViews(context.packageName, R.layout.who_fed_snoop_widget)

        val rootPadH = dpToPx(context, content.rootPaddingH)
        val rootPadV = dpToPx(context, content.rootPaddingV)
        views.setViewPadding(R.id.widget_root, rootPadH, rootPadV, rootPadH, rootPadV)

        views.setInt(
            R.id.widget_root,
            "setBackgroundResource",
            if (state.isFed) R.drawable.widget_background_fed else R.drawable.widget_background_hungry
        )

        val badgeColorRes = if (state.isFed) R.color.widget_badge_fed else R.color.widget_badge_hungry
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Passing the color resource ID lets Android 12+ launchers re-theme immediately
            // when OS Dark Mode toggles, without waiting for an APPWIDGET_UPDATE broadcast.
            views.setColor(R.id.widget_badge, "setTextColor", badgeColorRes)
        } else {
            views.setTextColor(R.id.widget_badge, context.getColor(badgeColorRes))
        }

        views.setTextViewText(R.id.widget_badge, content.badgeText)
        views.setTextViewTextSize(
            R.id.widget_badge,
            TypedValue.COMPLEX_UNIT_SP,
            content.badgeTextSizeSp
        )

        views.setTextViewText(R.id.widget_headline, content.headlineText)
        views.setTextViewTextSize(
            R.id.widget_headline,
            TypedValue.COMPLEX_UNIT_SP,
            content.headlineTextSizeSp
        )

        if (content.showSubheadline) {
            views.setViewVisibility(R.id.widget_subheadline, View.VISIBLE)
            views.setTextViewText(R.id.widget_subheadline, content.subheadlineText)
            views.setTextViewTextSize(
                R.id.widget_subheadline,
                TypedValue.COMPLEX_UNIT_SP,
                content.subheadlineTextSizeSp
            )
        } else {
            views.setViewVisibility(R.id.widget_subheadline, View.GONE)
        }

        if (state.isFed) {
            views.setViewVisibility(R.id.widget_action_button, View.GONE)
        } else {
            val btnPadH = dpToPx(context, content.buttonPaddingH)
            val btnPadV = dpToPx(context, content.buttonPaddingV)
            views.setViewVisibility(R.id.widget_action_button, View.VISIBLE)
            views.setViewPadding(R.id.widget_action_button, btnPadH, btnPadV, btnPadH, btnPadV)
            views.setTextViewText(R.id.widget_action_button, content.buttonText)
            views.setTextViewTextSize(
                R.id.widget_action_button,
                TypedValue.COMPLEX_UNIT_SP,
                content.buttonTextSizeSp
            )
        }

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

    private fun dpToPx(context: Context, dp: Int): Int =
        (dp * context.resources.displayMetrics.density).roundToInt()
}
