package com.khipu.flutter_khipu

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import com.khipu.client.KHIPU_RESULT_EXTRA
import com.khipu.client.KhipuOptions
import com.khipu.client.getKhipuLauncherIntent
import com.khipu.client.KhipuResult as SdkKhipuResult

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class FlutterKhipuPlugin : FlutterPlugin, KhipuHostApi,
    PluginRegistry.ActivityResultListener, ActivityAware {

    private var binding: ActivityPluginBinding? = null
    private val activity: Activity? get() = binding?.activity
    private var pendingResult: CancellableContinuation<KhipuResult?>? = null
    private var messenger: BinaryMessenger? = null

    /**
     * Builds the intent that launches Khipu.
     *
     * It's an injectable seam, not decoration: `getKhipuLauncherIntent` is a
     * top-level function of the SDK that builds a real `Intent`, and neither
     * of the two works in a JVM unit test. Substituting it here is what makes
     * the whole launch path testable.
     */
    internal var intentFactory: (Context, String, KhipuOptions) -> Intent =
        { context, operationId, options ->
            getKhipuLauncherIntent(context = context, operationId = operationId, options = options)
        }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        messenger = flutterPluginBinding.binaryMessenger
        KhipuHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        messenger?.let { KhipuHostApi.setUp(it, null) }
        messenger = null
    }

    override suspend fun startOperation(options: KhipuStartOperationOptions): KhipuResult? {
        val activity = this.activity
            ?: throw failure("NO_ACTIVITY", "A foreground activity is needed to start Khipu")

        if (pendingResult != null) {
            throw failure("OPERATION_IN_PROGRESS", "A Khipu operation is already running")
        }

        // MISSING_OPERATION_ID goes away: the schema declares operationId
        // non-null and the codec rejects the message before it gets here, so
        // the guard was unreachable. iOS loses it for the same reason (Task
        // 4), and the Task 6 README brings the table down from nine codes to
        // seven.
        val intent = try {
            intentFactory(activity.baseContext, options.operationId, buildKhipuOptions(options))
        } catch (e: Exception) {
            throw failure("INVALID_OPTIONS", e.message)
        }

        // The continuation is stored as late as possible. Everything that can
        // throw already happened above, and the only thing left runs inside a
        // try that clears it.
        return suspendCancellableCoroutine { continuation ->
            pendingResult = continuation
            try {
                activity.startActivityForResult(intent, KHIPU_START_OPERATION_CODE)
            } catch (e: Exception) {
                pendingResult = null
                continuation.resumeWithException(failure("LAUNCH_FAILED", e.message))
            }
        }
    }

    private fun failure(code: String, message: String?): FlutterError =
        FlutterError(code, message, null)

    /**
     * Answers the in-flight operation exactly once and clears the state.
     *
     * Returns false if there wasn't one, so the listener doesn't claim a
     * result that isn't its own.
     */
    private fun respondOnce(block: (CancellableContinuation<KhipuResult?>) -> Unit): Boolean {
        val continuation = pendingResult ?: return false
        pendingResult = null
        block(continuation)
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != KHIPU_START_OPERATION_CODE) return false

        // Decide on the payload, never the resultCode: both of the SDK's
        // exits carry a complete KhipuResult, and RESULT_CANCELED is only the
        // late restoration after a process death. Branching on the code would
        // make the same outcome reach the merchant in two different ways.
        val khipuResult = runCatching { data?.khipuResult() }.getOrNull()

        return respondOnce { continuation ->
            if (khipuResult == null) {
                continuation.resumeWithException(failure("NO_RESULT", "Khipu returned without a result"))
            } else {
                continuation.resume(khipuResult.toPigeon())
            }
        }
    }

    private fun Intent.khipuResult(): SdkKhipuResult? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getSerializableExtra(KHIPU_RESULT_EXTRA, SdkKhipuResult::class.java)
        } else {
            @Suppress("DEPRECATION")
            getSerializableExtra(KHIPU_RESULT_EXTRA) as? SdkKhipuResult
        }

    private fun SdkKhipuResult.toPigeon(): KhipuResult = KhipuResult(
        operationId = operationId,
        result = statusOf(result),
        exitTitle = exitTitle,
        exitMessage = exitMessage,
        exitUrl = exitUrl,
        failureReason = failureReason,
        continueUrl = continueUrl,
        events = events.map { event ->
            KhipuEvent(
                name = event.name,
                type = event.type,
                timestamp = event.timestamp,
            )
        },
    )

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attach(binding)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attach(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detach(answerPending = false)
    }

    override fun onDetachedFromActivity() {
        detach(answerPending = true)
    }

    private fun attach(binding: ActivityPluginBinding) {
        detach(answerPending = false)
        this.binding = binding
        binding.addActivityResultListener(this)
    }

    /**
     * A rotation does not cancel the payment: Khipu's activity stays on top
     * and the result will arrive on reattach. An actual detachment does, and
     * leaving the continuation unanswered here would hang the Dart Future
     * forever.
     */
    private fun detach(answerPending: Boolean) {
        binding?.removeActivityResultListener(this)
        binding = null
        if (answerPending) {
            respondOnce { it.resumeWithException(failure("ACTIVITY_DETACHED", "The activity went away before Khipu returned")) }
        }
    }

    companion object {
        private const val KHIPU_START_OPERATION_CODE = 101010

        /**
         * Translates the SDK's free text into the channel's enum.
         *
         * The five values are the ones khipu-client-android 2.28.5 can
         * emit, measured on the bytecode of KhipuActivityKt. UNKNOWN is what
         * makes a new value from the server reach the merchant instead of
         * breaking the whole message.
         */
        internal fun statusOf(raw: String?): KhipuResultStatus = when (raw) {
            "OK" -> KhipuResultStatus.OK
            "ERROR" -> KhipuResultStatus.ERROR
            "WARNING" -> KhipuResultStatus.WARNING
            "CONTINUE" -> KhipuResultStatus.MUST_CONTINUE
            "USER_CANCELED" -> KhipuResultStatus.USER_CANCELED
            else -> KhipuResultStatus.UNKNOWN
        }
    }
}
