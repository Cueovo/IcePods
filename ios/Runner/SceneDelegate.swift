import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    guard let windowScene = scene as? UIWindowScene else { return }
    windowScene.windows.first?.makeKeyAndVisible()
  }

  override func sceneWillEnterForeground(_ scene: UIScene) {
    super.sceneWillEnterForeground(scene)
    guard let windowScene = scene as? UIWindowScene else { return }
    windowScene.windows.first?.makeKeyAndVisible()
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    guard let windowScene = scene as? UIWindowScene else { return }
    windowScene.windows.first?.makeKeyAndVisible()
  }
}