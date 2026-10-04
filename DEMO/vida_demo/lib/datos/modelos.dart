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

  final bool enCurso;

  /// Null cuando ese día no hubo lecturas de ritmo cardíaco.
  final RitmoCardiacoDia? ritmo;

  bool get sinPermiso => origen == OrigenDatos.sinPermiso;
  bool get esManual => origen == OrigenDatos.manual;

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

  /// Días del año calendario en curso.
  ///
  /// Hoy el historial no llega a tanto —trae poco más de un mes—, así
  /// que devuelve todo. Filtra igual: el día que el backend mande dos
  /// años, "este año" tiene que seguir siendo este año.
  List<DiaActividad> get anioEnCurso =>
      dias.where((d) => d.fecha.year == hoy.fecha.year).toList();

  /// Días del mes calendario en curso.
  List<DiaActividad> get mesEnCurso {
    final ultimo = hoy.fecha;
    return dias
        .where(
          (d) => d.fecha.year == ultimo.year && d.fecha.month == ultimo.month,
        )
        .toList();
  }

  /// Las semanas del mes en curso, cada una con sus días, de la más
  /// vieja a la más nueva.
  ///
  /// UNA SEMANA ES DEL MES DE SU LUNES, no del mes de cada día suelto
  /// (decisión de Daniel, 21 de septiembre de 2026). Antes se agrupaban
  /// por su lunes los días del mes CALENDARIO, y eso partía una semana
  /// entre dos meses: agosto de 2026 arranca sábado, así que el 1 y el 2
  /// —que son la cola de la semana del 27 de julio— salían como "semana
  /// 1 de agosto", una barra de dos días parada al lado de barras de
  /// siete. Se leía como una semana pésima y ni siquiera era una semana.
  /// Agosto tiene CUATRO semanas, no cinco.
  ///
  /// Es la misma regla que ya manda en todo lo demás: la semana corre de
  /// lunes 00:00 a domingo 23:59 y la cierra el servidor de una sola
  /// vez, así que es indivisible — no puede contarse mitad en un mes y
  /// mitad en el otro.
  ///
  /// La ÚLTIMA sí puede ser corta, pero por el motivo bueno: es la
  /// semana en curso y todavía no terminó.
  ///
  /// Consecuencia a tener presente: estas semanas NO suman los puntos
  /// del mes calendario. Los días anteriores al primer lunes del mes
  /// quedan afuera, contados en el mes anterior, que es donde cayó su
  /// semana.
  ///
  /// Borde: mientras un mes que no arranca en lunes no llega a su primer
  /// lunes, no tiene ninguna semana propia. Ahí se devuelve la semana en
  /// curso sola — una barra sin nada al lado con qué confundirla es
  /// mejor que un panel vacío.
  List<List<DiaActividad>> get semanasDelMes {
    final mes = hoy.fecha;
    final porLunes = <DateTime, List<DiaActividad>>{};
    for (final d in mesEnCurso) {
      final lunes = DateTime(
        d.fecha.year,
        d.fecha.month,
        d.fecha.day,
      ).subtract(Duration(days: d.fecha.weekday - 1));
      if (lunes.year != mes.year || lunes.month != mes.month) continue;
      porLunes.putIfAbsent(lunes, () => []).add(d);
    }
    if (porLunes.isEmpty) return [semanaEnCurso];
    final lunes = porLunes.keys.toList()..sort();
    return [for (final l in lunes) porLunes[l]!];
  }

  /// Los días de [semanasDelMes], aplanados y en orden.
  ///
  /// Es lo que se le pasa a un widget que agrupa por su cuenta: así
  /// cuenta las mismas semanas que la gráfica y las numera igual, sin
  /// tener que repetir la regla.
  List<DiaActividad> get diasDeLasSemanasDelMes => [
    for (final semana in semanasDelMes) ...semana,
  ];

  factory Historial.desdeJson(Map<String, dynamic> j) => Historial(
    zonaHoraria: j['zona_horaria'] as String,
    dias: (j['dias'] as List)
        .map((d) => DiaActividad.desdeJson(d as Map<String, dynamic>))
        .toList(),
  );
}

