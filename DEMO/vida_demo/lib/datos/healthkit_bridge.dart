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
  /// cuando está negado devuelve datos vacíos, no un error. Por eso el
  /// resultado tiene un [EstadoPermisos] y no solo un booleano: hay un caso
  /// (`sinDatosVisibles`) que es genuinamente ambiguo y no se le puede
  /// presentar al usuario como "listo" ni como "negaste el permiso".
  Future<ResultadoPermisos> solicitarPermisos() async {
    final respuesta = await _canal.invokeMapMethod<String, dynamic>(
      'solicitarPermisos',
    );
    return ResultadoPermisos(
      concedido: respuesta?['concedido'] as bool? ?? false,
      estado: EstadoPermisos.desde(respuesta?['estado'] as String?),
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
      ok: respuesta?['ok'] as bool? ?? false,
      estado: EstadoSync.desde(respuesta?['estado'] as String?),
      sincronizadoEn: respuesta?['sincronizado_en'] as String?,
      detalle: respuesta?['detalle'] as String?,
    );
  }
}

enum EstadoPermisos {
  /// Se vieron datos reales: hay acceso, sin ambigüedad.
  concedido,

  /// No se vio ningún dato en 30 días. Puede ser permiso negado, o un usuario
  /// real sin actividad registrada — no se pueden distinguir. Mostrar algo
  /// como "No vemos datos de actividad. Si negaste el acceso, activalo en
  /// Ajustes › Salud › +Vida", nunca un "listo".
  sinDatosVisibles,

  /// El dispositivo no soporta HealthKit (iPad, simulador).
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
  final bool concedido;
  final EstadoPermisos estado;
  final String? detalle;

  const ResultadoPermisos({
    required this.concedido,
    required this.estado,
    this.detalle,
  });
}

class ResultadoSincronizacion {
  final bool ok;
  final EstadoSync estado;

  /// Timestamp ISO 8601 del envío. Solo viene cuando [ok] es true.
  final String? sincronizadoEn;

  /// Mensaje técnico del motivo. Sirve para logs — no mostrárselo crudo al
  /// usuario, el texto para él sale de [estado].
  final String? detalle;

  const ResultadoSincronizacion({
    required this.ok,
    required this.estado,
    this.sincronizadoEn,
    this.detalle,
  });
}
