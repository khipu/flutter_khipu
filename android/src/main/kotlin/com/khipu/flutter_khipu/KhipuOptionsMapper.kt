package com.khipu.flutter_khipu

import com.khipu.client.KhipuColors
import com.khipu.client.KhipuOptions
import io.flutter.plugin.common.MethodCall

/**
 * Traduce el mapa plano que llega por el method channel a las opciones del SDK.
 *
 * Las claves son el contrato con el lado Dart: cada nombre de acá aparece
 * literal en `lib/flutter_khipu_method_channel.dart`, y `test/method_channel_seam_test.dart`
 * compara los dos conjuntos. Renombrar una clave sin tocar el otro lado
 * desactiva esa opción en silencio.
 */
internal fun buildKhipuOptions(call: MethodCall): KhipuOptions {
    val builder = KhipuOptions.Builder()

    call.argument<String>("title")?.let { builder.topBarTitle = it }
    call.argument<String>("titleImageUrl")?.let { builder.topBarImageUrl = it }
    call.argument<String>("locale")?.let { builder.locale = it }
    call.argument<Boolean>("skipExitPage")?.let { builder.skipExitPage = it }
    call.argument<Boolean>("skipExitSuccessPage")?.let { builder.skipExitSuccessPage = it }
    call.argument<Boolean>("showFooter")?.let { builder.showFooter = it }
    call.argument<Boolean>("showMerchantLogo")?.let { builder.showMerchantLogo = it }
    call.argument<Boolean>("showPaymentDetails")?.let { builder.showPaymentDetails = it }

    call.argument<String>("theme")?.let {
        when (it) {
            "light" -> builder.theme = KhipuOptions.Theme.LIGHT
            "dark" -> builder.theme = KhipuOptions.Theme.DARK
            "system" -> builder.theme = KhipuOptions.Theme.SYSTEM
            // Un valor desconocido se ignora: el SDK aplica su propio default.
        }
    }

    builder.colors = buildKhipuColors(call)
    return builder.build()
}

private fun buildKhipuColors(call: MethodCall): KhipuColors {
    val builder = KhipuColors.Builder()

    call.argument<String>("lightBackground")?.let { builder.lightBackground = it }
    call.argument<String>("lightOnBackground")?.let { builder.lightOnBackground = it }
    call.argument<String>("lightPrimary")?.let { builder.lightPrimary = it }
    call.argument<String>("lightOnPrimary")?.let { builder.lightOnPrimary = it }
    call.argument<String>("lightTopBarContainer")?.let { builder.lightTopBarContainer = it }
    call.argument<String>("lightOnTopBarContainer")?.let { builder.lightOnTopBarContainer = it }
    call.argument<String>("darkBackground")?.let { builder.darkBackground = it }
    call.argument<String>("darkOnBackground")?.let { builder.darkOnBackground = it }
    call.argument<String>("darkPrimary")?.let { builder.darkPrimary = it }
    call.argument<String>("darkOnPrimary")?.let { builder.darkOnPrimary = it }
    call.argument<String>("darkTopBarContainer")?.let { builder.darkTopBarContainer = it }
    call.argument<String>("darkOnTopBarContainer")?.let { builder.darkOnTopBarContainer = it }

    return builder.build()
}