/// Un lote de monedas con su fecha de caducidad. Las monedas caducan al
/// CERRAR LA TEMPORADA en que se ganaron (reunión del 2 de octubre de
/// 2026; antes eran 90 días desde que se acuñaban).
///
/// Quién calcula la fecha: el backend. Acá solo se lee `caducan`, nunca
/// se calcula el cierre de la temporada en el teléfono — si el plazo
/// cambia otra vez, la app no tiene que enterarse.
class LoteMonedas {
  const LoteMonedas({
    required this.cantidad,
    required this.caducan,
    required this.diasParaCaducar,
  });

  final int cantidad;
  final String caducan;
  final int diasParaCaducar;

  factory LoteMonedas.desdeJson(Map<String, dynamic> j) => LoteMonedas(
    cantidad: j['cantidad'] as int,
    caducan: j['caducan'] as String,
    diasParaCaducar: j['dias_para_caducar'] as int,
  );
}

/// Saldo de MONEDAS. Nunca se mezcla con puntos: las monedas se gastan,
/// los puntos no; las monedas viven en Premios, los puntos en Mi Plan.
class SaldoMonedas {
  const SaldoMonedas({required this.saldo, required this.lotes});

  final int saldo;

  final List<LoteMonedas> lotes;

  LoteMonedas? get proximoLoteACaducar {
    if (lotes.isEmpty) return null;
    final ordenados = [...lotes]
      ..sort((a, b) => a.diasParaCaducar.compareTo(b.diasParaCaducar));
    return ordenados.first;
  }

  factory SaldoMonedas.desdeJson(Map<String, dynamic> j) => SaldoMonedas(
    saldo: j['saldo'] as int,
    lotes: (j['lotes'] as List)
        .map((l) => LoteMonedas.desdeJson(l as Map<String, dynamic>))
        .toList(),
  );
}

/// UN objetivo de la semana.
///
/// Son DOS por semana: pasos y minutos de entrenamiento. CADA UNO PAGA
/// SUS PROPIAS MONEDAS al cumplirse (reunión del 2 de octubre de 2026;
/// antes solo pagaba cumplir los dos juntos). La semana se marca
/// completada solo cuando están los dos (ver [SemanaObjetivos.cumplida]).
class ObjetivoSemanal {
  const ObjetivoSemanal({
    required this.id,
    required this.nombre,
    required this.progreso,
    required this.meta,
    required this.unidad,
    required this.completo,
    required this.monedas,
  });

  /// Identificador estable. Es lo que viaja en el JSON, nunca el nombre
  /// visible.
  final String id;

  final String nombre;
  final int progreso;

  /// Cuánto pide el objetivo esa semana.
  ///
  /// Null mientras la tabla de metas por semana no esté definida. La UI
  /// muestra "En curso", nunca un número inventado.
  final int? meta;

  final String unidad;

  final bool completo;

  /// MONEDAS que paga este objetivo si se cumple.
  ///
  /// Las decide el SERVIDOR, semana por semana y objetivo por objetivo:
  /// la app no tiene ninguna regla para calcularlas y no inventa una.
  final int monedas;

