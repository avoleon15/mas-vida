//
//  SyncPayload.swift
//  +vida_fetch
//
//  Modelos del JSON #1 del contrato v1 (iOS → Backend), tal como está
//  congelado en "contrato-v1-corregido.md":
//
//    POST /api/v1/sync
//    { usuario_id, fecha, zona_horaria, pasos[], sesiones[], sincronizado_en, app_version }
//
//  Las propiedades usan snake_case a propósito, en vez de camelCase +
//  CodingKeys — acá el nombre del campo ES el contrato con Luis y Daniel, y
//  cualquier typo en un CodingKeys manual rompería el payload en silencio.
//  Si el contrato cambia de forma, es un v2 (ver nota del documento), no un
//  parche acá.
//

import Foundation

/// Una muestra cruda de `.stepCount` (un `HKQuantitySample`), sin agregar.
/// El backend nunca recibe un total ya sumado del día — eso lo calcula Luis.
struct PasoMuestra: Codable {
    let external_id: String
    let inicio: String
    let fin: String
    let cantidad: Int
    let fuente_bundle: String
    let fuente_nombre: String
    let fuente_version: String?
}

/// Una sesión de actividad (un `HKWorkout`).
struct SesionMuestra: Codable {
    let external_id: String
    let inicio: String
    let fin: String
    let duracion_min: Int
    let tipo_actividad: String
    let fc_promedio: Int
    let fc_maxima: Int
    let fuente_bundle: String
    let fuente_nombre: String
}

/// El payload completo de un día calendario, listo para `POST /api/v1/sync`.
struct SyncPayload: Codable {
    let usuario_id: String
    let fecha: String
    let zona_horaria: String
    let pasos: [PasoMuestra]
    let sesiones: [SesionMuestra]
    let sincronizado_en: String
    let app_version: String
}

/// Formateadores de fecha compartidos, para que `fecha` y los timestamps
/// ISO 8601 del payload salgan siempre con el mismo formato
/// (`2026-08-23T11:15:40-06:00`, con el offset local, no "Z" de UTC).
enum FormatoFechas {
    /// Timestamps completos: inicio/fin de muestras, `sincronizado_en`.
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Día calendario en la zona horaria del usuario (campo `fecha`), no en UTC.
    static let diaCalendario: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
}
