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
/// Tema con el que Khipu se presenta.
enum KhipuTheme { light, dark, system }

/// Desenlace de la operación.
///
/// El SDK lo entrega como texto libre. Los cinco primeros casos son los que
/// `khipu-client-android` 2.28.5 puede emitir, medidos sobre su bytecode;
/// [unknown] existe para que un valor nuevo del servidor no rompa el canal.
/// Sin él, un valor no reconocido haría fallar la decodificación entera del
/// mensaje y el pago llegaría al comercio como un error de plataforma.
enum KhipuResultStatus {
  ok,
  error,
  warning,
  /// El SDK lo emite como `CONTINUE`. Se llama distinto porque `continue` es
  /// palabra reservada en Dart, en Kotlin y en Swift.
  mustContinue,
  userCanceled,
  unknown,
}

/// Paleta con la que se pinta Khipu. Un color nulo deja el del SDK.
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

/// Los tres campos son no nulos: medido sobre el AAR 2.28.5, el constructor
/// de `com.khipu.client.KhipuEvent` hace `checkNotNullParameter` en los tres.
class KhipuEvent {
  late String name;
  late String type;
  late String timestamp;
}

/// Nulabilidad según §2.3 del design doc: los tres opcionales son exactamente
/// los que el SDK Android declara `@Nullable`.
class KhipuResult {
  late String operationId;
  late KhipuResultStatus result;
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