  factory ObjetivoSemanal.desdeJson(Map<String, dynamic> j) => ObjetivoSemanal(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    progreso: j['progreso'] as int,
    meta: j['meta'] as int?,
    unidad: j['unidad'] as String,
    completo: j['completo'] as bool,
    monedas: j['monedas'] as int? ?? 0,
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

/// Una semana con sus dos objetivos.
///
/// Los dos son de la MISMA semana y se evalúan de una sola vez, el
/// domingo 23:59 (hora de Guatemala). Al cerrar, todos pasan a la semana
/// siguiente de la temporada, la hayan cumplido o no: el calendario
/// avanza solo.
class SemanaObjetivos {
  const SemanaObjetivos({
    required this.numero,
    required this.cierra,
    required this.estado,
    required this.objetivos,
    this.patrocinio,
  });

  /// Número de semana dentro del programa: 1, 2, 3…
  final int numero;

  /// Domingo 23:59 en que se evalúa.
  final DateTime cierra;

  final EstadoSemana estado;
  final List<ObjetivoSemanal> objetivos;

  /// MONEDAS que puede pagar la semana entera: la suma de lo que paga
  /// cada objetivo. Cada uno se cobra por separado.
  int get monedas => objetivos.fold(0, (suma, o) => suma + o.monedas);

  /// La marca aliada que compró ESTA semana, si alguna la compró.
  ///
  /// NO todas las semanas tienen: solo las que una alianza pagó por
  /// destacar. Null es el caso normal y la semana tiene que verse igual
  /// de terminada sin logo — nada puede cambiar de tamaño ni de lugar
  /// según si la semana está vendida.
  ///
  /// Completar una semana patrocinada (los dos objetivos) paga el cupón
  /// de esa marca ADEMÁS de las [monedas]: el patrocinio suma un premio,
  /// no cambia la mecánica.
  final Patrocinio? patrocinio;

  /// Cuántos objetivos van cumplidos.
  int get cumplidos => objetivos.where((o) => o.completo).length;

  /// Si están los dos: es lo único que marca la semana como COMPLETADA.
  /// Las monedas no dependen de esto, cada objetivo paga las suyas.
  bool get cumplida => objetivos.isNotEmpty && cumplidos == objetivos.length;

  /// Lo que la semana YA PAGÓ: las monedas de cada objetivo cumplido, si
  /// la semana cerró. Una semana en curso todavía no pagó nada — se
  /// evalúa el domingo 23:59.
  int get monedasGanadas => estado == EstadoSemana.cerrada
      ? objetivos
            .where((o) => o.completo)
            .fold(0, (suma, o) => suma + o.monedas)
      : 0;

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
    patrocinio: j['patrocinio'] == null
        ? null
        : Patrocinio.desdeJson(j['patrocinio'] as Map<String, dynamic>),
  );
}

/// Una temporada del año.
///
/// El año se divide en 4 temporadas de 13 semanas (reunión del 2 de
/// octubre de 2026). Las monedas que se ganan en una temporada vencen
/// cuando esa temporada cierra: hay que gastarlas antes.
///
/// Las fechas las manda el SERVIDOR. El teléfono nunca calcula en qué
/// temporada va: con el reloj del sistema se podría adelantar el cierre.
class Temporada {
  const Temporada({
    required this.numero,
    required this.inicia,
    required this.cierra,
  });

  /// 1 a 4.
  final int numero;

  /// Lunes 00:00 en que arranca.
  final DateTime inicia;

  /// Domingo 23:59 en que cierra y vencen sus monedas.
  final DateTime cierra;

  factory Temporada.desdeJson(Map<String, dynamic> j) => Temporada(
    numero: j['numero'] as int,
    inicia: DateTime.parse(j['inicia'] as String),
    cierra: DateTime.parse(j['cierra'] as String),
  );
}

/// Bloque de "Esta semana" de Home: las semanas de la temporada, cada
/// una con sus dos objetivos.
class ObjetivosSemana {
  const ObjetivosSemana({required this.semanas, this.temporada});

  /// Las semanas de la temporada (13). La app NO asume cuántas son:
  /// renderiza las que vengan.
  final List<SemanaObjetivos> semanas;

  /// La temporada en curso. Null si el servidor todavía no la manda.
  final Temporada? temporada;

  /// MONEDAS acuñadas en el programa con los objetivos.
  ///
  /// NO es el saldo de la billetera: el saldo incluye monedas de antes y
  /// descuenta lo gastado en Premios.
  int get monedasGanadas =>
      semanas.fold(0, (suma, s) => suma + s.monedasGanadas);

  /// La semana en curso, o null si el programa ya cerró.
  SemanaObjetivos? get enCurso {
    for (final s in semanas) {
      if (s.estado == EstadoSemana.enCurso) return s;
    }
    return null;
  }

