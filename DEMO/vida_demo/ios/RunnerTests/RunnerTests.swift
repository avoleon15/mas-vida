import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
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
