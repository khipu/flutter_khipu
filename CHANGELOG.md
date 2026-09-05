# 1.8.0

Migrates the plugin to Built-in Kotlin. It no longer applies the Kotlin Gradle Plugin (KGP)
itself: AGP 9 ships Kotlin support of its own, and applying KGP on top of it fails the build.

This raises the minimum supported version to Flutter 3.44 and Dart 3.12. The bump is not
cosmetic. Flutter applies `kotlin-android` to plugin subprojects itself, and that behaviour
landed in 3.44.0 — on anything older, a plugin that does not apply KGP has its Kotlin sources
left uncompiled. If your app is on Flutter 3.41 or earlier, stay on 1.7.1.

Nothing changes in the plugin's API or behaviour, and the compiled bytecode still targets
Java 8. What changes is that an app using this plugin no longer gets the warning Flutter emits
for plugins that apply KGP, and will keep building once Flutter turns that warning into an
error.

# 1.7.1

Fixes how the plugin finds the view controller to present Khipu from on iOS. It used
`UIApplication.windows`, deprecated since iOS 15, which reports windows across every
connected scene; it now goes through the foreground-active window scene instead.

It also no longer presents from the root view controller unconditionally. If your app is
already presenting something of its own when you call `startOperation`, UIKit rejects
presenting on top of it and Khipu never appears. The plugin now walks up to whatever is
actually presented. Measured against real UIKit: with a modal on screen the old code
returned a controller that was already presenting, while the new code returns the modal.

Nothing changes when no modal is present — both resolve to the same controller.

# 1.7.0

iOS now supports Swift Package Manager alongside CocoaPods, so an app whose every plugin supports
SPM can drop CocoaPods entirely. The minimum iOS version is now 13.0 and the Khipu client for iOS
was bumped to 2.16.5.

That client version carries fixes for two crashes this plugin's migration surfaced: a Keychain
failure aborting the payment when "remember my credentials" was on, and force-unwrapped optional
protocol fields aborting the closing screens.

Fixes a crash where a payment whose `exitUrl` came back empty threw `type 'Null' is not a subtype
of type 'String'` from `KhipuResult.fromJson` instead of returning a result. Every `KhipuResult`
and `KhipuEvent` field was already declared nullable; the JSON parsing now matches.

The example app was rewritten to let every option be toggled before launching Khipu, instead of
launching automatically with a hardcoded operation id.

# 1.6.1

Khipu clients for iOS bumped to 2.16.2 and Android bumped to 2.27.0

# 1.6.0

add skipExitSuccessPage option and update Khipu SDK dependencies (Android 2.26.0, iOS 2.16.0)

# 1.5.13

Khipu clients for iOS bumped to 2.14.0 and Android bumped to 2.25.0

# 1.5.12

MethodChannel.Result can sometimes be null, this version fixes that

# 1.5.11

Khipu clients for iOS bumped to 2.13.7 and Android bumped to 2.24.0

# 1.5.10

Khipu clients for iOS bumped to 2.13.6 and Android bumped to 2.23.1

# 1.5.9

Khipu clients for iOS bumped to 2.12.1

## 1.5.8

Khipu clients for iOS bumped to 2.12.0 and Android bumped to 2.19.0

## 1.5.7

Khipu clients for iOS bumped to 2.11.0, compatible with XCode 26

## 1.5.6

Khipu clients for iOS bumped to 2.10.1 and Android bumped to 2.18.0

## 1.5.5

Khipu clients for iOS bumped to 2.9.4 and Android bumped to 2.16.1

## 1.5.4

Khipu clients for iOS bumped to 2.9.3 and Android bumped to 2.16.0

## 1.5.3

Khipu clients for iOS bumped to 2.8.0

## 1.5.2

Khipu client for android bumped to 2.7.6

## 1.5.1

Khipu clients for android bumped to 2.7.5 and iOS bumped to 2.7.7

## 1.5.0

Khipu clients for android bumped to 2.7.4 and iOS bumped to 2.7.6

## 1.4.0

Added LGPL LICENCE

## 1.3.1

Khipu clients for iOS bumped to 2.7.5

## 1.3.0

Khipu clients for android bumped to 2.7.3 and iOS bumped to 2.7.4

## 1.2.0

Khipu clients for android and iOS bumped to 2.7.2

## 1.0.2

Information about the sourceCompatibility and targetCompatibility options

## 1.0.1

Suggest to use the Android Gradle plugin Upgrade Assistant

## 1.0.0

First version of the Flutter plugin for Khipu, it implements the screens needed for a payer to authorize payments in iOS and Android devices
