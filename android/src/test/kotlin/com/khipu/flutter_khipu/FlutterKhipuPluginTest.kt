@file:OptIn(DelicateCoroutinesApi::class, ExperimentalCoroutinesApi::class)

package com.khipu.flutter_khipu

import android.app.Activity
import android.content.Context
import android.content.Intent
import com.khipu.client.KHIPU_RESULT_EXTRA
import com.khipu.client.KhipuEvent as SdkKhipuEvent
import com.khipu.client.KhipuResult as SdkKhipuResult
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.any
import org.mockito.Mockito.doThrow
import org.mockito.Mockito.mock
import org.mockito.Mockito.times
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

class FlutterKhipuPluginTest {

    private lateinit var plugin: FlutterKhipuPlugin
    private lateinit var activity: Activity
    private lateinit var binding: ActivityPluginBinding

    @BeforeEach
    fun setUp() {
        plugin = FlutterKhipuPlugin()
        activity = mock(Activity::class.java)
        // A real Activity.baseContext is never null once attached; an unstubbed mock
        // returns null, and passing that into a Context-typed parameter trips
        // Kotlin's platform-type null check, which our try/catch would otherwise
        // misreport as INVALID_OPTIONS. Stubbing it keeps the mock honest.
        `when`(activity.baseContext).thenReturn(mock(Context::class.java))
        binding = mock(ActivityPluginBinding::class.java)
        `when`(binding.activity).thenReturn(activity)
        plugin.intentFactory = { _, _, _ -> mock(Intent::class.java) }
    }

    private fun options(operationId: String = "abc123") =
        KhipuStartOperationOptions(operationId = operationId)

    /**
     * How each test observes the way `plugin.startOperation` settles, without
     * tying that settling to the test's own call stack.
     *
     * `startOperation` is now a suspend function: its result only arrives
     * once `onActivityResult` (or `detach`) resumes the continuation it
     * suspended on. `GlobalScope.async(Dispatchers.Unconfined, start =
     * UNDISPATCHED)` runs the suspend function synchronously, on this
     * thread, up to that suspension point (or straight to completion, for
     * the calls that fail before ever reaching one) — so by the time
     * `start()` returns, `pendingResult` is already whatever it is going to
     * be for the rest of the test. `Unconfined` matters just as much as
     * `UNDISPATCHED`: without it, the *resumption* triggered later by
     * `onActivityResult`/`detach` would be dispatched onto
     * `Dispatchers.Default`'s thread pool instead of continuing on the
     * thread that called `continuation.resume(...)`, and the test's very
     * next assertion would race a background thread that hasn't run yet.
     * `invokeOnCompletion` then records the eventual outcome, whether it
     * arrives immediately (a synchronous throw) or later, from this test
     * calling `onActivityResult` itself. `GlobalScope` (not the test's own
     * coroutine) is what lets an operation be left deliberately unresolved —
     * several tests below need exactly that — without hanging.
     */
    private class Outcome {
        var resultSet: Boolean = false
        var result: KhipuResult? = null
        var error: Throwable? = null
    }

    private fun start(options: KhipuStartOperationOptions = options()): Outcome {
        val outcome = Outcome()
        val deferred = GlobalScope.async(Dispatchers.Unconfined, start = CoroutineStart.UNDISPATCHED) {
            plugin.startOperation(options)
        }
        deferred.invokeOnCompletion { cause ->
            if (cause == null) {
                outcome.result = deferred.getCompleted()
                outcome.resultSet = true
            } else {
                outcome.error = cause
            }
        }
        return outcome
    }

    private fun Outcome.assertFailed(code: String, message: String?) {
        val thrown = error
        assertIs<FlutterError>(thrown)
        assertEquals(code, thrown.code)
        assertEquals(message, thrown.message)
        // All nine call sites build their FlutterError with a null `details`;
        // this got lost when the `verify(result).error(code, message, null)`
        // calls were folded into this helper.
        assertNull(thrown.details)
    }

    private fun Outcome.assertNoFailure() {
        assertNull(error)
    }

    @Test
    fun `without an attached activity it errors instead of hanging`() {
        val outcome = start()
        outcome.assertFailed("NO_ACTIVITY", "A foreground activity is needed to start Khipu")
    }

    @Test
    fun `a failed call does not leave the plugin stuck`() {
        // The original bug: pendingResult was assigned before validating, so
        // a rejected call left the field dirty. With the concurrency guard on
        // top of that, it killed the plugin forever.
        val rejected = start()                       // no activity: NO_ACTIVITY
        rejected.assertFailed("NO_ACTIVITY", "A foreground activity is needed to start Khipu")

        plugin.onAttachedToActivity(binding)
        val accepted = start()
        accepted.assertNoFailure()
        verify(activity).startActivityForResult(any(Intent::class.java), anyInt())
    }

    @Test
    fun `a second operation while one is in flight is rejected, the first survives`() {
        plugin.onAttachedToActivity(binding)
        val first = start()
        val second = start()

        second.assertFailed("OPERATION_IN_PROGRESS", "A Khipu operation is already running")
        first.assertNoFailure()
        assertFalse(first.resultSet)
    }

