# Migración de `flutter_khipu` a Swift Package Manager — Diseño

**Fecha:** 2026-09-04
**Estado:** Decisiones confirmadas. Pendiente: plan + ejecución.
**Repo:** `khipu/flutter_khipu`
**Contexto:** `KhipuClientIOS` ya está disponible vía SPM desde `2.16.3` (ver su propio spec,
`docs/superpowers/specs/2026-06-28-spm-khipuclientios-design.md` en `khipu/KhipuClientIOS`).
Este trabajo es el eslabón siguiente: hacer que el plugin Flutter deje de exigir CocoaPods.

## 1. Objetivo

Agregar soporte SPM al lado iOS de `flutter_khipu`, **dual con CocoaPods**, de modo que una app
Flutter pueda consumir el plugin sin CocoaPods instalado. Android no se toca.

### Por qué importa

Flutter cae a CocoaPods si **cualquier** plugin del proyecto no soporta SPM. Hoy `flutter_khipu`
es ese plugin: un comercio que quiera una app sin CocoaPods queda bloqueado por nosotros. Desde
Flutter 3.44 SPM es el default, así que el problema ya está activo, no es a futuro.

## 2. Estado actual (verificado)

| Ítem | Valor |
|---|---|
| Versión del plugin | `1.6.1` |
| `pubspec.yaml` | `sdk: '>=3.4.1 <4.0.0'`, `flutter: '>=3.3.0'` |
| Fuente iOS | un solo archivo: `ios/Classes/FlutterKhipuPlugin.swift` (~160 líneas) |
| Podspec | `s.platform = :ios, '12.0'`; `s.dependency 'KhipuClientIOS', '2.16.2'` |
| Metadata del podspec | template sin editar: `'A new Flutter plugin project.'`, `http://example.com`, `'Your Company' => 'email@example.com'` |
| Assets propios del plugin | ninguno (`ios/Assets/` solo tiene `.gitkeep`) |
| `example/ios` — proyecto | `IPHONEOS_DEPLOYMENT_TARGET = 12.0` (3 ocurrencias) |
| `example/ios/Podfile` | `platform :ios, '15.0'` (ya inconsistente con el proyecto) |
| `example/ios` — xcscheme compartido | existe (`Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`), requisito de la migración SPM |
| CI | no existe (`.github/` ausente) |
| README | dice *"At this moment there is no need for special setup for iOS development"* |

### Versión de Flutter

Local actual: **3.38.4** (2025-12-03, Dart 3.10.3). **Se actualiza a `3.44.9`** para este trabajo
(ver decisión §3.6). Matriz verificada leyendo el código fuente de cada tag:

| Flutter | iOS deployment target (`darwin/darwin.dart`) | SPM por defecto (`features.dart`) |
|---|---|---|
| 3.38.4 (actual) | 13.0 | opt-in (`available: true`) |
| 3.41.x | 13.0 | opt-in |
| **3.44.0 – 3.44.9** | **13.0** | **`enabledByDefault: true`** |
| 3.47.0 – 3.47.2 (stable actual) | **15.0** | `enabledByDefault: true` |

### Soporte de la herramienta

- Detección de soporte SPM (`plugins.dart:443-465`): el tool solo comprueba que exista
  `ios/<plugin_name>/Package.swift`. **No hay nada que declarar en `pubspec.yaml`**, y podspec y
  `Package.swift` coexisten — el tool elige según el flag. De ahí que la compatibilidad dual sea real.
- El deployment target iOS de Flutter (13.0 en 3.38–3.44) hace que el mínimo iOS 13 que exige el SPM
  de Khipu no sea una regresión para nadie en Flutter moderno.

### `KhipuClientIOS` (upstream)

| Ítem | Valor |
|---|---|
| Repo SPM | `https://github.com/khipu/KhipuClientIOS.git` |
| SPM disponible desde | `2.16.3` · último tag **`2.16.4`** |
| `platforms` en su `Package.swift` | `.iOS(.v13)` |
| `deployment_target` en su podspec | `12.0` (dual con mínimos distintos) |
| Product | `KhipuClientIOS` |
| Recursos | resueltos vía `KhipuClientBundleHelper` con `#if SWIFT_PACKAGE → Bundle.module` |

