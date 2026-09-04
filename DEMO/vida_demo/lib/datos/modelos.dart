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
    required this.inicio,
    required this.duracionMin,
    required this.continua,
    required this.tipoActividad,
    required this.fcPromedio,
    required this.porcentajeFcm,
    required this.cuentaParaPuntos,
    required this.puntosIntensidad,
  });

  /// Cuándo arrancó el entrenamiento. Null si HealthKit no lo informó.
  final DateTime? inicio;

  final int duracionMin;
  final bool continua;
  final String tipoActividad;

  /// FC promedio de la sesión, en bpm. Es el dato CRUDO de HealthKit.
  ///
  /// Distinto de [porcentajeFcm]: ese es el % de la FCmáx y lo calcula el
  /// servidor con la edad de la póliza. El teléfono nunca manda la FCmáx.
  final int? fcPromedio;

  /// % de la FCM alcanzado. Lo calcula el servidor: el teléfono manda la
  /// edad y la FC cruda, nunca la FCM ni el porcentaje.
  final int porcentajeFcm;

  /// False si no llegó a los 30 minutos continuos.
  final bool cuentaParaPuntos;

  final int puntosIntensidad;

  factory SesionIntensidad.desdeJson(Map<String, dynamic> j) =>
      SesionIntensidad(
        inicio: j['inicio'] == null
            ? null
            : DateTime.tryParse(j['inicio'] as String),
        duracionMin: j['duracion_min'] as int,
        continua: j['continua'] as bool,
        tipoActividad: j['tipo_actividad'] as String,
        fcPromedio: j['fc_promedio'] as int?,
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

/// Ritmo cardíaco del día, tal como lo entrega HealthKit.
///
/// Son bpm CRUDOS. No se convierten a % de FCmáx acá: eso lo hace el
/// servidor con la edad de la póliza.
class RitmoCardiacoDia {
  const RitmoCardiacoDia({
    required this.promedio,
    required this.minimo,
    required this.maximo,
  });

  final int promedio;
  final int minimo;
  final int maximo;

  factory RitmoCardiacoDia.desdeJson(Map<String, dynamic> j) =>
      RitmoCardiacoDia(
        promedio: j['promedio_bpm'] as int,
        minimo: j['minimo_bpm'] as int,
        maximo: j['maximo_bpm'] as int,
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
    required this.ritmo,
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

  /// Null cuando ese día no hubo lecturas de ritmo cardíaco.
  final RitmoCardiacoDia? ritmo;

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
    ritmo: j['ritmo_cardiaco'] == null
        ? null
        : RitmoCardiacoDia.desdeJson(
            j['ritmo_cardiaco'] as Map<String, dynamic>,
          ),
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
  /// En el JSON el campo se llama `nivel`, que es como lo nombra el
  /// contrato. Acá se expone como rango porque Nivel ya es la escalera
  /// ANUAL de cashback: esa viene de los puntos y mueve el cashback,
  /// mientras que el rango viene de los objetivos semanales y paga
  /// monedas. La traducción ocurre en [desdeJson] y en ningún otro lado.
  final int rango;

  final bool completado;

  factory SemanaReto.desdeJson(Map<String, dynamic> j) => SemanaReto(
    semanaInicio: j['semana_inicio'] as String,
    rango: j['nivel'] as int,
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
  ///
  /// Llega como `nivel_actual` en el JSON: ese es el nombre del contrato
  /// y no se le cambia al backend desde acá — hacerlo sería un v3.
  final int rangoActual;

  final List<SemanaReto> historial;

  factory EstadoRetos.desdeJson(Map<String, dynamic> j) => EstadoRetos(
    rangoActual: j['nivel_actual'] as int,
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
  ///
  /// Llega como `nivel_actual`, igual que en [EstadoRetos] y por el mismo
  /// motivo: es la misma escalera y el JSON usa el nombre del contrato.
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
    rangoActual: j['nivel_actual'] as int,
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

/// Datos de contacto de la aseguradora.
///
/// [verificado] es la llave: mientras sea false, ningún número de acá se
/// puede presentar como bueno. Un teléfono de emergencias inventado es
/// peligroso de verdad — alguien lo marca en el peor momento de su vida.
class Aseguradora {
  const Aseguradora({
    required this.nombre,
    required this.telefonoEmergencias,
    required this.telefonoServicio,
    required this.correo,
    required this.horario,
    required this.verificado,
  });

  final String nombre;
  final String telefonoEmergencias;
  final String telefonoServicio;
  final String correo;
  final String horario;

  /// True solo cuando la aseguradora confirmó estos datos.
  final bool verificado;

  factory Aseguradora.desdeJson(Map<String, dynamic> j) => Aseguradora(
    nombre: j['nombre'] as String,
    telefonoEmergencias: j['telefono_emergencias'] as String,
    telefonoServicio: j['telefono_servicio'] as String,
    correo: j['correo'] as String,
    horario: j['horario'] as String,
    verificado: j['verificado'] as bool? ?? false,
  );
}

/// Un paso de "cómo usar tu seguro".
class PasoUso {
  const PasoUso({required this.titulo, required this.detalle});

  final String titulo;
  final String detalle;

  factory PasoUso.desdeJson(Map<String, dynamic> j) =>
      PasoUso(titulo: j['titulo'] as String, detalle: j['detalle'] as String);
}

/// El procedimiento para usar el seguro.
class UsoDelSeguro {
  const UsoDelSeguro({required this.pasos, required this.verificado});

  final List<PasoUso> pasos;

  /// Igual que en [Aseguradora]: mientras sea false, es un borrador de
  /// redacción y no un procedimiento que alguien pueda seguir.
  final bool verificado;

  factory UsoDelSeguro.desdeJson(Map<String, dynamic> j) => UsoDelSeguro(
    pasos: (j['pasos'] as List)
        .map((p) => PasoUso.desdeJson(p as Map<String, dynamic>))
        .toList(),
    verificado: j['verificado'] as bool? ?? false,
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
    required this.aseguradora,
    required this.usoDelSeguro,
  });

  final String usuarioId;
  final String nombre;

  /// Viene de la póliza, NUNCA autodeclarada por el usuario.
  final int edad;

  final String zonaHoraria;
  final String permisoHealthkit;
  final Poliza poliza;
  final Aseguradora aseguradora;
  final UsoDelSeguro usoDelSeguro;

  factory Perfil.desdeJson(Map<String, dynamic> j) => Perfil(
    usuarioId: j['usuario_id'] as String,
    nombre: j['nombre'] as String,
    edad: j['edad'] as int,
    zonaHoraria: j['zona_horaria'] as String,
    permisoHealthkit: j['permiso_healthkit'] as String,
    poliza: Poliza.desdeJson(j['poliza'] as Map<String, dynamic>),
    aseguradora: Aseguradora.desdeJson(
      j['aseguradora'] as Map<String, dynamic>,
    ),
    usoDelSeguro: UsoDelSeguro.desdeJson(
      j['uso_del_seguro'] as Map<String, dynamic>,
    ),
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

/// Una solicitud de amistad, recibida o enviada.
///
/// De alguien que TODAVÍA no es tu contacto solo se sabe el nombre, el
/// usuario y cuántos amigos comparten. Nada de rachas, niveles ni
/// actividad: eso se gana al aceptar, no al pedir.
class Solicitud {
  const Solicitud({
    required this.nombre,
    required this.handle,
    required this.amigosEnComun,
  });

  final String nombre;
  final String handle;
  final int amigosEnComun;

  factory Solicitud.desdeJson(Map<String, dynamic> j) => Solicitud(
    nombre: j['nombre'] as String,
    handle: j['handle'] as String,
    amigosEnComun: j['amigos_en_comun'] as int? ?? 0,
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

  /// Puntos de la semana.
  ///
  /// SIEMPRE se usan para ordenar. Si se MUESTRAN o no lo decide el
  /// grupo (ver [GrupoRanking.mostrarPuntos]): entre conocidos se pueden
  /// ver, con desconocidos nunca.
  final int puntosSemana;

  final Tendencia tendencia;
  final bool esUsuario;

  /// [yo] son los datos del usuario, que en el JSON se escriben UNA sola
  /// vez arriba de todo. El usuario aparece en todos los grupos con los
  /// mismos puntos, así que cada grupo solo lo marca con `es_usuario` y
  /// de acá se rellena el resto. Si un grupo trae el dato completo, ese
  /// gana.
  factory RankingPersona.desdeJson(
    Map<String, dynamic> j, {
    Map<String, dynamic>? yo,
  }) {
    final esUsuario = j['es_usuario'] as bool? ?? false;
    final campos = esUsuario && yo != null ? {...yo, ...j} : j;

    return RankingPersona(
      nombre: campos['nombre'] as String,
      puntosSemana: campos['puntos_semana'] as int,
      tendencia: Tendencia.desde(campos['tendencia'] as String? ?? 'igual'),
      esUsuario: esUsuario,
    );
  }

  Map<String, dynamic> aJson() => {
    'nombre': nombre,
    'puntos_semana': puntosSemana,
    'tendencia': tendencia.name,
    if (esUsuario) 'es_usuario': true,
  };
}

/// Con quién compite el usuario en un grupo.
enum TipoGrupo {
  /// Gente que el usuario conoce y agregó a mano: oficina, familia,
  /// amigos. Acá los puntos se pueden mostrar si el grupo lo decidió.
  conocidos,

  /// Liga local armada por la app entre gente que no se conoce. Los
  /// puntos NUNCA se muestran: solo la posición.
  desconocidos;

  static TipoGrupo desde(String s) =>
      s == 'desconocidos' ? TipoGrupo.desconocidos : TipoGrupo.conocidos;
}

/// Un grupo de ranking.
class GrupoRanking {
  const GrupoRanking({
    required this.id,
    required this.nombre,
    required this.tipo,
    required bool mostrarPuntos,
    required this.miembros,
    this.nivelActividad,
    this.zona,
    this.cierra,
    this.premiosMonedas = const [],
    this.creadoPorMi = false,
    String? codigo,
    // ignore: prefer_initializing_formals
  }) : _mostrarPuntos = mostrarPuntos,
       // ignore: prefer_initializing_formals
       _codigo = codigo;

  final String id;
  final String nombre;
  final TipoGrupo tipo;

  /// Si se ven los puntos de cada quien o solo la posición.
  ///
  /// Lo elige quien crea el grupo. En un grupo de [TipoGrupo.desconocidos]
  /// se ignora y siempre va en false: mostrarle a un extraño cuántos
  /// puntos hace alguien es dar su nivel de actividad a alguien que no
  /// eligió como contacto.
  bool get mostrarPuntos =>
      tipo == TipoGrupo.desconocidos ? false : _mostrarPuntos;
  final bool _mostrarPuntos;

  final List<RankingPersona> miembros;

  /// Solo en ligas de desconocidos: contra qué nivel de actividad se
  /// arma la liga, para que compita gente parecida.
  final String? nivelActividad;

  /// Solo en ligas de desconocidos: la zona contra la que se compite.
  ///
  /// Es el área declarada de la liga, NUNCA la ubicación de nadie: la app
  /// no comparte ubicación de personas.
  final String? zona;

  /// Cuándo cierra y se reparten los premios.
  final DateTime? cierra;

  /// MONEDAS que se lleva cada podio, del 1.o al 3.o. Vacío si el grupo
  /// no premia. Nunca puntos: los puntos no se regalan por competir.
  final List<int> premiosMonedas;

  /// Si el usuario lo creó o se unió a él desde la app, en vez de venir
  /// del mock. Solo estos se guardan en el teléfono: los del mock ya
  /// vuelven solos en cada arranque.
  final bool creadoPorMi;

  RankingPersona? get usuario {
    for (final m in miembros) {
      if (m.esUsuario) return m;
    }
    return null;
  }

  /// Si el usuario está compitiendo en este grupo. Estar en la tabla ES
  /// estar unido: no hay un estado aparte que se pueda desincronizar.
  bool get estoyUnido => usuario != null;

  /// El código con el que se invita a alguien a este grupo.
  ///
  /// Si el grupo no trae uno, se deriva del id: así el mismo grupo
  /// muestra siempre el mismo código, arranque tras arranque, en vez de
  /// uno nuevo cada vez que se abre la pantalla.
  ///
  /// TODO: el código real lo tiene que emitir el backend. Uno derivado
  /// no se puede revocar ni verificar, y quien lo adivine entra.
  String get codigoInvitacion => _codigo ?? _codigoDesde(id);
  final String? _codigo;

  /// Seis caracteres estables a partir del id, sin las letras y números
  /// que se confunden al dictarlos (O/0, I/1).
  static String _codigoDesde(String id) {
    const alfabeto = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var semilla = id.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7FFFFFF);

    final buffer = StringBuffer();
    for (var i = 0; i < 6; i++) {
      buffer.write(alfabeto[semilla % alfabeto.length]);
      semilla = semilla ~/ alfabeto.length + 13;
    }
    return buffer.toString();
  }

  /// Posición del usuario, empezando en 1.
  int get posicionUsuario => miembros.indexWhere((m) => m.esUsuario) + 1;

  /// Lo propio de una liga (nivel, cierre, premios) vive en un bloque
  /// `liga` aparte, para que un grupo normal no cargue cuatro campos
  /// vacíos que no le aplican.
  factory GrupoRanking.desdeJson(
    Map<String, dynamic> j, {
    Map<String, dynamic>? yo,
  }) {
    final liga = (j['liga'] as Map<String, dynamic>?) ?? const {};

    return GrupoRanking(
      id: j['id'] as String,
      nombre: j['nombre'] as String,
      tipo: TipoGrupo.desde(j['tipo'] as String? ?? 'conocidos'),
      mostrarPuntos: j['mostrar_puntos'] as bool? ?? false,
      miembros: (j['miembros'] as List)
          .map(
            (m) => RankingPersona.desdeJson(m as Map<String, dynamic>, yo: yo),
          )
          .toList(),
      nivelActividad: liga['nivel_actividad'] as String?,
      zona: liga['zona'] as String?,
      cierra: liga['cierra'] == null
          ? null
          : DateTime.tryParse(liga['cierra'] as String),
      premiosMonedas: ((liga['premios_monedas'] as List?) ?? const [])
          .cast<int>()
          .toList(),
      creadoPorMi: j['creado_por_mi'] as bool? ?? false,
      codigo: j['codigo'] as String?,
    );
  }

  /// Misma forma que un grupo de `social.json`, para que lo guardado en el
  /// teléfono se pueda volver a leer con el mismo parser.
  Map<String, dynamic> aJson() => {
    'id': id,
    'nombre': nombre,
    'tipo': tipo.name,
    'mostrar_puntos': _mostrarPuntos,
    'miembros': miembros.map((m) => m.aJson()).toList(),
    if (nivelActividad != null ||
        zona != null ||
        cierra != null ||
        premiosMonedas.isNotEmpty)
      'liga': {
        if (nivelActividad != null) 'nivel_actividad': nivelActividad,
        if (zona != null) 'zona': zona,
        if (cierra != null) 'cierra': cierra!.toIso8601String(),
        if (premiosMonedas.isNotEmpty) 'premios_monedas': premiosMonedas,
      },
    if (creadoPorMi) 'creado_por_mi': true,
    if (_codigo != null) 'codigo': _codigo,
  };
}

class DatosSociales {
  DatosSociales({
    required this.duelo,
    required this.historialDuelos,
    required this.conexiones,
    required this.grupos,
    required this.solicitudesRecibidas,
    required this.solicitudesEnviadas,
  });

  final Duelo duelo;
  final List<DueloHistorial> historialDuelos;

  /// Tus amigos. MUTABLE: aceptar una solicitud agrega uno.
  final List<Conexion> conexiones;

  /// Quién te pidió ser tu amigo. MUTABLE: aceptar o rechazar la saca.
  final List<Solicitud> solicitudesRecibidas;

  /// A quién le pediste vos. MUTABLE: cancelar la saca.
  final List<Solicitud> solicitudesEnviadas;

  /// Los grupos de ranking. Es una lista MUTABLE a propósito: crear o
  /// unirse a un grupo la modifica en el acto.
  ///
  /// Los del mock se leen de `social.json`; los que creó el usuario se
  /// pegan encima desde `AlmacenSocial`.
  ///
  /// TODO: cuando exista el backend, crear y unirse pasan por él y esto
  /// se hidrata de la API.
  final List<GrupoRanking> grupos;

  /// Los grupos de gente conocida, que son los únicos que pueden mostrar
  /// puntos.
  List<GrupoRanking> get deConocidos =>
      grupos.where((g) => g.tipo == TipoGrupo.conocidos).toList();

  /// La liga local con desconocidos, si el usuario está en alguna.
  GrupoRanking? get ligaLocal {
    for (final g in grupos) {
      if (g.tipo == TipoGrupo.desconocidos) return g;
    }
    return null;
  }

  factory DatosSociales.desdeJson(Map<String, dynamic> j) {
    final duelos = j['duelos'] as Map<String, dynamic>;
    // Los datos del usuario se escriben una sola vez y cada grupo los
    // hereda: así sus puntos no quedan repetidos (y desincronizables) en
    // cada ranking.
    final yo = j['yo'] as Map<String, dynamic>?;

    return DatosSociales(
      duelo: Duelo.desdeJson(duelos['activo'] as Map<String, dynamic>),
      historialDuelos: (duelos['historial'] as List)
          .map((d) => DueloHistorial.desdeJson(d as Map<String, dynamic>))
          .toList(),
      conexiones: (j['conexiones'] as List)
          .map((c) => Conexion.desdeJson(c as Map<String, dynamic>))
          .toList(),
      grupos: (j['grupos'] as List)
          .map((g) => GrupoRanking.desdeJson(g as Map<String, dynamic>, yo: yo))
          .toList(),
      solicitudesRecibidas: ((j['solicitudes_recibidas'] as List?) ?? const [])
          .map((s) => Solicitud.desdeJson(s as Map<String, dynamic>))
          .toList(),
      solicitudesEnviadas: ((j['solicitudes_enviadas'] as List?) ?? const [])
          .map((s) => Solicitud.desdeJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
