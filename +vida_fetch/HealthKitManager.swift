//
//  HealthKitManager.swift
//  +vida_fetch
//
//  Spike de lectura de HealthKit para +Vida.
//  Expone dos operaciones, alineadas a los dos únicos métodos que después
//  cruzarán el MethodChannel Swift↔Flutter: `solicitarPermisos` y `sincronizar`.
//  Todo lo demás (dashboard, niveles, retos) va por HTTP directo contra la API
//  de Luis — este spike solo prueba la lectura cruda de HealthKit.
//
//  OJO — nombres: `actualizarVistaHoy()` de acá abajo NO es el `sincronizar`
//  que define el contrato (ver contrato-v2.md). Ese método de acá es solo
//  para refrescar la pantalla de depuración con los datos de hoy. El
//  `sincronizar` real del contrato — el que arma el JSON #1, hace el POST y
//  devuelve el JSON #2 — es `enviarSincronizacion()`. Cuando A10 conecte el
//  MethodChannel, el método `sincronizar` de Flutter debe apuntar a
//  `enviarSincronizacion()`, no a `actualizarVistaHoy()`.
//
//  También incluye `exportarJSON`, que arma el JSON #1 del contrato v2
//  (ver "contrato-v2.md" y SyncPayload.swift) a partir de datos crudos de
//  HealthKit y lo guarda como archivo para compartirlo/inspeccionarlo a
//  mano — útil para depurar, pero ya no es el camino real de sincronización
//  (ver `enviarSincronizacion` / `sincronizarHistorial`, tickets A7/A9).
//

import Combine
import Foundation
import HealthKit

/// Resumen de un entrenamiento (HKWorkout) para mostrar en el demo.
struct WorkoutSummary: Identifiable {
    let id: UUID
    let tipoActividad: String
    let inicio: Date
    let fin: Date
    let duracionMinutos: Double
    let promedioFC: Double?

    init(workout: HKWorkout, promedioFC: Double? = nil) {
        self.id = UUID()
        self.tipoActividad = WorkoutSummary.nombre(for: workout.workoutActivityType)
        self.inicio = workout.startDate
        self.fin = workout.endDate
        self.duracionMinutos = workout.duration / 60
        self.promedioFC = promedioFC
    }

    private static func nombre(for tipo: HKWorkoutActivityType) -> String {
        switch tipo {
        case .running: return "Correr"
        case .walking: return "Caminar"
        case .cycling: return "Ciclismo"
        case .swimming: return "Natación"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Pesas"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .other: return "Otro"
        default: return "Actividad"
        }
    }
}

/// Estadísticas de ritmo cardíaco (bpm) para un rango de fechas.
struct HeartRateStats {
    let promedio: Double?
    let minimo: Double?
    let maximo: Double?

    static let vacio = HeartRateStats(promedio: nil, minimo: nil, maximo: nil)
}

/// Errores propios del spike, para mostrar mensajes legibles en la UI.
enum HealthKitSpikeError: LocalizedError {
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

@MainActor
final class HealthKitManager: ObservableObject {

    private let healthStore = HKHealthStore()

    /// Cola de reintentos con persistencia local (A8) para los payloads
    /// que fallaron al enviarse a Luis.
    private let syncQueue = SyncQueue()

    // MARK: - Estado publicado para la UI

    @Published var autorizado: Bool = false
    @Published var solicitandoPermisos: Bool = false
    @Published var cargando: Bool = false

    // Un error por acción, no uno compartido: si dos operaciones corren cerca
    // una de otra, el usuario tiene que poder saber sin ambigüedad cuál falló.
    @Published var errorPermisos: String?
    @Published var errorSincronizacion: String?
    @Published var errorExportacion: String?

    @Published var pasosHoy: Double = 0
    @Published var frecuenciaCardiacaHoy: HeartRateStats = .vacio
    @Published var entrenamientos: [WorkoutSummary] = []
    @Published var ultimaSincronizacion: Date?

    // MARK: - Estado publicado para la exportación del contrato v2

    /// `usuario_id` del payload. Editable desde la UI mientras no exista login
    /// real — no es el HealthKit userID, es el id interno que espera Luis.
    /// Es estado compartido: lo usan tanto `exportarJSON` como
    /// `enviarSincronizacion`/`sincronizarHistorial` — no es exclusivo de la
    /// exportación a archivo aunque viva en esa sección de la UI.
    @Published var usuarioID: String = "alvaro-001"
    @Published var exportando: Bool = false
    @Published var exportURL: URL?

    // MARK: - Estado publicado para el backfill de historial (A9)

