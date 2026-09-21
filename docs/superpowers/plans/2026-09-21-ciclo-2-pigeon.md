# Ciclo 2 — Pigeon y API 2.0.0: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el `MethodChannel` escrito a mano por un contrato generado con Pigeon, y publicar sobre él una API pública 2.0.0 con enums, nulabilidad real y tipos inmutables.

**Architecture:** Un esquema en `pigeons/khipu_api.dart` genera el canal para los tres lados (Dart, Kotlin, Swift). Los tipos generados viven en `lib/src/` y **no** son la API pública: encima van wrappers finos escritos a mano, para que regenerar no pueda cambiar lo que el comercio importa. `lib/flutter_khipu.dart` pasa a ser el único barrel. La capa `plugin_platform_interface` se elimina: Pigeon ya provee el seam entre Dart y cada plataforma, y este plugin no es federado.

**Tech Stack:** Dart / Flutter 3.44.9, Pigeon 29.0.2, Kotlin (`khipu-client-android` 2.28.5), Swift (`KhipuClientIOS` 2.17.1), Xcode 27.

**Spec:** `docs/superpowers/specs/2026-09-09-hardening-flutter-khipu-design.md` §7 (con §2.3 para la nulabilidad y §8 para el gate). El spike bloqueante de §7.1 cerró en verde el 2026-09-21.

---

## Global Constraints

- **Versión del paquete: `2.0.0`.** Es un major: la API pública cambia de forma rompedora. Sólo toca `main`; la línea `1.7.x` no recibe este ciclo.
- **Pigeon fijo en `29.0.2`**, exacto y no `^`. Es la versión con la que se midió el spike; el nombre de los casos de enum generados y la forma del código cambian entre versiones.
- **Pines nativos, sin mover:** `com.khipu:khipu-client-android:2.28.5` y `KhipuClientIOS 2.17.1`. Este ciclo no los toca.
- **Piso de Flutter, sin mover:** `sdk: ^3.12.0`, `flutter: '>=3.44.0'`.
- **El checkout tiene que llamarse `flutter_khipu`** o el build por SPM no arranca (§7.5). Vale para worktrees y para clones con otro nombre de carpeta. El error no menciona carpetas: `unable to override package 'flutter_khipu' because its identity '<carpeta>' doesn't match override's identity (directory name) 'flutter_khipu'`.
- **Los dos empaquetados de iOS siguen vivos**: SPM y CocoaPods. Ninguna tarea puede cerrar dejando uno roto.
- **Nunca `flutter build … | tail`**: devuelve el exit code de `tail`, y un build fallado se ve como éxito. Mismo defecto que se corrigió en el CI en `bc42eae`.
- **Los archivos `*.g.dart`, `Messages.g.kt` y `Messages.g.swift` no se editan a mano.** Se regeneran desde el esquema.
- **Marca Khipu** en cualquier ejemplo con colores: púrpura `#8347AD`, cian `#3CB4E5`.
- **Todo el código y la documentación van en inglés**: comentarios, doc comments (`///`), nombres y `reason:` de los tests, README, CHANGELOG y mensajes de commit. El repo viene mezclado —los nombres de test están en inglés pero varios comentarios del Ciclo 1 quedaron en español—, y este ciclo no propaga esa deriva. Los comentarios preexistentes en español **que caigan dentro de un bloque que este ciclo reescribe** se traducen junto con el bloque: dejar medio archivo en cada idioma es peor que traducir. Lo que el ciclo no toca se deja como está; traducir el repo entero no es parte de este trabajo.

  Traducir es conservar el contenido y el nivel de detalle, no resumir. Estos comentarios explican **por qué** el código es como es —qué se rompe si se mueve una línea, qué se midió, qué error confuso da si falla—, y esa carga es lo que tiene que sobrevivir.

### Valores medidos que el plan da por fijos

Verificados el 2026-09-21 sobre el AAR `khipu-client-android:2.28.5` (bytecode de `KhipuActivityKt`, offsets 81→557):

- **`result` tiene exactamente cinco valores:** `OK`, `ERROR`, `WARNING`, `CONTINUE`, `USER_CANCELED`.
- **`KhipuResult` — no nulos:** `operationId`, `exitTitle`, `exitMessage`, `result`, `events`. **Nulos:** `exitUrl`, `failureReason`, `continueUrl` (§2.3).
- **`KhipuEvent` — los tres campos son no nulos:** `name`, `type`, `timestamp`. Medido por las tres llamadas a `Intrinsics.checkNotNullParameter` en su constructor y la ausencia de `@Nullable`. Esto es **nuevo respecto de §2.3**, que sólo cubría `KhipuResult`, y significa que el test `survives an event with null fields` también cubre un caso imposible.

### El circuito queda abierto entre la Tarea 2 y la Tarea 4

Cambiar el protocolo del canal es atómico entre los tres lados: no hay forma de que Dart hable Pigeon mientras el nativo sigue hablando `MethodChannel`. Después de la Tarea 2 los tests de Dart pasan pero **el example no corre en ningún dispositivo** hasta que cierra la Tarea 4. Es esperado, no un defecto de la implementación. El gate de punta a punta es el de la Tarea 4; el de cada tarea intermedia son sus propios tests.

El CI de Android (`flutter build apk`) va a fallar en las Tareas 2 y 3. No lo arregles bajando el alcance: se cierra solo en la Tarea 4.

---

## File Structure

**Se crea:**

| Archivo | Responsabilidad |
|---|---|
| `pigeons/khipu_api.dart` | El esquema. Única fuente de la forma del canal y de los enums. |
| `lib/src/messages.g.dart` | Generado. Tipos y `KhipuHostApi` del lado Dart. No se edita. |
| `lib/src/khipu_options.dart` | `KhipuColors` y `KhipuStartOperationOptions` públicos, inmutables, con conversión hacia el generado. |
| `lib/src/khipu_result.dart` | `KhipuResult` y `KhipuEvent` públicos, inmutables, con conversión desde el generado. |
| `lib/src/flutter_khipu.dart` | La clase `FlutterKhipu`: la única puerta de entrada. |
| `android/src/main/kotlin/com/khipu/flutter_khipu/Messages.g.kt` | Generado. No se edita. |
| `ios/flutter_khipu/Sources/flutter_khipu/Messages.g.swift` | Generado. No se edita. |
| `test/pigeon_schema_test.dart` | Fija el contrato del esquema: nulabilidad de los tres opcionales y el caso `unknown`. |

**Se modifica:**

| Archivo | Cambio |
|---|---|
| `lib/flutter_khipu.dart` | Pasa de contener todos los tipos a ser el único barrel. |
| `pubspec.yaml` | `version: 2.0.0`; `pigeon: 29.0.2` en dev_dependencies; **fuera** `plugin_platform_interface`. |
| `android/…/FlutterKhipuPlugin.kt` | De `MethodCallHandler` a implementar `KhipuHostApi`. |
| `ios/…/FlutterKhipuPlugin.swift` | De `FlutterPlugin` con `handle(_:result:)` a implementar `KhipuHostApi`, con los tipos del SDK calificados por módulo. |
| `ios/flutter_khipu/Package.swift` | Declara `FlutterFramework`; sube la plataforma a iOS 15. |
| `ios/flutter_khipu.podspec` | `s.version = '2.0.0'`; `s.platform = :ios, '15.0'`. |
| `example/ios/Podfile` | Fuerza `IPHONEOS_DEPLOYMENT_TARGET = 15.0` en el `post_install`. |
| `example/ios/Runner.xcodeproj/project.pbxproj` | Deployment target a 15.0. |
| `example/lib/*.dart` | Se adapta a la API 2.0.0 (enums en vez de strings). |
| `.github/workflows/ci.yml` | Job que verifica que el generado está al día. |
| `test/flutter_khipu_method_channel_test.dart` | Se reescribe contra el `KhipuHostApi` generado. |
| `test/flutter_khipu_test.dart` | Deja de afirmar sobre la platform interface. |
| `README.md`, `CHANGELOG.md` | Guía de migración 1.x → 2.0. |

**Se borra:**

| Archivo | Por qué |
|---|---|
| `lib/flutter_khipu_platform_interface.dart` | Pigeon es el seam; el plugin no es federado. |
| `lib/flutter_khipu_method_channel.dart` | Lo reemplaza el `KhipuHostApi` generado. |
| `test/method_channel_seam_test.dart` | Vigilaba con regex una deriva de claves que Pigeon hace imposible por construcción (§7.3). Un test que sólo puede romperse por reformatear el código que vigila deja de pagar su costo. |

---

## Task 1: El esquema de Pigeon y la generación

**Files:**
- Create: `pigeons/khipu_api.dart`
- Create: `test/pigeon_schema_test.dart`
- Modify: `pubspec.yaml` (dev_dependencies)
- Modify: `.github/workflows/ci.yml:26` (después de `flutter analyze`)
- Generated (no editar): `lib/src/messages.g.dart`, `android/src/main/kotlin/com/khipu/flutter_khipu/Messages.g.kt`, `ios/flutter_khipu/Sources/flutter_khipu/Messages.g.swift`