**Sondeo de resolución ejecutado** (`swift package resolve` contra el repo real, con los nombres
definitivos del plugin y `exact: "2.16.4"`): resuelve correctamente en 6 paquetes —
`khipuclientios 2.16.4`, `khenshinprotocolswift 1.0.60`, `khenshinsecuremessage 1.4.1`,
`socket.io-client-swift 16.1.1`, `starscream 4.0.8`, `tweetnacl-swiftwrap 1.1.5`.
**`ViewInspector` no se descarga**: SPM poda las dependencias usadas solo por test targets de
paquetes no-raíz, así que las deps de testing de upstream no contaminan al consumidor.

**Validación de recursos ejecutada** (paquete SPM consumidor de `KhipuClientIOS 2.16.4` + XCTest en
simulador iOS 18.1, 6/6 tests verdes). El bundle generado es
`KhipuClientIOS_KhipuClientIOS.bundle`, resuelto vía `Bundle.module`, y **`.process("Assets")` aplana
la jerarquía**: los subdirectorios `Images/`, `Fonts/`, `HTML/` y `Resources/` desaparecen y todo
queda en la raíz del bundle:

```
[Assets.car, Info.plist, PublicSans-{Bold,Medium,Regular,SemiBold}.ttf,
 authorize.png, khipuClient.html, logo-khipu-color.png]

logo-khipu-color -> OK (45.0, 15.0)     authorize        -> OK (400.0, 400.0)
PublicSans-Bold  -> OK (registrada)     khipuClient.html -> OK
```

Esto **descarta la hipótesis de los PNG sueltos** que el spec de `KhipuClientIOS` §5 dejó como riesgo
abierto: la raíz del bundle es exactamente donde `UIImage(named:in:)`,
`Bundle.url(forResource:withExtension:)` y `CTFontManagerRegisterFontsForURL` buscan. No se requiere
ninguna versión nueva de `KhipuClientIOS`, ni mover los PNG a un `Images.xcassets`. `FontLoader` ya
está migrado a `Bundle.module` bajo `#if SWIFT_PACKAGE`.

## 3. Decisiones confirmadas

1. **Dual CocoaPods + SPM.** El podspec se mantiene funcional.
2. **iOS 13.0 en ambos caminos** del plugin (podspec y `Package.swift`), un solo mínimo que documentar.
3. **`KhipuClientIOS 2.16.4` con pin exacto en ambos caminos.** Política: el plugin es la compuerta
   de versiones — se libera una versión nueva del plugin cuando sale una versión nueva de la biblioteca.
   **El pin exacto garantiza la versión de `KhipuClientIOS` en sí, no de su árbol completo**: su
   podspec fija las transitivas exactas (`Socket.IO-Client-Swift 16.1.1`, `Starscream 4.0.8`,
   `KhenshinSecureMessage 1.4.1`, `KhenshinProtocolSwift 1.0.60`), pero su `Package.swift` las declara
   con rangos abiertos (`from:`). Nuestro `exact:` no cierra esa brecha — si upstream publica p. ej.
   `KhenshinProtocolSwift 1.0.61`, CocoaPods y SPM pueden resolver árboles transitivos distintos para
   la misma versión del plugin. **Esta brecha es de upstream y solo acotable, no cerrable del todo**:
   aunque `KhipuClientIOS` endureciera sus rangos a `exact:`/`.upToNextMinor`, `Starscream` seguiría
   flotando, porque no es una dependencia declarada de `KhipuClientIOS` — llega transitivamente vía
   `socket.io-client-swift 16.1.1`, cuyo propio manifiesto la declara
   `.upToNextMajor(from: "4.0.8")`. Cerrarlo del todo exigiría que upstream declare `Starscream`
   directo, lo que choca con una omisión deliberada de su diseño SPM. Es una limitación conocida y
   acotada, no un arreglo pendiente.
