//
//  ApiClient.swift
//  Runner (+Vida — A10)
//
//  Cliente HTTP del contrato v3 (ticket A7), portado del spike
//  (+vida_fetch/Networking/ApiClient.swift). Sin dependencia de UI.
//
//  No calcula ni decide nada: manda el JSON #1 tal cual lo arma
//  HealthKitManager y devuelve el JSON #2 que responde el backend, ya
//  decodificado.
//
//  Desde el 30 sep 2026 manda el token de la sesión en cada envío
//  (`Authorization: Token <clave>`). La identidad sale del token, nunca del
//  cuerpo: ver "Autenticación (token)" en contrato-tecnico.md. El token lo
//  entrega Flutter con `actualizarSesion`; acá solo se guarda y se lee.
//

import Foundation
import os
import Security

/// Diagnóstico de los envíos al servidor. Misma regla que `logSalud`: acá
/// nunca entra un valor de salud, el token ni el cuerpo de una respuesta.
private let logSync = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.assures.masvida",
    category: "Sync"
)

enum ApiError: LocalizedError {
    case urlInvalida
    case respuestaInvalida
    case respuestaIlegible
    case servidor(codigo: Int, cuerpo: String?)
    /// No hay token guardado: no hay a nombre de quién enviar. No se hace ni
    /// la petición. No es un error permanente: el día queda pendiente.
    case sinSesion
    /// `422` con `{"error": "fuera_de_ventana"}`: el día tiene más de 14 días
    /// y el servidor ya no lo acepta (ver "Ventana de aceptación de datos
    /// rezagados" en el contrato). Es permanente, pero solo para ESE día: a
    /// diferencia de los demás errores permanentes, no dice nada malo del
    /// payload ni de la cuenta. `fecha` es la que devolvió el servidor.
    case fueraDeVentana(fecha: String?)

    /// El servidor respondió `403 {"error": "consentimiento_requerido",
    /// "version": "1"}` (bloqueo del sync, apagado por defecto): la persona no
    /// tiene el consentimiento vigente. No dice nada malo del día
    /// ni de la cuenta, y se arregla cuando acepte (como el `401` cuando
    /// vuelve a entrar), así que el día queda pendiente y NO se descarta.
    /// Cualquier otro `403` (por ejemplo, la cuenta sin perfil) sigue siendo
    /// un permanente genérico.
    case consentimientoRequerido

    var errorDescription: String? {
        switch self {
        case .sinSesion:
            return "No hay una sesión iniciada: el día queda pendiente hasta que la haya."
        case .fueraDeVentana(let fecha):
            return "El servidor ya no acepta el día \(fecha ?? "enviado"): tiene más de 14 días."
        case .consentimientoRequerido:
            return "Falta aceptar el consentimiento: el día queda pendiente hasta que se acepte."
        case .urlInvalida:
            return "La URL del backend no es válida."
        case .respuestaInvalida:
            return "El servidor respondió con un formato inesperado."
        case .respuestaIlegible:
            return "El servidor recibió los datos, pero su respuesta no coincide con el contrato v3."
        case .servidor(let codigo, let cuerpo):
            return "Error del servidor (\(codigo)): \(cuerpo ?? "sin detalle")"
        }
    }

    /// ¿Tiene sentido volver a intentar este día más tarde?
    ///
    /// Sí: sin sesión, `401` (el token falta o ya no vale; se arregla al volver
    /// a iniciar sesión), el `403` de consentimiento (se arregla al aceptarlo),
    /// `408`, `429` y `5xx`. No: URL mal configurada,
    /// respuesta ilegible, el `422` de la ventana (el día ya es demasiado
    /// viejo, y mañana lo será más) y cualquier otro `4xx` (el payload o la
    /// cuenta están mal y reintentar no lo arregla).
    ///
    /// Que `401` sea reintentable es lo que evita perder días de datos: un
    /// error permanente saca el día de la cola (ver `AccionDiaFallido`).
    var esReintentable: Bool {
        switch self {
        case .urlInvalida, .respuestaInvalida, .respuestaIlegible, .fueraDeVentana:
            return false
        case .sinSesion, .consentimientoRequerido:
            return true
        case .servidor(let codigo, _):
            return codigo == 401 || codigo >= 500 || codigo == 408 || codigo == 429
        }
    }
}