**Interfaces:**
- Consumes: nada.
- Produces: el esquema y los tres generados. Las tareas 2, 3 y 4 consumen de ahí:
  - Dart: `KhipuHostApi.startOperation(KhipuStartOperationOptions) → Future<KhipuResult?>`
  - Enums: `KhipuTheme { light, dark, system }`, `KhipuResultStatus { ok, error, warning, mustContinue, userCanceled, unknown }`
  - Clases: `KhipuColors`, `KhipuStartOperationOptions`, `KhipuEvent`, `KhipuResult`

- [ ] **Step 1: Escribir el esquema**

Crear `pigeons/khipu_api.dart`:

```dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'flutter_khipu',
    kotlinOut:
        'android/src/main/kotlin/com/khipu/flutter_khipu/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.khipu.flutter_khipu'),
    swiftOut: 'ios/flutter_khipu/Sources/flutter_khipu/Messages.g.swift',
  ),
)
/// Theme with which Khipu presents itself.
enum KhipuTheme { light, dark, system }

/// Outcome of the operation.
///
/// The SDK delivers it as free text. The first five cases are the ones
/// `khipu-client-android` 2.28.5 can emit, measured on its bytecode;
/// [unknown] exists so that a new value from the server does not break the
/// channel. Without it, an unrecognized value would make the entire message
/// decoding fail and the payment would reach the merchant as a platform
/// error.
enum KhipuResultStatus {
  ok,
  error,
  warning,
  /// The SDK emits this as `CONTINUE`. It is named differently because
  /// `continue` is a reserved word in Dart, in Kotlin, and in Swift.
  mustContinue,
  userCanceled,
  unknown,
}

/// Palette Khipu is painted with. A null color leaves the SDK's own.
class KhipuColors {
  String? lightBackground;
  String? lightOnBackground;
  String? lightPrimary;
  String? lightOnPrimary;
  String? lightTopBarContainer;
  String? lightOnTopBarContainer;
  String? darkBackground;
  String? darkOnBackground;
  String? darkPrimary;
  String? darkOnPrimary;
  String? darkTopBarContainer;
  String? darkOnTopBarContainer;
}

class KhipuStartOperationOptions {
  late String operationId;
  String? locale;
  String? title;
  String? titleImageUrl;
  bool? skipExitPage;
  bool? skipExitSuccessPage;
  bool? showFooter;
  bool? showMerchantLogo;
  bool? showPaymentDetails;
  KhipuTheme? theme;
  KhipuColors? colors;
}

/// All three fields are non-null: measured on the 2.28.5 AAR, the
/// constructor of `com.khipu.client.KhipuEvent` runs `checkNotNullParameter`
/// on all three.
class KhipuEvent {
  late String name;
  late String type;
  late String timestamp;
}

/// Nullability per §2.3 of the design doc: the three optionals are exactly
/// the ones the Android SDK declares `@Nullable`.
class KhipuResult {
  late String operationId;
  late KhipuResultStatus result;
  late String exitTitle;
  late String exitMessage;
  late List<KhipuEvent> events;
  String? exitUrl;
  String? failureReason;
  String? continueUrl;
}

@HostApi()
abstract class KhipuHostApi {
  @async
  KhipuResult? startOperation(KhipuStartOperationOptions options);
}
```

- [ ] **Step 2: Escribir el test del contrato, que todavía falla**

Crear `test/pigeon_schema_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Pigeon schema is the single source of the channel's shape, and it has
/// two properties that no behavior test can defend.
///
/// The first is the empty-value encoding that PR #18 pinned down. Pigeon
/// serializes a positional list, not a map, so there is no key to omit: the
/// requirement holds by construction as long as the three fields are
/// nullable. The only thing that could break it is someone making them
/// required in the schema, and that is what this test watches.
///
/// The second is the `unknown` case of KhipuResultStatus. Removing it does
/// not break any test: it breaks in production, the day the server emits a
/// new value.
void main() {
  final String schema = File('pigeons/khipu_api.dart').readAsStringSync();

  test('the three optional fields of KhipuResult stay nullable', () {
    for (final String field in <String>[
      'exitUrl',
      'failureReason',
      'continueUrl',
    ]) {
      expect(
        schema,
        contains('String? $field;'),
        reason: 'PR #18 fixed that the three optionals always travel. With '
            'Pigeon that holds as long as they are nullable: $field stopped '
            'being so.',
      );
    }
  });

  test('KhipuResultStatus keeps the unknown case', () {
    expect(schema, contains('enum KhipuResultStatus'));
    expect(
      schema,
      contains('unknown,'),
      reason: 'Without unknown, a new value from the server breaks the '
          'decoding of the whole message.',
    );
  });

  test('the five values the SDK can emit are covered', () {
    // Measured on the bytecode of KhipuActivityKt in khipu-client-android
    // 2.28.5: OK, ERROR, WARNING, CONTINUE, USER_CANCELED. `mustContinue`
    // is CONTINUE renamed, because `continue` is reserved in the three
    // languages Pigeon generates for.
    for (final String c in <String>[
      'ok,',
      'error,',
      'warning,',
      'mustContinue,',
      'userCanceled,',
    ]) {
      expect(schema, contains(c));
    }
  });
}
```

- [ ] **Step 3: Correr el test y verificar que falla**

Run: `flutter test test/pigeon_schema_test.dart`
Expected: FAIL — `PathNotFoundException` sobre `pigeons/khipu_api.dart` si el Step 1 no se guardó. Si el Step 1 sí se guardó, este test **pasa de entrada**; eso es correcto y esperado, porque su objeto es el esquema y no el generado. Confirmalo invirtiendo una línea del esquema a mano (poner `late String exitUrl;`), corriendo el test para verlo fallar, y devolviéndola.

- [ ] **Step 4: Agregar Pigeon y generar**

En `pubspec.yaml`, dentro de `dev_dependencies`, después de `flutter_lints: ^6.0.0`:

```yaml
  # Exact, not ^: the name of the enum cases it generates and the shape of
  # the code change between versions, and 29.0.2 is what the §7.1 spike
  # measured against both iOS packaging paths.
  pigeon: 29.0.2
```

Run:
```bash
flutter pub get
dart run pigeon --input pigeons/khipu_api.dart
```

Expected: crea los tres archivos generados sin errores.

- [ ] **Step 5: Correr el test y verificar que pasa**

Run: `flutter test test/pigeon_schema_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 6: Leer los nombres de caso que Pigeon realmente generó**

Esto no es opcional y no se puede adivinar: Pigeon transforma los nombres del esquema al idiom de cada lenguaje, y la transformación cambia entre versiones. Las Tareas 3 y 4 necesitan los nombres exactos.

Run:
```bash
grep -n -A 10 'enum KhipuResultStatus' android/src/main/kotlin/com/khipu/flutter_khipu/Messages.g.kt
grep -n -A 10 'enum KhipuResultStatus' ios/flutter_khipu/Sources/flutter_khipu/Messages.g.swift
```

Anotá los seis nombres de cada lado antes de seguir. Si Kotlin generó `MUST_CONTINUE` y Swift `mustContinue`, ése es el dato que usan las tareas nativas.

- [ ] **Step 7: Agregar al CI la verificación de que el generado está al día**

En `.github/workflows/ci.yml`, en el job `dart`, entre `- run: flutter analyze` y `- run: flutter test`:

```yaml
      - name: Generated code is up to date
        # A schema edited without regenerating leaves the three sides
        # speaking different shapes, and nothing else in the CI sees it: the
        # Dart tests run against the old generated code and pass.
        run: |
          dart run pigeon --input pigeons/khipu_api.dart
          if ! git diff --exit-code --stat; then
            echo "::error::generated code does not match pigeons/khipu_api.dart; run 'dart run pigeon --input pigeons/khipu_api.dart' and commit it"
            exit 1
          fi
```

- [ ] **Step 8: Verificar que el analyzer y los tests siguen en verde**

Run: `flutter analyze && flutter test`
Expected: sin issues. Los tests viejos siguen pasando: nada consume todavía el generado.

- [ ] **Step 9: Commit**

```bash
git add pigeons/khipu_api.dart lib/src/messages.g.dart \
  android/src/main/kotlin/com/khipu/flutter_khipu/Messages.g.kt \
  ios/flutter_khipu/Sources/flutter_khipu/Messages.g.swift \
  test/pigeon_schema_test.dart pubspec.yaml pubspec.lock .github/workflows/ci.yml
git commit -m "feat: describe the channel with a Pigeon schema

The schema is now the single source of the wire shape for all three sides.
Nothing consumes it yet; the generated code sits alongside the hand-written
MethodChannel until the Dart and native sides move over.

KhipuResultStatus carries the five values khipu-client-android 2.28.5 can
emit, measured on its bytecode, plus unknown so a new server value degrades
instead of failing the whole message decode.

