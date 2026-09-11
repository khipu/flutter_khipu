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

Even so, three things follow for you, and none of them are optional:

- **Play Data Safety.** You must declare that your app collects location. The permissions
  are in your merged manifest, and the prompt can appear — that the payer may decline, or
  may never see it, does not exempt the declaration.
- **The prompt looks like yours.** The payer sees a location dialog while inside your app.
  Tell your support team, or they will field the question cold.
- **Ley 21.719.** Location collected during a payment is personal data. It belongs in your
  privacy notice, together with the purpose above.

Do **not** strip the permissions with `tools:node="remove"`. It builds, and then
authorization fails at the banks that ask for the check.

Khipu's own documentation is the canonical source for this behaviour; this section
describes what the plugin's pinned client does today.

## Usage


```dart
import 'package:flutter_khipu/flutter_khipu.dart';

...

KhipuResult? result =
    await FlutterKhipu().startOperation(KhipuStartOperationOptions(
                                            operationId: "<string>", // The unique identifier of the payment intent
                                            title: "<string>", // Text to show in the top bar
                                            titleImageUrl: "<string>", // Image to show centered in the top bar (it replaces the title)
                                            locale: "<string>", // Regional settings for the interface language. The standard format combines an ISO 639-1 language code and an ISO 3166 country code. For example, "es_CL" for Spanish (Chile).
                                            skipExitPage: false, // If true, skips the exit page at the end of the payment process, whether successful or failed.
                                            skipExitSuccessPage: false, // If true, skips the exit page at the end of the payment process if it was successful.
                                            showFooter: true, // If true, a message is displayed with a Khipu logo
                                            theme: "<string>", // The theme of the interface, can be light, dark or system
                                            colors: KhipuColors(
                                                lightBackground: "<hexColor>", //Optional General background color in light mode
                                                lightOnBackground: "<hexColor>", //Optional Color of elements on the general background in light mode
                                                lightPrimary: "<hexColor>", //Optional Primary color in light mode.
                                                lightOnPrimary: "<hexColor>", //Optional Color of elements on the primary color in light mode.
                                                lightTopBarContainer: "<hexColor>", //Optional Background color for the top bar in light mode.
                                                lightOnTopBarContainer: "<hexColor>", //Optional Color of the elements on the top bar in light mode.
                                                darkBackground: "<hexColor>", //Optional General background color in dark mode
                                                darkOnBackground: "<hexColor>", //Optional Color of elements on the general background in dark mode
                                                darkPrimary: "<hexColor>", //Optional Primary color in dark mode.
                                                darkOnPrimary: "<hexColor>", //Optional Color of elements on the primary color in dark mode.
                                                darkTopBarContainer: "<hexColor>", //Optional Background color for the top bar in dark mode.
                                                darkOnTopBarContainer: "<hexColor>", //Optional Color of the elements on the top bar in dark mode.
                                            )));

```

The `KhipuResult` object will contain the following fields.

- operationId : String? (Optional) The unique identifier for the payment intent.
- exitTitle : String? (Optional) Title that will be displayed to the user on the exit screen, reflecting the outcome of the operation.
- exitMessage : String? (Optional) Message that will be displayed to the user, providing additional details about the outcome of the operation.
- exitUrl : String? (Optional) URL to which the application will return at the end of the process.
- result : String? (Optional) General outcome of the operation, possible values are:
  - OK : Success
  - ERROR : Error
  - WARNING : Warnings
  - CONTINUE : Operation needs more steps
- failureReason : String? (Optional) Describes the reason for the failure, if the operation was not successful.
- continueUrl : String? (Optional) Available only when the result is "CONTINUE", indicating the URL to follow to continue the operation.
- events : Array (Optional) The steps taken to generate the payment, with their timestamps.

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

