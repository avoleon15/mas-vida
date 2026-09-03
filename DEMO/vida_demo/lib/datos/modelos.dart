// ============================================================
// Modelos de datos de +Vida.
//
// Los campos que también existen en el JSON #2 del contrato v1
// (`puntos_pasos`, `puntos_intensidad`, `puntos_dia`,
// `tope_diario_aplicado`, `puntos_ano`, `tope_anual_aplicado`, `nivel`)
// conservan ese nombre exacto al deserializar. El resto del historial no
// está congelado en el contrato: el contrato define /api/v1/sync, y dice
// que el historial Daniel lo pide aparte por HTTP.
//
// TODO: falta congelar la forma de GET /api/v1/historial y de
// GET /api/v1/retos/estado. Los mocks de acá son la propuesta.
// ============================================================

/// Cómo llegó el dato de un día. Distinguir `sinPermiso` de un día con
/// cero pasos es una regla dura: HealthKit nunca informa si el usuario
/// negó el permiso de lectura, solo se infiere porque no vuelve nada.
enum OrigenDatos {
  healthkit,
  manual,
  sinPermiso;

  static OrigenDatos desde(String s) => switch (s) {
    'manual' => OrigenDatos.manual,
    'sin_permiso' => OrigenDatos.sinPermiso,
    _ => OrigenDatos.healthkit,
  };
}

/// Una fuente que reportó pasos ese día (reloj, teléfono, ingreso manual).
class FuenteDatos {
  const FuenteDatos({
    required this.nombre,
    required this.bundle,
    required this.pasos,
    required this.prevalece,
  });

  final String nombre;
  final String bundle;
  final int pasos;

  /// True para la fuente que ganó la precedencia ese día. Si es solo
  /// pasos, gana la que reporte más; si hay actividad intensa y reloj,
  /// gana el reloj.
  final bool prevalece;

  factory FuenteDatos.desdeJson(Map<String, dynamic> j) => FuenteDatos(
    nombre: j['nombre'] as String,
    bundle: j['bundle'] as String,
    pasos: j['pasos'] as int,
    prevalece: j['prevalece'] as bool,
  );
}

/// Una sesión de ejercicio con ritmo cardíaco.
class SesionIntensidad {
  const SesionIntensidad({
    required this.duracionMin,
    required this.continua,
    required this.tipoActividad,
    required this.porcentajeFcm,
    required this.cuentaParaPuntos,
    required this.puntosIntensidad,
  });

  final int duracionMin;
  final bool continua;
  final String tipoActividad;

  /// % de la FCM alcanzado. Lo calcula el servidor: el teléfono manda la
  /// edad y la FC cruda, nunca la FCM ni el porcentaje.
  final int porcentajeFcm;

  /// False si no llegó a los 30 minutos continuos.
  final bool cuentaParaPuntos;

  final int puntosIntensidad;

  factory SesionIntensidad.desdeJson(Map<String, dynamic> j) =>
      SesionIntensidad(
        duracionMin: j['duracion_min'] as int,
        continua: j['continua'] as bool,
        tipoActividad: j['tipo_actividad'] as String,
        porcentajeFcm: j['porcentaje_fcm'] as int,
        cuentaParaPuntos: j['cuenta_para_puntos'] as bool,
        puntosIntensidad: j['puntos_intensidad'] as int,
      );
}

/// Una reversión de puntos ya acreditados. Se permite hasta 2 semanas
/// después de la acreditación y el saldo nunca puede quedar negativo.
class Reversion {
  const Reversion({
    required this.puntosRevertidos,
    required this.fechaReversion,
    required this.motivo,
  });

  final int puntosRevertidos;
  final String fechaReversion;
  final String motivo;

  factory Reversion.desdeJson(Map<String, dynamic> j) => Reversion(
    puntosRevertidos: j['puntos_revertidos'] as int,
    fechaReversion: j['fecha_reversion'] as String,
    motivo: j['motivo'] as String,
  );
}

