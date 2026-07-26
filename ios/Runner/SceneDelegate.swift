import Darwin
import Flutter
import MediaPlayer
import UIKit

/// On-device wake diagnostics (no Mac / Console.app).
/// Survives a failed Now Playing tap; open the app via icon and read back.
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

  /// Snapshot local process + public Now Playing state + MediaRemote PID.
  static func probeNowPlayingIdentity(reason: String) {
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
    MediaRemoteProbe.queryAndLog(selfPid: selfPid)
  }
}

/// Best-effort MediaRemote private API probe via dlsym (no hard link).
enum MediaRemoteProbe {
  // void MRMediaRemoteGetNowPlayingApplicationPID(dispatch_queue_t, void (^)(int))
  private typealias GetPidFn = @convention(c) (
    DispatchQueue, @convention(block) (Int32) -> Void
  ) -> Void

  // void MRMediaRemoteGetNowPlayingApplicationDisplayID(dispatch_queue_t, void (^)(CFStringRef))
  private typealias GetDisplayIdFn = @convention(c) (
    DispatchQueue, @convention(block) (CFString?) -> Void
  ) -> Void

  private static let handle: UnsafeMutableRawPointer? = {
    let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
    if let h = dlopen(path, RTLD_NOW) {
      return h
    }
    return dlopen(nil, RTLD_NOW)
  }()

  static func queryAndLog(selfPid: Int) {
    guard let handle else {
      WakeDiag.log("mediaRemote: dlopen failed")
      return
    }

    if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") {
      let fn = unsafeBitCast(sym, to: GetPidFn.self)
      let sem = DispatchSemaphore(value: 0)
      var remotePid: Int32 = -999
      fn(DispatchQueue.main) { pid in
        remotePid = pid
        sem.signal()
      }
      _ = sem.wait(timeout: .now() + 2.0)
      if remotePid == -999 {
        WakeDiag.log("mediaRemote.nowPlayingAppPID=TIMEOUT selfPid=\(selfPid)")
      } else {
        let match: String
        if remotePid == 0 {
          match = "NONE"
        } else if Int(remotePid) == selfPid {
          match = "MATCH"
        } else {
          match = "MISMATCH"
        }
        WakeDiag.log(
          "mediaRemote.nowPlayingAppPID=\(remotePid) selfPid=\(selfPid) \(match)"
        )
      }
    } else {
      WakeDiag.log("mediaRemote: GetNowPlayingApplicationPID missing")
    }

    if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationDisplayID") {
      let fn = unsafeBitCast(sym, to: GetDisplayIdFn.self)
      let sem = DispatchSemaphore(value: 0)
      var value = "(timeout)"
      fn(DispatchQueue.main) { cf in
        if let cf {
          value = cf as String
        } else {
          value = "(nil)"
        }
        sem.signal()
      }
      _ = sem.wait(timeout: .now() + 2.0)
      WakeDiag.log("mediaRemote.displayID=\(value)")
    } else {
      WakeDiag.log("mediaRemote: GetNowPlayingApplicationDisplayID missing")
    }
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
    WakeDiag.probeNowPlayingIdentity(reason: "sceneDidBecomeActive")
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
    WakeDiag.probeNowPlayingIdentity(reason: "sceneDidEnterBackground")
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
