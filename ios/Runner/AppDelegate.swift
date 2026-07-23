import AVFoundation
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
      case "claimNowPlaying":
        let playing = (call.arguments as? [String: Any])?["playing"] as? Bool ?? true
        result(Self.claimNowPlaying(playing: playing))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func claimNowPlaying(playing: Bool) -> Bool {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .default, options: [])
      try session.setActive(true)
    } catch {
      return false
    }

    UIApplication.shared.beginReceivingRemoteControlEvents()

    let center = MPNowPlayingInfoCenter.default()
    if var info = center.nowPlayingInfo {
      info[MPNowPlayingInfoPropertyPlaybackRate] = playing ? 1.0 : 0.0
      info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = playing ? 1.0 : 0.0
      center.nowPlayingInfo = info
    }
    if #available(iOS 13.0, *) {
      center.playbackState = playing ? .playing : .paused
    }
    return true
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