/// Un día del historial.
class DiaActividad {
  const DiaActividad({
    required this.fecha,
    required this.origen,
    required this.pasos,
    required this.puntosPasos,
    required this.puntosIntensidad,
    required this.puntosBrutos,
    required this.puntosDia,
    required this.topeAplicado,
    required this.fuentes,
    required this.sesion,
    required this.marcadoParaRevision,
    required this.reversion,
    required this.enCurso,
  });

  final DateTime fecha;
  final OrigenDatos origen;

  /// `null` cuando no hay permiso de HealthKit. NO es lo mismo que 0.
  final int? pasos;

  final int puntosPasos;
  final int puntosIntensidad;

  /// Lo que sumaron las dos vías antes del techo diario.
  final int puntosBrutos;

  /// Lo acreditado, ya con el techo aplicado.
  final int puntosDia;

  final bool topeAplicado;
  final List<FuenteDatos> fuentes;
  final SesionIntensidad? sesion;

  /// Un dato atípico se marca para revisión, nunca se rechaza en
  /// automático, y sigue mostrándose en pantalla.
  final bool marcadoParaRevision;

  final Reversion? reversion;
  final bool enCurso;

  bool get sinPermiso => origen == OrigenDatos.sinPermiso;
  bool get esManual => origen == OrigenDatos.manual;

  /// True cuando hay más de una fuente reportando pasos distintos ese
  /// día y hubo que aplicar precedencia.
  bool get huboPrecedencia => fuentes.length > 1;

  FuenteDatos? get fuentePrevalece {
    for (final f in fuentes) {
      if (f.prevalece) return f;
    }
    return null;
  }

  factory DiaActividad.desdeJson(Map<String, dynamic> j) => DiaActividad(
    fecha: DateTime.parse(j['fecha'] as String),
    origen: OrigenDatos.desde(j['origen_datos'] as String),
    pasos: j['pasos'] as int?,
    puntosPasos: j['puntos_pasos'] as int,
    puntosIntensidad: j['puntos_intensidad'] as int,
    puntosBrutos: j['puntos_brutos'] as int,
    puntosDia: j['puntos_dia'] as int,
    topeAplicado: j['tope_diario_aplicado'] as bool,
    fuentes: (j['fuentes'] as List)
        .map((f) => FuenteDatos.desdeJson(f as Map<String, dynamic>))
        .toList(),
    sesion: j['sesion'] == null
        ? null
        : SesionIntensidad.desdeJson(j['sesion'] as Map<String, dynamic>),
    marcadoParaRevision: j['marcado_para_revision'] as bool,
    reversion: j['reversion'] == null
        ? null
        : Reversion.desdeJson(j['reversion'] as Map<String, dynamic>),
    enCurso: j['dia_en_curso'] as bool? ?? false,
  );
}

/// Historial completo con su ventana.
class Historial {
  const Historial({required this.dias, required this.zonaHoraria});

  final List<DiaActividad> dias;
  final String zonaHoraria;

  DiaActividad get hoy => dias.last;

  /// Días de la semana en curso (lunes 00:00 a domingo 23:59, en hora de
  /// Guatemala). El corte se evalúa sobre la fecha del dato, nunca sobre
  /// la hora del dispositivo.
  List<DiaActividad> get semanaEnCurso {
    final ultimo = hoy.fecha;
    final lunes = ultimo.subtract(Duration(days: ultimo.weekday - 1));
    return dias.where((d) => !d.fecha.isBefore(lunes)).toList();
  }

  /// Días del mes calendario en curso.
  List<DiaActividad> get mesEnCurso {
    final ultimo = hoy.fecha;
    return dias
        .where(
          (d) => d.fecha.year == ultimo.year && d.fecha.month == ultimo.month,
        )
        .toList();
  }

