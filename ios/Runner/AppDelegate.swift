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
    Self.ensureKeyWindow(window)
    return launched
  }

  /// Now Playing / Dynamic Island / Handoff resume path.
  /// iOS often delivers an NSUserActivity rather than openURL when the user
  /// taps system Now Playing surfaces.
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    Self.ensureKeyWindow(window)
    Self.bringToForeground()

    // Let Flutter / plugins handle first (universal links, etc.).
    let handledBySuper = super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
    if handledBySuper {
      return true
    }

    // Accept media / browsing / any activity that woke us from system UI.
    let type = userActivity.activityType
    if type == NSUserActivityTypeBrowsingWeb
      || type.contains("Media")
      || type.contains("media")
      || type.contains("NowPlaying")
      || type.contains("MPNowPlaying")
      || type.contains("audio")
      || type.contains("Audio")
    {
      return true
    }

    // Still return true so SpringBoard does not treat the wake as failed
    // when the process was already the Now Playing owner.
    return true
  }

  override func application(
    _ application: UIApplication,
    willContinueUserActivityWithType userActivityType: String
  ) -> Bool {
    Self.ensureKeyWindow(window)
    return true
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    Self.ensureKeyWindow(window)
    return super.application(app, open: url, options: options)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    Self.ensureKeyWindow(window)
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
    var info = center.nowPlayingInfo ?? [:]

    // Playback identity  required for system surfaces to treat this process
    // as the active Now Playing owner.
    info[MPNowPlayingInfoPropertyPlaybackRate] = playing ? 1.0 : 0.0
    info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
    info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
    info[MPNowPlayingInfoPropertyIsLiveStream] = false

    if info[MPNowPlayingInfoPropertyElapsedPlaybackTime] == nil {
      info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
    }

    // Re-assign the full dictionary so SpringBoard picks up identity changes.
    center.nowPlayingInfo = info

    if #available(iOS 13.0, *) {
      center.playbackState = playing ? .playing : .paused
    }

    // Advertise a user activity so continueUserActivity has something to
    // resume when system media UI hands control back to the app.
    DispatchQueue.main.async {
      publishNowPlayingUserActivity(playing: playing, info: info)
    }

    return true
  }

  private static func publishNowPlayingUserActivity(
    playing: Bool,
    info: [String: Any]
  ) {
    guard
      let appDelegate = UIApplication.shared.delegate as? AppDelegate,
      let controller = appDelegate.window?.rootViewController
    else {
      return
    }

    let activity = NSUserActivity(activityType: "com.qqmusic.ipod.now-playing")
    activity.title = (info[MPMediaItemPropertyTitle] as? String) ?? "Ambient Player"
    activity.isEligibleForHandoff = false
    activity.isEligibleForSearch = false
    activity.isEligibleForPrediction = false
    activity.userInfo = [
      "playing": playing,
      "title": (info[MPMediaItemPropertyTitle] as? String) ?? "",
      "artist": (info[MPMediaItemPropertyArtist] as? String) ?? "",
    ]
    activity.becomeCurrent()
    controller.userActivity = activity
  }

  private static func ensureKeyWindow(_ window: UIWindow?) {
    guard let window else { return }
    if window.isHidden {
      window.isHidden = false
    }
    window.makeKeyAndVisible()
  }

  private static func bringToForeground() {
    // No-op beyond key window  system already activates the process.
    // Keeping a hook for future Flutter method-channel notify if needed.
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