# Migración de `flutter_khipu` a Swift Package Manager — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que el lado iOS de `flutter_khipu` se pueda consumir vía Swift Package Manager sin CocoaPods, manteniendo el camino CocoaPods intacto para los comercios actuales.

**Architecture:** Se agrega `ios/flutter_khipu/Package.swift` junto al podspec existente. Flutter detecta el soporte SPM por la sola presencia de ese archivo y elige camino según su feature flag, así que ambos coexisten. Las fuentes se mueven a `ios/flutter_khipu/Sources/flutter_khipu/` (obligatorio: SPM prohíbe que el path de un target escape la raíz del paquete) y el podspec se reapunta ahí.

**Tech Stack:** Flutter 3.44.9 · Swift 5.9 / swift-tools-version 5.9 · SPM · CocoaPods 1.16.2 · Xcode 26.6 · `KhipuClientIOS 2.16.4`

**Spec:** `docs/superpowers/specs/2026-09-04-spm-flutter-khipu-design.md`

## Global Constraints

- **Compatibilidad dual obligatoria.** El podspec debe seguir funcionando en todo momento. Nunca se elimina.
- **iOS 13.0** en ambos caminos: `s.platform = :ios, '13.0'` en el podspec y `.iOS("13.0")` en `Package.swift`.
- **`KhipuClientIOS 2.16.4` con pin exacto en ambos caminos**: `s.dependency 'KhipuClientIOS', '2.16.4'` y `exact: "2.16.4"`. El plugin es la compuerta de versiones.
- **Nombres, requisito del tool de Flutter**: package `flutter_khipu`, target `flutter_khipu`, product library `flutter-khipu` (guion, no guion bajo).
- **`swift-tools-version: 5.9`**.
- **`Package.swift` sin dependencia de `FlutterFramework`** — `dependencies` solo lleva `KhipuClientIOS`. El framework se inyecta por search paths.
- **`pubspec.yaml`: `flutter: '>=3.3.0'` NO se toca.** Bajar la compatibilidad declarada no aportaría nada: un Flutter viejo ignora el `Package.swift` y usa el podspec.
- **`FlutterKhipuPlugin.swift` se mueve sin editar una sola línea.**
- **Versión del plugin: `1.7.0`.**
- **Android no se toca.**

---

## Nota sobre el ciclo de verificación

Esta migración no agrega superficie Dart, así que no hay tests unitarios nuevos que escribir: los
tests Dart existentes (`test/`) son un control de regresión, no la verificación del cambio. El ciclo
de test acá es otro, y cada tarea lo trae explícito:

| Verificación | Qué prueba |
|---|---|
| `swift package describe` | el manifiesto carga y los nombres son los correctos |
| `swift package resolve` | la dependencia resuelve y queda fijada en 2.16.4 |
| `pod lib lint` | el camino CocoaPods sigue sano |
| `flutter run` en `example/` | el plugin compila y enlaza en una app real, por cada camino |
| lanzar un pago en el example | los recursos de Khipu llegan a la app (el único test de runtime) |

**Advertencia sobre `--no-codesign`.** Para verificar que algo *compila y enlaza* es correcto usar
`flutter build ios --simulator --no-codesign`, y es lo que permite automatizar los pasos que de otro
modo exigirían el `flutter run` interactivo. Pero **nunca para la validación de runtime**: esa
bandera produce una firma *linker-signed* (`flags 0x20002`) que deja al proceso sin acceso al
Keychain, y entonces cualquier llamada a `SecItem*` devuelve `-34018`
(`errSecMissingEntitlement`). Medido con una sonda en la app:

| Build | Firma | `SecItemDelete` / `SecItemAdd` |
|---|---|---|
| `--simulator --no-codesign` | `0x20002` adhoc, linker-signed | `-34018` / `-34018` |
| `--simulator` | `0x2` adhoc | `-25300` / `0` |

