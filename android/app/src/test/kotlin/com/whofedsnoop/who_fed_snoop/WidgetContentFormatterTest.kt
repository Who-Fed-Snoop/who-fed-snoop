package com.whofedsnoop.who_fed_snoop

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetContentFormatterTest {
    @Test
    fun resolveSizeTier_mapsWidthBreakpointsCorrectly() {
        assertEquals(WidgetContentFormatter.WidgetSizeTier.COMPACT, WidgetContentFormatter.resolveSizeTier(0))
        assertEquals(WidgetContentFormatter.WidgetSizeTier.COMPACT, WidgetContentFormatter.resolveSizeTier(189))
        assertEquals(WidgetContentFormatter.WidgetSizeTier.MEDIUM, WidgetContentFormatter.resolveSizeTier(190))
        assertEquals(WidgetContentFormatter.WidgetSizeTier.MEDIUM, WidgetContentFormatter.resolveSizeTier(259))
        assertEquals(WidgetContentFormatter.WidgetSizeTier.WIDE, WidgetContentFormatter.resolveSizeTier(260))
    }

    @Test
    fun buildWidgetContent_compactAndWidePreserveFb002Copy() {
        val compactHungry = WidgetContentFormatter.buildWidgetContent(
            tier = WidgetContentFormatter.WidgetSizeTier.COMPACT,
            petName = "Snoop",
            isFed = false,
            windowLabel = "Breakfast",
            windowEmoji = "🥣",
            fullHeadline = "🥣 Snoop needs Breakfast",
            fullSubheadline = "Tap to log breakfast"
        )
        assertEquals("🥣 BREAKFAST", compactHungry.badgeText)
        assertEquals("Snoop hungry", compactHungry.headlineText)
        assertFalse(compactHungry.showSubheadline)
        assertEquals("Feed", compactHungry.buttonText)

        val compactFed = WidgetContentFormatter.buildWidgetContent(
            tier = WidgetContentFormatter.WidgetSizeTier.COMPACT,
            petName = "Snoop",
            isFed = true,
            windowLabel = "Breakfast",
            windowEmoji = "🥣",
            fullHeadline = "✅ Ashley fed Snoop Breakfast",
            fullSubheadline = "Logged at 7:15 AM"
        )
        assertEquals("🥣 BREAKFAST · FED", compactFed.badgeText)
        assertEquals("✅ Ashley fed Snoop", compactFed.headlineText)

        val wideFed = WidgetContentFormatter.buildWidgetContent(
            tier = WidgetContentFormatter.WidgetSizeTier.WIDE,
            petName = "Snoop",
            isFed = true,
            windowLabel = "Dinner",
            windowEmoji = "🍖",
            fullHeadline = "✅ Keni fed Snoop Dinner",
            fullSubheadline = "Logged at 5:00 PM • 🦴 1/4 treats"
        )
        assertEquals("🍖 DINNER WINDOW", wideFed.badgeText)
        assertEquals("✅ Keni fed Snoop Dinner", wideFed.headlineText)
        assertTrue(wideFed.showSubheadline)
        assertEquals("I Fed Snoop", wideFed.buttonText)
    }
}
