import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente HTTP contra la API de Django (`mas-vida_backend/`).
///
/// Por ahora habla con tres endpoints, los que ya funcionan de punta a
/// punta:
///   - `POST /api/v1/registro`  → crea la cuenta y abre una sesión.
///   - `POST /api/v1/login`     → abre una sesión.
///   - `POST /api/v1/logout`    → cierra la sesión de este teléfono.
///   - `GET  /api/v1/historial` → los puntos acreditados día por día.
///
/// Cada login trae un token nuevo que vence a los 30 días sin uso (90 como
/// máximo). Cualquier `401` con token avisa a [alRechazarToken]: la sesión
/// venció o la cerraron desde otro lado, y hay que volver a entrar.
///
/// Todavía NO lo usa ninguna pantalla del producto: la app sigue leyendo
/// del mock (ver `fuente_datos.dart`). Lo que devuelve el historial del
/// backend es una lista de días con sus puntos, y el `Historial` que
/// dibujan las pantallas trae además semanas, entrenamientos y racha;
/// hasta que esa forma se acuerde con Luis, esto se prueba desde
/// `lib/debug/prueba_historial.dart`.
class ClienteApi {
  ClienteApi({required this.baseUrl, http.Client? cliente})
    : _http = cliente ?? http.Client();

  /// Dónde corre el backend, sin barra al final. En la compu de uno:
  /// `http://127.0.0.1:8000`.
  final String baseUrl;

  final http.Client _http;

  /// El token del usuario que inició sesión. Null hasta [iniciarSesion].
  ///
  /// Solo vive en memoria: para la app real va en almacenamiento seguro
  /// (CLAUDE.md, "Token en almacenamiento seguro").
  String? token;

  /// Se llama cuando el servidor rechaza un token con `401`, con el token
  /// que se mandó. Quien la recibe decide si cerrar la sesión: puede que
  /// ya haya entrado de nuevo con otro token mientras esta llamada volvía.
  void Function(String tokenRechazado)? alRechazarToken;

