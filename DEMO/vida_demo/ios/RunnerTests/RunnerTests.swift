import Flutter
import HealthKit
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  // MARK: - DatosDispositivo: lo que se lee del HKDevice de cada muestra

  private func dispositivo(
    nombre: String?, fabricante: String?, modelo: String?
  ) -> HKDevice {
    HKDevice(
      name: nombre, manufacturer: fabricante, model: modelo,
      hardwareVersion: nil, firmwareVersion: nil, softwareVersion: nil,
      localIdentifier: nil, udiDeviceIdentifier: nil
    )
  }

  func testDispositivoDeUnAppleWatchSeLeeTalCual() {
    let datos = DatosDispositivo(dispositivo(nombre: "Apple Watch", fabricante: "Apple Inc.", modelo: "Watch6,1"))

    XCTAssertEqual(datos.nombre, "Apple Watch")
    XCTAssertEqual(datos.modelo, "Watch6,1")
    XCTAssertEqual(datos.fabricante, "Apple Inc.")
  }

  func testDispositivoDeUnIPhoneSeDistingueDelReloj() {
    // Mismo fabricante y misma app (com.apple.health): lo único que separa
    // al iPhone del reloj es el modelo.
    let telefono = DatosDispositivo(dispositivo(nombre: "iPhone", fabricante: "Apple Inc.", modelo: "iPhone14,2"))
    let reloj = DatosDispositivo(dispositivo(nombre: "Apple Watch", fabricante: "Apple Inc.", modelo: "Watch6,1"))

    XCTAssertNotEqual(telefono.modelo, reloj.modelo)
    XCTAssertEqual(telefono.fabricante, reloj.fabricante)
  }

  func testSinDispositivoTodoEsNulo() {
    let datos = DatosDispositivo(nil)

    XCTAssertNil(datos.nombre)
    XCTAssertNil(datos.modelo)
    XCTAssertNil(datos.fabricante)
  }

  func testUnDispositivoConCamposParcialesConservaLoQueTiene() {
    let datos = DatosDispositivo(dispositivo(nombre: nil, fabricante: "Whoop Inc.", modelo: nil))

    XCTAssertNil(datos.nombre)
    XCTAssertNil(datos.modelo)
    XCTAssertEqual(datos.fabricante, "Whoop Inc.")
  }

  func testTextosVaciosOSoloEspaciosSeMandanComoNulos() {
    let datos = DatosDispositivo(dispositivo(nombre: "", fabricante: "   ", modelo: "\n"))

    XCTAssertNil(datos.nombre)
    XCTAssertNil(datos.modelo)
    XCTAssertNil(datos.fabricante)
  }

  func testSeRecortanLosEspaciosDeLosBordes() {
    let datos = DatosDispositivo(dispositivo(nombre: "  Apple Watch ", fabricante: nil, modelo: " Watch6,1\n"))

    XCTAssertEqual(datos.nombre, "Apple Watch")
    XCTAssertEqual(datos.modelo, "Watch6,1")
  }

  // MARK: - Payload: los tres tipos de muestra llevan los campos nuevos

  private func json<T: Encodable>(_ valor: T) throws -> [String: Any] {
    let datos = try JSONEncoder().encode(valor)
    return try XCTUnwrap(try JSONSerialization.jsonObject(with: datos) as? [String: Any])
  }

  func testUnPasoEnviaLosTresCamposDeDispositivo() throws {
    let paso = PasoMuestra(
      external_id: "p1", inicio: "2026-09-20T08:00:00-06:00", fin: "2026-09-20T08:05:00-06:00",
      cantidad: 120, fuente_bundle: "com.apple.health", fuente_nombre: "Health", fuente_version: "17.0",
      dispositivo_nombre: "Apple Watch", dispositivo_modelo: "Watch6,1", dispositivo_fabricante: "Apple Inc."
    )

    let enviado = try json(paso)

    XCTAssertEqual(enviado["dispositivo_nombre"] as? String, "Apple Watch")
    XCTAssertEqual(enviado["dispositivo_modelo"] as? String, "Watch6,1")
    XCTAssertEqual(enviado["dispositivo_fabricante"] as? String, "Apple Inc.")
  }

  func testUnaMuestraDeRitmoCardiacoEnviaLosTresCamposDeDispositivo() throws {
    let muestra = FrecuenciaCardiacaMuestra(
      external_id: "h1", inicio: "2026-09-20T08:00:00-06:00", fin: "2026-09-20T08:00:05-06:00",
      bpm: 72, fuente_bundle: "com.apple.health", fuente_nombre: "Health",
      dispositivo_nombre: "Apple Watch", dispositivo_modelo: "Watch6,1", dispositivo_fabricante: "Apple Inc."
    )

    let enviado = try json(muestra)

    XCTAssertEqual(enviado["dispositivo_modelo"] as? String, "Watch6,1")
    XCTAssertEqual(enviado["dispositivo_nombre"] as? String, "Apple Watch")
    XCTAssertEqual(enviado["dispositivo_fabricante"] as? String, "Apple Inc.")
  }

  func testUnaSesionEnviaLosTresCamposDeDispositivo() throws {
    let sesion = SesionMuestra(
      external_id: "s1", inicio: "2026-09-20T18:00:00-06:00", fin: "2026-09-20T18:45:00-06:00",
      duracion_min: 45, tipo_actividad: "running", fc_promedio: 128, fc_maxima: 150,
      fuente_bundle: "com.apple.health", fuente_nombre: "Health",
      dispositivo_nombre: "Apple Watch", dispositivo_modelo: "Watch6,1", dispositivo_fabricante: "Apple Inc."
    )

    let enviado = try json(sesion)

    XCTAssertEqual(enviado["dispositivo_modelo"] as? String, "Watch6,1")
    XCTAssertEqual(enviado["dispositivo_nombre"] as? String, "Apple Watch")
    XCTAssertEqual(enviado["dispositivo_fabricante"] as? String, "Apple Inc.")
  }

  func testSinDispositivoLosCamposNoSeEnvian() throws {
    // Un nulo se omite en vez de mandarse como null: el backend lee estos
    // campos con .get(), así que ausente equivale a nulo.
    let paso = PasoMuestra(
      external_id: "p1", inicio: "i", fin: "f", cantidad: 10,
      fuente_bundle: "b", fuente_nombre: "n", fuente_version: nil,
      dispositivo_nombre: nil, dispositivo_modelo: nil, dispositivo_fabricante: nil
    )

    let enviado = try json(paso)

    XCTAssertNil(enviado["dispositivo_nombre"])
    XCTAssertNil(enviado["dispositivo_modelo"])
    XCTAssertNil(enviado["dispositivo_fabricante"])
    // Y lo demás sigue igual.
    XCTAssertEqual(enviado["cantidad"] as? Int, 10)
  }

  func testNoCambiaNingunCampoQueYaExistia() throws {
    let paso = PasoMuestra(
      external_id: "p1", inicio: "2026-09-20T08:00:00-06:00", fin: "2026-09-20T08:05:00-06:00",
      cantidad: 120, fuente_bundle: "com.apple.health", fuente_nombre: "Health", fuente_version: "17.0",
      dispositivo_nombre: nil, dispositivo_modelo: nil, dispositivo_fabricante: nil
    )

    let enviado = try json(paso)

    XCTAssertEqual(
      Set(enviado.keys),
      ["external_id", "inicio", "fin", "cantidad", "fuente_bundle", "fuente_nombre", "fuente_version"]
    )
  }

  // MARK: - Compatibilidad: un payload sin los campos nuevos sigue siendo válido

  func testUnPayloadSinCamposDeDispositivoSigueLeyendose() throws {
    // Los tres campos son opcionales: un JSON que no los trae (el formato
    // anterior a este cambio) se lee igual, con esos campos en nulo. La cola
    // de reintentos no guarda payloads sino fechas y reconstruye cada día
    // desde HealthKit, así que un reintento ya sale con los campos nuevos.
    let viejo = """
    {"usuario_id":"u1","fecha":"2026-09-20","zona_horaria":"America/Guatemala",
     "pasos":[{"external_id":"p1","inicio":"i","fin":"f","cantidad":10,
               "fuente_bundle":"b","fuente_nombre":"n","fuente_version":null}],
     "sesiones":[{"external_id":"s1","inicio":"i","fin":"f","duracion_min":30,
                  "tipo_actividad":"running","fc_promedio":120,"fc_maxima":150,
                  "fuente_bundle":"b","fuente_nombre":"n"}],
     "frecuencia_cardiaca":[{"external_id":"h1","inicio":"i","fin":"f","bpm":70,
                             "fuente_bundle":"b","fuente_nombre":"n"}],
     "sincronizado_en":"2026-09-20T20:00:00-06:00","app_version":"1.0"}
    """.data(using: .utf8)!

    let payload = try JSONDecoder().decode(SyncPayload.self, from: viejo)

    XCTAssertEqual(payload.pasos.count, 1)
    XCTAssertNil(payload.pasos[0].dispositivo_modelo)
    XCTAssertNil(payload.sesiones[0].dispositivo_nombre)
    XCTAssertNil(payload.frecuencia_cardiaca[0].dispositivo_fabricante)
  }

  func testUnPayloadNuevoSobreviveAIdaYVuelta() throws {
    let paso = PasoMuestra(
      external_id: "p1", inicio: "i", fin: "f", cantidad: 10,
      fuente_bundle: "b", fuente_nombre: "n", fuente_version: nil,
      dispositivo_nombre: "Apple Watch", dispositivo_modelo: "Watch6,1", dispositivo_fabricante: "Apple Inc."
    )
    let payload = SyncPayload(
      usuario_id: "u1", fecha: "2026-09-20", zona_horaria: "America/Guatemala",
      pasos: [paso], sesiones: [], frecuencia_cardiaca: [],
      sincronizado_en: "2026-09-20T20:00:00-06:00", app_version: "1.0"
    )

    let vuelta = try JSONDecoder().decode(SyncPayload.self, from: JSONEncoder().encode(payload))

    XCTAssertEqual(vuelta.pasos[0].dispositivo_modelo, "Watch6,1")
    XCTAssertEqual(vuelta.pasos[0].dispositivo_nombre, "Apple Watch")
  }

}
