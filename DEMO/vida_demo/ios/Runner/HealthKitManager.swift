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

/// Hardware que generó una muestra (`HKDevice`): nombre, modelo y fabricante.
///
/// Se manda al servidor tal cual, sin decidir nada acá: el servidor deriva si
/// es teléfono, reloj o anillo (ver "Tipo de dispositivo" en el contrato).
/// `nil` cuando HealthKit no lo trae o viene vacío — el servidor nunca
/// descarta una muestra por eso; la trata como teléfono.
struct DatosDispositivo: Equatable {
    let nombre: String?
    let modelo: String?
    let fabricante: String?

    init(_ dispositivo: HKDevice?) {
        nombre = Self.limpiar(dispositivo?.name)
        modelo = Self.limpiar(dispositivo?.model)
        fabricante = Self.limpiar(dispositivo?.manufacturer)
    }

    /// Un texto vacío o de puros espacios no dice nada: se manda como nulo.
    private static func limpiar(_ texto: String?) -> String? {
        guard let recortado = texto?.trimmingCharacters(in: .whitespacesAndNewlines),
              !recortado.isEmpty else { return nil }
        return recortado
    }
}

/// Estadísticas de ritmo cardíaco (bpm) para un rango de fechas.
struct HeartRateStats {
    let promedio: Double?
    let minimo: Double?
    let maximo: Double?

    static let vacio = HeartRateStats(promedio: nil, minimo: nil, maximo: nil)
}

/// Lo que la persona escribió a mano en Salud no cuenta (decidido 1 oct 2026).
///
/// Apple marca esas lecturas con `HKMetadataKeyWasUserEntered`. Aplica a los
/// pasos, al ritmo cardíaco y a los workouts: cualquiera se puede inventar en
/// un minuto desde Salud › Explorar › Añadir datos. Sin metadata se asume que
/// NO fue a mano (un reloj de terceros suele no escribir esa marca).
///
/// Esto frena el engaño fácil, no todo: una app que escriba datos falsos por
/// programa no viene marcada. Eso HealthKit no lo puede probar.
enum ReglasManuales {
    static func esManual(metadata: [String: Any]?) -> Bool {
        (metadata?[HKMetadataKeyWasUserEntered] as? Bool) == true
    }
}

// MARK: - Lecturas de Salud copiadas a valores simples
// HealthKit solo se LEE en un lugar; todo lo que se decide va en funciones
// puras (abajo) que reciben estos valores. Así las reglas se prueban de punta
// a punta sin un iPhone, y quien las borre rompe un test.

struct EntradaPaso {
    let uuid: String
    let inicio: Date
    let fin: Date
    let cantidad: Double
    let fuenteBundle: String
    let fuenteNombre: String
    let fuenteVersion: String?
    let dispositivo: DatosDispositivo
    let metadata: [String: Any]?
}

extension EntradaPaso {
    init(_ muestra: HKQuantitySample) {
        self.init(
            uuid: muestra.uuid.uuidString,
            inicio: muestra.startDate,
            fin: muestra.endDate,
            cantidad: muestra.quantity.doubleValue(for: .count()),
            fuenteBundle: muestra.sourceRevision.source.bundleIdentifier,
            fuenteNombre: muestra.sourceRevision.source.name,
            fuenteVersion: muestra.sourceRevision.version,
            dispositivo: DatosDispositivo(muestra.device),
            metadata: muestra.metadata
        )
    }
}

struct EntradaRitmo {
    let uuid: String
    let inicio: Date
    let fin: Date
    let bpm: Double
    let fuenteBundle: String
    let fuenteNombre: String
    let dispositivo: DatosDispositivo
    let metadata: [String: Any]?
}

extension EntradaRitmo {
    init(_ muestra: HKQuantitySample) {
        self.init(
            uuid: muestra.uuid.uuidString,
            inicio: muestra.startDate,
            fin: muestra.endDate,
            bpm: muestra.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
            fuenteBundle: muestra.sourceRevision.source.bundleIdentifier,
            fuenteNombre: muestra.sourceRevision.source.name,
            dispositivo: DatosDispositivo(muestra.device),
            metadata: muestra.metadata
        )
    }
}

struct EntradaWorkout {
    let uuid: String
    let inicio: Date
    let fin: Date
    let duracionSegundos: Double
    let tipoActividad: String
    let fuenteBundle: String
    let fuenteNombre: String
    let dispositivo: DatosDispositivo
    let metadata: [String: Any]?
    /// Las lecturas de ritmo cardíaco dentro de la ventana del workout.
    let ritmo: [EntradaRitmo]
}

