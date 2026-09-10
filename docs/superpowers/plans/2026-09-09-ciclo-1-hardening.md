# Ciclo 1 — Endurecimiento, CI y documentación: Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cerrar seis defectos del camino de resultado de Android más un guard de concurrencia en iOS, montar CI en las dos ramas de mantenimiento, y documentar la geolocalización que el SDK inyecta en la app del comercio.

**Architecture:** El mapeo de opciones sale a su propio archivo (`KhipuOptionsMapper.kt`), dejando a `FlutterKhipuPlugin.kt` con una sola responsabilidad: ciclo de vida y plomería del resultado. Se introduce un seam inyectable para construir el `Intent`, que es lo que hace testeable el camino de lanzamiento sin un dispositivo. Todo el trabajo no-rompedor se escribe primero en `1.7.x` y se mergea a `main`.

**Tech Stack:** Kotlin + JUnit 5 + Mockito 5 (Android), Swift (iOS), Dart + `flutter_test`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-09-hardening-flutter-khipu-design.md`

## Global Constraints

- **Rama de trabajo:** `fix/android-result-path`, creada **desde `origin/1.7.x`**, no desde `main`.
- **No rompe API.** Ninguna firma pública de Dart cambia en este ciclo. Los enums, `final`, `lib/src/` y Pigeon son Ciclo 2.
- **`1.7.x` no recibe higiene.** Sólo bloques A y C. AGP, `compileSdk`, Java 11, `flutter_lints` y metadata de pubspec van únicamente a `main`.
- **A+C llegan a `main` por merge**, nunca reescritas a mano en las dos ramas.
- **Versiones:** `1.7.x` → 1.7.2. `main` → 1.8.1.
- **Restricciones de `1.7.x`:** `sdk: '>=3.4.1 <4.0.0'`, `flutter: '>=3.3.0'`. No usar sintaxis de Dart posterior a 3.4.1 en esa rama.
- **Comando de tests Kotlin:** `cd example/android && ./gradlew :flutter_khipu:test` (verificado: ~1m16s en frío).
- **Comando de tests Dart:** `flutter test` desde la raíz.
- **Nombres de error ya existentes que NO se renombran:** `MISSING_OPERATION_ID`, `NO_VIEW_CONTROLLER`, `BAD_ARGUMENT_DICTIONARY`.
- **Nombres de error nuevos, exactos:** `NO_ACTIVITY`, `OPERATION_IN_PROGRESS`, `INVALID_OPTIONS`, `LAUNCH_FAILED`, `NO_RESULT`, `ACTIVITY_DETACHED`.
- **Tamaño del tarball hoy: 98 KB.** El tope del CI se fija en 5 MB (holgado para crecer, y atrapa una regresión como los 87 MB de 1.7.0).
- **El Nexus de Khipu responde HTTP 200 sin credenciales** (verificado). El build de Android en CI es viable.

---

## Estructura de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `.github/workflows/ci.yml` | CI. Contenido distinto por rama. | 1, 11 |
| `android/.../KhipuOptionsMapper.kt` | **Nuevo.** Traduce el `MethodCall` a `KhipuOptions`. Sin estado. | 2 |
| `android/.../FlutterKhipuPlugin.kt` | Ciclo de vida y plomería del resultado. Nada de mapeo. | 3, 4, 5 |
| `android/src/test/kotlin/.../KhipuOptionsMapperTest.kt` | **Nuevo.** | 2 |
| `android/src/test/kotlin/.../FlutterKhipuPluginTest.kt` | **Nuevo.** | 3, 4, 5 |
| `android/build.gradle` | Stubs de test, pin de `khenshin-protocol`, higiene. | 2, 6, 12 |
| `ios/.../FlutterKhipuPlugin.swift` | Guard de concurrencia únicamente. | 7 |
| `README.md` | Geolocalización, códigos de error, cancelación. | 8 |
| `test/package_metadata_test.dart` | **Nuevo.** Sincronía de versiones entre pubspec, podspec y Package.swift. | 13 |

---

## Fase 1 — Rama `fix/android-result-path` desde `origin/1.7.x`

### Task 1: CI mínimo en `1.7.x`, antes de tocar código

La red de seguridad va primero. Sin esto, las tareas 2-8 se validan sólo a mano.

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: nada.
- Produces: un workflow llamado `ci` con un job `dart` que corre en cada push y PR.

- [ ] **Step 1: Crear la rama desde `1.7.x`**

```bash
git fetch origin
git checkout -b fix/android-result-path origin/1.7.x
git log --oneline -1   # debe mostrar el head de 1.7.x, no el de main
```

- [ ] **Step 2: Escribir el workflow**

```yaml
name: ci

on:
  push:
    branches: [main, 1.7.x]
  pull_request:

jobs:
  dart:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.0'
          channel: stable
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - name: Publish dry run
        run: dart pub publish --dry-run
```

- [ ] **Step 3: Verificar en local lo que el CI va a correr**

```bash
flutter pub get && flutter analyze && flutter test && dart pub publish --dry-run
```

Esperado: analyze sin issues, 28 tests en verde, dry-run con 0 warnings.

- [ ] **Step 4: Commit y empujar para que el workflow corra de verdad**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: run analyze, tests and a publish dry run on every push"
git push -u origin fix/android-result-path
```

- [ ] **Step 5: Confirmar que el job pasó en GitHub**

```bash
gh run list --branch fix/android-result-path --limit 1
gh run watch
```

