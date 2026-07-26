import Flutter
import UIKit

/// On-device wake diagnostics (no Mac / Console.app).
/// Survives a failed Now Playing tap; open the app via icon and read back.
enum WakeDiag {
  static let key = "wake_diag_log"
  private static let maxLines = 150

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