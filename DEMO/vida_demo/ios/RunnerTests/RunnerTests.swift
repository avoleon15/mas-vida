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

  func testElConsentimientoPendiente_SeReintentaComoElTokenRechazado() {
    // El 403 de `consentimiento_requerido` se arregla cuando la persona acepta,
    // igual que el 401 cuando vuelve a entrar: el día no se descarta.
    XCTAssertEqual(AccionDiaFallido.para(ApiError.consentimientoRequerido), .reintentarDespues)
    XCTAssertEqual(AccionDiaFallido.para(ApiError.consentimientoRequerido),
                   AccionDiaFallido.para(servidor(401)))
    XCTAssertTrue(ApiError.consentimientoRequerido.esReintentable)
  }

  func testUn403QueNoEsDeConsentimiento_SigueSiendoPermanente() {
    // Por ejemplo, la cuenta sin perfil: reintentar no lo arregla.
    for cuerpo in [nil, "", #"{"mensaje":"El usuario autenticado no tiene un perfil asociado."}"#] {
      XCTAssertEqual(
        AccionDiaFallido.para(ApiError.servidor(codigo: 403, cuerpo: cuerpo)),
        .descartarYCortar, "cuerpo: \(String(describing: cuerpo))")
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
  }

  func testUnaRespuestaIlegible_SeTomaComoEnviada() {
    // El servidor respondió 2xx: el día ya está guardado (decidido 3 oct 2026).
    XCTAssertEqual(AccionDiaFallido.para(ApiError.respuestaIlegible), .tomarComoEnviado)
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
  ) async -> (intentados: [String], registrados: [String], vistos: [Visto], fin: FinDeVuelta) {
    var intentados: [String] = []
    var registrados: [String] = []
    var vistos: [Visto] = []
    let fin = await RecorridoDias.recorrer(
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
    return (intentados, registrados, vistos, fin)
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

  func testSinRed_SeReintentaDespuesYCorta() async {
    let r = await recorrer(["d1", "d2", "d3"], ["d1": .failure(URLError(.notConnectedToInternet))])

    XCTAssertEqual(r.vistos, [.reintentar])
    XCTAssertEqual(r.intentados, ["d1"], "Los demás fallarían igual: no se gastan intentos")
    XCTAssertEqual(r.fin, .cortadaPorFalloGeneral)
  }

  func testServidorCaidoOTokenRechazado_TambienCortan() async {
    for error in [ApiError.servidor(codigo: 503, cuerpo: nil),
                  ApiError.servidor(codigo: 401, cuerpo: nil),
                  ApiError.sinSesion] {
      let r = await recorrer(["d1", "d2", "d3"], ["d2": .failure(error)])

      XCTAssertEqual(r.intentados, ["d1", "d2"], "\(error)")
      XCTAssertEqual(r.fin, .cortadaPorFalloGeneral, "\(error)")
    }
  }

  func testComoTermina_CadaVuelta() async {
    let completa = await recorrer(["d1", "d2"], [:])
    XCTAssertEqual(completa.fin, .completa)

    let conVentanaEIlegible = await recorrer(
      ["d1", "d2"], ["d1": .failure(ventana), "d2": .failure(ApiError.respuestaIlegible)])
    XCTAssertEqual(conVentanaEIlegible.fin, .completa, "Ninguno de los dos corta")

    let rechazo = await recorrer(["d1", "d2"], ["d1": .failure(invalido)])
    XCTAssertEqual(rechazo.fin, .cortadaPorRechazo)

    let vacia = await recorrer([], [:])
    XCTAssertEqual(vacia.fin, .completa)
  }

  func testUnDiaVacio_SeSaltaYSigue() async {
    let r = await recorrer(["d1", "d2"], ["d1": .success(false)])

    XCTAssertEqual(r.vistos, [.saltado, .enviado])
  }

  func testMezcla_ElCorteGanaSoloDesdeDondeAparece() async {
    let r = await recorrer(
      ["d1", "d2", "d3", "d4", "d5"],
      ["d2": .failure(ventana), "d3": .failure(invalido), "d4": .failure(Falla())]
    )

    XCTAssertEqual(r.vistos, [.enviado, .descartado, .cortado])
    XCTAssertEqual(r.intentados.last, "d3", "d4 y d5 nunca se intentan")
  }

  func testUnaRespuestaIlegible_CuentaComoEnviadaYSigue() async {
    let r = await recorrer(["d1", "d2", "d3"], ["d2": .failure(ApiError.respuestaIlegible)])

    XCTAssertEqual(r.intentados, ["d1", "d2", "d3"], "No corta la vuelta")
    XCTAssertEqual(r.vistos, [.enviado, .enviado, .enviado])
  }

  func testSinDias_NoLlamaANada() async {
    let r = await recorrer([], [:])

    XCTAssertTrue(r.intentados.isEmpty)
    XCTAssertTrue(r.registrados.isEmpty)
  }
}

/// La cola de reintentos: orden, duplicados, tope, y que los días caduquen
/// a los 14 días, igual que la ventana del servidor.
final class SyncQueueTests: XCTestCase {

  private var almacen: UserDefaults!
  private var nombreAlmacen: String!
  private var ahora: Date!
  private var cola: SyncQueue!

  private static func dia(_ texto: String, hora: Int = 15) -> Date {
    FormatoFechas.diaCalendario.date(from: texto)!.addingTimeInterval(Double(hora) * 3600)
  }

  /// `yyyy-MM-dd` de hace `n` días respecto de `ahora`.
  private func haceDias(_ n: Int) -> String {
    FormatoFechas.diaCalendario.string(from: Calendar.current.date(byAdding: .day, value: -n, to: ahora)!)
  }

  override func setUp() {
    super.setUp()
    nombreAlmacen = "pruebas.cola.\(UUID().uuidString)"
    almacen = UserDefaults(suiteName: nombreAlmacen)
    ahora = Self.dia("2026-10-03")
    cola = SyncQueue(almacen: almacen, hoy: { self.ahora })
  }

  override func tearDown() {
    almacen.removePersistentDomain(forName: nombreAlmacen)
    super.tearDown()
  }

  private var guardado: [String] { almacen.stringArray(forKey: "vida.diasPendientes") ?? [] }

  func testEncolarGuardaEnOrden_SinDuplicar() {
    cola.encolar(fecha: "2026-10-01")
    cola.encolar(fecha: "2026-09-30")
    cola.encolar(fecha: "2026-10-01")

    XCTAssertEqual(cola.pendientes(), ["2026-10-01", "2026-09-30"])
  }

  func testRemover() {
    cola.encolar(fecha: "2026-10-01")
    cola.encolar(fecha: "2026-09-30")

    cola.remover(fecha: "2026-10-01")

    XCTAssertEqual(cola.pendientes(), ["2026-09-30"])
  }

  func testElDiaDeHace14DiasSigue_ElDeHace15Caduca() {
    XCTAssertEqual(haceDias(14), "2026-09-19")
    cola.encolar(fecha: haceDias(14))
    cola.encolar(fecha: haceDias(15))

    XCTAssertEqual(cola.pendientes(), ["2026-09-19"])
  }

  func testLaCuentaEsLaMismaQueLaDelServidor() {
    // views.py: rechaza si fecha < hoy - 14.
    for n in 0...20 {
      XCTAssertEqual(cola.vencido(haceDias(n)), n > 14, "hace \(n) días")
    }
  }

  func testLaHoraDelDiaNoCambiaLaCuenta() {
    for hora in [0, 1, 12, 23] {
      ahora = Self.dia("2026-10-03", hora: hora)
      XCTAssertFalse(cola.vencido("2026-09-19"), "a las \(hora)h")
      XCTAssertTrue(cola.vencido("2026-09-18"), "a las \(hora)h")
    }
  }

  func testUnDiaYaVencidoNoSeEncola() {
    cola.encolar(fecha: "2026-09-01")

    XCTAssertTrue(guardado.isEmpty)
  }

  func testLosDiasCaducanSolosConElTiempo() {
    cola.encolar(fecha: "2026-10-01")
    XCTAssertEqual(cola.pendientes(), ["2026-10-01"])

    ahora = Self.dia("2026-10-15")   // hace 14 días: sigue
    XCTAssertEqual(cola.pendientes(), ["2026-10-01"])

    ahora = Self.dia("2026-10-16")   // hace 15 días: fuera
    XCTAssertEqual(cola.pendientes(), [])
  }

  func testLeerLaColaBorraDelDiscoLosVencidos() {
    // Como quedaría una cola guardada por la versión anterior (sin caducidad).
    almacen.set(["2026-08-01", "2026-10-01", "2026-09-01"], forKey: "vida.diasPendientes")

    XCTAssertEqual(cola.pendientes(), ["2026-10-01"])
    XCTAssertEqual(guardado, ["2026-10-01"], "Los vencidos se borran, no solo se esconden")
  }

  func testUnaFechaIlegibleNoSeDaPorVencida() {
    // La saca reintentarPendientes(), que sabe que no se puede mandar.
    almacen.set(["no-es-fecha", "2026-10-01"], forKey: "vida.diasPendientes")

    XCTAssertEqual(cola.pendientes(), ["no-es-fecha", "2026-10-01"])
  }

  func testElTopeEs15_YSaleElPrimeroQueEntro() {
    XCTAssertEqual(SyncQueue.maximoDias, 15)
    for n in (0...14).reversed() { cola.encolar(fecha: haceDias(n)) }   // 15 días válidos
    XCTAssertEqual(cola.pendientes().count, 15)

    cola.encolar(fecha: "2026-10-10")   // uno más (futuro, solo para pasar el tope)

    XCTAssertEqual(cola.pendientes().count, 15)
    XCTAssertFalse(cola.pendientes().contains(haceDias(14)), "Sale el que entró primero")
    XCTAssertTrue(cola.pendientes().contains("2026-10-10"))
  }

  func testLaColaDePruebaNoTocaLaReal() {
    let real = UserDefaults.standard.stringArray(forKey: "vida.diasPendientes")

    cola.encolar(fecha: "2026-10-01")

    XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "vida.diasPendientes"), real)
  }

  func testVaciar() {
    cola.encolar(fecha: "2026-10-01")
    cola.encolar(fecha: "2026-10-02")

    cola.vaciar()

    XCTAssertEqual(cola.pendientes(), [])
  }

  func testAplicarCadaEfecto() {
    cola.encolar(fecha: "2026-10-01")

    cola.aplicar(.dejar, a: "2026-10-01")
    XCTAssertEqual(cola.pendientes(), ["2026-10-01"])

    cola.aplicar(.encolar, a: "2026-10-02")
    XCTAssertEqual(cola.pendientes(), ["2026-10-01", "2026-10-02"])

    cola.aplicar(.sacar, a: "2026-10-01")
    XCTAssertEqual(cola.pendientes(), ["2026-10-02"])
  }
}

