//
//  ApiClient.swift
//  +vida_fetch
//
//  Cliente HTTP del contrato v2 (ticket A7). Hace el POST real a
//  /api/v1/sync que antes exportarJSON() solo armaba y guardaba en un
//  archivo local para compartir a mano — el JSON no cambia, solo cómo
//  llega hasta Luis.
//
//  No calcula ni decide nada: manda el JSON #1 tal cual lo arma
//  HealthKitManager y devuelve el JSON #2 que responde el backend, ya
//  decodificado.
//

import Foundation

enum ApiError: LocalizedError {
    case urlInvalida
    case respuestaInvalida
    case servidor(codigo: Int, cuerpo: String?)

    var errorDescription: String? {
        switch self {
        case .urlInvalida:
            return "La URL del backend no es válida."
        case .respuestaInvalida:
            return "El servidor respondió con un formato inesperado."
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

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// `POST /api/v1/sync` — manda el JSON #1 y devuelve el JSON #2 ya
    /// decodificado. Nunca manda puntos, edad ni FCM: eso ya viene resuelto
    /// dentro de `payload`, armado siempre a partir de datos crudos de
    /// HealthKit (ver el principio no negociable en contrato-v2.md).
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

        return try JSONDecoder().decode(RespuestaSincronizacion.self, from: datos)
    }
}
