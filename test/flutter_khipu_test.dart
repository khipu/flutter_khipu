import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_khipu/flutter_khipu.dart';
import 'package:flutter_khipu/flutter_khipu_platform_interface.dart';
import 'package:flutter_khipu/flutter_khipu_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterKhipuPlatform
    with MockPlatformInterfaceMixin
    implements FlutterKhipuPlatform {
  @override
  Future<KhipuResult?> startOperation(KhipuStartOperationOptions options) {
    // TODO: implement startOperation
    throw UnimplementedError();
  }
}

void main() {
  final FlutterKhipuPlatform initialPlatform = FlutterKhipuPlatform.instance;

  test('$MethodChannelFlutterKhipu is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterKhipu>());
  });
}
