# flutter_khipu

A new Flutter plugin project.

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

At this moment there is no need for special setup for iOS development

### Android

#### Repository

Add the Khipu repository to the `android/build.gralde` file

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
android.jetifier.ignorelist = jackson - core
```

to the `android/gradle.properties` file

#### Gradle plugins

Khipu needs the Kotlin Android Gradle Plugin and the Android Gradle Plugin to be at least 1.9.0 and 8.4.0 respectively, so please make sure the file `android/settings.gradle` has at lease those versions

```groovy
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.4.0" apply false
    id "org.jetbrains.kotlin.android" version "1.9.0" apply false
}
```

You will, most likely, have to upgrade Gradle as well to at least 8.6, to do so, please modify the file `android/gradle/gradle-wrapper.properties` to look like this

```bash
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.6-all.zip
```

You can also use the [use the Android Gradle plugin Upgrade Assistant](https://developer.android.com/build/agp-upgrade-assistant) to do this.


## Usage


```dart
import 'package:flutter_khipu/flutter_khipu.dart';

...

KhipuResult? result =
    await FlutterKhipu().startOperation(KhipuStartOperationOptions(
                                            operationId: "<string>", // The unique identifier of the payment intent
                                            locale: "<string>", // Regional settings for the interface language. The standard format combines an ISO 639-1 language code and an ISO 3166 country code. For example, "es_CL" for Spanish (Chile).
                                            skipExitPage: false, // If true, skips the exit page at the end of the payment process, whether successful or failed.
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

- operationId : String The unique identifier for the payment intent.
- exitTitle : String Title that will be displayed to the user on the exit screen, reflecting the outcome of the operation.
- exitMessage : String Message that will be displayed to the user, providing additional details about the outcome of the operation.
- exitUrl : String URL to which the application will return at the end of the process.
- result : String General outcome of the operation, possible values are:
  - OK : Success
  - ERROR : Error
  - WARNING : Warnings
  - CONTINUE : Operation needs more steps
- failureReason : String (Optional) Describes the reason for the failure, if the operation was not successful.
- continueUrl : String (Optional) Available only when the result is "CONTINUE", indicating the URL to follow to continue the operation.
- events : Array The steps taken to generate the payment, with their timestamps.

