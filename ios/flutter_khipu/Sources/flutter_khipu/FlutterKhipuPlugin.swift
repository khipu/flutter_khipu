import Flutter
import UIKit
import KhipuClientIOS

public class FlutterKhipuPlugin: NSObject, FlutterPlugin, KhipuHostApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FlutterKhipuPlugin()
    KhipuHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
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

    /// True while Khipu is presented.
    ///
    /// Without this, a second call would present Khipu **on top of Khipu**:
    /// `presenter()` walks up to the highest presented controller, which at
    /// that point is Khipu itself. Two payments stacked on the same operation.
    private var operationInFlight = false

    func startOperation(options: KhipuStartOperationOptions) async throws -> KhipuResult? {
        if operationInFlight {
            throw PigeonError(code: "OPERATION_IN_PROGRESS",
                              message: "A Khipu operation is already running",
                              details: nil)
        }

        guard let rootViewController = FlutterKhipuPlugin.presenter() else {
            throw PigeonError(code: "NO_VIEW_CONTROLLER",
                              message: "A view controller is needed to start Khipu",
                              details: nil)
        }

        // SDK types are always named with their module. KhipuClientIOS
        // exports KhipuColors, KhipuResult and KhipuEvent as public, and the
        // ones Pigeon generates land in this same module: unqualified,
        // Swift picks the generated one and the error it gives does not
        // mention shadowing.
        var optionsBuilder = KhipuClientIOS.KhipuOptions.Builder()

        if let title = options.title { optionsBuilder = optionsBuilder.topBarTitle(title) }
        if let url = options.titleImageUrl { optionsBuilder = optionsBuilder.topBarImageUrl(url) }
        if let locale = options.locale { optionsBuilder = optionsBuilder.locale(locale) }
        if let v = options.skipExitPage { optionsBuilder = optionsBuilder.skipExitPage(v) }
        if let v = options.skipExitSuccessPage { optionsBuilder = optionsBuilder.skipExitSuccessPage(v) }
        if let v = options.showFooter { optionsBuilder = optionsBuilder.showFooter(v) }
        if let v = options.showMerchantLogo { optionsBuilder = optionsBuilder.showMerchantLogo(v) }
        if let v = options.showPaymentDetails { optionsBuilder = optionsBuilder.showPaymentDetails(v) }

        if let theme = options.theme {
            switch theme {
            case .light: optionsBuilder = optionsBuilder.theme(.light)
            case .dark: optionsBuilder = optionsBuilder.theme(.dark)
            case .system: optionsBuilder = optionsBuilder.theme(.system)
            }
        }

        var colorsBuilder = KhipuClientIOS.KhipuColors.Builder()

        if let v = options.colors?.lightBackground { colorsBuilder = colorsBuilder.lightBackground(v) }
        if let v = options.colors?.lightOnBackground { colorsBuilder = colorsBuilder.lightOnBackground(v) }
        if let v = options.colors?.lightPrimary { colorsBuilder = colorsBuilder.lightPrimary(v) }
        if let v = options.colors?.lightOnPrimary { colorsBuilder = colorsBuilder.lightOnPrimary(v) }
        if let v = options.colors?.lightTopBarContainer { colorsBuilder = colorsBuilder.lightTopBarContainer(v) }
        if let v = options.colors?.lightOnTopBarContainer { colorsBuilder = colorsBuilder.lightOnTopBarContainer(v) }
        if let v = options.colors?.darkBackground { colorsBuilder = colorsBuilder.darkBackground(v) }
        if let v = options.colors?.darkOnBackground { colorsBuilder = colorsBuilder.darkOnBackground(v) }
        if let v = options.colors?.darkPrimary { colorsBuilder = colorsBuilder.darkPrimary(v) }
        if let v = options.colors?.darkOnPrimary { colorsBuilder = colorsBuilder.darkOnPrimary(v) }
        if let v = options.colors?.darkTopBarContainer { colorsBuilder = colorsBuilder.darkTopBarContainer(v) }
        if let v = options.colors?.darkOnTopBarContainer { colorsBuilder = colorsBuilder.darkOnTopBarContainer(v) }

        optionsBuilder = optionsBuilder.colors(colorsBuilder.build())

        // Load-bearing placement: this must be set *before* the `DispatchQueue.main.async`
        // below, not inside it. Setting it here makes two rapid `startOperation` calls
        // race-free, because the guard at the top of this method sees it synchronously on
        // whatever thread the second call arrives on. Moving this line inside the async
        // block would look like a harmless refactor but would reopen the race: both calls
        // could pass the `operationInFlight` check before either reaches the block.
        //
        // This flag is per-plugin-instance, not a global lock. Two Flutter engines (as in
        // add-to-app, or a `FlutterEngineGroup`) each get their own `FlutterKhipuPlugin`
        // instance and can still present Khipu on top of Khipu.
        operationInFlight = true
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                KhipuClientIOS.KhipuLauncher.launch(presenter: rootViewController,
                                                    operationId: options.operationId,
                                                    options: optionsBuilder.build()) { [weak self] khipuResult in
                    // Released only here, by the SDK's completion closure. That is safe because
                    // in KhipuClientIOS 2.17.1 every SDK-driven exit reaches this closure — the
                    // close button, every terminal message, and even a terminal message the SDK
                    // cannot parse — and the view is presented `.overFullScreen`, so there is no
                    // interactive-dismiss (swipe-to-dismiss) path around it. The residual hole is
                    // the *host app* dismissing Khipu's view controller itself, bypassing the
                    // SDK; that would leave `operationInFlight` stuck `true` and this plugin
                    // rejecting every later call with `OPERATION_IN_PROGRESS` for the life of the
                    // process.
                    //
                    // The continuation is resumed exactly once here: the SDK's closure runs a
                    // single time per operation, and there is no other `resume` on any other
                    // path in this block. Resuming twice is a Swift crash; never resuming leaves
                    // the merchant's Dart `Future` hanging forever — the same defect Cycle 1
                    // closed on Android.
                    self?.operationInFlight = false
                    continuation.resume(returning: KhipuResult(
                        operationId: khipuResult.operationId,
                        result: Self.statusOf(khipuResult.result),
                        exitTitle: khipuResult.exitTitle,
                        exitMessage: khipuResult.exitMessage,
                        events: khipuResult.events.map { event in
                            KhipuEvent(name: event.name,
                                       type: event.type,
                                       timestamp: event.timestamp)
                        },
                        exitUrl: khipuResult.exitUrl,
                        failureReason: khipuResult.failureReason,
                        continueUrl: khipuResult.continueUrl
                    ))
                }
            }
        }
    }

    /// Translates the SDK's free text into the channel's enum.
    ///
    /// The five values are the ones the native client emits; `.unknown` is
    /// what makes a new value from the server reach the merchant instead of
    /// breaking the whole message. It has to match `statusOf` in
    /// FlutterKhipuPlugin.kt: they are the same contract written twice.
    private static func statusOf(_ raw: String) -> KhipuResultStatus {
        switch raw {
        case "OK": return .ok
        case "ERROR": return .error
        case "WARNING": return .warning
        case "CONTINUE": return .mustContinue
        case "USER_CANCELED": return .userCanceled
        default: return .unknown
        }
    }
}