Esperado: `dart` en verde. **Si `flutter-version: '3.41.0'` no existe en el manifiesto de la action**, el job falla en el paso de setup con un mensaje que lista las versiones disponibles: elegir la 3.41.x más alta de esa lista, corregir el YAML y volver a empujar. No cambiar a 3.44 en esta rama.

---

### Task 2: Extraer el mapeo de opciones a su propio archivo

Refactor puro: mismo comportamiento, archivo nuevo. Se hace primero y solo, para que el diff de las tareas 3-5 sea legible.

**Files:**
- Create: `android/src/main/kotlin/com/khipu/flutter_khipu/KhipuOptionsMapper.kt`
- Create: `android/src/test/kotlin/com/khipu/flutter_khipu/KhipuOptionsMapperTest.kt`
- Modify: `android/src/main/kotlin/com/khipu/flutter_khipu/FlutterKhipuPlugin.kt` (borrar líneas 52-134, llamar al mapper)
- Modify: `android/build.gradle`

**Interfaces:**
- Produces: `internal fun buildKhipuOptions(call: MethodCall): KhipuOptions`

- [ ] **Step 1: Habilitar los stubs de `android.jar` en tests unitarios**

En `android/build.gradle`, dentro del bloque `testOptions { unitTests.all { ... } }` ya existente, agregar arriba de `unitTests.all`:

```groovy
    testOptions {
        unitTests.returnDefaultValues = true
        unitTests.all {
```

Sin esto, cualquier llamada a `android.util.Log` o similar en un test lanza `RuntimeException: Method not mocked`.

- [ ] **Step 2: Escribir el test que falla**

Crear `android/src/test/kotlin/com/khipu/flutter_khipu/KhipuOptionsMapperTest.kt`:

```kotlin
package com.khipu.flutter_khipu

import com.khipu.client.KhipuOptions
import io.flutter.plugin.common.MethodCall
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals

class KhipuOptionsMapperTest {

    private fun call(args: Map<String, Any?>) = MethodCall("startOperation", args)

    @Test
    fun `maps the scalar options`() {
        val options = buildKhipuOptions(call(mapOf(
            "operationId" to "abc123",
            "title" to "Mi comercio",
            "titleImageUrl" to "https://example.com/logo.png",
            "locale" to "es_CL",
            "skipExitPage" to true,
            "skipExitSuccessPage" to false,
            "showFooter" to false,
            "showMerchantLogo" to true,
            "showPaymentDetails" to false
        )))

        assertEquals("Mi comercio", options.topBarTitle)
        assertEquals("https://example.com/logo.png", options.topBarImageUrl)
        assertEquals("es_CL", options.locale)
        assertEquals(true, options.skipExitPage)
        assertEquals(false, options.skipExitSuccessPage)
        assertEquals(false, options.showFooter)
        assertEquals(true, options.showMerchantLogo)
        assertEquals(false, options.showPaymentDetails)
    }

    @Test
    fun `maps each theme string onto its enum`() {
        assertEquals(KhipuOptions.Theme.LIGHT, buildKhipuOptions(call(mapOf("theme" to "light"))).theme)
        assertEquals(KhipuOptions.Theme.DARK, buildKhipuOptions(call(mapOf("theme" to "dark"))).theme)
        assertEquals(KhipuOptions.Theme.SYSTEM, buildKhipuOptions(call(mapOf("theme" to "system"))).theme)
    }

    @Test
    fun `maps every colour onto its own field`() {
        val names = listOf(
            "lightBackground", "lightOnBackground", "lightPrimary", "lightOnPrimary",
            "lightTopBarContainer", "lightOnTopBarContainer",
            "darkBackground", "darkOnBackground", "darkPrimary", "darkOnPrimary",
            "darkTopBarContainer", "darkOnTopBarContainer"
        )
        val colors = buildKhipuOptions(call(names.associateWith { it })).colors

        assertEquals("lightBackground", colors.lightBackground)
        assertEquals("lightOnBackground", colors.lightOnBackground)
        assertEquals("lightPrimary", colors.lightPrimary)
        assertEquals("lightOnPrimary", colors.lightOnPrimary)
        assertEquals("lightTopBarContainer", colors.lightTopBarContainer)
        assertEquals("lightOnTopBarContainer", colors.lightOnTopBarContainer)
        assertEquals("darkBackground", colors.darkBackground)
        assertEquals("darkOnBackground", colors.darkOnBackground)
        assertEquals("darkPrimary", colors.darkPrimary)
        assertEquals("darkOnPrimary", colors.darkOnPrimary)
        assertEquals("darkTopBarContainer", colors.darkTopBarContainer)
        assertEquals("darkOnTopBarContainer", colors.darkOnTopBarContainer)
    }

    @Test
    fun `an absent option is left at its default instead of being set to null`() {
        val options = buildKhipuOptions(call(mapOf("operationId" to "abc123")))
        assertEquals(null, options.topBarTitle)
        assertEquals(null, options.theme)
    }

    @Test
    fun `an unknown theme string is ignored rather than throwing`() {
        assertEquals(null, buildKhipuOptions(call(mapOf("theme" to "neon"))).theme)
    }
}
```

- [ ] **Step 3: Correr y verificar que falla**

```bash
cd example/android && ./gradlew :flutter_khipu:test
```

Esperado: FALLA en compilación con `Unresolved reference: buildKhipuOptions`.

- [ ] **Step 4: Escribir el mapper**

Crear `android/src/main/kotlin/com/khipu/flutter_khipu/KhipuOptionsMapper.kt`:

```kotlin
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
```

- [ ] **Step 5: Borrar el mapeo viejo del plugin**

En `FlutterKhipuPlugin.kt`, borrar desde `val optionsBuilder = KhipuOptions.Builder()` (línea 52) hasta `optionsBuilder.colors = colorsBuilder.build()` (línea 134) inclusive, y reemplazar el uso en la construcción del intent por `buildKhipuOptions(call)`. Borrar los imports de `KhipuColors` y `KhipuOptions`, que ya no se usan en este archivo.

- [ ] **Step 6: Correr todo y verificar verde**

```bash
cd example/android && ./gradlew :flutter_khipu:test
cd ../.. && flutter analyze && flutter test
```

Esperado: 5 tests Kotlin en verde, 28 Dart en verde. El seam test de Dart sigue pasando porque las claves no cambiaron de nombre ni de archivo — lee `lib/`, no el Kotlin. Si falla, el mapeo perdió una clave.

- [ ] **Step 7: Commit**

```bash
git add android/build.gradle android/src
git commit -m "refactor(android): move option mapping into KhipuOptionsMapper"
```

---

### Task 3: Reordenar `startOperation` y agregar el seam del intent

Ésta es la tarea que desarma la bomba. El orden es la mitad del arreglo: agregar `OPERATION_IN_PROGRESS` sobre el orden actual convertiría una llamada malformada en un plugin muerto para el resto de la sesión.

**Files:**
- Modify: `android/src/main/kotlin/com/khipu/flutter_khipu/FlutterKhipuPlugin.kt`
- Create: `android/src/test/kotlin/com/khipu/flutter_khipu/FlutterKhipuPluginTest.kt`

**Interfaces:**
- Consumes: `buildKhipuOptions(call)` de la Task 2.
- Produces: `internal var intentFactory: (Context, String, KhipuOptions) -> Intent` en `FlutterKhipuPlugin`, sobreescribible desde tests. `internal` alcanza: Gradle hace del source set de test un *friend* del main.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `android/src/test/kotlin/com/khipu/flutter_khipu/FlutterKhipuPluginTest.kt`:

```kotlin
package com.khipu.flutter_khipu

import android.app.Activity
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

class FlutterKhipuPluginTest {

    private lateinit var plugin: FlutterKhipuPlugin
    private lateinit var activity: Activity
    private lateinit var binding: ActivityPluginBinding

    @BeforeEach
    fun setUp() {
        plugin = FlutterKhipuPlugin()
        activity = mock(Activity::class.java)
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
        doThrow(android.content.ActivityNotFoundException("no activity"))
            .`when`(activity).startActivityForResult(any(Intent::class.java), anyInt())

        val rejected = mock(MethodChannel.Result::class.java)
        startOperation(rejected)
        verify(rejected).error("LAUNCH_FAILED", "no activity", null)

        val activity2 = mock(Activity::class.java)
        `when`(binding.activity).thenReturn(activity2)
        plugin.onAttachedToActivity(binding)
        val accepted = mock(MethodChannel.Result::class.java)
        startOperation(accepted)
        verify(accepted, never()).error(any(), any(), any())
        verify(activity2).startActivityForResult(any(Intent::class.java), anyInt())
    }
}
```

Nota sobre imports: `` `when` `` es `org.mockito.Mockito.\`when\``; agregarlo al bloque de imports como `` import org.mockito.Mockito.`when` ``.

- [ ] **Step 2: Correr y verificar que falla**

```bash
cd example/android && ./gradlew :flutter_khipu:test
```

Esperado: FALLA en compilación con `Unresolved reference: intentFactory`.

- [ ] **Step 3: Reescribir `startOperation` y agregar el seam**

En `FlutterKhipuPlugin.kt`, agregar los imports `android.content.Context` y `com.khipu.client.KhipuOptions`, y dentro de la clase:

```kotlin
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
```

Y reemplazar el cuerpo entero de `startOperation` por:

```kotlin
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
```

Cambiar también la declaración a `private fun` (hoy es pública sin motivo) y mover el request code a un companion:

```kotlin
    companion object {
        private const val KHIPU_START_OPERATION_CODE = 101010
    }
```

- [ ] **Step 4: Correr y verificar verde**

```bash
cd example/android && ./gradlew :flutter_khipu:test
```

Esperado: 11 tests en verde (5 del mapper, 6 de éste).

- [ ] **Step 5: Commit**

```bash
git add android/src
git commit -m "fix(android): validate before storing the pending result

Storing the MethodChannel.Result first meant a rejected call left the field
pointing at an already-answered Result. Harmless on its own, but the
OPERATION_IN_PROGRESS guard added here turns that into a plugin that rejects
every later call for the rest of the session. Validating first, storing last,
and releasing on a failed launch is what keeps the guard from becoming a trap."
```

---

### Task 4: Responder por payload, nunca por `resultCode`

**Files:**
- Modify: `android/src/main/kotlin/com/khipu/flutter_khipu/FlutterKhipuPlugin.kt`
- Modify: `android/src/test/kotlin/com/khipu/flutter_khipu/FlutterKhipuPluginTest.kt`

**Interfaces:**
- Consumes: `intentFactory`, `pendingResult` de la Task 3.
- Produces: `private fun respondOnce(block: (Result) -> Unit): Boolean`

- [ ] **Step 1: Escribir los tests que fallan**

