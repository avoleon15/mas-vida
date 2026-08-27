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

    // MARK: - Pasos (suma acumulada del día calendario)

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

    // MARK: - Entrenamientos recientes (HKWorkout), con su FC promedio

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

    // MARK: - Helpers

    private func inicioDelDia() -> Date {
        Calendar.current.startOfDay(for: Date())
    }
}
