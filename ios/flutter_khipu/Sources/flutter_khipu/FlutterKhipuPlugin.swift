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


    /// The view controller Khipu should be presented from.
    ///
    /// Goes through the window scene rather than `UIApplication.windows`, which is
    /// deprecated since iOS 15 and returns windows across every connected scene.
    /// Then walks up any presented controllers: UIKit refuses to present on a
    /// controller that is already presenting, which is what a merchant hits when
    /// launching Khipu from behind one of their own modals.
    ///
    /// Kept private to this type rather than exposed as a `UIViewController`
    /// extension, so a merchant's own `topMostViewController` cannot collide with
    /// it once the plugin is statically linked into their app.
    private static func presenter() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        else {
            return nil
        }

        var controller = window.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }

    private func startOperation(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let rootViewController = FlutterKhipuPlugin.presenter() else {
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

        if (args["titleImageUrl"] is String) {
            optionsBuilder = optionsBuilder.topBarImageUrl(args["titleImageUrl"]! as! String)
        }

        if (args["skipExitPage"] is Bool) {
            optionsBuilder = optionsBuilder.skipExitPage(args["skipExitPage"]! as! Bool)
        }

        if (args["skipExitSuccessPage"] is Bool) {
            optionsBuilder = optionsBuilder.skipExitSuccessPage(args["skipExitSuccessPage"]! as! Bool)
        }

        if (args["showFooter"] is Bool) {
            optionsBuilder = optionsBuilder.showFooter(args["showFooter"]! as! Bool)
        }

        if (args["showMerchantLogo"] is Bool) {
            optionsBuilder = optionsBuilder.showMerchantLogo(args["showMerchantLogo"]! as! Bool)
        }

        if (args["showPaymentDetails"] is Bool) {
            optionsBuilder = optionsBuilder.showPaymentDetails(args["showPaymentDetails"]! as! Bool)
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
