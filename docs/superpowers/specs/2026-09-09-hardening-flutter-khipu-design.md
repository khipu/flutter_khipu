# Endurecimiento, CI y API 2.0.0 de `flutter_khipu` — Diseño

Fecha: 2026-09-09
Estado: aprobado
Alcance: dos ciclos independientes de spec → plan → implementación

---

## 1. Objetivo

Cerrar seis defectos del camino de resultado de Android, poner integración
continua por primera vez en el repositorio, documentar el tratamiento de
geolocalización que el SDK inyecta en la app del comercio, y —en un segundo
ciclo separado— rediseñar la API pública sobre Pigeon.

### Por qué importa

El plugin no tiene CI. Los 28 tests que existen no los corre nadie, y las dos
últimas versiones se rompieron por cosas que ningún test unitario ve: 1.7.0 metió
87 MB de caché del compilador en el tarball por una trampa del `.pubignore`, y
1.8.0 fue enteramente un problema de Gradle/Kotlin.

Los defectos de Android son latentes, no urgentes (ver §2). Pero comparten una
forma: dejan el `Future` de Dart sin completar. En un plugin de pagos eso es lo
peor que puede pasar en silencio — el comercio no sabe si cobró.

---

## 2. Estado actual (verificado)

### 2.1 Corrección del registro

Una versión anterior de esta revisión afirmó que el back del sistema en Android
colgaba el `Future` porque el SDK no interceptaba el back. **Es falso.** El error
vino de un `grep -rl "BackHandler"` sin la bandera `-a`: el grep de BSD no matchea
dentro de `.class` binarios sin ella y devuelve cero **en silencio**, de modo que
la ausencia de evidencia se leyó como evidencia de ausencia.

La contradicción la levantó una sesión paralela que trabajaba sobre el puente de
React Native, leyendo la fuente en `khipu-client-android` tag 2.27.0. Se verificó
de forma independiente sobre el AAR compilado de la misma versión.

Queda como regla de método para este repositorio: **al auditar binarios, `grep -a`
siempre, y validar el extractor con un patrón de control que se sepa presente.**
Es la misma disciplina que ya aplica `test/method_channel_seam_test.dart` en su
grupo "the extractors actually found something".

### 2.2 Matriz de salidas de `KhipuActivity` (AAR 2.27.0)

Las cuatro salidas llevan payload. **No existe un cuelgue reproducible hoy.**

| Salida | `resultCode` | `data` | Evidencia |
|---|---|---|---|
| Pago termina | `RESULT_OK` | sí | `KhipuActivityKt` off. 2324 `setResult(-1, intent)` |
| Back del sistema → modal → confirmar | `RESULT_OK` | sí | `KhipuActivityKt` off. 1732 `BackHandlerKt.BackHandler(...)`, cadenas `modal.abortOperation.*` |
| Botón cerrar → mismo modal | `RESULT_OK` | sí | ídem, vía `KhipuViewModel.returnToApp()` |
| Restauración >180 s tras muerte de proceso | `RESULT_CANCELED` | sí | `KhipuActivity.onCreate` off. 176-184 |

El cuarto caso construye, literalmente:

    KhipuResult(operationId = cleanString(extra), exitTitle = "", exitMessage = "",
                exitUrl = "", continueUrl = null, result = "ERROR",
                events = emptyArray(), failureReason = cleanString("USER_CANCELED"))

De ahí sale el vocabulario de cancelación del SDK: `result = "ERROR"` con
`failureReason = "USER_CANCELED"`, y los textos de salida vacíos, no inventados.

### 2.3 Nulabilidad real de `KhipuResult`

Ambos SDK coinciden exactamente. Prueba en iOS por declaración
(`KhipuResult.swift:4-11`); en Android por el sistema de tipos: el plugin asigna
esos campos a un `HashMap<String, Any>`, lo que no compilaría si fueran `String?`.

- **No nulos:** `operationId`, `exitTitle`, `exitMessage`, `result`, `events`
- **Nulos:** `exitUrl`, `failureReason`, `continueUrl`

El `String?` de todos los campos en Dart es más ancho que la realidad. Se ensanchó
en 1.7.1 para arreglar un crash real, pero de más. Consecuencia: el test
`flutter_khipu_method_channel_test.dart:337` cubre un caso imposible.

### 2.4 Los seis defectos

Todos en `android/src/main/kotlin/com/khipu/flutter_khipu/FlutterKhipuPlugin.kt`.