  factory ObjetivosSemana.desdeJson(Map<String, dynamic> j) => ObjetivosSemana(
    temporada: j['temporada'] == null
        ? null
        : Temporada.desdeJson(j['temporada'] as Map<String, dynamic>),
    semanas: (j['semanas'] as List)
        .map((s) => SemanaObjetivos.desdeJson(s as Map<String, dynamic>))
        .toList(),
  );
}

/// Cashback anual proyectado.
class Cashback {
  const Cashback({required this.porcentaje, required this.proyectadoQ});

  final double porcentaje;
  final int proyectadoQ;

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
    required this.nivel,
    required this.cashback,
    required this.puntosSemana,
    required this.puntosSemanaAnterior,
    required this.puntosMes,
    required this.rachaSemanas,
    required this.rachaHistorial,
    required this.monedas,
    required this.objetivosSemana,
    required this.actividadPorMes,
    required this.mesActualIndice,
    required this.monedasGanadasAnio,
  });

  final int anio;
  final int puntosAno;
  final int techoAnual;

  /// Nivel numérico 0–4 del esquema propio. El contrato prohíbe el
  /// naming Bronze/Silver/Gold/Platinum.
  final int nivel;

  final Cashback cashback;
  final int puntosSemana;
  final int puntosSemanaAnterior;
  final int puntosMes;
  final int rachaSemanas;
  final List<bool> rachaHistorial;
  final SaldoMonedas monedas;
  final ObjetivosSemana objetivosSemana;

  /// Puntos por mes del año en curso, de enero a diciembre.
  final List<int> actividadPorMes;

  /// Índice (0 = enero) del mes en curso.
  final int mesActualIndice;

  final int monedasGanadasAnio;

  factory ResumenAnual.desdeJson(Map<String, dynamic> j) {
    final sem = j['semana_actual'] as Map<String, dynamic>;
    final anual = j['actividad_anual'] as Map<String, dynamic>;
    return ResumenAnual(
      actividadPorMes: (anual['por_mes'] as List).cast<int>(),
      mesActualIndice: anual['mes_actual_indice'] as int,
      monedasGanadasAnio: j['monedas_ganadas_anio'] as int,
      anio: j['anio'] as int,
      puntosAno: j['puntos_ano'] as int,
      techoAnual: j['techo_anual'] as int,
      nivel: j['nivel'] as int,
      cashback: Cashback.desdeJson(j['cashback'] as Map<String, dynamic>),
      puntosSemana: sem['puntos'] as int,
      puntosSemanaAnterior: sem['puntos_semana_anterior'] as int,
      puntosMes: (j['mes_actual'] as Map<String, dynamic>)['puntos'] as int,
      rachaSemanas: j['racha_semanas'] as int,
      rachaHistorial: (j['racha_historial'] as List).cast<bool>(),
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
    this.fechaNacimiento,
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

  /// La fecha de nacimiento que CONFIRMA la aseguradora ("14 mar 1981").
  /// Es la que manda para la edad —la FCmáx, el bono 60+ y la meta de
  /// pasos— una vez que la póliza está verificada. Null si todavía no
  /// llegó.
  final String? fechaNacimiento;

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
    fechaNacimiento: j['fecha_nacimiento'] as String?,
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
    this.foto,
    this.fondo,
    this.destacado = false,
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

  /// Ruta del asset con el logo del comercio, o null si todavía no hay.
  ///
  /// Opcional a propósito: un premio sin logo tiene que seguir saliendo
  /// en el catálogo con el placeholder, no desaparecer ni reventar.
  final String? foto;

  /// Color de fondo detrás del logo, en hex "#RRGGBB".
  ///
  /// Null (blanco) sirve para casi todos. Se pone solo cuando el logo es
  /// claro y necesita fondo oscuro para leerse: Montanos y Frutalle son
  /// blancos sobre negro y sobre blanco desaparecen.
  ///
  /// Queda como String y no como Color a propósito: este archivo no
  /// importa Flutter, y el que sabe de colores es el widget.
  final String? fondo;

  /// El comercio compró visibilidad: su tarjeta va ancha en el mosaico.
  ///
  /// Es una de las tres vías de ingreso del producto (alianzas), así que
  /// vale que se vea más grande y no solo más arriba. Falso por defecto:
  /// **un catálogo sin ningún destacado es el caso normal** y tiene que
  /// verse entero, sin huecos ni cartel que anuncie la ausencia.
  ///
  /// [PENDIENTE: hoy sale del mock. Qué comercio está vendido lo tiene
  /// que decir el endpoint de patrocinios que debe Luis — el mismo que
  /// falta para las semanas y los ciclos de liga.]
  final bool destacado;

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
    foto: j['foto'] as String?,
    fondo: j['fondo'] as String?,
    destacado: j['destacado'] as bool? ?? false,
  );
}

