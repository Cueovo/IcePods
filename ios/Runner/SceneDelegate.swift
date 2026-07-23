import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // Live Activity widgetURL (qqmusicpod://nowplaying) arrives here under UIScene.
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
  }
}