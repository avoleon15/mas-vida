//
//  SyncQueue.swift
//  Runner (+Vida — A10)
//
//  Cola de reintentos con persistencia local (ticket A8), portada tal cual
//  del spike (+vida_fetch/Networking/SyncQueue.swift) — sin cambios, es
//  Foundation puro sin dependencia de UI.
//
//  IMPORTANTE — la cola guarda FECHAS, no payloads. La primera versión
//  guardaba el `SyncPayload` entero y eso tenía dos problemas serios:
//
//  1. Se congelaba una foto vieja del día. Si el envío fallaba a las 8pm y
//     el usuario seguía caminando, el reintento del día siguiente mandaba la
//     foto de las 8pm; como Luis deduplica por `external_id`, esas muestras
//     nuevas no se mandaban NUNCA y el usuario perdía puntos que sí ganó.
//  2. Cada día con `frecuencia_cardiaca[]` cruda pesa cientos de KB, y
//     UserDefaults se carga entero en memoria al arrancar la app.
//
//  Guardando solo la fecha, el reintento reconstruye el día completo desde
//  HealthKit — que es la fuente de verdad y siempre está disponible local —
//  y la cola pesa bytes. Además, sacar un día de la cola ya no destruye nada:
//  los datos siguen en HealthKit y ese día se puede reenviar cuando sea.
//
//  No hace falta lógica propia de deduplicación: el `external_id` de cada
//  muestra ya es idempotente del lado de Luis (constraint único, L4).
//

import Foundation

final class SyncQueue {
    /// Clave nueva a propósito: la versión anterior guardaba `Data` con los
    /// payloads serializados bajo otra clave, y ese formato ya no se lee.
    private static let clave = "vida.diasPendientes"

    /// Techo de seguridad. Un usuario meses sin red no debería acumular una
    /// lista infinita; con 30 días hay de sobra para el piloto.
    private static let maximoDias = 30

    /// Anota un día como pendiente de reenviar. Si ya estaba, no se duplica.
    func encolar(fecha: String) {
        var actuales = pendientes()
        guard !actuales.contains(fecha) else { return }

        actuales.append(fecha)
        if actuales.count > Self.maximoDias {
            actuales.removeFirst(actuales.count - Self.maximoDias)
        }
        guardar(actuales)
    }

    /// Los días que siguen esperando, en el orden en que se encolaron.
    /// Formato `yyyy-MM-dd`, el mismo del campo `fecha` del contrato.
    func pendientes() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.clave) ?? []
    }

    /// Saca un día de la cola: o porque el reenvío llegó bien, o porque el
    /// servidor lo rechazó de forma permanente y reintentarlo no cambia nada.
    func remover(fecha: String) {
        guardar(pendientes().filter { $0 != fecha })
    }

    private func guardar(_ fechas: [String]) {
        UserDefaults.standard.set(fechas, forKey: Self.clave)
    }
}

/// Cómo terminó un día dentro de una vuelta de envíos.
enum DesenlaceDia {
    case enviado
    /// No había nada que mandar (payload vacío): no se envió.
    case saltado
    case reintentarDespues(Error)
    /// El `422` de la ventana: ese día ya no entra nunca, los demás sí.
    case descartado(Error)
    /// Error permanente: la vuelta se corta después de este día.
    case cortado(Error)
}

/// La vuelta día por día que comparten la cola de reintentos y el backfill.
/// Vive aparte (sin HealthKit ni red) para poder probar cuándo sigue y cuándo
/// corta: antes cada uno tenía su propio `for` con su propio `break`.
enum RecorridoDias {
    /// Recorre `dias` en orden. `enviar` manda un día y devuelve `false` si no
    /// había nada que mandar. Después de CADA día llama a `registrar`, para que
    /// quien llama toque la cola en ese momento (si la app se cierra a mitad
    /// de la vuelta, lo ya hecho queda hecho).
    ///
    /// Decide con `AccionDiaFallido`: tras un `descartarYCortar` no se intenta
    /// ningún día más, ni se llama a `registrar` por ellos.
    @MainActor
    static func recorrer(
        _ dias: [String],
        enviar: (String) async throws -> Bool,
        registrar: (String, DesenlaceDia) -> Void
    ) async {
        for dia in dias {
            do {
                let seEnvio = try await enviar(dia)
                registrar(dia, seEnvio ? .enviado : .saltado)
            } catch {
                switch AccionDiaFallido.para(error) {
                case .reintentarDespues:
                    registrar(dia, .reintentarDespues(error))
                case .descartarYSeguir:
                    registrar(dia, .descartado(error))
                case .descartarYCortar:
                    registrar(dia, .cortado(error))
                    // `return`, no `break`: dentro de un `switch`, `break` solo
                    // saldría del `switch` y la vuelta seguiría.
                    return
                }
            }
        }
    }
}
