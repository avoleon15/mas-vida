//
//  ApiClient.swift
//  Runner (+Vida — A10)
//
//  Cliente HTTP del contrato v3 (ticket A7), portado tal cual del spike
//  (+vida_fetch/Networking/ApiClient.swift) — sin cambios, es Foundation
//  puro sin dependencia de UI.
//
//  No calcula ni decide nada: manda el JSON #1 tal cual lo arma
//  HealthKitManager y devuelve el JSON #2 que responde el backend, ya
//  decodificado.
//

import Foundation

enum ApiError: LocalizedError {
    case urlInvalida
    case respuestaInvalida
    case respuestaIlegible
    case servidor(codigo: Int, cuerpo: String?)

    var errorDescription: String? {
        switch self {
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
}

final class ApiClient {
    /// URL base del backend de Luis — ej. `http://192.168.1.23:8000` en la
    /// misma wifi, un túnel de ngrok, o más adelante la URL pública de
    /// Railway/Render. Cambia varias veces durante el desarrollo, por eso
    /// se recibe en el init en vez de quedar hardcodeada.
    let baseURL: URL

    private let session: URLSession

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

    init(baseURL: URL, session: URLSession? = nil) {
        self.baseURL = baseURL
        self.session = session ?? Self.sesionCompartida
    }

    /// `POST /api/v1/sync` — manda el JSON #1 y devuelve el JSON #2 ya
    /// decodificado. Nunca manda puntos, edad ni FCM: eso ya viene resuelto
    /// dentro de `payload`, armado siempre a partir de datos crudos de
    /// HealthKit (ver el principio no negociable en contrato-v3_1.md).
    func enviarSincronizacion(_ payload: SyncPayload) async throws -> RespuestaSincronizacion {
        let url = baseURL.appendingPathComponent("api/v1/sync")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
