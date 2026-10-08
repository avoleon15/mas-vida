import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'healthkit_bridge.dart';

import 'cliente_api.dart';

// ============================================================
// LA SESIÓN DEL USUARIO: QUIÉN ENTRÓ Y CON QUÉ TOKEN.
//
// Tres piezas, de abajo hacia arriba:
//   · [Sesion]          → lo que se sabe del que entró.
//   · [AlmacenSesion]   → dónde queda guardada entre arranques. Va en el
//                         llavero de iOS (flutter_secure_storage) y no en
//                         SharedPreferences: el token abre la cuenta
//                         entera, y CLAUDE.md pide almacenamiento seguro.
//   · [ServicioSesion]  → entrar, crear cuenta, recuperar la contraseña
//                         y salir. Hay dos: el local (hoy, sin backend) y
//                         el de la API. Cuál se usa lo decide
//                         `fuente_datos.dart`, igual que con los datos.
// ============================================================

/// Versión del texto de términos que se acepta al crear la cuenta.
///
/// Se guarda con la sesión para saber QUÉ texto aceptó cada quien: el
/// día que cambie, hay que volver a pedirlo.
const String versionTerminos = '2026-09-30';

/// Si quien usa la app tiene su póliza verificada.
///
/// Sin ella la app se ve COMPLETA —puntos, nivel, monedas, objetivos y
/// sus competencias— pero no puede canjear premios ni entrar a La Liga,
/// y Mi Plan solo ofrece agregar la póliza o buscar un plan ("gratis para
/// jugar, pago para los beneficios", CLAUDE.md). Póliza pendiente de
/// verificación cuenta como sin póliza: no hay un tercer estado.
///
/// Arranca en true para que los tests y las pantallas sueltas se vean
/// como siempre; el arranque lo ajusta a la sesión que entró.
final ValueNotifier<bool> tienePoliza = ValueNotifier<bool>(true);

/// El usuario que entró.
class Sesion {
  const Sesion({
    required this.token,
    required this.correo,
    required this.nombre,
    this.fechaNacimiento,
    this.polizaPendiente = false,
    this.sinPoliza = false,
    this.poliza,
    this.empiezaDeCero = false,
    this.compartirConAseguradora = false,
    this.terminosAceptados,
    this.esPrueba = false,
  });

  /// Lo que se manda en cada request (`Authorization: Token ...`).
  final String token;
  final String correo;
  final String nombre;

  /// Autoreportada en el registro. Con ella el servidor calcula la FCmáx
  /// desde el primer día; la aseguradora la confirma al vincular la
  /// póliza. Null en las sesiones que entraron con correo y contraseña y
  /// todavía no la trajeron del servidor.
  final DateTime? fechaNacimiento;

  /// Cargó una póliza que la aseguradora todavía no verificó. Para la UI
  /// es exactamente lo mismo que no tener póliza (CLAUDE.md): no hay un
  /// tercer estado visual.
  final bool polizaPendiente;

  /// Eligió "Aún no tengo póliza" al crear la cuenta y todavía no agregó
  /// ninguna.
  final bool sinPoliza;

  /// Tiene la póliza vinculada y verificada: puede canjear y entra a La
  /// Liga.
  bool get polizaVerificada => !sinPoliza && !polizaPendiente;

  /// La póliza que escribió al crear la cuenta o al agregarla después.
  /// Mientras no haya backend, es lo que llena Mi Plan y Perfil encima de
  /// los datos de prueba (ver `usarSesion` en `fuente_datos.dart`).
  final PolizaRegistro? poliza;

  /// Agregó la póliza DESPUÉS de jugar sin ella: sus puntos del año y su
  /// nivel de cashback arrancan en cero con la póliza (Daniel, 8 de
  /// octubre de 2026). Lo de la cuenta base no cuenta para la póliza.
  final bool empiezaDeCero;

  /// Dio el consentimiento aparte para compartir el resumen diario con
  /// la aseguradora. Revocable.
  final bool compartirConAseguradora;

  /// Qué versión de los términos aceptó. Null en el acceso de prueba.
  final String? terminosAceptados;

  /// Entró con "Acceder por prueba", sin cuenta.
  final bool esPrueba;

