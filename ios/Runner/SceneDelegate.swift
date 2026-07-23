import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneWillEnterForeground(_ scene: UIScene) {
    super.sceneWillEnterForeground(scene)
    guard let windowScene = scene as? UIWindowScene else { return }
    for window in windowScene.windows {
      window.makeKeyAndVisible()
    }
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    guard let windowScene = scene as? UIWindowScene else { return }
    for window in windowScene.windows {
      window.makeKeyAndVisible()
    }
  }
}