4. **Validación de los dos caminos, más una corrida sin CocoaPods** (desechable, ver §9).
5. **Versión del plugin: `1.7.0`.** El piso iOS 12→13 es nominalmente breaking, pero Flutter ya
   impone iOS 13 desde antes, así que en la práctica no afecta a nadie en Flutter moderno; y sigue la
   convención del CHANGELOG, donde los bumps de SDK han sido minor/patch.
6. **Actualizar el Flutter local a `3.44.9`.** Es la versión donde SPM pasa a ser el default, así que
   se valida la configuración en que están los comercios de verdad, y mantiene el piso iOS en 13,
   coherente con lo que el plugin declara. **No se salta a 3.47.x** porque esa serie sube el piso iOS
   a 15: es un cambio con consecuencias propias para los comercios y merece su propio release, no ir
   acoplado a esta migración. Actualizar el SDK de desarrollo **no baja la compatibilidad del plugin**
   — eso lo gobiernan el `flutter: '>=3.3.0'` del `pubspec.yaml` y que el podspec siga funcionando.

## 4. Layout de archivos

```
ios/
├── flutter_khipu/                            ← nuevo: el Swift package
│   ├── Package.swift
│   └── Sources/
│       └── flutter_khipu/
│           └── FlutterKhipuPlugin.swift      ← movido sin editar desde ios/Classes/
├── flutter_khipu.podspec                     ← se queda, apuntando al path nuevo
├── Classes/                                  ← se elimina
└── Assets/                                   ← se elimina (.gitkeep, nunca tuvo assets)
```

### El movimiento de archivos es forzado

Se evaluó la alternativa de dejar las fuentes en `ios/Classes` y apuntarlas con `path:`, como hizo
upstream (`path: "KhipuClientIOS", sources: ["Classes"]`). **No es viable acá.** Flutter exige el
manifiesto en `ios/<plugin_name>/Package.swift`, y desde ahí `Classes` queda fuera de la raíz del
paquete. Comprobado empíricamente:

```
error: target 'pkg' in package 'pkg' is outside the package root
```

`KhipuClientIOS` pudo hacerlo porque su `Package.swift` vive en la raíz de su repo.

## 5. `ios/flutter_khipu/Package.swift`

Validado: esta declaración resuelve correctamente (§2).

```swift
// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_khipu",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "flutter-khipu", targets: ["flutter_khipu"])
    ],
    dependencies: [
        .package(url: "https://github.com/khipu/KhipuClientIOS.git", exact: "2.16.4")
    ],
    targets: [
        .target(
            name: "flutter_khipu",
            dependencies: [
                .product(name: "KhipuClientIOS", package: "KhipuClientIOS")
            ]
        )
    ]
)
```

### Reglas de nombres (requisito del tool)

- nombre del package = nombre del plugin = `flutter_khipu`
- nombre del target = nombre del plugin = `flutter_khipu`
- nombre del product library = `_` reemplazado por `-` = `flutter-khipu`

### Sin dependencia de `FlutterFramework`

El template de `flutter/flutter@master` agrega
`.package(name: "FlutterFramework", path: "../FlutterFramework")`, lo que plantea una duda de
compatibilidad hacia adelante. **No es obligatorio:** de los 19 `Package.swift` first-party en
`flutter/packages@main`, solo `video_player_avfoundation` lo declara; los otros 18 —incluido
`url_launcher_ios`, con CI contra master— usan `dependencies: []`. El framework se inyecta por search
paths. Validar sobre 3.44.9, donde SPM es el default (§9), comprueba esto en la práctica en vez de
dejarlo inferido.

## 6. `ios/flutter_khipu.podspec`

Cambios funcionales: `source_files` al path nuevo, `platform` a 13.0, pod a `2.16.4`. Se corrige de
paso la metadata del template, ya que el archivo se reescribe igual.

```ruby
  s.name         = 'flutter_khipu'
  s.version      = '0.0.1'
  s.summary      = 'Flutter plugin for Khipu payments.'
  s.description  = <<-DESC
Flutter plugin for Khipu, this plugin enables a flutter app to use Khipu to authorize payments.
                   DESC
  s.homepage     = 'https://github.com/khipu/flutter_khipu'
  s.license      = { :file => '../LICENSE' }
  s.author       = { 'Khipu' => 'developers@khipu.com' }
  s.source       = { :path => '.' }
  s.source_files = 'flutter_khipu/Sources/flutter_khipu/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'KhipuClientIOS', '2.16.4'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
```

