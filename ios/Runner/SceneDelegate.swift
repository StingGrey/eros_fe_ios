import Flutter
import UIKit

/// Scene callbacks own the window; the application delegate may run before it
/// exists. Preserve Flutter's lifecycle forwarding for plugins and Dart.
class SceneDelegate: FlutterSceneDelegate {
    override func sceneWillResignActive(_ scene: UIScene) {
        if UserDefaults.standard.bool(forKey: "flutter.blurredInRecentTasks") {
            SecurityBlurEffect.addBlurEffect(to: window)
        }
        super.sceneWillResignActive(scene)
    }

    override func sceneDidBecomeActive(_ scene: UIScene) {
        super.sceneDidBecomeActive(scene)
        SecurityBlurEffect.removeBlurEffect(from: window)
    }

    override func sceneWillEnterForeground(_ scene: UIScene) {
        super.sceneWillEnterForeground(scene)
        SecurityBlurEffect.removeBlurEffect(from: window)
    }
}
