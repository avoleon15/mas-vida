//
//  HealthKitManager.swift
//  Runner (+Vida — A10)
//
//  Puente real de HealthKit para el MethodChannel Swift↔Flutter. Portado y
//  adaptado del spike (+vida_fetch, tickets A7-A9) — misma lógica de
//  sincronización, cola de reintentos y backfill, ya validada en hardware
//  real. Lo que se saca acá es todo lo que en el spike solo existía para la
//  pantalla de depuración con SwiftUI (@Published, entrenamientos, export a
//  archivo) — este archivo no tiene UI propia, lo maneja AppDelegate a través
//  de los 2 métodos del MethodChannel: `solicitarPermisos` y `sincronizar`.
//
//  El cálculo de puntos, FCM y niveles NUNCA va acá — eso lo hace siempre el
//  servidor de Luis con datos crudos (ver reglas del proyecto).
//

import Foundation
import HealthKit
import os

/// Diagnostico de la capa de salud. Global `let` a proposito: `Logger` es
/// `Sendable`, asi que se puede usar desde el callback de una HKSampleQuery
/// (que llega en una cola cualquiera) sin pelear con el aislamiento del
/// @MainActor de la clase.
///
/// REGLA: aca nunca entra un valor de salud — ni un conteo de pasos ni un
/// bpm. Solo hechos estructurales (que tipo se ve, que fallo). Los logs de
/// `os` se persisten y se leen desde un archivo de diagnostico del
/// dispositivo; un dato de salud ahi seria una fuga.
private let logSalud = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.assures.masvida",
    category: "HealthKit"
)

/// Estadísticas de ritmo cardíaco (bpm) para un rango de fechas.
struct HeartRateStats {
    let promedio: Double?
    let minimo: Double?
    let maximo: Double?

    static let vacio = HeartRateStats(promedio: nil, minimo: nil, maximo: nil)
}

/// Errores propios de esta capa, para distinguir el motivo real de un fallo
/// (permiso vs. rango de fechas) en vez de un mensaje genérico.
enum HealthKitError: LocalizedError {
    case noDisponible
    case rangoInvalido

    var errorDescription: String? {
        switch self {
        case .noDisponible:
            return "HealthKit no está disponible en este dispositivo."
        case .rangoInvalido:
            return "No se pudo calcular el rango de fechas."
        }
    }
}

/// Los tipos de dato que la app lee. Es un enum con `rawValue` y no tres
/// booleanos sueltos por dos razones: el `rawValue` es el nombre que viaja
/// por el MethodChannel (una sola fuente de verdad para la serialización), y
/// cuando en v2 entre sueño la forma del resultado no cambia.
enum TipoDatoSalud: String, CaseIterable {
    case pasos = "pasos"
    case ritmoCardiaco = "ritmo_cardiaco"
    case entrenamientos = "entrenamientos"
}

/// Resultado de pedir permisos.
///
/// Los permisos de HealthKit son **por tipo**: el usuario puede conceder
/// pasos y negar ritmo cardíaco en el mismo diálogo. Y HealthKit NUNCA
/// informa qué negó — con el permiso negado devuelve arrays vacíos, no un
/// error. Lo único posible es consultar cada tipo y ver si vuelve algo.
///
/// Por eso los dos casos que sondearon cargan `visibles`: un sí/no global
/// mentiría. Pero ojo con cómo se lee ese conjunto — la ambigüedad NO es la
/// misma en los tres tipos:
///
/// - `pasos` vacío ⇒ casi seguro permiso negado. Con permiso, cualquier
///   usuario tiene pasos en 30 días.
/// - `ritmoCardiaco` / `entrenamientos` vacíos ⇒ lo más probable es que no
///   tenga reloj, NO que haya negado. En el piloto la mayoría no va a tener
///   uno. Tratar esto como "negaste el permiso" sería ruido para casi todos.
enum ResultadoPermisos {
    /// Se ven pasos: la app puede hacer su trabajo base. `visibles` dice qué
    /// más se ve, que es lo que decide si el usuario puede ganar puntos por
    /// intensidad además de por pasos.
    case concedido(visibles: Set<TipoDatoSalud>)
    /// No se ven pasos, que son el piso del puntaje. Puede ser permiso
    /// negado, o un usuario real sin actividad en 30 días — indistinguibles.
    case sinDatosVisibles(visibles: Set<TipoDatoSalud>)
    case noDisponible(detalle: String)
    case error(detalle: String)
}

