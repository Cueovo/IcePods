import AudioToolbox
import Flutter
import UIKit

private final class WheelSystemFeedback {
  private var clickSounds: [SystemSoundID] = []
  private var clickIndex = 0
  private let selection = UISelectionFeedbackGenerator()
  private let lightImpact = UIImpactFeedbackGenerator(style: .light)
  private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)

  init() {
    let assetKey = FlutterDartProject.lookupKey(forAsset: "assets/sounds/click_tick.wav")
    if let path = Bundle.main.path(forResource: assetKey, ofType: nil) {
      let url = URL(fileURLWithPath: path) as CFURL
      for _ in 0..<6 {
        var sound: SystemSoundID = 0
        if AudioServicesCreateSystemSoundID(url, &sound) == kAudioServicesNoError {
          clickSounds.append(sound)
        }
      }
    }
    selection.prepare()
    lightImpact.prepare()
    mediumImpact.prepare()
  }

  deinit {
    for sound in clickSounds {
      AudioServicesDisposeSystemSoundID(sound)
    }
  }

  func playClick() {
    guard !clickSounds.isEmpty else { return }
    AudioServicesPlaySystemSound(clickSounds[clickIndex])
    clickIndex = (clickIndex + 1) % clickSounds.count
  }

  func selectionChanged() {
    selection.selectionChanged()
    selection.prepare()
  }

  func performLightImpact() {
    lightImpact.impactOccurred(intensity: 0.65)
    lightImpact.prepare()
  }

  func performMediumImpact() {
    mediumImpact.impactOccurred(intensity: 0.82)
    mediumImpact.prepare()
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // audio_service never calls this. MPRemoteCommandCenter handles the button
    // commands, but this is what registers the process as UIKit's remote-control
    // receiver, which is a separate identity from the command targets.
    application.beginReceivingRemoteControlEvents()
    MediaRemoteClaim.claim()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Device metrics. Now Playing is owned by audio_service.
    let channel = FlutterMethodChannel(
      name: "qqmusic_ipod/device",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "displayCornerRadius":
        result(Self.displayCornerRadius())
      case "claimNowPlayingApp":
        MediaRemoteClaim.claim()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let feedback = WheelSystemFeedback()
    let feedbackChannel = FlutterMethodChannel(
      name: "qqmusic_ipod/system_feedback",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    feedbackChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "playClick":
        feedback.playClick()
        result(nil)
      case "selectionChanged":
        feedback.selectionChanged()
        result(nil)
      case "lightImpact":
        feedback.performLightImpact()
        result(nil)
      case "mediumImpact":
        feedback.performMediumImpact()
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
