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
/// Theme Khipu presents itself with.
enum KhipuTheme { light, dark, system }

/// Outcome of the operation.
///
/// The SDK delivers it as free text. The first five cases are the ones
/// `khipu-client-android` 2.28.5 can emit, measured against its bytecode;
/// [unknown] exists so a new value from the server doesn't break the
/// channel. Without it, an unrecognized value would fail decoding of the
/// entire message, and the payment would reach the merchant as a platform
/// error.
enum KhipuResultStatus {
  ok,
  error,
  warning,
  /// The SDK emits this as `CONTINUE`. It's named differently because
  /// `continue` is a reserved word in Dart, Kotlin, and Swift.
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

/// All three fields are non-null: measured against the 2.28.5 AAR, the
/// `com.khipu.client.KhipuEvent` constructor does `checkNotNullParameter` on
/// all three.
class KhipuEvent {
  late String name;
  late String type;
  late String timestamp;
}

/// Nullability per §2.3 of the design doc: the three optional fields are
/// exactly the ones the Android SDK declares `@Nullable`.
class KhipuResult {
  late String operationId;
  late KhipuResultStatus result;

  /// What the SDK actually sent for [result], before it was matched against
  /// the known cases. Always present, even when [result] is not
  /// [KhipuResultStatus.unknown]: this is what lets a merchant log, report
  /// to support, or otherwise handle a value this plugin doesn't recognize
  /// yet, without waiting for a plugin release that adds it.
  late String rawResult;
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