/// Catálogo de premios con sus filtros.
class Catalogo {
  Catalogo({
    required this.categorias,
    required this.premios,
    List<CuponCanjeado>? cupones,
  }) : cupones = cupones ?? [];

  final List<String> categorias;
  final List<Premio> premios;

  /// Los cupones del usuario: los que compró en la tienda y los que ganó
  /// por una semana o un podio patrocinado. Crece al canjear, por eso no
  /// es `const`.
  final List<CuponCanjeado> cupones;

  factory Catalogo.desdeJson(Map<String, dynamic> j) => Catalogo(
    categorias: (j['categorias'] as List).cast<String>(),
    premios: (j['premios'] as List)
        .map((p) => Premio.desdeJson(p as Map<String, dynamic>))
        .toList(),
    cupones: ((j['mis_cupones'] as List?) ?? const [])
        .map((c) => CuponCanjeado.desdeJson(c as Map<String, dynamic>))
        .toList(),
  );
}

// ---- Cupones canjeados ----

/// De dónde salió un cupón. Todos viven en el mismo lugar —Premios › Mis
/// cupones—, pero el usuario tiene que poder reconocer el que ganó sin
/// gastar monedas.
enum OrigenCupon {
  /// Lo compró con monedas en la tienda.
  tienda,

  /// Lo ganó al cumplir una semana patrocinada.
  semana,

  /// Lo ganó en el podio de un ciclo de La Liga patrocinado.
  liga;

  static OrigenCupon desde(String? s) => switch (s) {
    'semana' => OrigenCupon.semana,
    'liga' => OrigenCupon.liga,
    _ => OrigenCupon.tienda,
  };
}

enum EstadoCupon {
  activo,
  usado,
  vencido;

  static EstadoCupon desde(String? s) => switch (s) {
    'usado' => EstadoCupon.usado,
    'vencido' => EstadoCupon.vencido,
    _ => EstadoCupon.activo,
  };
}

/// Un cupón que el usuario ya tiene: el código que se muestra en caja.
///
/// Un cupón canjeado caduca a los 60 DÍAS de canjeado (CLAUDE.md), aparte
/// de las monedas. Igual que con los lotes de monedas, quien calcula el
/// vencimiento y los días que faltan es el backend: acá solo se leen.
class CuponCanjeado {
  const CuponCanjeado({
    required this.id,
    required this.comercio,
    required this.beneficio,
    required this.codigo,
    required this.origen,
    required this.canjeado,
    required this.vence,
    required this.diasParaVencer,
    required this.estado,
    this.foto,
    this.fondo,
    this.costoMonedas,
    this.ganadoEn,
    this.usadoEl,
  });

  final String id;
  final String comercio;

  /// Lo que da el cupón, en palabras del comercio: "2x1 en sushi".
  final String beneficio;

  /// Lo que lee la caja. Hoy se dibuja como un QR de muestra.
  final String codigo;

  final OrigenCupon origen;

  /// Fechas "AAAA-MM-DD", en hora de Guatemala.
  final String canjeado;
  final String vence;
  final int diasParaVencer;
  final EstadoCupon estado;

  final String? foto;
  final String? fondo;

  /// Cuántas monedas costó. Null en los que se ganaron.
  final int? costoMonedas;

  /// Dónde se ganó, si no se compró: "Semana 1", "La Liga de agosto".
  final String? ganadoEn;

  final String? usadoEl;

