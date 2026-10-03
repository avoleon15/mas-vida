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
      fecha: "2026-09-20", zona_horaria: "America/Guatemala",
      pasos: [paso], sesiones: [], frecuencia_cardiaca: [],
      sincronizado_en: "2026-09-20T20:00:00-06:00", app_version: "1.0"
    )

    let vuelta = try JSONDecoder().decode(SyncPayload.self, from: JSONEncoder().encode(payload))

    XCTAssertEqual(vuelta.pasos[0].dispositivo_modelo, "Watch6,1")
    XCTAssertEqual(vuelta.pasos[0].dispositivo_nombre, "Apple Watch")
  }

}


// MARK: - Sesión y token (A24)

/// Almacén en memoria: prueba la lógica sin tocar el Keychain.
final class AlmacenEnMemoria: AlmacenSesion {
  var token: String?
  var falla: ErrorAlmacenSesion?

  func leerToken() -> String? { token }

  func guardar(token: String) throws {
    if let falla { throw falla }
    self.token = token
  }

  func borrarToken() throws {
    if let falla { throw falla }
    token = nil
  }
}

/// Intercepta las peticiones de URLSession para verlas sin red.
final class ProtocoloEspia: URLProtocol {
  static var peticiones: [URLRequest] = []
  static var cuerpos: [Data] = []
  static var status = 200
  static var respuesta = Data()

  static func reiniciar() {
    peticiones = []
    cuerpos = []
    status = 200
    respuesta = Data()
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.peticiones.append(request)
    Self.cuerpos.append(Self.leerCuerpo(request))
    let http = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Self.respuesta)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}

  /// URLProtocol convierte `httpBody` en un flujo: hay que leerlo.
  private static func leerCuerpo(_ request: URLRequest) -> Data {
    if let datos = request.httpBody { return datos }
    guard let flujo = request.httpBodyStream else { return Data() }
    flujo.open()
    defer { flujo.close() }
    var datos = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while flujo.hasBytesAvailable {
      let leidos = flujo.read(&buffer, maxLength: buffer.count)
      if leidos <= 0 { break }
      datos.append(buffer, count: leidos)
    }
    return datos
  }
}

private let respuestaValida = """
{"fecha":"2026-09-28","puntos_pasos":25,"puntos_intensidad":0,"puntos_dia":25,
 "tope_diario_aplicado":false,"puntos_ano":0,"tope_anual_aplicado":false,
 "nivel":0,"pasos_totales_dia":8000}
""".data(using: .utf8)!

private func payloadDePrueba() -> SyncPayload {
  SyncPayload(
    fecha: "2026-09-28", zona_horaria: "America/Guatemala",
    pasos: [], sesiones: [], frecuencia_cardiaca: [],
    sincronizado_en: "2026-09-28T20:00:00-06:00", app_version: "1.0.0"
  )
}

/// `ApiClient` manda el token, y no hace la petición si no lo tiene.
final class ApiClientSesionTests: XCTestCase {

  private var almacen: AlmacenEnMemoria!
  private var cliente: ApiClient!

  override func setUp() {
    super.setUp()
    ProtocoloEspia.reiniciar()
    ProtocoloEspia.respuesta = respuestaValida
    almacen = AlmacenEnMemoria()
    let configuracion = URLSessionConfiguration.ephemeral
    configuracion.protocolClasses = [ProtocoloEspia.self]
    cliente = ApiClient(
      baseURL: URL(string: "http://servidor.prueba")!,
      session: URLSession(configuration: configuracion),
      almacen: almacen
    )
  }

  func testManda_ElTokenEnElEncabezadoAuthorization() async throws {
    almacen.token = "abc123"

    _ = try await cliente.enviarSincronizacion(payloadDePrueba())

    XCTAssertEqual(ProtocoloEspia.peticiones.count, 1)
    XCTAssertEqual(ProtocoloEspia.peticiones[0].value(forHTTPHeaderField: "Authorization"), "Token abc123")
  }

  func testUsaLaPalabraToken_NoBearer() async throws {
    almacen.token = "abc123"

    _ = try await cliente.enviarSincronizacion(payloadDePrueba())

    let encabezado = try XCTUnwrap(ProtocoloEspia.peticiones[0].value(forHTTPHeaderField: "Authorization"))
    XCTAssertTrue(encabezado.hasPrefix("Token "))
    XCTAssertFalse(encabezado.contains("Bearer"))
  }

  func testSinToken_NoHaceLaPeticion() async {
    almacen.token = nil

    do {
      _ = try await cliente.enviarSincronizacion(payloadDePrueba())
      XCTFail("Debió lanzar sinSesion")
    } catch {
      guard case ApiError.sinSesion = error else { return XCTFail("Error inesperado: \(error)") }
    }

    XCTAssertEqual(ProtocoloEspia.peticiones.count, 0, "Sin sesión no debe salir ninguna petición")
  }