  factory Historial.desdeJson(Map<String, dynamic> j) => Historial(
    zonaHoraria: j['zona_horaria'] as String,
    dias: (j['dias'] as List)
        .map((d) => DiaActividad.desdeJson(d as Map<String, dynamic>))
        .toList(),
  );
}

/// Un lote de monedas con su fecha de caducidad. Las monedas caducan a
/// los 6 meses de acuñadas.
class LoteMonedas {
  const LoteMonedas({
    required this.cantidad,
    required this.caducan,
    required this.diasParaCaducar,
  });

  final int cantidad;
  final String caducan;
  final int diasParaCaducar;

  /// Umbral de aviso al usuario. Es una decisión de presentación, no una
  /// regla de negocio.
  bool get cercaDeCaducar => diasParaCaducar <= 15;

  factory LoteMonedas.desdeJson(Map<String, dynamic> j) => LoteMonedas(
    cantidad: j['cantidad'] as int,
    caducan: j['caducan'] as String,
    diasParaCaducar: j['dias_para_caducar'] as int,
  );
}

/// Saldo de MONEDAS. Nunca se mezcla con puntos: las monedas se gastan,
/// los puntos no; las monedas viven en Premios, los puntos en Mi Plan.
class SaldoMonedas {
  const SaldoMonedas({
    required this.saldo,
    required this.ganadasEsteMes,
    required this.techoMensual,
    required this.lotes,
  });

  final int saldo;
  final int ganadasEsteMes;
  final int techoMensual;
  final List<LoteMonedas> lotes;

  /// TODO: falta cuánto vale una moneda en quetzales. Depende de las
  /// alianzas comerciales y no debe mostrarse hasta que exista.
  Object? get valorEnQuetzales => null;

  LoteMonedas? get proximoLoteACaducar {
    if (lotes.isEmpty) return null;
    final ordenados = [...lotes]
      ..sort((a, b) => a.diasParaCaducar.compareTo(b.diasParaCaducar));
    return ordenados.first;
  }

  factory SaldoMonedas.desdeJson(Map<String, dynamic> j) => SaldoMonedas(
    saldo: j['saldo'] as int,
    ganadasEsteMes: j['ganadas_este_mes'] as int,
    techoMensual: j['techo_mensual'] as int,
    lotes: (j['lotes'] as List)
        .map((l) => LoteMonedas.desdeJson(l as Map<String, dynamic>))
        .toList(),
  );
}

/// Una semana del historial de retos.
class SemanaReto {
  const SemanaReto({
    required this.semanaInicio,
    required this.rango,
    required this.completado,
  });

  final String semanaInicio;

  /// RANGO en el que se jugó esa semana, de 1 a [rangoMaximo].
  ///
  /// Se llamaba `nivel`, que es el nombre de la escalera ANUAL de
  /// cashback. Son dos cosas distintas: Nivel viene de los puntos y mueve
  /// el cashback; Rango viene de los objetivos semanales y paga monedas.
  final int rango;

  final bool completado;

  factory SemanaReto.desdeJson(Map<String, dynamic> j) => SemanaReto(
    semanaInicio: j['semana_inicio'] as String,
    rango: j['rango'] as int,
    completado: j['completado'] as bool,
  );
}

/// Estado de los objetivos semanales: en qué RANGO va el usuario y cómo
/// le fue en las semanas anteriores.
///
/// Cumplir los tres objetivos de la semana sube un rango; no cumplirlos
/// baja uno. Las reglas completas viven en `reglas_rango.dart`.
class EstadoRetos {
  const EstadoRetos({required this.rangoActual, required this.historial});

  /// De 1 a [rangoMaximo]. NO es el nivel de cashback: ese es anual, sale
  /// de los puntos y se llama Nivel.
  final int rangoActual;

  final List<SemanaReto> historial;

  /// TODO: falta la tabla de dificultad por rango. El contrato dice
  /// explícitamente que no hay número documentado todavía.
  Object? get objetivoSemanaActual => null;