No es la sección de entitlements —el build que funciona tampoco la tiene— sino el tipo de firma.
Esto importa porque el flujo de pago de Khipu toca el Keychain al recordar credenciales, así que un
build con `--no-codesign` crashea ahí por una razón que no tiene nada que ver con lo que se está
validando. **El paso 4 usa un build sin `--no-codesign`.**

**Línea base ya medida en la rama, antes de cualquier cambio:**
`pod lib lint ios/flutter_khipu.podspec --configuration=Debug --skip-tests --use-modular-headers --allow-warnings`
→ `flutter_khipu passed validation.`

## Estructura de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `ios/flutter_khipu/Package.swift` | **crear** — manifiesto SPM del plugin: nombres, piso iOS, dependencia a `KhipuClientIOS` | 2 |
| `ios/flutter_khipu/Sources/flutter_khipu/FlutterKhipuPlugin.swift` | **mover** desde `ios/Classes/`, sin editar — el `FlutterPlugin` que puentea el method channel a `KhipuLauncher` | 2 |
| `ios/flutter_khipu.podspec` | **modificar** — reapuntar `source_files`, subir piso a 13.0, pod a 2.16.4, corregir metadata del template | 2 |
| `ios/.gitignore` | **modificar** — ignorar los artefactos que genera SPM | 2 |
| `ios/Classes/`, `ios/Assets/` | **eliminar** — quedan vacíos tras el movimiento | 2 |
| `example/ios/Runner.xcodeproj/project.pbxproj` | **modificar** — piso iOS a 13.0; más adelante recibe la migración automática de SPM | 3, 4 |
| `example/ios/Podfile` | **modificar** — `platform :ios, '13.0'`. Se mantiene commiteado: es lo que permite validar la regresión CocoaPods | 3 |
| `example/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | **modificar** (por el tool) — pre-acción *Run Prepare Flutter Framework Script* | 4 |
| `pubspec.yaml` | **modificar** — solo `version: 1.7.0` | 6 |
| `CHANGELOG.md` | **modificar** — entrada 1.7.0 | 6 |
| `README.md` | **modificar** — sección iOS real en lugar de *"no need for special setup"* | 6 |

---

### Task 1: Línea base y actualización de Flutter a 3.44.9

**Files:** ninguno. Es trabajo de entorno; no se commitea nada.

**Interfaces:**
- Consumes: nada.
- Produces: un Flutter 3.44.9 operativo, con SPM activo por defecto, y constancia de que el plugin sin modificar funciona.

El orden importa: la línea base se mide **antes** de actualizar y antes de tocar código. Después ya no
se puede.

- [ ] **Step 1: Confirmar el punto de partida**

```bash
cd /Users/edavis/git/flutter_khipu
git branch --show-current          # esperado: spm-migration
git status --short                 # esperado: sin cambios
flutter --version | head -1        # esperado: Flutter 3.38.4
```

- [ ] **Step 2: Arrancar un simulador iOS**

```bash
xcrun simctl boot 93EFD59E-34E4-4C5B-BF4F-18425C6F561E   # iPhone 16, iOS 18.1
open -a Simulator
xcrun simctl list devices | grep Booted
```

Esperado: el iPhone 16 aparece como `Booted`. Si ese UDID ya no existe, elegir otro con
`xcrun simctl list devices available | grep iPhone`.

- [ ] **Step 3: Línea base — el example corre con CocoaPods en 3.38.4**

```bash
cd /Users/edavis/git/flutter_khipu/example
flutter pub get
flutter run -d 93EFD59E-34E4-4C5B-BF4F-18425C6F561E
```

Esperado: la app compila, se instala y arranca mostrando el formulario de opciones. No hace falta
lanzar un pago: lo que se está midiendo es que compila y enlaza. Anotar el resultado. Salir con `q`.

- [ ] **Step 4: Actualizar el SDK de Flutter a 3.44.9**

```bash
cd /Users/edavis/bin/flutter
git fetch --tags
git checkout 3.44.9
flutter --version
```

Esperado: `Flutter 3.44.9`. Queda en HEAD desacoplado, que es lo normal al fijar un tag; para volver
al canal, `git checkout stable`.

- [ ] **Step 5: Precachear los artefactos de iOS**

```bash
flutter precache --ios
flutter doctor -v 2>&1 | head -30
```

Esperado: `flutter doctor` sin errores en las secciones de Xcode y CocoaPods.

- [ ] **Step 6: Confirmar que SPM viene activo por defecto**

```bash
cd /Users/edavis/git/flutter_khipu
flutter config --list | grep -i swift
```

Esperado: `enable-swift-package-manager: (Not set)`. En 3.44 "not set" significa **activo**, porque
el feature trae `enabledByDefault: true` en el canal stable. No hay que encender nada.

- [ ] **Step 7: Control de regresión del lado Dart tras el salto de SDK**

```bash
cd /Users/edavis/git/flutter_khipu
flutter pub get
flutter analyze
flutter test
```

Esperado: `flutter test` en verde (`test/flutter_khipu_test.dart`,
`test/flutter_khipu_method_channel_test.dart`). Si `flutter analyze` reporta problemas nuevos por el
`flutter_lints: ^3.0.0` viejo, **anotarlos y seguir**: bumpear los lints está fuera del alcance de
este plan (spec §11). Solo detenerse si `flutter test` falla.

Sin commit: nada de esta tarea cambia el repo.

---

### Task 2: Crear el Swift package y reapuntar el podspec

**Files:**
- Create: `ios/flutter_khipu/Package.swift`
- Create: `ios/flutter_khipu/Sources/flutter_khipu/FlutterKhipuPlugin.swift` (movido desde `ios/Classes/FlutterKhipuPlugin.swift`)
- Modify: `ios/flutter_khipu.podspec`
- Modify: `ios/.gitignore`
- Delete: `ios/Classes/`, `ios/Assets/`

**Interfaces:**
- Consumes: Flutter 3.44.9 operativo (Task 1).
- Produces: el paquete SPM `flutter_khipu` con product library `flutter-khipu` y target `flutter_khipu`, que expone la clase `FlutterKhipuPlugin` (`public class FlutterKhipuPlugin: NSObject, FlutterPlugin`, con `public static func register(with:)` y `public func handle(_:result:)`) y depende del product `KhipuClientIOS`. El podspec pasa a leer las fuentes desde `flutter_khipu/Sources/flutter_khipu/**/*.swift`.

Los cuatro cambios son atómicos: mover las fuentes rompe el podspec, así que entran juntos o no entran.

- [ ] **Step 1: Mover la fuente Swift al layout de SPM**

```bash
cd /Users/edavis/git/flutter_khipu
mkdir -p ios/flutter_khipu/Sources/flutter_khipu
git mv ios/Classes/FlutterKhipuPlugin.swift ios/flutter_khipu/Sources/flutter_khipu/FlutterKhipuPlugin.swift
git rm -r --quiet ios/Assets
rmdir ios/Classes 2>/dev/null || true
git status --short
```

Esperado: un rename de `FlutterKhipuPlugin.swift` y el borrado de `ios/Assets/.gitkeep`. `ios/Classes`
y `ios/Assets` desaparecen. **No editar el contenido del archivo movido.**

- [ ] **Step 2: Escribir `Package.swift`**

Crear `ios/flutter_khipu/Package.swift` con exactamente esto:

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

- [ ] **Step 3: Verificar que el manifiesto carga y los nombres son los correctos**

```bash
cd /Users/edavis/git/flutter_khipu/ios/flutter_khipu
swift package describe 2>&1 | grep -E "^Name:|Path:|Modules:|Type:|C99name:|Product|Target" | head -20
```

Esperado: `Name: flutter_khipu`, un product `flutter-khipu` de tipo library y un target
`flutter_khipu`. Si sale `error: target 'flutter_khipu' ... outside the package root`, la fuente
quedó en el lugar equivocado — revisar el Step 1.

Nota: no correr `swift build` ni `swift test` acá. El target hace `import Flutter`, que solo existe
dentro de una build de Flutter; compilarlo suelto falla por diseño. Quien prueba la compilación real
es `flutter run` (Task 4).

- [ ] **Step 4: Verificar que la dependencia resuelve y queda fijada**

```bash
cd /Users/edavis/git/flutter_khipu/ios/flutter_khipu
swift package resolve
python3 -c "
import json; d=json.load(open('Package.resolved'))
pins = d.get('pins') or d.get('object',{}).get('pins',[])
for p in sorted(pins, key=lambda x: x.get('identity','')):
    print(' ', p.get('identity'), (p.get('state') or {}).get('version'))
