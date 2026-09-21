# flutter_khipu

Flutter plugin for Khipu, this plugin enables a flutter app to use Khipu to authorize payments.

## Installing the plugin

Version 1.8.0 and later require **Flutter 3.44 or later** (Dart 3.12). Anything earlier than
3.44 is served by the **1.7.x** line, which is maintained on the `1.7.x` branch and still
receives critical fixes.

You do not need to pin anything for this: pub takes each version's SDK constraint into account
when resolving, so a `flutter_khipu: ^1.7.1` dependency resolves to 1.7.1 on an older Flutter
and to 1.8.0 on 3.44 or later. `flutter pub upgrade` will report that a newer version exists
but is incompatible, which is expected and not an error.

Add this plugin to your dependencies

```bash
flutter pub add flutter_khipu
```

Then get the dependency

```bash
flutter pub get
```

## Platform setup

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

#### Location

Khipu's iOS client may ask the payer for their location during a payment, for the same banks
described in the "Location permissions" section under Android below.

Your app must declare `NSLocationWhenInUseUsageDescription` in `ios/Runner/Info.plist` with a
real purpose string. Without it, iOS never shows the prompt — `requestWhenInUseAuthorization()`
has no effect and silently does nothing. An **empty** string is also rejected during App Store
review. For example:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Usamos tu ubicación para verificar el pago con tu banco cuando este lo solicita.</string>
```

Declining the prompt does not block the payment. The three obligations that follow from this —
Play Data Safety (or its App Store equivalent), the prompt appearing inside your app, and Ley
21.719 — are the same ones listed below for Android; see that section rather than this one.

### Android

#### Repository

Add the Khipu repository to the `android/build.gradle` file

```groovy
allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url 'https://dev.khipu.com/nexus/content/repositories/khenshin' }
    }
}
```

Note that the `google()` and `mavenCentral()` repos are usually already added.

#### Jetifier

If you are still using jetifier please add jackson-core to the list of ignored jars by adding the line

```groovy
android.jetifier.ignorelist = jackson-core
```

to the `android/gradle.properties` file

#### Gradle plugins

This plugin does not apply the Kotlin Gradle Plugin (KGP) itself, so Kotlin has to come from
your project. With **AGP 9** there is nothing to do: Kotlin support ships with AGP. With
**AGP 8 and earlier**, your app supplies KGP, and Khipu needs it to be at least 1.9.0, so make
sure `android/settings.gradle` (or `settings.gradle.kts`) declares at least that version.
Projects created by recent Flutter versions already declare a newer one — if the version there
is higher than 1.9.0, leave it alone.

```groovy
plugins {
    id "org.jetbrains.kotlin.android" version "1.9.0" apply false
}
```

#### Opening banking apps

Khipu's `openApp` feature sends the payer to their banking app to authorize the payment. Starting
with Android 11 (API 30), an app must declare which packages it queries up front, so add a
`<queries>` block to `android/app/src/main/AndroidManifest.xml`, as a child of `<manifest>`.
Without it, the app can't detect or launch the banking app. For Chile:

```xml
<queries>
    <package android:name="cl.bci.pass" />
    <package android:name="cl.bancochile.mi_pass2" />
    <package android:name="net.veritran.becl.prod" />
    <package android:name="cl.scotiabank.go" />
    <package android:name="cl.santander.santanderpasschile" />
    <package android:name="com.konylabs.ItauMobileBank" />
    <package android:name="cl.bancosecurity.securitypass" />
    <package android:name="cl.bice.bicepassmobile2" />
    <package android:name="cl.consorcio.tupass" />
</queries>
```

See `example/android/app/src/main/AndroidManifest.xml` for a working copy.

#### Location permissions

Khipu's Android client declares `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` in
its own manifest, so the manifest merger adds them to your app whether or not you declare
them. They are there because some banks ask to geolocate the payer during the payment.

**Nothing happens by default.** The SDK does not ask for location when it starts. The
geolocation screen appears only if the server sends a geolocation request for that
particular payment, and only then does the SDK show the system permission dialog — from
inside Khipu's own UI, in response to the payer tapping through it. If the payer declines,
**the payment continues**: geolocation is not mandatory at this call site. With no
permission granted, the only thing the SDK reports is whether the device has any location
providers at all, which needs no permission and yields no location.

Even so, three things follow for you, and none of them are optional, on either platform:

- **Play Data Safety / App Store privacy labels.** On Android you must declare that your
  app collects location in Play's Data Safety section; on iOS the equivalent is your app's
  App Store privacy label (Location under "Data Used to Track You" or "Data Linked to You",
  as applicable). The permissions are declared, and the prompt can appear — that the payer
  may decline, or may never see it, does not exempt the declaration.
- **The prompt looks like yours.** The payer sees a location dialog while inside your app,
  on either platform. Tell your support team, or they will field the question cold.
- **Ley 21.719.** Location collected during a payment is personal data, regardless of
  platform. It belongs in your privacy notice, together with the purpose above.

Do **not** strip the permissions with `tools:node="remove"`. It builds, and then
authorization fails at the banks that ask for the check.

Khipu's own documentation is the canonical source for this behaviour; this section
describes what the plugin's pinned client does today.

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

## Usage

```dart
import 'package:flutter_khipu/flutter_khipu.dart';

...