  Map<String, dynamic> toJson() => {
    'token': token,
    'correo': correo,
    'nombre': nombre,
    if (fechaNacimiento != null)
      'fecha_nacimiento': fechaNacimiento!.toIso8601String(),
    'poliza_pendiente': polizaPendiente,
    'sin_poliza': sinPoliza,
    if (poliza != null) 'poliza': poliza!.toJson(),
    'empieza_de_cero': empiezaDeCero,
    'compartir_con_aseguradora': compartirConAseguradora,
    if (terminosAceptados != null) 'terminos_aceptados': terminosAceptados,
    'es_prueba': esPrueba,
  };

  factory Sesion.desdeJson(Map<String, dynamic> j) => Sesion(
    token: j['token'] as String,
    correo: j['correo'] as String,
    nombre: j['nombre'] as String,
    fechaNacimiento: j['fecha_nacimiento'] == null
        ? null
        : DateTime.parse(j['fecha_nacimiento'] as String),
    polizaPendiente: j['poliza_pendiente'] as bool? ?? false,
    sinPoliza: j['sin_poliza'] as bool? ?? false,
    poliza: j['poliza'] == null
        ? null
        : PolizaRegistro.desdeJson(j['poliza'] as Map<String, dynamic>),
    empiezaDeCero: j['empieza_de_cero'] as bool? ?? false,
    compartirConAseguradora: j['compartir_con_aseguradora'] as bool? ?? false,
    terminosAceptados: j['terminos_aceptados'] as String?,
    esPrueba: j['es_prueba'] as bool? ?? false,
  );

  /// La misma sesión con la póliza recién agregada. Quien la agrega
  /// después de jugar sin ella empieza de cero.
  Sesion conPoliza(
    PolizaRegistro poliza, {
    required bool pendiente,
    required bool compartirConAseguradora,
  }) => Sesion(
    token: token,
    correo: correo,
    nombre: nombre,
    fechaNacimiento: fechaNacimiento,
    polizaPendiente: pendiente,
    poliza: poliza,
    empiezaDeCero: sinPoliza || empiezaDeCero,
    compartirConAseguradora: compartirConAseguradora,
    terminosAceptados: terminosAceptados,
    esPrueba: esPrueba,
  );
}

/// La póliza que se carga en el registro. Queda pendiente hasta que la
/// aseguradora la verifica.
class PolizaRegistro {
  const PolizaRegistro({
    required this.aseguradora,
    required this.numero,
    required this.inicioVigencia,
  });

  final String aseguradora;
  final String numero;
  final DateTime inicioVigencia;

  Map<String, dynamic> toJson() => {
    'aseguradora': aseguradora,
    'numero': numero,
    'inicio_vigencia': inicioVigencia.toIso8601String(),
  };

  factory PolizaRegistro.desdeJson(Map<String, dynamic> j) => PolizaRegistro(
    aseguradora: j['aseguradora'] as String,
    numero: j['numero'] as String,
    inicioVigencia: DateTime.parse(j['inicio_vigencia'] as String),
  );
}

/// Todo lo que junta el registro antes de crear la cuenta.
class DatosRegistro {
  const DatosRegistro({
    required this.nombre,
    required this.correo,
    required this.contrasena,
    required this.fechaNacimiento,
    this.poliza,
    this.compartirConAseguradora = false,
  });

  final String nombre;
  final String correo;
  final String contrasena;
  final DateTime fechaNacimiento;

  /// Null si eligió "Aún no tengo póliza": la cuenta base funciona sin
  /// ella.
  final PolizaRegistro? poliza;

  final bool compartirConAseguradora;
}

/// Un error que se le puede mostrar al usuario tal cual.
class ErrorSesion implements Exception {
  const ErrorSesion(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'ErrorSesion: $mensaje';
}

/// Guarda la sesión en el llavero del teléfono.
///
/// Si el llavero falla (una plataforma sin soporte, un test sin mock),
/// se comporta como si no hubiera sesión: es preferible pedir el ingreso
/// otra vez que trabar el arranque.
///
/// HAY DOS COPIAS DEL TOKEN y se mueven siempre juntas: la de Flutter
/// (para sus llamadas HTTP) y la de Swift (para firmar el `sync`), que se
/// le entrega con `actualizarSesion` (contrato, "MethodChannel"). Guardar
/// le pasa el token a Swift, borrar le pasa null, y leer —que es lo que
/// pasa al abrir la app— le vuelve a mandar lo que haya.
class AlmacenSesion {
  AlmacenSesion({FlutterSecureStorage? llavero, HealthKitBridge? puente})
    : _llavero = llavero ?? const FlutterSecureStorage(),
      _puente = puente ?? HealthKitBridge();