Se dejan intactos a propósito:

- **`s.version = '0.0.1'`** — convención de Flutter para pods locales por path; sincronizarla con
  `pubspec.yaml` sería un bump en dos lugares sin beneficio.
- **`pod_target_xcconfig` completo, incluido `EXCLUDED_ARCHS ... i386`** — es peso muerto desde
  Xcode 12, pero el camino CocoaPods es el que no debe romperse. Se deja idéntico; limpiarlo es un
  cambio aparte.

## 7. Código Swift: cero cambios

`FlutterKhipuPlugin.swift` se mueve sin editar. **No necesita `#if SWIFT_PACKAGE`** porque el plugin
no empaqueta recursos propios: todos los assets (fuentes, `Colors.xcassets`, `khipuClient.html`, PNGs)
viven dentro de `KhipuClientIOS`, que ya los resuelve upstream vía `Bundle.module`.

## 8. Archivos restantes

| Archivo | Cambio |
|---|---|
| `example/ios/Runner.xcodeproj/project.pbxproj` | `IPHONEOS_DEPLOYMENT_TARGET` 12.0 → 13.0 (3 ocurrencias) |
| `example/ios/Podfile` | `platform :ios, '15.0'` → `'13.0'`, para alinear con el piso real. **El Podfile se mantiene commiteado**: es lo que permite validar la regresión CocoaPods |
| `ios/.gitignore` | agregar `.build/` y `.swiftpm/` |
| `pubspec.yaml` | `version: 1.6.1` → `1.7.0`. **`flutter: '>=3.3.0'` se mantiene**: un Flutter viejo ignora el `Package.swift` y usa el podspec, así que bajar la compatibilidad no aportaría nada |
| `CHANGELOG.md` | entrada `1.7.0`: soporte SPM, mínimo iOS 13, `KhipuClientIOS 2.16.4` |
| `README.md` | reemplazar *"no need for special setup for iOS"* por una sección iOS: mínimo iOS 13 y soporte de CocoaPods y SPM |

### Migración automática del proyecto Xcode del example

Al correr el example con SPM activo, el tool modifica por su cuenta
`example/ios/Runner.xcodeproj/project.pbxproj` (agrega `FlutterGeneratedPluginSwiftPackage` como
dependencia del target) y `Runner.xcscheme` (agrega la pre-acción *Run Prepare Flutter Framework
Script*). **Esos cambios se commitean**: son lo que hace que el example efectivamente ejercite el
camino SPM. Degradan bien en Flutter viejo — con el flag apagado el tool genera un `Package.swift`
sin dependencias (`flutterAsADependency: false` en `darwin_dependency_management.dart`).

## 9. Gate de validación

**Paso 0 — línea base, antes de tocar nada.** Con el Flutter actual (3.38.4) y el plugin sin
modificar, correr `cd example && flutter run` y dejar constancia de que funciona. Es gratis ahora y
después ya no se puede: es la única medición del comportamiento previo a la migración.

Luego actualizar a `3.44.9` y ejecutar el resto. Ojo: en 3.44 SPM es el default, así que el camino
CocoaPods hay que forzarlo explícitamente.

1. **Regresión CocoaPods** — `flutter config --no-enable-swift-package-manager`, luego
   `cd example && flutter run`.
2. `pod lib lint ios/flutter_khipu.podspec --configuration=Debug --skip-tests --use-modular-headers`
3. **SPM** — `flutter config --enable-swift-package-manager` (obligatorio acá: el paso 1 lo apagó
   globalmente), `cd example && flutter run`. Confirmar en Xcode: `Package Dependencies` presente y
   `FlutterGeneratedPluginSwiftPackage` como dependencia del target `Runner`.