1. **`activity == null` → no-op silencioso** (líneas 137-145). `pendingResult` ya
   quedó asignado en la 43 y nadie lo responde. Alcanzable: plugin adjunto al
   engine pero no a una activity. iOS cubre el simétrico con `NO_VIEW_CONTROLLER`.
2. **`pendingResult` asignado antes de validar** (línea 43). El early-return de
   `MISSING_OPERATION_ID` responde pero deja el campo apuntando a un `Result` ya
   respondido.
3. **`as KhipuResult` sin chequear** (línea 157). Si el extra falta o cambia de
   clase, la excepción escapa del listener sin llamar `success` ni `error`.
   Además `getSerializableExtra` está deprecado desde API 33.
4. **`pendingResult` nunca se limpia** tras responder (línea 174), y una segunda
   llamada pisa la primera.
5. **El listener nunca se remueve.** `onAttachedToActivity` y
   `onReattachedToActivityForConfigChanges` llaman `addActivityResultListener`;
   ningún `onDetached*` llama el inverso. Se duplica en cada cambio de configuración.
6. **`if (data != null)` sin `else`** (línea 156). Sin gatillo conocido hoy, pero
   si aparece uno, cuelga.

### 2.5 Geolocalización inyectada en la app del comercio

El `AndroidManifest.xml` del AAR declara `INTERNET`, `ACCESS_FINE_LOCATION` y
`ACCESS_COARSE_LOCATION`, más la propia `KhipuActivity`, y el merge de manifiestos
lo inyecta todo en cualquier app que instale el plugin. `INTERNET` es trivial; las
dos de ubicación no. El uso es real: `com/khipu/client/ui/views/GeolocationWarningViewKt`
usa `FusedLocationProviderClient` y `LocationServices`.

No es recolección silenciosa: hay una pantalla de advertencia, un `PermissionChecker`
y un `ManagedActivityResultLauncher`, o sea **consentimiento en runtime**. Es el paso
que exigen algunos bancos para autorizar transferencias.

Consecuencias que el README no menciona hoy:

- El comercio debe declarar ubicación en Play Data Safety igual, aunque el permiso
  se pida en runtime dentro de la UI de Khipu.
- Al usuario le aparece un diálogo de ubicación que parece del comercio.
- Bajo Ley 21.719 es dato personal tratado durante el pago y debe estar en el aviso
  de privacidad del comercio.

**No se deben remover con `tools:node="remove"`:** rompería la autorización en los
bancos que la exigen.

---

## 3. Decisiones confirmadas

| # | Decisión | Alternativa descartada |
|---|---|---|
| D1 | Dos ciclos: **A+B+C** (no rompe API) y luego **D+E** (2.0.0) | Un solo spec hasta 2.0.0; A suelto como hotfix |
| D2 | A+C a `1.7.x` → **release 1.7.2**; todo a `main` → **1.8.1**; B sólo en `main`; CI en ambas ramas | CI sólo en `main`; congelar `1.7.x` |
| D3 | El arreglo va **en el plugin** como refuerzo, y se abre ticket upstream | Esperar release del SDK Android |
| D4 | CI: en PR ubuntu (analyze, test, dry-run + tope de tarball, build apk); iOS en macOS nocturno y en tags | Sólo tests; todo en cada PR |
| D5 | **Pigeon** para el Ciclo 2, con los tipos generados **envueltos** en `lib/src/` | MethodChannel a mano; Pigeon a medias |

Sobre D3: el arreglo es un fallback idempotente. Si el SDK cambia, `data` deja de
ser nulo y el camino nuevo simplemente no se ejecuta. No hay conflicto posible.

---

## 4. Ciclo 1 — A: camino de resultado en Android

### 4.1 Principio rector

Una operación en vuelo se responde **exactamente una vez**, y quien decide es el
payload, **nunca el `resultCode`**. Ramificar por `resultCode` haría que el mismo
desenlace para el comercio —el usuario abandonó— llegara de dos formas distintas
según si Android mató la activity y pasaron más de tres minutos.

Corolario, y la mitad del arreglo: **el callback se guarda lo más tarde posible, y
todo lo que pueda lanzar va antes, o dentro de un `try` que lo libere.**

### 4.2 Por qué el orden no es cosmético

