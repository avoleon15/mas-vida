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

    /// La misma ventana del servidor (`VENTANA_DIAS` en
    /// Apps/activities/views.py): acepta un día si `fecha >= hoy - 14`. Un día
    /// más viejo ya no entra nunca, así que no tiene sentido seguir
    /// intentándolo. Ver "Ventana de aceptación de datos rezagados" en el
    /// contrato: ventana y cola comparten cifra a propósito.
    static let ventanaDias = 14

    /// Techo de seguridad: hoy + los 14 días de la ventana = 15 fechas válidas
    /// como mucho. Solo se alcanzaría con fechas raras (futuras o ilegibles).
    static let maximoDias = ventanaDias + 1

    private let almacen: UserDefaults
    private let hoy: () -> Date
    private let calendario: Calendar

    /// `almacen` y `hoy` se cambian en las pruebas: otro `UserDefaults` para
    /// no tocar la cola real, y un "hoy" fijo.
    init(almacen: UserDefaults = .standard,
         hoy: @escaping () -> Date = Date.init,
         calendario: Calendar = .current) {
        self.almacen = almacen
        self.hoy = hoy
        self.calendario = calendario
    }

    /// Anota un día como pendiente de reenviar. Si ya estaba, no se duplica.
    /// Un día que ya quedó fuera de la ventana no se anota.
    func encolar(fecha: String) {
        guard !vencido(fecha) else { return }

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
    ///
    /// De paso borra de la cola los que ya quedaron fuera de la ventana: así
    /// caducan solos aunque nunca se vuelva a intentar mandarlos.
    func pendientes() -> [String] {
        let guardados = almacen.stringArray(forKey: Self.clave) ?? []
        let vigentes = guardados.filter { !vencido($0) }
        if vigentes.count != guardados.count {
            guardar(vigentes)
        }
        return vigentes
    }

    /// Saca un día de la cola: o porque el reenvío llegó bien, o porque el
    /// servidor lo rechazó de forma permanente y reintentarlo no cambia nada.
    func remover(fecha: String) {
        guardar(pendientes().filter { $0 != fecha })
    }

    /// Aplica a un día lo que decidió `DesenlaceDia` (ver `efectoEnReintento`
    /// y `efectoEnBackfill`).
    func aplicar(_ efecto: EfectoEnCola, a fecha: String) {
        switch efecto {
        case .sacar: remover(fecha: fecha)
        case .encolar: encolar(fecha: fecha)
        case .dejar: break
        }
    }

    /// ¿El servidor ya rechazaría este día? Misma cuenta que el servidor:
    /// `fecha < hoy - 14`, en días calendario de la zona del teléfono.
    ///
    /// Una fecha que no se puede leer NO se da por vencida acá: la saca
    /// `reintentarPendientes()`, que es quien sabe que no se puede mandar.
    func vencido(_ fecha: String) -> Bool {
        guard let dia = FormatoFechas.diaCalendario.date(from: fecha),
              let limite = calendario.date(
                byAdding: .day, value: -Self.ventanaDias,
                to: calendario.startOfDay(for: hoy())) else { return false }
        return dia < limite
    }

    private func guardar(_ fechas: [String]) {
        almacen.set(fechas, forKey: Self.clave)
    }
}

/// Qué le pasa a un día en la cola después de intentar mandarlo.
enum EfectoEnCola: Equatable {
    case sacar
    case dejar
    case encolar
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

    /// En la cola de reintentos, donde el día ya está anotado.
    var efectoEnReintento: EfectoEnCola {
        switch self {
        // Llegó, o no va a llegar nunca: fuera.
        case .enviado, .descartado, .cortado: return .sacar
        // Ante la duda se queda: un día vacío puede ser un permiso todavía
        // no concedido, y sin red se vuelve a intentar.
        case .saltado, .reintentarDespues: return .dejar
        }
    }

    /// En el backfill, donde el día puede no estar en la cola.
    var efectoEnBackfill: EfectoEnCola {
        switch self {
        case .enviado, .descartado: return .sacar
        case .reintentarDespues: return .encolar
        // Vacío: no se anota. Cortado: la vuelta entera se repite la próxima
        // vez (la bandera de "ya hecho" no se enciende), no hace falta la cola.
        case .saltado, .cortado: return .dejar
        }
    }

    /// ¿Repetir el backfill podría arreglar este día? Solo tras un corte. Un
    /// día descartado por la ventana no entra nunca: repetir no sirve.
    var dejaBackfillIncompleto: Bool {
        if case .cortado = self { return true }
        return false
    }
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