Agregar a `FlutterKhipuPluginTest.kt` (y los imports `com.khipu.client.KHIPU_RESULT_EXTRA`, `com.khipu.client.KhipuEvent`, `com.khipu.client.KhipuResult`, `org.mockito.ArgumentMatchers.anyString`, `kotlin.test.assertFalse`, `kotlin.test.assertTrue`):

```kotlin
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

        assertTrue(plugin.onActivityResult(101010, Activity.RESULT_OK, intentCarrying(null)))
        verify(result).error("NO_RESULT", "Khipu returned without a result", null)
    }

    @Test
    fun `a second activity result for the same request does not respond twice`() {
        plugin.onAttachedToActivity(binding)
        val result = mock(MethodChannel.Result::class.java)
        startOperation(result)

        assertTrue(plugin.onActivityResult(101010, Activity.RESULT_OK, intentCarrying(khipuResult())))
        assertFalse(plugin.onActivityResult(101010, Activity.RESULT_OK, intentCarrying(khipuResult())))
        verify(result, org.mockito.Mockito.times(1)).success(any())
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
```

- [ ] **Step 2: Correr y verificar que falla**

```bash
cd example/android && ./gradlew :flutter_khipu:test
```

Esperado: los seis tests nuevos fallan. `a reply with no payload errors instead of hanging` falla con `Wanted but not invoked: result.error("NO_RESULT", ...)` — que es exactamente el defecto 6.

- [ ] **Step 3: Reescribir `onActivityResult`**

Reemplazar el método completo, y agregar el import `android.os.Build`:

```kotlin
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

    private fun KhipuResult.toMap(): Map<String, Any?> = buildMap {
        put("operationId", operationId)
        put("result", result)
        put("exitTitle", exitTitle)
        put("exitMessage", exitMessage)
        exitUrl?.let { put("exitUrl", it) }
        failureReason?.let { put("failureReason", it) }
        continueUrl?.let { put("continueUrl", it) }
        put("events", events.map { mapOf("name" to it.name, "type" to it.type, "timestamp" to it.timestamp) })
    }
```

Borrar el import de `android.util.Log`, que ya no se usa.

- [ ] **Step 4: Correr y verificar verde**

```bash
cd example/android && ./gradlew :flutter_khipu:test
cd ../.. && flutter test
```

Esperado: 17 tests Kotlin en verde. Los 28 de Dart siguen verdes: `method_channel_seam_test.dart` compara las claves del resultado entre Kotlin, Swift y Dart, y `toMap()` conserva los mismos nombres. Si ese test se pone rojo, una clave cambió de nombre.

- [ ] **Step 5: Commit**

```bash
git add android/src
git commit -m "fix(android): answer from the payload, never from the result code

A reply with no payload left the pending result unanswered, and an extra of an
unexpected class threw inside the listener without answering either. Both hung
the Dart Future. respondOnce makes answering exactly once structural rather
than something each exit path has to remember."
```

---

### Task 5: Ciclo de vida de la activity

**Files:**
- Modify: `android/src/main/kotlin/com/khipu/flutter_khipu/FlutterKhipuPlugin.kt`
- Modify: `android/src/test/kotlin/com/khipu/flutter_khipu/FlutterKhipuPluginTest.kt`

**Interfaces:**
- Consumes: `respondOnce` de la Task 4.
- Produces: nada nuevo para tareas posteriores.

- [ ] **Step 1: Escribir los tests que fallan**

```kotlin
    @Test
    fun `detaching from the activity answers an operation in flight`() {
        plugin.onAttachedToActivity(binding)
        val result = mock(MethodChannel.Result::class.java)
        startOperation(result)

        plugin.onDetachedFromActivity()

        verify(result).error("ACTIVITY_DETACHED", "The activity went away before Khipu returned", null)
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

        verify(binding, org.mockito.Mockito.times(2)).addActivityResultListener(plugin)
        verify(binding, org.mockito.Mockito.times(1)).removeActivityResultListener(plugin)
    }
```

- [ ] **Step 2: Correr y verificar que falla**

```bash
cd example/android && ./gradlew :flutter_khipu:test
```

Esperado: los tres fallan. `detaching removes the activity result listener` falla con `Wanted but not invoked: binding.removeActivityResultListener` — el defecto 5.

- [ ] **Step 3: Guardar el binding y limpiarlo**

Reemplazar los cuatro métodos de `ActivityAware` y el campo `activity`:

```kotlin
    private var binding: ActivityPluginBinding? = null
    private val activity: Activity? get() = binding?.activity

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
     * Una rotación no cancela el pago: la activity de Khipu sigue arriba y el
     * resultado llegará al reattach. Un desprendimiento definitivo sí, y dejar el
     * callback sin responder ahí colgaría el Future para siempre.
     */
    private fun detach(answerPending: Boolean) {
        binding?.removeActivityResultListener(this)
        binding = null
        if (answerPending) {
            respondOnce { it.error("ACTIVITY_DETACHED", "The activity went away before Khipu returned", null) }
        }
    }
```

Borrar el campo `private var activity: Activity? = null` viejo.

- [ ] **Step 4: Correr y verificar verde**

```bash
cd example/android && ./gradlew :flutter_khipu:test
cd ../.. && flutter analyze && flutter test
```

Esperado: 20 tests Kotlin en verde, 28 Dart en verde, analyze limpio.

- [ ] **Step 5: Commit**

```bash
git add android/src
git commit -m "fix(android): remove the activity result listener on detach

Every reattach added another listener without the previous one ever being
removed, so a rotation accumulated them. Detaching for good now also answers
an operation in flight instead of leaving the Future unresolved."
```

