/// Motor de los OBJETIVOS SEMANALES y la escalera de RANGO.
///
/// Reglas cerradas que implementa este archivo:
///
///   - Los objetivos son SEMANALES. No existen objetivos mensuales.
///   - Hay 3 objetivos por semana, y los tres son de la MISMA semana.
///   - La semana va de lunes 00:00 a domingo 23:59 (hora de Guatemala) y
///     se evalúa UNA sola vez, el domingo 23:59.
///   - Cumplir 1 o 2 objetivos: gana MONEDAS, el rango NO sube.
///   - Cumplir los 3: sube un rango.
///   - No cumplir los 3: baja un rango.
///   - Piso [rangoMinimo], techo [rangoMaximo].
///   - Máximo UN movimiento por semana, para arriba o para abajo.
///   - Al empezar un mes nuevo, todos vuelven al piso.
///
/// REGLA DURA — el rango paga MONEDAS, nunca PUNTOS. Los puntos son los
/// que mueven el nivel de cashback anual: si el rango diera puntos,
/// estaría moviendo el cashback. Las dos monedas del producto no se
/// mezclan nunca. Por eso en este archivo no aparece la palabra "puntos"
/// ni se importa `reglas_puntos.dart`.
library;

// ============================================================
// La escalera de rango.
// ============================================================

/// Piso de la escalera. De acá no se baja, por más semanas seguidas que
/// se fallen.
const int rangoMinimo = 1;

/// Techo de la escalera.
const int rangoMaximo = 4;

/// Cuántos objetivos hay por semana.
const int objetivosPorSemana = 3;

// ============================================================
// Los 3 objetivos de la semana.
// ============================================================

/// Definición de UN objetivo semanal.
///
/// Los tres objetivos son CONFIGURABLES: entran como datos, no como
/// código. Cambiar cuáles son los tres no toca el motor de reglas.
///
/// Los que se manejan hoy (pasos semanales, intensidad, y sostener ritmo
/// cardíaco alto 4 días) son PROVISIONALES: todavía no están definidos.
class DefinicionObjetivo {
  const DefinicionObjetivo({
    required this.id,
    required this.nombre,
    required this.unidad,
    required this.metaPorRango,
  });

  /// Identificador estable. Es lo que viaja en el JSON y lo que se usa
  /// para casar un objetivo con su avance, nunca el nombre visible.
  final String id;

  /// Cómo se le dice al usuario. Puede cambiar sin romper nada.
  final String nombre;

  /// Qué se cuenta: "pasos", "minutos", "días"…
  final String unidad;

  /// Cuánto pide el objetivo en cada rango, indexado por número de rango.
  ///
  /// Vacío mientras la dificultad por rango no esté definida. Un objetivo
  /// sin meta para el rango en curso NO se puede evaluar, y el motor lo
  /// dice en vez de inventar un número (ver [ResultadoSemana.evaluable]).
  final Map<int, int> metaPorRango;

  /// Cuánto pide este objetivo en [rango], o null si no está definido.
  int? metaPara(int rango) => metaPorRango[rango];

  factory DefinicionObjetivo.desdeJson(Map<String, dynamic> j) =>
      DefinicionObjetivo(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        unidad: j['unidad'] as String,
        metaPorRango:
            (j['meta_por_rango'] as Map?)?.map(
              (k, v) => MapEntry(int.parse(k as String), v as int),
            ) ??
            const {},
      );
}

/// Los tres objetivos vigentes.
///
/// PROVISIONALES. `metaPorRango` va vacío a propósito: la tabla de
/// dificultad por rango no está definida en ninguna fuente y no se
/// inventa acá. Cuando exista, entra como dato —de la API o de este
/// mismo literal— sin tocar el motor.
const List<DefinicionObjetivo> objetivosProvisionales = [
  DefinicionObjetivo(
    id: 'pasos_semana',
    nombre: 'Pasos de la semana',
    unidad: 'pasos',
    metaPorRango: {},
  ),
  DefinicionObjetivo(
    id: 'intensidad_semana',
    nombre: 'Minutos de intensidad',
    unidad: 'minutos',
    metaPorRango: {},
  ),
  DefinicionObjetivo(
    id: 'dias_ritmo_alto',
    nombre: 'Días con ritmo cardíaco alto',
    unidad: 'días',
    metaPorRango: {},
  ),
];

/// El avance del usuario en un objetivo, al cierre de la semana.
class AvanceObjetivo {
  const AvanceObjetivo({required this.id, required this.logrado});

  /// El [DefinicionObjetivo.id] al que corresponde este avance.
  final String id;

  /// Cuánto acumuló el usuario en la semana.
  final int logrado;
}

// ============================================================
// A qué mes pertenece una semana.
// ============================================================

/// Cómo se decide a qué mes pertenece una semana partida entre dos meses.
///
/// Existe porque los meses NO tienen 4 semanas exactas: varios tienen 5
/// lunes, y una semana puede arrancar en enero y cerrar en febrero.
enum ReglaMesDeLaSemana {
  /// La semana pertenece al mes de su DOMINGO (el día en que se evalúa).
  porDomingo,

  /// La semana pertenece al mes de su LUNES (el día en que arranca).
  porLunes,
}

/// Regla vigente.
///
/// [PENDIENTE DE CONFIRMAR] Daniel propuso [ReglaMesDeLaSemana.porDomingo]
/// con el argumento de que el domingo es cuando se evalúa. El motor
/// soporta las dos y hay tests para ambas, así que cambiar de una a la
/// otra es cambiar esta única línea.
const ReglaMesDeLaSemana reglaMesVigente = ReglaMesDeLaSemana.porDomingo;

