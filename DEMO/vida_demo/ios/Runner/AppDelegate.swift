import Flutter
import UIKit

/// Nombre del canal — debe coincidir EXACTO con el `MethodChannel` que Daniel
/// crea del lado de Dart (ver lib/datos/healthkit_bridge.dart).
private let canalHealthKit = "com.assures.masvida/healthkit"

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registrarCanalHealthKit(engineBridge)
  }

  /// Registra los 2 únicos métodos del contrato (ver contrato-v3_1.md):
  /// `solicitarPermisos` y `sincronizar`. Todo lo demás (dashboard, niveles,
  /// retos) es HTTP directo de Flutter contra la API de Luis — nunca pasa
  /// por acá.
  private func registrarCanalHealthKit(_ engineBridge: FlutterImplicitEngineBridge) {
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HealthKitBridge") else {
      assertionFailure("No se pudo obtener el registrar de Flutter para HealthKitBridge")
      return
    }
    let canal = FlutterMethodChannel(name: canalHealthKit, binaryMessenger: registrar.messenger())

    canal.setMethodCallHandler { call, result in
      Task { @MainActor in
        switch call.method {
        // `concedido` va acompañado de `estado` porque no son lo mismo:
        // `concedido: false` con estado `sin_datos_visibles` NO significa que
        // el usuario haya negado el permiso — HealthKit no permite saberlo.
        // Significa que no vemos datos, y puede ser cualquiera de las dos.
        case "solicitarPermisos":
          switch await HealthKitManager.shared.solicitarPermisos() {
          case .concedido:
            result(["concedido": true, "estado": "concedido"])
          case .sinDatosVisibles:
            result(["concedido": false, "estado": "sin_datos_visibles"])
          case .noDisponible(let detalle):
            result(["concedido": false, "estado": "no_disponible", "detalle": detalle])
          case .error(let detalle):
            result(FlutterError(code: "PERMISOS_ERROR", message: detalle, details: nil))
          }

        // `ok: false` ya no es un solo caso: `encolado` no requiere nada del
        // usuario (se reintenta solo), `sin_acceso_a_salud` requiere que vaya
        // a Ajustes, y `error_permanente` es un problema de configuración que
        // no puede resolver. Flutter necesita poder distinguirlos para decir
        // algo distinto en cada uno.
        case "sincronizar":
          switch await HealthKitManager.shared.enviarSincronizacion() {
          case .ok(let sincronizadoEn):
            result([
              "ok": true,
              "estado": "ok",
              "sincronizado_en": FormatoFechas.iso8601.string(from: sincronizadoEn),
            ])
          case .encolado(let detalle):
            result(["ok": false, "estado": "encolado", "detalle": detalle])
          case .sinAccesoASalud(let detalle):
            result(["ok": false, "estado": "sin_acceso_a_salud", "detalle": detalle])
          case .errorPermanente(let detalle):
            result(["ok": false, "estado": "error_permanente", "detalle": detalle])
          }

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
