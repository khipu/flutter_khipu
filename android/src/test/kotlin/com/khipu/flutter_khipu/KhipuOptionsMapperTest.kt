package com.khipu.flutter_khipu

import com.khipu.client.KhipuOptions
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals

class KhipuOptionsMapperTest {

    private fun options(
        operationId: String = "abc123",
        title: String? = null,
        titleImageUrl: String? = null,
        locale: String? = null,
        skipExitPage: Boolean? = null,
        skipExitSuccessPage: Boolean? = null,
        showFooter: Boolean? = null,
        showMerchantLogo: Boolean? = null,
        showPaymentDetails: Boolean? = null,
        theme: KhipuTheme? = null,
        colors: KhipuColors? = null,
    ) = KhipuStartOperationOptions(
        operationId = operationId,
        title = title,
        titleImageUrl = titleImageUrl,
        locale = locale,
        skipExitPage = skipExitPage,
        skipExitSuccessPage = skipExitSuccessPage,
        showFooter = showFooter,
        showMerchantLogo = showMerchantLogo,
        showPaymentDetails = showPaymentDetails,
        theme = theme,
        colors = colors,
    )

    @Test
    fun `maps the scalar options`() {
        val mapped = buildKhipuOptions(options(
            title = "Mi comercio",
            titleImageUrl = "https://example.com/logo.png",
            locale = "es_CL",
            skipExitPage = true,
            skipExitSuccessPage = false,
            showFooter = false,
            showMerchantLogo = true,
            showPaymentDetails = false,
        ))

        assertEquals("Mi comercio", mapped.topBarTitle)
        assertEquals("https://example.com/logo.png", mapped.topBarImageUrl)
        assertEquals("es_CL", mapped.locale)
        assertEquals(true, mapped.skipExitPage)
        assertEquals(false, mapped.skipExitSuccessPage)
        assertEquals(false, mapped.showFooter)
        assertEquals(true, mapped.showMerchantLogo)
        assertEquals(false, mapped.showPaymentDetails)
    }

    @Test
    fun `maps every theme onto the SDK's enum`() {
        // Rewritten over the typed enum instead of deleted: the theme no
        // longer travels as a string buildKhipuOptions has to parse — the
        // codec hands it a KhipuTheme already — so what used to exercise
        // "light"/"dark"/"system"/"neon" through buildKhipuOptions now
        // exercises KhipuTheme.toSdk() directly. The intent survives: every
        // theme the schema can carry must land on its SDK counterpart.
        assertEquals(KhipuOptions.Theme.LIGHT, KhipuTheme.LIGHT.toSdk())
        assertEquals(KhipuOptions.Theme.DARK, KhipuTheme.DARK.toSdk())
        assertEquals(KhipuOptions.Theme.SYSTEM, KhipuTheme.SYSTEM.toSdk())
    }

    @Test
    fun `maps every colour onto its own field`() {
        val colors = KhipuColors(
            lightBackground = "lightBackground",
            lightOnBackground = "lightOnBackground",
            lightPrimary = "lightPrimary",
            lightOnPrimary = "lightOnPrimary",
            lightTopBarContainer = "lightTopBarContainer",
            lightOnTopBarContainer = "lightOnTopBarContainer",
            darkBackground = "darkBackground",
            darkOnBackground = "darkOnBackground",
            darkPrimary = "darkPrimary",
            darkOnPrimary = "darkOnPrimary",
            darkTopBarContainer = "darkTopBarContainer",
            darkOnTopBarContainer = "darkOnTopBarContainer",
        )
        // The SDK declares KhipuOptions.colors as nullable, but the mapper
        // populates it whenever the schema's colors object is present (see
        // buildKhipuOptions), so asserting non-null here reflects that
        // invariant rather than testing SDK behaviour.
        val mapped = buildKhipuOptions(options(colors = colors)).colors!!

        assertEquals("lightBackground", mapped.lightBackground)
        assertEquals("lightOnBackground", mapped.lightOnBackground)
        assertEquals("lightPrimary", mapped.lightPrimary)
        assertEquals("lightOnPrimary", mapped.lightOnPrimary)
        assertEquals("lightTopBarContainer", mapped.lightTopBarContainer)
        assertEquals("lightOnTopBarContainer", mapped.lightOnTopBarContainer)
        assertEquals("darkBackground", mapped.darkBackground)
        assertEquals("darkOnBackground", mapped.darkOnBackground)
        assertEquals("darkPrimary", mapped.darkPrimary)
        assertEquals("darkOnPrimary", mapped.darkOnPrimary)
        assertEquals("darkTopBarContainer", mapped.darkTopBarContainer)
        assertEquals("darkOnTopBarContainer", mapped.darkOnTopBarContainer)
    }

    @Test
    fun `an absent option is left at its default instead of being set to null`() {
        val mapped = buildKhipuOptions(options())
        assertEquals(null, mapped.topBarTitle)
        // KhipuOptions.Builder().build().theme defaults to SYSTEM, not null —
        // the mapper never sets theme when the argument is absent, so this
        // asserts the SDK's own default rather than a mapper-imposed one.
        // Pre-existing behaviour, unchanged by this refactor.
        assertEquals(KhipuOptions.Theme.SYSTEM, mapped.theme)
    }

    // "an unknown theme string is ignored rather than throwing" is deleted,
    // not adapted: an unknown theme is no longer representable on this path.
    // The theme now arrives as a typed KhipuTheme, and the Pigeon codec
    // rejects any value outside its three cases before the message ever
    // reaches buildKhipuOptions — there is no string left here to be
    // "unknown".
}