  factory EstadoRetos.desdeJson(Map<String, dynamic> j) => EstadoRetos(
    rangoActual: j['rango_actual'] as int,
    historial: (j['historial'] as List)
        .map((h) => SemanaReto.desdeJson(h as Map<String, dynamic>))
        .toList(),
  );
}

/// UN objetivo de la semana. Paga MONEDAS, nunca puntos.
///
/// Los objetivos son SEMANALES: las metas mensuales ya no existen.
class ObjetivoSemanal {
  const ObjetivoSemanal({
    required this.id,
    required this.nombre,
    required this.progreso,
    required this.meta,
    required this.unidad,
    required this.monedas,
    required this.avanceReportado,
    required this.completo,
  });

  /// Identificador estable. Es lo que casa el objetivo con su definición
  /// en el motor de reglas, nunca el nombre visible.
  final String id;

  final String nombre;
  final int progreso;

  /// Cuánto pide el objetivo en el rango de esa semana.
  ///
  /// Null mientras la tabla de dificultad por rango no esté definida. La
  /// UI muestra "pendiente", nunca un número inventado.
  final int? meta;

  final String unidad;

  /// MONEDAS que acuña cumplirlo. Nunca puntos.
  final int monedas;

  final bool completo;

  /// Avance de 0 a 1 tal como lo reporta el servidor.
  ///
  /// Existe porque el servidor SÍ conoce la meta de cada rango aunque la
  /// app todavía no tenga la tabla de dificultad: puede decir qué tan
  /// lleno va el objetivo sin que el cliente sepa contra qué número.
  final double? avanceReportado;

  /// Qué tan lleno va el objetivo, de 0 a 1. Null solo cuando no hay
  /// forma de saberlo.
  ///
  /// Un objetivo CUMPLIDO va lleno siempre. Antes esto devolvía null
  /// cuando `meta` era null, y como null se pinta como cero, un objetivo
  /// completado se veía con la barra vacía.
  double? get avance {
    if (completo) return 1;
    final reportado = avanceReportado;
    if (reportado != null) return reportado.clamp(0.0, 1.0);
    final m = meta;
    if (m == null || m <= 0) return null;
    return (progreso / m).clamp(0.0, 1.0);
  }

  factory ObjetivoSemanal.desdeJson(Map<String, dynamic> j) => ObjetivoSemanal(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    progreso: j['progreso'] as int,
    meta: j['meta'] as int?,
    unidad: j['unidad'] as String,
    monedas: j['monedas'] as int,
    avanceReportado: (j['avance'] as num?)?.toDouble(),
    completo: j['completo'] as bool,
  );
}

/// En qué momento está una semana respecto de hoy.
enum EstadoSemana {
  /// Ya se evaluó (su domingo 23:59 pasó).
  cerrada,

  /// Es la semana en curso.
  enCurso,

  /// Todavía no empieza.
  futura,
}

/// Una semana con sus 3 objetivos.
///
/// Los tres son de la MISMA semana y se evalúan de una sola vez, el
/// domingo 23:59 (hora de Guatemala).
class SemanaObjetivos {
  const SemanaObjetivos({
    required this.numero,
    required this.cierra,
    required this.estado,
    required this.objetivos,
  });

  /// Número de semana dentro del mes: 1, 2, 3… Un mes puede tener 5.
  final int numero;

  /// Domingo 23:59 en que se evalúa.
  final DateTime cierra;

  final EstadoSemana estado;
  final List<ObjetivoSemanal> objetivos;

  /// Cuántos de los tres van cumplidos.
  int get cumplidos => objetivos.where((o) => o.completo).length;

  /// MONEDAS ya acuñadas en la semana.
  int get monedasGanadas =>
      objetivos.where((o) => o.completo).fold(0, (suma, o) => suma + o.monedas);

  /// MONEDAS que quedan en juego si se cumple todo lo que falta.
  int get monedasEnJuego =>
      objetivos.fold(0, (suma, o) => suma + o.monedas) - monedasGanadas;

