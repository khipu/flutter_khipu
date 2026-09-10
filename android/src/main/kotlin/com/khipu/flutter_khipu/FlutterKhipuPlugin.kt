package com.khipu.flutter_khipu

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.util.Log
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


    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == KHIPU_START_OPERATION_CODE) {
            val result = pendingResult
            if (result == null) {
                Log.e("FlutterKhipuPlugin", "Result callback invoked but pendingResult not initialized")
                return false
            }
            if (data != null) {
                val khipuResult = data.getSerializableExtra(KHIPU_RESULT_EXTRA) as KhipuResult

                val resultMap = HashMap<String, Any>()
                resultMap["operationId"] = khipuResult.operationId
                resultMap["result"] = khipuResult.result
                resultMap["exitTitle"] = khipuResult.exitTitle
                resultMap["exitMessage"] = khipuResult.exitMessage
                khipuResult.exitUrl?.let { resultMap["exitUrl"] = it }
                khipuResult.failureReason?.let { resultMap["failureReason"] = it }
                khipuResult.continueUrl?.let { resultMap["continueUrl"] = it }
                resultMap["events"] = khipuResult.events.map { event ->
                    hashMapOf(
                        "name" to event.name,
                        "type" to event.type,
                        "timestamp" to event.timestamp
                    )
                }
                result.success(resultMap)
                return true
            }
        }
        return false
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
