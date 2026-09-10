package com.khipu.flutter_khipu

import android.app.Activity
import android.content.Context
import android.content.Intent
import com.khipu.client.KHIPU_RESULT_EXTRA
import com.khipu.client.KhipuEvent
import com.khipu.client.KhipuResult
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.anyString
import org.mockito.ArgumentMatchers.any
import org.mockito.Mockito.doThrow
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.times
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import kotlin.test.assertFalse
import kotlin.test.assertTrue

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

    private fun khipuResult() = KhipuResult(
        operationId = "abc123",
        exitTitle = "Listo",
        exitMessage = "Pago realizado",
        exitUrl = "https://khipu.com/done",
        continueUrl = null,
        result = "OK",
        // Verificado contra el AAR: el orden posicional de KhipuEvent es
        // (name, timestamp, type), no (name, type, timestamp). Nombrados a propósito.
        events = arrayOf(KhipuEvent(name = "start", timestamp = "2026-09-09T10:00:00Z", type = "info")),
        failureReason = null
    )

    private fun intentCarrying(payload: KhipuResult?): Intent {
        val intent = mock(Intent::class.java)
        `when`(intent.getSerializableExtra(KHIPU_RESULT_EXTRA)).thenReturn(payload)
        return intent
    }

    @Test
    fun `the payload decides, not the result code`() {
        // Las dos salidas del SDK traen un KhipuResult completo. Ramificar por
        // resultCode haría que el mismo desenlace llegara de dos formas según si
        // Android mató la activity y pasaron más de tres minutos.
        for (code in listOf(Activity.RESULT_OK, Activity.RESULT_CANCELED)) {
            plugin = FlutterKhipuPlugin()
            plugin.intentFactory = { _, _, _ -> mock(Intent::class.java) }
            plugin.onAttachedToActivity(binding)

            val result = mock(MethodChannel.Result::class.java)
            startOperation(result)
            assertTrue(plugin.onActivityResult(101010, code, intentCarrying(khipuResult())))

            verify(result).success(mapOf(
                "operationId" to "abc123",
                "result" to "OK",
                "exitTitle" to "Listo",
                "exitMessage" to "Pago realizado",
                "exitUrl" to "https://khipu.com/done",
                "events" to listOf(mapOf(
                    "name" to "start", "type" to "info", "timestamp" to "2026-09-09T10:00:00Z"
                ))
            ))
        }
    }

    @Test
    fun `a reply with no payload errors instead of hanging`() {
        plugin.onAttachedToActivity(binding)
        val result = mock(MethodChannel.Result::class.java)
        startOperation(result)

        assertTrue(plugin.onActivityResult(101010, Activity.RESULT_CANCELED, null))
        verify(result).error("NO_RESULT", "Khipu returned without a result", null)
    }

    @Test
    fun `a payload of the wrong shape errors instead of crashing the listener`() {
        plugin.onAttachedToActivity(binding)
        val result = mock(MethodChannel.Result::class.java)
        startOperation(result)

        val intent = mock(Intent::class.java)
        // Un extra de una clase inesperada — String también es Serializable — es
        // justo lo que el cast duro original (`as KhipuResult`) no toleraba: tiraba
        // ClassCastException dentro del listener sin responder nunca. El `as?` de la
        // reescritura debe convertirlo en null en silencio, no en una excepción.
        `when`(intent.getSerializableExtra(KHIPU_RESULT_EXTRA)).thenReturn("not a KhipuResult")

        assertTrue(plugin.onActivityResult(101010, Activity.RESULT_OK, intent))
        verify(result).error("NO_RESULT", "Khipu returned without a result", null)
    }

    @Test
    fun `a payload that fails to deserialize errors, and leaves the plugin usable for the next operation`() {
        plugin.onAttachedToActivity(binding)
        val result = mock(MethodChannel.Result::class.java)
        startOperation(result)

        val intent = mock(Intent::class.java)
        // A diferencia del test anterior (un valor presente pero de otra clase), acá
        // la propia lectura del extra lanza — la falla real que el `runCatching`
        // existe para atrapar. Sin él, esto escaparía del listener sin llamar ni
        // success ni error, colgando el Future de Dart para siempre.
        `when`(intent.getSerializableExtra(KHIPU_RESULT_EXTRA)).thenThrow(RuntimeException("boom"))

        assertTrue(plugin.onActivityResult(101010, Activity.RESULT_OK, intent))
        verify(result).error("NO_RESULT", "Khipu returned without a result", null)

        // Lo que más importa: atrapar la excepción no alcanza si deja pendingResult
        // sucio. Sin este assert, el test no distingue "atrapó y respondió" de
        // "atrapó y dejó el estado envenenado para la próxima operación".
        val second = mock(MethodChannel.Result::class.java)
        startOperation(second)
        verify(second, never()).error(anyString(), any(), any())
    }

    @Test
    fun `a second activity result for the same request does not respond twice`() {
        plugin.onAttachedToActivity(binding)
        val result = mock(MethodChannel.Result::class.java)
        startOperation(result)

        assertTrue(plugin.onActivityResult(101010, Activity.RESULT_OK, intentCarrying(khipuResult())))
        assertFalse(plugin.onActivityResult(101010, Activity.RESULT_OK, intentCarrying(khipuResult())))
        verify(result, times(1)).success(any())
    }

    @Test
    fun `after a result the plugin accepts the next operation`() {
        plugin.onAttachedToActivity(binding)
        val first = mock(MethodChannel.Result::class.java)
        startOperation(first)
        plugin.onActivityResult(101010, Activity.RESULT_OK, intentCarrying(khipuResult()))

        val second = mock(MethodChannel.Result::class.java)
        startOperation(second)
        verify(second, never()).error(anyString(), any(), any())
    }

    @Test
    fun `an unrelated request code is ignored`() {
        plugin.onAttachedToActivity(binding)
        val result = mock(MethodChannel.Result::class.java)
        startOperation(result)

        assertFalse(plugin.onActivityResult(999, Activity.RESULT_OK, intentCarrying(khipuResult())))
        verify(result, never()).success(any())
        verify(result, never()).error(any(), any(), any())
    }
}
