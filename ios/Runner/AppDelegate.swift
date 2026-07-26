import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let keys = launchOptions?.keys.map { String(describing: $0.rawValue) }
      .joined(separator: ", ") ?? ""
    WakeDiag.log("app.didFinishLaunching options:[\(keys)]")
    // audio_service never calls this. MPRemoteCommandCenter handles the button
    // commands, but this is what registers the process as UIKit's remote-control
    // receiver, which is a separate identity from the command targets.
    application.beginReceivingRemoteControlEvents()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    WakeDiag.log("app.didBecomeActive")
    super.applicationDidBecomeActive(application)
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    WakeDiag.log("app.willEnterForeground")
    super.applicationWillEnterForeground(application)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    WakeDiag.log("app.didEnterBackground")
    super.applicationDidEnterBackground(application)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    WakeDiag.log("app.openURL: \(url.absoluteString)")
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    WakeDiag.log("app.continueUserActivity: \(userActivity.activityType)")
    return super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Device metrics + wake diagnostics. Now Playing is owned by audio_service.
    let channel = FlutterMethodChannel(
      name: "qqmusic_ipod/device",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "displayCornerRadius":
        result(Self.displayCornerRadius())
      case "readWakeDiag":
        result(WakeDiag.read())
      case "clearWakeDiag":
        WakeDiag.clear()
        result(nil)
      case "markWakeDiag":
        let label = (call.arguments as? String) ?? "mark"
        WakeDiag.log("dart.\(label)")
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func displayCornerRadius() -> Double {
    let screen = UIScreen.main
    if let value = screen.value(forKey: "displayCornerRadius") as? CGFloat, value > 0 {
      return Double(value)
    }
    if let value = screen.value(forKey: "_displayCornerRadius") as? CGFloat, value > 0 {
      return Double(value)
    }
    return 0
  }
}