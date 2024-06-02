import Flutter
import UIKit
import KhipuClientIOS

public class FlutterKhipuPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_khipu", binaryMessenger: registrar.messenger())
    let instance = FlutterKhipuPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "startOperation":
        
        KhipuLauncher.launch(presenter: self, operationId: <#T##String#>, options: <#T##KhipuOptions#>)
      
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