La guarda `OPERATION_IN_PROGRESS` es una **regresión** si se agrega sin reordenar:
convierte un callback colgado en un plugin muerto para el resto de la sesión, porque
toda llamada posterior rechaza. Hoy, sin guarda, el defecto 2 ya deja el campo sucio
con una sola llamada de `operationId` ausente. Agregar la guarda sobre ese código
haría que esa única llamada malformada matara el plugin.

Esto lo levantó la sesión de React Native, que pagó el mismo problema en su puente.

### 4.3 Forma objetivo

    private fun startOperation(call: MethodCall, result: Result) {
        val activity = this.activity
            ?: return result.error("NO_ACTIVITY", "…", null)
        if (pendingResult != null)
            return result.error("OPERATION_IN_PROGRESS", "…", null)
        val operationId = call.argument<String>("operationId")
            ?: return result.error("MISSING_OPERATION_ID", "…", null)

        val intent = try {
            getKhipuLauncherIntent(activity.baseContext, operationId, buildOptions(call))
        } catch (e: Exception) {
            return result.error("INVALID_OPTIONS", e.message, null)
        }

        pendingResult = result
        try {
            activity.startActivityForResult(intent, KHIPU_START_OPERATION_CODE)
        } catch (e: Exception) {
            pendingResult = null
            result.error("LAUNCH_FAILED", e.message, null)
        }
    }

Cambios estructurales que esto arrastra:

- `buildOptions(call)` sale a su propia función. Resuelve de paso que
  `startOperation` tenga ~100 líneas de mapeo.
- Un helper `respondOnce(...)` que lee `pendingResult`, lo anula y responde. Todo
  camino de salida pasa por ahí; es lo que hace imposible el doble-`success`.
- `onActivityResult`: `runCatching` alrededor, `data?.extras?.getSerializable(...) as?
  KhipuResult`, sobrecarga tipada en API 33+. Con resultado → `success`; sin
  resultado → `error("NO_RESULT")`.
- Guardar el `ActivityPluginBinding`; `removeActivityResultListener` en ambos
  `onDetached*`; si hay operación en vuelo al desprenderse → `error("ACTIVITY_DETACHED")`.
- `startOperation` pasa a privado; `KHIPU_START_OPERATION_CODE` a `const val` en
  un `companion object`.

### 4.4 Códigos de error resultantes

| Código | Android | iOS | Cuándo |
|---|---|---|---|
| `MISSING_OPERATION_ID` | sí | ya existe | falta el `operationId` |
| `NO_ACTIVITY` | **nuevo** | — | no hay activity adjunta |
| `NO_VIEW_CONTROLLER` | — | ya existe | simétrico de iOS |
| `BAD_ARGUMENT_DICTIONARY` | — | ya existe | argumentos no son diccionario |
| `OPERATION_IN_PROGRESS` | **nuevo** | **nuevo** | ya hay una operación en vuelo |
| `INVALID_OPTIONS` | **nuevo** | — | el mapeo de opciones lanzó |
| `LAUNCH_FAILED` | **nuevo** | — | no se pudo lanzar la activity |
| `NO_RESULT` | **nuevo** | — | volvió sin payload |
| `ACTIVITY_DETACHED` | **nuevo** | — | la activity se fue con una operación en vuelo |

La asimetría restante es inherente a las plataformas y queda documentada en §6.

### 4.5 Tests

`android/src/test/kotlin/` **no existe** hoy, pese a que `build.gradle:42-43` ya
declara mockito y kotlin-test. Se crea ahora. Cada defecto de §2.4 es un test que
hoy falla — TDD literal.

El test más importante es el que no estaba en el diagnóstico inicial:
**tras un `LAUNCH_FAILED`, la llamada siguiente funciona.** Es el que demuestra que
la guarda no se convirtió en una trampa.

### 4.6 El único cambio de iOS en este ciclo

`OPERATION_IN_PROGRESS` se agrega también en iOS, por simetría de códigos de error
(§6 documenta la tabla como contrato cruzado, y una asimetría evitable ahí obliga al
comercio a ramificar por plataforma para el mismo desenlace).

Hace falta por su cuenta, además: `presenter()` camina hasta el controlador presentado
más alto, así que una segunda llamada con Khipu ya en pantalla presentaría Khipu
**encima de Khipu**. Dos pagos apilados sobre la misma operación.

Es el único cambio de iOS del Ciclo 1. No hay simétrico de los otros cinco defectos:
`KhipuLauncher.launch` entrega siempre por un solo callback, y el closure de cada
llamada es propio, así que no existe estado compartido que ensuciar.