extension EntradaWorkout {
    init(_ workout: HKWorkout, tipoActividad: String, ritmo: [EntradaRitmo]) {
        self.init(
            uuid: workout.uuid.uuidString,
            inicio: workout.startDate,
            fin: workout.endDate,
            duracionSegundos: workout.duration,
            tipoActividad: tipoActividad,
            fuenteBundle: workout.sourceRevision.source.bundleIdentifier,
            fuenteNombre: workout.sourceRevision.source.name,
            dispositivo: DatosDispositivo(workout.device),
            metadata: workout.metadata,
            ritmo: ritmo
        )
    }
}

// MARK: - Qué se manda al backend (funciones puras)

/// Pasos y ritmo cardíaco crudos del día: lo escrito a mano no se manda.
enum ReglasMuestras {
    static func pasos(de entradas: [EntradaPaso]) -> [PasoMuestra] {
        entradas
            .filter { !ReglasManuales.esManual(metadata: $0.metadata) }
            .map { entrada in
                PasoMuestra(
                    external_id: entrada.uuid,
                    inicio: FormatoFechas.iso8601.string(from: entrada.inicio),
                    fin: FormatoFechas.iso8601.string(from: entrada.fin),
                    cantidad: Int(entrada.cantidad.rounded()),
                    fuente_bundle: entrada.fuenteBundle,
                    fuente_nombre: entrada.fuenteNombre,
                    fuente_version: entrada.fuenteVersion,
                    dispositivo_nombre: entrada.dispositivo.nombre,
                    dispositivo_modelo: entrada.dispositivo.modelo,
                    dispositivo_fabricante: entrada.dispositivo.fabricante
                )
            }
    }

    static func ritmo(de entradas: [EntradaRitmo]) -> [FrecuenciaCardiacaMuestra] {
        entradas
            .filter { !ReglasManuales.esManual(metadata: $0.metadata) }
            .map { entrada in
                FrecuenciaCardiacaMuestra(
                    external_id: entrada.uuid,
                    inicio: FormatoFechas.iso8601.string(from: entrada.inicio),
                    fin: FormatoFechas.iso8601.string(from: entrada.fin),
                    bpm: Int(entrada.bpm.rounded()),
                    fuente_bundle: entrada.fuenteBundle,
                    fuente_nombre: entrada.fuenteNombre,
                    dispositivo_nombre: entrada.dispositivo.nombre,
                    dispositivo_modelo: entrada.dispositivo.modelo,
                    dispositivo_fabricante: entrada.dispositivo.fabricante
                )
            }
    }

    /// Promedio, mínimo y máximo de las lecturas MEDIDAS. Una lectura escrita
    /// a mano dentro del workout no puede inflar el ritmo.
    static func estadisticas(de lecturas: [EntradaRitmo]) -> HeartRateStats {
        let valores = lecturas
            .filter { !ReglasManuales.esManual(metadata: $0.metadata) }
            .map(\.bpm)
        guard !valores.isEmpty else { return .vacio }
        return HeartRateStats(
            promedio: valores.reduce(0, +) / Double(valores.count),
            minimo: valores.min(),
            maximo: valores.max()
        )
    }
}

/// Qué workouts se mandan al backend (decidido 1 oct 2026; contrato, "Qué
/// cuenta como workout").
///
/// - Un workout **necesita ritmo cardíaco medido**, o sea un reloj o una banda.
///   Con solo el teléfono no se registran workouts. Antes se mandaba
///   `fc_promedio`/`fc_maxima` en `0`; ahora esa sesión simplemente no se manda.
/// - Los workouts **ingresados a mano** no cuentan, ni cuenta el ritmo cardíaco
///   escrito a mano dentro de uno.
enum ReglasWorkout {
    struct FC: Equatable {
        let promedio: Int
        let maxima: Int
    }

    /// El ritmo cardíaco que viaja con la sesión, o `nil` si no hay uno medido
    /// (en cuyo caso la sesión no se manda). Nunca devuelve ceros.
    static func fcParaEnviar(stats: HeartRateStats) -> FC? {
        guard let promedio = stats.promedio, let maximo = stats.maximo else { return nil }
        let promedioEntero = Int(promedio.rounded())
        let maximoEntero = Int(maximo.rounded())
        guard promedioEntero > 0, maximoEntero > 0 else { return nil }
        return FC(promedio: promedioEntero, maxima: maximoEntero)
    }