/// Qué le pasa a un día en la cola según cómo terminó, en cada camino.
final class EfectoDeCadaDesenlaceTests: XCTestCase {

  private struct Falla: Error {}
  private let error = Falla()

  func testEnLaColaDeReintentos() {
    XCTAssertEqual(DesenlaceDia.enviado.efectoEnReintento, .sacar)
    XCTAssertEqual(DesenlaceDia.descartado(error).efectoEnReintento, .sacar, "Un 422 sale de la cola")
    XCTAssertEqual(DesenlaceDia.cortado(error).efectoEnReintento, .sacar)
    XCTAssertEqual(DesenlaceDia.saltado.efectoEnReintento, .dejar, "Ante la duda, un día vacío se queda")
    XCTAssertEqual(DesenlaceDia.reintentarDespues(error).efectoEnReintento, .dejar)
  }

  func testAlPonerseAlDia() {
    XCTAssertEqual(DesenlaceDia.enviado.efectoAlPonerseAlDia, .sacar)
    XCTAssertEqual(DesenlaceDia.descartado(error).efectoAlPonerseAlDia, .sacar)
    XCTAssertEqual(DesenlaceDia.reintentarDespues(error).efectoAlPonerseAlDia, .encolar)
    XCTAssertEqual(DesenlaceDia.saltado.efectoAlPonerseAlDia, .dejar, "Un día vacío no se anota")
    XCTAssertEqual(DesenlaceDia.cortado(error).efectoAlPonerseAlDia, .dejar,
                   "Tras un corte la marca no avanza: se reintenta desde ahí, sin la cola")
  }