"
```

Esperado exactamente estos 6, con `khipuclientios` en `2.16.4`:

```
  khenshinprotocolswift 1.0.60
  khenshinsecuremessage 1.4.1
  khipuclientios 2.16.4
  socket.io-client-swift 16.1.1
  starscream 4.0.8
  tweetnacl-swiftwrap 1.1.5
```

`ViewInspector` **no** debe aparecer: es dependencia solo de los tests de `KhipuClientIOS`, y SPM poda
las deps de test de paquetes no-raíz. Si aparece, algo está mal en el manifiesto.

- [ ] **Step 5: Reapuntar el podspec y corregir su metadata**

Reemplazar el contenido completo de `ios/flutter_khipu.podspec` por:

```ruby
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_khipu.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_khipu'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for Khipu payments.'
  s.description      = <<-DESC
Flutter plugin for Khipu, this plugin enables a flutter app to use Khipu to authorize payments.
                       DESC
  s.homepage         = 'https://github.com/khipu/flutter_khipu'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Khipu' => 'developers@khipu.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_khipu/Sources/flutter_khipu/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'KhipuClientIOS', '2.16.4'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
```

Dos cosas se dejan como están, a propósito: `s.version = '0.0.1'` es la convención de Flutter para
pods locales por path (sincronizarla con `pubspec.yaml` sería un bump en dos lugares sin beneficio), y
el `pod_target_xcconfig` se mantiene íntegro —`EXCLUDED_ARCHS ... i386` incluido— porque el camino
CocoaPods es el que no debe romperse. Limpiar ese `i386` muerto es un cambio aparte (spec §11).

- [ ] **Step 6: Verificar que el camino CocoaPods sigue sano**

```bash
cd /Users/edavis/git/flutter_khipu
pod lib lint ios/flutter_khipu.podspec --configuration=Debug --skip-tests --use-modular-headers --allow-warnings 2>&1 | tail -5
```

Esperado: `flutter_khipu passed validation.` — el mismo resultado que la línea base. Si falla con
`No such file or directory` en las fuentes, el `source_files` del Step 5 no coincide con dónde quedó
el archivo en el Step 1.

- [ ] **Step 7: Ignorar los artefactos que genera SPM**

Agregar al final de `ios/.gitignore`:

```
# Swift Package Manager
.build/
.swiftpm/
Package.resolved
```

`Package.resolved` se ignora porque el Step 4 lo genera y para un paquete-biblioteca no aporta nada:
los consumidores lo descartan. `url_launcher_ios` en `flutter/packages@main` tampoco lo commitea.

- [ ] **Step 8: Confirmar que no queda basura para commitear**

```bash
cd /Users/edavis/git/flutter_khipu
git status --short
```

Esperado: solo el rename, el borrado de `ios/Assets/.gitkeep`, el `Package.swift` nuevo, el podspec y
el `.gitignore`. **No debe aparecer** `ios/flutter_khipu/.build/`, `.swiftpm/` ni `Package.resolved`.
Si aparecen, el Step 7 quedó mal escrito.

- [ ] **Step 9: Commit**

```bash
cd /Users/edavis/git/flutter_khipu
git add ios/
git commit -m "feat(ios): add Swift Package Manager support alongside CocoaPods