/// Qué hacer con un día cuyo envío falló. Es la ÚNICA regla: la usan el sync
/// de hoy, la cola de reintentos y ponerse al día (ver `RecorridoDias` en
/// SyncQueue.swift y HealthKitManager.swift).
enum AccionDiaFallido: Equatable {
    /// El día queda pendiente y se vuelve a intentar: sin red, sin sesión,
    /// `401`, el `403` de consentimiento, `408`, `429`, `5xx`, o HealthKit no
    /// se pudo leer.
    case reintentarDespues
    /// Se saca de la cola y la vuelta SIGUE con los demás días. Solo el `422`
    /// de la ventana: el problema es de ese día (es demasiado viejo), no del
    /// payload ni de la cuenta.
    case descartarYSeguir
    /// Se saca de la cola y la vuelta se CORTA: cualquier otro error
    /// permanente. Si el servidor rechaza el payload o la cuenta, lo más
    /// probable es que rechace igual los días siguientes; esos no se pierden,
    /// siguen en la cola para la próxima vuelta.
    case descartarYCortar
    /// No es una falla del envío: el servidor respondió 2xx (ya guardó el
    /// día) y lo único que no se entendió fue su respuesta. Se cuenta como
    /// enviado y la vuelta sigue (decidido 3 oct 2026; es lo que hacen
    /// Google, Stripe y los clientes HTTP bien hechos: un éxito no se
    /// reintenta). `ApiClient` lo deja anotado en el log.
    case tomarComoEnviado

    static func para(_ error: Error) -> AccionDiaFallido {
        // Un error que no es de `ApiError` (red caída, tiempo agotado, lectura
        // de HealthKit) se reintenta.
        guard let error = error as? ApiError else { return .reintentarDespues }
        if case .fueraDeVentana = error { return .descartarYSeguir }
        if case .respuestaIlegible = error { return .tomarComoEnviado }
        return error.esReintentable ? .reintentarDespues : .descartarYCortar
    }
}

// MARK: - Sesión (token)

/// Dónde vive, en el teléfono, el token de la sesión.
protocol AlmacenSesion {
    /// El token guardado, o `nil` si no hay sesión.
    func leerToken() -> String?
    func guardar(token: String) throws
    /// Borra el token. Borrar cuando no hay nada no es un error.
    func borrarToken() throws
}

/// Falló una operación del Keychain. Solo lleva qué se intentó y el código de
/// Apple: nunca el token.
struct ErrorAlmacenSesion: LocalizedError, Equatable {
    let operacion: String
    let estado: OSStatus

    var errorDescription: String? {
        "No se pudo \(operacion) la sesión en el Keychain (código \(estado))."
    }
}

/// El token en el Keychain propio de la app.
///
/// `AfterFirstUnlockThisDeviceOnly`: se puede leer con el teléfono bloqueado,
/// siempre que se haya desbloqueado una vez desde que se encendió (así un envío
/// en segundo plano sí puede firmar), y no viaja en copias de seguridad ni a
/// otro teléfono.
final class SesionKeychain: AlmacenSesion {
    static let servicioPorDefecto = "com.assures.masvida.sesion"
    static let cuentaPorDefecto = "token_api"

    private let servicio: String
    private let cuenta: String

    /// `servicio` y `cuenta` se pueden cambiar para aislar las pruebas.
    init(servicio: String = SesionKeychain.servicioPorDefecto,
         cuenta: String = SesionKeychain.cuentaPorDefecto) {
        self.servicio = servicio
        self.cuenta = cuenta
    }

