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

/// El usuario que entró.
class Sesion {
  const Sesion({
    required this.token,
    required this.correo,
    required this.nombre,
    this.usuarioId,
    this.fechaNacimiento,
    this.polizaPendiente = false,
    this.compartirConAseguradora = false,
    this.terminosAceptados,
    this.esPrueba = false,
  });

  /// Lo que se manda en cada request (`Authorization: Token ...`).
  final String token;
  final String correo;
  final String nombre;

  /// El nombre público que generó el servidor (login y registro). Swift lo
  /// usa para saber si entró otra persona. Null en las sesiones locales y
  /// en las guardadas antes de A35.
  final String? usuarioId;

  /// Autoreportada en el registro. Con ella el servidor calcula la FCmáx
  /// desde el primer día; la aseguradora la confirma al vincular la
  /// póliza. Null en las sesiones que entraron con correo y contraseña y
  /// todavía no la trajeron del servidor.
  final DateTime? fechaNacimiento;

  /// Cargó una póliza que la aseguradora todavía no verificó. Para la UI
  /// es exactamente lo mismo que no tener póliza (CLAUDE.md): no hay un
  /// tercer estado visual.
  final bool polizaPendiente;

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
    if (usuarioId != null) 'usuario_id': usuarioId,
    if (fechaNacimiento != null)
      'fecha_nacimiento': fechaNacimiento!.toIso8601String(),
    'poliza_pendiente': polizaPendiente,
    'compartir_con_aseguradora': compartirConAseguradora,
    if (terminosAceptados != null) 'terminos_aceptados': terminosAceptados,
    'es_prueba': esPrueba,
  };

  factory Sesion.desdeJson(Map<String, dynamic> j) => Sesion(
    token: j['token'] as String,
    correo: j['correo'] as String,
    nombre: j['nombre'] as String,
    usuarioId: j['usuario_id'] as String?,
    fechaNacimiento: j['fecha_nacimiento'] == null
        ? null
        : DateTime.parse(j['fecha_nacimiento'] as String),
    polizaPendiente: j['poliza_pendiente'] as bool? ?? false,
    compartirConAseguradora: j['compartir_con_aseguradora'] as bool? ?? false,
    terminosAceptados: j['terminos_aceptados'] as String?,
    esPrueba: j['es_prueba'] as bool? ?? false,
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

  /// Null si eligió "Lo hago después": la cuenta base funciona sin póliza.
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
    _avisarASwift(sesion);
    return sesion;
  }

  Future<void> guardar(Sesion sesion) async {
    try {
      await _llavero.write(key: _clave, value: jsonEncode(sesion.toJson()));
    } catch (_) {
      // Sin llavero la sesión dura lo que dure la app abierta.
    }
    _avisarASwift(sesion);
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
  void _avisarASwift(Sesion? sesion) => unawaited(
    _puente.actualizarSesion(sesion?.token, usuarioId: sesion?.usuarioId),
  );
}

/// Sube en uno cada vez que el servidor rechaza la sesión (`401`): venció
/// (30 días sin uso, o 90 desde que se entró) o se cerró desde otro lado.
/// Para entonces la sesión ya se borró; `main.dart` escucha esto y vuelve al
/// arranque, que muestra el ingreso.
final ValueNotifier<int> sesionRechazada = ValueNotifier<int>(0);

/// Entrar, crear cuenta, recuperar la contraseña y salir.
abstract class ServicioSesion {
  ServicioSesion({AlmacenSesion? almacen})
    : almacen = almacen ?? AlmacenSesion();

  final AlmacenSesion almacen;

  /// La sesión guardada del arranque anterior, o null si hay que entrar.
  Future<Sesion?> actual() => almacen.leer();

  Future<Sesion> iniciarSesion(String correo, String contrasena);