  /// Abre una sesión con usuario y contraseña, y guarda el token en [token].
  Future<InicioDeSesion> iniciarSesion(
    String usuario,
    String contrasena,
  ) async {
    final respuesta = await _http.post(
      Uri.parse('$baseUrl/api/v1/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': usuario, 'password': contrasena}),
    );
    if (respuesta.statusCode != 200) {
      throw ErrorApi(
        respuesta.statusCode,
        'No se pudo iniciar sesión. Revisa el usuario y la contraseña.',
      );
    }
    final inicio = InicioDeSesion.desdeJson(
      jsonDecode(respuesta.body) as Map<String, dynamic>,
    );
    token = inicio.token;
    return inicio;
  }

  /// Cierra la sesión de este teléfono en el servidor (los demás siguen).
  ///
  /// Nunca falla hacia afuera y no espera más de unos segundos: cerrar
  /// sesión no puede quedar trabado por la red. Si no llega, el token sigue
  /// vivo en el servidor hasta que venza. Devuelve si el servidor lo cerró.
  Future<bool> cerrarSesionEnServidor() async {
    final token = this.token;
    if (token == null) return false;
    try {
      final respuesta = await _http
          .post(
            Uri.parse('$baseUrl/api/v1/logout'),
            headers: {'Authorization': 'Token $token'},
          )
          .timeout(const Duration(seconds: 5));
      return respuesta.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Crea la cuenta y guarda el token que devuelve en [token].
  ///
  /// El correo va como `username`: el backend usa el `User` de Django,
  /// y así el login de después es con el mismo correo.
  ///
  /// El `usuario_id` lo genera el servidor y llega en la respuesta. La
  /// póliza va aparte (`polizas/vincular`); el registro hoy la ignora.
  Future<InicioDeSesion> registrar({
    required String correo,
    required String contrasena,
    required DateTime fechaNacimiento,
    String? numeroPoliza,
    String? aseguradora,
    DateTime? inicioVigencia,
  }) async {
    final respuesta = await _http.post(
      Uri.parse('$baseUrl/api/v1/registro'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': correo,
        'password': contrasena,
        'birth_date': _soloFecha(fechaNacimiento),
        'policy_number': ?numeroPoliza,
        'insurer': ?aseguradora,
        if (inicioVigencia != null)
          'policy_start_date': _soloFecha(inicioVigencia),
      }),
    );
    final cuerpo = respuesta.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
    if (respuesta.statusCode != 201) {
      throw ErrorApi(respuesta.statusCode, _primerError(cuerpo));
    }
    final inicio = InicioDeSesion.desdeJson(cuerpo);
    token = inicio.token;
    return inicio;
  }

  /// El primer mensaje de un 400 de DRF, que llega como
  /// `{"campo": ["mensaje", ...]}`.
  static String _primerError(Map<String, dynamic> cuerpo) {
    for (final valor in cuerpo.values) {
      if (valor is List && valor.isNotEmpty) return valor.first.toString();
      if (valor is String) return valor;
    }
    return 'No pudimos crear tu cuenta. Intenta de nuevo.';
  }

  /// Los puntos de cada día, del más nuevo al más viejo.
  ///
  /// [desde] y [hasta] son opcionales y entran los dos extremos. Solo se
  /// manda la fecha, sin hora: el día lo decide el servidor en hora de
  /// Guatemala.
  Future<List<PuntosDelDia>> historialDePuntos({
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final token = this.token;
    if (token == null) {
      throw const ErrorApi(401, 'Primero hay que iniciar sesión.');
    }
    final filtros = {
      if (desde != null) 'fecha_desde': _soloFecha(desde),
      if (hasta != null) 'fecha_hasta': _soloFecha(hasta),
    };
    // Sin filtros no se pasa queryParameters: con un mapa vacío la URL
    // sale con un "?" colgando al final.
    final base = Uri.parse('$baseUrl/api/v1/historial');
    final uri = filtros.isEmpty ? base : base.replace(queryParameters: filtros);
    final respuesta = await _http.get(
      uri,
      headers: {'Authorization': 'Token $token'},
    );
    if (respuesta.statusCode == 401) alRechazarToken?.call(token);
    final cuerpo = respuesta.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
    if (respuesta.statusCode != 200) {
      throw ErrorApi(
        respuesta.statusCode,
        cuerpo['mensaje'] as String? ??
            cuerpo['detail'] as String? ??
            'El servidor respondió ${respuesta.statusCode}.',
      );
    }
    return [
      for (final dia in cuerpo['historial'] as List)
        PuntosDelDia.desdeJson(dia as Map<String, dynamic>),
    ];
  }

  static String _soloFecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Lo que devuelven el login y el registro.
class InicioDeSesion {
  const InicioDeSesion({required this.token, this.usuarioId});

  final String token;

  /// El nombre público que genera el servidor. Se le pasa a Swift para que
  /// sepa si entró otra persona. Null solo en cuentas sin perfil.
  final String? usuarioId;

  factory InicioDeSesion.desdeJson(Map<String, dynamic> j) => InicioDeSesion(
    token: j['token'] as String,
    usuarioId: j['usuario_id'] as String?,
  );
}

/// Un día del historial de puntos, tal como lo manda el backend.
class PuntosDelDia {
  const PuntosDelDia({
    required this.fecha,
    required this.puntosPasos,
    required this.puntosIntensidad,
    required this.puntosBrutos,
    required this.puntosDia,
    required this.topeDiarioAplicado,
    required this.versionRegla,
  });

  final DateTime fecha;
  final int puntosPasos;
  final int puntosIntensidad;

  /// Pasos + intensidad, antes del tope diario de 200.
  final int puntosBrutos;

  /// Lo que se acreditó de verdad ese día. Nunca pasa de 200.
  final int puntosDia;

  /// True solo si los brutos pasaron de 200. Llegar a 200 justos no es
  /// un recorte.
  final bool topeDiarioAplicado;

  /// Con qué versión de las reglas se calculó.
  final int versionRegla;

  factory PuntosDelDia.desdeJson(Map<String, dynamic> j) => PuntosDelDia(
    fecha: DateTime.parse(j['fecha'] as String),
    puntosPasos: (j['puntos_pasos'] as num).toInt(),
    puntosIntensidad: (j['puntos_intensidad'] as num).toInt(),
    puntosBrutos: (j['puntos_brutos'] as num).toInt(),
    puntosDia: (j['puntos_dia'] as num).toInt(),
    topeDiarioAplicado: j['tope_diario_aplicado'] as bool,
    versionRegla: (j['version_regla'] as num).toInt(),
  );
}

/// Un error que vino del servidor, con su código HTTP y un texto que se
/// puede mostrar.
class ErrorApi implements Exception {
  const ErrorApi(this.codigo, this.mensaje);

  final int codigo;
  final String mensaje;

  @override
  String toString() => 'ErrorApi($codigo): $mensaje';
}