  func testSoloLoQueYaNoHayQueMandarMueveLaMarca() {
    XCTAssertTrue(DesenlaceDia.enviado.avanzaMarca)
    XCTAssertTrue(DesenlaceDia.descartado(error).avanzaMarca,
                  "Un día fuera de la ventana no va a entrar nunca")
    XCTAssertFalse(DesenlaceDia.saltado.avanzaMarca,
                   "Un día vacío puede ser un permiso que todavía no se dio")
    XCTAssertFalse(DesenlaceDia.reintentarDespues(error).avanzaMarca)
    XCTAssertFalse(DesenlaceDia.cortado(error).avanzaMarca)
  }
}

/// Desde qué día ponerse al día (decidido 3 oct 2026): la primera vez, los
/// últimos 7 días; después, desde el último enviado (otra vez) hasta hoy,
/// sin pasar de la ventana de 14 días del servidor.
final class MarcaEnviosTests: XCTestCase {

  private var almacen: UserDefaults!
  private var nombreAlmacen: String!
  private var ahora: Date!
  private var marca: MarcaEnvios!

  private static func dia(_ texto: String, hora: Int = 15) -> Date {
    FormatoFechas.diaCalendario.date(from: texto)!.addingTimeInterval(Double(hora) * 3600)
  }

  override func setUp() {
    super.setUp()
    nombreAlmacen = "pruebas.marca.\(UUID().uuidString)"
    almacen = UserDefaults(suiteName: nombreAlmacen)
    ahora = Self.dia("2026-10-03")
    marca = MarcaEnvios(almacen: almacen, hoy: { self.ahora })
  }

