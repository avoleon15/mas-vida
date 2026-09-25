import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  /// Reintento automático al volver del background (A8) — el equivalente
  /// UIKit de lo que en el spike SwiftUI hacía `.onChange(of: scenePhase)`.
  /// Si `FlutterSceneDelegate` no implementa `sceneDidBecomeActive` (y Xcode
  /// marca error de "does not override any method from its superclass"),
  /// quitar `override` y la llamada a `super` de acá abajo.
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    Task { @MainActor in
      await HealthKitManager.shared.reintentarPendientes()
    }
  }
}
