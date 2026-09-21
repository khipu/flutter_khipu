import 'package:flutter/services.dart' show BinaryMessenger;

import 'khipu_options.dart';
import 'khipu_result.dart';
import 'messages.g.dart' as pigeon;

/// Entry point of the plugin.
///
/// ```dart
/// final KhipuResult? result = await FlutterKhipu().startOperation(
///   const KhipuStartOperationOptions(operationId: 'abc123'),
/// );
/// ```
class FlutterKhipu {
  /// Builds the plugin.
  ///
  /// [messenger] exists for tests: passing one of your own lets you
  /// intercept the channel without touching the global binding. In an app
  /// there is no need to give it.
  FlutterKhipu({BinaryMessenger? messenger})
      : _api = pigeon.KhipuHostApi(binaryMessenger: messenger);

  final pigeon.KhipuHostApi _api;

  /// Opens Khipu and waits for the person to finish the payment.
  ///
  /// Returns the outcome, or `null` if the native side finished without
  /// one.
  ///
  /// Throws [PlatformException] if the operation failed to open. The
  /// possible codes are documented in the README. Only `OPERATION_IN_PROGRESS`
  /// exists on both platforms; the rest are platform-specific.
  Future<KhipuResult?> startOperation(
    KhipuStartOperationOptions options,
  ) async {
    final pigeon.KhipuResult? result =
        await _api.startOperation(options.toPigeon());
    return result == null ? null : KhipuResult.fromPigeon(result);
  }
}