  static const _clave = 'sesion';

  final FlutterSecureStorage _llavero;
  final HealthKitBridge _puente;

  Future<Sesion?> leer() async {
    Sesion? sesion;
    try {
      final texto = await _llavero.read(key: _clave);
      if (texto != null) {
        sesion = Sesion.desdeJson(jsonDecode(texto) as Map<String, dynamic>);
      }
    } catch (_) {
      sesion = null;
    }
    // Al abrir la app: Swift recibe el token de ahora, o null.
    _avisarASwift(sesion?.token);
    return sesion;
  }

  Future<void> guardar(Sesion sesion) async {
    try {
      await _llavero.write(key: _clave, value: jsonEncode(sesion.toJson()));
    } catch (_) {
      // Sin llavero la sesión dura lo que dure la app abierta.
    }
    _avisarASwift(sesion.token);
  }

  Future<void> borrar() async {
    try {
      await _llavero.delete(key: _clave);
    } catch (_) {}
    // Al cerrar sesión se borran LAS DOS copias.
    _avisarASwift(null);
  }

  /// Sin esperar la respuesta: entrar o salir no puede quedar colgado de
  /// Swift. Si el Keychain falla, el próximo arranque lo vuelve a mandar
  /// (la llamada es idempotente).
  void _avisarASwift(String? token) =>
      unawaited(_puente.actualizarSesion(token));
}

/// Entrar, crear cuenta, recuperar la contraseña y salir.
abstract class ServicioSesion {
  ServicioSesion({AlmacenSesion? almacen})
    : almacen = almacen ?? AlmacenSesion();

  final AlmacenSesion almacen;

  /// La sesión guardada del arranque anterior, o null si hay que entrar.
  Future<Sesion?> actual() => almacen.leer();

  Future<Sesion> iniciarSesion(String correo, String contrasena);

  Future<Sesion> registrar(DatosRegistro datos);

  /// Agrega la póliza a una cuenta que entró sin ella (desde Mi Plan,
  /// Premios o Social).
  Future<Sesion> vincularPoliza(
    Sesion sesion,
    PolizaRegistro poliza, {
    bool compartirConAseguradora = false,
  });

  /// Manda el enlace para crear una contraseña nueva. No dice si el
  /// correo tiene cuenta o no: eso le serviría a alguien para averiguar
  /// quién usa la app.
  Future<void> recuperarContrasena(String correo);

  /// Entra sin cuenta, para las pruebas del equipo. Se saca antes del
  /// piloto (ver `mostrarAccesoDePrueba` en `acceso_screen.dart`).
  Future<Sesion> accederPorPrueba() async {
    const sesion = Sesion(
      token: 'prueba',
      correo: 'prueba@masvida.gt',
      nombre: 'Prueba',
      esPrueba: true,
    );
    await almacen.guardar(sesion);
    return sesion;
  }

  Future<void> cerrarSesion() => almacen.borrar();
}

/// Las cuentas creadas en ESTE teléfono, mientras no haya backend.
///
/// Es lo que hace que el ingreso se sienta real: quien creó su cuenta y
/// después cerró sesión vuelve a entrar con su correo y su contraseña, y
/// la app lo saluda con SU nombre y recuerda si tiene póliza, en vez de
/// inventar un nombre a partir del correo.
///
/// Vive en el llavero de iOS, igual que la sesión. OJO: guarda la
/// contraseña tal cual, porque no hay servidor que la verifique. Es un
/// reemplazo de prueba y se borra el día que el ingreso hable con la API.
class AlmacenCuentasLocales {
  AlmacenCuentasLocales({FlutterSecureStorage? llavero})
    : _llavero = llavero ?? const FlutterSecureStorage();

  static const _clave = 'cuentas_locales';

  final FlutterSecureStorage _llavero;