    private var consulta: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ]
    }

    func leerToken() -> String? {
        var busqueda = consulta
        busqueda[kSecReturnData as String] = true
        busqueda[kSecMatchLimit as String] = kSecMatchLimitOne

        var resultado: CFTypeRef?
        guard SecItemCopyMatching(busqueda as CFDictionary, &resultado) == errSecSuccess,
              let datos = resultado as? Data,
              let token = String(data: datos, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }

    func guardar(token: String) throws {
        let atributos: [String: Any] = [
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        // Se actualiza si ya existe (así también se corrige la accesibilidad
        // de un ítem viejo) y se crea si no.
        var estado = SecItemUpdate(consulta as CFDictionary, atributos as CFDictionary)
        if estado == errSecItemNotFound {
            estado = SecItemAdd(consulta.merging(atributos) { _, nuevo in nuevo } as CFDictionary, nil)
        }
        guard estado == errSecSuccess else {
            throw ErrorAlmacenSesion(operacion: "guardar", estado: estado)
        }
    }

    func borrarToken() throws {
        let estado = SecItemDelete(consulta as CFDictionary)
        guard estado == errSecSuccess || estado == errSecItemNotFound else {
            throw ErrorAlmacenSesion(operacion: "borrar", estado: estado)
        }
    }
}

/// Resultado de `actualizarSesion`, tal como lo define el contrato.
enum ResultadoActualizarSesion: Equatable {
    case ok
    /// No se pudo escribir o borrar en el Keychain. `detalle` es texto
    /// técnico para logs y nunca contiene el token.
    case errorAlmacenamiento(detalle: String)
}

enum Sesion {
    /// Aplica lo que entrega Flutter: un token lo guarda; `nil` (o un texto
    /// vacío) significa "no hay sesión" y borra el que hubiera.
    static func aplicar(token: String?, en almacen: AlmacenSesion) -> ResultadoActualizarSesion {
        do {
            if let limpio = token?.trimmingCharacters(in: .whitespacesAndNewlines), !limpio.isEmpty {
                try almacen.guardar(token: limpio)
            } else {
                try almacen.borrarToken()
            }
            return .ok
        } catch {
            // No se reenvía el texto de un error desconocido: por si alguna
            // vez incluyera algo que no debe salir.
            let detalle = (error as? ErrorAlmacenSesion)?.errorDescription
                ?? "No se pudo actualizar la sesión."
            return .errorAlmacenamiento(detalle: detalle)
        }
    }

    /// Lo mismo, y además: si entró **otra persona** se olvidan hasta qué día
    /// se había mandado y la cola de reintentos, para que empiece como la
    /// primera vez (sus 7 días) y no reciba días que esperaban a nombre de la
    /// anterior. Devuelve también si quedó una sesión, para saber si ponerse
    /// al día.
    ///
    /// Desde A35 (Knox) cada login trae un token nuevo, así que "otra persona"
    /// se decide por el `usuario_id`, no por el token (como `updateUserID` del
    /// SDK de Rook): si la misma persona vuelve a entrar después de que su
    /// token venció, sigue donde iba y no pierde los días de la cola.
    /// - `nil` (cerró sesión o el token venció): solo se borra el token. La
    ///   marca y la cola esperan a ver quién entra.
    /// - Sin `usuario_id` (una versión de Flutter que no lo manda, o la primera
    ///   vez después de actualizar) se compara el token, como antes.
    static func aplicar(
        token: String?,
        usuarioId: String?,
        en almacen: AlmacenSesion,
        marca: MarcaEnvios,
        cola: SyncQueue,
        cuenta: CuentaDeEnvios
    ) -> (resultado: ResultadoActualizarSesion, haySesion: Bool) {
        let anterior = almacen.leerToken()
        let resultado = aplicar(token: token, en: almacen)
        let actual = almacen.leerToken()
        // Si falló el Keychain, el token anterior sigue ahí: no cambió nada.
        // Sin sesión no hay a quién comparar: se decide cuando alguien entre.
        guard resultado == .ok, let actual else { return (resultado, actual != nil) }

        let id = usuarioId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nuevoId = (id?.isEmpty ?? true) ? nil : id
        let otraPersona: Bool
        if let nuevoId, let dueno = cuenta.usuarioId {
            otraPersona = nuevoId != dueno
        } else {
            otraPersona = actual != anterior
        }
        if otraPersona {
            marca.olvidar()
            cola.vaciar()
        }
        if let nuevoId {
            cuenta.anotar(nuevoId)
        } else if otraPersona {
            // Los días que sigan ya no son de quien estaba anotado.
            cuenta.olvidar()
        }
        return (resultado, true)
    }
}

/// A nombre de qué cuenta (`usuario_id`) están la marca de envíos y la cola.
///
/// Sobrevive al cierre de sesión a propósito: así, al volver a entrar, se sabe
/// si es la misma persona. No es secreto (es el nombre público que genera el
/// servidor), por eso vive en `UserDefaults` y no en el Keychain.
final class CuentaDeEnvios {
    private static let clave = "vida.cuentaDeLosEnvios"

    private let almacen: UserDefaults

    init(almacen: UserDefaults = .standard) {
        self.almacen = almacen
    }

    var usuarioId: String? {
        guard let id = almacen.string(forKey: Self.clave), !id.isEmpty else { return nil }
        return id
    }

    func anotar(_ usuarioId: String) {
        almacen.set(usuarioId, forKey: Self.clave)
    }

    func olvidar() {
        almacen.removeObject(forKey: Self.clave)
    }
}

final class ApiClient {
    /// URL base del backend de Luis — ej. `http://192.168.1.23:8000` en la
    /// misma wifi, un túnel de ngrok, o más adelante la URL pública de
    /// Railway/Render. Cambia varias veces durante el desarrollo, por eso
    /// se recibe en el init en vez de quedar hardcodeada.
    let baseURL: URL

    private let session: URLSession

    /// De dónde sale el token de cada envío.
    private let almacen: AlmacenSesion

    /// Sesión compartida con timeout propio. `URLSession.shared` espera 60s
    /// por request: con el backend caído, el backfill de 7 días dejaba al
    /// usuario 7 minutos mirando un spinner sin poder cancelar. Con 20s la
    /// cola de reintentos (A8) entra en acción mucho antes.
    ///
    /// Es `static` a propósito: `clienteAPI()` crea un `ApiClient` nuevo en
    /// cada envío, y una URLSession por request desperdicia recursos.
    private static let sesionCompartida: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    init(baseURL: URL, session: URLSession? = nil, almacen: AlmacenSesion = SesionKeychain()) {
        self.baseURL = baseURL
        self.session = session ?? Self.sesionCompartida
        self.almacen = almacen
    }

    /// `POST /api/v1/sync` — manda el JSON #1 y devuelve el JSON #2 ya
    /// decodificado. Nunca manda puntos, edad ni FCM: eso ya viene resuelto
    /// dentro de `payload`, armado siempre a partir de datos crudos de
    /// HealthKit (ver el principio no negociable en contrato-v3_1.md).
    ///
    /// Sin token guardado lanza `ApiError.sinSesion` y NO hace la petición: el
    /// servidor respondería 401 de todas formas.
    func enviarSincronizacion(_ payload: SyncPayload) async throws -> RespuestaSincronizacion {
        guard let token = almacen.leerToken() else {
            throw ApiError.sinSesion
        }

        let url = baseURL.appendingPathComponent("api/v1/sync")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (datos, respuesta) = try await session.data(for: request)

        guard let http = respuesta as? HTTPURLResponse else {
            throw ApiError.respuestaInvalida
        }

        guard (200...299).contains(http.statusCode) else {
            if let rechazo = Self.rechazoPorVentana(codigo: http.statusCode, cuerpo: datos) {
                throw rechazo
            }
            if let rechazo = Self.rechazoPorConsentimiento(codigo: http.statusCode, cuerpo: datos) {
                throw rechazo
            }
            throw ApiError.servidor(codigo: http.statusCode, cuerpo: String(data: datos, encoding: .utf8))
        }

        // Un fallo de decodificación acá NO es un fallo de envío: el POST
        // devolvió 2xx, así que Luis ya guardó las muestras. Se distingue con
        // su propio error para que el día no se encole a reintentar algo que
        // ya llegó — reintentarlo fallaría igual y la cola nunca drenaría.
        do {
            return try JSONDecoder().decode(RespuestaSincronizacion.self, from: datos)
        } catch {
            // El día se da por enviado (`AccionDiaFallido.tomarComoEnviado`),
            // así que sin esta línea nadie se enteraría de que el servidor y
            // la app ya no están de acuerdo en el formato. Solo la fecha y el
            // código: el cuerpo trae datos de salud.
            logSync.error(
                "Respuesta ilegible del servidor (HTTP \(http.statusCode, privacy: .public)) para el día \(payload.fecha, privacy: .public): el día quedó guardado. Revisar que el contrato y el servidor coincidan."
            )
            throw ApiError.respuestaIlegible
        }
    }

    /// Cuerpo del `422` de la ventana: `{"error": "fuera_de_ventana", "fecha": "…"}`.
    private struct CuerpoRechazo: Decodable {
        let error: String
        let fecha: String?
    }

    /// `fueraDeVentana` solo si es un `422` Y trae ese motivo. Cualquier otro
    /// `422` (o un cuerpo que no se entiende) sigue siendo `servidor(422)`:
    /// un permanente genérico, que no se puede tratar como "solo este día".
    static func rechazoPorVentana(codigo: Int, cuerpo: Data) -> ApiError? {
        guard codigo == 422,
              let rechazo = try? JSONDecoder().decode(CuerpoRechazo.self, from: cuerpo),
              rechazo.error == "fuera_de_ventana" else { return nil }
        return .fueraDeVentana(fecha: rechazo.fecha)
    }

    /// El motivo con el que el servidor rechaza un envío porque falta el
    /// consentimiento.
    static let motivoConsentimientoRequerido = "consentimiento_requerido"

    /// `consentimientoRequerido` solo si es un `403` Y trae ese motivo. Cualquier
    /// otro `403` sigue siendo `servidor(403)`: un permanente genérico (la cuenta
    /// sin perfil, por ejemplo), que no se puede dejar pendiente.
    ///
    /// Así lo manda el servidor (`Apps/activities/views.py`):
    /// `{"error": "consentimiento_requerido", "version": "1"}`; la `version` se
    /// ignora. Si algún día la forma cambiara pero el texto trajera el motivo,
    /// también se toma: perder el día por una diferencia de forma sería lo peor
    /// de las dos equivocaciones.
    static func rechazoPorConsentimiento(codigo: Int, cuerpo: Data) -> ApiError? {
        guard codigo == 403 else { return nil }
        // Si el cuerpo es un objeto con `error` de texto, ESE valor manda, sin importar cómo
        // sean los demás campos (con `JSONDecoder` y `fecha` de otro tipo, el decodificador
        // fallaba y caía al respaldo por texto: un 403 con otro `error` que mencionara el
        // motivo en otro campo se tomaba por consentimiento). Lo encontraron las pruebas al
        // azar de A38.
        if let objeto = (try? JSONSerialization.jsonObject(with: cuerpo)) as? [String: Any],
           let error = objeto["error"] as? String {
            return error == motivoConsentimientoRequerido ? .consentimientoRequerido : nil
        }
        guard let texto = String(data: cuerpo, encoding: .utf8),
              texto.contains(motivoConsentimientoRequerido) else { return nil }
        return .consentimientoRequerido
    }
}