4. **Runtime real bajo SPM.** Lanzar un pago y confirmar que la UI de Khipu renderiza fuentes,
   colores e imágenes. Los pasos 1-3 solo prueban que compila; **este prueba que funciona**. Cierra
   el paso `8.4` que el spec de `KhipuClientIOS` dejó pendiente (*"Consumidor SPM iOS real desde el
   tag 2.16.3"*). Tras la validación de recursos de §2 esto es una **confirmación**, no una sospecha:
   lo único que queda por verificar es que Xcode copie el resource bundle dentro de la app.
5. **Sin CocoaPods** — `cd example/ios && pod deintegrate`; borrar `Podfile`, `Podfile.lock`, `Pods/`,
   `.symlinks/`; quitar los `#include` de CocoaPods en `Flutter/Debug.xcconfig` y
   `Flutter/Release.xcconfig`; `flutter clean && flutter run`. **Revertir con `git checkout` al
   terminar** — el example no puede estar con y sin Podfile a la vez.
6. `flutter analyze` y `flutter test` — los tests Dart no se ven afectados por la migración; acá
   sirven de control de que el salto de SDK no rompió nada del lado Dart.

## 10. Riesgos

| Riesgo | Nivel | Mitigación |
|---|---|---|
| Que el resource bundle de `KhipuClientIOS` no se copie dentro de la app Flutter con enlazado estático vía `FlutterGeneratedPluginSwiftPackage` | **Bajo** | La hipótesis de los PNG sueltos quedó **descartada empíricamente** (§2): los recursos se resuelven bien en un consumidor SPM real. Lo que resta es que Xcode copie el bundle, camino rutinario de su integración SPM. El paso 4 del gate lo confirma |
| Un comercio que declare `KhipuClientIOS` directo vía SPM con `from:` entrará en conflicto duro con nuestro `exact:` | Conocido y aceptado | Consecuencia deliberada de la política de §3.3: la resolución es liberar la versión del plugin que corresponda |
| El salto de SDK 3.38.4 → 3.44.9 rompa algo del lado Dart (`flutter_lints: ^3.0.0` quedó viejo) | Bajo | Paso 6 del gate. Si `flutter analyze` se queja, bumpear `flutter_lints` es un cambio aparte y acotado |
| `RunnerTests` pierde sus `search_paths` al deintegrar pods | Bajo | Solo afecta el paso 5, que es desechable |
| `FlutterFramework` se vuelva obligatorio en un Flutter futuro | Bajo | 18/19 plugins first-party no lo declaran; validar en 3.44.9 lo comprueba; sería un cambio aditivo de una línea |
| Que CocoaPods y SPM resuelvan transitivas distintas de `KhipuClientIOS` (su podspec las fija exactas, su `Package.swift` usa `from:`) si upstream publica una versión nueva de una de ellas | Bajo | Nuestro `exact:` en `KhipuClientIOS` no lo cierra — es una brecha de upstream, no de este plugin, y solo acotable: `Starscream` llega vía `socket.io-client-swift` como `.upToNextMajor(from: "4.0.8")` y no como dependencia directa de `KhipuClientIOS`, así que ni endureciendo sus rangos a `exact:` upstream la fijaría del todo |

## 11. Fuera de alcance

- **Android** — usa Gradle, no le afecta nada de esto.
- **El salto a Flutter 3.47.x y su piso iOS 15** — decisión separada, con consecuencias propias para
  los comercios y su propio release.
- **`UIApplication.shared.windows`** en `FlutterKhipuPlugin.swift`, deprecado desde iOS 15 y con
  comportamiento dudoso en apps multi-scene. Bug preexistente; el archivo se mueve sin editar.
- **Bumpear `flutter_lints`** — solo si el paso 6 del gate lo exige.
- **CI** — el repo no tiene `.github/`. Montarla es un trabajo aparte.
- **Limpieza del `EXCLUDED_ARCHS ... i386`** del podspec (ver §6).

## 12. Referencias

- Doc del cliente iOS: `https://docs.khipu.com/payment-solutions/instant-payments/khipu-client-ios`
- Spec upstream: `khipu/KhipuClientIOS` → `docs/superpowers/specs/2026-06-28-spm-khipuclientios-design.md`
- Flutter, autores de plugins: `https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors`
- Referencia de layout real: `url_launcher_ios` en `flutter/packages@main`
