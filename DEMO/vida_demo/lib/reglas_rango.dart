/// Motor de los OBJETIVOS SEMANALES y la escalera de RANGO.
///
/// Reglas cerradas que implementa este archivo:
///
///   - El programa dura [semanasDelPrograma] semanas y la escalera tiene
///     [rangoMaximo] rangos: una semana, un rango.
///   - Los objetivos son SEMANALES. No existen objetivos mensuales.
///   - Hay [objetivosPorSemana] objetivos por semana, y los tres son de la
///     MISMA semana.
///   - La semana va de lunes 00:00 a domingo 23:59 (hora de Guatemala) y
///     se evalúa UNA sola vez, el domingo 23:59.
///   - Cumplir los TRES sube un rango. No cumplir los tres baja uno.
///   - SUBIR de rango es lo único que acuña MONEDAS, según
///     [monedasPorSubirA].
///   - Piso [rangoMinimo], techo [rangoMaximo].
///   - Máximo UN movimiento por semana, para arriba o para abajo.
///
/// REGLA DURA — el rango paga MONEDAS, nunca PUNTOS. Los puntos son los
/// que mueven el nivel de cashback anual: si el rango diera puntos,
/// estaría moviendo el cashback. Las monedas del producto no se mezclan
/// nunca con los puntos. Por eso en este archivo no aparece la palabra
/// "puntos" ni se importa `reglas_puntos.dart`.
///
/// ------------------------------------------------------------
/// DOS REGLAS QUE VIVÍAN ACÁ Y SE FUERON
/// ------------------------------------------------------------
///
/// **El XP.** Había un medidor de XP (100 por rango, repartido 40/35/25
/// entre los tres objetivos) que en teoría llenaba el rango. No decidía
/// nada: el movimiento siempre salió de `cumplidos == 3`, y el XP era
/// interfaz encima de tres checks. Peor: la barra de Home arrastraba el
/// sobrante de una semana a la siguiente ("dos semanas a medias valen un
/// rango"), y el motor nunca hizo eso — dos semanas a medias bajan el
/// rango dos veces. Eran dos reglas contradictorias y la pantalla mostraba
/// la que el motor no aplicaba. No volver a introducirlo.
///
/// **El reinicio mensual.** El rango volvía al piso al empezar mes nuevo.
/// Es incompatible con un programa de diez semanas corridas: diez semanas
/// cruzan dos veces de mes, así que nadie habría pasado del rango 4 y la
/// escalera de 10 era inalcanzable por construcción. El programa se
/// recorre entero de punta a punta; no se reinicia a mitad de camino.
library;

// ============================================================
// La escalera de rango.
// ============================================================

/// Cuántas semanas dura el programa.
///
/// Es el mismo número que [rangoMaximo] a propósito: una semana perfecta
/// vale exactamente un escalón, así que quien cumple todas las semanas
/// llega justo al techo. Hay un test que fija esa igualdad.
const int semanasDelPrograma = 10;

/// Piso de la escalera. Todos arrancan acá y de acá no se baja, por más
/// semanas seguidas que se fallen.
///
/// Es 0 y no 1: el rango 0 es "todavía no subiste ninguna vez", y así
/// subir al 1 ya es un logro que paga.
const int rangoMinimo = 0;

/// Techo de la escalera.
const int rangoMaximo = 10;

/// Cuántas MONEDAS acuña subir a [rango].
///
/// Cinco por escalón: subir al 1 paga 5, al 2 paga 10, al 3 paga 15, y
/// así hasta el 10, que paga 50. Recorrer la escalera entera de una
/// punta a la otra da 275 monedas.
///
/// Bajar de rango NO cobra nada: el castigo es tener que volver a
/// subirlo, no perder monedas ya acuñadas.
///
/// Devuelve 0 para el rango 0, que es el piso y no se "sube".
int monedasPorSubirA(int rango) {
  if (rango <= rangoMinimo || rango > rangoMaximo) return 0;
  return rango * 5;
}

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
// El calendario de la semana.
// ============================================================

/// Guatemala está en UTC−6 y no cambia de hora en todo el año.
const Duration desfaseDeGuatemala = Duration(hours: 6);

/// La misma fecha, leída como reloj de pared en Guatemala.
///
/// Hace falta porque `DateTime.parse` de una fecha con offset —como las
/// que manda el backend, `2026-09-20T23:59:59-06:00`— devuelve un
/// DateTime en UTC. Preguntarle el día directamente daba 21, no 20: el
/// domingo 23:59 de Guatemala ya es lunes en Londres.
///
/// No se usa `toLocal()` a propósito: eso daría la hora del teléfono, y
/// el ciclo de la semana está fijado en hora de Guatemala para todos los
/// usuarios. Alguien de viaje no tiene que ver otra fecha de cierre.
DateTime enHoraDeGuatemala(DateTime fecha) =>
    fecha.toUtc().subtract(desfaseDeGuatemala);

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
    required this.monedasGanadas,
    required this.evaluable,
  });

  final int rangoPrevio;
  final int rangoNuevo;
  final MovimientoRango movimiento;

  /// Cuántos de los tres objetivos cumplió.
  final int objetivosCumplidos;

  /// MONEDAS acuñadas esta semana (nunca puntos).
  ///
  /// Salen ÚNICAMENTE de subir de rango. Cumplir uno o dos objetivos no
  /// paga nada: el avance de la semana no se guarda ni se arrastra.
  final int monedasGanadas;

  /// Si esta semana acuñó monedas. Atajo para no repetir la comparación.
  bool get ganaMonedas => monedasGanadas > 0;

  /// False cuando algún objetivo no tiene meta definida para el rango en
  /// curso. En ese caso el rango NO se mueve: es preferible congelarlo a
  /// castigar o premiar a alguien contra un número que no existe.
  final bool evaluable;
}

/// Cierra una semana y devuelve el rango resultante.
///
/// El movimiento es de UN escalón como máximo, para arriba o para abajo:
/// no importa por cuánto se pasó ni por cuánto falló.
///
/// No recibe fechas: desde que murió el reinicio mensual, el resultado no
/// depende de en qué semana del calendario estemos. Cuándo se evalúa lo
/// dice [domingoDeLaSemana]; qué pasa al evaluar lo dice esta función.
ResultadoSemana evaluarSemana({
  required int rangoPrevio,
  required List<DefinicionObjetivo> objetivos,
  required List<AvanceObjetivo> avances,
}) {
  final base = rangoPrevio.clamp(rangoMinimo, rangoMaximo);

  // 1. ¿Se puede evaluar? Un objetivo sin meta para este rango no se
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
      // Sin poder evaluar no se acredita nada: se estaría pagando por
      // algo que no se sabe si ocurrió.
      monedasGanadas: 0,
      evaluable: false,
    );
  }

  // 2. Los tres: sube. Menos de tres: baja. No hay estado intermedio, y
  //    por eso no hay nada que arrastrar a la semana siguiente.
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
    // Las monedas las paga SOLO subir de rango, y se calculan sobre el
    // rango al que se llegó. Quedarse o bajar no acuña nada.
    monedasGanadas: movimiento == MovimientoRango.sube
        ? monedasPorSubirA(rangoNuevo)
        : 0,
    evaluable: true,
  );
}
