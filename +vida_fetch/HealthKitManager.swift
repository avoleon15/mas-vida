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
//  que define el contrato (ver contrato-v3_1.md). Ese método de acá es solo
//  para refrescar la pantalla de depuración con los datos de hoy. El
//  `sincronizar` real del contrato — el que arma el JSON #1, hace el POST y
//  devuelve el JSON #2 — es `enviarSincronizacion()`. Cuando A10 conecte el
//  MethodChannel, el método `sincronizar` de Flutter debe apuntar a
//  `enviarSincronizacion()`, no a `actualizarVistaHoy()`.
//
//  También incluye `exportarJSON`, que arma el JSON #1 del contrato v3
//  (ver "contrato-v3_1.md" y SyncPayload.swift) a partir de datos crudos de
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

    // MARK: - Estado publicado para la exportación del contrato v3

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

    /// El último backfill recorrió los días pedidos sin abortar por un error
    /// permanente. Días encolados por falta de red no cuentan como abortar:
    /// quedaron a salvo en la cola de reintentos.
    private var huboRecorridoCompleto = false

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

    /// Hay una operación de red en curso. Las tres acciones (enviar hoy,
    /// reintentar, backfill) pegan al mismo endpoint y tocan la misma cola,
    /// así que nunca deben correr en paralelo: si "enviar hoy" fallara y
    /// encolara el día justo mientras el loop de reintentos termina y llama
    /// a `remover(fecha:)` para ese mismo día, se borraría de la cola un día
    /// que acaba de fallar. Los tres botones se deshabilitan juntos.
    var ocupado: Bool { enviando || reintentando || backfillEnProgreso }

    init() {
        // Sin esto el aviso de la UI arranca en 0 aunque haya días esperando
        // en disco: cerrás la app con 3 días pendientes, la volvés a abrir, y
        // no se ve nada hasta que toques algo. Es justo el escenario para el
        // que existe la cola.
        pendientesEnCola = syncQueue.pendientes().count
    }

    /// Respuesta del envío de HOY (`enviarSincronizacion`) — separada de
    /// `respuestasHistorial` (el backfill) a propósito. Antes había un solo
    /// `ultimaRespuesta` compartido entre las dos acciones: tocabas
    /// "Traer últimos 7 días" y pisaba silenciosamente el resultado de
    /// "Enviar hoy a Luis" sin ninguna señal de cuál era cuál. Cada acción
    /// ahora tiene su propio resultado, mostrado junto a su propio botón.
    @Published var respuestaEnvioHoy: RespuestaSincronizacion?

    /// Cuándo se obtuvo `respuestaEnvioHoy`. Sin esto, un resultado viejo se
    /// queda en pantalla junto al error de un intento posterior y no hay
    /// forma de saber si esos puntos son de ahora o de hace dos intentos.
    /// No se reusa `ultimaSincronizacion` porque esa la pisa también
    /// `actualizarVistaHoy()`, que es otra acción distinta.
    @Published var respuestaEnvioHoyEn: Date?

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
    // Arma el JSON #1 del contrato v3 para un día calendario cualquiera —
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
    // Arma el JSON #1 del contrato v3 para un día calendario completo y lo
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

    /// La URL del backend es usable. Vive acá y no en la vista porque antes
    /// estaba escrita tres veces en los `.disabled` de la UI y ninguna de las
    /// tres coincidía con esta validación (la UI no miraba `scheme`), así que
    /// un botón podía verse habilitado para una URL que `clienteAPI()` iba a
    /// rechazar igual.
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
    // `respuestaEnvioHoy`. Reemplaza al humano como "cartero" — antes armabas
    // el archivo con exportarJSON() y lo mandabas a mano; ahora el código lo
    // entrega directo por la red. Nunca calcula ni manda puntos, edad ni
    // FCM — eso ya viene resuelto por el backend en la respuesta.

    func enviarSincronizacion(fecha: Date = Date()) async {
        enviando = true
        errorEnvio = nil
        defer { enviando = false }

        let payload: SyncPayload
        do {
            payload = try await construirPayload(fecha: fecha)
        } catch {
            // Se conserva el motivo real: "permiso denegado" y "rango de
            // fechas inválido" son problemas muy distintos y con un `try?`
            // los dos salían como el mismo mensaje genérico.
            errorEnvio = "No se pudo leer HealthKit: \(error.localizedDescription)"
            return
        }

        do {
            let cliente = try clienteAPI()
            let respuesta = try await cliente.enviarSincronizacion(payload)
            respuestaEnvioHoy = respuesta
            respuestaEnvioHoyEn = Date()
            ultimaSincronizacion = Date()
            // Este envío trae el día ya completo, así que si estaba en la
            // cola por un intento anterior, deja de estar pendiente.
            syncQueue.remover(fecha: payload.fecha)
            pendientesEnCola = syncQueue.pendientes().count
            // Si esto sí llegó, probablemente ya hay red — aprovechamos para
            // intentar vaciar lo que haya quedado pendiente de antes.
            await reintentarPendientes()
        } catch {
            if esReintentable(error) {
                syncQueue.encolar(fecha: payload.fecha)
                pendientesEnCola = syncQueue.pendientes().count
                errorEnvio = "No se pudo enviar: \(error.localizedDescription) — guardado para reintentar."
            } else {
                // Permanente: encolarlo solo dejaría la cola atascada.
                errorEnvio = "No se pudo enviar: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - esReintentable() (A8)
    /// ¿Este error se arregla solo con reintentar más tarde, o va a fallar
    /// siempre? Encolar un error permanente deja la cola atascada para
    /// siempre, mostrando un aviso que el usuario no puede resolver.
    ///
    /// - Errores de red (sin señal, timeout, DNS): sí, son transitorios.
    /// - 5xx / 408 / 429: el servidor está caído o saturado, sí.
    /// - Resto de 4xx: el payload o la ruta están mal — reintentar no arregla nada.
    /// - URL inválida: es configuración, no conectividad.
    /// - Respuesta ilegible: el servidor YA guardó los datos (respondió 2xx),
    ///   solo no pudimos leer su respuesta. Reencolar el día sería pedirle
    ///   que guarde algo que ya tiene.
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
    // Recorre la cola persistida de payloads que fallaron al enviarse antes
    // y reintenta cada uno. Idempotente del lado de Luis (external_id, L4):
    // reintentar un payload ya guardado nunca duplica una fila en el ledger,
    // así que no hace falta ningún control extra de duplicados acá.
    func reintentarPendientes() async {
        guard !reintentando else { return }   // un solo loop a la vez

        let dias = syncQueue.pendientes()
        pendientesEnCola = dias.count
        // Si no hay nada pendiente no validamos la URL: hacerlo pintaría un
        // error rojo de "URL inválida" en cada arranque de la app sin que
        // haya realmente nada que reintentar.
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
                syncQueue.remover(fecha: dia)   // entrada corrupta, no se puede reconstruir
                continue
            }

            do {
                // Se reconstruye el día desde HealthKit en vez de mandar una
                // foto vieja: si el día siguió acumulando pasos después del
                // fallo, esos pasos van incluidos. Con el payload congelado
                // se habrían perdido para siempre (Luis deduplica por
                // external_id y nunca los volvería a recibir).
                let payload = try await construirPayload(fecha: fecha)

                // Ante la duda, el día se queda pendiente. Un payload vacío
                // puede ser un día sin actividad, pero también un permiso de
                // HealthKit denegado — HealthKit no permite distinguirlos:
                // cuando no hay permiso devuelve arrays vacíos, no un error.
                // Mandarlo sería fatal: Luis respondería 200, el día saldría
                // de la cola dado por entregado con cero datos, y nunca se
                // volvería a mandar. Este método corre solo (al abrir la app,
                // al volver del background), así que puede ejecutarse antes
                // de que el permiso esté concedido.
                guard !payload.pasos.isEmpty
                        || !payload.sesiones.isEmpty
                        || !payload.frecuencia_cardiaca.isEmpty else {
                    fallaron += 1
                    continue
                }

                _ = try await cliente.enviarSincronizacion(payload)
                syncQueue.remover(fecha: dia)
                // Se actualiza día por día, no al final del loop: el contador
                // baja en vivo mientras la cola se vacía.
                pendientesEnCola = syncQueue.pendientes().count
            } catch {
                fallaron += 1

                if !esReintentable(error) {
                    // Permanente (4xx, o el servidor ya lo guardó y no
                    // pudimos leer su respuesta): se saca de la cola para que
                    // pueda drenar. No se pierde nada — los datos siguen en
                    // HealthKit y ese día se puede reenviar con el backfill.
                    syncQueue.remover(fecha: dia)
                    errorReintento = "Día \(dia): \(error.localizedDescription)"
                    break   // el resto de días va a fallar por lo mismo
                }
            }
        }

        pendientesEnCola = syncQueue.pendientes().count

        if fallaron > 0 && errorReintento == nil {
            // Ojo: esto es un String, no un Text — la sintaxis ^[...](inflect:)
            // solo funciona en literales de Text, acá saldría tal cual.
            errorReintento = fallaron == 1
                ? "1 día sigue sin poder enviarse."
                : "\(fallaron) días siguen sin poder enviarse."
        }
    }

    // MARK: - sincronizarHistorial() (A9)
    // Trae los últimos `dias` días (hoy incluido), uno por uno, y los manda
    // por el mismo POST /api/v1/sync — el campo `fecha` de cada payload le
    // dice a Luis de qué día son los datos, no hace falta un endpoint
    // separado (ver contrato-v3_1.md, nota "ventana de sync" para Luis).
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

        guard let cliente = try? clienteAPI() else {
            errorBackfill = "La URL del backend no es válida."
            return
        }

        // Se limpian y se van llenando día por día: antes se asignaban al
        // final del loop, así que si el día 3 fallaba, los días 1 y 2 que SÍ
        // habían llegado a Luis no aparecían en pantalla — el usuario veía un
        // error y cero días, con dos días ya guardados en la base.
        payloadsHistorial = []
        respuestasHistorial = []
        var encolados = 0
        huboRecorridoCompleto = true

        for fecha in fechas {
            let dia = FormatoFechas.diaCalendario.string(from: fecha)

            do {
                let payload = try await construirPayload(fecha: fecha)
                let respuesta = try await cliente.enviarSincronizacion(payload)
                payloadsHistorial.append(payload)
                respuestasHistorial.append(respuesta)
                syncQueue.remover(fecha: dia)
            } catch {
                // Un día que falla ya no aborta los otros seis, y no se
                // pierde: entra a la cola de reintentos igual que el envío
                // de hoy (antes el backfill era el único camino sin red de
                // seguridad, justo el que arriesga 7 días de una).
                if esReintentable(error) {
                    syncQueue.encolar(fecha: dia)
                    encolados += 1
                } else {
                    errorBackfill = "Día \(dia): \(error.localizedDescription)"
                    huboRecorridoCompleto = false
                    break   // permanente: el resto va a fallar por lo mismo
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
    /// real (L10/D6), "primera vez" se simula con una bandera local que se
    /// prende apenas el backfill termina sin error.
    func sincronizarHistorialSiEsPrimeraVez(dias: Int = 7) async {
        guard !UserDefaults.standard.bool(forKey: Self.claveBackfillInicialHecho) else { return }

        await sincronizarHistorial(dias: dias)

        // La bandera se prende si el backfill llegó a recorrer los días, aunque
        // alguno haya quedado encolado: esos días están a salvo en la cola y el
        // reintento automático se encarga. Antes bastaba un día con mala red
        // para que la bandera nunca se prendiera y el backfill de 7 días se
        // re-corriera entero en cada intento, duplicando trabajo que la cola ya
        // estaba haciendo. Solo un fallo permanente (4xx) deja el backfill sin
        // marcar, porque ahí sí no se recorrió todo.
        guard huboRecorridoCompleto else { return }
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
    // Agregado en el contrato v2, sin cambios en v3 — reemplaza lo que
    // iba a ser el ticket A4
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