/// Resultado de una sincronización. Cada caso implica una acción distinta del
/// lado del usuario, por eso no alcanza con un `Bool`: `encolado` no requiere
/// nada (se reintenta solo), `sinAccesoASalud` requiere ir a Ajustes, y
/// `errorPermanente` es un problema de configuración que el usuario no puede
/// resolver y hay que reportar.
enum ResultadoSincronizacion {
    case ok(sincronizadoEn: Date)
    case encolado(detalle: String)
    case sinAccesoASalud(detalle: String)
    case errorPermanente(detalle: String)
}

@MainActor
final class HealthKitManager {

    /// Instancia única: la usan tanto AppDelegate (para los 2 métodos del
    /// MethodChannel) como SceneDelegate (para el reintento automático al
    /// volver del background) — necesitan ver la misma cola de reintentos.
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()

    /// Cola de reintentos con persistencia local (A8) para los payloads que
    /// fallaron al enviarse a Luis.
    private let syncQueue = SyncQueue()

    // MARK: - Estado

    private(set) var autorizado: Bool = false
    private(set) var errorBackfill: String?
    private(set) var errorReintento: String?

    /// `usuario_id` del payload.
    /// TODO(A10): placeholder hasta que exista login real (L10/D6) — el
    /// MethodChannel todavía no recibe un usuario autenticado desde Flutter.
    private let usuarioID = "alvaro-001"

    /// URL base del backend de Luis.
    /// TODO(A10): reemplazar por configuración real antes de TestFlight —
    /// hoy apunta a la misma IP local usada para probar A7-A9
    /// (ver mock_luis_server.py). No debe llegar así a TestFlight.
    private var baseURLTexto: String = "http://192.168.1.21:8000"

    private static let claveBackfillInicialHecho = "vida.backfillInicialHecho"

    /// El último backfill recorrió los días pedidos sin abortar por un error
    /// permanente. Días encolados por falta de red no cuentan como abortar:
    /// quedaron a salvo en la cola de reintentos.
    private var huboRecorridoCompleto = false

    private var enviando = false
    private var reintentando = false
    private var backfillEnProgreso = false

    /// Respuesta del envío de HOY — lo que arma el resultado que vuelve por
    /// el MethodChannel a Flutter.
    private(set) var respuestaEnvioHoy: RespuestaSincronizacion?
    private(set) var respuestaEnvioHoyEn: Date?

    /// Cuántos días quedan esperando a ser reenviados (A8).
    private(set) var pendientesEnCola: Int = 0

    /// Hay una operación de red en curso. Las tres acciones (enviar hoy,
    /// reintentar, backfill) pegan al mismo endpoint y tocan la misma cola,
    /// así que nunca deben correr en paralelo — ver detalle en el spike
    /// original (misma razón, portada tal cual).
    var ocupado: Bool { enviando || reintentando || backfillEnProgreso }

    private init() {
        // Sin esto el contador arranca en 0 aunque haya días esperando en
        // disco desde una sesión anterior de la app.
        pendientesEnCola = syncQueue.pendientes().count
    }

    // MARK: - Tipos de HealthKit que leemos (v1: pasos, ritmo cardíaco, workouts)
    // Elevación descartada, sueño fuera de alcance en v1 — ver reglas del proyecto.

    private let tipoPasos = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let tipoFrecuenciaCardiaca = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private let tipoEntrenamiento = HKObjectType.workoutType()

    private var tiposLectura: Set<HKObjectType> {
        [tipoPasos, tipoFrecuenciaCardiaca, tipoEntrenamiento]
    }

    // MARK: - solicitarPermisos()
    // Corresponde al método `solicitarPermisos` del MethodChannel.
    // Nota: HealthKit nunca informa si el usuario negó el permiso de lectura,
    // solo se puede inferir consultando y viendo si vuelve algo (ver
    // enviarSincronizacion()).

