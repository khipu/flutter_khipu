import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_khipu/flutter_khipu.dart';

import 'flutter_khipu_platform_interface.dart';

/// An implementation of [FlutterKhipuPlatform] that uses method channels.
class MethodChannelFlutterKhipu extends FlutterKhipuPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_khipu');

  @override
  Future<KhipuResult?> startOperation(
      KhipuStartOperationOptions options) async {
    var result = await methodChannel
        .invokeMethod<dynamic>('startOperation', <String, dynamic>{
      'operationId': options.operationId,
      'title': options.title,
      'titleImageUrl': options.titleImageUrl,
      'locale': options.locale,
      'skipExitPage': options.skipExitPage,
      'showFooter': options.showFooter,
      'theme': options.theme,
      'lightBackground': options.colors?.lightBackground,
      'lightOnBackground': options.colors?.lightOnBackground,
      'lightPrimary': options.colors?.lightPrimary,
      'lightOnPrimary': options.colors?.lightOnPrimary,
      'lightTopBarContainer': options.colors?.lightTopBarContainer,
      'lightOnTopBarContainer': options.colors?.lightOnTopBarContainer,
      'darkBackground': options.colors?.darkBackground,
      'darkOnBackground': options.colors?.darkOnBackground,
      'darkPrimary': options.colors?.darkPrimary,
      'darkOnPrimary': options.colors?.darkOnPrimary,
      'darkTopBarContainer': options.colors?.darkTopBarContainer,
      'darkOnTopBarContainer': options.colors?.darkOnTopBarContainer,
    });

    return KhipuResult.fromJson(result);
  }
}
