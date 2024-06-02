// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter

import 'package:flutter_khipu/flutter_khipu.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'flutter_khipu_platform_interface.dart';

/// A web implementation of the FlutterKhipuPlatform of the FlutterKhipu plugin.
class FlutterKhipuWeb extends FlutterKhipuPlatform {
  /// Constructs a FlutterKhipuWeb
  FlutterKhipuWeb();

  static void registerWith(Registrar registrar) {
    FlutterKhipuPlatform.instance = FlutterKhipuWeb();
  }


  @override
  Future<KhipuResult?> startOperation(KhipuStartOperationOptions options) async {
    final operationId = options.operationId;
    return KhipuResult(operationId: operationId);
  }
}
