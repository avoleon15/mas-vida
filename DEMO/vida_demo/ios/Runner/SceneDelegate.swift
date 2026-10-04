import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  /// Cada vez que la app vuelve a primer plano se manda lo que falte: la
  /// cola de reintentos y los días desde el último enviado hasta hoy (ver
  /// `HealthKitManager.ponerseAlDia()`). Es el equivalente UIKit de lo que en
  /// el spike SwiftUI hacía `.onChange(of: scenePhase)`.
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    Task { @MainActor in
      await HealthKitManager.shared.ponerseAlDia()
    }
  }
}