---

## 5. Ciclo 1 — B: CI e higiene (sólo `main`, salvo el workflow)

### 5.1 Workflow

    PR (ubuntu-latest)
      flutter analyze
      flutter test
      dart pub publish --dry-run   + assert del tamaño del tarball
      flutter build apk            (example)

    nightly + tags (macos-latest)
      flutter build ios --no-codesign   (SPM)
      flutter build ios                 (CocoaPods)

El mismo archivo se copia a `1.7.x` fijando Flutter 3.41 en vez de 3.44.

Dos cosas a verificar **antes** de escribirlo, o el CI nace rojo:

- Que el Nexus de Khipu (`dev.khipu.com/nexus/content/repositories/khenshin`) sea
  accesible sin credenciales desde un runner. El README lo pide sin auth, pero eso
  no está confirmado desde fuera de la red de Khipu.
- El tope de tamaño del tarball, calibrado sobre el valor real de hoy y no sobre
  una cifra inventada.

### 5.2 Higiene

- `s.version` del podspec (hoy `0.0.1`) sincronizada con `pubspec.yaml`, más un test
  que compare eso y la versión de `KhipuClientIOS` entre `flutter_khipu.podspec:17`
  y `Package.swift:16`. Son dos lugares que deben decir `2.16.5` y nada lo comprueba.
- `flutter_lints` `^3.0.0` → `^6.x`, y `strict-casts` en `analysis_options.yaml`.
  `public_member_api_docs` se deja fuera del Ciclo 1: gatilla el trabajo de docs del
  Ciclo 2 y pondría el analyzer en rojo desde el primer commit.
- `android/build.gradle`: quitar el bloque `buildscript` con AGP 7.3.0 (obsoleto y en
  contradicción con lo que afirma el CHANGELOG de 1.8.0), subir `compileSdk`, Java 11.
- `AndroidManifest.xml`: quitar el atributo `package=`, deprecado desde AGP 8.
- `pubspec.yaml`: agregar `repository`, `issue_tracker`, `topics`.
- README: typo "android/build.gralde".

---

## 6. Ciclo 1 — C: documentación

- **Sección nueva de geolocalización** con lo de §2.5: qué inyecta el merge, que el
  diálogo lo pide Khipu en runtime dentro de su propia UI, Play Data Safety, Ley
  21.719, y que no se deben remover.
- **Códigos de `PlatformException`** de ambas plataformas, con la tabla de §4.4.
- **Semántica de cancelación:** el abandono llega como `result: "ERROR"` con
  `failureReason: "USER_CANCELED"` y textos de salida vacíos, por cualquiera de las
  tres vías (back, botón cerrar, restauración tardía).

### Ticket upstream

A `khipu-client-android`, sin bloquear este ciclo:

1. Qué bancos gatillan el paso de geolocalización, para poder documentarlo con
   precisión en vez de en general.
2. Que la matriz de salidas de §2.2 pase a ser contrato documentado. Hoy se conoce
   sólo por lectura de bytecode, y el refuerzo del plugin depende de que se mantenga.

---

## 7. Ciclo 2 — D+E: Pigeon y API 2.0.0

D y E son **un solo paso**. El esquema de Pigeon *es* el rediseño de tipos; hacerlos
por separado significa escribir los tipos dos veces.

### 7.1 Spike previo, bloqueante

Verificar que el Swift generado por Pigeon funcione con **SPM y CocoaPods a la vez**.
El plugin soporta ambos empaquetados desde 1.7.0 y no puede dejar de hacerlo. Si esto
no cierra, se cae E y hay que replantear el ciclo.

### 7.2 Alcance

- `pigeons/khipu_api.dart` con `KhipuColors` **anidado de verdad** (hoy viaja aplanado
  en 12 claves de primer nivel), `enum KhipuTheme`, `enum KhipuResultStatus` con caso
  `unknown` para no romper ante valores nuevos del servidor.
- Nulabilidad ajustada a §2.3.
- Los tipos generados van a `lib/src/` con **wrappers finos escritos a mano** encima
  (D5). Desacopla la API publicada del estilo de codegen de Pigeon: regenerar no puede
  cambiar la API pública. Cuesta más código y es deliberado.