/// Lunes 00:00 de la semana que contiene a [dia].
DateTime lunesDeLaSemana(DateTime dia) {
  final soloFecha = DateTime(dia.year, dia.month, dia.day);
  // DateTime.monday == 1, así que restar (weekday - 1) cae siempre en lunes.
  return soloFecha.subtract(Duration(days: soloFecha.weekday - 1));
}

/// Domingo de la semana que contiene a [dia], a las 23:59:59.
///
/// Es el instante de evaluación de la semana.
DateTime domingoDeLaSemana(DateTime dia) {
  final lunes = lunesDeLaSemana(dia);
  final domingo = lunes.add(const Duration(days: 6));
  return DateTime(domingo.year, domingo.month, domingo.day, 23, 59, 59);
}

/// A qué mes pertenece la semana que contiene a [dia].
///
/// Devuelve el primer día de ese mes, para poder comparar dos semanas sin
/// preocuparse por el año.
///
/// Una semana pertenece a UN solo mes, nunca a los dos: eso es justamente
/// lo que resuelve [reglaMesVigente].
DateTime mesDeLaSemana(DateTime dia, {ReglaMesDeLaSemana? regla}) {
  final cual = regla ?? reglaMesVigente;
  final ancla = switch (cual) {
    ReglaMesDeLaSemana.porDomingo => domingoDeLaSemana(dia),
    ReglaMesDeLaSemana.porLunes => lunesDeLaSemana(dia),
  };
  return DateTime(ancla.year, ancla.month);
}

/// True si la semana de [dia] cae en un mes distinto al de [semanaPrevia].
///
/// Es lo que dispara el reinicio del rango: al empezar un mes nuevo,
/// todos vuelven al piso.
bool empiezaMesNuevo(DateTime dia, DateTime semanaPrevia) =>
    mesDeLaSemana(dia) != mesDeLaSemana(semanaPrevia);

// ============================================================
// Evaluación de la semana.
// ============================================================

/// Qué le pasó al rango del usuario esta semana.
enum MovimientoRango { sube, baja, seQueda }

/// El resultado del cierre de una semana.
class ResultadoSemana {
  const ResultadoSemana({
    required this.rangoPrevio,
    required this.rangoNuevo,
    required this.movimiento,
    required this.objetivosCumplidos,
    required this.ganaMonedas,
    required this.evaluable,
    required this.reinicioPorMesNuevo,
  });

  final int rangoPrevio;
  final int rangoNuevo;
  final MovimientoRango movimiento;

  /// Cuántos de los tres objetivos cumplió.
  final int objetivosCumplidos;

  /// Cumplir 1 o 2 objetivos acuña MONEDAS (nunca puntos). Cumplir los 3
  /// también, además de subir el rango.
  final bool ganaMonedas;

  /// False cuando algún objetivo no tiene meta definida para el rango en
  /// curso. En ese caso el rango NO se mueve: es preferible congelarlo a
  /// castigar o premiar a alguien contra un número que no existe.
  final bool evaluable;

  /// True cuando la semana arranca un mes nuevo y el rango volvió al piso.
  final bool reinicioPorMesNuevo;
}

/// Cierra una semana y devuelve el rango resultante.
///
/// [cierre] es el domingo que se está evaluando; [cierrePrevio], el de la
/// semana anterior (null si es la primera semana del usuario).
///
/// El movimiento es de UN escalón como máximo, para arriba o para abajo:
/// no importa por cuánto se pasó ni por cuánto falló.
ResultadoSemana evaluarSemana({
  required int rangoPrevio,
  required List<DefinicionObjetivo> objetivos,
  required List<AvanceObjetivo> avances,
  required DateTime cierre,
  DateTime? cierrePrevio,
}) {
  // 1. El mes nuevo manda sobre todo lo demás: primero se vuelve al piso
  //    y recién desde ahí se evalúa la semana.
  final reinicia =
      cierrePrevio != null && empiezaMesNuevo(cierre, cierrePrevio);
  final base = reinicia ? rangoMinimo : rangoPrevio;

  // 2. ¿Se puede evaluar? Un objetivo sin meta para este rango no se
  //    puede dar por cumplido ni por fallado.
  final porId = {for (final a in avances) a.id: a.logrado};
  var cumplidos = 0;
  var evaluable = objetivos.length == objetivosPorSemana;

  for (final o in objetivos) {
    final meta = o.metaPara(base);
    if (meta == null) {
      evaluable = false;
      continue;
    }
    if ((porId[o.id] ?? 0) >= meta) cumplidos++;
  }

  if (!evaluable) {
    return ResultadoSemana(
      rangoPrevio: rangoPrevio,
      rangoNuevo: base,
      movimiento: MovimientoRango.seQueda,
      objetivosCumplidos: cumplidos,
      // Sin poder evaluar tampoco se acuñan monedas: se pagaría por algo
      // que no se sabe si ocurrió.
      ganaMonedas: false,
      evaluable: false,
      reinicioPorMesNuevo: reinicia,
    );
  }

  // 3. Los tres: sube. Menos de tres: baja. Uno o dos igual pagan monedas.
  final todos = cumplidos == objetivosPorSemana;
  final rangoNuevo = todos
      ? (base + 1).clamp(rangoMinimo, rangoMaximo)
      : (base - 1).clamp(rangoMinimo, rangoMaximo);

  final movimiento = rangoNuevo > base
      ? MovimientoRango.sube
      : rangoNuevo < base
      ? MovimientoRango.baja
      : MovimientoRango.seQueda;

  return ResultadoSemana(
    rangoPrevio: rangoPrevio,
    rangoNuevo: rangoNuevo,
    movimiento: movimiento,
    objetivosCumplidos: cumplidos,
    ganaMonedas: cumplidos > 0,
    evaluable: true,
    reinicioPorMesNuevo: reinicia,
  );
}
