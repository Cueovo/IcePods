import AVFoundation
import Flutter
import MediaPlayer
import ObjectiveC
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static var deviceChannel: FlutterMethodChannel?
  private static var nowPlayingSession: AnyObject?
  private static var sessionCommandsConfigured = false
  private static var wantsNowPlayingActive = false
  private static var playerCaptureInstalled = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    Self.installAVQueuePlayerCapture()
    application.beginReceivingRemoteControlEvents()
    NotificationCenter.default.addObserver(
      forName: UIApplication.willEnterForegroundNotification,
      object: nil,
      queue: .main
    ) { _ in
      if Self.wantsNowPlayingActive {
        _ = Self.claimNowPlaying(playing: true)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "qqmusic_ipod/device",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    Self.deviceChannel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "displayCornerRadius":
        result(Self.displayCornerRadius())
      case "claimNowPlaying":
        let args = call.arguments as? [String: Any]
        let playing = args?["playing"] as? Bool ?? true
        result(Self.claimNowPlaying(playing: playing))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @objc static func claimNowPlaying(playing: Bool) -> Bool {
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(.playback, mode: .default, options: [])
      try audioSession.setActive(true)
    } catch {
      return false
    }

    UIApplication.shared.beginReceivingRemoteControlEvents()
    wantsNowPlayingActive = playing

    let defaultCenter = MPNowPlayingInfoCenter.default()
    var info = defaultCenter.nowPlayingInfo ?? [:]
    info[MPNowPlayingInfoPropertyPlaybackRate] = playing ? 1.0 : 0.0
    info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
    if info[MPNowPlayingInfoPropertyMediaType] == nil {
      info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
    }
    defaultCenter.nowPlayingInfo = info
    if #available(iOS 13.0, *) {
      defaultCenter.playbackState = playing ? .playing : .paused
    }

    if #available(iOS 16.0, *) {
      activateNowPlayingSession(playing: playing, info: info)
    }

    return true
  }

  @available(iOS 16.0, *)
  private static func activateNowPlayingSession(
    playing: Bool,
    info: [String: Any]
  ) {
    guard let player = CapturedAVQueuePlayer.last else {
      return
    }

    let session: MPNowPlayingSession
    if let existing = nowPlayingSession as? MPNowPlayingSession {
      session = existing
    } else {
      session = MPNowPlayingSession(players: [player])
      session.automaticallyPublishesNowPlayingInfo = false
      nowPlayingSession = session
      configureSessionCommands(session.remoteCommandCenter)
    }

    var sessionInfo = info
    sessionInfo[MPNowPlayingInfoPropertyPlaybackRate] = playing ? 1.0 : 0.0
    session.nowPlayingInfoCenter.nowPlayingInfo = sessionInfo
    session.becomeActiveIfPossible { _ in }
  }

  @available(iOS 16.0, *)
  private static func configureSessionCommands(_ center: MPRemoteCommandCenter) {
    guard !sessionCommandsConfigured else { return }
    sessionCommandsConfigured = true

    center.playCommand.isEnabled = true
    center.playCommand.addTarget { _ in
      deviceChannel?.invokeMethod("remotePlay", arguments: nil)
      return .success
    }

    center.pauseCommand.isEnabled = true
    center.pauseCommand.addTarget { _ in
      deviceChannel?.invokeMethod("remotePause", arguments: nil)
      return .success
    }

    center.togglePlayPauseCommand.isEnabled = true
    center.togglePlayPauseCommand.addTarget { _ in
      deviceChannel?.invokeMethod("remoteToggle", arguments: nil)
      return .success
    }

    center.nextTrackCommand.isEnabled = true
    center.nextTrackCommand.addTarget { _ in
      deviceChannel?.invokeMethod("remoteNext", arguments: nil)
      return .success
    }

    center.previousTrackCommand.isEnabled = true
    center.previousTrackCommand.addTarget { _ in
      deviceChannel?.invokeMethod("remotePrevious", arguments: nil)
      return .success
    }

    center.changePlaybackPositionCommand.isEnabled = true
    center.changePlaybackPositionCommand.addTarget { event in
      guard let event = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      deviceChannel?.invokeMethod(
        "remoteSeek",
        arguments: ["positionMs": Int(event.positionTime * 1000.0)]
      )
      return .success
    }
  }

  private static func installAVQueuePlayerCapture() {
    CapturedAVQueuePlayer.install()
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

/// Captures just_audio's AVQueuePlayer created via `initWithItems:`.
enum CapturedAVQueuePlayer {
  private(set) static weak var last: AVQueuePlayer?
  private static var installed = false

  static func install() {
    guard !installed else { return }
    installed = true

    let cls: AnyClass = AVQueuePlayer.self
    let selector = NSSelectorFromString("initWithItems:")
    guard let method = class_getInstanceMethod(cls, selector) else { return }

    let originalIMP = method_getImplementation(method)
    let block: @convention(block) (AnyObject, NSArray) -> AnyObject = { this, items in
      typealias InitIMP = @convention(c) (AnyObject, Selector, NSArray) -> Unmanaged<AnyObject>
      let initIMP = unsafeBitCast(originalIMP, to: InitIMP.self)
      let instance = initIMP(this, selector, items).takeRetainedValue()
      if let player = instance as? AVQueuePlayer {
        CapturedAVQueuePlayer.last = player
      }
      return instance
    }
    method_setImplementation(method, imp_implementationWithBlock(block))
  }
}