---

### Task 6: Subir `khipu-client-android` a 2.28.0

Cierra §2.6.a del spec. Es el único defecto de este ciclo que hoy mata el proceso de la app del comercio.

**Files:**
- Modify: `android/build.gradle`

**Interfaces:**
- Consumes: nada.
- Produces: nada.

- [ ] **Step 1: Confirmar el estado actual**

```bash
cd example/android && ./gradlew :flutter_khipu:dependencies --configuration releaseRuntimeClasspath | grep khenshin
```

Esperado: `com.khipu.khenshin:protocol:1.0.59`, traída por `khipu-client-android:2.27.0`.

- [ ] **Step 2: Subir el pin del cliente**

En `android/build.gradle`, dentro de `dependencies`:

```groovy
        // 2.27.0 arrastraba protocol 1.0.59, cuyo FailureReasonType no conoce
        // USER_DISCONNECTED — un valor que la librería de iOS sí tiene. El enum lo
        // deserializa un forValue generado que LANZA ante un valor desconocido, y en
        // Android esa excepción sale sin atrapar en el EventThread de socket.io y se
        // lleva el proceso de la app. 2.28.0 fija protocol 1.0.60, que agrega esa
        // constante y nada más.
        implementation 'com.khipu:khipu-client-android:2.28.0'
```

- [ ] **Step 3: Verificar que subió el protocolo y nada más se movió**

```bash
cd example/android && ./gradlew :flutter_khipu:dependencies --configuration releaseRuntimeClasspath | grep -E "khipu|khenshin"
```

Esperado: `khipu-client-android:2.28.0` y `protocol:1.0.60`. `khenshin-java-securemessage` sigue en `4.0.0.32` y `kotlin-stdlib` en `2.0.21` — si alguno se movió, parar y revisar, porque el POM de 2.28.0 no los cambia.

- [ ] **Step 4: Verificar que compila y los tests siguen verdes**

```bash
cd example/android && ./gradlew :flutter_khipu:test
cd .. && flutter build apk --debug
```

Esperado: 20 tests en verde y APK construido. La API pública del AAR es idéntica entre 2.27.0 y 2.28.0 (verificado con `javap`, 3834 líneas, diff vacío), así que nada del plugin debería necesitar cambios.

- [ ] **Step 5: Commit**

```bash
git add android/build.gradle
git commit -m "fix(android): move to khipu-client-android 2.28.0

2.27.0 pinned khenshin protocol 1.0.59, whose FailureReasonType has 14
constants against the 15 the iOS protocol library ships. The missing one is
USER_DISCONNECTED, and an unknown value does not degrade: the generated
forValue throws, and on Android that throw escapes uncaught on socket.io's
EventThread and takes the host app's process with it.

2.28.0 is 2.27.0 with that pin raised to 1.0.60. Verified before adopting:
the AAR manifest is identical, the public API is identical across all 3834
lines javap reports, and 1.0.60 adds USER_DISCONNECTED and nothing else."
```

---

### Task 7: Guard de concurrencia en iOS

**Files:**
- Modify: `ios/flutter_khipu/Sources/flutter_khipu/FlutterKhipuPlugin.swift`

**Interfaces:**
- Produces: nada que consuman otras tareas.

- [ ] **Step 1: Agregar el guard**

En la clase, agregar la propiedad y el chequeo. Va después del `guard let args` y antes de construir las opciones:

```swift
    /// Verdadero mientras Khipu está presentado.
    ///
    /// Sin esto, una segunda llamada presentaría Khipu **encima de Khipu**:
    /// `presenter()` camina hasta el controlador presentado más alto, que en ese
    /// momento es el propio Khipu. Dos pagos apilados sobre la misma operación.
    private var operationInFlight = false
```

Y al inicio de `startOperation`, antes del `guard let rootViewController`:

```swift
        if operationInFlight {
            result(FlutterError(code: "OPERATION_IN_PROGRESS",
                                message: "A Khipu operation is already running",
                                details: nil))
            return
        }
```

Justo antes del `DispatchQueue.main.async`, marcar la bandera, y liberarla dentro del closure de resultado:

```swift
        operationInFlight = true
        DispatchQueue.main.async {
            KhipuLauncher.launch(presenter: rootViewController,
                                 operationId: operationId,
                                 options: optionsBuilder.build()) { [weak self] khipuResult in
                self?.operationInFlight = false
                result([
```

- [ ] **Step 2: Compilar el example en iOS**

```bash
cd example && flutter build ios --no-codesign --debug
```

Esperado: BUILD SUCCEEDED. Es la única verificación posible sin dispositivo; el guard se prueba a mano en el gate del spec (§8, ítem 4).

- [ ] **Step 3: Commit**

```bash
git add ios/flutter_khipu/Sources/flutter_khipu/FlutterKhipuPlugin.swift
git commit -m "fix(ios): reject a second operation while Khipu is presented

presenter() walks to the topmost presented controller, so a second call with
Khipu already on screen presented Khipu on top of Khipu."
```

---

### Task 8: Documentación

**Files:**
- Modify: `README.md`

**Interfaces:**
- Produces: nada de código.

- [ ] **Step 1: Agregar la sección de geolocalización**

En `README.md`, dentro de `## Platform setup` → `### Android`, después de la subsección `#### Opening banking apps`, agregar:

```markdown
#### Location permissions

Khipu's Android client declares `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`
in its own manifest, so the manifest merger adds them to your app whether or not you
declare them yourself. Some banks require a geolocation check before authorizing a
transfer, and the SDK asks the payer for the permission at runtime, from a warning
screen inside Khipu's own UI.

Three things follow from that, and none of them are optional:

- **Play Data Safety.** You must declare that your app collects location, even though
  the prompt comes from Khipu and the payer can decline it.
- **The prompt looks like yours.** The payer sees a location dialog while inside your
  app. Tell your support team, or they will field the question cold.
- **Ley 21.719.** Location collected during a payment is personal data. It belongs in
  your privacy notice.

Do **not** strip the permissions with `tools:node="remove"`. It builds, and then
authorization fails at the banks that require the check.
```

- [ ] **Step 2: Documentar los códigos de error y la cancelación**

Al final de `README.md`, después de la lista de campos de `KhipuResult`, agregar:

```markdown
## Cancellation

There is no separate "cancelled" outcome. When the payer abandons the payment — by
backing out, by using Khipu's close button, or by coming back to a payment Android
tore down more than three minutes earlier — the result arrives as a normal
`KhipuResult` with `result` set to `"ERROR"` and `failureReason` set to
`"USER_CANCELED"`. `exitTitle` and `exitMessage` come back empty in that case.

## Errors

`startOperation` throws a `PlatformException` when it cannot start or finish. Not
every code exists on both platforms — the causes are platform-specific.

| Code | Android | iOS | Cause |
|---|:-:|:-:|---|
| `MISSING_OPERATION_ID` | ✓ | ✓ | No `operationId` was given |
| `OPERATION_IN_PROGRESS` | ✓ | ✓ | A Khipu operation is already running |
| `NO_ACTIVITY` | ✓ | | The plugin is attached to the engine but not to an activity |
| `NO_VIEW_CONTROLLER` | | ✓ | No view controller was available to present from |
| `BAD_ARGUMENT_DICTIONARY` | | ✓ | The arguments were not a dictionary |
| `INVALID_OPTIONS` | ✓ | | The options could not be mapped — check your colour strings |
| `LAUNCH_FAILED` | ✓ | | Khipu's activity could not be started |
| `NO_RESULT` | ✓ | | Khipu returned without a result |
| `ACTIVITY_DETACHED` | ✓ | | The activity went away before Khipu returned |
```

- [ ] **Step 3: Verificar que el README no rompe el dry run**

```bash
dart pub publish --dry-run
```

Esperado: 0 warnings.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document location permissions, cancellation and error codes"
```

---

### Task 9: CHANGELOG y versión 1.7.2

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Escribir la entrada del CHANGELOG**

Agregar arriba de todo en `CHANGELOG.md`, siguiendo la prosa explicativa del resto del archivo:

```markdown
# 1.7.2

Fixes a crash that killed the host app's process on Android, and hardens the result
path around it.

The crash: `khipu-client-android` pins a version of the Khenshin protocol library whose
`FailureReasonType` is missing `USER_DISCONNECTED`, which the iOS library has. An
unknown value there does not degrade — the generated parser throws, and on Android that
throw escapes uncaught on the socket's event thread and takes the process down. This
release pulls the protocol library version that knows the value. It adds that one
constant and nothing else.

The hardening is separate and had no known trigger — the SDK's four exits all carry a
result, including the back button, which opens Khipu's own abort dialog — but each path
left the Dart `Future` unresolved if it ever fired, and a payment that never answers is
the worst thing this plugin can do quietly.

The plugin now validates before it stores the pending result, answers from the
payload rather than the result code, treats a missing or malformed payload as an
explicit `NO_RESULT` instead of throwing inside the listener, and removes its
activity result listener on detach instead of accumulating one per rotation.

New `PlatformException` codes: `NO_ACTIVITY`, `OPERATION_IN_PROGRESS`,
`INVALID_OPTIONS`, `LAUNCH_FAILED`, `NO_RESULT`, `ACTIVITY_DETACHED`. They are
documented in the README, along with the fact that the two Khipu SDKs declare
location permissions that the manifest merger adds to your app.

On iOS, a second `startOperation` while Khipu is on screen is now rejected instead
of presenting Khipu on top of Khipu.

Nothing changes in the plugin's API.
```

- [ ] **Step 2: Subir la versión**

En `pubspec.yaml`, `version: 1.7.1` → `version: 1.7.2`.

- [ ] **Step 3: Verificación completa antes de publicar nada**

```bash
flutter analyze && flutter test
cd example/android && ./gradlew :flutter_khipu:test && cd ../..
cd example && flutter build apk --debug && cd ..
dart pub publish --dry-run
```

Esperado: todo verde, dry-run con 0 warnings y el tarball bien por debajo de 5 MB.

- [ ] **Step 4: Commit y PR**

```bash
git add CHANGELOG.md pubspec.yaml
git commit -m "chore: release 1.7.2"
git push
gh pr create --base 1.7.x --title "Harden the Android result path" --body "Implements blocks A and C of docs/superpowers/specs/2026-09-09-hardening-flutter-khipu-design.md"
```

**PARAR ACÁ.** La publicación a pub.dev y el merge los aprueba una persona. No correr `dart pub publish` sin confirmación explícita.

---

## Fase 2 — Rama `main`

### Task 10: Mergear `1.7.x` a `main`

- [ ] **Step 1: Mergear, no cherry-pick**

```bash
git checkout main && git pull
git merge origin/1.7.x
```

- [ ] **Step 2: Resolver los dos conflictos esperados**

`android/build.gradle` y `README.md` divergen entre las ramas (6 y 15 líneas respectivamente, verificado). En ambos: **quedarse con la versión de `main`** para lo que 1.8.0 cambió (Kotlin built-in, redacción del rango de versiones) y **agregar encima** lo que trae `1.7.x` (la sección de geolocalización, los códigos de error, la sección de cancelación). El `.kt` y el `.swift` son idénticos en las dos ramas y no deberían conflictuar.

- [ ] **Step 3: Verificar**

```bash
flutter analyze && flutter test
cd example/android && ./gradlew :flutter_khipu:test && cd ../..
```

- [ ] **Step 4: Commit del merge**

```bash
git add -A && git commit --no-edit
```

---

### Task 11: CI completo en `main`

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Ampliar el workflow**

```yaml
name: ci

