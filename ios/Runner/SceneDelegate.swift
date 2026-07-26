import Darwin
import Flutter
import MediaPlayer
import UIKit

/// On-device wake diagnostics (no Mac / Console.app).
enum WakeDiag {
  static let key = "wake_diag_log"
  private static let maxLines = 200

  static func log(_ message: String) {
    NSLog("[WakeDiag] %@", message)
    let defaults = UserDefaults.standard
    var lines = defaults.stringArray(forKey: key) ?? []
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    lines.append("\(formatter.string(from: Date())) \(message)")
    if lines.count > maxLines {
      lines.removeFirst(lines.count - maxLines)
    }
    defaults.set(lines, forKey: key)
  }

  static func read() -> [String] {
    UserDefaults.standard.stringArray(forKey: key) ?? []
  }

  static func clear() {
    UserDefaults.standard.removeObject(forKey: key)
  }

  /// Public Now Playing snapshot (safe on main; no private APIs).
  static func probeLocal(reason: String) {
    let selfPid = Int(getpid())
    let bundleId = Bundle.main.bundleIdentifier ?? "(nil)"
    let center = MPNowPlayingInfoCenter.default()
    let info = center.nowPlayingInfo
    let title = (info?[MPMediaItemPropertyTitle] as? String) ?? "(no title)"
    let artist = (info?[MPMediaItemPropertyArtist] as? String) ?? ""
    let rate = info?[MPNowPlayingInfoPropertyPlaybackRate] as? Double
    let rateText = rate.map { String(format: "%.2f", $0) } ?? "nil"
    var playbackState = "n/a"
    if #available(iOS 13.0, *) {
      switch center.playbackState {
      case .unknown: playbackState = "unknown"
      case .playing: playbackState = "playing"
      case .paused: playbackState = "paused"
      case .stopped: playbackState = "stopped"
      case .interrupted: playbackState = "interrupted"
      @unknown default: playbackState = "other"
      }
    }
    log(
      "probe[\(reason)] selfPid=\(selfPid) bundle=\(bundleId) state=\(playbackState) rate=\(rateText) title=\(title) artist=\(artist)"
    )
  }

  /// Manual probe entry point used by the DIAG radar button.
  static func probeNowPlayingIdentity(reason: String) {
    probeLocal(reason: reason)
    MediaRemoteClaim.claim(reason: "probe:\(reason)")
  }
}


/// Safe MediaRemote claim: only simple BOOL APIs (no callback/semaphore).
/// Jellyfin etc. call SetCanBeNowPlayingApplication so the process is eligible
/// as the system Now Playing *application* (not just info publisher).
enum MediaRemoteClaim {
  private static let handle: UnsafeMutableRawPointer? = {
    dlopen(
      "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
      RTLD_LAZY
    )
  }()

  /// Boolean MRMediaRemoteSetCanBeNowPlayingApplication(Boolean)
  private typealias SetCanFn = @convention(c) (UInt8) -> UInt8
  /// void MRMediaRemoteSetNowPlayingApplicationOverrideEnabled(Boolean)
  private typealias SetOverrideFn = @convention(c) (UInt8) -> Void

  @discardableResult
  static func claim(reason: String) -> Bool {
    guard let handle else {
      WakeDiag.log("mediaRemote.claim[\(reason)]: dlopen failed")
      return false
    }
    var ok = false
    if let sym = dlsym(handle, "MRMediaRemoteSetCanBeNowPlayingApplication") {
      let fn = unsafeBitCast(sym, to: SetCanFn.self)
      let result = fn(1)
      WakeDiag.log(
        "mediaRemote.SetCanBeNowPlayingApplication[\(reason)] -> \(result)"
      )
      ok = true
    } else {
      WakeDiag.log("mediaRemote.SetCanBeNowPlayingApplication missing")
    }
    if let sym = dlsym(handle, "MRMediaRemoteSetNowPlayingApplicationOverrideEnabled") {
      let fn = unsafeBitCast(sym, to: SetOverrideFn.self)
      fn(1)
      WakeDiag.log("mediaRemote.SetNowPlayingApplicationOverrideEnabled[\(reason)]")
    }
    return ok
  }
}

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    let activities = connectionOptions.userActivities
      .map { $0.activityType }
      .joined(separator: ", ")
    let urls = connectionOptions.urlContexts
      .map { $0.url.absoluteString }
      .joined(separator: ", ")
    WakeDiag.log(
      "scene.willConnect role=\(session.role.rawValue) activities:[\(activities)] urls:[\(urls)]"
    )
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    WakeDiag.log("scene.didBecomeActive")
    WakeDiag.probeLocal(reason: "sceneDidBecomeActive")
    super.sceneDidBecomeActive(scene)
  }

  override func sceneWillResignActive(_ scene: UIScene) {
    WakeDiag.log("scene.willResignActive")
    super.sceneWillResignActive(scene)
  }

  override func sceneWillEnterForeground(_ scene: UIScene) {
    WakeDiag.log("scene.willEnterForeground")
    super.sceneWillEnterForeground(scene)
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    WakeDiag.log("scene.didEnterBackground")
    WakeDiag.probeLocal(reason: "sceneDidEnterBackground")
    super.sceneDidEnterBackground(scene)
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    let urls = URLContexts.map { $0.url.absoluteString }.joined(separator: ", ")
    WakeDiag.log("scene.openURLContexts: [\(urls)]")
    super.scene(scene, openURLContexts: URLContexts)
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    WakeDiag.log("scene.continueUserActivity: \(userActivity.activityType)")
    super.scene(scene, continue: userActivity)
  }
}