    func solicitarPermisos() async -> ResultadoPermisos {
        guard HKHealthStore.isHealthDataAvailable() else {
            autorizado = false
            logSalud.error("HealthKit no disponible en este dispositivo")
            return .noDisponible(detalle: HealthKitError.noDisponible.localizedDescription)
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: tiposLectura)
        } catch {
            autorizado = false
            logSalud.error("requestAuthorization falló: \(error.localizedDescription, privacy: .public)")
            return .error(detalle: "No se pudo solicitar autorización: \(error.localizedDescription)")
        }

        // `requestAuthorization` termina sin error aunque el usuario haya
        // negado TODO — "se mostró el diálogo" no es "hay acceso". La única
        // forma de saberlo es consultar cada tipo y ver si vuelve algo.
        let visibles = await tiposVisibles()
        logSalud.notice("Tipos visibles: \(Self.describir(visibles), privacy: .public)")

        // Los pasos son el piso: sin ellos no hay puntaje de ningún tipo, ni
        // por tabla de pasos ni por intensidad. Que falte ritmo cardíaco es
        // degradado pero usable; que falten pasos no.
        guard visibles.contains(.pasos) else {
            autorizado = false
            return .sinDatosVisibles(visibles: visibles)
        }

        autorizado = true

        // Primera sincronización del historial (A9). Antes esto no lo llamaba
        // nadie y el backfill era código inalcanzable: un usuario nuevo
        // entraba con cero historial.
        //
        // Sin `await` a propósito: son hasta 7 días × red, y Flutter está
        // esperando la respuesta del permiso — no puede colgarse por esto.
        // Los días que fallen quedan en la cola de reintentos (A8) y drenan
        // solos al volver del background.
        //
        // Y solo se dispara con acceso confirmado: con el permiso negado,
        // los 7 días saldrían vacíos, Luis respondería 200 a todos, y la
        // bandera de "backfill ya hecho" se quemaría para siempre con cero
        // datos guardados.
        Task { await self.sincronizarHistorialSiEsPrimeraVez() }

