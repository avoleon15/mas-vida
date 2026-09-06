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
        // Solo `estado`, sin el booleano `concedido` que había antes: era
        // exactamente `estado == "concedido"`, o sea un segundo lugar donde
        // podía desincronizarse la misma verdad. Eso fue justo el bug de
        // v3.1, no hacía falta repetirlo.
        //
        // `tipos` viaja solo en los dos casos que efectivamente sondearon.
        // En `no_disponible` no hay HealthKit en el aparato y nunca se
        // consultó nada — inventar ahí un mapa de `false` diría "miramos y no
        // había", que es distinto de "no se pudo mirar".
        case "solicitarPermisos":
          switch await HealthKitManager.shared.solicitarPermisos() {
          case .concedido(let visibles):
            result(["estado": "concedido", "tipos": Self.mapaTipos(visibles)])
          case .sinDatosVisibles(let visibles):
            result(["estado": "sin_datos_visibles", "tipos": Self.mapaTipos(visibles)])
          case .noDisponible(let detalle):
            result(["estado": "no_disponible", "detalle": detalle])
          case .error(let detalle):
            result(FlutterError(code: "PERMISOS_ERROR", message: detalle, details: nil))
          }

        // Fallar no es un solo caso: `encolado` no requiere nada del usuario
        // (se reintenta solo), `sin_acceso_a_salud` requiere que vaya a
        // Ajustes, y `error_permanente` es un problema de configuración que no
        // puede resolver. Flutter necesita distinguirlos para decir algo
        // distinto en cada uno — por eso `estado` y no un booleano.
        case "sincronizar":
          switch await HealthKitManager.shared.enviarSincronizacion() {
          case .ok(let sincronizadoEn):
            result([
              "estado": "ok",
              "sincronizado_en": FormatoFechas.iso8601.string(from: sincronizadoEn),
            ])
          case .encolado(let detalle):
            result(["estado": "encolado", "detalle": detalle])
          case .sinAccesoASalud(let detalle):
            result(["estado": "sin_acceso_a_salud", "detalle": detalle])
          case .errorPermanente(let detalle):
            result(["estado": "error_permanente", "detalle": detalle])
          }

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  /// Los tipos visibles como mapa para el canal. Se recorre `allCases` y no
  /// el conjunto, así el mapa SIEMPRE trae las tres claves: Daniel nunca
  /// tiene que distinguir "false" de "la clave no vino", y agregar un tipo en
  /// v2 no puede olvidarse de este lado.
  private static func mapaTipos(_ visibles: Set<TipoDatoSalud>) -> [String: Bool] {
    Dictionary(uniqueKeysWithValues: TipoDatoSalud.allCases.map { ($0.rawValue, visibles.contains($0)) })
  }
}