Adds ios/flutter_khipu/Package.swift so Flutter can build the plugin as a
Swift package, which lets an app drop CocoaPods entirely. The podspec stays
and keeps working, so current merchants are unaffected.

Sources move to ios/flutter_khipu/Sources/flutter_khipu/ because SPM refuses
a target path outside the package root, and Flutter mandates the manifest at
ios/<plugin_name>/Package.swift. FlutterKhipuPlugin.swift is unchanged.

Raises the iOS floor to 13.0 on both paths and pins KhipuClientIOS 2.16.4
exactly on both. That pin is at the KhipuClientIOS level only — its own
Package.swift uses open ranges for its transitives, so upstream still
governs whether both paths resolve the same transitive graph."
```

---

### Task 3: Alinear el example a iOS 13 y validar la regresión CocoaPods

**Files:**
- Modify: `example/ios/Runner.xcodeproj/project.pbxproj` (3 ocurrencias de `IPHONEOS_DEPLOYMENT_TARGET`)
- Modify: `example/ios/Podfile:1`

**Interfaces:**
- Consumes: el plugin con `Package.swift` y podspec nuevo (Task 2).
- Produces: un example con piso iOS 13.0 coherente, y la prueba de que el camino CocoaPods sigue funcionando end-to-end.

Esta es la tarea que protege a los comercios actuales. Si algo falla acá, el cambio no sale.

- [ ] **Step 1: Subir el piso iOS del proyecto Xcode del example**

```bash
cd /Users/edavis/git/flutter_khipu
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 12.0;/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/g' \
  example/ios/Runner.xcodeproj/project.pbxproj
