import 'package:flutter_khipu/flutter_khipu.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_khipu_method_channel.dart';

abstract class FlutterKhipuPlatform extends PlatformInterface {
  /// Constructs a FlutterKhipuPlatform.
  FlutterKhipuPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterKhipuPlatform _instance = MethodChannelFlutterKhipu();

  /// The default instance of [FlutterKhipuPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterKhipu].
  static FlutterKhipuPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterKhipuPlatform] when
  /// they register themselves.
  static set instance(FlutterKhipuPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<KhipuResult?> startOperation(KhipuStartOperationOptions options) {
    throw UnimplementedError('startOperation() has not been implemented.');
  }
}