  /// Cumplir los TRES es lo único que sube de rango.
  bool get subioDeRango => cumplidos == objetivos.length;

  factory SemanaObjetivos.desdeJson(Map<String, dynamic> j) => SemanaObjetivos(
    numero: j['numero'] as int,
    cierra: DateTime.parse(j['cierra'] as String),
    estado: switch (j['estado'] as String) {
      'cerrada' => EstadoSemana.cerrada,
      'en_curso' => EstadoSemana.enCurso,
      _ => EstadoSemana.futura,
    },
    objetivos: (j['objetivos'] as List)
        .map((o) => ObjetivoSemanal.desdeJson(o as Map<String, dynamic>))
        .toList(),
  );
}

/// Bloque de "Objetivos de la semana" de Home: las semanas del mes en
/// curso, cada una con sus 3 objetivos.
///
/// Reemplaza por completo al bloque viejo de metas mensuales, que ya no
/// existe. Las reglas del movimiento de rango viven en
/// `reglas_rango.dart`.
class ObjetivosSemana {
  const ObjetivosSemana({required this.rangoActual, required this.semanas});

  /// Rango en la escalera. Paga MONEDAS, nunca puntos.
  final int rangoActual;

  /// Las semanas del mes. Pueden ser 4 o 5: no todos los meses tienen
  /// cuatro lunes.
  final List<SemanaObjetivos> semanas;

  /// MONEDAS acuñadas por estos objetivos, sumando todas las semanas.
  ///
  /// NO es el saldo de la billetera: el saldo incluye monedas de meses
  /// anteriores y descuenta lo gastado en Premios. Esto es solo lo que
  /// dieron los objetivos que se están mostrando, así que suma
  /// exactamente lo que el usuario ve en las tarjetas de cada semana.
  int get monedasGanadas =>
      semanas.fold(0, (suma, s) => suma + s.monedasGanadas);

  /// La semana en curso, o null si el mes ya cerró.
  SemanaObjetivos? get enCurso {
    for (final s in semanas) {
      if (s.estado == EstadoSemana.enCurso) return s;
    }
    return null;
  }

  factory ObjetivosSemana.desdeJson(Map<String, dynamic> j) => ObjetivosSemana(
    rangoActual: j['rango_actual'] as int,
    semanas: (j['semanas'] as List)
        .map((s) => SemanaObjetivos.desdeJson(s as Map<String, dynamic>))
        .toList(),
  );
}

/// Reparto del tiempo de entrenamiento en zonas de ritmo cardíaco, en %
/// del total.
///
/// TODO: faltan los umbrales de % de FCM que separan una zona de otra.
/// No están en el contrato ni en el Excel — dependen de la misma matriz
/// de intensidad que define Luis en L7.
class ZonasRitmo {
  const ZonasRitmo({
    required this.ligero,
    required this.moderado,
    required this.intenso,
    required this.tendenciaIntensa,
  });

  final int ligero;
  final int moderado;
  final int intenso;

  /// Variación de la zona intensa respecto al período anterior, en puntos
  /// porcentuales.
  final int tendenciaIntensa;

  factory ZonasRitmo.desdeJson(Map<String, dynamic> j) => ZonasRitmo(
    ligero: j['ligero'] as int,
    moderado: j['moderado'] as int,
    intenso: j['intenso'] as int,
    tendenciaIntensa: j['tendencia_intensa'] as int,
  );
}

/// Cashback anual proyectado.
class Cashback {
  const Cashback({required this.porcentaje, required this.proyectadoQ});

  final double porcentaje;
  final int proyectadoQ;

  /// TODO: falta la fórmula de devengo a mitad de año. Solo está fijado
  /// que el cashback se devuelve como dinero DESPUÉS del pago de la
  /// prima — nunca como descuento directo (Superintendencia de Bancos).
  int? get devengadoQ => null;