  override func tearDown() {
    almacen.removePersistentDomain(forName: nombreAlmacen)
    super.tearDown()
  }

  func testLaPrimeraVez_LosUltimos7Dias_DelMasViejoAHoy() {
    XCTAssertNil(marca.ultimoDiaEnviado)
    XCTAssertEqual(marca.diasPorMandar(), [
      "2026-09-27", "2026-09-28", "2026-09-29", "2026-09-30",
      "2026-10-01", "2026-10-02", "2026-10-03",
    ])
  }

  func testConMarca_DesdeEseDiaOtraVezHastaHoy() {
    marca.registrarEnviado("2026-10-01")

    XCTAssertEqual(marca.diasPorMandar(), ["2026-10-01", "2026-10-02", "2026-10-03"],
                   "El último enviado se repite: pudo sumar pasos después del envío")
  }

  func testEnviadoHoy_SoloHoy() {
    marca.registrarEnviado("2026-10-03")

    XCTAssertEqual(marca.diasPorMandar(), ["2026-10-03"])
  }

  func testUnaMarcaMuyVieja_SeRecortaALaVentanaDelServidor() {
    marca.registrarEnviado("2026-08-01")

    let dias = marca.diasPorMandar()
    XCTAssertEqual(dias.first, "2026-09-19", "hoy - 14: el más viejo que el servidor acepta")
    XCTAssertEqual(dias.last, "2026-10-03")
    XCTAssertEqual(dias.count, 15)
  }

  func testUnaMarcaEnElFuturo_NoDejaAHoyAfuera() {
    marca.registrarEnviado("2026-10-09")   // el reloj del teléfono se movió

    XCTAssertEqual(marca.diasPorMandar(), ["2026-10-03"])
  }

  func testLaMarcaSoloAvanza() {
    marca.registrarEnviado("2026-10-02")
    marca.registrarEnviado("2026-09-30")   // un día viejo que llegó tarde

    XCTAssertEqual(marca.ultimoDiaEnviado, "2026-10-02")
  }

  func testOlvidar_VuelveAEmpezarComoLaPrimeraVez() {
    marca.registrarEnviado("2026-10-02")

    marca.olvidar()

    XCTAssertNil(marca.ultimoDiaEnviado)
    XCTAssertEqual(marca.diasPorMandar().count, MarcaEnvios.diasPrimeraVez)
  }