- `lib/flutter_khipu.dart` pasa a ser el único barrel. Hoy los tres archivos de `lib/`
  son API pública, así que cualquier refactor interno es *breaking*.
- Doc comments en toda la API pública. El contenido ya existe en el README; es mudanza,
  no redacción desde cero.
- `List<KhipuEvent>` en vez de `Iterable` (hoy es el `.map` perezoso de
  `flutter_khipu.dart:105`, que se re-parsea en cada iteración), `const []` en vez de
  `null`, `final` en todos los campos, constructores `const`, `==`/`hashCode`/`toString`.

### 7.3 Qué se borra

- `test/method_channel_seam_test.dart` completo. Su comentario de cabecera diagnostica
  bien el problema, pero Pigeon lo elimina por construcción en vez de detectarlo con
  regex. Un test que sólo puede romperse por reformateo del código que vigila deja de
  pagar su costo cuando la deriva ya no es posible.
- El test del caso imposible en `flutter_khipu_method_channel_test.dart:337`.

### 7.4 Migración

Guía 1.x → 2.0 en README y CHANGELOG. Los cambios rompedores son: `theme` pasa de
`String` a enum, `result` pasa de `String?` a enum, cinco campos de `KhipuResult` dejan
de ser nulos, `events` pasa de `Iterable?` a `List`, y los campos dejan de ser mutables.

---

## 8. Gate de validación

Ningún ciclo se da por cerrado sin esto.

**Ciclo 1:**

1. `flutter analyze` sin issues y `flutter test` en verde, en ambas ramas.
2. Los tests de Kotlin nuevos: cada defecto de §2.4 tiene uno, y falla si se revierte
   el arreglo.
3. El test de recuperación tras `LAUNCH_FAILED` pasa.
4. El guard de §4.6 verificado en iOS: con Khipu en pantalla, una segunda llamada
   devuelve `OPERATION_IN_PROGRESS` en vez de apilar un segundo Khipu encima.
5. `dart pub publish --dry-run` limpio, con el tarball bajo el tope.
6. Build del example en Android, y en iOS con SPM y con CocoaPods.
7. Prueba manual en dispositivo de las tres vías de cancelación, contra un
   `operationId` de demo, verificando que llega `USER_CANCELED` y no un cuelgue.
8. A+C mergeadas a `main` desde `1.7.x`, no reescritas a mano en las dos ramas.
9. 1.7.2 y 1.8.1 publicadas y verificadas desde cero contra la doc pública.

**Ciclo 2:** todo lo anterior, más el spike de §7.1 cerrado en verde antes de empezar.

---

## 9. Riesgos

| Riesgo | Mitigación |
|---|---|
| El Nexus de Khipu no es accesible desde un runner de GitHub | Verificar antes de escribir el workflow; si falla, el build de Android queda fuera del CI y se documenta |
| Pigeon no convive con SPM + CocoaPods | Spike bloqueante en §7.1; si falla, se cae E |
| El refuerzo de Android tapa un bug real del SDK en vez de exponerlo | El ticket upstream de §6 va igual; el fallback no reemplaza el arreglo de origen |
| La matriz de §2.2 cambia en una versión futura del SDK | Es exactamente lo que pide el punto 2 del ticket upstream |
| 1.7.2 se publica con cambios que nadie pidió | El alcance de `1.7.x` es sólo A+C; B no entra |

---

## 10. Fuera de alcance

- Remover los permisos de ubicación del manifest fusionado (§2.5).
- Cambiar el comportamiento del SDK Android o iOS.
- Una API de cancelación programática desde Dart.
- Tests de integración con `integration_test`, pese a estar declarado en el
  `dev_dependencies` del example.
- Cualquier refactor de iOS más allá del guard de concurrencia de §4.6 y de lo que
  exija Pigeon en el Ciclo 2.

---

## 11. Referencias

- `android/src/main/kotlin/com/khipu/flutter_khipu/FlutterKhipuPlugin.kt`
- `ios/flutter_khipu/Sources/flutter_khipu/FlutterKhipuPlugin.swift`
- `test/method_channel_seam_test.dart` — el seam test que Pigeon deja obsoleto
- `docs/superpowers/specs/2026-09-04-spm-flutter-khipu-design.md` — migración a SPM
- AAR `com.khipu:khipu-client-android:2.27.0`, caché de Gradle
- Checkout SPM de `KhipuClientIOS` 2.16.5 en `ios/flutter_khipu/.build/checkouts/`
