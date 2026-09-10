package com.khipu.flutter_khipu

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import com.khipu.client.KHIPU_RESULT_EXTRA
import com.khipu.client.KhipuOptions
import com.khipu.client.KhipuResult
import com.khipu.client.getKhipuLauncherIntent

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

class FlutterKhipuPlugin : FlutterPlugin, MethodCallHandler, PluginRegistry.ActivityResultListener,
    ActivityAware {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: Result? = null

    /**
     * Construye el intent que lanza Khipu.
     *
     * Es un seam inyectable, no un adorno: `getKhipuLauncherIntent` es una función
     * de nivel superior del SDK que construye un `Intent` real, y ninguna de las
     * dos cosas funciona en un test unitario de JVM. Sustituirlo acá es lo que
     * hace testeable todo el camino de lanzamiento.
     */
    internal var intentFactory: (Context, String, KhipuOptions) -> Intent =
        { context, operationId, options ->
            getKhipuLauncherIntent(context = context, operationId = operationId, options = options)
        }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_khipu")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "startOperation") {
            return startOperation(call, result)
        } else {
            result.notImplemented()
        }
    }

    private fun startOperation(call: MethodCall, result: Result) {
        val activity = this.activity
            ?: return result.error("NO_ACTIVITY", "A foreground activity is needed to start Khipu", null)

        if (pendingResult != null) {
            return result.error("OPERATION_IN_PROGRESS", "A Khipu operation is already running", null)
        }

        val operationId = call.argument<String>("operationId")
            ?: return result.error("MISSING_OPERATION_ID", "OperationId is required", null)

        val intent = try {
            intentFactory(activity.baseContext, operationId, buildKhipuOptions(call))
        } catch (e: Exception) {
            return result.error("INVALID_OPTIONS", e.message, null)
        }

        // El callback se guarda lo más tarde posible. Todo lo que puede lanzar
        // ya ocurrió arriba, y lo único que queda va dentro de un try que lo libera.
        pendingResult = result
        try {
            activity.startActivityForResult(intent, KHIPU_START_OPERATION_CODE)
        } catch (e: Exception) {
            pendingResult = null
            result.error("LAUNCH_FAILED", e.message, null)
        }
    }


    /**
     * Responde la operación en vuelo exactamente una vez y limpia el estado.
     *
     * Devuelve false si no había ninguna, para que el listener no reclame un
     * resultado que no le corresponde.
     */
    private fun respondOnce(block: (Result) -> Unit): Boolean {
        val result = pendingResult ?: return false
        pendingResult = null
        block(result)
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != KHIPU_START_OPERATION_CODE) return false

        // Decide el payload, nunca el resultCode: las dos salidas del SDK traen un
        // KhipuResult completo, y RESULT_CANCELED es sólo la restauración tardía
        // tras una muerte de proceso. Ramificar por el código haría que el mismo
        // desenlace llegara al comercio de dos formas distintas.
        val khipuResult = runCatching { data?.khipuResult() }.getOrNull()

        return respondOnce { result ->
            if (khipuResult == null) {
                result.error("NO_RESULT", "Khipu returned without a result", null)
            } else {
                result.success(khipuResult.toMap())
            }
        }
    }

    private fun Intent.khipuResult(): KhipuResult? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getSerializableExtra(KHIPU_RESULT_EXTRA, KhipuResult::class.java)
        } else {
            @Suppress("DEPRECATION")
            getSerializableExtra(KHIPU_RESULT_EXTRA) as? KhipuResult
        }

    // Nota: se preserva deliberadamente el estilo de asignación indexada e infix
    // (en vez de un builder con una función put) porque
    // test/method_channel_seam_test.dart extrae las claves de esta función con una
    // regex que reconoce esos dos idioms, no una llamada a función. El contrato de
    // claves es el mismo; sólo cambia la sintaxis para seguir siendo legible por
    // ese test.
    private fun KhipuResult.toMap(): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>(
            "operationId" to operationId,
            "result" to result,
            "exitTitle" to exitTitle,
            "exitMessage" to exitMessage,
            "events" to events.map { event ->
                mapOf("name" to event.name, "type" to event.type, "timestamp" to event.timestamp)
            }
        )
        exitUrl?.let { map["exitUrl"] = it }
        failureReason?.let { map["failureReason"] = it }
        continueUrl?.let { map["continueUrl"] = it }
        return map
    }


    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    companion object {
        private const val KHIPU_START_OPERATION_CODE = 101010
    }
}
