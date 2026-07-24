import Flutter
import MediaPlayer
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    application.beginReceivingRemoteControlEvents()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Expose UIScreen continuous corner radius so the framed glass can sit
    // concentrically inside the physical display curve (14 Pro Max ≈ 55pt, etc.).
    let channel = FlutterMethodChannel(
      name: "qqmusic_ipod/device",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "displayCornerRadius":
        result(Self.displayCornerRadius())
      case "readSceneDiag":
        result(UserDefaults.standard.stringArray(forKey: SceneDiag.key) ?? [])
      case "clearSceneDiag":
        UserDefaults.standard.removeObject(forKey: SceneDiag.key)
        result(nil)
      case "setNowPlayingPlaybackState":
        guard #available(iOS 13.0, *), let state = call.arguments as? String else {
          result(nil)
          return
        }
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let center = MPNowPlayingInfoCenter.default()
        let rate: Double
        switch state {
        case "playing":
          center.playbackState = .playing
          rate = 1.0
        case "paused":
          center.playbackState = .paused
          rate = 0.0
        case "stopped":
          center.playbackState = .stopped
          rate = 0.0
        default:
          result(FlutterError(
            code: "invalid_now_playing_state",
            message: "Unsupported Now Playing playback state: \(state)",
            details: nil
          ))
          return
        }
        if var info = center.nowPlayingInfo {
          info[MPNowPlayingInfoPropertyPlaybackRate] = rate
          info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = rate == 0 ? 1.0 : rate
          center.nowPlayingInfo = info
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Reads Apple's continuous display corner radius (logical points).
  ///
  /// Prefer public-ish KVC keys; fall back to 0 so Dart uses its heuristic table.
  private static func displayCornerRadius() -> Double {
    let screen = UIScreen.main
    // Newer SDKs / runtimes may expose without underscore.
    if let value = screen.value(forKey: "displayCornerRadius") as? CGFloat, value > 0 {
      return Double(value)
    }
    if let value = screen.value(forKey: "_displayCornerRadius") as? CGFloat, value > 0 {
      return Double(value)
    }
    return 0
  }
}