  func testLaPeticionNoLlevaUsuarioId() async throws {
    almacen.token = "abc123"

    _ = try await cliente.enviarSincronizacion(payloadDePrueba())

    let cuerpo = String(data: ProtocoloEspia.cuerpos[0], encoding: .utf8) ?? ""
    XCTAssertFalse(cuerpo.contains("usuario_id"), "La identidad sale del token, no del cuerpo")
    XCTAssertTrue(cuerpo.contains("\"fecha\""), "El resto del payload sigue saliendo")
  }

  func testCadaEnvioLeeElTokenActual() async throws {
    almacen.token = "primero"
    _ = try await cliente.enviarSincronizacion(payloadDePrueba())

    almacen.token = "segundo"
    _ = try await cliente.enviarSincronizacion(payloadDePrueba())

    XCTAssertEqual(ProtocoloEspia.peticiones.map { $0.value(forHTTPHeaderField: "Authorization") },
                   ["Token primero", "Token segundo"])
  }

  func testDespuesDeBorrarLaSesion_YaNoEnvia() async throws {
    almacen.token = "abc123"
    _ = try await cliente.enviarSincronizacion(payloadDePrueba())

    almacen.token = nil
    do {
      _ = try await cliente.enviarSincronizacion(payloadDePrueba())
      XCTFail("Debió lanzar sinSesion")
    } catch {
      guard case ApiError.sinSesion = error else { return XCTFail("Error inesperado: \(error)") }
    }

    XCTAssertEqual(ProtocoloEspia.peticiones.count, 1)
  }