grep -c "IPHONEOS_DEPLOYMENT_TARGET = 13.0;" example/ios/Runner.xcodeproj/project.pbxproj
```

Esperado: `3`.

- [ ] **Step 2: Alinear el Podfile**

```bash
cd /Users/edavis/git/flutter_khipu
sed -i '' "s/^platform :ios, '15.0'/platform :ios, '13.0'/" example/ios/Podfile
head -1 example/ios/Podfile
```

Esperado: `platform :ios, '13.0'`.

- [ ] **Step 3: Forzar el camino CocoaPods**

En 3.44 SPM es el default, así que hay que apagarlo explícitamente para probar el camino viejo.

```bash
flutter config --no-enable-swift-package-manager
flutter config --list | grep -i swift
```

Esperado: `enable-swift-package-manager: false`.

- [ ] **Step 4: Reconstruir el example desde cero por el camino CocoaPods**

```bash
cd /Users/edavis/git/flutter_khipu/example
flutter clean
rm -rf ios/Pods ios/Podfile.lock ios/.symlinks
flutter pub get
flutter run -d 93EFD59E-34E4-4C5B-BF4F-18425C6F561E
```

Esperado: la app compila, arranca y abre la UI de Khipu, igual que en la línea base del Task 1
Step 3. Salir con `q`.

- [ ] **Step 5: Confirmar que efectivamente se usó CocoaPods y no SPM**

```bash
cd /Users/edavis/git/flutter_khipu/example
ls ios/Pods/KhipuClientIOS >/dev/null 2>&1 && echo "CocoaPods: KhipuClientIOS presente"
grep -c "FlutterGeneratedPluginSwiftPackage" ios/Runner.xcodeproj/project.pbxproj || echo "SPM: ausente (correcto)"
```

Esperado: `CocoaPods: KhipuClientIOS presente`, y que el `grep` devuelva `0` o "ausente". Si aparece
`FlutterGeneratedPluginSwiftPackage`, el flag del Step 3 no tomó efecto.

- [ ] **Step 6: Commit**

```bash
cd /Users/edavis/git/flutter_khipu
git add example/ios/Runner.xcodeproj/project.pbxproj example/ios/Podfile
git commit -m "chore(example): align iOS deployment target to 13.0

The project said 12.0 while the Podfile said 15.0. Both now match the
floor the plugin declares, so the example exercises the minimum we claim
to support.