    @Published var backfillEnProgreso: Bool = false
    @Published var errorBackfill: String?
    @Published var payloadsHistorial: [SyncPayload] = []
    @Published var respuestasHistorial: [RespuestaSincronizacion] = []

    private static let claveBackfillInicialHecho = "vida.backfillInicialHecho"

    // MARK: - Estado publicado para el envío real al backend (A7)

    /// URL base del backend de Luis. Mientras no exista una pantalla de
    /// configuración real, queda editable desde acá — va a cambiar varias
    /// veces mientras Luis pasa de correrlo local a un túnel de ngrok a la
    /// URL pública de Railway/Render.
    @Published var baseURLTexto: String = "http://localhost:8000"
    @Published var enviando: Bool = false
    @Published var errorEnvio: String?

    /// Cuántos días quedan esperando a ser reenviados (A8) — para mostrar
    /// en la UI que hay algo pendiente aunque el usuario no vea el error.
    @Published var pendientesEnCola: Int = 0

    /// Un reintento en curso (A8). Sirve para dos cosas: mostrar progreso en
    /// la UI, y evitar que dos taps seguidos lancen dos loops concurrentes
    /// sobre la misma cola — eso mandaría los mismos días dos veces.
    @Published var reintentando: Bool = false
    @Published var errorReintento: String?

    /// Respuesta del envío de HOY (`enviarSincronizacion`) — separada de
    /// `respuestasHistorial` (el backfill) a propósito. Antes había un solo
    /// `ultimaRespuesta` compartido entre las dos acciones: tocabas
    /// "Traer últimos 7 días" y pisaba silenciosamente el resultado de
    /// "Enviar hoy a Luis" sin ninguna señal de cuál era cuál. Cada acción
    /// ahora tiene su propio resultado, mostrado junto a su propio botón.
    @Published var respuestaEnvioHoy: RespuestaSincronizacion?

    // MARK: - Tipos de HealthKit que leemos (v1: pasos, ritmo cardíaco, workouts)
    // Elevación descartada, sueño fuera de alcance en v1 — ver reglas del proyecto.

    private let tipoPasos = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let tipoFrecuenciaCardiaca = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private let tipoEntrenamiento = HKObjectType.workoutType()

    private var tiposLectura: Set<HKObjectType> {
        [tipoPasos, tipoFrecuenciaCardiaca, tipoEntrenamiento]
    }

    // MARK: - solicitarPermisos()
    // Corresponde al método `solicitarPermisos` del futuro MethodChannel.
    // Nota: HealthKit nunca informa si el usuario negó el permiso de lectura,
    // solo se puede inferir consultando y viendo si vuelve algo (ver
    // actualizarVistaHoy() / enviarSincronizacion()).

    func solicitarPermisos() async {
        solicitandoPermisos = true
        errorPermisos = nil
        defer { solicitandoPermisos = false }

        guard HKHealthStore.isHealthDataAvailable() else {
            errorPermisos = HealthKitSpikeError.noDisponible.localizedDescription
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: tiposLectura)
            autorizado = true
        } catch {
            errorPermisos = "No se pudo solicitar autorización: \(error.localizedDescription)"
        }
    }

    // MARK: - actualizarVistaHoy()
    // Solo refresca la pantalla de depuración con datos de hoy: pasos, FC
    // (promedio/más bajo/más alto) y entrenamientos recientes. NO manda nada
    // a ningún lado y NO es el `sincronizar` del contrato — ver nota al
    // inicio del archivo. El cálculo de puntos, FCM y niveles NO va aquí —
    // eso lo hace siempre el servidor de Luis con datos crudos.

    func actualizarVistaHoy() async {
        cargando = true
        errorSincronizacion = nil
        defer { cargando = false }

        async let pasosTask = fetchPasosHoy()
        async let frecuenciaTask = fetchFrecuenciaCardiaca(desde: inicioDelDia(), hasta: Date())
        async let workoutsTask = fetchEntrenamientos(dias: 7)

        do {
            let (pasos, frecuencia, workouts) = try await (pasosTask, frecuenciaTask, workoutsTask)
            pasosHoy = pasos
            frecuenciaCardiacaHoy = frecuencia
            entrenamientos = workouts
            ultimaSincronizacion = Date()
        } catch {
            errorSincronizacion = "Error al sincronizar: \(error.localizedDescription)"
        }
    }

    // MARK: - construirPayload() (A9)
    // Arma el JSON #1 del contrato v2 para un día calendario cualquiera —
    // extraído de exportarJSON() para que tanto la exportación a archivo
    // como el envío real (enviarSincronizacion) y el backfill
    // (sincronizarHistorial) compartan exactamente la misma lógica.