  factory Cashback.desdeJson(Map<String, dynamic> j) => Cashback(
    porcentaje: (j['porcentaje'] as num).toDouble(),
    proyectadoQ: j['proyectado_q'] as int,
  );
}

/// Resumen anual: el acumulado de PUNTOS, el nivel y el cashback.
class ResumenAnual {
  const ResumenAnual({
    required this.anio,
    required this.puntosAno,
    required this.techoAnual,
    required this.topeAnualAplicado,
    required this.nivel,
    required this.cashback,
    required this.puntosSemana,
    required this.puntosSemanaAnterior,
    required this.puntosMes,
    required this.rachaSemanas,
    required this.rachaHistorial,
    required this.retos,
    required this.monedas,
    required this.objetivosSemana,
    required this.actividadPorMes,
    required this.mesActualIndice,
    required this.zonasSemana,
    required this.zonasMes,
    required this.zonasAnio,
    required this.monedasGanadasAnio,
  });

  final int anio;
  final int puntosAno;
  final int techoAnual;
  final bool topeAnualAplicado;

  /// Nivel numérico 0–4 del esquema propio. El contrato prohíbe el
  /// naming Bronze/Silver/Gold/Platinum.
  final int nivel;

  final Cashback cashback;
  final int puntosSemana;
  final int puntosSemanaAnterior;
  final int puntosMes;
  final int rachaSemanas;
  final List<bool> rachaHistorial;
  final EstadoRetos retos;
  final SaldoMonedas monedas;
  final ObjetivosSemana objetivosSemana;

  /// Puntos por mes del año en curso, de enero a diciembre.
  final List<int> actividadPorMes;

  /// Índice (0 = enero) del mes en curso.
  final int mesActualIndice;

  final ZonasRitmo zonasSemana;
  final ZonasRitmo zonasMes;
  final ZonasRitmo zonasAnio;
  final int monedasGanadasAnio;

  factory ResumenAnual.desdeJson(Map<String, dynamic> j) {
    final sem = j['semana_actual'] as Map<String, dynamic>;
    final anual = j['actividad_anual'] as Map<String, dynamic>;
    final ritmo = j['ritmo_cardiaco'] as Map<String, dynamic>;
    return ResumenAnual(
      actividadPorMes: (anual['por_mes'] as List).cast<int>(),
      mesActualIndice: anual['mes_actual_indice'] as int,
      zonasSemana: ZonasRitmo.desdeJson(
        ritmo['semana'] as Map<String, dynamic>,
      ),
      zonasMes: ZonasRitmo.desdeJson(ritmo['mes'] as Map<String, dynamic>),
      zonasAnio: ZonasRitmo.desdeJson(ritmo['anio'] as Map<String, dynamic>),
      monedasGanadasAnio: j['monedas_ganadas_anio'] as int,
      anio: j['anio'] as int,
      puntosAno: j['puntos_ano'] as int,
      techoAnual: j['techo_anual'] as int,
      topeAnualAplicado: j['tope_anual_aplicado'] as bool,
      nivel: j['nivel'] as int,
      cashback: Cashback.desdeJson(j['cashback'] as Map<String, dynamic>),
      puntosSemana: sem['puntos'] as int,
      puntosSemanaAnterior: sem['puntos_semana_anterior'] as int,
      puntosMes: (j['mes_actual'] as Map<String, dynamic>)['puntos'] as int,
      rachaSemanas: j['racha_semanas'] as int,
      rachaHistorial: (j['racha_historial'] as List).cast<bool>(),
      retos: EstadoRetos.desdeJson(
        j['retos_semanales'] as Map<String, dynamic>,
      ),
      monedas: SaldoMonedas.desdeJson(j['monedas'] as Map<String, dynamic>),
      objetivosSemana: ObjetivosSemana.desdeJson(
        j['objetivos_semana'] as Map<String, dynamic>,
      ),
    );
  }
}