Verified the CocoaPods path still builds and runs end-to-end with Swift
Package Manager explicitly disabled."
```

---

### Task 4: Validar el camino SPM, compilación y runtime

**Files:**
- Modify (por el tool, se commitea): `example/ios/Runner.xcodeproj/project.pbxproj`, `example/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`

**Interfaces:**
- Consumes: el plugin con `Package.swift` (Task 2) y el example alineado (Task 3).
- Produces: la prueba de que el plugin compila, enlaza y **funciona** por el camino SPM, con los recursos de Khipu llegando a la app.

- [ ] **Step 1: Volver a activar SPM y reconstruir**

```bash
flutter config --enable-swift-package-manager
cd /Users/edavis/git/flutter_khipu/example
flutter clean
flutter pub get
flutter run -d 93EFD59E-34E4-4C5B-BF4F-18425C6F561E
```

Esperado: compila y arranca. En la primera build Xcode resuelve los paquetes, así que tarda más que
por CocoaPods. Dejar la app corriendo para el Step 4.

- [ ] **Step 2: Confirmar que el plugin entró como Swift package**

```bash
cd /Users/edavis/git/flutter_khipu/example
cat ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift
grep -c "FlutterGeneratedPluginSwiftPackage" ios/Runner.xcodeproj/project.pbxproj
grep -c "Run Prepare Flutter Framework Script" ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
```

Esperado: el `Package.swift` generado declara una dependencia hacia `flutter_khipu` y el product
`flutter-khipu`; los dos `grep` devuelven un número mayor que `0`. Eso confirma que el tool integró el
paquete y agregó la pre-acción al scheme.

- [ ] **Step 3: Configurar la corrida desde el formulario del example**

Ya no hay que editar código: el example expone todas las opciones en pantalla. En la app corriendo:

1. Crear una intención de pago con una cuenta en **modo desarrollador** y pegar su `operationId` en el campo de la sección *Operation*. Es de un solo uso, así que hace falta uno nuevo por cada corrida.
2. En *Behaviour*, dejar **`showFooter` encendido** — es lo que renderiza el footer con el PNG `logo-khipu-color`, uno de los recursos que se quiere ver en pantalla.
3. En *Colors*, elegir el preset **Khipu**, para que además se ejerciten los 12 colores.
4. En *Theme and locale*, dejar `theme` en `light` y `locale` en `es_CL`.

Nada de esto toca archivos, así que no hay nada que revertir después.

- [ ] **Step 4: La prueba de runtime**

Con el `operationId` fresco, hacer hot restart (`R` en la consola de `flutter run`) y recorrer el
flujo de pago. Verificar **en pantalla**:

1. Los textos usan la tipografía **PublicSans**, no la del sistema (valida las `.ttf` vía `FontLoader` y `Bundle.module`).
2. Los colores del tema son los de Khipu, no los de por defecto (valida `Colors.xcassets` → `Assets.car`).
3. El footer muestra el logo de Khipu (valida el PNG suelto `logo-khipu-color`).
4. Al llegar a la pantalla de autorización, se ve su imagen (valida el PNG suelto `authorize`).
5. Al terminar, la app del example muestra el `KhipuResult` con `operationId` y `result`.

Esto confirma la validación que ya se hizo aislada sobre `KhipuClientIOS 2.16.4` —donde los 6 tests
de recursos pasaron y `.process("Assets")` deja todo en la raíz del bundle (spec §2)—, ahora dentro de
una app Flutter con enlazado estático. Lo único genuinamente nuevo que se está probando es que Xcode
copie el resource bundle dentro de la app.

Si algo no se renderiza, **detenerse y reportar**: sería un problema de empaquetado de recursos
upstream, no algo parcheable desde este plugin.

- [ ] **Step 5: Commitear solo la migración del proyecto Xcode**

```bash
cd /Users/edavis/git/flutter_khipu
git status --short
git add example/ios/Runner.xcodeproj/project.pbxproj \
        example/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
git commit -m "chore(example): integrate the generated Flutter Swift package

