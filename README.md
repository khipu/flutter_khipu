# flutter_khipu

Flutter plugin for Khipu, this plugin enables a flutter app to use Khipu to authorize payments.

## Installing the plugin

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

This plugin supports **iOS 13.0 or later**, but **Xcode 27 refuses to build any target below
iOS 15.0** — and Flutter's app template sets 13.0, so an app with no plugins at all fails the
same way. If you build with Xcode 27, raise your app to 15.0:

- **The Runner target, always.** In Xcode, select the Runner target and set *Minimum
  Deployments* to 15.0, or replace every `IPHONEOS_DEPLOYMENT_TARGET = 13.0;` with `15.0;` in
  `ios/Runner.xcodeproj/project.pbxproj`. With Swift Package Manager, that is all it takes.
- **With CocoaPods, every pod as well.** CocoaPods writes each pod's own deployment target into
  its build settings, and neither the `platform` line nor Flutter's
  `flutter_additional_ios_build_settings` raises it: Flutter skips every pod that does not depend
  on Flutter, which leaves Khipu's native SDK and its dependencies at 12.0, and this plugin's own
  pod stays at 13.0. Set `platform :ios, '15.0'` in `ios/Podfile` and force every pod in its
  `post_install`:

  ```ruby
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      flutter_additional_ios_build_settings(target)
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      end
    end
  end
  ```

  With the Runner at 15.0 but without this override, a CocoaPods build still fails.

One more catch on this line, and it is Flutter's, not this plugin's: with Flutter 3.41.9 and
Xcode 27, **simulator** builds fail inside Flutter's own framework step (`Failed to copy Flutter
framework`), even for an app with no plugins. Device builds work. Flutter 3.44.9 builds for the
simulator with Xcode 27.

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

Add the Khipu repository to `android/build.gradle.kts`, which is what `flutter create` generates:

```kotlin
allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://dev.khipu.com/nexus/content/repositories/khenshin") }
    }
}
```

If your project still uses the Groovy DSL, the file is `android/build.gradle` instead:

```groovy
allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = 'https://dev.khipu.com/nexus/content/repositories/khenshin' }
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

Khipu needs the Kotlin Android Gradle Plugin to be at least 1.9.0, so please make sure the file `android/settings.gradle` has at least that version

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

There is no separate "cancelled" outcome. When the payer abandons the payment — by backing out,
which opens Khipu's own confirmation dialog, or by using its close button — the result arrives as
a normal `KhipuResult` with `result` set to `"ERROR"` and `failureReason` set to
`"USER_CANCELED"`. `exitTitle` and `exitMessage` carry Khipu's own localized wording for the
abandonment, so you can show them as-is.

Two uncommon paths differ. If Android tore the payment down and the payer returns more than three
minutes later, the SDK ends the operation with the same `result` and `failureReason` but with the
exit strings empty. And if the SDK cannot parse the message that ended the operation, it returns
`result: "ERROR"` with `failureReason` **null** — it does not know why the payment failed, and
says so rather than guessing. Treat both fields as optional.

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

`NO_RESULT` and `ACTIVITY_DETACHED` can both fire on a payment that actually succeeded. The
plugin answers with one of them because leaving the `Future` unresolved would be worse, not
because it knows the payment failed — **the outcome is unknown** at that point, and it may
have completed server-side. Before treating either as a failure, confirm the operation's real
status against the operation id through Khipu's API. Under-crediting a payer who paid is the
expensive direction of this error: refunding a mistaken charge is routine, but a merchant who
silently wrote off a successful payment usually never finds out.