    private func construirPayload(fecha: Date) async throws -> SyncPayload {
        let inicioDia = Calendar.current.startOfDay(for: fecha)
        guard let finDia = Calendar.current.date(byAdding: .day, value: 1, to: inicioDia) else {
            throw HealthKitSpikeError.rangoInvalido
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

    // MARK: - exportarJSON()
    // Arma el JSON #1 del contrato v2 para un día calendario completo y lo
    // guarda como archivo para compartir/inspeccionar a mano. Herramienta de
    // depuración — para el envío real usar `enviarSincronizacion`.

    func exportarJSON(fecha: Date = Date()) async {
        exportando = true
        errorExportacion = nil
        defer { exportando = false }

        do {
            let payload = try await construirPayload(fecha: fecha)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let datos = try encoder.encode(payload)

            let nombreArchivo = "vida_sync_\(payload.fecha).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombreArchivo)
            try datos.write(to: url, options: .atomic)

            exportURL = url
        } catch {
            errorExportacion = "Error al exportar JSON: \(error.localizedDescription)"
        }
    }

    // MARK: - clienteAPI() (A7)
    // `baseURLTexto` es editable desde la UI mientras no exista una pantalla
    // de configuración real — se valida acá en vez de guardar una URL
    // potencialmente inválida.

    private func clienteAPI() throws -> ApiClient {
        guard let url = URL(string: baseURLTexto), url.scheme != nil, url.host != nil else {
            throw ApiError.urlInvalida
        }
        return ApiClient(baseURL: url)
    }

    // MARK: - enviarSincronizacion() (A7)
    // Este es el `sincronizar` real del contrato: arma el JSON #1 de un día,
    // lo manda por POST a /api/v1/sync, y guarda el JSON #2 de respuesta en
    // `respuestaEnvioHoy`. Reemplaza al humano como "cartero" — antes armabas
    // el archivo con exportarJSON() y lo mandabas a mano; ahora el código lo
    // entrega directo por la red. Nunca calcula ni manda puntos, edad ni
    // FCM — eso ya viene resuelto por el backend en la respuesta.

    func enviarSincronizacion(fecha: Date = Date()) async {
        enviando = true
        errorEnvio = nil
        defer { enviando = false }

        guard let payload = try? await construirPayload(fecha: fecha) else {
            errorEnvio = "Error al armar el payload de HealthKit."
            return
        }

        do {
            let cliente = try clienteAPI()
            let respuesta = try await cliente.enviarSincronizacion(payload)
            respuestaEnvioHoy = respuesta
            ultimaSincronizacion = Date()
            syncQueue.remover(fecha: payload.fecha)
            pendientesEnCola = syncQueue.pendientes().count
            // Si esto sí llegó, probablemente ya hay red — aprovechamos para
            // intentar vaciar lo que haya quedado pendiente de antes.
            await reintentarPendientes()
        } catch ApiError.urlInvalida {
            // Error de configuración, no de red: encolarlo llenaría la cola
            // de días pendientes por un typo en la URL, no por falta de señal.
            errorEnvio = "La URL del backend no es válida — corregila antes de enviar."
        } catch {
            errorEnvio = "Error al enviar a Luis: \(error.localizedDescription) — guardado para reintentar."
            syncQueue.encolar(payload)
            pendientesEnCola = syncQueue.pendientes().count
        }
    }

    // MARK: - reintentarPendientes() (A8)
    // Recorre la cola persistida de payloads que fallaron al enviarse antes
    // y reintenta cada uno. Idempotente del lado de Luis (external_id, L4):
    // reintentar un payload ya guardado nunca duplica una fila en el ledger,
    // así que no hace falta ningún control extra de duplicados acá.
    func reintentarPendientes() async {
        guard !reintentando else { return }   // un solo loop a la vez
        guard let cliente = try? clienteAPI() else {
            errorReintento = "La URL del backend no es válida."
            return
        }

        reintentando = true
        errorReintento = nil
        defer { reintentando = false }

        var fallaron = 0
        for payload in syncQueue.pendientes() {
            do {
                _ = try await cliente.enviarSincronizacion(payload)
                syncQueue.remover(fecha: payload.fecha)
                // Se actualiza día por día, no al final del loop: el contador
                // baja en vivo mientras la cola se vacía.
                pendientesEnCola = syncQueue.pendientes().count
            } catch {
                fallaron += 1
                // Sigue en la cola tal cual — se vuelve a intentar la
                // próxima vez que se llame a este método.
            }
        }

        pendientesEnCola = syncQueue.pendientes().count
        if fallaron > 0 {
            errorReintento = "^[\(fallaron) día](inflect: true) sigue sin poder enviarse."
        }
    }

    // MARK: - sincronizarHistorial() (A9)
    // Trae los últimos `dias` días (hoy incluido), uno por uno, y los manda
    // por el mismo POST /api/v1/sync — el campo `fecha` de cada payload le
    // dice a Luis de qué día son los datos, no hace falta un endpoint
    // separado (ver contrato-v2.md, nota "ventana de sync" para Luis).
    // Secuencial a propósito: varias HKSampleQuery en paralelo para el mismo
    // tipo no ganan velocidad, solo compiten entre sí.
    //
    // Guarda su resultado en `respuestasHistorial`, no en `respuestaEnvioHoy`
    // — son dos acciones distintas y no deben pisarse el resultado.

    func sincronizarHistorial(dias: Int = 7) async {
        backfillEnProgreso = true
        errorBackfill = nil
        defer { backfillEnProgreso = false }

        let hoy = Calendar.current.startOfDay(for: Date())
        let fechas = (0..<dias).compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: hoy)
        }

        do {
            let cliente = try clienteAPI()
            var payloads: [SyncPayload] = []
            var respuestas: [RespuestaSincronizacion] = []

            for fecha in fechas {
                let payload = try await construirPayload(fecha: fecha)
                let respuesta = try await cliente.enviarSincronizacion(payload)
                payloads.append(payload)
                respuestas.append(respuesta)
            }

            payloadsHistorial = payloads
            respuestasHistorial = respuestas
        } catch {
            errorBackfill = "Error al traer historial: \(error.localizedDescription)"
        }
    }

