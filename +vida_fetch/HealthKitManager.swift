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
//  También incluye `exportarJSON`, que arma el JSON #1 del contrato v1
//  (ver "contrato-v1-corregido.md" y SyncPayload.swift) a partir de datos
//  crudos de HealthKit, para compartirlo/inspeccionarlo manualmente mientras
//  no existe todavía el endpoint /api/v1/sync.
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

    var errorDescription: String? {
        switch self {
        case .noDisponible:
            return "HealthKit no está disponible en este dispositivo."
        }
    }
}

@MainActor
final class HealthKitManager: ObservableObject {

    private let healthStore = HKHealthStore()

    // MARK: - Estado publicado para la UI

    @Published var autorizado: Bool = false
    @Published var cargando: Bool = false
    @Published var error: String?

    @Published var pasosHoy: Double = 0
    @Published var frecuenciaCardiacaHoy: HeartRateStats = .vacio
    @Published var entrenamientos: [WorkoutSummary] = []
    @Published var ultimaSincronizacion: Date?

    // MARK: - Estado publicado para la exportación del contrato v1

    /// `usuario_id` del payload. Editable desde la UI mientras no exista login
    /// real — no es el HealthKit userID, es el id interno que espera Luis.
    @Published var usuarioID: String = "alvaro-001"
    @Published var exportando: Bool = false
    @Published var exportURL: URL?

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
    // solo se puede inferir consultando y viendo si vuelve algo (ver sincronizar()).

    func solicitarPermisos() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            error = HealthKitSpikeError.noDisponible.localizedDescription
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: tiposLectura)
            autorizado = true
            error = nil
        } catch {
            self.error = "No se pudo solicitar autorización: \(error.localizedDescription)"
        }
    }

    // MARK: - sincronizar()
    // Corresponde al método `sincronizar` del futuro MethodChannel.
    // Trae datos crudos de hoy: pasos, FC (promedio/más bajo/más alto) y
    // entrenamientos recientes. El cálculo de puntos, FCM y niveles NO va
    // aquí — eso lo hace siempre el servidor de Luis con datos crudos.

    func sincronizar() async {
        cargando = true
        error = nil
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
            self.error = "Error al sincronizar: \(error.localizedDescription)"
        }
    }

    // MARK: - exportarJSON()
    // Arma el JSON #1 del contrato v1 (ver contrato-v1-corregido.md) para un
    // día calendario completo, y lo guarda como archivo para compartir. Esto
    // es una herramienta de desarrollo/depuración: mientras no exista
    // /api/v1/sync, sirve para mandarle a Luis un payload real de ejemplo.

    func exportarJSON(fecha: Date = Date()) async {
        exportando = true
        error = nil
        defer { exportando = false }

        let inicioDia = Calendar.current.startOfDay(for: fecha)
        guard let finDia = Calendar.current.date(byAdding: .day, value: 1, to: inicioDia) else {
            self.error = "No se pudo calcular el rango del día."
            return
        }

        do {
            async let pasosTask = fetchPasosCrudos(desde: inicioDia, hasta: finDia)
            async let sesionesTask = fetchSesiones(desde: inicioDia, hasta: finDia)
            let (pasos, sesiones) = try await (pasosTask, sesionesTask)

            let payload = SyncPayload(
                usuario_id: usuarioID,
                fecha: FormatoFechas.diaCalendario.string(from: fecha),
                zona_horaria: TimeZone.current.identifier,
                pasos: pasos,
                sesiones: sesiones,
                sincronizado_en: FormatoFechas.iso8601.string(from: Date()),
                app_version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let datos = try encoder.encode(payload)

            let nombreArchivo = "vida_sync_\(payload.fecha).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombreArchivo)
            try datos.write(to: url, options: .atomic)

            exportURL = url
        } catch {
            self.error = "Error al exportar JSON: \(error.localizedDescription)"
        }
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
