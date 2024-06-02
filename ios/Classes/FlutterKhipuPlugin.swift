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
    case "startOperation":
        startOperation(call, result: result)
    default:
        result(FlutterMethodNotImplemented)
    }
  }
    
    
    private func startOperation(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        guard let rootViewController = keyWindow?.rootViewController else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "A view controller is needed to start Khipu", details: nil))
            return
        }
        
        guard let args = call.arguments as? Dictionary<String, Any> else {
            result(FlutterError(code: "BAD_ARGUMENT_DICTIONARY", message: "The arguments parameter is not a Dictionary<String, Any>", details: nil))
            return
        }
        
        guard let operationId = args["operationId"] as? String else {
            result(FlutterError(code: "MISSING_OPERATION_ID", message: "There is no operationId argument", details: nil))
            return
        }
        
        var optionsBuilder = KhipuOptions.Builder()
        
        if (args["title"] is String) {
            optionsBuilder = optionsBuilder.topBarTitle(args["title"]! as! String)
        }
        
        if (args["skipExitPage"] is Bool) {
            optionsBuilder = optionsBuilder.skipExitPage(args["skipExitPage"]! as! Bool)
        }
        
        if (args["locale"] is String) {
            optionsBuilder = optionsBuilder.locale(args["locale"]! as! String)
        }
        
        if (args["theme"] is String) {
            let theme = args["theme"]! as! String
            if(theme == "light") {
                optionsBuilder = optionsBuilder.theme(.light)
            } else if (theme == "dark") {
                optionsBuilder = optionsBuilder.theme(.dark)
            } else if (theme == "system") {
                optionsBuilder = optionsBuilder.theme(.system)
            }
        }
        
        var colorsBuilder = KhipuColors.Builder()
            
        if (args["lightBackground"] is String) {
            colorsBuilder = colorsBuilder.lightBackground(args["lightBackground"]! as! String)
        }
        if (args["lightOnBackground"] is String) {
            colorsBuilder = colorsBuilder.lightOnBackground(args["lightOnBackground"]! as! String)
        }
        if (args["lightPrimary"] is String) {
            colorsBuilder = colorsBuilder.lightPrimary(args["lightPrimary"]! as! String)
        }
        if (args["lightOnPrimary"] is String) {
            colorsBuilder = colorsBuilder.lightOnPrimary(args["lightOnPrimary"]! as! String)
        }
        if (args["lightTopBarContainer"] is String) {
            colorsBuilder = colorsBuilder.lightTopBarContainer(args["lightTopBarContainer"]! as! String)
        }
        if (args["lightOnTopBarContainer"] is String) {
            colorsBuilder = colorsBuilder.lightOnTopBarContainer(args["lightOnTopBarContainer"]! as! String)
        }
        if (args["darkBackground"] is String) {
            colorsBuilder = colorsBuilder.darkBackground(args["darkBackground"]! as! String)
        }
        if (args["darkOnBackground"] is String) {
            colorsBuilder = colorsBuilder.darkOnBackground(args["darkOnBackground"]! as! String)
        }
        if (args["darkPrimary"] is String) {
            colorsBuilder = colorsBuilder.darkPrimary(args["darkPrimary"]! as! String)
        }
        if (args["darkOnPrimary"] is String) {
            colorsBuilder = colorsBuilder.darkOnPrimary(args["darkOnPrimary"]! as! String)
        }
        if (args["darkTopBarContainer"] is String) {
            colorsBuilder = colorsBuilder.darkTopBarContainer(args["darkTopBarContainer"]! as! String)
        }
        if (args["darkOnTopBarContainer"] is String) {
            colorsBuilder = colorsBuilder.darkOnTopBarContainer(args["darkOnTopBarContainer"]! as! String)
        }
        
        optionsBuilder = optionsBuilder.colors(colorsBuilder.build())
        
        DispatchQueue.main.async {
            KhipuLauncher.launch(presenter: rootViewController,
                                 operationId: operationId,
                                 options: optionsBuilder.build()){ khipuResult in
                result([
                    "operationId": khipuResult.operationId,
                    "result": khipuResult.result,
                    "exitTitle": khipuResult.exitTitle,
                    "exitMessage": khipuResult.exitMessage,
                    "exitUrl": khipuResult.exitUrl as Any,
                    "failureReason": khipuResult.failureReason as Any,
                    "continueUrl": khipuResult.continueUrl as Any,
                    "events": khipuResult.events.map({ event in
                        return [
                            "name": event.name,
                            "type": event.type,
                            "timestamp": event.timestamp
                        ]
                    })
                ])
            }
            
            
        }
    }
}