Pigeon is pinned exactly: it renames enum cases between versions, and 29.0.2
is what the SPM/CocoaPods spike measured."
```

---

## Task 2: La API pública de Dart

**Files:**
- Create: `lib/src/khipu_options.dart`
- Create: `lib/src/khipu_result.dart`
- Create: `lib/src/flutter_khipu.dart`
- Modify: `lib/flutter_khipu.dart` (se reescribe entero: pasa a ser sólo el barrel)
- Modify: `pubspec.yaml` (quitar `plugin_platform_interface`)
- Delete: `lib/flutter_khipu_platform_interface.dart`, `lib/flutter_khipu_method_channel.dart`
- Delete: `test/method_channel_seam_test.dart`
- Rewrite: `test/flutter_khipu_method_channel_test.dart` → `test/flutter_khipu_test.dart` (un solo archivo de tests de Dart)

**Interfaces:**
- Consumes: de la Tarea 1, `lib/src/messages.g.dart` con `KhipuHostApi`, `KhipuTheme`, `KhipuResultStatus` y las cuatro clases generadas.
- Produces, y es lo que el comercio importa:
  - `class FlutterKhipu { FlutterKhipu({BinaryMessenger? messenger}); Future<KhipuResult?> startOperation(KhipuStartOperationOptions options); }`
  - `class KhipuStartOperationOptions` — `const`, campos `final`, `required String operationId`, `KhipuTheme? theme`, `KhipuColors? colors`
  - `class KhipuColors` — `const`, 12 campos `final String?`
  - `class KhipuResult` — `const`, `String operationId`, `KhipuResultStatus result`, `String exitTitle`, `String exitMessage`, `List<KhipuEvent> events`, `String? exitUrl`, `String? failureReason`, `String? continueUrl`
  - `class KhipuEvent` — `const`, `String name`, `String type`, `String timestamp`
  - Los enums `KhipuTheme` y `KhipuResultStatus` se re-exportan del generado tal cual.

**Decisión de diseño, explícita:** los **enums se re-exportan** del generado y las **clases se envuelven a mano**. Un enum es una lista de nombres de caso, sin forma de codegen que filtre a la API; una clase generada por Pigeon sí trae su estilo (campos mutables, constructor sin `const`, `encode`/`decode` públicos), y eso es justo lo que el wrapper existe para no publicar.

- [ ] **Step 1: Escribir los tests que fallan**

Reemplazar `test/flutter_khipu_test.dart` por completo:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_khipu/flutter_khipu.dart';

import 'package:flutter_khipu/src/messages.g.dart' as pigeon;

/// Answers the Pigeon channel the way the native side would.
///
/// Pigeon names each channel `dev.flutter.pigeon.<package>.<api>.<method>`,
/// and encodes arguments and response with its own codec. Intercepting it
/// here is the Pigeon equivalent of the old `setMockMethodCallHandler`.
void mockHost(
  Object? Function(pigeon.KhipuStartOperationOptions options) respond,
) {
  const String name =
      'dev.flutter.pigeon.flutter_khipu.KhipuHostApi.startOperation';
  final MessageCodec<Object?> codec = pigeon.KhipuHostApi.pigeonChannelCodec;

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockDecodedMessageHandler<Object?>(codec, name, (Object? message) async {
    final List<Object?> args = message! as List<Object?>;
    final options = args[0]! as pigeon.KhipuStartOperationOptions;
    return <Object?>[respond(options)];
  });
}

/// A complete native result, in the generated types.
pigeon.KhipuResult nativeResult({
  pigeon.KhipuResultStatus result = pigeon.KhipuResultStatus.ok,
  String? exitUrl = 'https://khipu.com/done',
  String? failureReason,
  String? continueUrl,
  List<pigeon.KhipuEvent>? events,
}) {
  return pigeon.KhipuResult(
    operationId: 'abc123',
    result: result,
    exitTitle: 'Listo',
    exitMessage: 'Pago realizado',
    exitUrl: exitUrl,
    failureReason: failureReason,
    continueUrl: continueUrl,
    events: events ??
        <pigeon.KhipuEvent>[
          pigeon.KhipuEvent(
            name: 'start',
            type: 'info',
            timestamp: '2026-09-21T10:00:00Z',
          ),
        ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final FlutterKhipu khipu = FlutterKhipu();

  group('startOperation', () {
    test('passes the scalar options to the native side', () async {
      late pigeon.KhipuStartOperationOptions seen;
      mockHost((pigeon.KhipuStartOperationOptions o) {
        seen = o;
        return nativeResult();
      });

      await khipu.startOperation(
        const KhipuStartOperationOptions(
          operationId: 'abc123',
          title: 'Mi comercio',
          locale: 'es_CL',
          skipExitPage: true,
          theme: KhipuTheme.dark,
        ),
      );

      expect(seen.operationId, 'abc123');
      expect(seen.title, 'Mi comercio');
      expect(seen.locale, 'es_CL');
      expect(seen.skipExitPage, isTrue);
      expect(seen.theme, pigeon.KhipuTheme.dark);
    });

    test('sends the palette nested, not twelve loose keys', () async {
      late pigeon.KhipuStartOperationOptions seen;
      mockHost((pigeon.KhipuStartOperationOptions o) {
        seen = o;
        return nativeResult();
      });

      await khipu.startOperation(
        const KhipuStartOperationOptions(
          operationId: 'abc123',
          colors: KhipuColors(
            lightPrimary: '#8347AD',
            darkPrimary: '#3CB4E5',
          ),
        ),
      );

      expect(seen.colors, isNotNull);
      expect(seen.colors!.lightPrimary, '#8347AD');
      expect(seen.colors!.darkPrimary, '#3CB4E5');
      expect(seen.colors!.lightBackground, isNull);
    });

    test('leaves the palette null when none was given', () async {
      late pigeon.KhipuStartOperationOptions seen;
      mockHost((pigeon.KhipuStartOperationOptions o) {
        seen = o;
        return nativeResult();
      });

      await khipu.startOperation(
        const KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(seen.colors, isNull);
    });
  });

  group('result', () {
    test('maps a complete result', () async {
      mockHost((_) => nativeResult());

      final KhipuResult? r = await khipu.startOperation(
        const KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(r, isNotNull);
      expect(r!.operationId, 'abc123');
      expect(r.result, KhipuResultStatus.ok);
      expect(r.exitTitle, 'Listo');
      expect(r.exitUrl, 'https://khipu.com/done');
      expect(r.failureReason, isNull);
      expect(r.continueUrl, isNull);
      expect(r.events, hasLength(1));
      expect(r.events.single.name, 'start');
    });

    test('events is its own list, not a view over the message', () async {
      mockHost((_) => nativeResult());

      final KhipuResult? r = await khipu.startOperation(
        const KhipuStartOperationOptions(operationId: 'abc123'),
      );

      // Pigeon delivers a CastList, which is a view over the list the
      // channel decoded and casts on every access. The wrapper copies it.
      expect(r!.events, isA<List<KhipuEvent>>());
      expect(() => r.events.add(r.events.first), throwsUnsupportedError);
    });

    test('an empty events list arrives as const []', () async {
      mockHost((_) => nativeResult(events: <pigeon.KhipuEvent>[]));

      final KhipuResult? r = await khipu.startOperation(
        const KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(r!.events, isEmpty);
    });

    test('returns null when the native side sends no result', () async {
      mockHost((_) => null);

      final KhipuResult? r = await khipu.startOperation(
        const KhipuStartOperationOptions(operationId: 'abc123'),
      );

      expect(r, isNull);
    });

    test('the five SDK statuses cross the channel', () async {
      for (final pigeon.KhipuResultStatus s in <pigeon.KhipuResultStatus>[
        pigeon.KhipuResultStatus.ok,
        pigeon.KhipuResultStatus.error,
        pigeon.KhipuResultStatus.warning,
        pigeon.KhipuResultStatus.mustContinue,
        pigeon.KhipuResultStatus.userCanceled,
      ]) {
        mockHost((_) => nativeResult(result: s));

        final KhipuResult? r = await khipu.startOperation(
          const KhipuStartOperationOptions(operationId: 'abc123'),
        );

        expect(r!.result.name, s.name);
      }
    });
  });

  group('value', () {
    test('two results with the same fields are equal', () {
      const KhipuResult a = KhipuResult(
        operationId: 'abc123',
        result: KhipuResultStatus.ok,
        exitTitle: 'Listo',
        exitMessage: 'Pago realizado',
        events: <KhipuEvent>[],
      );
      const KhipuResult b = KhipuResult(
        operationId: 'abc123',
        result: KhipuResultStatus.ok,
        exitTitle: 'Listo',
        exitMessage: 'Pago realizado',
        events: <KhipuEvent>[],
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toString names the status', () {
      const KhipuResult a = KhipuResult(
        operationId: 'abc123',
        result: KhipuResultStatus.userCanceled,
        exitTitle: 'Cancelado',
        exitMessage: 'La persona salió',
        events: <KhipuEvent>[],
      );

      expect(a.toString(), contains('userCanceled'));
    });
  });
}
```

- [ ] **Step 2: Correr y verificar que falla**

Run: `flutter test test/flutter_khipu_test.dart`
Expected: FAIL en compilación — `KhipuStartOperationOptions` no tiene constructor `const`, `FlutterKhipu` no acepta `messenger`, `KhipuResult.result` es `String?` y no `KhipuResultStatus`.

- [ ] **Step 3: Escribir los tipos de opciones**

Crear `lib/src/khipu_options.dart`:

