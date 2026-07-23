import AVFoundation
import Flutter
import MediaPlayer
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    application.beginReceivingRemoteControlEvents()
    GeneratedPluginRegistrant.register(with: self)

    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    Self.registerDeviceChannel(window: window)
    return launched
  }

  private static func registerDeviceChannel(window: UIWindow?) {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "qqmusic_ipod/device",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "displayCornerRadius":
        result(displayCornerRadius())
      case "claimNowPlaying":
        let playing = (call.arguments as? [String: Any])?["playing"] as? Bool ?? true
        result(claimNowPlaying(playing: playing))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Activate a non-mixable playback session and refresh Now Playing ownership.
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

  /// Reads Apple continuous display corner radius (logical points).
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