  func testUnaFechaIlegibleNoSeGuarda_YLaGuardadaSeIgnora() {
    marca.registrarEnviado("no-es-fecha")
    XCTAssertNil(marca.ultimoDiaEnviado)

    almacen.set("basura", forKey: "vida.ultimoDiaEnviado")
    XCTAssertNil(marca.ultimoDiaEnviado)
    XCTAssertEqual(marca.diasPorMandar().count, MarcaEnvios.diasPrimeraVez)
  }

  func testCruzandoElCambioDeMes() {
    ahora = Self.dia("2026-11-01")
    marca.registrarEnviado("2026-10-30")

    XCTAssertEqual(marca.diasPorMandar(), ["2026-10-30", "2026-10-31", "2026-11-01"])
  }

  func testLaHoraDelDiaNoCambiaLaCuenta() {
    marca.registrarEnviado("2026-10-02")
    for hora in [0, 1, 23] {
      ahora = Self.dia("2026-10-03", hora: hora)
      XCTAssertEqual(marca.diasPorMandar(), ["2026-10-02", "2026-10-03"], "a las \(hora)h")
    }
  }

  func testLaMarcaDePruebaNoTocaLaReal() {
    let real = UserDefaults.standard.string(forKey: "vida.ultimoDiaEnviado")

    marca.registrarEnviado("2026-10-02")

    XCTAssertEqual(UserDefaults.standard.string(forKey: "vida.ultimoDiaEnviado"), real)
  }
}

/// Al entrar otra persona se olvida hasta qué día se había mandado: tiene que
/// recibir sus 7 días. Desde A35 cada login trae un token nuevo, así que "otra
/// persona" se decide por el `usuario_id` y la misma persona no pierde la cola.
final class SesionYMarcaTests: XCTestCase {

  private var almacen: AlmacenEnMemoria!
  private var defaults: UserDefaults!
  private var nombre: String!
  private var marca: MarcaEnvios!
  private var cola: SyncQueue!
  private var cuenta: CuentaDeEnvios!