```dart
import 'package:meta/meta.dart';

import 'messages.g.dart' as pigeon;

/// Palette Khipu is painted with.
///
/// Each color is a hex string, `'#8347AD'`. A null color leaves the one the
/// SDK brings.
@immutable
class KhipuColors {
  const KhipuColors({
    this.lightBackground,
    this.lightOnBackground,
    this.lightPrimary,
    this.lightOnPrimary,
    this.lightTopBarContainer,
    this.lightOnTopBarContainer,
    this.darkBackground,
    this.darkOnBackground,
    this.darkPrimary,
    this.darkOnPrimary,
    this.darkTopBarContainer,
    this.darkOnTopBarContainer,
  });

  final String? lightBackground;
  final String? lightOnBackground;
  final String? lightPrimary;
  final String? lightOnPrimary;
  final String? lightTopBarContainer;
  final String? lightOnTopBarContainer;
  final String? darkBackground;
  final String? darkOnBackground;
  final String? darkPrimary;
  final String? darkOnPrimary;
  final String? darkTopBarContainer;
  final String? darkOnTopBarContainer;

  pigeon.KhipuColors toPigeon() => pigeon.KhipuColors(
        lightBackground: lightBackground,
        lightOnBackground: lightOnBackground,
        lightPrimary: lightPrimary,
        lightOnPrimary: lightOnPrimary,
        lightTopBarContainer: lightTopBarContainer,
        lightOnTopBarContainer: lightOnTopBarContainer,
        darkBackground: darkBackground,
        darkOnBackground: darkOnBackground,
        darkPrimary: darkPrimary,
        darkOnPrimary: darkOnPrimary,
        darkTopBarContainer: darkTopBarContainer,
        darkOnTopBarContainer: darkOnTopBarContainer,
      );

  @override
  bool operator ==(Object other) =>
      other is KhipuColors &&
      other.lightBackground == lightBackground &&
      other.lightOnBackground == lightOnBackground &&
      other.lightPrimary == lightPrimary &&
      other.lightOnPrimary == lightOnPrimary &&
      other.lightTopBarContainer == lightTopBarContainer &&
      other.lightOnTopBarContainer == lightOnTopBarContainer &&
      other.darkBackground == darkBackground &&
      other.darkOnBackground == darkOnBackground &&
      other.darkPrimary == darkPrimary &&
      other.darkOnPrimary == darkOnPrimary &&
      other.darkTopBarContainer == darkTopBarContainer &&
      other.darkOnTopBarContainer == darkOnTopBarContainer;

  @override
  int get hashCode => Object.hash(
        lightBackground,
        lightOnBackground,
        lightPrimary,
        lightOnPrimary,
        lightTopBarContainer,
        lightOnTopBarContainer,
        darkBackground,
        darkOnBackground,
        darkPrimary,
        darkOnPrimary,
        darkTopBarContainer,
        darkOnTopBarContainer,
      );

  @override
  String toString() => 'KhipuColors(lightPrimary: $lightPrimary, '
      'darkPrimary: $darkPrimary)';
}

/// What is needed to open a payment.
///
/// Only [operationId] is required; the rest adjusts the presentation and,
/// if left null, Khipu uses its own default.
@immutable
class KhipuStartOperationOptions {
  const KhipuStartOperationOptions({
    required this.operationId,
    this.locale,
    this.title,
    this.titleImageUrl,
    this.skipExitPage,
    this.skipExitSuccessPage,
    this.showFooter,
    this.showMerchantLogo,
    this.showPaymentDetails,
    this.theme,
    this.colors,
  });

  /// Operation identifier, created on the merchant's backend.
  final String operationId;

  /// Interface language, `'es_CL'`.
  final String? locale;

  /// Title of the top bar.
  final String? title;

  /// Image of the top bar.
  final String? titleImageUrl;

  /// Skips the final screen, whatever the outcome.
  final bool? skipExitPage;

  /// Skips the final screen only when the payment went well.
  final bool? skipExitSuccessPage;

  final bool? showFooter;
  final bool? showMerchantLogo;
  final bool? showPaymentDetails;

  /// Theme it presents itself with. Null leaves the SDK's own.
  final KhipuTheme? theme;

  /// Palette. Null leaves the SDK's own.
  final KhipuColors? colors;

  pigeon.KhipuStartOperationOptions toPigeon() =>
      pigeon.KhipuStartOperationOptions(
        operationId: operationId,
        locale: locale,
        title: title,
        titleImageUrl: titleImageUrl,
        skipExitPage: skipExitPage,
        skipExitSuccessPage: skipExitSuccessPage,
        showFooter: showFooter,
        showMerchantLogo: showMerchantLogo,
        showPaymentDetails: showPaymentDetails,
        theme: theme,
        colors: colors?.toPigeon(),
      );

  @override
  bool operator ==(Object other) =>
      other is KhipuStartOperationOptions &&
      other.operationId == operationId &&
      other.locale == locale &&
      other.title == title &&
      other.titleImageUrl == titleImageUrl &&
      other.skipExitPage == skipExitPage &&
      other.skipExitSuccessPage == skipExitSuccessPage &&
      other.showFooter == showFooter &&
      other.showMerchantLogo == showMerchantLogo &&
      other.showPaymentDetails == showPaymentDetails &&
      other.theme == theme &&
      other.colors == colors;

  @override
  int get hashCode => Object.hash(
        operationId,
        locale,
        title,
        titleImageUrl,
        skipExitPage,
        skipExitSuccessPage,
        showFooter,
        showMerchantLogo,
        showPaymentDetails,
        theme,
        colors,
      );

  @override
  String toString() =>
      'KhipuStartOperationOptions(operationId: $operationId, theme: $theme)';
}
```

Nota: `theme` es del tipo generado `KhipuTheme` sin prefijo porque el barrel lo re-exporta; dentro de este archivo se referencia por el import con prefijo sólo cuando se construye el mensaje.

Agregar al final del import block de este archivo:

```dart
export 'messages.g.dart' show KhipuTheme;
```

- [ ] **Step 4: Escribir los tipos de resultado**

Crear `lib/src/khipu_result.dart`:

```dart
import 'package:meta/meta.dart';

import 'messages.g.dart' as pigeon;

export 'messages.g.dart' show KhipuResultStatus;

/// A milestone of the payment, as reported by the SDK.
@immutable
class KhipuEvent {
  const KhipuEvent({
    required this.name,
    required this.type,
    required this.timestamp,
  });

  /// All three are non-null: measured on `khipu-client-android` 2.28.5, the
  /// constructor of `com.khipu.client.KhipuEvent` checks them with
  /// `checkNotNullParameter`.
  final String name;
  final String type;
  final String timestamp;

  factory KhipuEvent._fromPigeon(pigeon.KhipuEvent e) => KhipuEvent(
        name: e.name,
        type: e.type,
        timestamp: e.timestamp,
      );

  @override
  bool operator ==(Object other) =>
      other is KhipuEvent &&
      other.name == name &&
      other.type == type &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(name, type, timestamp);

  @override
  String toString() =>
      'KhipuEvent(name: $name, type: $type, timestamp: $timestamp)';
}

/// The outcome of the payment.
///
/// The five non-null fields are so because the SDK declares them that way
/// on both platforms (§2.3 of the design doc). The three optionals —
/// [exitUrl], [failureReason] and [continueUrl]— are exactly the ones the
/// SDK declares `@Nullable`, and they always travel: Pigeon serializes a
/// positional list, so an empty field takes its place with `null` and there
/// is no key to omit.
@immutable
class KhipuResult {
  const KhipuResult({
    required this.operationId,
    required this.result,
    required this.exitTitle,
    required this.exitMessage,
    required this.events,
    this.exitUrl,
    this.failureReason,
    this.continueUrl,
  });

  final String operationId;

  /// What happened with the payment. Can be [KhipuResultStatus.unknown] if
  /// the server emitted a value this plugin does not know yet.
  final KhipuResultStatus result;

  final String exitTitle;
  final String exitMessage;

  /// The payment's milestones, in order. Its own, fixed-length list: the
  /// wrapper copies the one the channel delivers, which is a view that
  /// casts on each access.
  final List<KhipuEvent> events;

  /// Where to return to when the payment finished. Null if not applicable.
  final String? exitUrl;

  /// Why it failed. Null if it did not fail.
  final String? failureReason;

  /// Where to continue to when the payment was left halfway. Null if not
  /// applicable.
  final String? continueUrl;

  factory KhipuResult.fromPigeon(pigeon.KhipuResult r) => KhipuResult(
        operationId: r.operationId,
        result: r.result,
        exitTitle: r.exitTitle,
        exitMessage: r.exitMessage,
        exitUrl: r.exitUrl,
        failureReason: r.failureReason,
        continueUrl: r.continueUrl,
        events: r.events.isEmpty
            ? const <KhipuEvent>[]
            : List<KhipuEvent>.unmodifiable(
                r.events.map(KhipuEvent._fromPigeon),
              ),
      );

  @override
  bool operator ==(Object other) =>
      other is KhipuResult &&
      other.operationId == operationId &&
      other.result == result &&
      other.exitTitle == exitTitle &&
      other.exitMessage == exitMessage &&
      other.exitUrl == exitUrl &&
      other.failureReason == failureReason &&
      other.continueUrl == continueUrl &&
      _sameEvents(other.events, events);

  static bool _sameEvents(List<KhipuEvent> a, List<KhipuEvent> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        operationId,
        result,
        exitTitle,
        exitMessage,
        exitUrl,
        failureReason,
        continueUrl,
        Object.hashAll(events),
      );

  @override
  String toString() => 'KhipuResult(operationId: $operationId, '
      'result: $result, events: ${events.length})';
}
```

- [ ] **Step 5: Escribir la puerta de entrada**

Crear `lib/src/flutter_khipu.dart`:

```dart
import 'package:flutter/services.dart' show BinaryMessenger;

import 'khipu_options.dart';
import 'khipu_result.dart';
import 'messages.g.dart' as pigeon;

/// Entry point of the plugin.
///
/// ```dart
/// final KhipuResult? result = await FlutterKhipu().startOperation(
///   const KhipuStartOperationOptions(operationId: 'abc123'),
/// );
/// ```
class FlutterKhipu {
  /// Builds the plugin.
  ///
  /// [messenger] exists for tests: passing one of your own lets you
  /// intercept the channel without touching the global binding. In an app
  /// there is no need to give it.
  FlutterKhipu({BinaryMessenger? messenger})
      : _api = pigeon.KhipuHostApi(binaryMessenger: messenger);

  final pigeon.KhipuHostApi _api;

  /// Opens Khipu and waits for the person to finish the payment.
  ///
  /// Returns the outcome, or `null` if the native side finished without
  /// one.
  ///
  /// Throws [PlatformException] if the operation failed to open. The
  /// possible codes are documented in the README; two of them —
  /// `OPERATION_IN_PROGRESS` and `MISSING_OPERATION_ID`— exist on both
  /// platforms, and the rest only on one.
  Future<KhipuResult?> startOperation(
    KhipuStartOperationOptions options,
  ) async {
    final pigeon.KhipuResult? result =
        await _api.startOperation(options.toPigeon());
    return result == null ? null : KhipuResult.fromPigeon(result);
  }
}
```

- [ ] **Step 6: Reescribir el barrel**

Reemplazar `lib/flutter_khipu.dart` por completo:

```dart
/// Khipu plugin for Flutter.
///
/// This is the only file a merchant imports. Everything under `lib/src/` is
/// internal and can change without notice, including the code Pigeon
/// generates.
library;

export 'src/flutter_khipu.dart' show FlutterKhipu;
export 'src/khipu_options.dart'
    show KhipuColors, KhipuStartOperationOptions, KhipuTheme;
export 'src/khipu_result.dart'
    show KhipuEvent, KhipuResult, KhipuResultStatus;
```

- [ ] **Step 7: Borrar la capa vieja**

```bash
git rm lib/flutter_khipu_platform_interface.dart \
       lib/flutter_khipu_method_channel.dart \
       test/method_channel_seam_test.dart \
       test/flutter_khipu_method_channel_test.dart
```

`test/flutter_khipu_method_channel_test.dart` se borra porque su contenido quedó reescrito dentro de `test/flutter_khipu_test.dart` en el Step 1: probaba el `MethodChannel` que ya no existe.

En `pubspec.yaml`, quitar de `dependencies`:

```yaml
  plugin_platform_interface: ^2.0.2
```

y agregar, en su lugar:

```yaml
  meta: ^1.15.0
```

- [ ] **Step 8: Correr los tests y verificar que pasan**

Run: `flutter test`
Expected: PASS. `test/pigeon_schema_test.dart`, `test/flutter_khipu_test.dart` y `test/package_metadata_test.dart` en verde.

Si `throwsUnsupportedError` falla en el test de `events`, es porque `List.unmodifiable` no se usó; revisar el Step 4.

- [ ] **Step 9: Verificar el analyzer**

Run: `flutter analyze`
Expected: sin issues. Si aparece `unused_import` sobre `messages.g.dart` en `khipu_options.dart`, es que el `export` quedó mal puesto.

- [ ] **Step 10: Commit**

```bash
git add -A lib test pubspec.yaml pubspec.lock
git commit -m "feat!: publish a 2.0.0 Dart API over the generated channel

lib/flutter_khipu.dart is now only a barrel. Everything a merchant can
import is a hand-written wrapper in lib/src/, so regenerating the schema
cannot move the public API.

The types are immutable: const constructors, final fields, ==/hashCode/
toString. result and theme are enums instead of strings, five fields that
were nullable stop being so, and events is an unmodifiable List instead of
a lazy Iterable that re-parsed on every pass.

plugin_platform_interface goes away. Pigeon's KhipuHostApi is the seam
between Dart and each platform, and this plugin is not federated.

The native sides still speak the old MethodChannel: the example does not
run again until the Android and iOS tasks land."
```

---

## Task 3: Android

**Files:**
- Modify: `android/src/main/kotlin/com/khipu/flutter_khipu/FlutterKhipuPlugin.kt` (se reescribe el camino del canal; el manejo de activity se conserva)
- Test: `android/src/test/kotlin/com/khipu/flutter_khipu/FlutterKhipuPluginTest.kt` (existente, se adapta)

**Interfaces:**
- Consumes: de la Tarea 1, `Messages.g.kt` con `KhipuHostApi`, `KhipuResultStatus`, `KhipuStartOperationOptions`, `KhipuResult`, `KhipuEvent` y `FlutterError`, todos en `com.khipu.flutter_khipu`.
- Produces: el lado Android del canal. Ningún otro task de Dart depende de esto.

**Lo que NO cambia, y es deliberado:** el `intentFactory` inyectable, `respondOnce`, el ciclo de `ActivityAware`, la guarda por `pendingResult`, y los siete códigos de error con sus mensajes exactos. La Tarea 3 cambia **cómo se transporta** el resultado, no el camino del resultado que endureció el Ciclo 1.

- [ ] **Step 1: Leer los nombres de caso generados**

Run: `grep -n -A 10 'enum class KhipuResultStatus' android/src/main/kotlin/com/khipu/flutter_khipu/Messages.g.kt`

Copiá los seis nombres exactos. El Step 3 los usa y **no se pueden adivinar**: Pigeon los transforma y la transformación cambia entre versiones. Si generó `MUST_CONTINUE`, usá ése; si generó `mustContinue`, ése.

- [ ] **Step 2: Escribir el test que falla**

Agregar a `android/src/test/kotlin/com/khipu/flutter_khipu/FlutterKhipuPluginTest.kt`:

```kotlin
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
```

Ajustá `MUST_CONTINUE` y los demás al nombre real que leíste en el Step 1.

- [ ] **Step 3: Correr y verificar que falla**

Run: `./gradlew :flutter_khipu:test --tests '*FlutterKhipuPluginTest*'`
Working directory: `example/android`
Expected: FAIL — `Unresolved reference: statusOf`.

- [ ] **Step 4: Reescribir el plugin**

En `android/src/main/kotlin/com/khipu/flutter_khipu/FlutterKhipuPlugin.kt`:

Cambiar los imports del SDK para que no choquen con los generados, que viven en este mismo paquete:

```kotlin
import com.khipu.client.KHIPU_RESULT_EXTRA
import com.khipu.client.KhipuOptions
import com.khipu.client.getKhipuLauncherIntent
import com.khipu.client.KhipuResult as SdkKhipuResult
```

Cambiar la declaración de la clase y el estado pendiente:

```kotlin
class FlutterKhipuPlugin : FlutterPlugin, KhipuHostApi,
    PluginRegistry.ActivityResultListener, ActivityAware {

    private var binding: ActivityPluginBinding? = null
    private val activity: Activity? get() = binding?.activity
    private var pendingResult: ((Result<KhipuResult?>) -> Unit)? = null
    private var messenger: BinaryMessenger? = null
```

Reemplazar `onAttachedToEngine` / `onDetachedFromEngine`:

```kotlin
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        messenger = flutterPluginBinding.binaryMessenger
        KhipuHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        messenger?.let { KhipuHostApi.setUp(it, null) }
        messenger = null
    }
```

Borrar `onMethodCall` entero y reemplazar `startOperation` por la firma del HostApi:

```kotlin
    override fun startOperation(
        options: KhipuStartOperationOptions,
        callback: (Result<KhipuResult?>) -> Unit
    ) {
        val activity = this.activity
            ?: return callback(failure("NO_ACTIVITY", "A foreground activity is needed to start Khipu"))

        if (pendingResult != null) {
            return callback(failure("OPERATION_IN_PROGRESS", "A Khipu operation is already running"))
        }

        // MISSING_OPERATION_ID goes away: the schema declares operationId
        // non-null and the codec rejects the message before it gets here,
        // so the guard was unreachable. iOS loses it for the same reason
        // (Task 4), and the Task 6 README brings the table down from nine
        // codes to seven.
        val intent = try {
            intentFactory(activity.baseContext, options.operationId, buildKhipuOptions(options))
        } catch (e: Exception) {
            return callback(failure("INVALID_OPTIONS", e.message))
        }

        // The callback is stored as late as possible. Everything that can
        // throw already happened above, and the only thing left runs inside
        // a try that clears it.
        pendingResult = callback
        try {
            activity.startActivityForResult(intent, KHIPU_START_OPERATION_CODE)
        } catch (e: Exception) {
            pendingResult = null
            callback(failure("LAUNCH_FAILED", e.message))
        }
    }

    private fun failure(code: String, message: String?): Result<KhipuResult?> =
        Result.failure(FlutterError(code, message, null))
