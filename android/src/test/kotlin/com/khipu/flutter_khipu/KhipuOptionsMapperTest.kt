package com.khipu.flutter_khipu

import com.khipu.client.KhipuOptions
import io.flutter.plugin.common.MethodCall
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals

class KhipuOptionsMapperTest {

    private fun call(args: Map<String, Any?>) = MethodCall("startOperation", args)

    @Test
    fun `maps the scalar options`() {
        val options = buildKhipuOptions(call(mapOf(
            "operationId" to "abc123",
            "title" to "Mi comercio",
            "titleImageUrl" to "https://example.com/logo.png",
            "locale" to "es_CL",
            "skipExitPage" to true,
            "skipExitSuccessPage" to false,
            "showFooter" to false,
            "showMerchantLogo" to true,
            "showPaymentDetails" to false
        )))

        assertEquals("Mi comercio", options.topBarTitle)
        assertEquals("https://example.com/logo.png", options.topBarImageUrl)
        assertEquals("es_CL", options.locale)
        assertEquals(true, options.skipExitPage)
        assertEquals(false, options.skipExitSuccessPage)
        assertEquals(false, options.showFooter)
        assertEquals(true, options.showMerchantLogo)
        assertEquals(false, options.showPaymentDetails)
    }

    @Test
    fun `maps each theme string onto its enum`() {
        assertEquals(KhipuOptions.Theme.LIGHT, buildKhipuOptions(call(mapOf("theme" to "light"))).theme)
        assertEquals(KhipuOptions.Theme.DARK, buildKhipuOptions(call(mapOf("theme" to "dark"))).theme)
        assertEquals(KhipuOptions.Theme.SYSTEM, buildKhipuOptions(call(mapOf("theme" to "system"))).theme)
    }

    @Test
    fun `maps every colour onto its own field`() {
        val names = listOf(
            "lightBackground", "lightOnBackground", "lightPrimary", "lightOnPrimary",
            "lightTopBarContainer", "lightOnTopBarContainer",
            "darkBackground", "darkOnBackground", "darkPrimary", "darkOnPrimary",
            "darkTopBarContainer", "darkOnTopBarContainer"
        )
        // The SDK declares KhipuOptions.colors as nullable, but the mapper always
        // populates it (see buildKhipuColors), so asserting non-null here reflects
        // that invariant rather than testing SDK behaviour.
        val colors = buildKhipuOptions(call(names.associateWith { it })).colors!!

        assertEquals("lightBackground", colors.lightBackground)
        assertEquals("lightOnBackground", colors.lightOnBackground)
        assertEquals("lightPrimary", colors.lightPrimary)
        assertEquals("lightOnPrimary", colors.lightOnPrimary)
        assertEquals("lightTopBarContainer", colors.lightTopBarContainer)
        assertEquals("lightOnTopBarContainer", colors.lightOnTopBarContainer)
        assertEquals("darkBackground", colors.darkBackground)
        assertEquals("darkOnBackground", colors.darkOnBackground)
        assertEquals("darkPrimary", colors.darkPrimary)
        assertEquals("darkOnPrimary", colors.darkOnPrimary)
        assertEquals("darkTopBarContainer", colors.darkTopBarContainer)
        assertEquals("darkOnTopBarContainer", colors.darkOnTopBarContainer)
    }

    @Test
    fun `an absent option is left at its default instead of being set to null`() {
        val options = buildKhipuOptions(call(mapOf("operationId" to "abc123")))
        assertEquals(null, options.topBarTitle)
        // KhipuOptions.Builder().build().theme defaults to SYSTEM, not null — the
        // mapper never sets theme when the argument is absent, so this asserts the
        // SDK's own default rather than a mapper-imposed one. Pre-existing
        // behaviour, unchanged by this refactor.
        assertEquals(KhipuOptions.Theme.SYSTEM, options.theme)
    }

    @Test
    fun `an unknown theme string is ignored rather than throwing`() {
        assertEquals(KhipuOptions.Theme.SYSTEM, buildKhipuOptions(call(mapOf("theme" to "neon"))).theme)
    }
}
