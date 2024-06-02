package com.khipu.flutter_khipu

import android.app.Activity
import android.content.Intent
import com.khipu.client.KHIPU_RESULT_EXTRA
import com.khipu.client.KhipuColors
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
    private lateinit var result: Result
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
        this.result = result

        if (!call.hasArgument("operationId")) {
            result.error("MISSING_OPERATION_ID", "OperationId is required", null)
            return
        }

        val operationId = call.argument<String>("operationId")!!

        val optionsBuilder = KhipuOptions.Builder()

        call.argument<String>("title")?.let {
            optionsBuilder.topBarTitle = it
        }

        call.argument<String>("locale")?.let {
            optionsBuilder.locale = it
        }

        call.argument<Boolean>("skipExitPage")?.let {
            optionsBuilder.skipExitPage = it
        }

        call.argument<String>("theme")?.let {
            if (it == "light") {
                optionsBuilder.theme = KhipuOptions.Theme.LIGHT
            } else if (it == "dark") {
                optionsBuilder.theme = KhipuOptions.Theme.DARK
            } else if (it == "system") {
                optionsBuilder.theme = KhipuOptions.Theme.SYSTEM
            }
        }

        val colorsBuilder = KhipuColors.Builder()

        call.argument<String>("lightPrimary")?.let {
            colorsBuilder.lightPrimary = it
        }
        call.argument<String>("lightOnPrimary")?.let {
            colorsBuilder.lightOnPrimary = it
        }
        call.argument<String>("lightBackground")?.let {
            colorsBuilder.lightBackground = it
        }
        call.argument<String>("lightOnBackground")?.let {
            colorsBuilder.lightOnBackground = it
        }
        call.argument<String>("lightTopBarContainer")?.let {
            colorsBuilder.lightTopBarContainer = it
        }
        call.argument<String>("lightOnTopBarContainer")?.let {
            colorsBuilder.lightOnTopBarContainer = it
        }
        call.argument<String>("darkPrimary")?.let {
            colorsBuilder.darkPrimary = it
        }
        call.argument<String>("darkOnPrimary")?.let {
            colorsBuilder.darkOnPrimary = it
        }
        call.argument<String>("darkBackground")?.let {
            colorsBuilder.darkBackground = it
        }
        call.argument<String>("darkOnBackground")?.let {
            colorsBuilder.darkOnBackground = it
        }
        call.argument<String>("darkTopBarContainer")?.let {
            colorsBuilder.darkTopBarContainer = it
        }
        call.argument<String>("darkOnTopBarContainer")?.let {
            colorsBuilder.darkOnTopBarContainer = it
        }
        optionsBuilder.colors = colorsBuilder.build()


        val intent = activity?.let {
            getKhipuLauncherIntent(
                context = it.baseContext,
                operationId = operationId,
                options = optionsBuilder.build()
            )

        }
        activity?.startActivityForResult(intent, KHIPU_START_OPERATION_CODE)
    }


    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == KHIPU_START_OPERATION_CODE) {
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