Applied by the Flutter tool when running the example with Swift Package
Manager enabled: FlutterGeneratedPluginSwiftPackage becomes a dependency of
the Runner target, and the scheme gains the Run Prepare Flutter Framework
Script pre-action.

Committed so the example actually exercises the SPM path. It degrades
cleanly on older Flutter: with the flag off the tool generates the package
with no dependencies.

Verified at runtime — fonts, theme colors and both loose PNGs render inside
a real Flutter app built through SPM."
```

Esperado: `git status --short` solo debe listar los dos archivos del proyecto Xcode.

---

### Task 5: Validar que el plugin funciona sin CocoaPods

**Files:** ninguno permanente. Todo lo que se toca acá se revierte.

**Interfaces:**
- Consumes: el camino SPM validado (Task 4).
- Produces: la prueba de que no queda ningún amarre a CocoaPods — el objetivo de fondo de esta migración.

Esta es la tarea que responde la pregunta que motivó todo: *¿funciona el plugin en una app sin
CocoaPods?* Es desechable por construcción: el example no puede estar con y sin `Podfile` a la vez.

- [ ] **Step 1: Desintegrar CocoaPods del example**

```bash
cd /Users/edavis/git/flutter_khipu/example/ios
pod deintegrate
rm -rf Podfile Podfile.lock Pods .symlinks
```

- [ ] **Step 2: Quitar los `#include` de CocoaPods de los xcconfig**

```bash
cd /Users/edavis/git/flutter_khipu/example/ios
grep -n "Pods-Runner" Flutter/Debug.xcconfig Flutter/Release.xcconfig
sed -i '' '/Pods-Runner/d' Flutter/Debug.xcconfig Flutter/Release.xcconfig
grep -c "Pods-Runner" Flutter/Debug.xcconfig Flutter/Release.xcconfig || echo "sin referencias a CocoaPods (correcto)"
```

Esperado: tras el `sed`, ninguna línea con `Pods-Runner`.

- [ ] **Step 3: Correr la app sin CocoaPods**

```bash
cd /Users/edavis/git/flutter_khipu/example
flutter clean
flutter pub get
flutter run -d 93EFD59E-34E4-4C5B-BF4F-18425C6F561E
```

Esperado: **compila y arranca sin `Podfile` ni directorio `Pods/`**. Esto es la demostración de que el
plugin ya no exige CocoaPods. Salir con `q`.

- [ ] **Step 4: Confirmar que de verdad no hubo pods**

```bash
cd /Users/edavis/git/flutter_khipu/example
ls ios/Podfile ios/Pods 2>&1 | head -3
```

Esperado: `No such file or directory` en ambos.

Nota: el target `RunnerTests` pierde sus `search_paths` al desintegrar los pods (venían de
`inherit! :search_paths` en el `Podfile`). Si `flutter run` funciona pero los tests de Xcode no
compilan, es esperable y no bloquea: este estado se descarta en el Step 5.

- [ ] **Step 5: Revertir todo**

```bash
cd /Users/edavis/git/flutter_khipu
git checkout example/ios
git clean -fd example/ios
git status --short
```

Esperado: `git status --short` limpio, con el `Podfile` de vuelta. Sin commit: esta tarea no deja
rastro en el repo, solo la constancia de que funcionó.

---

### Task 6: Versionado, CHANGELOG y README

**Files:**
- Modify: `pubspec.yaml:4`
- Modify: `CHANGELOG.md` (nueva entrada al inicio)
- Modify: `README.md` (sección *Platform setup → iOS*)

**Interfaces:**
- Consumes: los tres caminos validados (Tasks 3, 4, 5).
- Produces: la versión `1.7.0` documentada y lista para publicar.

Va al final a propósito: primero se valida, después se declara.

- [ ] **Step 1: Bumpear la versión del plugin**

En `pubspec.yaml`, cambiar `version: 1.6.1` por `version: 1.7.0`. **No tocar el bloque
`environment:`** — `flutter: '>=3.3.0'` se mantiene (Global Constraints).