  override func setUp() {
    super.setUp()
    almacen = AlmacenEnMemoria()
    nombre = "pruebas.sesionmarca.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: nombre)
    let hoy = { FormatoFechas.diaCalendario.date(from: "2026-10-03")!.addingTimeInterval(15 * 3600) }
    marca = MarcaEnvios(almacen: defaults, hoy: hoy)
    cola = SyncQueue(almacen: defaults, hoy: hoy)
    cuenta = CuentaDeEnvios(almacen: defaults)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: nombre)
    super.tearDown()
  }

  @discardableResult
  private func aplicar(_ token: String?, _ usuarioId: String?) -> (resultado: ResultadoActualizarSesion, haySesion: Bool) {
    Sesion.aplicar(token: token, usuarioId: usuarioId, en: almacen, marca: marca, cola: cola, cuenta: cuenta)
  }

  /// Ana entró, mandó hasta el 2 y le queda el 25 en la cola.
  private func anaConDiasPendientes() {
    aplicar("abc", "ana")
    marca.registrarEnviado("2026-10-02")
    cola.encolar(fecha: "2026-09-25")
  }

  private func nadaSeOlvido(_ mensaje: String = "", file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(marca.ultimoDiaEnviado, "2026-10-02", mensaje, file: file, line: line)
    XCTAssertEqual(cola.pendientes(), ["2026-09-25"], mensaje, file: file, line: line)
  }

  private func seOlvidoTodo(_ mensaje: String = "", file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertNil(marca.ultimoDiaEnviado, mensaje, file: file, line: line)
    XCTAssertEqual(cola.pendientes(), [], mensaje, file: file, line: line)
  }

  func testElMismoTokenEnCadaArranque_NoOlvidaNada() {
    anaConDiasPendientes()

    let r = aplicar("abc", "ana")

    XCTAssertEqual(r.resultado, .ok)
    XCTAssertTrue(r.haySesion)
    nadaSeOlvido()
  }

  func testLaMismaPersonaConUnTokenNuevo_NoPierdeLaCola() {
    // Su token venció (o entró de nuevo): Knox le da otro, pero es Ana.
    anaConDiasPendientes()

    let r = aplicar("token-nuevo", "ana")

    XCTAssertTrue(r.haySesion)
    nadaSeOlvido("Es la misma persona: sigue donde iba")
  }

  func testOtraPersona_OlvidaLaMarcaYVaciaLaCola() {
    anaConDiasPendientes()

    let r = aplicar("otra", "beto")

    XCTAssertTrue(r.haySesion)
    seOlvidoTodo("Beto no recibe días de Ana")
    XCTAssertEqual(cuenta.usuarioId, "beto")
  }

  func testCerrarSesion_SoloBorraElToken() {
    anaConDiasPendientes()

    let r = aplicar(nil, nil)

    XCTAssertEqual(r.resultado, .ok)
    XCTAssertFalse(r.haySesion)
    XCTAssertNil(almacen.leerToken())
    nadaSeOlvido("Se decide cuando alguien entre")
    XCTAssertEqual(cuenta.usuarioId, "ana", "Se recuerda para comparar")
  }

  func testCerrarSesionYVuelveLaMisma_SigueDondeIba() {
    anaConDiasPendientes()
    aplicar(nil, nil)

    aplicar("token-nuevo", "ana")

    nadaSeOlvido()
  }

  func testCerrarSesionYEntraOtra_SeOlvidaTodo() {
    anaConDiasPendientes()
    aplicar(nil, nil)

    aplicar("token-de-beto", "beto")

    seOlvidoTodo()
  }

  func testSiFallaElKeychain_NoSeOlvidaNada() {
    anaConDiasPendientes()
    almacen.falla = ErrorAlmacenSesion(operacion: "guardar", estado: -25308)

    let r = aplicar("otra", "beto")

    guard case .errorAlmacenamiento = r.resultado else { return XCTFail("Debió fallar") }
    XCTAssertTrue(r.haySesion, "Sigue el token anterior")
    nadaSeOlvido("El token no cambió, así que la cuenta tampoco")
    XCTAssertEqual(cuenta.usuarioId, "ana")
  }

  func testElPrimerLogin_AnotaLaCuenta_YQuedaSesion() {
    let r = aplicar("abc", "ana")

    XCTAssertEqual(r.resultado, .ok)
    XCTAssertTrue(r.haySesion)
    XCTAssertNil(marca.ultimoDiaEnviado)
    XCTAssertEqual(cuenta.usuarioId, "ana")
  }

  // MARK: Sin `usuario_id`: se compara el token, como antes de A35

  func testSinUsuarioId_ElMismoToken_NoOlvidaNada() {
    anaConDiasPendientes()

    aplicar("abc", nil)

    nadaSeOlvido()
    XCTAssertEqual(cuenta.usuarioId, "ana", "Con el mismo token sigue siendo Ana")
  }

  func testSinUsuarioId_OtroToken_OlvidaTodo_YYaNoSabeDeQuienEs() {
    anaConDiasPendientes()

    aplicar("otra", nil)

    seOlvidoTodo("Sin saber quién es, otro token cuenta como otra persona")
    XCTAssertNil(cuenta.usuarioId)
  }

  func testUnUsuarioIdVacioOSoloEspacios_CuentaComoQueNoVino() {
    anaConDiasPendientes()

    aplicar("otra", "  ")

    seOlvidoTodo()
    XCTAssertNil(cuenta.usuarioId)
  }

  func testAlActualizarDesdeUnaVersionSinCuentaAnotada_ElMismoToken_NoOlvidaNada() {
    // La versión anterior guardó el token pero nunca anotó la cuenta.
    _ = Sesion.aplicar(token: "abc", en: almacen)
    marca.registrarEnviado("2026-10-02")
    cola.encolar(fecha: "2026-09-25")
    XCTAssertNil(cuenta.usuarioId)

    aplicar("abc", "ana")

    nadaSeOlvido("La migración a Knox conserva la clave del token")
    XCTAssertEqual(cuenta.usuarioId, "ana")
  }

  func testLaCuentaSeGuardaDondeSeLeVaABuscar() {
    aplicar("abc", "ana")

    XCTAssertEqual(defaults.string(forKey: "vida.cuentaDeLosEnvios"), "ana")
    XCTAssertEqual(CuentaDeEnvios(almacen: defaults).usuarioId, "ana", "Sobrevive a reiniciar la app")
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

/// El `403 consentimiento_requerido`: el servidor todavía no deja recibir datos de
/// quien no aceptó el consentimiento. Es "pendiente", no "rechazado": el día no se
/// pierde y sale solo cuando la persona acepte.
final class ApiClientConsentimientoTests: XCTestCase {

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

  func testElMotivoSeReconoce_YSeReintenta() async {
    let error = await errorAl(
      responder: 403,
      #"{"error":"consentimiento_requerido","mensaje":"Acepta el consentimiento para continuar."}"#)

    guard case .consentimientoRequerido? = error as? ApiError else {
      return XCTFail("Debió ser consentimientoRequerido, fue: \(String(describing: error))")
    }
    XCTAssertEqual((error as? ApiError)?.esReintentable, true)
    XCTAssertEqual(AccionDiaFallido.para(error!), .reintentarDespues)
  }

  func testSiLaFormaEsOtra_PeroTraeElMotivo_IgualSeReconoce() async {
    // Todavía no está en `dev` cómo lo manda Luis: perder el día por una
    // diferencia de forma sería peor que reintentarlo de más.
    for cuerpo in [
      #"{"detail":"consentimiento_requerido"}"#,
      #"{"codigo":"consentimiento_requerido","version":"2026-10-06"}"#,
      "consentimiento_requerido",
    ] {
      let error = await errorAl(responder: 403, cuerpo)

      guard case .consentimientoRequerido? = error as? ApiError else {
        return XCTFail("Con \(cuerpo) debió ser consentimientoRequerido, fue: \(String(describing: error))")
      }
    }
  }

  func testOtro403_SigueSiendoPermanente() async {
    for cuerpo in [
      #"{"mensaje":"El usuario autenticado no tiene un perfil asociado."}"#,  // cuenta sin perfil
      #"{"error":"otra_cosa"}"#,                                               // otro motivo
      #"<html>Forbidden</html>"#,                                              // no es JSON
      "",                                                                      // sin cuerpo
    ] {
      let error = await errorAl(responder: 403, cuerpo)

      guard case .servidor(let codigo, _)? = error as? ApiError else {
        return XCTFail("Con \(cuerpo) debió ser servidor(403), fue: \(String(describing: error))")
      }
      XCTAssertEqual(codigo, 403)
      XCTAssertEqual(AccionDiaFallido.para(error!), .descartarYCortar, cuerpo)
    }
  }

  func testEl403QueDiceOtroMotivo_NoSeConfundeConElDeConsentimiento() async {
    // Un `error` distinto pesa más que un texto suelto: no se reintenta por
    // casualidad.
    let error = await errorAl(
      responder: 403, #"{"error":"cuenta_suspendida","nota":"no es consentimiento_requerido"}"#)

    guard case .servidor(let codigo, _)? = error as? ApiError else {
      return XCTFail("Debió ser servidor(403), fue: \(String(describing: error))")
    }
    XCTAssertEqual(codigo, 403)
  }

  func testElMismoCuerpoConOtroCodigo_NoEsDeConsentimiento() async {
    for status in [400, 401, 404, 422, 500] {
      let error = await errorAl(responder: status, #"{"error":"consentimiento_requerido"}"#)

      guard case .servidor(let codigo, _)? = error as? ApiError else {
        return XCTFail("Con \(status) debió ser servidor, fue: \(String(describing: error))")
      }
      XCTAssertEqual(codigo, status)
    }
  }

  func testElMensajeEsClaro_YNoTraeElToken() async {
    let error = await errorAl(responder: 403, #"{"error":"consentimiento_requerido"}"#)

    let mensaje = error?.localizedDescription ?? ""
    XCTAssertTrue(mensaje.lowercased().contains("consentimiento"))
    XCTAssertFalse(mensaje.contains("abc123-secreto"))
  }
}

/// Lo que pasa con los días mientras el consentimiento está pendiente, y cuando se
/// acepta. Es la razón del cambio: el servidor deja de aceptar días y ninguno se
/// puede perder en el camino (revisión del 6 de octubre de 2026).
@MainActor
final class ConsentimientoPendienteTests: XCTestCase {

  private var defaults: UserDefaults!
  private var nombre: String!
  private var marca: MarcaEnvios!
  private var cola: SyncQueue!

  override func setUp() {
    super.setUp()
    nombre = "pruebas.consentimiento.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: nombre)
    let hoy = { FormatoFechas.diaCalendario.date(from: "2026-10-14")!.addingTimeInterval(15 * 3600) }
    marca = MarcaEnvios(almacen: defaults, hoy: hoy)
    cola = SyncQueue(almacen: defaults, hoy: hoy)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: nombre)
    super.tearDown()
  }

  /// La vuelta de la cola de reintentos (`reintentarPendientes`), con `respuesta`
  /// como servidor.
  private func reintentar(_ respuesta: Result<Bool, Error>) async -> FinDeVuelta {
    await RecorridoDias.recorrer(
      cola.pendientes(),
      enviar: { _ in try respuesta.get() },
      registrar: { dia, desenlace in
        self.cola.aplicar(desenlace.efectoEnReintento, a: dia)
        if desenlace.avanzaMarca { self.marca.registrarEnviado(dia) }
      }
    )
  }

  func testUnDiaViejoEnLaCola_NoSePierdeConElConsentimientoPendiente() async {
    // El caso que el 403 como "permanente" sí perdía: el día 8 falló antes por red,
    // es anterior a la marca, y por eso nadie lo vuelve a calcular: solo vive en la
    // cola.
    marca.registrarEnviado("2026-10-10")
    cola.encolar(fecha: "2026-10-08")

    let fin = await reintentar(.failure(ApiError.consentimientoRequerido))

    XCTAssertEqual(fin, .cortadaPorFalloGeneral)
    XCTAssertEqual(cola.pendientes(), ["2026-10-08"], "El día sigue en la cola")
    XCTAssertEqual(marca.ultimoDiaEnviado, "2026-10-10", "La marca no se mueve")

    // La persona acepta: el día sale solo.
    let despues = await reintentar(.success(true))

    XCTAssertEqual(despues, .completa)
    XCTAssertEqual(cola.pendientes(), [])
  }

  func testComoPermanente_ElMismoDiaSiSePerdia() async {
    // Contraste: así se portaba el 403 antes del cambio (cualquier permanente).
    marca.registrarEnviado("2026-10-10")
    cola.encolar(fecha: "2026-10-08")

    let fin = await reintentar(.failure(ApiError.servidor(codigo: 403, cuerpo: "{}")))

    XCTAssertEqual(fin, .cortadaPorRechazo)
    XCTAssertEqual(cola.pendientes(), [], "Un 403 permanente saca el día de la cola")
  }

  func testLaVueltaSeCortaDeUnaVezComoConElToken() async {
    var intentados: [String] = []
    let fin = await RecorridoDias.recorrer(
      ["d1", "d2", "d3"],
      enviar: { dia in
        intentados.append(dia)
        throw ApiError.consentimientoRequerido
      },
      registrar: { _, _ in }
    )

    XCTAssertEqual(intentados, ["d1"], "Si el primero falla por el consentimiento, los demás también")
    XCTAssertEqual(fin, .cortadaPorFalloGeneral)
  }

  func testConElConsentimientoPendiente_LaMarcaNoAvanza_YLosDiasSiguenAhi() async {
    // Primera vez, sin marca: los últimos 7 días siguen siendo los candidatos
    // aunque el servidor rechace todos los envíos.
    let antes = marca.diasPorMandar()

    _ = await RecorridoDias.recorrer(
      antes,
      enviar: { _ in throw ApiError.consentimientoRequerido },
      registrar: { dia, desenlace in
        self.cola.aplicar(desenlace.efectoAlPonerseAlDia, a: dia)
        if desenlace.avanzaMarca { self.marca.registrarEnviado(dia) }
      }
    )

    XCTAssertNil(marca.ultimoDiaEnviado)
    XCTAssertEqual(marca.diasPorMandar(), antes, "Cuando acepte, se mandan los mismos días")
  }
}