final KhipuResult? result = await FlutterKhipu().startOperation(
  const KhipuStartOperationOptions(
    operationId: '<string>', // The unique identifier of the payment intent
    title: '<string>', // Text to show in the top bar
    titleImageUrl: '<string>', // Image to show centered in the top bar (it replaces the title)
    locale: '<string>', // Regional settings for the interface language. The standard format combines an ISO 639-1 language code and an ISO 3166 country code. For example, "es_CL" for Spanish (Chile).
    skipExitPage: false, // If true, skips the exit page at the end of the payment process, whether successful or failed.
    skipExitSuccessPage: false, // If true, skips the exit page at the end of the payment process if it was successful.
    showFooter: true, // If true, a message is displayed with a Khipu logo
    showMerchantLogo: true, // If true, shows the merchant's logo in the top bar
    showPaymentDetails: true, // If true, shows the payment's amount and detail
    theme: KhipuTheme.system, // The theme of the interface: light, dark or system
    colors: KhipuColors(
      lightBackground: '<hexColor>', // Optional. General background color in light mode
      lightOnBackground: '<hexColor>', // Optional. Color of elements on the general background in light mode
      lightPrimary: '<hexColor>', // Optional. Primary color in light mode
      lightOnPrimary: '<hexColor>', // Optional. Color of elements on the primary color in light mode
      lightTopBarContainer: '<hexColor>', // Optional. Background color for the top bar in light mode
      lightOnTopBarContainer: '<hexColor>', // Optional. Color of the elements on the top bar in light mode
      darkBackground: '<hexColor>', // Optional. General background color in dark mode
      darkOnBackground: '<hexColor>', // Optional. Color of elements on the general background in dark mode
      darkPrimary: '<hexColor>', // Optional. Primary color in dark mode
      darkOnPrimary: '<hexColor>', // Optional. Color of elements on the primary color in dark mode
      darkTopBarContainer: '<hexColor>', // Optional. Background color for the top bar in dark mode
      darkOnTopBarContainer: '<hexColor>', // Optional. Color of the elements on the top bar in dark mode
    ),
  ),
);
```

`startOperation` returns `null` only if the native side finished without a result at all; in
practice you always get a `KhipuResult`, whose fields are:

- `operationId` : `String`. The unique identifier for the payment intent.
- `result` : `KhipuResultStatus`. General outcome of the operation:
  - `ok` : Success
  - `error` : Error
  - `warning` : Warning
  - `mustContinue` : The operation needs more steps. The SDK sends this as `CONTINUE`; it is
    spelled differently here because `continue` is a reserved word in Dart, Kotlin and Swift.
  - `userCanceled` : The payer abandoned the payment.
  - `unknown` : The server sent a status this version of the plugin does not know yet. Handle
    it explicitly — treating it as a failure is usually right, but it is your call.
- `exitTitle` : `String`. Title to show the user on the exit screen, reflecting the outcome.
- `exitMessage` : `String`. Additional detail about the outcome, to show alongside `exitTitle`.
- `exitUrl` : `String?`. URL to return the app to at the end of the process, if any.
- `failureReason` : `String?`. Why it failed, if `result` was not `ok`.
- `continueUrl` : `String?`. Present only when `result` is `mustContinue`; the URL to continue
  the operation at.
- `events` : `List<KhipuEvent>`. The steps taken to generate the payment, with their timestamps.
  Empty, never null.

## Cancellation

When the payer abandons the payment — by backing out, which opens Khipu's own confirmation
dialog, or by using its close button — the result arrives as a normal `KhipuResult` with `result`
set to `KhipuResultStatus.userCanceled`. `exitTitle` and `exitMessage` carry Khipu's own localized
wording for the abandonment, so you can show them as-is.

Two uncommon paths differ. If Android tore the payment down and the payer returns more than three
minutes later, the SDK ends the operation with the same `result` but with the exit strings empty.
And if the SDK cannot parse the message that ended the operation, it returns
`result: KhipuResultStatus.error` with `failureReason` **null** — it does not know why the payment
failed, and says so rather than guessing.

## Errors

`startOperation` throws a `PlatformException` when it cannot start or finish. Not
every code exists on both platforms — the causes are platform-specific, and only one
code, `OPERATION_IN_PROGRESS`, exists on both.

| Code | Android | iOS | Cause |
|---|:-:|:-:|---|
| `OPERATION_IN_PROGRESS` | ✓ | ✓ | A Khipu operation is already running |
| `NO_ACTIVITY` | ✓ | | The plugin is attached to the engine but not to an activity |
| `NO_VIEW_CONTROLLER` | | ✓ | No view controller was available to present from |
| `INVALID_OPTIONS` | ✓ | | The options could not be mapped — check your colour strings |
| `LAUNCH_FAILED` | ✓ | | Khipu's activity could not be started |
| `NO_RESULT` | ✓ | | Khipu returned without a result |
| `ACTIVITY_DETACHED` | ✓ | | The activity went away before Khipu returned |

Two codes from 1.x are gone: `MISSING_OPERATION_ID` and `BAD_ARGUMENT_DICTIONARY`. Both
described a malformed call, and the channel can no longer deliver one — its shape is now
generated from a Pigeon schema that declares `operationId` as non-null, so the generated codec
rejects a malformed message before `startOperation` ever runs. That class of call became
unreachable rather than unhandled.

`NO_RESULT` and `ACTIVITY_DETACHED` can both fire on a payment that actually succeeded. The
plugin answers with one of them because leaving the `Future` unresolved would be worse, not
because it knows the payment failed — **the outcome is unknown** at that point, and it may
have completed server-side. Before treating either as a failure, confirm the operation's real
status against the operation id through Khipu's API. Under-crediting a payer who paid is the
expensive direction of this error: refunding a mistaken charge is routine, but a merchant who
silently wrote off a successful payment usually never finds out.