on:
  push:
    branches: [main, 1.7.x]
  pull_request:
  schedule:
    - cron: '0 6 * * *'

jobs:
  dart:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.9'
          channel: stable
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - name: Publish dry run
        run: dart pub publish --dry-run
      - name: Tarball stays small
        # 1.7.0 shipped 87 MB of Dart compiler caches because a .pubignore
        # stopped the root .gitignore's build/ pattern from applying. It is
        # 98 KB today; 5 MB is room to grow and still catches that class of bug.
        run: |
          size=$(dart pub publish --dry-run 2>&1 \
            | grep -oE 'Total compressed archive size: [0-9.]+ [KMG]B' \
            | grep -oE '[0-9.]+ [KMG]B')
          echo "tarball: $size"
          case "$size" in
            *GB) echo "::error::tarball is $size, over the 5 MB cap"; exit 1 ;;
            *MB) n=${size% MB}; awk -v n="$n" 'BEGIN{exit !(n>5)}' \
                 && { echo "::error::tarball is $size, over the 5 MB cap"; exit 1; } ;;
          esac

  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.9'
          channel: stable
      - run: flutter pub get
        working-directory: example
      - run: flutter build apk --debug
        working-directory: example
      - name: Kotlin unit tests
        run: ./gradlew :flutter_khipu:test
        working-directory: example/android

  ios:
    if: github.event_name == 'schedule' || startsWith(github.ref, 'refs/tags/')
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.9'
          channel: stable
      - run: flutter pub get
        working-directory: example
      - name: Build with Swift Package Manager
        run: |
          flutter config --enable-swift-package-manager
          flutter build ios --no-codesign --debug
        working-directory: example
      - name: Build with CocoaPods
        run: |
          flutter config --no-enable-swift-package-manager
          flutter clean && flutter build ios --no-codesign --debug
        working-directory: example
```

En la rama `1.7.x`, el mismo archivo se queda **sólo con el job `dart`** y con `flutter-version: '3.41.0'`. No backportear `android` ni `ios`.

- [ ] **Step 2: Empujar y confirmar los tres jobs**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: build the example on Android per PR and on iOS nightly"
git push
gh run watch
```

Esperado: `dart` y `android` en verde; `ios` saltado (sólo corre en schedule y tags). Verificar el `ios` a mano una vez con `gh workflow run ci.yml` antes de confiar en él.

---

### Task 12: Higiene del build de Android

**Files:**
- Modify: `android/build.gradle`
- Modify: `android/src/main/AndroidManifest.xml`

- [ ] **Step 1: Limpiar `build.gradle`**

Borrar el bloque `buildscript { ... }` entero (fija AGP 7.3.0, obsoleto y en contradicción con lo que afirma el CHANGELOG de 1.8.0 sobre AGP 9), y el `allprojects { repositories { ... } }` (bajo `dependencyResolutionManagement` no hace nada). Subir el resto:

```groovy
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
```

Y el bloque `kotlin { compilerOptions { jvmTarget = ... JVM_11 } }`.

- [ ] **Step 2: Quitar el `package=` deprecado**

`android/src/main/AndroidManifest.xml` queda:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
</manifest>
```

El `namespace` de `build.gradle` es lo que manda desde AGP 8.

- [ ] **Step 3: Verificar**

```bash
cd example/android && ./gradlew :flutter_khipu:test && cd ../..
cd example && flutter build apk --debug && cd ..
```

Esperado: 20 tests en verde y APK construido. Si `compileSdk = 36` no está instalado, el build lo dice y hay que instalarlo con `sdkmanager "platforms;android-36"`.

- [ ] **Step 4: Commit**

```bash
git add android/build.gradle android/src/main/AndroidManifest.xml
git commit -m "build(android): drop the AGP 7.3.0 buildscript and move to Java 11"
```

---

### Task 13: Higiene del paquete y test de sincronía de versiones

**Files:**
- Modify: `ios/flutter_khipu.podspec`
- Modify: `pubspec.yaml`
- Modify: `analysis_options.yaml`
- Modify: `README.md`
- Create: `test/package_metadata_test.dart`

**Interfaces:**
- Produces: un test Dart que falla si las versiones se desincronizan.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/package_metadata_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El podspec y el Package.swift tienen que declarar la misma versión de
/// KhipuClientIOS, y el podspec la misma versión que el pubspec. Son tres
/// archivos que nadie compara, y el podspec se quedó en 0.0.1 durante ocho
/// releases sin que nada lo notara.
void main() {
  String read(String path) => File(path).readAsStringSync();

  String? firstMatch(String source, String pattern) =>
      RegExp(pattern).firstMatch(source)?.group(1);

  test('the podspec version matches the pubspec version', () {
    final String? pubspec =
        firstMatch(read('pubspec.yaml'), r"^version:\s*(\S+)");
    final String? podspec =
        firstMatch(read('ios/flutter_khipu.podspec'), r"s\.version\s*=\s*'([^']+)'");

    expect(pubspec, isNotNull, reason: 'could not read version from pubspec.yaml');
    expect(podspec, isNotNull, reason: 'could not read s.version from the podspec');
    expect(podspec, pubspec);
  });

  test('both iOS packaging files pin the same KhipuClientIOS', () {
    final String? fromPodspec = firstMatch(
        read('ios/flutter_khipu.podspec'), r"KhipuClientIOS',\s*'([^']+)'");
    final String? fromSwift = firstMatch(
        read('ios/flutter_khipu/Package.swift'), r'exact:\s*"([^"]+)"');

    expect(fromPodspec, isNotNull, reason: 'could not read the pod dependency');
    expect(fromSwift, isNotNull, reason: 'could not read the SPM dependency');
    expect(fromPodspec, fromSwift,
        reason: 'CocoaPods and SPM would install different Khipu clients');
  });
}
```

