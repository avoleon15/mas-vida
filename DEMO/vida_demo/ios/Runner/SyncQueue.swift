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
    /// y `efectoAlPonerseAlDia`).
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

    /// Al ponerse al día, donde el día puede no estar en la cola.
    var efectoAlPonerseAlDia: EfectoEnCola {
        switch self {
        case .enviado, .descartado: return .sacar
        case .reintentarDespues: return .encolar
        // Vacío: no se anota. Cortado: la marca no avanza, así que la próxima
        // vez se vuelve a intentar desde ahí; no hace falta la cola.
        case .saltado, .cortado: return .dejar
        }
    }

    /// ¿Mueve la marca de "último día enviado" (`MarcaEnvios`)? Solo lo que
    /// ya no hay que volver a mandar: lo que llegó, y lo que el servidor ya no
    /// acepta por viejo. Un día vacío no la mueve: puede ser un permiso de
    /// Salud que todavía no se dio, y ese día tiene que poder salir después.
    var avanzaMarca: Bool {
        switch self {
        case .enviado, .descartado: return true
        case .saltado, .reintentarDespues, .cortado: return false
        }
    }
}

/// Hasta qué día llegó todo al servidor, para saber desde dónde ponerse al
/// día (decidido 3 oct 2026, ver "Cuándo se manda cada día" en el contrato).
///
/// Reemplaza a la bandera de "backfill ya hecho": un teléfono que nunca
/// mandó nada no tiene marca, y entonces se mandan los últimos
/// `diasPrimeraVez` días (los 7 del backfill de siempre, que dan puntos).
/// Con marca, se manda desde ese día (otra vez, porque pudo seguir sumando
/// pasos después del envío) hasta hoy, sin pasar de la ventana del servidor.
final class MarcaEnvios {
    private static let clave = "vida.ultimoDiaEnviado"

    /// Cuántos días se mandan la primera vez, hoy incluido.
    static let diasPrimeraVez = 7

    private let almacen: UserDefaults
    private let hoy: () -> Date
    private let calendario: Calendar

    init(almacen: UserDefaults = .standard,
         hoy: @escaping () -> Date = Date.init,
         calendario: Calendar = .current) {
        self.almacen = almacen
        self.hoy = hoy
        self.calendario = calendario
    }

    /// `yyyy-MM-dd` del último día que llegó, o `nil` si este teléfono (con
    /// esta cuenta) nunca mandó nada.
    var ultimoDiaEnviado: String? {
        guard let texto = almacen.string(forKey: Self.clave),
              FormatoFechas.diaCalendario.date(from: texto) != nil else { return nil }
        return texto
    }

    /// Anota que `fecha` ya llegó. Solo avanza: los días se recorren del más
    /// viejo al más nuevo, y uno viejo que llegue tarde no la hace retroceder.
    func registrarEnviado(_ fecha: String) {
        guard FormatoFechas.diaCalendario.date(from: fecha) != nil else { return }
        if let actual = ultimoDiaEnviado, actual >= fecha { return }
        almacen.set(fecha, forKey: Self.clave)
    }

    /// Al cerrar sesión o cambiar de cuenta: la próxima cuenta empieza como
    /// la primera vez. Si vuelve a entrar la misma, se reenvían 7 días y el
    /// servidor ignora lo que ya tenía.
    func olvidar() {
        almacen.removeObject(forKey: Self.clave)
    }

    /// Los días que hay que mandar, del más viejo a hoy.
    func diasPorMandar() -> [String] {
        let hoyInicio = calendario.startOfDay(for: hoy())
        guard let masViejoAceptado = calendario.date(
            byAdding: .day, value: -SyncQueue.ventanaDias, to: hoyInicio) else { return [] }

        let desde: Date
        if let texto = ultimoDiaEnviado,
           let marca = FormatoFechas.diaCalendario.date(from: texto) {
            // Una marca en el futuro (el reloj del teléfono se movió) no puede
            // dejar a hoy afuera.
            desde = min(max(calendario.startOfDay(for: marca), masViejoAceptado), hoyInicio)
        } else {
            desde = calendario.date(
                byAdding: .day, value: -(Self.diasPrimeraVez - 1), to: hoyInicio) ?? hoyInicio
        }

        var dias: [String] = []
        var dia = desde
        while dia <= hoyInicio {
            dias.append(FormatoFechas.diaCalendario.string(from: dia))
            guard let siguiente = calendario.date(byAdding: .day, value: 1, to: dia) else { break }
            dia = siguiente
        }
        return dias
    }
}

/// La vuelta día por día que comparten la cola de reintentos y ponerse al día.
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
                case .tomarComoEnviado:
                    // El servidor ya lo guardó; solo no se entendió su
                    // respuesta (ApiClient lo anota en el log).
                    registrar(dia, .enviado)
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
