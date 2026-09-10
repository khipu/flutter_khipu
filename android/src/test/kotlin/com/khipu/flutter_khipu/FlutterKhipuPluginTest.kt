package com.khipu.flutter_khipu

import android.app.Activity
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.any
import org.mockito.Mockito.doThrow
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`

class FlutterKhipuPluginTest {

    private lateinit var plugin: FlutterKhipuPlugin
    private lateinit var activity: Activity
    private lateinit var binding: ActivityPluginBinding

    @BeforeEach
    fun setUp() {
        plugin = FlutterKhipuPlugin()
        activity = mock(Activity::class.java)
        // Real Activity.baseContext is never null once attached; an unstubbed mock
        // returns null, and passing that into a Context-typed parameter trips
        // Kotlin's platform-type null check, which our try/catch would otherwise
        // misreport as INVALID_OPTIONS. Stubbing it keeps the mock honest.
        `when`(activity.baseContext).thenReturn(mock(Context::class.java))
        binding = mock(ActivityPluginBinding::class.java)
        `when`(binding.activity).thenReturn(activity)
        plugin.intentFactory = { _, _, _ -> mock(Intent::class.java) }
    }

    private fun startOperation(result: MethodChannel.Result, operationId: String? = "abc123") {
        val args = if (operationId == null) emptyMap() else mapOf("operationId" to operationId)
        plugin.onMethodCall(MethodCall("startOperation", args), result)
    }

    @Test
    fun `without an attached activity it errors instead of hanging`() {
        val result = mock(MethodChannel.Result::class.java)
        startOperation(result)
        verify(result).error("NO_ACTIVITY", "A foreground activity is needed to start Khipu", null)
    }

    @Test
    fun `a failed call does not leave the plugin stuck`() {
        // El defecto original: pendingResult se asignaba antes de validar, así que
        // una llamada rechazada dejaba el campo sucio. Con la guarda de concurrencia
        // encima, eso mataba el plugin para siempre.
        val rejected = mock(MethodChannel.Result::class.java)
        startOperation(rejected)                       // sin activity: NO_ACTIVITY
        verify(rejected).error("NO_ACTIVITY", "A foreground activity is needed to start Khipu", null)

        plugin.onAttachedToActivity(binding)
        val accepted = mock(MethodChannel.Result::class.java)
        startOperation(accepted)
        verify(accepted, never()).error(any(), any(), any())
        verify(activity).startActivityForResult(any(Intent::class.java), anyInt())
    }

    @Test
    fun `a missing operationId is rejected and leaves the plugin usable`() {
        plugin.onAttachedToActivity(binding)
        val rejected = mock(MethodChannel.Result::class.java)
        startOperation(rejected, operationId = null)
        verify(rejected).error("MISSING_OPERATION_ID", "OperationId is required", null)

        val accepted = mock(MethodChannel.Result::class.java)
        startOperation(accepted)
        verify(accepted, never()).error(any(), any(), any())
    }

    @Test
    fun `a second operation while one is in flight is rejected, the first survives`() {
        plugin.onAttachedToActivity(binding)
        val first = mock(MethodChannel.Result::class.java)
        val second = mock(MethodChannel.Result::class.java)

        startOperation(first)
        startOperation(second)

        verify(second).error("OPERATION_IN_PROGRESS", "A Khipu operation is already running", null)
        verify(first, never()).error(any(), any(), any())
        verify(first, never()).success(any())
    }

    @Test
    fun `an intent factory that throws yields INVALID_OPTIONS and frees the plugin`() {
        plugin.onAttachedToActivity(binding)
        plugin.intentFactory = { _, _, _ -> throw IllegalArgumentException("bad colour") }

        val rejected = mock(MethodChannel.Result::class.java)
        startOperation(rejected)
        verify(rejected).error("INVALID_OPTIONS", "bad colour", null)

        plugin.intentFactory = { _, _, _ -> mock(Intent::class.java) }
        val accepted = mock(MethodChannel.Result::class.java)
        startOperation(accepted)
        verify(accepted, never()).error(any(), any(), any())
    }

    @Test
    fun `a launch that throws yields LAUNCH_FAILED and the next call still works`() {
        // El test más importante del ciclo: demuestra que la guarda de concurrencia
        // no se convirtió en una trampa permanente.
        plugin.onAttachedToActivity(binding)
        // El android.jar "mockable" que usa el unit test para las clases de Android
        // reemplaza el cuerpo de ActivityNotFoundException(String) por un
        // `super()` sin argumento seguido de un throw de stub, así que su mensaje
        // real se pierde incluso con returnDefaultValues=true. Usamos una
        // excepción de la JVM (no simulada) para poder verificar el mensaje.
        doThrow(RuntimeException("no activity"))
            .`when`(activity).startActivityForResult(any(Intent::class.java), anyInt())

        val rejected = mock(MethodChannel.Result::class.java)
        startOperation(rejected)
        verify(rejected).error("LAUNCH_FAILED", "no activity", null)

        val activity2 = mock(Activity::class.java)
        `when`(activity2.baseContext).thenReturn(mock(Context::class.java))
        `when`(binding.activity).thenReturn(activity2)
        plugin.onAttachedToActivity(binding)
        val accepted = mock(MethodChannel.Result::class.java)
        startOperation(accepted)
        verify(accepted, never()).error(any(), any(), any())
        verify(activity2).startActivityForResult(any(Intent::class.java), anyInt())
    }
}