```bash
cd /Users/edavis/git/flutter_khipu
grep -n "^version:\|flutter: '>=" pubspec.yaml
```

Esperado: `version: 1.7.0` y `flutter: '>=3.3.0'` intacto.

- [ ] **Step 2: Agregar la entrada del CHANGELOG**

Insertar al inicio de `CHANGELOG.md`, respetando el formato de las entradas existentes:

```markdown
# 1.7.0

iOS now supports Swift Package Manager in addition to CocoaPods, so an app can drop CocoaPods
entirely. The minimum iOS version is now 13.0 and the Khipu client for iOS was bumped to 2.16.4.

```

- [ ] **Step 3: Reemplazar la sección iOS del README**

En `README.md`, reemplazar:

```markdown
### iOS

At this moment there is no need for special setup for iOS development
```

por:

```markdown
### iOS

This plugin requires **iOS 13.0 or later**. Make sure your app's deployment target is at least
`13.0`, both in the Xcode project and in `ios/Podfile` if you have one.

The plugin ships support for both **Swift Package Manager** and **CocoaPods**, so no extra setup
is needed either way — Flutter picks the one your project uses.

Swift Package Manager is the default from Flutter 3.44 onwards. If every plugin in your app
supports it, you can remove CocoaPods from your project entirely:

```bash
cd ios
pod deintegrate
```

Then delete `ios/Podfile`, `ios/Podfile.lock`, `ios/Pods/`, and any `#include` lines referencing
CocoaPods in `ios/Flutter/Debug.xcconfig` and `ios/Flutter/Release.xcconfig`.
```

#### Opening banking apps

Khipu's `openApp` feature sends the payer to their banking app to authorize the payment. iOS only
lets an app open another one if it declares the schemes up front, so add `LSApplicationQueriesSchemes`
to `ios/Runner/Info.plist`. Without it, iOS refuses to open the banking app. For Chile:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>bancochilemipass2</string>
  <string>BciPassApp</string>
  <string>BICEPassApp</string>
  <string>scotiabankgo</string>
  <string>SantanderPassApp</string>
  <string>tupass</string>
  <string>bancoestado</string>
  <string>itau.cl</string>
  <string>SecurityPass</string>
</array>
```

See `example/ios/Runner/Info.plist` for a working copy.
```

- [ ] **Step 4: Verificar que el paquete queda publicable**

```bash
cd /Users/edavis/git/flutter_khipu
flutter pub publish --dry-run 2>&1 | tail -20
```

Esperado: sin errores. Advertencias sobre el `homepage` o el formato del README son aceptables;
anotarlas. Si reporta que faltan archivos o que hay rutas rotas, revisar Task 2.

- [ ] **Step 5: Commit**

```bash
cd /Users/edavis/git/flutter_khipu
git add pubspec.yaml CHANGELOG.md README.md
git commit -m "chore: release 1.7.0 with Swift Package Manager support

Documents the iOS 13.0 floor and that both dependency managers are
supported, replacing the README's claim that iOS needs no special setup.

The pubspec flutter constraint stays at >=3.3.0 on purpose: older Flutter
ignores Package.swift and uses the podspec, so narrowing it would drop
compatibility for no gain."
```

---

## Cierre

Al terminar las 6 tareas:

- [ ] `git log --oneline spm-migration` muestra 4 commits de implementación sobre los 2 de documentación.
- [ ] Los tres caminos quedaron validados: CocoaPods (Task 3), SPM (Task 4) y sin CocoaPods (Task 5).
- [ ] `git status --short` limpio.
- [ ] Abrir el PR `spm-migration` → `main`.

Fuera de alcance en este plan, según spec §11: Android, el salto a Flutter 3.47.x con su piso iOS 15,
el `UIApplication.shared.windows` deprecado, bumpear `flutter_lints`, montar CI, y limpiar el
`EXCLUDED_ARCHS ... i386` del podspec.