/// Datos de la póliza que la aseguradora expone al asegurado.
class Poliza {
  const Poliza({
    required this.numero,
    required this.titularYDependientes,
    required this.tipoPlan,
    required this.sumaAsegurada,
    required this.deducible,
    required this.coaseguro,
    required this.vigencia,
    required this.fechaRenovacion,
    required this.primaAnual,
    required this.formaPago,
    required this.redCobertura,
    required this.estado,
  });

  final String numero;
  final String titularYDependientes;
  final String tipoPlan;
  final String sumaAsegurada;
  final String deducible;
  final String coaseguro;
  final String vigencia;
  final String fechaRenovacion;
  final String primaAnual;
  final String formaPago;
  final String redCobertura;
  final String estado;

  factory Poliza.desdeJson(Map<String, dynamic> j) => Poliza(
    numero: j['numero'] as String,
    titularYDependientes: j['titular_y_dependientes'] as String,
    tipoPlan: j['tipo_plan'] as String,
    sumaAsegurada: j['suma_asegurada'] as String,
    deducible: j['deducible'] as String,
    coaseguro: j['coaseguro'] as String,
    vigencia: j['vigencia'] as String,
    fechaRenovacion: j['fecha_renovacion'] as String,
    primaAnual: j['prima_anual'] as String,
    formaPago: j['forma_pago'] as String,
    redCobertura: j['red_cobertura'] as String,
    estado: j['estado'] as String,
  );
}

/// Perfil del asegurado.
class Perfil {
  const Perfil({
    required this.usuarioId,
    required this.nombre,
    required this.edad,
    required this.zonaHoraria,
    required this.permisoHealthkit,
    required this.poliza,
  });

  final String usuarioId;
  final String nombre;

  /// Viene de la póliza, NUNCA autodeclarada por el usuario.
  final int edad;

  final String zonaHoraria;
  final String permisoHealthkit;
  final Poliza poliza;

  factory Perfil.desdeJson(Map<String, dynamic> j) => Perfil(
    usuarioId: j['usuario_id'] as String,
    nombre: j['nombre'] as String,
    edad: j['edad'] as int,
    zonaHoraria: j['zona_horaria'] as String,
    permisoHealthkit: j['permiso_healthkit'] as String,
    poliza: Poliza.desdeJson(j['poliza'] as Map<String, dynamic>),
  );
}

/// Un premio del catálogo. El costo va SOLO en monedas.
class Premio {
  const Premio({
    required this.id,
    required this.nombre,
    required this.zona,
    required this.categoria,
    required this.descripcion,
    required this.detalle,
    required this.condiciones,
    required this.costoMonedas,
    required this.vence,
  });

  final String id;
  final String nombre;
  final String zona;
  final String categoria;
  final String descripcion;
  final String detalle;
  final String condiciones;
  final int costoMonedas;
  final String vence;

  factory Premio.desdeJson(Map<String, dynamic> j) => Premio(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    zona: j['zona'] as String,
    categoria: j['categoria'] as String,
    descripcion: j['descripcion'] as String,
    detalle: j['detalle'] as String,
    condiciones: j['condiciones'] as String,
    costoMonedas: j['costo_monedas'] as int,
    vence: j['vence'] as String,
  );
}

/// Catálogo de premios con sus filtros.
class Catalogo {
  const Catalogo({required this.categorias, required this.premios});

  final List<String> categorias;
  final List<Premio> premios;

  factory Catalogo.desdeJson(Map<String, dynamic> j) => Catalogo(
    categorias: (j['categorias'] as List).cast<String>(),
    premios: (j['premios'] as List)
        .map((p) => Premio.desdeJson(p as Map<String, dynamic>))
        .toList(),
  );
}

// ---- Social ----

enum Tendencia {
  subida,
  bajada,
  igual;

  static Tendencia desde(String s) => switch (s) {
    'subida' => Tendencia.subida,
    'bajada' => Tendencia.bajada,
    _ => Tendencia.igual,
  };
}

