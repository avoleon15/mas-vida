import 'package:flutter/services.dart';

/// Puente hacia el MethodChannel nativo de HealthKit (ver contrato-v3_1.md
/// y AppDelegate.swift). Expone únicamente los 2 métodos del contrato —
/// todo lo demás (dashboard, niveles, retos) es HTTP directo contra la API
/// de Luis, sin pasar por acá.
class HealthKitBridge {
  static const MethodChannel _canal = MethodChannel(
    'com.assures.masvida/healthkit',
  );

  /// Pide permisos de lectura de HealthKit.
  ///
  /// OJO: HealthKit nunca informa si el usuario negó el permiso de lectura —
  /// cuando está negado devuelve datos vacíos, no un error. Y los permisos
  /// son **por tipo**: se puede conceder pasos y negar ritmo cardíaco en el
  /// mismo diálogo. Por eso el resultado trae un [EstadoPermisos] Y un
  /// [TiposVisibles]: el estado dice si la app puede hacer su trabajo base,
  /// los tipos dicen qué se ve realmente.
  Future<ResultadoPermisos> solicitarPermisos() async {
    final respuesta = await _canal.invokeMapMethod<String, dynamic>(
      'solicitarPermisos',
    );
    return ResultadoPermisos(
      estado: EstadoPermisos.desde(respuesta?['estado'] as String?),
      tipos: TiposVisibles.desde(respuesta?['tipos']),
      detalle: respuesta?['detalle'] as String?,
    );
  }

  /// Dispara la sincronización de hoy: el lado nativo lee HealthKit, arma el
  /// payload y hace el POST a /api/v1/sync. Puede tardar (red + lectura de
  /// HealthKit) — mostrar un estado de carga mientras se espera.
  Future<ResultadoSincronizacion> sincronizar() async {
    final respuesta = await _canal.invokeMapMethod<String, dynamic>(
      'sincronizar',
    );
    return ResultadoSincronizacion(
      estado: EstadoSync.desde(respuesta?['estado'] as String?),
      sincronizadoEn: respuesta?['sincronizado_en'] as String?,
      detalle: respuesta?['detalle'] as String?,
    );
  }
}

enum EstadoPermisos {
  /// Se ven pasos: la app puede puntuar. Revisar igual [ResultadoPermisos.tipos]
  /// — puede faltar el ritmo cardíaco, y sin eso no hay puntos por intensidad.
  concedido,

  /// No se ven pasos, que son el piso del puntaje. Puede ser permiso negado, o
  /// un usuario real sin actividad en 30 días — no se pueden distinguir.
  /// Mostrar algo como "No vemos datos de actividad. Si negaste el acceso,
  /// activalo en Ajustes › Salud › +Vida", nunca un "listo".
  sinDatosVisibles,

  /// El dispositivo no soporta HealthKit (iPad, simulador). Caso terminal.
  noDisponible,

  /// Llegó un estado que esta versión de la app no conoce.
  desconocido;

  static EstadoPermisos desde(String? valor) => switch (valor) {
    'concedido' => EstadoPermisos.concedido,
    'sin_datos_visibles' => EstadoPermisos.sinDatosVisibles,
    'no_disponible' => EstadoPermisos.noDisponible,
    _ => EstadoPermisos.desconocido,
  };
}

/// Qué tipos de dato devolvieron algo en los últimos 30 días.
///
/// **La ambigüedad no es igual en los tres.** Con permiso concedido casi
/// cualquier usuario tiene pasos en 30 días, así que `pasos == false` es casi
/// seguro un permiso negado. Pero [ritmoCardiaco] y [entrenamientos] salen del
/// reloj, y la mayoría del piloto no va a tener uno: `false` ahí es "no tiene
/// reloj" mucho más seguido que "negó el permiso".
///
/// Por eso el texto para el usuario tiene que ser condicional, no acusatorio:
/// "No vemos datos de ritmo cardíaco. Si usás un reloj, revisá que +Vida tenga
/// permiso en Ajustes › Salud." Decirle a todo el que no tiene reloj que
/// arregle un permiso sería ruido para casi todos.
class TiposVisibles {
  final bool pasos;

  /// Sin esto no hay sesiones intensas, y por lo tanto no hay puntos por
  /// intensidad — solo por la tabla de pasos.
  final bool ritmoCardiaco;

  final bool entrenamientos;

  const TiposVisibles({
    required this.pasos,
    required this.ritmoCardiaco,
    required this.entrenamientos,
  });

  /// Lo que se asume cuando no vino el mapa: el caso `no_disponible`, donde
  /// nunca se sondeó nada.
  static const ninguno = TiposVisibles(
    pasos: false,
    ritmoCardiaco: false,
    entrenamientos: false,
  );

  /// El nativo garantiza las tres claves siempre presentes cuando manda
  /// `tipos` (las serializa desde `allCases`), así que acá no hay que
  /// distinguir "false" de "no vino la clave".
  static TiposVisibles desde(Object? mapa) {
    if (mapa is! Map) return ninguno;
    return TiposVisibles(
      pasos: mapa['pasos'] == true,
      ritmoCardiaco: mapa['ritmo_cardiaco'] == true,
      entrenamientos: mapa['entrenamientos'] == true,
    );
  }
}

enum EstadoSync {
  /// Llegó a Luis y quedó guardado.
  ok,

  /// No había red o el servidor estaba caído. **No es un error a mostrar como
  /// falla**: el día quedó en la cola local y se reintenta solo al volver del
  /// background. Como mucho, un aviso suave.
  encolado,

  /// No se pudo leer HealthKit — casi siempre permisos. Acá sí hay que
  /// mandar al usuario a Ajustes.
  sinAccesoASalud,

  /// Configuración mal (URL inválida, el backend rechazó el payload). El
  /// usuario no puede hacer nada; esto es para reportar.
  errorPermanente,

  /// Llegó un estado que esta versión de la app no conoce.
  desconocido;

  static EstadoSync desde(String? valor) => switch (valor) {
    'ok' => EstadoSync.ok,
    'encolado' => EstadoSync.encolado,
    'sin_acceso_a_salud' => EstadoSync.sinAccesoASalud,
    'error_permanente' => EstadoSync.errorPermanente,
    _ => EstadoSync.desconocido,
  };
}

class ResultadoPermisos {
  final EstadoPermisos estado;

  /// Qué se ve realmente. En `noDisponible` y `desconocido` es
  /// [TiposVisibles.ninguno], porque nunca se sondeó.
  final TiposVisibles tipos;

  /// Mensaje técnico. Para logs — el texto del usuario sale de [estado].
  final String? detalle;

  const ResultadoPermisos({
    required this.estado,
    required this.tipos,
    this.detalle,
  });
}

class ResultadoSincronizacion {
  final EstadoSync estado;

  /// Timestamp ISO 8601 del envío. Solo viene cuando [estado] es
  /// [EstadoSync.ok].
  final String? sincronizadoEn;

  /// Mensaje técnico del motivo. Sirve para logs — no mostrárselo crudo al
  /// usuario, el texto para él sale de [estado].
  final String? detalle;

  const ResultadoSincronizacion({
    required this.estado,
    this.sincronizadoEn,
    this.detalle,
  });
}