- [ ] **Step 2: Correr y verificar que falla**

```bash
flutter test test/package_metadata_test.dart
```

Esperado: el primer test falla — el podspec dice `0.0.1` y el pubspec `1.8.0`. El segundo pasa: ambos dicen `2.16.5`.

- [ ] **Step 3: Sincronizar el podspec**

En `ios/flutter_khipu.podspec`: `s.version = '0.0.1'` → `s.version = '1.8.1'`.

- [ ] **Step 4: Verificar verde**

```bash
flutter test
```

Esperado: 30 tests en verde.

- [ ] **Step 5: Metadata de pubspec y lints**

En `pubspec.yaml`, después de `homepage`:

```yaml
repository: "https://github.com/khipu/flutter_khipu"
issue_tracker: "https://github.com/khipu/flutter_khipu/issues"
topics: [payments, khipu, chile, fintech]
```

Y `flutter_lints: ^3.0.0` → `flutter_lints: ^6.0.0` en `dev_dependencies`.

En `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true

# `public_member_api_docs` se activa en el Ciclo 2, junto con los doc comments.
```

- [ ] **Step 6: Corregir el typo del README**

`android/build.gralde` → `android/build.gradle`.

- [ ] **Step 7: Verificar y arreglar lo que los lints nuevos levanten**

```bash
flutter pub get && flutter analyze && flutter test
```

Esperado: analyze limpio. `flutter_lints` 6 y `strict-casts` pueden levantar issues nuevos en `lib/` y `example/lib/`; arreglarlos acá, sin cambiar comportamiento ni firmas públicas. Si alguno exigiera un cambio rompedor, dejarlo para el Ciclo 2 y anotarlo con un `// ignore:` comentado con el motivo.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml analysis_options.yaml ios/flutter_khipu.podspec README.md test/package_metadata_test.dart lib example/lib
git commit -m "chore: sync the podspec version, modernise lints and pin metadata"
```

---

### Task 14: CHANGELOG y versión 1.8.1

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `pubspec.yaml`
- Modify: `ios/flutter_khipu.podspec`

- [ ] **Step 1: Entrada del CHANGELOG**

```markdown
# 1.8.1

Carries the 1.7.2 hardening of the Android result path onto the current line, and
adds what 1.7.x deliberately does not get: the repository now has CI. Every push
runs the analyzer, the Dart tests, the new Kotlin tests and a publish dry run with
a cap on the tarball size, and builds the example for Android. iOS builds nightly,
against both Swift Package Manager and CocoaPods.

The podspec had been claiming version 0.0.1 since it was first written. A test now
compares it against the pubspec, and compares the KhipuClientIOS pin between the
podspec and Package.swift, so the two iOS packaging paths cannot drift apart.

The Android build drops its AGP 7.3.0 buildscript block, which contradicted the AGP 9
support 1.8.0 was about, and moves to Java 11.

See the 1.7.2 entry for the behavioural changes. Nothing in the plugin's API changes.
```

- [ ] **Step 2: Subir versiones**

`pubspec.yaml`: `1.8.0` → `1.8.1`. El podspec ya quedó en `1.8.1` en la Task 13.

- [ ] **Step 3: Gate completo del spec §8**

```bash
flutter analyze && flutter test
cd example/android && ./gradlew :flutter_khipu:test && cd ../..
cd example && flutter build apk --debug && cd ..
cd example && flutter build ios --no-codesign --debug && cd ..
dart pub publish --dry-run
```

- [ ] **Step 4: Commit y PR**

```bash
git add CHANGELOG.md pubspec.yaml
git commit -m "chore: release 1.8.1"
git push
gh pr create --base main --title "Cycle 1: hardening, CI and documentation" --body "Implements docs/superpowers/specs/2026-09-09-hardening-flutter-khipu-design.md"
```

**PARAR ACÁ.** Quedan pendientes, para una persona: el merge de los dos PRs, `dart pub publish` en cada rama, la prueba manual en dispositivo de las tres vías de cancelación (spec §8 ítems 4 y 7), y el ticket upstream de spec §6.

---

## Qué queda fuera de este plan

Todo el Ciclo 2: Pigeon, enums, `lib/src/`, nulabilidad ajustada, doc comments, y el borrado de `method_channel_seam_test.dart`. Tiene su propio spec y su propio plan, y arranca con el spike bloqueante de spec §7.1.