  /// Las cuentas por correo, en minúsculas.
  Future<Map<String, Map<String, dynamic>>> leer() async {
    try {
      final texto = await _llavero.read(key: _clave);
      if (texto == null) return {};
      final datos = jsonDecode(texto) as Map<String, dynamic>;
      return datos.map((k, v) => MapEntry(k, v as Map<String, dynamic>));
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>?> buscar(String correo) async =>
      (await leer())[_llave(correo)];

  Future<void> guardar(String correo, Map<String, dynamic> cuenta) async {
    final cuentas = await leer();
    cuentas[_llave(correo)] = cuenta;
    try {
      await _llavero.write(key: _clave, value: jsonEncode(cuentas));
    } catch (_) {
      // Sin llavero, la cuenta dura lo que dure la app abierta.
    }
  }

  static String _llave(String correo) => correo.trim().toLowerCase();
}

/// Sesión sin backend: las cuentas viven en el teléfono
/// ([AlmacenCuentasLocales]).
///
/// Crear una cuenta la guarda; entrar pide un correo que ya tenga cuenta
/// y su contraseña, y devuelve la sesión con el nombre, la fecha de
/// nacimiento y la póliza de esa cuenta. NO es una cuenta de verdad: no
/// sale del teléfono.
class ServicioSesionLocal extends ServicioSesion {
  ServicioSesionLocal({
    super.almacen,
    AlmacenCuentasLocales? cuentas,
    this.demora = const Duration(milliseconds: 700),
  }) : cuentas = cuentas ?? AlmacenCuentasLocales();

  final AlmacenCuentasLocales cuentas;

  /// Lo que tarda cada operación. Sin ella el botón pasaría de "Entrar" a
  /// la pantalla siguiente sin que se alcance a ver que algo pasó.
  final Duration demora;

  String _token() => 'local-${DateTime.now().millisecondsSinceEpoch}';

  @override
  Future<Sesion> iniciarSesion(String correo, String contrasena) async {
    await Future<void>.delayed(demora);
    final cuenta = await cuentas.buscar(correo);
    if (cuenta == null) {
      throw const ErrorSesion(
        'No encontramos una cuenta con ese correo. Revisa cómo lo '
        'escribiste o crea tu cuenta.',
      );
    }
    if (cuenta['contrasena'] != contrasena) {
      throw const ErrorSesion(
        'El correo o la contraseña no coinciden. Revísalos e intenta de '
        'nuevo.',
      );
    }
    final sesion = Sesion.desdeJson({
      ...cuenta,
      'token': _token(),
      'correo': correo.trim(),
    });
    await almacen.guardar(sesion);
    return sesion;
  }

  @override
  Future<Sesion> registrar(DatosRegistro datos) async {
    await Future<void>.delayed(demora);
    if (await cuentas.buscar(datos.correo) != null) {
      throw const ErrorSesion(
        'Ya hay una cuenta con ese correo. Entra con tu contraseña.',
      );
    }
    final sesion = Sesion(
      token: _token(),
      correo: datos.correo,
      nombre: datos.nombre,
      fechaNacimiento: datos.fechaNacimiento,
      // Sin backend no hay aseguradora que la revise: la póliza que se
      // carga queda verificada de una, para que el flujo se pueda
      // recorrer entero. El servicio de la API sí la deja pendiente.
      sinPoliza: datos.poliza == null,
      poliza: datos.poliza,
      compartirConAseguradora: datos.compartirConAseguradora,
      terminosAceptados: versionTerminos,
    );
    await cuentas.guardar(datos.correo, _cuenta(sesion, datos.contrasena));
    await almacen.guardar(sesion);
    return sesion;
  }

  @override
  Future<Sesion> vincularPoliza(
    Sesion sesion,
    PolizaRegistro poliza, {
    bool compartirConAseguradora = false,
  }) async {
    await Future<void>.delayed(demora);
    // Verificada de una, igual que en el registro (ver arriba).
    final nueva = sesion.conPoliza(
      poliza,
      pendiente: false,
      compartirConAseguradora: compartirConAseguradora,
    );
    // La cuenta también la recuerda: al volver a entrar ya tiene póliza.
    final cuenta = await cuentas.buscar(sesion.correo);
    if (cuenta != null) {
      await cuentas.guardar(
        sesion.correo,
        _cuenta(nueva, cuenta['contrasena'] as String),
      );
    }
    await almacen.guardar(nueva);
    return nueva;
  }

  /// Lo que se guarda de una cuenta: todo lo de la sesión menos el token,
  /// más la contraseña.
  Map<String, dynamic> _cuenta(Sesion sesion, String contrasena) =>
      {...sesion.toJson(), 'contrasena': contrasena}..remove('token');

  @override
  Future<void> recuperarContrasena(String correo) =>
      Future<void>.delayed(demora);
}

/// Sesión contra la API de Django.
///
/// OJO, lo que falta del lado del servidor antes de poder usarla:
///   · `POST /api/v1/registro` pide la póliza como obligatoria
///     (`policy_number`, `insurer`, `policy_start_date`). Según
///     `arquitectura-cuentas-vivo.md` la cuenta base va sin póliza y
///     vincularla es un paso aparte: hay que volverlos opcionales.
///   · Pide también `usuario_id`. Lo debería generar el servidor; hasta
///     entonces se manda uno armado acá.
///   · No existe el endpoint para recuperar la contraseña.
///   · No existe el endpoint para vincular la póliza a una cuenta que ya
///     existe.
///   · No hay dónde guardar los consentimientos (términos y aseguradora).
class ServicioSesionApi extends ServicioSesion {
  ServicioSesionApi({required this.cliente, super.almacen});

  final ClienteApi cliente;

  @override
  Future<Sesion?> actual() async {
    final sesion = await super.actual();
    if (sesion != null) cliente.token = sesion.token;
    return sesion;
  }

  @override
  Future<Sesion> iniciarSesion(String correo, String contrasena) async {
    try {
      final token = await cliente.iniciarSesion(correo, contrasena);
      final sesion = Sesion(
        token: token,
        correo: correo,
        nombre: nombreDesdeCorreo(correo),
      );
      await almacen.guardar(sesion);
      return sesion;
    } on ErrorApi {
      throw const ErrorSesion(
        'El correo o la contraseña no coinciden. Revísalos e intenta de '
        'nuevo.',
      );
    } catch (_) {
      throw const ErrorSesion(
        'No pudimos conectarnos. Revisa tu internet e intenta de nuevo.',
      );
    }
  }

  @override
  Future<Sesion> registrar(DatosRegistro datos) async {
    try {
      final token = await cliente.registrar(
        correo: datos.correo,
        contrasena: datos.contrasena,
        usuarioId: 'app-${DateTime.now().microsecondsSinceEpoch}',
        fechaNacimiento: datos.fechaNacimiento,
        numeroPoliza: datos.poliza?.numero,
        aseguradora: datos.poliza?.aseguradora,
        inicioVigencia: datos.poliza?.inicioVigencia,
      );
      final sesion = Sesion(
        token: token,
        correo: datos.correo,
        nombre: datos.nombre,
        fechaNacimiento: datos.fechaNacimiento,
        polizaPendiente: datos.poliza != null,
        sinPoliza: datos.poliza == null,
        poliza: datos.poliza,
        compartirConAseguradora: datos.compartirConAseguradora,
        terminosAceptados: versionTerminos,
      );
      await almacen.guardar(sesion);
      return sesion;
    } on ErrorApi catch (e) {
      throw ErrorSesion(e.mensaje);
    } catch (_) {
      throw const ErrorSesion(
        'No pudimos conectarnos. Revisa tu internet e intenta de nuevo.',
      );
    }
  }

  @override
  Future<void> recuperarContrasena(String correo) async {
    throw const ErrorSesion(
      'Todavía no podemos mandarte el enlace desde la app. Intenta más '
      'tarde.',
    );
  }

  /// OJO: el servidor todavía no tiene el endpoint para vincular la
  /// póliza a una cuenta que ya existe (ver la nota de la clase).
  @override
  Future<Sesion> vincularPoliza(
    Sesion sesion,
    PolizaRegistro poliza, {
    bool compartirConAseguradora = false,
  }) async {
    throw const ErrorSesion(
      'Todavía no podemos agregar tu póliza desde la app. Intenta más '
      'tarde.',
    );
  }

  @override
  Future<void> cerrarSesion() async {
    cliente.token = null;
    await super.cerrarSesion();
  }
}

/// "ana.lopez@gmail.com" → "Ana". Para saludar a alguien que entró con
/// correo y contraseña cuando el servidor todavía no manda el nombre.
String nombreDesdeCorreo(String correo) {
  final usuario = correo.split('@').first.split(RegExp(r'[._\-+0-9]')).first;
  if (usuario.isEmpty) return '';
  return usuario[0].toUpperCase() + usuario.substring(1).toLowerCase();
}
