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
import Security

enum ApiError: LocalizedError {
    case urlInvalida
    case respuestaInvalida
    case respuestaIlegible
    case servidor(codigo: Int, cuerpo: String?)
    /// No hay token guardado: no hay a nombre de quién enviar. No se hace ni
    /// la petición. No es un error permanente: el día queda pendiente.
    case sinSesion

    var errorDescription: String? {
        switch self {
        case .sinSesion:
            return "No hay una sesión iniciada: el día queda pendiente hasta que la haya."
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
    /// a iniciar sesión), `408`, `429` y `5xx`. No: URL mal configurada,
    /// respuesta ilegible y cualquier otro `4xx` (el payload o la cuenta
    /// están mal y reintentar no lo arregla).
    ///
    /// Que `401` sea reintentable es lo que evita perder días de datos: un
    /// error permanente saca el día de la cola y corta el procesamiento de los
    /// demás.
    var esReintentable: Bool {
        switch self {
        case .urlInvalida, .respuestaInvalida, .respuestaIlegible:
            return false
        case .sinSesion:
            return true
        case .servidor(let codigo, _):
            return codigo == 401 || codigo >= 500 || codigo == 408 || codigo == 429
        }
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
            throw ApiError.servidor(codigo: http.statusCode, cuerpo: String(data: datos, encoding: .utf8))
        }

        // Un fallo de decodificación acá NO es un fallo de envío: el POST
        // devolvió 2xx, así que Luis ya guardó las muestras. Se distingue con
        // su propio error para que el día no se encole a reintentar algo que
        // ya llegó — reintentarlo fallaría igual y la cola nunca drenaría.
        do {
            return try JSONDecoder().decode(RespuestaSincronizacion.self, from: datos)
        } catch {
            throw ApiError.respuestaIlegible
        }
    }
}