  func testUn401SeLanzaComoErrorDelServidor_YEsReintentable() async {
    almacen.token = "abc123"
    ProtocoloEspia.status = 401
    ProtocoloEspia.respuesta = Data(#"{"detail":"Invalid token."}"#.utf8)

    do {
      _ = try await cliente.enviarSincronizacion(payloadDePrueba())
      XCTFail("Debió lanzar")
    } catch let error as ApiError {
      guard case .servidor(let codigo, _) = error else { return XCTFail("Error inesperado: \(error)") }
      XCTAssertEqual(codigo, 401)
      XCTAssertTrue(error.esReintentable, "Un 401 no debe sacar el día de la cola")
    } catch {
      XCTFail("Error inesperado: \(error)")
    }
  }

  func testElTokenNoApareceEnElMensajeDeError() async {
    almacen.token = "abc123-secreto"
    ProtocoloEspia.status = 401
    ProtocoloEspia.respuesta = Data(#"{"detail":"Invalid token."}"#.utf8)

    do {
      _ = try await cliente.enviarSincronizacion(payloadDePrueba())
      XCTFail("Debió lanzar")
    } catch {
      XCTAssertFalse(error.localizedDescription.contains("abc123-secreto"))
    }
  }

  func testUn200ConLaRespuestaDelContratoSeDecodifica() async throws {
    almacen.token = "abc123"

    let respuesta = try await cliente.enviarSincronizacion(payloadDePrueba())

    XCTAssertEqual(respuesta.pasos_totales_dia, 8000)
    XCTAssertEqual(respuesta.puntos_dia, 25)
  }
}

/// Qué errores justifican volver a intentar un día más tarde.
final class ApiErrorReintentableTests: XCTestCase {

  private func servidor(_ codigo: Int) -> ApiError { .servidor(codigo: codigo, cuerpo: nil) }

  func testSeReintentan_SinSesion_401_408_429_Y5xx() {
    XCTAssertTrue(ApiError.sinSesion.esReintentable)
    for codigo in [401, 408, 429, 500, 502, 503, 504] {
      XCTAssertTrue(servidor(codigo).esReintentable, "\(codigo) debe reintentarse")
    }
  }

  func testNoSeReintentan_OtrosErroresDelCliente() {
    for codigo in [400, 403, 404, 405, 409, 422] {
      XCTAssertFalse(servidor(codigo).esReintentable, "\(codigo) es permanente")
    }
  }

  func testNoSeReintentan_ConfiguracionYRespuestaIlegible() {
    XCTAssertFalse(ApiError.urlInvalida.esReintentable)
    XCTAssertFalse(ApiError.respuestaInvalida.esReintentable)
    XCTAssertFalse(ApiError.respuestaIlegible.esReintentable)
  }

  func testUn401_AunqueSeaDeLaFamilia4xx_NoEsPermanente() {
    // Es la regla nueva: antes cualquier 4xx (salvo 408 y 429) era permanente
    // y sacaba el día de la cola.
    XCTAssertTrue(servidor(401).esReintentable)
    XCTAssertFalse(servidor(403).esReintentable)
  }
}

/// El `422` de la ventana de 14 días se distingue de cualquier otro rechazo:
/// solo con ESE motivo se puede descartar el día y seguir con los demás.
final class ApiClientVentanaTests: XCTestCase {

  private var cliente: ApiClient!

  override func setUp() {
    super.setUp()
    ProtocoloEspia.reiniciar()
    let almacen = AlmacenEnMemoria()
    almacen.token = "abc123-secreto"
    let configuracion = URLSessionConfiguration.ephemeral
    configuracion.protocolClasses = [ProtocoloEspia.self]
    cliente = ApiClient(
      baseURL: URL(string: "http://servidor.prueba")!,
      session: URLSession(configuration: configuracion),
      almacen: almacen
    )
  }

  /// Responde `status` con `cuerpo` y devuelve el error que lanzó el envío.
  private func errorAl(responder status: Int, _ cuerpo: String) async -> Error? {
    ProtocoloEspia.status = status
    ProtocoloEspia.respuesta = Data(cuerpo.utf8)
    do {
      _ = try await cliente.enviarSincronizacion(payloadDePrueba())
      return nil
    } catch {
      return error
    }
  }

  func testEl422DeLaVentanaSeReconoce_ConSuFecha() async {
    // Tal cual lo arma Apps/activities/views.py.
    let error = await errorAl(responder: 422, #"{"error":"fuera_de_ventana","fecha":"2026-09-01"}"#)

    guard case .fueraDeVentana(let fecha)? = error as? ApiError else {
      return XCTFail("Debió ser fueraDeVentana, fue: \(String(describing: error))")
    }
    XCTAssertEqual(fecha, "2026-09-01")
  }

  func testEl422DeLaVentanaNoSeReintenta() async {
    let error = await errorAl(responder: 422, #"{"error":"fuera_de_ventana","fecha":"2026-09-01"}"#)

    XCTAssertEqual((error as? ApiError)?.esReintentable, false,
                   "Un día fuera de la ventana mañana estará más fuera: reintentarlo es inútil")
  }

  func testSinFechaEnElCuerpo_IgualSeReconoce() async {
    let error = await errorAl(responder: 422, #"{"error":"fuera_de_ventana"}"#)

    guard case .fueraDeVentana(let fecha)? = error as? ApiError else {
      return XCTFail("Debió ser fueraDeVentana, fue: \(String(describing: error))")
    }
    XCTAssertNil(fecha)
    XCTAssertFalse((error?.localizedDescription ?? "").isEmpty)
  }

  func testOtro422_SigueSiendoUnErrorDelServidor() async {
    for cuerpo in [
      #"{"error":"otra_cosa","fecha":"2026-09-01"}"#,   // otro motivo
      #"{"fecha":["Formato inválido."]}"#,               // error de validación
      #"<html>Unprocessable</html>"#,                    // no es JSON
      "",                                                // sin cuerpo
    ] {
      let error = await errorAl(responder: 422, cuerpo)

      guard case .servidor(let codigo, _)? = error as? ApiError else {
        return XCTFail("Con cuerpo \(cuerpo) debió ser servidor(422), fue: \(String(describing: error))")
      }
      XCTAssertEqual(codigo, 422)
    }
  }

  func testElMismoCuerpoConOtroCodigo_NoEsDeVentana() async {
    for status in [400, 403, 500] {
      let error = await errorAl(responder: status, #"{"error":"fuera_de_ventana","fecha":"2026-09-01"}"#)

      guard case .servidor(let codigo, _)? = error as? ApiError else {
        return XCTFail("Con \(status) debió ser servidor, fue: \(String(describing: error))")
      }
      XCTAssertEqual(codigo, status)
    }
  }

  func testElMensajeDiceElDia_YNoTraeElToken() async {
    let error = await errorAl(responder: 422, #"{"error":"fuera_de_ventana","fecha":"2026-09-01"}"#)

    let mensaje = error?.localizedDescription ?? ""
    XCTAssertTrue(mensaje.contains("2026-09-01"))
    XCTAssertFalse(mensaje.contains("abc123-secreto"))
  }
}

/// La única regla para un día que falló: reintentar, descartar y seguir, o
/// descartar y cortar.
final class AccionDiaFallidoTests: XCTestCase {

  private func servidor(_ codigo: Int) -> ApiError { .servidor(codigo: codigo, cuerpo: nil) }

  func testSinRedOHealthKit_SeReintenta() {
    XCTAssertEqual(AccionDiaFallido.para(URLError(.notConnectedToInternet)), .reintentarDespues)
    XCTAssertEqual(AccionDiaFallido.para(URLError(.timedOut)), .reintentarDespues)
    XCTAssertEqual(AccionDiaFallido.para(NSError(domain: "com.apple.healthkit", code: 6)), .reintentarDespues)
  }

  func testSinSesion401_408_429Y5xx_SeReintentan() {
    XCTAssertEqual(AccionDiaFallido.para(ApiError.sinSesion), .reintentarDespues)
    for codigo in [401, 408, 429, 500, 503] {
      XCTAssertEqual(AccionDiaFallido.para(servidor(codigo)), .reintentarDespues, "\(codigo)")
    }
  }

  func testEl422DeLaVentana_SeDescartaYSigue() {
    XCTAssertEqual(AccionDiaFallido.para(ApiError.fueraDeVentana(fecha: "2026-09-01")), .descartarYSeguir)
    XCTAssertEqual(AccionDiaFallido.para(ApiError.fueraDeVentana(fecha: nil)), .descartarYSeguir)
  }

  func testOtrosPermanentes_SeDescartanYCortan() {
    for codigo in [400, 403, 404, 422] {
      XCTAssertEqual(AccionDiaFallido.para(servidor(codigo)), .descartarYCortar, "\(codigo)")
    }
    XCTAssertEqual(AccionDiaFallido.para(ApiError.urlInvalida), .descartarYCortar)
    XCTAssertEqual(AccionDiaFallido.para(ApiError.respuestaInvalida), .descartarYCortar)
    XCTAssertEqual(AccionDiaFallido.para(ApiError.respuestaIlegible), .descartarYCortar)
  }
}

/// La vuelta día por día de la cola y el backfill: cuándo sigue y cuándo corta.
@MainActor
final class RecorridoDiasTests: XCTestCase {

  /// Un desenlace sin el error adentro, para poder comparar.
  private enum Visto: Equatable { case enviado, saltado, reintentar, descartado, cortado }

  private struct Falla: Error {}

  /// Corre la vuelta con `respuestas[dia]` (nil = se envía bien) y devuelve
  /// qué días se intentaron y qué se registró de cada uno.
  private func recorrer(
    _ dias: [String],
    _ respuestas: [String: Result<Bool, Error>]
  ) async -> (intentados: [String], registrados: [String], vistos: [Visto]) {
    var intentados: [String] = []
    var registrados: [String] = []
    var vistos: [Visto] = []
    await RecorridoDias.recorrer(
      dias,
      enviar: { dia in
        intentados.append(dia)
        return try (respuestas[dia] ?? .success(true)).get()
      },
      registrar: { dia, desenlace in
        registrados.append(dia)
        switch desenlace {
        case .enviado: vistos.append(.enviado)
        case .saltado: vistos.append(.saltado)
        case .reintentarDespues: vistos.append(.reintentar)
        case .descartado: vistos.append(.descartado)
        case .cortado: vistos.append(.cortado)
        }
      }
    )
    return (intentados, registrados, vistos)
  }

  private let ventana = ApiError.fueraDeVentana(fecha: "2026-09-01")
  private let invalido = ApiError.servidor(codigo: 400, cuerpo: nil)

  func testTodoBien_SeEnvianTodosEnOrden() async {
    let r = await recorrer(["d1", "d2", "d3"], [:])

    XCTAssertEqual(r.intentados, ["d1", "d2", "d3"])
    XCTAssertEqual(r.vistos, [.enviado, .enviado, .enviado])
  }

  func testUn422EnMedio_SeDescartaYLosDemasSiguen() async {
    let r = await recorrer(["d1", "d2", "d3"], ["d2": .failure(ventana)])

    XCTAssertEqual(r.intentados, ["d1", "d2", "d3"], "El 422 no debe cortar la vuelta")
    XCTAssertEqual(r.vistos, [.enviado, .descartado, .enviado])
  }

  func testVarios422Seguidos_NingunoCorta() async {
    let r = await recorrer(["d1", "d2", "d3"], ["d1": .failure(ventana), "d2": .failure(ventana)])

    XCTAssertEqual(r.vistos, [.descartado, .descartado, .enviado])
  }

  func testUnPermanenteEnMedio_CortaYNoTocaLosDemas() async {
    let r = await recorrer(["d1", "d2", "d3", "d4"], ["d2": .failure(invalido)])

    XCTAssertEqual(r.intentados, ["d1", "d2"], "Después de cortar no se intenta ningún día más")
    XCTAssertEqual(r.registrados, ["d1", "d2"], "Ni se registra nada de los que no se intentaron")
    XCTAssertEqual(r.vistos, [.enviado, .cortado])
  }

  func testSinRed_SeReintentaDespuesYSigue() async {
    let r = await recorrer(["d1", "d2"], ["d1": .failure(URLError(.notConnectedToInternet))])

    XCTAssertEqual(r.vistos, [.reintentar, .enviado])
  }

  func testUnDiaVacio_SeSaltaYSigue() async {
    let r = await recorrer(["d1", "d2"], ["d1": .success(false)])

    XCTAssertEqual(r.vistos, [.saltado, .enviado])
  }

  func testMezcla_ElCorteGanaSoloDesdeDondeAparece() async {
    let r = await recorrer(
      ["d1", "d2", "d3", "d4", "d5"],
      ["d2": .failure(ventana), "d3": .failure(Falla()), "d4": .failure(invalido)]
    )

    XCTAssertEqual(r.vistos, [.enviado, .descartado, .reintentar, .cortado])
    XCTAssertEqual(r.intentados.last, "d4", "d5 nunca se intenta")
  }

  func testSinDias_NoLlamaANada() async {
    let r = await recorrer([], [:])

    XCTAssertTrue(r.intentados.isEmpty)
    XCTAssertTrue(r.registrados.isEmpty)
  }
}

/// `actualizarSesion`: qué hace Swift con lo que entrega Flutter.
final class SesionAplicarTests: XCTestCase {

  private var almacen: AlmacenEnMemoria!

  override func setUp() {
    super.setUp()
    almacen = AlmacenEnMemoria()
  }

  func testUnTokenSeGuarda() {
    XCTAssertEqual(Sesion.aplicar(token: "abc123", en: almacen), .ok)
    XCTAssertEqual(almacen.token, "abc123")
  }

  func testNilCierraLaSesion_BorraElToken() {
    almacen.token = "abc123"

    XCTAssertEqual(Sesion.aplicar(token: nil, en: almacen), .ok)

    XCTAssertNil(almacen.token)
  }

  func testUnTextoVacioOSoloEspaciosTambienCierraLaSesion() {
    for vacio in ["", "   ", "\n\t "] {
      almacen.token = "abc123"
      XCTAssertEqual(Sesion.aplicar(token: vacio, en: almacen), .ok)
      XCTAssertNil(almacen.token, "\(vacio.debugDescription) debe borrar la sesión")
    }
  }

  func testSeRecortanLosEspaciosDelToken() {
    _ = Sesion.aplicar(token: "  abc123\n", en: almacen)
    XCTAssertEqual(almacen.token, "abc123")
  }

  func testUnTokenNuevoReemplazaAlAnterior() {
    _ = Sesion.aplicar(token: "primero", en: almacen)
    _ = Sesion.aplicar(token: "segundo", en: almacen)
    XCTAssertEqual(almacen.token, "segundo")
  }

  func testEsIdempotente_MandarElMismoTokenDosVeces() {
    XCTAssertEqual(Sesion.aplicar(token: "abc123", en: almacen), .ok)
    XCTAssertEqual(Sesion.aplicar(token: "abc123", en: almacen), .ok)
    XCTAssertEqual(almacen.token, "abc123")
  }

  func testCerrarSesionSinTenerlaNoEsError() {
    XCTAssertNil(almacen.token)
    XCTAssertEqual(Sesion.aplicar(token: nil, en: almacen), .ok)
  }

  func testSiFallaGuardar_DevuelveErrorAlmacenamientoSinElToken() {
    almacen.falla = ErrorAlmacenSesion(operacion: "guardar", estado: -25299)

    let resultado = Sesion.aplicar(token: "abc123-secreto", en: almacen)

    guard case .errorAlmacenamiento(let detalle) = resultado else {
      return XCTFail("Debió devolver errorAlmacenamiento")
    }
    XCTAssertFalse(detalle.contains("abc123-secreto"), "El detalle nunca lleva el token")
    XCTAssertTrue(detalle.contains("-25299"))
    XCTAssertNil(almacen.token, "Si falló, no quedó guardado")
  }

  func testSiFallaBorrar_DevuelveErrorAlmacenamiento() {
    almacen.token = "abc123"
    almacen.falla = ErrorAlmacenSesion(operacion: "borrar", estado: -34018)

    guard case .errorAlmacenamiento = Sesion.aplicar(token: nil, en: almacen) else {
      return XCTFail("Debió devolver errorAlmacenamiento")
    }
  }
}

/// El Keychain de verdad. Cada prueba usa su propio servicio para no pisar el
/// token real de la app ni a las demás pruebas.
final class SesionKeychainTests: XCTestCase {

  private var servicio: String!
  private var keychain: SesionKeychain!

  override func setUp() {
    super.setUp()
    servicio = "com.assures.masvida.pruebas.\(UUID().uuidString)"
    keychain = SesionKeychain(servicio: servicio)
  }

  override func tearDown() {
    try? keychain.borrarToken()
    super.tearDown()
  }

  func testSinNadaGuardado_NoHayToken() {
    XCTAssertNil(keychain.leerToken())
  }

  func testGuardarYLeer() throws {
    try keychain.guardar(token: "abc123")
    XCTAssertEqual(keychain.leerToken(), "abc123")
  }

  func testGuardarDeNuevoSobrescribe_SinDuplicar() throws {
    try keychain.guardar(token: "primero")
    try keychain.guardar(token: "segundo")
    XCTAssertEqual(keychain.leerToken(), "segundo")
  }

  func testBorrar() throws {
    try keychain.guardar(token: "abc123")
    try keychain.borrarToken()
    XCTAssertNil(keychain.leerToken())
  }

  func testBorrarCuandoNoHayNadaNoEsError() throws {
    XCTAssertNoThrow(try keychain.borrarToken())
  }

  func testUnTokenLargoYConCaracteresRarosSobrevive() throws {
    let token = String(repeating: "aB3-_/+=", count: 40) + "ñ✓"
    try keychain.guardar(token: token)
    XCTAssertEqual(keychain.leerToken(), token)
  }

  func testDosServiciosDistintosNoSeVen() throws {
    let otro = SesionKeychain(servicio: servicio + ".otro")
    defer { try? otro.borrarToken() }

    try keychain.guardar(token: "mio")

    XCTAssertNil(otro.leerToken())
  }

  func testSeGuardaConAccesoDespuesDelPrimerDesbloqueo_SoloEnEsteDispositivo() throws {
    try keychain.guardar(token: "abc123")

    let consulta: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: servicio as Any,
      kSecAttrAccount as String: SesionKeychain.cuentaPorDefecto,
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var resultado: CFTypeRef?
    XCTAssertEqual(SecItemCopyMatching(consulta as CFDictionary, &resultado), errSecSuccess)
    let atributos = try XCTUnwrap(resultado as? [String: Any])

    XCTAssertEqual(
      atributos[kSecAttrAccessible as String] as? String,
      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
    )
  }

  func testElServicioYLaCuentaPorDefectoSonLosDelContrato() {
    XCTAssertEqual(SesionKeychain.servicioPorDefecto, "com.assures.masvida.sesion")
    XCTAssertEqual(SesionKeychain.cuentaPorDefecto, "token_api")
  }
}

// MARK: - Lo escrito a mano no cuenta (1 oct 2026)
// Estas pruebas fabrican muestras REALES de HealthKit (HKQuantitySample,
// HKWorkout) con y sin la marca de "manual", y comprueban lo que de verdad
// se manda. Si alguien borra una regla, una de ellas falla.

private enum Fab {
  static let inicio = Date(timeIntervalSince1970: 1_790_000_000)
  static let manual: [String: Any] = [HKMetadataKeyWasUserEntered: true]
  static let unidadRitmo = HKUnit.count().unitDivided(by: .minute())

  static func paso(_ cantidad: Double, minuto: Int = 0, metadata: [String: Any]? = nil) -> HKQuantitySample {
    let ini = inicio.addingTimeInterval(Double(minuto) * 60)
    return HKQuantitySample(
      type: HKQuantityType(.stepCount), quantity: HKQuantity(unit: .count(), doubleValue: cantidad),
      start: ini, end: ini.addingTimeInterval(540), metadata: metadata)
  }

  static func latido(_ bpm: Double, segundo: Int, metadata: [String: Any]? = nil) -> HKQuantitySample {
    let ini = inicio.addingTimeInterval(Double(segundo))
    return HKQuantitySample(
      type: HKQuantityType(.heartRate), quantity: HKQuantity(unit: unidadRitmo, doubleValue: bpm),
      start: ini, end: ini.addingTimeInterval(5), metadata: metadata)
  }

  static func workout(minutos: Double = 45, tipo: HKWorkoutActivityType = .running,
                      metadata: [String: Any]? = nil) -> HKWorkout {
    HKWorkout(
      activityType: tipo, start: inicio, end: inicio.addingTimeInterval(minutos * 60),
      duration: minutos * 60, totalEnergyBurned: nil, totalDistance: nil, metadata: metadata)
  }

  static func entrada(_ w: HKWorkout, ritmo: [HKQuantitySample]) -> EntradaWorkout {
    EntradaWorkout(w, tipoActividad: "running", ritmo: ritmo.map { EntradaRitmo($0) })
  }
}

final class ReglasManualesTests: XCTestCase {
  func testUnaLecturaEscritaAManoSeDetecta() {
    XCTAssertTrue(ReglasManuales.esManual(metadata: [HKMetadataKeyWasUserEntered: true]))
  }

  func testUnaLecturaMedidaPorUnSensorNoEsManual() {
    XCTAssertFalse(ReglasManuales.esManual(metadata: [HKMetadataKeyWasUserEntered: false]))
  }

  func testSinMetadataSeAsumeQueNoFueAMano() {
    // Un reloj de terceros suele no escribir esa marca: no se le acusa de nada.
    XCTAssertFalse(ReglasManuales.esManual(metadata: nil))
    XCTAssertFalse(ReglasManuales.esManual(metadata: [:]))
    XCTAssertFalse(ReglasManuales.esManual(metadata: ["otra_clave": true]))
  }

  func testUnaMarcaQueNoEsBooleanaNoCuentaComoManual() {
    XCTAssertFalse(ReglasManuales.esManual(metadata: [HKMetadataKeyWasUserEntered: "true"]))
  }
}

final class PasosManualesTests: XCTestCase {
  func testLosPasosEscritosAManoNoSeMandan() {
    let enviados = ReglasMuestras.pasos(de: [
      EntradaPaso(Fab.paso(3000, minuto: 0)),
      EntradaPaso(Fab.paso(15_000, minuto: 10, metadata: Fab.manual)),   // "15.000 pasos" inventados
      EntradaPaso(Fab.paso(500, minuto: 20)),
    ])

    XCTAssertEqual(enviados.map(\.cantidad), [3000, 500])
  }

  func testSiTodosLosPasosSonManualesNoSeMandaNada() {
    let enviados = ReglasMuestras.pasos(de: [
      EntradaPaso(Fab.paso(9000, metadata: Fab.manual)),
      EntradaPaso(Fab.paso(9000, minuto: 10, metadata: Fab.manual)),
    ])

    XCTAssertTrue(enviados.isEmpty)
  }

  func testUnPasoMedidoSeMandaCompletoYRedondeado() throws {
    let muestra = Fab.paso(1500.4, minuto: 5)

    let enviado = try XCTUnwrap(ReglasMuestras.pasos(de: [EntradaPaso(muestra)]).first)

    XCTAssertEqual(enviado.external_id, muestra.uuid.uuidString)
    XCTAssertEqual(enviado.cantidad, 1500)
    XCTAssertEqual(enviado.inicio, FormatoFechas.iso8601.string(from: muestra.startDate))
    XCTAssertEqual(enviado.fin, FormatoFechas.iso8601.string(from: muestra.endDate))
    XCTAssertNil(enviado.dispositivo_modelo)   // sin HKDevice => nulo, nunca vacío
  }

  func testElOrdenSeConserva() {
    let enviados = ReglasMuestras.pasos(de: [10, 20, 30].enumerated().map { EntradaPaso(Fab.paso(Double($1), minuto: $0 * 10)) })

    XCTAssertEqual(enviados.map(\.cantidad), [10, 20, 30])
  }
}

final class RitmoManualTests: XCTestCase {
  func testElRitmoEscritoAManoNoSeManda() {
    let enviados = ReglasMuestras.ritmo(de: [
      EntradaRitmo(Fab.latido(120, segundo: 0)),
      EntradaRitmo(Fab.latido(190, segundo: 10, metadata: Fab.manual)),
    ])

    XCTAssertEqual(enviados.map(\.bpm), [120])
  }

  func testLasEstadisticasIgnoranLasLecturasManuales() {
    let stats = ReglasMuestras.estadisticas(de: [
      EntradaRitmo(Fab.latido(100, segundo: 0)),
      EntradaRitmo(Fab.latido(140, segundo: 10)),
      EntradaRitmo(Fab.latido(220, segundo: 20, metadata: Fab.manual)),   // inflaría el máximo
    ])

    XCTAssertEqual(stats.promedio, 120)
    XCTAssertEqual(stats.minimo, 100)
    XCTAssertEqual(stats.maximo, 140)
  }

  func testSinLecturasMedidasLasEstadisticasSonVacias() {
    XCTAssertNil(ReglasMuestras.estadisticas(de: []).promedio)
    XCTAssertNil(ReglasMuestras.estadisticas(
      de: [EntradaRitmo(Fab.latido(150, segundo: 0, metadata: Fab.manual))]).maximo)
  }
}

final class SesionesQueSeMandanTests: XCTestCase {
  private let ritmoMedido = [Fab.latido(140, segundo: 60), Fab.latido(160, segundo: 120), Fab.latido(150, segundo: 180)]

  func testUnWorkoutMedidoConRitmoSeMandaConSusDatos() throws {
    let w = Fab.workout(minutos: 45)

    let enviadas = ReglasWorkout.sesiones(de: [Fab.entrada(w, ritmo: ritmoMedido)])

    let sesion = try XCTUnwrap(enviadas.first)
    XCTAssertEqual(enviadas.count, 1)
    XCTAssertEqual(sesion.external_id, w.uuid.uuidString)
    XCTAssertEqual(sesion.duracion_min, 45)
    XCTAssertEqual(sesion.tipo_actividad, "running")
    XCTAssertEqual(sesion.fc_promedio, 150)
    XCTAssertEqual(sesion.fc_maxima, 160)
  }

  func testUnWorkoutIngresadoAManoNoSeManda() {
    // Aunque traiga ritmo cardíaco medido en la ventana.
    let manual = Fab.workout(metadata: Fab.manual)

    XCTAssertTrue(ReglasWorkout.sesiones(de: [Fab.entrada(manual, ritmo: ritmoMedido)]).isEmpty)
  }

  func testUnWorkoutSinRitmoCardiacoNoSeManda() {
    // Era el caso del iPhone sin reloj: antes salía con fc_promedio = 0.
    XCTAssertTrue(ReglasWorkout.sesiones(de: [Fab.entrada(Fab.workout(), ritmo: [])]).isEmpty)
  }

  func testUnWorkoutCuyoUnicoRitmoFueEscritoAManoNoSeManda() {
    let inventado = [Fab.latido(150, segundo: 60, metadata: Fab.manual), Fab.latido(170, segundo: 120, metadata: Fab.manual)]

    XCTAssertTrue(ReglasWorkout.sesiones(de: [Fab.entrada(Fab.workout(), ritmo: inventado)]).isEmpty)
  }

  func testUnaLecturaManualDentroDeUnWorkoutNoCambiaSuRitmo() throws {
    let mezcla = ritmoMedido + [Fab.latido(230, segundo: 240, metadata: Fab.manual)]

    let sesion = try XCTUnwrap(ReglasWorkout.sesiones(de: [Fab.entrada(Fab.workout(), ritmo: mezcla)]).first)

    XCTAssertEqual(sesion.fc_maxima, 160)    // no 230
    XCTAssertEqual(sesion.fc_promedio, 150)
  }

  func testDeVariosWorkoutsSoloSeMandanLosValidosYEnOrden() {
    let bueno1 = Fab.workout(minutos: 30)
    let manual = Fab.workout(minutos: 50, metadata: Fab.manual)
    let sinReloj = Fab.workout(minutos: 40)
    let bueno2 = Fab.workout(minutos: 60)

    let enviadas = ReglasWorkout.sesiones(de: [
      Fab.entrada(bueno1, ritmo: ritmoMedido),
      Fab.entrada(manual, ritmo: ritmoMedido),
      Fab.entrada(sinReloj, ritmo: []),
      Fab.entrada(bueno2, ritmo: ritmoMedido),
    ])

    XCTAssertEqual(enviadas.map(\.external_id), [bueno1.uuid.uuidString, bueno2.uuid.uuidString])
  }

  func testNuncaSeMandaUnRitmoEnCero() {
    // El servidor lo descartaría, y un 0 inventado es justo lo que ya no se hace.
    let enCero = [Fab.latido(0, segundo: 0)]

    XCTAssertTrue(ReglasWorkout.sesiones(de: [Fab.entrada(Fab.workout(), ritmo: enCero)]).isEmpty)
  }
}

final class FCParaEnviarTests: XCTestCase {
  func testSinNingunDatoDeRitmoNoHayFC() {
    XCTAssertNil(ReglasWorkout.fcParaEnviar(stats: .vacio))
  }

  func testConSoloPromedioONadaMasNoHayFC() {
    XCTAssertNil(ReglasWorkout.fcParaEnviar(stats: HeartRateStats(promedio: 140, minimo: nil, maximo: nil)))
    XCTAssertNil(ReglasWorkout.fcParaEnviar(stats: HeartRateStats(promedio: nil, minimo: nil, maximo: 160)))
  }

  func testUnRitmoEnCeroONoSeManda() {
    XCTAssertNil(ReglasWorkout.fcParaEnviar(stats: HeartRateStats(promedio: 0, minimo: 0, maximo: 0)))
    XCTAssertNil(ReglasWorkout.fcParaEnviar(stats: HeartRateStats(promedio: 0.4, minimo: 0.2, maximo: 0.4)))
  }

  func testConRitmoMedidoSeMandaRedondeado() {
    let fc = ReglasWorkout.fcParaEnviar(stats: HeartRateStats(promedio: 142.6, minimo: 90, maximo: 161.2))

    XCTAssertEqual(fc, ReglasWorkout.FC(promedio: 143, maxima: 161))
  }

  func testNoHayDatosEsUnCasoNormalNoUnFallo() {
    XCTAssertTrue(ReglasWorkout.esSinDatos(HKError(.errorNoData)))
  }

  func testOtrosErroresDeHealthKitSiSonFallos() {
    XCTAssertFalse(ReglasWorkout.esSinDatos(HKError(.errorAuthorizationDenied)))
    XCTAssertFalse(ReglasWorkout.esSinDatos(HKError(.errorDatabaseInaccessible)))
    XCTAssertFalse(ReglasWorkout.esSinDatos(NSError(domain: "otro", code: 11)))
  }
}
