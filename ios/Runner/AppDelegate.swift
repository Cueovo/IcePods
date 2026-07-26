import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // audio_service never calls this itself. Without it the app is not
    // registered as a remote-control receiver, so SpringBoard renders the
    // Now Playing UI but will not activate the app when it is tapped.
    application.beginReceivingRemoteControlEvents()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Device metrics only - Now Playing is owned by audio_service.
    let channel = FlutterMethodChannel(
      name: "qqmusic_ipod/device",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "displayCornerRadius":
        result(Self.displayCornerRadius())
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