    /// Dispara el backfill solo la primera vez — mientras no exista login
    /// real (L10/D6), "primera vez" se simula con una bandera local que se
    /// prende apenas el backfill termina sin error.
    func sincronizarHistorialSiEsPrimeraVez(dias: Int = 7) async {
        guard !UserDefaults.standard.bool(forKey: Self.claveBackfillInicialHecho) else { return }
        await sincronizarHistorial(dias: dias)
        guard errorBackfill == nil else { return }
        UserDefaults.standard.set(true, forKey: Self.claveBackfillInicialHecho)
    }

    // MARK: - Pasos (suma acumulada del día calendario, para la UI)

    private func fetchPasosHoy() async throws -> Double {
        let predicado = HKQuery.predicateForSamples(
            withStart: inicioDelDia(), end: Date(), options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: tipoPasos,
                quantitySamplePredicate: predicado,
                options: .cumulativeSum
            ) { _, resultado, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let total = resultado?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: total)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Pasos crudos (una entrada por HKQuantitySample, para el export)
    // El contrato pide muestras sin agregar — "nunca un total ya sumado del
    // día, eso lo calcula el backend".

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

    // MARK: - Ritmo cardíaco: promedio, mínimo y máximo en un rango

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
    // Nuevo en el contrato v2 — reemplaza lo que iba a ser el ticket A4
    // ("detectar sesión intensa en Swift"): ahora A4 es solo exportar este
    // HR crudo, esté o no dentro de un workout. La detección de sesiones
    // intensas sin workout la hace el backend (L7) sobre este dato.

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

    // MARK: - Entrenamientos recientes (HKWorkout), con su FC promedio — demo UI (últimos 7 días)

    private func fetchEntrenamientos(dias: Int) async throws -> [WorkoutSummary] {
        let inicio = Calendar.current.date(byAdding: .day, value: -dias, to: Date()) ?? Date()
        let predicado = HKQuery.predicateForSamples(withStart: inicio, end: Date(), options: .strictStartDate)
        let ordenar = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: tipoEntrenamiento,
                predicate: predicado,
                limit: 20,
                sortDescriptors: ordenar
            ) { _, muestras, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (muestras as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        var resumenes: [WorkoutSummary] = []
        for workout in workouts {
            let fc = try? await fetchFrecuenciaCardiaca(desde: workout.startDate, hasta: workout.endDate)
            resumenes.append(WorkoutSummary(workout: workout, promedioFC: fc?.promedio))
        }
        return resumenes
    }

    // MARK: - Sesiones (HKWorkout) de un día calendario, para el export del contrato v1

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
            // Si el workout no tiene FC asociada (sin reloj emparejado), no hay
            // forma honesta de llenar fc_promedio/fc_maxima como "obligatorio
            // sí" dice el contrato. Por ahora se manda 0 — pendiente de
            // confirmar con Luis cómo debe tratar el backend este caso.
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
    /// `HKWorkoutActivityType` en inglés, distintos de los nombres en español
    /// que usa `WorkoutSummary` solo para mostrar en pantalla.
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

    // MARK: - Helpers

    private func inicioDelDia() -> Date {
        Calendar.current.startOfDay(for: Date())
    }
}