  bool get activo => estado == EstadoCupon.activo;

  /// A una semana de vencer: es la única alerta real de un cupón, y va
  /// en naranja.
  bool get porVencer => activo && diasParaVencer <= 7;

  factory CuponCanjeado.desdeJson(Map<String, dynamic> j) => CuponCanjeado(
    id: j['id'] as String,
    comercio: j['comercio'] as String,
    beneficio: j['beneficio'] as String,
    codigo: j['codigo'] as String,
    origen: OrigenCupon.desde(j['origen'] as String?),
    canjeado: j['canjeado'] as String,
    vence: j['vence'] as String,
    diasParaVencer: j['dias_para_vencer'] as int,
    estado: EstadoCupon.desde(j['estado'] as String?),
    foto: j['foto'] as String?,
    fondo: j['fondo'] as String?,
    costoMonedas: j['costo_monedas'] as int?,
    ganadoEn: j['ganado_en'] as String?,
    usadoEl: j['usado_el'] as String?,
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

/// Una marca aliada que paga por aparecer.
///
/// Vive acá y no en cada pantalla porque patrocina dos cosas distintas
/// con la misma forma: un ciclo de la liga (ver [GrupoRanking.patrocinio])
/// y una semana del programa (ver `SemanaObjetivos.patrocinio`).
///
/// SIEMPRE llega del backend. Que hoy salga del mock es circunstancial:
/// ninguna pantalla escribe el nombre de una marca a mano.
class Patrocinio {
  const Patrocinio({
    required this.id,
    required this.marca,
    required this.logo,
    required this.cupon,
    this.fotos = const [],
    this.fondo,
    this.acento,
  });

  /// El id del comercio, el MISMO que usa el catálogo de Premios.
  ///
  /// Sirve para poder llevar al usuario al premio de esa marca sin tener
  /// que adivinarlo por el nombre.
  final String id;

  /// El nombre de la marca, tal como se muestra.
  final String marca;

  /// Ruta de la foto del local. Hoy es un asset local del catálogo de
  /// Premios; con el backend va a ser una URL y solo cambia quién
  /// resuelve la imagen.
  final String logo;

  /// Las fotos del premio, las que rota el carrusel de la semana.
  ///
  /// Vienen de los datos y NO se arman en el widget. Si no llega ninguna,
  /// el carrusel usa [logo] sola y se queda quieto.
  ///
  /// [PENDIENTE: Diego consigue las fotos de cada premio. Hasta entonces
  /// el mock repite la del catálogo de Premios.]
  final List<String> fotos;

  /// Qué se lleva quien cumpla: el texto del cupón de ESTA marca. Se
  /// suma a las monedas, nunca las reemplaza.
  final String cupon;

  /// Color DETRÁS de la foto, en hex "#RRGGBB". Es el mismo campo que ya
  /// trae el catálogo de Premios y existe por una razón concreta: los
  /// logos blancos sobre fondo transparente desaparecen si se los pone
  /// sobre blanco. Null quiere decir blanco.
  final String? fondo;

  /// Color de marca para los detalles: el anillo del nodo y el borde del
  /// cupón. En hex "#RRGGBB", o null para usar el azul de +Vida.
  ///
  /// Va SEPARADO de [fondo] a propósito. `fondo` es el color sobre el que
  /// se lee el logo —el de Montanos es negro— y un anillo negro sobre una
  /// pantalla clara no transmite calma, que es lo que pide el sistema de
  /// diseño. Con dos campos, la marca elige con qué acento aparece sin
  /// arrastrar el color de su fondo.
  final String? acento;

  factory Patrocinio.desdeJson(Map<String, dynamic> j) => Patrocinio(
    // El id es nuevo. Los patrocinios que un cliente viejo tenga
    // guardados no lo traen, así que se cae al nombre en minúsculas en
    // vez de reventar.
    id: (j['id'] ?? (j['marca'] as String).toLowerCase()) as String,
    marca: j['marca'] as String,
    logo: j['logo'] as String,
    cupon: j['cupon'] as String,
    fotos: ((j['fotos'] as List?) ?? const []).cast<String>(),
    fondo: j['fondo'] as String?,
    acento: j['acento'] as String?,
  );

  Map<String, dynamic> aJson() => {
    'id': id,
    'marca': marca,
    'logo': logo,
    'cupon': cupon,
    if (fotos.isNotEmpty) 'fotos': fotos,
    if (fondo != null) 'fondo': fondo,
    if (acento != null) 'acento': acento,
  };
}

/// Cada cuánto cierra un ranking y se reparten los premios.
///
/// Hoy hay uno solo: La Liga y las competencias que arma el usuario con
/// su gente corren las dos por MES, del día 1 al último día del mes en
/// hora de Guatemala (decisión de Alvaro, 22 de septiembre de 2026). La
/// liga trimestral de antes es del modelo viejo. El enum se queda para
/// que el ciclo siga viniendo del backend y no quede fijo en la UI.
///
/// No es el ciclo SEMANAL de los objetivos, que es otra
/// mecánica y vive en [SemanaObjetivos]. Si algún día se tocan, se tocan
/// ahí, no acá.
enum CicloRanking {
  mes('este mes');

  const CicloRanking(this.cuando);

  /// Cómo se dice el período en curso dentro de una frase: "este mes".
  final String cuando;

  static CicloRanking desde(String? s) => CicloRanking.mes;
}

class RankingPersona {
  const RankingPersona({
    required this.nombre,
    required this.puntosPeriodo,
    required this.tendencia,
    required this.esUsuario,
  });

  final String nombre;

  /// Puntos acumulados en el ciclo del grupo (ver [GrupoRanking.ciclo]):
  /// del mes, tanto en una competencia personal como en la liga.
  ///
  /// Antes eran los de la SEMANA, y era un bug: ningún ranking del
  /// producto corre por semana. Lo semanal son los retos, que no son
  /// esto.
  ///
  /// SIEMPRE se usan para ordenar. Si se MUESTRAN o no lo decide el
  /// grupo (ver [GrupoRanking.mostrarPuntos]): entre conocidos se pueden
  /// ver, con desconocidos nunca.
  ///
  /// EL ORDEN LO MANDA EL SERVIDOR y la app no lo toca: por puntos y, si
  /// dos empatan, gana quien caminó más pasos en el mes (reunión del 2 de
  /// octubre de 2026). Los pasos de los demás nunca llegan al teléfono:
  /// el usuario solo ve que alguien con sus mismos puntos va arriba.
  final int puntosPeriodo;

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
      // `puntos_semana` es la clave vieja. Se sigue leyendo porque los
      // grupos que el usuario ya creó están guardados en su teléfono con
      // ese nombre (ver `AlmacenSocial`): quitarla le vaciaría los
      // grupos al actualizar la app. Escribir, se escribe la nueva.
      puntosPeriodo:
          (campos['puntos_periodo'] ?? campos['puntos_semana']) as int,
      nombre: campos['nombre'] as String,
      tendencia: Tendencia.desde(campos['tendencia'] as String? ?? 'igual'),
      esUsuario: esUsuario,
    );
  }