/// Duelo activo. Los duelos NO otorgan monedas ni premios: son
/// puramente competitivos y sociales.
class Duelo {
  const Duelo({
    required this.activo,
    required this.rivalHandle,
    required this.tiempoRestante,
    required this.superacionPropia,
    required this.superacionRival,
  });

  final bool activo;
  final String rivalHandle;
  final String tiempoRestante;

  /// % sobre el propio promedio de cada quien. Nunca comparación directa
  /// de pasos entre personas.
  final double superacionPropia;
  final double superacionRival;

  factory Duelo.desdeJson(Map<String, dynamic> j) => Duelo(
    activo: j['activo'] as bool,
    rivalHandle: j['rival_handle'] as String,
    tiempoRestante: j['tiempo_restante'] as String,
    superacionPropia: (j['superacion_propia'] as num).toDouble(),
    superacionRival: (j['superacion_rival'] as num).toDouble(),
  );
}

class DueloHistorial {
  const DueloHistorial({required this.rival, required this.ganado});

  final String rival;
  final bool ganado;

  factory DueloHistorial.desdeJson(Map<String, dynamic> j) =>
      DueloHistorial(rival: j['rival'] as String, ganado: j['ganado'] as bool);
}

/// Una conexión. De otra persona solo se exponen racha, nivel y monedas
/// — NUNCA sus pasos ni su historial crudo.
class Conexion {
  const Conexion({
    required this.nombre,
    required this.handle,
    required this.rachaSemanas,
    required this.nivel,
    required this.monedasTotales,
  });

  final String nombre;
  final String handle;
  final int rachaSemanas;
  final int nivel;
  final int monedasTotales;

  factory Conexion.desdeJson(Map<String, dynamic> j) => Conexion(
    nombre: j['nombre'] as String,
    handle: j['handle'] as String,
    rachaSemanas: j['racha_semanas'] as int,
    nivel: j['nivel'] as int,
    monedasTotales: j['monedas_totales'] as int,
  );
}

class RankingPersona {
  const RankingPersona({
    required this.nombre,
    required this.puntosSemana,
    required this.tendencia,
    required this.esUsuario,
  });

  final String nombre;

  /// Solo se usa para ordenar. El ranking visible es posición, nunca los
  /// puntos de los demás.
  final int puntosSemana;

  final Tendencia tendencia;
  final bool esUsuario;

  factory RankingPersona.desdeJson(Map<String, dynamic> j) => RankingPersona(
    nombre: j['nombre'] as String,
    puntosSemana: j['puntos_semana'] as int,
    tendencia: Tendencia.desde(j['tendencia'] as String),
    esUsuario: j['es_usuario'] as bool? ?? false,
  );
}

class DatosSociales {
  const DatosSociales({
    required this.duelo,
    required this.historialDuelos,
    required this.conexiones,
    required this.gruposRanking,
    required this.rankingPorGrupo,
  });

  final Duelo duelo;
  final List<DueloHistorial> historialDuelos;
  final List<Conexion> conexiones;
  final List<String> gruposRanking;
  final Map<String, List<RankingPersona>> rankingPorGrupo;

  factory DatosSociales.desdeJson(Map<String, dynamic> j) => DatosSociales(
    duelo: Duelo.desdeJson(j['duelo'] as Map<String, dynamic>),
    historialDuelos: (j['historial_duelos'] as List)
        .map((d) => DueloHistorial.desdeJson(d as Map<String, dynamic>))
        .toList(),
    conexiones: (j['conexiones'] as List)
        .map((c) => Conexion.desdeJson(c as Map<String, dynamic>))
        .toList(),
    gruposRanking: (j['grupos_ranking'] as List).cast<String>(),
    rankingPorGrupo: (j['ranking_por_grupo'] as Map<String, dynamic>).map(
      (grupo, personas) => MapEntry(
        grupo,
        (personas as List)
            .map((p) => RankingPersona.desdeJson(p as Map<String, dynamic>))
            .toList(),
      ),
    ),
  );
}
