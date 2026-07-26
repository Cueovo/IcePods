import Darwin
import Flutter
import UIKit

/// Claims Now Playing application eligibility via MediaRemote (TrollStore open path).
enum MediaRemoteClaim {
  private static let handle: UnsafeMutableRawPointer? = {
    dlopen(
      "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
      RTLD_LAZY
    )
  }()

  /// Boolean MRMediaRemoteSetCanBeNowPlayingApplication(Boolean)
  private typealias SetCanFn = @convention(c) (UInt8) -> UInt8

  @discardableResult
  static func claim() -> Bool {
    guard let handle else {
      return false
    }
    guard let sym = dlsym(handle, "MRMediaRemoteSetCanBeNowPlayingApplication") else {
      return false
    }
    let fn = unsafeBitCast(sym, to: SetCanFn.self)
    return fn(1) != 0
  }
}

class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidBecomeActive(_ scene: UIScene) {
    UIApplication.shared.beginReceivingRemoteControlEvents()
    super.sceneDidBecomeActive(scene)
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    // Keep remote-control / NP eligibility alive while background audio continues.
    UIApplication.shared.beginReceivingRemoteControlEvents()
    MediaRemoteClaim.claim()
    super.sceneDidEnterBackground(scene)
  }
}