    @Test
    fun `an intent factory that throws yields INVALID_OPTIONS and frees the plugin`() {
        plugin.onAttachedToActivity(binding)
        plugin.intentFactory = { _, _, _ -> throw IllegalArgumentException("bad colour") }

        val rejected = start()
        rejected.assertFailed("INVALID_OPTIONS", "bad colour")

        plugin.intentFactory = { _, _, _ -> mock(Intent::class.java) }
        val accepted = start()
        accepted.assertNoFailure()
    }

    @Test
    fun `a launch that throws yields LAUNCH_FAILED and the next call still works`() {
        // The most important test of the cycle: it proves the concurrency
        // guard did not become a permanent trap.
        plugin.onAttachedToActivity(binding)
        // The "mockable" android.jar the unit test uses for Android classes
        // replaces the body of ActivityNotFoundException(String) with a
        // no-argument `super()` followed by a stubbed throw, so its real
        // message is lost even with returnDefaultValues=true. We use a plain
        // JVM exception (not mocked) so we can verify the message.
        doThrow(RuntimeException("no activity"))
            .`when`(activity).startActivityForResult(any(Intent::class.java), anyInt())

        val rejected = start()
        rejected.assertFailed("LAUNCH_FAILED", "no activity")

        val activity2 = mock(Activity::class.java)
        `when`(activity2.baseContext).thenReturn(mock(Context::class.java))
        `when`(binding.activity).thenReturn(activity2)
        plugin.onAttachedToActivity(binding)
        val accepted = start()
        accepted.assertNoFailure()
        verify(activity2).startActivityForResult(any(Intent::class.java), anyInt())
    }

    private fun khipuResult() = SdkKhipuResult(
        operationId = "abc123",
        exitTitle = "Listo",
        exitMessage = "Pago realizado",
        exitUrl = "https://khipu.com/done",
        continueUrl = null,
        result = "OK",
        // Verified against the AAR: the positional order of KhipuEvent is
        // (name, timestamp, type), not (name, type, timestamp). Named on purpose.
        events = arrayOf(SdkKhipuEvent(name = "start", timestamp = "2026-09-09T10:00:00Z", type = "info")),
        failureReason = null
    )

    private fun intentCarrying(payload: SdkKhipuResult?): Intent {
        val intent = mock(Intent::class.java)
        `when`(intent.getSerializableExtra(KHIPU_RESULT_EXTRA)).thenReturn(payload)
        return intent
    }

    @Test
    fun `the payload decides, not the result code`() {
        // Both of the SDK's exits carry a complete KhipuResult. Branching on
        // resultCode would make the same outcome reach the merchant in two
        // different ways depending on whether Android killed the activity and
        // more than three minutes passed.
        for (code in listOf(Activity.RESULT_OK, Activity.RESULT_CANCELED)) {
            plugin = FlutterKhipuPlugin()
            plugin.intentFactory = { _, _, _ -> mock(Intent::class.java) }
            plugin.onAttachedToActivity(binding)

            val outcome = start()
            assertTrue(plugin.onActivityResult(101010, code, intentCarrying(khipuResult())))

            assertTrue(outcome.resultSet)
            assertEquals(
                KhipuResult(
                    operationId = "abc123",
                    result = KhipuResultStatus.OK,
                    rawResult = "OK",
                    exitTitle = "Listo",
                    exitMessage = "Pago realizado",
                    exitUrl = "https://khipu.com/done",
                    failureReason = null,
                    continueUrl = null,
                    events = listOf(
                        KhipuEvent(name = "start", type = "info", timestamp = "2026-09-09T10:00:00Z")
                    ),
                ),
                outcome.result,
            )
        }
    }

    @Test
    fun `a reply with no payload errors instead of hanging`() {
        plugin.onAttachedToActivity(binding)
        val outcome = start()

        assertTrue(plugin.onActivityResult(101010, Activity.RESULT_CANCELED, null))
        outcome.assertFailed("NO_RESULT", "Khipu returned without a result")
    }

    @Test
    fun `a payload of the wrong shape errors instead of crashing the listener`() {
        plugin.onAttachedToActivity(binding)
        val outcome = start()

        val intent = mock(Intent::class.java)
        // An extra of an unexpected class — String is also Serializable — is
        // exactly what the original hard cast (`as KhipuResult`) could not
        // tolerate: it threw a ClassCastException inside the listener without
        // ever responding. The `as?` in the rewrite must turn it into a
        // silent null, not an exception.
        `when`(intent.getSerializableExtra(KHIPU_RESULT_EXTRA)).thenReturn("not a KhipuResult")

        assertTrue(plugin.onActivityResult(101010, Activity.RESULT_OK, intent))
        outcome.assertFailed("NO_RESULT", "Khipu returned without a result")
    }