    /// Los workouts que se mandan, en el mismo orden en que llegaron.
    static func sesiones(de entradas: [EntradaWorkout]) -> [SesionMuestra] {
        entradas.compactMap { entrada in
            guard !ReglasManuales.esManual(metadata: entrada.metadata) else { return nil }
            guard let fc = fcParaEnviar(stats: ReglasMuestras.estadisticas(de: entrada.ritmo)) else {
                return nil
            }
            return SesionMuestra(
                external_id: entrada.uuid,
                inicio: FormatoFechas.iso8601.string(from: entrada.inicio),
                fin: FormatoFechas.iso8601.string(from: entrada.fin),
                duracion_min: Int((entrada.duracionSegundos / 60).rounded()),
                tipo_actividad: entrada.tipoActividad,
                fc_promedio: fc.promedio,
                fc_maxima: fc.maxima,
                fuente_bundle: entrada.fuenteBundle,
                fuente_nombre: entrada.fuenteNombre,
                dispositivo_nombre: entrada.dispositivo.nombre,
                dispositivo_modelo: entrada.dispositivo.modelo,
                dispositivo_fabricante: entrada.dispositivo.fabricante
            )
        }
    }

    /// HealthKit a veces reporta "no hay muestras en este rango" como el error
    /// `errorNoData` en vez de un resultado vacío. Es lo normal en un iPhone
    /// sin reloj: no es un fallo, es "sin ritmo cardíaco".
    static func esSinDatos(_ error: Error) -> Bool {
        (error as? HKError)?.code == .errorNoData
    }
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

    /// Hasta qué día llegó todo al servidor: de ahí sale qué mandar al
    /// ponerse al día (ver `ponerseAlDia()`).
    private let marcaEnvios = MarcaEnvios()
    /// A nombre de quién están la marca y la cola (ver `CuentaDeEnvios`).
    private let cuentaDeEnvios = CuentaDeEnvios()

    // MARK: - Estado

    private(set) var autorizado: Bool = false
    private(set) var errorPonerseAlDia: String?
    private(set) var errorReintento: String?

    /// Dónde vive el token de la sesión. Lo entrega Flutter con
    /// `actualizarSesion`; acá solo se lee, para mandarlo en cada envío.
    private let almacenSesion: AlmacenSesion = SesionKeychain()

    /// ¿Hay un token guardado? Sin él no se envía nada: los días quedan
    /// pendientes hasta que Flutter entregue la sesión.
    private var haySesion: Bool { almacenSesion.leerToken() != nil }

    /// URL base del backend de Luis.
    /// TODO(A10): reemplazar por configuración real antes de TestFlight —
    /// hoy apunta a la misma IP local usada para probar A7-A9
    /// (ver mock_luis_server.py). No debe llegar así a TestFlight.
    private var baseURLTexto: String = "http://192.168.1.21:8000"

    /// La bandera del backfill de antes (una sola vez por instalación). La
    /// reemplaza `MarcaEnvios`; se borra al arrancar para no dejar basura.
    private static let claveBackfillViejo = "vida.backfillInicialHecho"

    private var enviando = false
    private var reintentando = false
    private var poniendoseAlDia = false

    /// Respuesta del envío de HOY — lo que arma el resultado que vuelve por
    /// el MethodChannel a Flutter.
    private(set) var respuestaEnvioHoy: RespuestaSincronizacion?
    private(set) var respuestaEnvioHoyEn: Date?

    /// Cuántos días quedan esperando a ser reenviados (A8).
    private(set) var pendientesEnCola: Int = 0

    /// Hay una operación de red en curso. Las tres acciones (enviar hoy,
    /// reintentar, ponerse al día) pegan al mismo endpoint y tocan la misma
    /// cola — ver detalle en el spike original (misma razón, portada tal cual).
    var ocupado: Bool { enviando || reintentando || poniendoseAlDia }