  Map<String, dynamic> aJson() => {
    'nombre': nombre,
    'puntos_periodo': puntosPeriodo,
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
    this.ciclo = CicloRanking.mes,
    this.franjaEdad,
    this.arranca,
    this.cierra,
    this.premiosMonedas = const [],
    this.patrocinio,
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
  /// SIEMPRE true: en todo ranking —La Liga y Tus Ligas— se ven los
  /// puntos de cada participante (reunión del 2 de octubre de 2026). Lo
  /// que nunca se muestra son los pasos de nadie: el servidor los usa
  /// solo para desempatar. El campo `mostrar_puntos` de un JSON viejo se
  /// lee pero ya no manda.
  bool get mostrarPuntos => true;
  final bool _mostrarPuntos;

  final List<RankingPersona> miembros;

  /// Cada cuánto cierra este ranking.
  ///
  /// Todo corre por MES: La Liga del 1 al último día del mes, y las
  /// competencias que arma el usuario, un mes desde que se crean.
  final CicloRanking ciclo;

  /// Del modelo viejo: La Liga se sorteaba por franja de edad de 10 años.
  /// Desde el 2 de octubre de 2026 es UN SOLO GRUPO con todos los
  /// usuarios con póliza verificada, así que el servidor ya no la manda y
  /// la app no la muestra. Se sigue leyendo para no romper con un JSON
  /// viejo.
  final String? franjaEdad;

  /// Cuándo arrancó el ciclo en curso. Con [cierra] arma el rango que se
  /// le muestra al usuario ("del 1 al 30 de septiembre"), que es lo que
  /// hace entender que la liga dura el mes y no una semana.
  ///
  /// Las dos fechas las manda el backend en hora de Guatemala: el ciclo
  /// va del día 1 al último día del mes, y el teléfono
  /// NUNCA las calcula. Alguien de viaje tiene que ver el mismo cierre.
  final DateTime? arranca;

  /// Cuándo cierra y se reparten los premios.
  final DateTime? cierra;

  /// MONEDAS que se lleva cada podio, del 1.o al 3.o. Vacío si el grupo
  /// no premia. Nunca puntos: los puntos no se regalan por competir.
  final List<int> premiosMonedas;

  /// La marca que patrocina el ciclo en curso, si alguna lo hace.
  ///
  /// Los tres del podio se llevan un cupón de esta marca ADEMÁS de sus
  /// monedas: el patrocinio suma un premio, no reemplaza el de siempre.
  ///
  /// Null es el caso normal, no un error: un ciclo sin marca vendida se
  /// juega igual y la pantalla no puede cambiar de forma por eso.
  final Patrocinio? patrocinio;

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
      ciclo: CicloRanking.desde(
        // Un grupo normal trae el ciclo arriba; la liga, adentro de su
        // bloque. Si no viene ninguno queda mensual, que es lo que dura
        // todo lo que crea el usuario.
        (j['ciclo'] ?? liga['ciclo']) as String?,
      ),
      franjaEdad: liga['franja_edad'] as String?,
      arranca: liga['arranca'] == null
          ? null
          : DateTime.tryParse(liga['arranca'] as String),
      cierra: liga['cierra'] == null
          ? null
          : DateTime.tryParse(liga['cierra'] as String),
      premiosMonedas: ((liga['premios_monedas'] as List?) ?? const [])
          .cast<int>()
          .toList(),
      patrocinio: liga['patrocinio'] == null
          ? null
          : Patrocinio.desdeJson(liga['patrocinio'] as Map<String, dynamic>),
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
    'ciclo': ciclo.name,
    'miembros': miembros.map((m) => m.aJson()).toList(),
    if (franjaEdad != null ||
        arranca != null ||
        cierra != null ||
        premiosMonedas.isNotEmpty ||
        patrocinio != null)
      'liga': {
        if (franjaEdad != null) 'franja_edad': franjaEdad,
        if (arranca != null) 'arranca': arranca!.toIso8601String(),
        if (cierra != null) 'cierra': cierra!.toIso8601String(),
        if (premiosMonedas.isNotEmpty) 'premios_monedas': premiosMonedas,
        if (patrocinio != null) 'patrocinio': patrocinio!.aJson(),
      },
    if (creadoPorMi) 'creado_por_mi': true,
    if (_codigo != null) 'codigo': _codigo,
  };
}

/// Lo que hay en Social: el ranking y nada más. Los amigos, las
/// solicitudes y los duelos se sacaron el 25 de septiembre de 2026.
class DatosSociales {
  DatosSociales({required this.grupos});

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
    // Los datos del usuario se escriben una sola vez y cada grupo los
    // hereda: así sus puntos no quedan repetidos (y desincronizables) en
    // cada ranking.
    final yo = j['yo'] as Map<String, dynamic>?;

    return DatosSociales(
      grupos: (j['grupos'] as List)
          .map((g) => GrupoRanking.desdeJson(g as Map<String, dynamic>, yo: yo))
          .toList(),
    );
  }
}
