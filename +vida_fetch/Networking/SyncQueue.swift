//
//  SyncQueue.swift
//  +vida_fetch
//
//  Cola de reintentos con persistencia local (ticket A8). Cuando
//  `enviarSincronizacion()` falla (sin red, timeout, servidor caído), el
//  payload de ese día se guarda acá en vez de perderse. Se persiste en
//  UserDefaults — alcanza para el piloto, que maneja como mucho unos pocos
//  días pendientes por usuario a la vez.
//
//  No hace falta lógica propia de deduplicación: el `external_id` de cada
//  muestra ya es idempotente del lado de Luis (constraint único, L4), así
//  que reintentar un payload ya guardado nunca duplica una fila en el
//  ledger aunque se reintente más de una vez.
//

import Foundation

final class SyncQueue {
    private static let clave = "vida.syncPendientes"

    /// Encola un payload que falló al enviarse. Si ya había uno pendiente
    /// para el mismo día (`fecha`), lo reemplaza — no tiene sentido guardar
    /// dos versiones del mismo día, la más nueva ya incluye todo.
    func encolar(_ payload: SyncPayload) {
        var actuales = pendientes()
        actuales.removeAll { $0.fecha == payload.fecha }
        actuales.append(payload)
        guardar(actuales)
    }

    /// Los payloads que siguen esperando a ser reenviados, en el orden en
    /// que se encolaron.
    func pendientes() -> [SyncPayload] {
        guard let datos = UserDefaults.standard.data(forKey: Self.clave) else { return [] }
        return (try? JSONDecoder().decode([SyncPayload].self, from: datos)) ?? []
    }

    /// Saca de la cola el payload de `fecha` — se llama después de que un
    /// reintento sí llegó a Luis con éxito (200).
    func remover(fecha: String) {
        guardar(pendientes().filter { $0.fecha != fecha })
    }

    private func guardar(_ payloads: [SyncPayload]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(payloads), forKey: Self.clave)
    }
}
