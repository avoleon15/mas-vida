//
//  SyncPayload.swift
//  +vida_fetch
//
//  Modelos del JSON #1 y JSON #2 del contrato v3 (iOS ↔ Backend), tal como
//  está congelado en "contrato-v3_1.md":
//
//    POST /api/v1/sync
//    → { usuario_id, fecha, zona_horaria, pasos[], sesiones[], frecuencia_cardiaca[],
//        sincronizado_en, app_version }
//    ← { fecha, puntos_pasos, puntos_intensidad, puntos_dia, tope_diario_aplicado,
//        puntos_ano, tope_anual_aplicado, nivel, pasos_totales_dia }
//
//  Novedad de v3 (3 sep 2026): se agrega `pasos_totales_dia` a la respuesta —
//  total de pasos del día ya deduplicado por fuente del lado del servidor
//  (misma lógica que L9 usa para puntos). Nunca se calcula sumando
//  `pasos[].cantidad` crudo del lado del teléfono — eso infla el número
//  cuando hay más de una fuente activa el mismo día (ver el caso real de
//  Apple Watch/iPhone + Zepp superpuestos, documentado en
//  claude/estado-ios-a7-a9.md).
//
//  Se evaluó agregar `fc_promedio_dia` en el mismo cambio y se descartó por
//  ahora — no es necesario. Los niveles de reto semanal siguen sin viajar acá
//  a propósito (ver contrato-v3_1.md, sección de retos): cambian una vez por
//  semana, no por cada sync, y viven en su propio endpoint separado.
//
//  Novedad de v2 (30 ago 2026): se agrega `frecuencia_cardiaca[]` al request,
//  con el HR crudo del día completo, esté o no dentro de un workout —
//  reemplaza lo que iba a ser el ticket A4 (detectar sesión intensa en
//  Swift); ahora A4 es solo exportar el HR crudo, y la detección de sesión
//  intensa sin workout vive en el backend (L7). El teléfono sigue sin mandar
//  ninguna conclusión ya calculada.
//
//  Las propiedades usan snake_case a propósito, en vez de camelCase +
//  CodingKeys — acá el nombre del campo ES el contrato con Luis y Daniel, y
//  cualquier typo en un CodingKeys manual rompería el payload en silencio.
//  Si el contrato cambia de forma, es un v4 (ver nota del documento), no un
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

/// Una muestra cruda de `.heartRate` (un `HKQuantitySample`), del día
/// completo — esté o no dentro de una sesión. Agregado en v2 del contrato,
/// sin cambios en v3.
struct FrecuenciaCardiacaMuestra: Codable {
    let external_id: String
    let inicio: String
    let fin: String
    let bpm: Int
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
    let frecuencia_cardiaca: [FrecuenciaCardiacaMuestra]
    let sincronizado_en: String
    let app_version: String
}

/// El JSON #2 — respuesta síncrona al mismo `POST /api/v1/sync` (ticket A7).
/// A propósito no trae nada que explique *por qué* se descartó una muestra,
/// se detectó (o no) una sesión intensa sin workout, o se aplicó un techo —
/// esa lógica es del backend y no debe ser visible para el cliente (ver
/// contrato-v3_1.md).
///
/// OJO: `nivel` acá es el nivel ANUAL (0-4, define % de cashback) — no tiene
/// nada que ver con el nivel de reto semanal (1, 2, 3... dificultad
/// progresiva), que es un concepto totalmente distinto y vive en su propio
/// endpoint (GET /api/v1/retos/estado), nunca en esta respuesta.
struct RespuestaSincronizacion: Codable {
    let fecha: String
    let puntos_pasos: Int
    let puntos_intensidad: Int
    let puntos_dia: Int
    let tope_diario_aplicado: Bool
    let puntos_ano: Int
    let tope_anual_aplicado: Bool
    let nivel: Int
    /// Nuevo en v3 — total de pasos del día, ya deduplicado por fuente en el
    /// servidor. Es el número que hay que mostrarle al usuario ("pasos de
    /// hoy") porque coincide con lo que realmente le generó puntos.
    let pasos_totales_dia: Int
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