```

Adaptar `respondOnce` y `onActivityResult`:

```kotlin
    private fun respondOnce(block: ((Result<KhipuResult?>) -> Unit) -> Unit): Boolean {
        val callback = pendingResult ?: return false
        pendingResult = null
        block(callback)
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != KHIPU_START_OPERATION_CODE) return false

        // Decide on the payload, never the resultCode: both of the SDK's
        // exits carry a complete KhipuResult, and RESULT_CANCELED is only
        // the late restoration after a process death.
        val khipuResult = runCatching { data?.khipuResult() }.getOrNull()

        return respondOnce { callback ->
            if (khipuResult == null) {
                callback(failure("NO_RESULT", "Khipu returned without a result"))
            } else {
                callback(Result.success(khipuResult.toPigeon()))
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
```

Reemplazar `toMap()` entero por la conversión a los tipos generados. **El comentario sobre el estilo de asignación indexada se borra con él**: vigilaba una regex de `method_channel_seam_test.dart`, que ya no existe.

```kotlin
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
```

Y ampliar el `companion object` del final de la clase con el mapeo de estado. Va ahí, y no como método de instancia, porque no toca estado del plugin y el test lo ejercita sin construir uno:

```kotlin
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
```

Este `when` **sí** lleva `else`: su entrada es texto libre del SDK, no un tipo cerrado, y el `else` es justamente el comportamiento que se quiere.

Adaptar `detach`:

```kotlin
    private fun detach(answerPending: Boolean) {
        binding?.removeActivityResultListener(this)
        binding = null
        if (answerPending) {
            respondOnce { it(failure("ACTIVITY_DETACHED", "The activity went away before Khipu returned")) }
        }
    }
```

Y `buildKhipuOptions`, que pasa de leer un `MethodCall` a leer el objeto tipado. El tema deja de compararse por string:

```kotlin
    private fun buildKhipuOptions(options: KhipuStartOperationOptions): KhipuOptions {
        val builder = KhipuOptions.Builder()
        options.title?.let { builder.topBarTitle(it) }
        options.titleImageUrl?.let { builder.topBarImageUrl(it) }
        options.locale?.let { builder.locale(it) }
        options.skipExitPage?.let { builder.skipExitPage(it) }
        options.skipExitSuccessPage?.let { builder.skipExitSuccessPage(it) }
        options.showFooter?.let { builder.showFooter(it) }
        options.showMerchantLogo?.let { builder.showMerchantLogo(it) }
        options.showPaymentDetails?.let { builder.showPaymentDetails(it) }
        options.theme?.let { builder.theme(it.toSdk()) }
        options.colors?.let { builder.colors(it.toSdk()) }
        return builder.build()
    }

    /**
     * The `when` deliberately has no `else`: adding a theme to the schema
     * has to fail to compile here, not fail silently at runtime.
     */
    private fun KhipuTheme.toSdk(): KhipuOptions.Theme = when (this) {
        KhipuTheme.LIGHT -> KhipuOptions.Theme.LIGHT
        KhipuTheme.DARK -> KhipuOptions.Theme.DARK
        KhipuTheme.SYSTEM -> KhipuOptions.Theme.SYSTEM
    }

    private fun KhipuColors.toSdk(): SdkKhipuColors {
        val b = SdkKhipuColors.Builder()
        lightBackground?.let { b.lightBackground(it) }
        lightOnBackground?.let { b.lightOnBackground(it) }
        lightPrimary?.let { b.lightPrimary(it) }
        lightOnPrimary?.let { b.lightOnPrimary(it) }
        lightTopBarContainer?.let { b.lightTopBarContainer(it) }
        lightOnTopBarContainer?.let { b.lightOnTopBarContainer(it) }
        darkBackground?.let { b.darkBackground(it) }
        darkOnBackground?.let { b.darkOnBackground(it) }
        darkPrimary?.let { b.darkPrimary(it) }
        darkOnPrimary?.let { b.darkOnPrimary(it) }
        darkTopBarContainer?.let { b.darkTopBarContainer(it) }
        darkOnTopBarContainer?.let { b.darkOnTopBarContainer(it) }
        return b.build()
    }
```

`KhipuOptions.Theme` tiene exactamente `LIGHT`, `DARK` y `SYSTEM`, y `KhipuColors.Builder` expone los doce setters fluidos más `build()`: medido con `javap` sobre el AAR 2.28.5. `SdkKhipuColors` es el alias de import que hay que agregar arriba, junto al de `SdkKhipuResult`:

```kotlin
import com.khipu.client.KhipuColors as SdkKhipuColors
```

Ajustá `KhipuTheme.LIGHT` al nombre de caso que Pigeon haya generado (Step 1).

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `./gradlew :flutter_khipu:test`
Working directory: `example/android`
Expected: PASS, incluidos los tests del Ciclo 1 sobre el camino del resultado.

- [ ] **Step 6: Compilar el example**

Run: `flutter build apk --debug`
Working directory: `example`
Expected: BUILD SUCCESSFUL. **Sin pipe a `tail`.**

El example todavía no compila su Dart si no se adaptó a la API 2.0.0; si falla ahí y no en Kotlin, dejá el arreglo del example para la Tarea 5 y verificá sólo `./gradlew :flutter_khipu:assembleDebug`.

- [ ] **Step 7: Commit**

```bash
git add android/
git commit -m "feat!: implement the Pigeon host API on Android

The channel plumbing moves to the generated KhipuHostApi. What the first
cycle hardened stays exactly as it was: the injectable intentFactory, the
answer-once discipline, the ActivityAware lifecycle, the pendingResult
guard, and all seven error codes with their messages.

The SDK's result string becomes an enum at this boundary, with UNKNOWN for
anything the plugin does not recognise yet, so a new server value reaches
the merchant instead of failing the decode.

The SDK's KhipuResult is imported aliased: Pigeon's lands in the same
package."
```

---

## Task 4: iOS, y el circuito cierra

**Files:**
- Modify: `ios/flutter_khipu/Sources/flutter_khipu/FlutterKhipuPlugin.swift`

**Interfaces:**
- Consumes: de la Tarea 1, `Messages.g.swift`.
- Produces: el lado iOS del canal. **Al cerrar esta tarea el plugin vuelve a funcionar de punta a punta.**

**Lo que NO cambia:** `presenter()` con su recorrido por el window scene, el flag `operationInFlight` con su colocación *antes* del `DispatchQueue.main.async`, y los cuatro códigos de error con sus mensajes.

- [ ] **Step 1: Leer los nombres de caso generados**

Run: `grep -n -A 10 'enum KhipuResultStatus' ios/flutter_khipu/Sources/flutter_khipu/Messages.g.swift`

- [ ] **Step 2: Calificar por módulo todos los usos del SDK**

`KhipuClientIOS` exporta `KhipuColors`, `KhipuResult` y `KhipuEvent` como públicos, y los generados caen en el mismo módulo Swift: Swift prefiere el local y el build se cae con `Type 'KhipuColors' has no member 'Builder'`.

Decisión de Emilio del 2026-09-21: calificar con el módulo. Y calificar **todos** los usos del SDK, no sólo el que rompe, para que la regla sea legible y el próximo tipo que entre al esquema no reabra el problema en silencio.

En `FlutterKhipuPlugin.swift`:

```swift
        var optionsBuilder = KhipuClientIOS.KhipuOptions.Builder()
```
```swift
        var colorsBuilder = KhipuClientIOS.KhipuColors.Builder()
```
```swift
            KhipuClientIOS.KhipuLauncher.launch(presenter: rootViewController,
```

Agregar arriba del primero:

```swift
        // SDK types are always named with their module. KhipuClientIOS
        // exports KhipuColors, KhipuResult and KhipuEvent as public, and the
        // ones Pigeon generates land in this same module: unqualified,
        // Swift picks the generated one and the error it gives does not
        // mention shadowing.
```

- [ ] **Step 3: Pasar de FlutterPlugin a KhipuHostApi**

Cambiar el registro:

```swift
public class FlutterKhipuPlugin: NSObject, FlutterPlugin, KhipuHostApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FlutterKhipuPlugin()
    KhipuHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
  }
```

Borrar `handle(_:result:)` entero.

Cambiar la firma de `startOperation` a la del HostApi generado. **Ojo con la forma: Pigeon 29.0.2 con `@async` NO genera un completion handler, genera `async throws`.** Medido en el generado (`Messages.g.swift:583-585`):

```swift
protocol KhipuHostApi {
  func startOperation(options: KhipuStartOperationOptions) async throws -> KhipuResult?
}
```

Kotlin hace lo mismo (`suspend fun`), y la Tarea 3 ya lo resolvió con `suspendCancellableCoroutine`. Acá el equivalente es `withCheckedThrowingContinuation`, porque `KhipuLauncher.launch` sigue siendo callback.

Así que los errores se **lanzan**, no se pasan a un completion:

```swift
    func startOperation(options: KhipuStartOperationOptions) async throws -> KhipuResult? {
        if operationInFlight {
            throw PigeonError(code: "OPERATION_IN_PROGRESS",
                              message: "A Khipu operation is already running",
                              details: nil)
        }

        guard let rootViewController = FlutterKhipuPlugin.presenter() else {
            throw PigeonError(code: "NO_VIEW_CONTROLLER",
                              message: "A view controller is needed to start Khipu",
                              details: nil)
        }
        ...
```

**La continuación se reanuda exactamente una vez.** Reanudarla dos veces es un crash de Swift, y no reanudarla nunca deja el `Future` del comercio colgado para siempre — que es justo el defecto que el Ciclo 1 cerró en Android. El `operationInFlight` se libera en el mismo lugar donde hoy se libera, dentro del closure del SDK, y sigue teniendo que setearse **antes** del salto a la cola principal.

Confirmá el nombre exacto del tipo de error contra `Messages.g.swift` antes de escribirlo: en Kotlin es `FlutterError` y en Swift `PigeonError`.

Los guards `BAD_ARGUMENT_DICTIONARY` y `MISSING_OPERATION_ID` **se borran**: el codec de Pigeon rechaza un mensaje malformado antes de llegar acá, y `operationId` es no nulo en el esquema. Anotalo para el README de la Tarea 6: los dos códigos desaparecen de la API 2.0.0.

Las 22 guardas `if (args["x"] is String)` se reemplazan por los campos tipados:

```swift
        if let title = options.title { optionsBuilder = optionsBuilder.topBarTitle(title) }
        if let url = options.titleImageUrl { optionsBuilder = optionsBuilder.topBarImageUrl(url) }
        if let locale = options.locale { optionsBuilder = optionsBuilder.locale(locale) }
        if let v = options.skipExitPage { optionsBuilder = optionsBuilder.skipExitPage(v) }
        if let v = options.skipExitSuccessPage { optionsBuilder = optionsBuilder.skipExitSuccessPage(v) }
        if let v = options.showFooter { optionsBuilder = optionsBuilder.showFooter(v) }
        if let v = options.showMerchantLogo { optionsBuilder = optionsBuilder.showMerchantLogo(v) }
        if let v = options.showPaymentDetails { optionsBuilder = optionsBuilder.showPaymentDetails(v) }

        if let theme = options.theme {
            switch theme {
            case .light: optionsBuilder = optionsBuilder.theme(.light)
            case .dark: optionsBuilder = optionsBuilder.theme(.dark)
            case .system: optionsBuilder = optionsBuilder.theme(.system)
            }
        }
```

El `switch` va sin `default`: agregar un tema al esquema tiene que dejar de compilar.

El bloque de colores hace lo mismo con `options.colors?.lightBackground` y sus once hermanos, sobre `KhipuClientIOS.KhipuColors.Builder()`.

- [ ] **Step 4: Convertir el resultado, con el mismo mapeo de estado que Android**

El launcher del SDK sigue siendo callback, así que el puente es `withCheckedThrowingContinuation`. Dentro del closure, reemplazar el diccionario por el tipo generado y reanudar la continuación:

```swift
        operationInFlight = true
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                KhipuClientIOS.KhipuLauncher.launch(presenter: rootViewController,
                                                    operationId: options.operationId,
                                                    options: optionsBuilder.build()) { [weak self] khipuResult in
                    self?.operationInFlight = false
                    continuation.resume(returning: KhipuResult(
                        operationId: khipuResult.operationId,
                        result: Self.statusOf(khipuResult.result),
                        exitTitle: khipuResult.exitTitle,
                        exitMessage: khipuResult.exitMessage,
                        events: khipuResult.events.map { event in
                            KhipuEvent(name: event.name,
                                       type: event.type,
                                       timestamp: event.timestamp)
                        },
                        exitUrl: khipuResult.exitUrl,
                        failureReason: khipuResult.failureReason,
                        continueUrl: khipuResult.continueUrl
                    ))
                }
            }
        }
```

`operationInFlight = true` queda **fuera** del `withCheckedThrowingContinuation` y antes del `DispatchQueue.main.async`, igual que hoy: es lo que hace que dos llamadas rápidas no pasen las dos la guarda. Moverlo adentro parece un refactor inocente y reabre la carrera.

El orden de los parámetros de `KhipuResult` lo fija el generado —es un `struct` con memberwise init sintetizado— y el de arriba es el orden real medido; confirmalo igual en `Messages.g.swift`.

**La continuación se reanuda exactamente una vez.** El closure del SDK corre una sola vez por operación, así que el camino normal está cubierto; lo que hay que cuidar es no agregar un segundo `resume` en un camino de error dentro del closure.

Y el mapeo, que tiene que dar exactamente lo mismo que el `statusOf` de Kotlin:

```swift
    /// Translates the SDK's free text into the channel's enum.
    ///
    /// The five values are the ones the native client emits; `.unknown` is
    /// what makes a new value from the server reach the merchant instead of
    /// breaking the whole message. It has to match `statusOf` in
    /// FlutterKhipuPlugin.kt: they are the same contract written twice.
    private static func statusOf(_ raw: String) -> KhipuResultStatus {
        switch raw {
        case "OK": return .ok
        case "ERROR": return .error
        case "WARNING": return .warning
        case "CONTINUE": return .mustContinue
        case "USER_CANCELED": return .userCanceled
        default: return .unknown
        }
    }
```

- [ ] **Step 5: Compilar con los dos empaquetados**

```bash
cd example
flutter config --enable-swift-package-manager
flutter build ios --no-codesign --debug

flutter config --no-enable-swift-package-manager
flutter clean && flutter build ios --no-codesign --debug
```

Expected: los dos terminan en éxito. **Sin pipe a `tail`**: devuelve el exit code de `tail` y un build fallado se ve como verde.

Si CocoaPods se cae con `Cannot find 'KhipuHostApi' in scope`, es que no vio el `Messages.g.swift` nuevo: CocoaPods fija la lista de archivos en `pod install`, mientras SPM toma el directorio por glob. Se confirma buscando el archivo en `example/ios/Pods/Pods.xcodeproj/project.pbxproj`, y se arregla con `pod install` en `example/ios`.

- [ ] **Step 6: Verificar el canal en el binario**

```bash
strings example/build/ios/Debug-iphonesimulator/Runner.app/Frameworks/App.framework/App \
  | grep 'dev.flutter.pigeon.flutter_khipu.KhipuHostApi'
```

Expected: al menos una línea. En modo SPM el binario `Runner` es un stub de ~70 KB y el código vive en `Runner.debug.dylib`; buscar en `Runner` da vacío aunque todo esté bien.

- [ ] **Step 7: Commit**

```bash
git add ios/
git commit -m "feat!: implement the Pigeon host API on iOS

The channel closes: Dart, Android and iOS now speak the generated contract
and the example runs again.

Every KhipuClientIOS type is now named with its module. The SDK exports
KhipuColors, KhipuResult and KhipuEvent as public and Pigeon's land in the
same Swift module, so an unqualified name silently picks the generated one
— the build then fails on a missing .Builder, which does not mention
shadowing. Qualifying all of them, not just the one that broke, keeps the
rule legible when the next type enters the schema.

BAD_ARGUMENT_DICTIONARY and MISSING_OPERATION_ID are gone: the codec rejects
a malformed message before the handler runs, and operationId is non-null in
the schema.

presenter() and the operationInFlight flag are untouched, placement
included."
```

---

## Task 5: El example, y la higiene de empaquetado de §7.5

**Files:**
- Modify: `example/lib/main.dart`, `example/lib/options_form.dart`, `example/lib/result_card.dart`, `example/lib/demo_settings.dart`
- Modify: `example/test/demo_page_test.dart`, `example/test/demo_settings_test.dart`
- Modify: `ios/flutter_khipu/Package.swift`
- Modify: `ios/flutter_khipu.podspec`
- Modify: `example/ios/Podfile`
- Modify: `example/ios/Runner.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: la API 2.0.0 de la Tarea 2.
- Produces: nada que otra tarea consuma.

- [ ] **Step 1: Adaptar el example a la API 2.0.0**

Run: `flutter analyze` en `example/`, y arreglá lo que reporte. Los cambios son mecánicos:
- `theme: 'dark'` → `theme: KhipuTheme.dark`
- `result.result == 'OK'` → `result.result == KhipuResultStatus.ok`
- `result.events?.length ?? 0` → `result.events.length`
- Los constructores de opciones y colores admiten `const`.

- [ ] **Step 2: Correr los tests del example**

Run: `flutter test`
Working directory: `example`
Expected: PASS.

- [ ] **Step 3: Subir la plataforma de Package.swift a iOS 15**

```swift
    platforms: [
        .iOS("15.0")
    ],
```

- [ ] **Step 4: Medir el aviso de FlutterFramework antes de tocarlo**

**Este paso empieza por medir, no por editar, y puede terminar sin cambio.** El spec (§7.5) registra que Flutter pide `FlutterFramework` por consola en cada build y sugiere cerrarlo en este ciclo. No hay una forma que se pueda escribir de antemano: en Flutter 3.44.9, `FlutterFramework` es un Swift package que **genera la herramienta dentro del proyecto de la app** y que la app agrega por **path relativo** (`swift_package_manager.dart:365-384`). Un plugin no puede declararlo con un path fijo, porque ese path depende del proyecto que lo consuma.

Buscado en `flutter_tools` el 2026-09-21, **no hay ningún warning que nombre `FlutterFramework` dirigido a un plugin**: el aviso que vio el spike puede venir de xcodebuild o de SwiftPM, no de Flutter.

Capturá el mensaje literal antes de decidir:

```bash
cd example
flutter config --enable-swift-package-manager
flutter build ios --no-codesign --debug 2>&1 | tee /tmp/spm-build.log
grep -n -i "flutterframework" /tmp/spm-build.log
```

Nota que acá el pipe sí es correcto: `tee` preserva el flujo y el build se evalúa por el `grep` posterior, no por el exit code de la tubería. Para la verificación de éxito del build, usá el Step 7, que corre sin pipe.

Con el mensaje en mano:
- **Si nombra un símbolo concreto que el plugin deba declarar**, agregalo y volvé a medir que el mensaje desapareció y que los dos empaquetados siguen compilando.
- **Si el mensaje no existe, o es del proyecto de la app y no del plugin**, no toques `Package.swift` y anotalo en el commit. El spec pedía cerrarlo; medir que no hay nada que cerrar también lo cierra.

- [ ] **Step 5: Subir el deployment target donde hace falta**

En `ios/flutter_khipu.podspec`:

```ruby
  s.version          = '2.0.0'
  s.platform = :ios, '15.0'
```

Y en `pubspec.yaml`, **en esta tarea y no en la 6**:

```yaml
version: 2.0.0
```

Van juntos a propósito: `test/package_metadata_test.dart` compara las dos versiones, así que subir una sola deja el test rojo hasta que la otra la alcance, y ninguna tarea puede cerrar con un test rojo.

En `example/ios/Podfile`, dentro del `post_install`, **después** de `flutter_additional_ios_build_settings(target)`:

```ruby
    target.build_configurations.each do |config|
      # flutter_additional_ios_build_settings puts 13.0 back on every pod
      # install, so raising it above is not enough: it has to be forced
      # here. Xcode 27 does not accept anything below 15.0. This is not
      # about the plugin — a bare app fails the same way.
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
```

Y en `example/ios/Runner.xcodeproj/project.pbxproj`, reemplazar todas las apariciones de `IPHONEOS_DEPLOYMENT_TARGET = 13.0;` por `15.0`.

- [ ] **Step 6: Verificar que el test de metadatos sigue cubriendo**

`test/package_metadata_test.dart` compara la versión del podspec contra el pubspec, y el pin de `KhipuClientIOS` entre el podspec y `Package.swift`. Con `2.0.0` en los dos primeros y `2.17.1` sin tocar en los otros, tiene que pasar.

Run: `flutter test test/package_metadata_test.dart`
Expected: PASS. Si falla por versión, es que el Step 5 subió sólo uno de los dos archivos.

- [ ] **Step 7: Recompilar los dos empaquetados**

```bash
cd example/ios && pod install && cd ..
flutter config --enable-swift-package-manager && flutter build ios --no-codesign --debug
flutter config --no-enable-swift-package-manager && flutter clean && flutter build ios --no-codesign --debug
flutter build apk --debug
```

Expected: los tres en verde.

- [ ] **Step 8: Commit**

```bash
git add example ios
git commit -m "chore: move the example to 2.0.0 and close the packaging frictions

The example uses the enums instead of strings, and its options and colours
are const.

Package.swift declares FlutterFramework, which Flutter had been asking for
on every build, and both packaging files move to iOS 15: Xcode 27 rejects
anything below it. The example needed the target raised in three places,
and the Podfile has to force it in post_install because
flutter_additional_ios_build_settings puts 13.0 back on every pod install."
```

---

## Task 6: Documentación, migración y el corte de versión

**Files:**
- Modify: `pubspec.yaml` (`version: 2.0.0`)
- Modify: `README.md` (secciones `Usage` y `Errors`, más una sección de migración)
- Modify: `CHANGELOG.md` (entrada 2.0.0 al tope)

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: el paquete listo para publicar.

- [ ] **Step 1: Confirmar que la versión ya está en 2.0.0**

El bump vive en la Tarea 5, junto al del podspec, porque `test/package_metadata_test.dart` compara los dos y ninguna tarea puede cerrar con un test rojo. Acá sólo se verifica.

Run: `grep '^version:' pubspec.yaml && flutter test test/package_metadata_test.dart`
Expected: `version: 2.0.0` y el test en verde. Si dice `1.9.0`, la Tarea 5 quedó a medias: subilo acá y decilo en el reporte.

- [ ] **Step 2: Escribir la guía de migración en el README**

Agregar una sección `## Migrating from 1.x` antes de `## Usage`:

````markdown
## Migrating from 1.x

Six breaking changes. Most integrations only hit the first two.

### 1. `theme` is an enum

```dart
// 1.x
KhipuStartOperationOptions(operationId: id, theme: 'dark')
// 2.0
const KhipuStartOperationOptions(operationId: id, theme: KhipuTheme.dark)
```

A typo used to be silently ignored — the native side compared the string and
fell through. Now it does not compile.

### 2. `result` is an enum

```dart
// 1.x
if (result?.result == 'OK') { … }
// 2.0
if (result?.result == KhipuResultStatus.ok) { … }
```

The cases are `ok`, `error`, `warning`, `mustContinue`, `userCanceled` and
`unknown`. `mustContinue` is the value the SDK sends as `CONTINUE`; it is
spelled differently because `continue` is a reserved word.

**Handle `unknown`.** It is what you get if the server starts sending a
result this plugin does not know yet. In 1.x that value reached you as a raw
string; treating it as a failure is usually right, but it is your call.

### 3. Five fields are no longer nullable

`operationId`, `result`, `exitTitle`, `exitMessage` and `events` are always
present. They never were null in practice — 1.7.1 widened every field to
`String?` to fix a crash, and widened too far.

```dart
// 1.x
final String title = result!.exitTitle ?? '';
// 2.0
final String title = result!.exitTitle;
```

`exitUrl`, `failureReason` and `continueUrl` stay nullable. They are exactly
the three the native SDKs declare optional.

### 4. `events` is a `List`, never null

```dart
// 1.x
for (final e in result!.events ?? const <KhipuEvent>[]) { … }
// 2.0
for (final e in result!.events) { … }
```

Empty means empty. It is also unmodifiable, and it no longer re-parses on
every pass: in 1.x it was a lazy `Iterable` that re-decoded each time you
iterated it.

### 5. The types are immutable

Fields are `final` and the constructors are `const`. If you were mutating
options after building them, build them with the values instead.

```dart
// 1.x
final options = KhipuStartOperationOptions(operationId: id);
options.title = 'My shop';
// 2.0
const options = KhipuStartOperationOptions(operationId: id, title: 'My shop');
```

They also have `==`, `hashCode` and `toString`, so two results with the same
fields compare equal.

### 6. Two files are gone

`flutter_khipu_platform_interface.dart` and `flutter_khipu_method_channel.dart`
no longer exist. `package:flutter_khipu/flutter_khipu.dart` is the only import,
and it is all you needed unless you were extending the platform interface.
````

- [ ] **Step 3: Actualizar la tabla de errores del README**

De los nueve códigos, **quedan siete**. `BAD_ARGUMENT_DICTIONARY` y `MISSING_OPERATION_ID` desaparecen: el codec de Pigeon rechaza un mensaje malformado antes de que corra el handler, y `operationId` es no nulo en el esquema.

Eso deja **un solo código en las dos plataformas**, `OPERATION_IN_PROGRESS`, y hay que decirlo donde hoy dice "dos de los nueve". Es un cambio que también le toca a docs.khipu.com; anotalo para esa sesión, no lo edites desde acá.

- [ ] **Step 4: Escribir la entrada del CHANGELOG**

Al tope de `CHANGELOG.md`, siguiendo el tono de las entradas existentes: qué cambia para el comercio primero, por qué es un major, y la migración después. Mencioná que la forma del canal ahora se genera desde un esquema, y que por eso la clase de bug que el Ciclo 1 vigilaba con un test de regex dejó de ser posible.

- [ ] **Step 5: Verificar el paquete entero**

```bash
flutter analyze
flutter test
dart pub publish --dry-run
```

Expected: sin issues, todos los tests en verde, dry run limpio y el tarball muy por debajo de 5 MB.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml README.md CHANGELOG.md
git commit -m "docs: 2.0.0, and how to move a 1.x integration onto it

Six breaking changes, each with its before and after. Two error codes are
gone because the generated codec rejects those messages before the handler
runs, which leaves OPERATION_IN_PROGRESS as the only code both platforms
share."
```

---

## Gate de salida (§8)

El ciclo no se cierra sin esto. Lo de arriba son los tests de cada tarea; esto es el gate del ciclo.

- [ ] `flutter analyze` sin issues y `flutter test` en verde.
- [ ] `./gradlew :flutter_khipu:test` en verde.
- [ ] El job de CI que regenera y compara no encuentra diferencias.
- [ ] `dart pub publish --dry-run` limpio, tarball bajo el tope de 5 MB.
- [ ] Build del example en Android, y en iOS con SPM **y** con CocoaPods.
- [ ] En simulador, con Khipu presentado sobre un pago real: una segunda `startOperation` devuelve `OPERATION_IN_PROGRESS`. Por UI es inalcanzable —Khipu tapa la pantalla entera—, así que el example tiene que disparar la segunda llamada desde adentro a los 3 segundos y reportar qué devolvió **la segunda**.
- [ ] Pago real de punta a punta en Android y en iOS, contra un `operationId` de demo distinto en cada plataforma. El criterio es que el SDK devuelva el desenlace y el `Future` complete.
- [ ] Las tres vías de cancelación llegan como `KhipuResultStatus.userCanceled` y no como un cuelgue.
- [ ] Un valor de estado desconocido llega como `KhipuResultStatus.unknown` y no rompe el mensaje. Se mide sustituyendo el `statusOf` nativo por uno que devuelva una cadena inventada, no esperando a que el servidor emita uno.
- [ ] Publicado en pub.dev y tagueado `2.0.0` — tag ligero, sin prefijo `v`.
- [ ] Validado desde cero con una app nueva siguiendo docs.khipu.com, no el README del repo.
