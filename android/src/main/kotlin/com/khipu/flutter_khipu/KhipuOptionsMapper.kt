package com.khipu.flutter_khipu

import com.khipu.client.KhipuOptions
import com.khipu.client.KhipuColors as SdkKhipuColors

/**
 * Translates the typed options that arrive over the Pigeon channel into the
 * SDK's own options.
 *
 * The Pigeon schema (`pigeons/khipu_api.dart`) is now the contract for every
 * field name and type here: there is no separate flat map of string keys to
 * keep in sync by hand any more, and no regex-based test watching this
 * function's assignment style either — that job now belongs to the generated
 * code and its own schema test (`test/pigeon_schema_test.dart`).
 */
internal fun buildKhipuOptions(options: KhipuStartOperationOptions): KhipuOptions {
    val builder = KhipuOptions.Builder()

    options.title?.let { builder.topBarTitle(it) }
    options.titleImageUrl?.let { builder.topBarImageUrl(it) }
    options.locale?.let { builder.locale(it) }
    options.skipExitPage?.let { builder.skipExitPage(it) }
    options.skipExitSuccessPage?.let { builder.skipExitSuccessPage(it) }
    options.showFooter?.let { builder.showFooter(it) }
    options.showMerchantLogo?.let { builder.showMerchantLogo(it) }
    options.showPaymentDetails?.let { builder.showPaymentDetails(it) }
    options.theme?.let { builder.theme(it.toSdk()) }
    options.colors?.let { builder.colors(it.toSdk()) }

    return builder.build()
}

/**
 * The `when` deliberately has no `else`: adding a theme to the schema has to
 * fail to compile here, not fail silently at runtime.
 */
internal fun KhipuTheme.toSdk(): KhipuOptions.Theme = when (this) {
    KhipuTheme.LIGHT -> KhipuOptions.Theme.LIGHT
    KhipuTheme.DARK -> KhipuOptions.Theme.DARK
    KhipuTheme.SYSTEM -> KhipuOptions.Theme.SYSTEM
}

private fun KhipuColors.toSdk(): SdkKhipuColors {
    val b = SdkKhipuColors.Builder()

    lightBackground?.let { b.lightBackground(it) }
    lightOnBackground?.let { b.lightOnBackground(it) }
    lightPrimary?.let { b.lightPrimary(it) }
    lightOnPrimary?.let { b.lightOnPrimary(it) }
    lightTopBarContainer?.let { b.lightTopBarContainer(it) }
    lightOnTopBarContainer?.let { b.lightOnTopBarContainer(it) }
    darkBackground?.let { b.darkBackground(it) }
    darkOnBackground?.let { b.darkOnBackground(it) }
    darkPrimary?.let { b.darkPrimary(it) }
    darkOnPrimary?.let { b.darkOnPrimary(it) }
    darkTopBarContainer?.let { b.darkTopBarContainer(it) }
    darkOnTopBarContainer?.let { b.darkOnTopBarContainer(it) }

    return b.build()
}
