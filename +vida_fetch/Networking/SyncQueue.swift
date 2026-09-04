//
//  SyncQueue.swift
//  +vida_fetch
//
//  Cola de reintentos con persistencia local (ticket A8). Cuando un envío a
//  /api/v1/sync falla por red, el día queda anotado acá para reintentarlo
//  después en vez de perderse.
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
