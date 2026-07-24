import Flutter
import UIKit

/// On-device diagnostics ring buffer (no Mac / Console.app required).
///
/// Every scene lifecycle callback appends a timestamped line to UserDefaults,
/// which survives the (possibly failed) Dynamic Island tap. The next time the
/// app is opened by hand, the Flutter side reads these lines back over the
/// `qqmusic_ipod/device` channel and shows them in an in-app log viewer.
enum SceneDiag {
  static let key = "scene_diag_log"
  private static let maxLines = 120

  static func log(_ message: String) {
    NSLog("[SceneDelegate] %@", message)
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
}

class SceneDelegate: FlutterSceneDelegate {
  // Live Activity widgetURL (qqmusicpod://nowplaying) arrives here under UIScene.
  // Must explicitly make the window key+visible: the Flutter engine may still be
  // resuming from background when SpringBoard delivers the URL, so relying on
  // FlutterSceneDelegate alone leaves the app visually frozen.
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    let urls = URLContexts.map { $0.url.absoluteString }.joined(separator: ", ")
    SceneDiag.log("openURLContexts: [\(urls)]")
    super.scene(scene, openURLContexts: URLContexts)
    guard let windowScene = scene as? UIWindowScene else { return }
    // Bring the first Flutter window to the foreground immediately.
    windowScene.windows.first?.makeKeyAndVisible()
  }

  override func sceneWillEnterForeground(_ scene: UIScene) {
    SceneDiag.log("sceneWillEnterForeground")
    super.sceneWillEnterForeground(scene)
    // Ensure window is key when returning from background via any path
    // (e.g. Dynamic Island tap while app is suspended).
    guard let windowScene = scene as? UIWindowScene else { return }
    windowScene.windows.first?.makeKeyAndVisible()
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    SceneDiag.log("sceneDidBecomeActive")
    super.sceneDidBecomeActive(scene)
    // Re-assert window visibility after the Flutter engine has processed
    // sceneWillEnterForeground — the Metal drawable may not exist yet at
    // sceneWillEnterForeground time so a second call here covers that gap.
    guard let windowScene = scene as? UIWindowScene else { return }
    DispatchQueue.main.async {
      windowScene.windows.first?.makeKeyAndVisible()
    }
  }

  override func sceneWillResignActive(_ scene: UIScene) {
    SceneDiag.log("sceneWillResignActive")
    super.sceneWillResignActive(scene)
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    SceneDiag.log("sceneDidEnterBackground")
    super.sceneDidEnterBackground(scene)
  }

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    let activities = connectionOptions.userActivities
      .map { $0.activityType }.joined(separator: ", ")
    let urls = connectionOptions.urlContexts
      .map { $0.url.absoluteString }.joined(separator: ", ")
    SceneDiag.log("willConnectTo (cold launch) activities:[\(activities)] urls:[\(urls)]")
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    SceneDiag.log("continue userActivity: \(userActivity.activityType)")
    super.scene(scene, continue: userActivity)
  }
}