        return .concedido(visibles: visibles)
    }

    /// Qué tipos devuelven al menos una muestra en los últimos 30 días.
    ///
    /// Es la única forma de inferir el permiso de lectura: con el permiso
    /// negado HealthKit devuelve arrays vacíos, no un error. Y hay que
    /// preguntarlo por tipo porque el permiso se concede por tipo — sondear
    /// solo pasos y opinar sobre los tres fue exactamente el bug que esto
    /// arregla (un usuario que negaba ritmo cardíaco quedaba "concedido" y
    /// nunca ganaba un punto de intensidad, sin señal para nadie).
    ///
    /// Las tres consultas van en paralelo: son tipos distintos, así que no
    /// compiten entre sí como sí lo harían varias del mismo tipo.
    private func tiposVisibles() async -> Set<TipoDatoSalud> {
        async let pasos = hayMuestras(de: tipoPasos)
        async let ritmo = hayMuestras(de: tipoFrecuenciaCardiaca)
        async let entrenamientos = hayMuestras(de: tipoEntrenamiento)

        var visibles: Set<TipoDatoSalud> = []
        if await pasos { visibles.insert(.pasos) }
        if await ritmo { visibles.insert(.ritmoCardiaco) }
        if await entrenamientos { visibles.insert(.entrenamientos) }
        return visibles
    }

    /// ¿Vuelve al menos una muestra de este tipo en 30 días?
    ///
    /// A diferencia de antes, el error de la consulta ya no se traga en
    /// silencio: un fallo real de HealthKit y un "no hay nada" llevan al mismo
    /// `false`, pero el primero deja rastro en el log. Sin eso, un problema de
    /// entitlements se le presentaba al usuario como "andá a Ajustes", consejo
    /// que no lo iba a ayudar.
    private func hayMuestras(de tipo: HKSampleType) async -> Bool {
        let desde = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let predicado = HKQuery.predicateForSamples(withStart: desde, end: Date(), options: .strictStartDate)
        // Se saca el identificador ANTES del closure: es un String (Sendable),
        // mientras que el HKSampleType no lo es y el callback llega en otra cola.
        let idTipo = tipo.identifier

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: tipo,
                predicate: predicado,
                limit: 1,
                sortDescriptors: nil
            ) { _, resultados, error in
                if let error {
                    logSalud.error("Sonda de \(idTipo, privacy: .public) falló: \(error.localizedDescription, privacy: .public)")
                }
                continuation.resume(returning: !(resultados ?? []).isEmpty)
            }
            healthStore.execute(query)
        }
    }

    /// Los tipos visibles como texto estable para el log. Nunca incluye
    /// valores de salud, solo qué tipos se ven.
    private static func describir(_ visibles: Set<TipoDatoSalud>) -> String {
        guard !visibles.isEmpty else { return "ninguno" }
        return TipoDatoSalud.allCases
            .filter(visibles.contains)
            .map(\.rawValue)
            .joined(separator: ",")
    }

    // MARK: - construirPayload() (A9)
    // Arma el JSON #1 del contrato v3 para un día calendario cualquiera.
    // Comparten esta misma lógica tanto el envío real (enviarSincronizacion)
    // como el backfill (sincronizarHistorial).

    private func construirPayload(fecha: Date) async throws -> SyncPayload {
        let inicioDia = Calendar.current.startOfDay(for: fecha)
        guard let finDia = Calendar.current.date(byAdding: .day, value: 1, to: inicioDia) else {
            throw HealthKitError.rangoInvalido
        }

        async let pasosTask = fetchPasosCrudos(desde: inicioDia, hasta: finDia)
        async let sesionesTask = fetchSesiones(desde: inicioDia, hasta: finDia)
        async let frecuenciaCrudaTask = fetchFrecuenciaCardiacaCruda(desde: inicioDia, hasta: finDia)
        let (pasos, sesiones, frecuenciaCardiaca) = try await (pasosTask, sesionesTask, frecuenciaCrudaTask)

        return SyncPayload(
            usuario_id: usuarioID,
            fecha: FormatoFechas.diaCalendario.string(from: fecha),
            zona_horaria: TimeZone.current.identifier,
            pasos: pasos,
            sesiones: sesiones,
            frecuencia_cardiaca: frecuenciaCardiaca,
            sincronizado_en: FormatoFechas.iso8601.string(from: Date()),
            app_version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        )
    }

    // MARK: - clienteAPI() (A7)

    var urlBackendValida: Bool {
        guard let url = URL(string: baseURLTexto) else { return false }
        return url.scheme != nil && url.host != nil
    }

    private func clienteAPI() throws -> ApiClient {
        guard urlBackendValida, let url = URL(string: baseURLTexto) else {
            throw ApiError.urlInvalida
        }
        return ApiClient(baseURL: url)
    }

    // MARK: - enviarSincronizacion() (A7)
    // Este es el `sincronizar` real del contrato: arma el JSON #1 de un día,
    // lo manda por POST a /api/v1/sync, y guarda el JSON #2 de respuesta en
    // `respuestaEnvioHoy`. Nunca calcula ni manda puntos, edad ni FCM — eso
    // ya viene resuelto por el backend en la respuesta.

    // Devuelve un `ResultadoSincronizacion` en vez de escribir un `String` de
    // error en una propiedad: el error tipado que lanza `ApiClient` tiene que
    // sobrevivir hasta el MethodChannel, porque "sin red" y "sin permisos" son
    // situaciones distintas que el usuario resuelve distinto. Antes las dos
    // se aplastaban en el mismo mensaje.
    //
    // Devolver el resultado también elimina la carrera que había en el
    // AppDelegate, que hacía `await` y después leía `errorEnvio` — una
    // propiedad que otra llamada concurrente podía haber pisado en el medio.
    func enviarSincronizacion(fecha: Date = Date()) async -> ResultadoSincronizacion {
        enviando = true
        defer { enviando = false }

        let payload: SyncPayload
        do {
            payload = try await construirPayload(fecha: fecha)
        } catch {
            return .sinAccesoASalud(detalle: "No se pudo leer HealthKit: \(error.localizedDescription)")
        }

        let cliente: ApiClient
        do {
            cliente = try clienteAPI()
        } catch {
            return .errorPermanente(detalle: error.localizedDescription)
        }

        do {
            let respuesta = try await cliente.enviarSincronizacion(payload)
            let ahora = Date()
            respuestaEnvioHoy = respuesta
            respuestaEnvioHoyEn = ahora
            syncQueue.remover(fecha: payload.fecha)
            pendientesEnCola = syncQueue.pendientes().count
            // Si esto sí llegó, probablemente ya hay red — aprovechamos para
            // intentar vaciar lo que haya quedado pendiente de antes.
            await reintentarPendientes()
            return .ok(sincronizadoEn: ahora)
        } catch {
            if esReintentable(error) {
                syncQueue.encolar(fecha: payload.fecha)
                pendientesEnCola = syncQueue.pendientes().count
                return .encolado(detalle: error.localizedDescription)
            } else {
                // Permanente: encolarlo solo dejaría la cola atascada.
                return .errorPermanente(detalle: error.localizedDescription)
            }
        }
    }

    // MARK: - esReintentable() (A8)
    private func esReintentable(_ error: Error) -> Bool {
        guard let apiError = error as? ApiError else { return true }

        switch apiError {
        case .urlInvalida, .respuestaInvalida, .respuestaIlegible:
            return false
        case .servidor(let codigo, _):
            return codigo >= 500 || codigo == 408 || codigo == 429
        }
    }

    // MARK: - reintentarPendientes() (A8)
    // Recorre la cola persistida y reintenta cada día. Idempotente del lado
    // de Luis (external_id, L4): reintentar un payload ya guardado nunca
    // duplica una fila en el ledger.
    func reintentarPendientes() async {
        guard !reintentando else { return }

        let dias = syncQueue.pendientes()
        pendientesEnCola = dias.count
        guard !dias.isEmpty else { return }

        guard let cliente = try? clienteAPI() else {
            errorReintento = "La URL del backend no es válida."
            return
        }

        reintentando = true
        errorReintento = nil
        defer { reintentando = false }

        var fallaron = 0

        for dia in dias {
            guard let fecha = FormatoFechas.diaCalendario.date(from: dia) else {
                syncQueue.remover(fecha: dia)
                continue
            }

            do {
                // Se reconstruye el día desde HealthKit en vez de mandar una
                // foto vieja — ver razón completa en SyncQueue.swift.
                let payload = try await construirPayload(fecha: fecha)

                // Ante la duda, el día se queda pendiente: un payload vacío
                // puede ser un día sin actividad, pero también un permiso de
                // HealthKit todavía no concedido — HealthKit no permite
                // distinguirlos.
                guard !payload.pasos.isEmpty
                        || !payload.sesiones.isEmpty
                        || !payload.frecuencia_cardiaca.isEmpty else {
                    fallaron += 1
                    continue
                }

                _ = try await cliente.enviarSincronizacion(payload)
                syncQueue.remover(fecha: dia)
                pendientesEnCola = syncQueue.pendientes().count
            } catch {
                fallaron += 1

                if !esReintentable(error) {
                    syncQueue.remover(fecha: dia)
                    errorReintento = "Día \(dia): \(error.localizedDescription)"
                    break
                }
            }
        }

        pendientesEnCola = syncQueue.pendientes().count

        if fallaron > 0 && errorReintento == nil {
            errorReintento = fallaron == 1
                ? "1 día sigue sin poder enviarse."
                : "\(fallaron) días siguen sin poder enviarse."
        }
    }

    // MARK: - sincronizarHistorial() (A9)
    // Trae los últimos `dias` días (hoy incluido) y los manda uno por uno.
    // Secuencial a propósito: varias HKSampleQuery en paralelo para el mismo
    // tipo no ganan velocidad, solo compiten entre sí.

    func sincronizarHistorial(dias: Int = 7) async {
        backfillEnProgreso = true
        errorBackfill = nil
        defer { backfillEnProgreso = false }

        let hoy = Calendar.current.startOfDay(for: Date())
        let fechas = (0..<dias).compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: hoy)
        }

        guard let cliente = try? clienteAPI() else {
            errorBackfill = "La URL del backend no es válida."
            return
        }

        var encolados = 0
        huboRecorridoCompleto = true

        for fecha in fechas {
            let dia = FormatoFechas.diaCalendario.string(from: fecha)

            do {
                let payload = try await construirPayload(fecha: fecha)

                // Mismo criterio que en reintentarPendientes(): un día vacío
                // puede ser un día sin actividad, pero también un permiso
                // denegado — HealthKit no permite distinguirlos. Mandarlo haría
                // que Luis lo dé por entregado con cero datos y ese día no se
                // vuelva a mandar nunca.
                guard !payload.pasos.isEmpty
                        || !payload.sesiones.isEmpty
                        || !payload.frecuencia_cardiaca.isEmpty else { continue }

                _ = try await cliente.enviarSincronizacion(payload)
                syncQueue.remover(fecha: dia)
            } catch {
                if esReintentable(error) {
                    syncQueue.encolar(fecha: dia)
                    encolados += 1
                } else {
                    errorBackfill = "Día \(dia): \(error.localizedDescription)"
                    huboRecorridoCompleto = false
                    break
                }
            }
        }

        pendientesEnCola = syncQueue.pendientes().count

        if encolados > 0 && errorBackfill == nil {
            errorBackfill = encolados == 1
                ? "1 día no se pudo enviar — quedó en la cola de reintentos."
                : "\(encolados) días no se pudieron enviar — quedaron en la cola de reintentos."
        }
    }

    /// Dispara el backfill solo la primera vez — mientras no exista login
    /// real (L10/D6), "primera vez" se simula con una bandera local.
    func sincronizarHistorialSiEsPrimeraVez(dias: Int = 7) async {
        guard !UserDefaults.standard.bool(forKey: Self.claveBackfillInicialHecho) else { return }

        await sincronizarHistorial(dias: dias)

        guard huboRecorridoCompleto else { return }
        UserDefaults.standard.set(true, forKey: Self.claveBackfillInicialHecho)
    }

    // MARK: - Pasos crudos (una entrada por HKQuantitySample)
    // El contrato pide muestras sin agregar — nunca un total ya sumado del
    // día, eso lo calcula el backend.

    private func fetchPasosCrudos(desde inicio: Date, hasta fin: Date) async throws -> [PasoMuestra] {
        let predicado = HKQuery.predicateForSamples(withStart: inicio, end: fin, options: .strictStartDate)
        let ordenar = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        let muestras: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: tipoPasos,
                predicate: predicado,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: ordenar
            ) { _, resultados, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (resultados as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }

        return muestras.map { muestra in
            PasoMuestra(
                external_id: muestra.uuid.uuidString,
                inicio: FormatoFechas.iso8601.string(from: muestra.startDate),
                fin: FormatoFechas.iso8601.string(from: muestra.endDate),
                cantidad: Int(muestra.quantity.doubleValue(for: .count()).rounded()),
                fuente_bundle: muestra.sourceRevision.source.bundleIdentifier,
                fuente_nombre: muestra.sourceRevision.source.name,
                fuente_version: muestra.sourceRevision.version
            )
        }
    }

    // MARK: - Ritmo cardíaco: promedio, mínimo y máximo en un rango (para fc_promedio/fc_maxima de una sesión)

    private func fetchFrecuenciaCardiaca(desde inicio: Date, hasta fin: Date) async throws -> HeartRateStats {
        let predicado = HKQuery.predicateForSamples(withStart: inicio, end: fin, options: .strictStartDate)
        let unidad = HKUnit.count().unitDivided(by: .minute())

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: tipoFrecuenciaCardiaca,
                quantitySamplePredicate: predicado,
                options: [.discreteAverage, .discreteMin, .discreteMax]
            ) { _, resultado, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let stats = HeartRateStats(
                    promedio: resultado?.averageQuantity()?.doubleValue(for: unidad),
                    minimo: resultado?.minimumQuantity()?.doubleValue(for: unidad),
                    maximo: resultado?.maximumQuantity()?.doubleValue(for: unidad)
                )
                continuation.resume(returning: stats)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Frecuencia cardíaca cruda del día (una entrada por HKQuantitySample)
    // Reemplaza lo que iba a ser el ticket A4 ("detectar sesión intensa en
    // Swift"): la detección de sesiones intensas sin workout la hace el
    // backend (L7) sobre este dato crudo.

    private func fetchFrecuenciaCardiacaCruda(desde inicio: Date, hasta fin: Date) async throws -> [FrecuenciaCardiacaMuestra] {
        let predicado = HKQuery.predicateForSamples(withStart: inicio, end: fin, options: .strictStartDate)
        let ordenar = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        let unidad = HKUnit.count().unitDivided(by: .minute())

        let muestras: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: tipoFrecuenciaCardiaca,
                predicate: predicado,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: ordenar
            ) { _, resultados, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (resultados as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }

        return muestras.map { muestra in
            FrecuenciaCardiacaMuestra(
                external_id: muestra.uuid.uuidString,
                inicio: FormatoFechas.iso8601.string(from: muestra.startDate),
                fin: FormatoFechas.iso8601.string(from: muestra.endDate),
                bpm: Int(muestra.quantity.doubleValue(for: unidad).rounded()),
                fuente_bundle: muestra.sourceRevision.source.bundleIdentifier,
                fuente_nombre: muestra.sourceRevision.source.name
            )
        }
    }

    // MARK: - Sesiones (HKWorkout) de un día calendario, para el export del contrato v3

    private func fetchSesiones(desde inicio: Date, hasta fin: Date) async throws -> [SesionMuestra] {
        let predicado = HKQuery.predicateForSamples(withStart: inicio, end: fin, options: .strictStartDate)
        let ordenar = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: tipoEntrenamiento,
                predicate: predicado,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: ordenar
            ) { _, resultados, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (resultados as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        var sesiones: [SesionMuestra] = []
        for workout in workouts {
            // Si el workout no tiene FC asociada (sin reloj emparejado), no
            // hay forma honesta de llenar fc_promedio/fc_maxima como
            // "obligatorio sí" dice el contrato. Por ahora se manda 0 —
            // pendiente de confirmar con Luis cómo debe tratar el backend
            // este caso (igual que en el spike original).
            let fc = try? await fetchFrecuenciaCardiaca(desde: workout.startDate, hasta: workout.endDate)
            sesiones.append(
                SesionMuestra(
                    external_id: workout.uuid.uuidString,
                    inicio: FormatoFechas.iso8601.string(from: workout.startDate),
                    fin: FormatoFechas.iso8601.string(from: workout.endDate),
                    duracion_min: Int((workout.duration / 60).rounded()),
                    tipo_actividad: Self.identificadorActividad(for: workout.workoutActivityType),
                    fc_promedio: Int((fc?.promedio ?? 0).rounded()),
                    fc_maxima: Int((fc?.maximo ?? 0).rounded()),
                    fuente_bundle: workout.sourceRevision.source.bundleIdentifier,
                    fuente_nombre: workout.sourceRevision.source.name
                )
            )
        }
        return sesiones
    }

    /// `tipo_actividad` en texto plano para el contrato — nombres del caso de
    /// `HKWorkoutActivityType` en inglés.
    private static func identificadorActividad(for tipo: HKWorkoutActivityType) -> String {
        switch tipo {
        case .running: return "running"
        case .walking: return "walking"
        case .cycling: return "cycling"
        case .swimming: return "swimming"
        case .hiking: return "hiking"
        case .yoga: return "yoga"
        case .traditionalStrengthTraining: return "traditionalStrengthTraining"
        case .functionalStrengthTraining: return "functionalStrengthTraining"
        case .highIntensityIntervalTraining: return "highIntensityIntervalTraining"
        case .elliptical: return "elliptical"
        case .rowing: return "rowing"
        case .stairClimbing: return "stairClimbing"
        case .coreTraining: return "coreTraining"
        case .crossTraining: return "crossTraining"
        case .mixedCardio: return "mixedCardio"
        case .dance: return "dance"
        case .soccer: return "soccer"
        case .basketball: return "basketball"
        case .tennis: return "tennis"
        default: return "other_\(tipo.rawValue)"
        }
    }
}