    @Test
    fun `a payload that fails to deserialize errors, and leaves the plugin usable for the next operation`() {
        plugin.onAttachedToActivity(binding)
        val outcome = start()

        val intent = mock(Intent::class.java)
        // Unlike the previous test (a value present but of another class),
        // here the read of the extra itself throws — the real failure that
        // `runCatching` exists to catch. Without it, this would escape the
        // listener without calling either success or error, hanging the Dart
        // Future forever.
        `when`(intent.getSerializableExtra(KHIPU_RESULT_EXTRA)).thenThrow(RuntimeException("boom"))

        assertTrue(plugin.onActivityResult(101010, Activity.RESULT_OK, intent))
        outcome.assertFailed("NO_RESULT", "Khipu returned without a result")

        // What matters most: catching the exception isn't enough if it
        // leaves pendingResult dirty. Without this assertion, the test
        // cannot tell "caught and responded" apart from "caught and left the
        // state poisoned for the next operation".
        val second = start()
        second.assertNoFailure()
    }

    @Test
    fun `a second activity result for the same request does not respond twice`() {
        plugin.onAttachedToActivity(binding)
        val outcome = start()

        assertTrue(plugin.onActivityResult(101010, Activity.RESULT_OK, intentCarrying(khipuResult())))
        assertFalse(plugin.onActivityResult(101010, Activity.RESULT_OK, intentCarrying(khipuResult())))
        assertTrue(outcome.resultSet)
    }

    @Test
    fun `after a result the plugin accepts the next operation`() {
        plugin.onAttachedToActivity(binding)
        start()
        plugin.onActivityResult(101010, Activity.RESULT_OK, intentCarrying(khipuResult()))

        val second = start()
        second.assertNoFailure()
    }

    @Test
    fun `an unrelated request code is ignored`() {
        plugin.onAttachedToActivity(binding)
        val outcome = start()

        assertFalse(plugin.onActivityResult(999, Activity.RESULT_OK, intentCarrying(khipuResult())))
        assertFalse(outcome.resultSet)
        outcome.assertNoFailure()
    }

    @Test
    fun `detaching from the activity answers an operation in flight`() {
        plugin.onAttachedToActivity(binding)
        val outcome = start()

        plugin.onDetachedFromActivity()

        outcome.assertFailed("ACTIVITY_DETACHED", "The activity went away before Khipu returned")
    }

    @Test
    fun `detaching removes the activity result listener`() {
        plugin.onAttachedToActivity(binding)
        plugin.onDetachedFromActivity()
        verify(binding).removeActivityResultListener(plugin)
    }

    @Test
    fun `a configuration change does not accumulate listeners`() {
        plugin.onAttachedToActivity(binding)
        plugin.onDetachedFromActivityForConfigChanges()
        plugin.onReattachedToActivityForConfigChanges(binding)

        verify(binding, times(2)).addActivityResultListener(plugin)
        verify(binding, times(1)).removeActivityResultListener(plugin)
    }

    @Test
    fun `a configuration change does not cancel an operation in flight`() {
        // Unlike the previous test (which only counts listeners), this one
        // walks the full journey: if `detach` ever answered pendingResult
        // during a rotation, or cleared it without answering, this test
        // catches it where the other one couldn't.
        plugin.onAttachedToActivity(binding)
        val outcome = start()

        plugin.onDetachedFromActivityForConfigChanges()
        outcome.assertNoFailure()
        assertFalse(outcome.resultSet)

        plugin.onReattachedToActivityForConfigChanges(binding)
        assertTrue(plugin.onActivityResult(101010, Activity.RESULT_OK, intentCarrying(khipuResult())))

        assertTrue(outcome.resultSet)
        outcome.assertNoFailure()
    }

    // "a missing operationId is rejected and leaves the plugin usable" is
    // deleted, not adapted: MISSING_OPERATION_ID is no longer representable.
    // The schema declares KhipuStartOperationOptions.operationId non-null, so
    // the Pigeon codec rejects a message missing it before startOperation is
    // ever called — there is no path left here that reaches the guard this
    // test exercised.

    @Test
    fun `maps every status the SDK can emit`() {
        // The five values measured on the bytecode of KhipuActivityKt in
        // khipu-client-android 2.28.5, plus the case that guards against a
        // new value from the server.
        assertEquals(KhipuResultStatus.OK, FlutterKhipuPlugin.statusOf("OK"))
        assertEquals(KhipuResultStatus.ERROR, FlutterKhipuPlugin.statusOf("ERROR"))
        assertEquals(KhipuResultStatus.WARNING, FlutterKhipuPlugin.statusOf("WARNING"))
        assertEquals(KhipuResultStatus.MUST_CONTINUE, FlutterKhipuPlugin.statusOf("CONTINUE"))
        assertEquals(KhipuResultStatus.USER_CANCELED, FlutterKhipuPlugin.statusOf("USER_CANCELED"))
    }

    @Test
    fun `an unknown status degrades instead of throwing`() {
        // This is the whole point of the unknown case: the day the server
        // emits a new value, the payment still has to reach the merchant.
        assertEquals(KhipuResultStatus.UNKNOWN, FlutterKhipuPlugin.statusOf("SOMETHING_NEW"))
        assertEquals(KhipuResultStatus.UNKNOWN, FlutterKhipuPlugin.statusOf(""))
    }
}