  Future<Sesion> registrar(DatosRegistro datos);

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

/// Sesión sin backend: acepta cualquier correo y contraseña bien
/// formados y guarda la sesión en el teléfono.
///
/// Existe para que el flujo completo se pueda recorrer hoy, mientras el
/// login de la app no habla con el servidor. No valida contra nada: NO
/// es una cuenta de verdad.
class ServicioSesionLocal extends ServicioSesion {
  ServicioSesionLocal({
    super.almacen,
    this.demora = const Duration(milliseconds: 700),
  });

  /// Lo que tarda cada operación. Sin ella el botón pasaría de "Entrar" a
  /// la pantalla siguiente sin que se alcance a ver que algo pasó.
  final Duration demora;

  @override
  Future<Sesion> iniciarSesion(String correo, String contrasena) async {
    await Future<void>.delayed(demora);
    final sesion = Sesion(
      token: 'local-${DateTime.now().millisecondsSinceEpoch}',
      correo: correo,
      nombre: nombreDesdeCorreo(correo),
    );
    await almacen.guardar(sesion);
    return sesion;
  }

  @override
  Future<Sesion> registrar(DatosRegistro datos) async {
    await Future<void>.delayed(demora);
    final sesion = Sesion(
      token: 'local-${DateTime.now().millisecondsSinceEpoch}',
      correo: datos.correo,
      nombre: datos.nombre,
      fechaNacimiento: datos.fechaNacimiento,
      polizaPendiente: datos.poliza != null,
      compartirConAseguradora: datos.compartirConAseguradora,
      terminosAceptados: versionTerminos,
    );
    await almacen.guardar(sesion);
    return sesion;
  }

  @override
  Future<void> recuperarContrasena(String correo) =>
      Future<void>.delayed(demora);
}

/// Sesión contra la API de Django.
///
/// Cualquier `401` del servidor cierra la sesión y avisa en
/// [sesionRechazada] (contrato, "Qué hacen las apps").
///
/// OJO, lo que falta del lado del servidor antes de poder usarla:
///   · La póliza del registro se ignora: va aparte, con `polizas/vincular`.
///   · No existe el endpoint para recuperar la contraseña.
///   · No hay dónde guardar los consentimientos (términos y aseguradora).
class ServicioSesionApi extends ServicioSesion {
  ServicioSesionApi({required this.cliente, super.almacen}) {
    cliente.alRechazarToken = _alRechazarToken;
  }

  final ClienteApi cliente;

  /// El servidor rechazó [rechazado]. Si sigue siendo el de la sesión, se
  /// cierra; si no, es la respuesta tardía de una sesión anterior y la de
  /// ahora no se toca.
  Future<void> _alRechazarToken(String rechazado) async {
    if (cliente.token != rechazado) return;
    cliente.token = null;
    await almacen.borrar();
    sesionRechazada.value++;
  }

  @override
  Future<Sesion?> actual() async {
    final sesion = await super.actual();
    if (sesion != null) cliente.token = sesion.token;
    return sesion;
  }

  @override
  Future<Sesion> iniciarSesion(String correo, String contrasena) async {
    try {
      final inicio = await cliente.iniciarSesion(correo, contrasena);
      final sesion = Sesion(
        token: inicio.token,
        usuarioId: inicio.usuarioId,
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
      final inicio = await cliente.registrar(
        correo: datos.correo,
        contrasena: datos.contrasena,
        fechaNacimiento: datos.fechaNacimiento,
        numeroPoliza: datos.poliza?.numero,
        aseguradora: datos.poliza?.aseguradora,
        inicioVigencia: datos.poliza?.inicioVigencia,
      );
      final sesion = Sesion(
        token: inicio.token,
        usuarioId: inicio.usuarioId,
        correo: datos.correo,
        nombre: datos.nombre,
        fechaNacimiento: datos.fechaNacimiento,
        polizaPendiente: datos.poliza != null,
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

  /// Cierra la sesión de este teléfono en el servidor y después borra las
  /// dos copias locales. Si el servidor no contesta, igual se borran: el
  /// token queda vivo allá hasta que venza.
  @override
  Future<void> cerrarSesion() async {
    await cliente.cerrarSesionEnServidor();
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
