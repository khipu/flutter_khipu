# 1.7.2

**Read this before upgrading: the payment behaves differently on iOS.** Until now, a payer who
declined the location permission ended the operation there. From this release the payment
continues instead, which is what Android has always done. If you relied on the old behaviour,
this changes what your users experience. It is a patch release only because the 1.7.x line has
no minor number available below the already-published 1.8.0.

Both native clients move forward. On Android, the pinned Khenshin protocol library was missing
a `FailureReasonType` constant the iOS library already had, and an unknown value there does not
degrade — the generated parser throws, and that throw escaped uncaught onto the socket's event
thread and took the host app's process with it. The Khipu client now guards every socket
listener, treats all four terminal message types as terminal, and returns a result to the
merchant even when it cannot parse the message that ended the operation. On iOS, besides the
location change above, a failure inside CoreLocation used to leave the payment spinning with no
error and no way out; it now reports null coordinates and carries on. The iOS client also fixes
a force-cast of a socket frame and a force-unwrap of an optional decryption result, neither of
which the surrounding `do`/`catch` could contain because a Swift trap is not an `Error`, and
pins Starscream so the CocoaPods and Swift Package Manager graphs cannot drift apart.

The plugin-side hardening is separate and had no known trigger — the SDK's exits all carry a
result, including the back button, which opens Khipu's own abort dialog — but each path left the
Dart `Future` unresolved if it ever fired, and a payment that never answers is the worst thing
this plugin can do quietly.

The plugin now validates before it stores the pending result, answers from the payload rather
than the result code, treats a missing or malformed payload as an explicit `NO_RESULT` instead of
throwing inside the listener, and removes its activity result listener on detach instead of
accumulating one per screen rotation. A configuration change still leaves an operation in flight
untouched; only a permanent detach ends it.

New `PlatformException` codes: `NO_ACTIVITY`, `OPERATION_IN_PROGRESS`, `INVALID_OPTIONS`,
`LAUNCH_FAILED`, `NO_RESULT`, `ACTIVITY_DETACHED`. All of them, and the ones that already existed,
are now documented in the README — including which exist on only one platform.

On iOS, a second `startOperation` while Khipu is on screen is rejected with
`OPERATION_IN_PROGRESS` instead of presenting Khipu on top of Khipu.

The README also documents, for the first time, that Khipu's Android client declares location
permissions that the manifest merger adds to your app, when that flow actually fires, and what you
have to declare because of it.

Nothing changes in the plugin's Dart API.

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