    private init() {
        // Sin esto el contador arranca en 0 aunque haya días esperando en
        // disco desde una sesión anterior de la app.
        pendientesEnCola = syncQueue.pendientes().count
        UserDefaults.standard.removeObject(forKey: Self.claveBackfillViejo)
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

        // Con acceso recién confirmado, se manda lo que falte (la primera vez,
        // los últimos 7 días). Sin `await` a propósito: son varios días × red,
        // y Flutter está esperando la respuesta del permiso.
        Task { await self.ponerseAlDia() }

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
    // Comparten esta misma lógica el envío de hoy (enviarSincronizacion), la
    // cola (reintentarPendientes) y ponerse al día (ponerseAlDia).

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
        return ApiClient(baseURL: url, almacen: almacenSesion)
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

        // Sin sesión no hay a nombre de quién enviar. El día queda pendiente
        // (no se pierde) y sale cuando Flutter entregue el token. Ni siquiera
        // se lee HealthKit: no hace falta para dejarlo anotado.
        guard haySesion else {
            syncQueue.encolar(fecha: FormatoFechas.diaCalendario.string(from: fecha))
            pendientesEnCola = syncQueue.pendientes().count
            return .encolado(detalle: ApiError.sinSesion.localizedDescription)
        }

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
            marcaEnvios.registrarEnviado(payload.fecha)
            pendientesEnCola = syncQueue.pendientes().count
            // Si esto sí llegó, probablemente ya hay red — aprovechamos para
            // intentar vaciar lo que haya quedado pendiente de antes.
            await reintentarPendientes()
            return .ok(sincronizadoEn: ahora)
        } catch {
            // Misma regla que la cola y el backfill (`AccionDiaFallido`). Acá
            // hay un solo día, así que "seguir" y "cortar" dan lo mismo.
            switch AccionDiaFallido.para(error) {
            case .reintentarDespues:
                syncQueue.encolar(fecha: payload.fecha)
                pendientesEnCola = syncQueue.pendientes().count
                return .encolado(detalle: error.localizedDescription)
            case .tomarComoEnviado:
                // Llegó (2xx); solo no se entendió la respuesta. Se queda sin
                // `respuestaEnvioHoy` nueva, pero el dato está en el servidor.
                syncQueue.remover(fecha: payload.fecha)
                marcaEnvios.registrarEnviado(payload.fecha)
                pendientesEnCola = syncQueue.pendientes().count
                return .ok(sincronizadoEn: Date())
            case .descartarYSeguir, .descartarYCortar:
                // Permanente: encolarlo solo dejaría la cola atascada.
                return .errorPermanente(detalle: error.localizedDescription)
            }
        }
    }

    // MARK: - reintentarPendientes() (A8)
    // Recorre la cola persistida y reintenta cada día. Idempotente del lado
    // de Luis (external_id, L4): reintentar un payload ya guardado nunca
    // duplica una fila en el ledger.
    /// Devuelve cómo terminó: `ponerseAlDia()` no sigue si la cola se cortó
    /// por un fallo general (fallaría igual).
    @discardableResult
    func reintentarPendientes() async -> FinDeVuelta {
        guard !reintentando else { return .completa }

        let dias = syncQueue.pendientes()
        pendientesEnCola = dias.count
        guard !dias.isEmpty else { return .completa }

        // Sin sesión los días se quedan donde están: no se lee HealthKit ni se
        // toca la cola. Se intenta de nuevo cuando vuelva a primer plano.
        guard haySesion else {
            errorReintento = ApiError.sinSesion.localizedDescription
            return .cortadaPorFalloGeneral
        }

        guard let cliente = try? clienteAPI() else {
            errorReintento = "La URL del backend no es válida."
            return .cortadaPorRechazo
        }

        reintentando = true
        errorReintento = nil
        defer { reintentando = false }

        // Una fecha que no se puede leer no se va a poder mandar nunca.
        var fechas: [String: Date] = [:]
        for dia in dias {
            if let fecha = FormatoFechas.diaCalendario.date(from: dia) {
                fechas[dia] = fecha
            } else {
                syncQueue.remover(fecha: dia)
            }
        }

        var fallaron = 0
        var descartados = 0

        let fin = await RecorridoDias.recorrer(
            dias.filter { fechas[$0] != nil },
            enviar: { dia in
                guard let fecha = fechas[dia] else { return false }

                // Se reconstruye el día desde HealthKit en vez de mandar una
                // foto vieja — ver razón completa en SyncQueue.swift.
                let payload = try await self.construirPayload(fecha: fecha)

                // Ante la duda, el día se queda pendiente: un payload vacío
                // puede ser un día sin actividad, pero también un permiso de
                // HealthKit todavía no concedido — HealthKit no permite
                // distinguirlos.
                guard !payload.pasos.isEmpty
                        || !payload.sesiones.isEmpty
                        || !payload.frecuencia_cardiaca.isEmpty else { return false }

                _ = try await cliente.enviarSincronizacion(payload)
                return true
            },
            registrar: { dia, desenlace in
                // Qué pasa con el día en la cola: `DesenlaceDia.efectoEnReintento`.
                self.syncQueue.aplicar(desenlace.efectoEnReintento, a: dia)
                if desenlace.avanzaMarca {
                    self.marcaEnvios.registrarEnviado(dia)
                }
                switch desenlace {
                case .enviado:
                    break
                case .saltado, .reintentarDespues:
                    fallaron += 1
                case .descartado:
                    // Demasiado viejo: no va a entrar nunca. Los demás días
                    // de la vuelta siguen.
                    descartados += 1
                case .cortado(let error):
                    // Los días que quedaban siguen en la cola y salen en la
                    // próxima vuelta.
                    fallaron += 1
                    self.errorReintento = "Día \(dia): \(error.localizedDescription)"
                }
                self.pendientesEnCola = self.syncQueue.pendientes().count
            }
        )

        pendientesEnCola = syncQueue.pendientes().count

        if fallaron > 0 && errorReintento == nil {
            errorReintento = fallaron == 1
                ? "1 día sigue sin poder enviarse."
                : "\(fallaron) días siguen sin poder enviarse."
        }
        if descartados > 0 && errorReintento == nil {
            errorReintento = descartados == 1
                ? "1 día tenía más de 14 días y el servidor ya no lo acepta: se descartó."
                : "\(descartados) días tenían más de 14 días y el servidor ya no los acepta: se descartaron."
        }
        return fin
    }

    // MARK: - ponerseAlDia()
    // Manda "desde el último día enviado hasta hoy" (la primera vez, los
    // últimos 7 días). Reemplaza al backfill de una sola vez por instalación:
    // antes, después del primer día nadie mandaba los días nuevos.
    //
    // Se dispara al confirmar el permiso de Salud, al llegar un token
    // (`actualizarSesion`) y cada vez que la app vuelve a primer plano
    // (SceneDelegate). Secuencial a propósito: varias HKSampleQuery en
    // paralelo para el mismo tipo no ganan velocidad, solo compiten.

    func ponerseAlDia() async {
        // Flutter manda el token al abrir la app y SceneDelegate avisa que
        // volvió a primer plano casi al mismo tiempo: una sola vuelta basta.
        guard !poniendoseAlDia else { return }
        poniendoseAlDia = true
        errorPonerseAlDia = nil
        defer { poniendoseAlDia = false }

        // Primero la cola: días que fallaron antes, que pueden ser más viejos
        // que la marca. Si se cortó por un fallo general (sin red, servidor
        // caído, token rechazado, consentimiento pendiente), los días nuevos
        // fallarían igual: se intentan la próxima vez, desde la marca, que no
        // se movió.
        guard await reintentarPendientes() != .cortadaPorFalloGeneral else {
            errorPonerseAlDia = errorReintento
            return
        }

        // Sin sesión no hay a nombre de quién enviar: la marca no se mueve y
        // se intenta de nuevo cuando llegue el token.
        guard haySesion else {
            errorPonerseAlDia = ApiError.sinSesion.localizedDescription
            return
        }

        guard let cliente = try? clienteAPI() else {
            errorPonerseAlDia = "La URL del backend no es válida."
            return
        }

        let dias = marcaEnvios.diasPorMandar()
        var encolados = 0

        await RecorridoDias.recorrer(
            dias,
            enviar: { dia in
                guard let fecha = FormatoFechas.diaCalendario.date(from: dia) else { return false }

                let payload = try await self.construirPayload(fecha: fecha)

                // Mismo criterio que en reintentarPendientes(): un día vacío
                // puede ser un día sin actividad, pero también un permiso
                // denegado — HealthKit no permite distinguirlos. Mandarlo haría
                // que Luis lo dé por entregado con cero datos.
                guard !payload.pasos.isEmpty
                        || !payload.sesiones.isEmpty
                        || !payload.frecuencia_cardiaca.isEmpty else { return false }

                _ = try await cliente.enviarSincronizacion(payload)
                return true
            },
            registrar: { dia, desenlace in
                // Qué pasa con el día en la cola: `DesenlaceDia.efectoAlPonerseAlDia`.
                self.syncQueue.aplicar(desenlace.efectoAlPonerseAlDia, a: dia)
                if desenlace.avanzaMarca {
                    self.marcaEnvios.registrarEnviado(dia)
                }
                if case .reintentarDespues = desenlace {
                    encolados += 1
                }
                if case .cortado(let error) = desenlace {
                    self.errorPonerseAlDia = "Día \(dia): \(error.localizedDescription)"
                }
            }
        )

        pendientesEnCola = syncQueue.pendientes().count

        if encolados > 0 && errorPonerseAlDia == nil {
            errorPonerseAlDia = encolados == 1
                ? "1 día no se pudo enviar — quedó en la cola de reintentos."
                : "\(encolados) días no se pudieron enviar — quedaron en la cola de reintentos."
        }
    }

    // MARK: - actualizarSesion()
    // Tercer método del contrato. Flutter entrega el token (y el `usuario_id`)
    // al iniciar sesión, `nil` al cerrarla, y otra vez lo actual cada vez que
    // abre la app.
    // Nunca se escribe el token en logs.

    func actualizarSesion(token: String?, usuarioId: String?) -> ResultadoActualizarSesion {
        // Si entró otra persona, también olvida hasta qué día se había mandado
        // y la cola (ver `Sesion.aplicar(token:usuarioId:en:marca:cola:cuenta:)`).
        let (resultado, haySesion) = Sesion.aplicar(
            token: token, usuarioId: usuarioId, en: almacenSesion,
            marca: marcaEnvios, cola: syncQueue, cuenta: cuentaDeEnvios)
        pendientesEnCola = syncQueue.pendientes().count
        // Con sesión, se manda lo que falte. Sin `await`: Flutter espera esta
        // respuesta y no puede colgarse por la red.
        if resultado == .ok && haySesion {
            Task { await self.ponerseAlDia() }
        }
        return resultado
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

        // Lo escrito a mano no se manda (ver ReglasManuales).
        return ReglasMuestras.pasos(de: muestras.map { EntradaPaso($0) })
    }

    // MARK: - Ritmo cardíaco: lectura de HealthKit (sin decidir nada)
    // Un solo lector para el ritmo del día y para el de cada workout. Qué se
    // manda lo deciden ReglasMuestras / ReglasWorkout: una lectura escrita a
    // mano no cuenta, ni para el día ni para el promedio de un workout.

    private func leerRitmo(desde inicio: Date, hasta fin: Date) async throws -> [EntradaRitmo] {
        let predicado = HKQuery.predicateForSamples(withStart: inicio, end: fin, options: .strictStartDate)
        let ordenar = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        let muestras: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: tipoFrecuenciaCardiaca,
                predicate: predicado,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: ordenar
            ) { _, resultados, error in
                if let error {
                    // "Sin muestras" no es un fallo (un iPhone sin reloj); un
                    // error real sí se propaga para no perder datos en silencio.
                    if ReglasWorkout.esSinDatos(error) {
                        continuation.resume(returning: [])
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                continuation.resume(returning: (resultados as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
        return muestras.map { EntradaRitmo($0) }
    }

    // MARK: - Frecuencia cardíaca cruda del día (una entrada por HKQuantitySample)
    // Reemplaza lo que iba a ser el ticket A4 ("detectar sesión intensa en
    // Swift"): la detección de sesiones intensas sin workout la hace el
    // backend (L7) sobre este dato crudo.

    private func fetchFrecuenciaCardiacaCruda(desde inicio: Date, hasta fin: Date) async throws -> [FrecuenciaCardiacaMuestra] {
        ReglasMuestras.ritmo(de: try await leerRitmo(desde: inicio, hasta: fin))
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

        // Se lee todo y se decide después, en ReglasWorkout.sesiones: sin ritmo
        // cardíaco medido o escrito a mano, el workout no se manda. Un error
        // real de HealthKit al leer el ritmo se propaga (no se traga), para que
        // el día no se dé por enviado y no se pierda un workout en silencio.
        var entradas: [EntradaWorkout] = []
        for workout in workouts {
            let ritmo = try await leerRitmo(desde: workout.startDate, hasta: workout.endDate)
            entradas.append(EntradaWorkout(
                workout,
                tipoActividad: Self.identificadorActividad(for: workout.workoutActivityType),
                ritmo: ritmo
            ))
        }
        return ReglasWorkout.sesiones(de: entradas)
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
