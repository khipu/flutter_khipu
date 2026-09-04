# 1.7.0

iOS now supports Swift Package Manager alongside CocoaPods, so an app whose every plugin supports
SPM can drop CocoaPods entirely. The minimum iOS version is now 13.0 and the Khipu client for iOS
was bumped to 2.16.4.

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
