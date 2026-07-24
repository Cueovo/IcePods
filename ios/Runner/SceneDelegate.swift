import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // Live Activity widgetURL (qqmusicpod://nowplaying) arrives here under UIScene.
  // Must explicitly make the window key+visible: the Flutter engine may still be
  // resuming from background when SpringBoard delivers the URL, so relying on
  // FlutterSceneDelegate alone leaves the app visually frozen.
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    guard let windowScene = scene as? UIWindowScene else { return }
    // Bring the first Flutter window to the foreground immediately.
    windowScene.windows.first?.makeKeyAndVisible()
  }

  override func sceneWillEnterForeground(_ scene: UIScene) {
    super.sceneWillEnterForeground(scene)
    // Ensure window is key when returning from background via any path
    // (e.g. Dynamic Island tap while app is suspended).
    guard let windowScene = scene as? UIWindowScene else { return }
    windowScene.windows.first?.makeKeyAndVisible()
  }
}