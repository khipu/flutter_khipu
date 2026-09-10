package com.khipu.flutter_khipu

import android.app.Activity
import android.content.Intent
import android.util.Log
import com.khipu.client.KHIPU_RESULT_EXTRA
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
    private val KHIPU_START_OPERATION_CODE = 101010

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

    fun startOperation(call: MethodCall, result: Result) {
        this.pendingResult = result

        if (!call.hasArgument("operationId")) {
            result.error("MISSING_OPERATION_ID", "OperationId is required", null)
            return
        }

        val operationId = call.argument<String>("operationId")!!

        val intent = activity?.let {
            getKhipuLauncherIntent(
                context = it.baseContext,
                operationId = operationId,
                options = buildKhipuOptions(call)
            )

        }
        activity?.startActivityForResult(intent, KHIPU_START_OPERATION_CODE)
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
}
