import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/modelos.dart';
import '../reglas_rango.dart';
import '../theme.dart';
import 'moneda_animada.dart';
import 'patrocinio.dart';

// ============================================================
// LA TARJETA DE UNA SEMANA.
//
// Es la MISMA pieza en dos lugares: la sección de Hoy y la hoja que se
// abre al tocar un nodo del camino. Una sola implementación porque son
// literalmente el mismo contenido — si fueran dos, se desincronizan y el
// usuario ve dos versiones de su propia semana.
//
// Dos zonas:
//
//   arriba  -> el titular, y los tres objetivos con NOMBRE a la vista
//   al pie  -> dónde va en el programa, y la recompensa
//
// QUÉ SE SACÓ Y POR QUÉ:
//
// 1. LA BARRA POR OBJETIVO. Había un GFProgressBar en cada uno. La regla
//    no es llenar nada: son tres casillas y hay que marcar las tres. Una
//    barra al 66% se lee como "falta poco", cuando falta exactamente lo
//    mismo que al 0% — un objetivo entero, y sin él la semana no cuenta.
//
// 2. EL PORCENTAJE. Decía "48 minutos · 55% del objetivo". Un porcentaje
//    no le dice a nadie qué hacer hoy. Ahora dice "48 de 90 min", que es
//    una cantidad concreta.
//
// 3. EL ACTION SHEET. Tocar un objetivo abría un CupertinoActionSheet con
//    su nombre y su avance, más dos botones para salir. Existía solo
//    porque los nombres no se veían. Ahora se ven, así que no hace falta:
//    los action sheets son para elegir entre acciones, no para mostrar
//    un dato que cabe en la tarjeta.
// ============================================================

/// Cómo se dice el avance de un objetivo: "48 de 90 min".
///
/// En UNIDADES REALES, nunca en porcentaje: "48 de 90 min" se puede
/// terminar hoy, "55% del objetivo" no le dice nada a nadie.
///
/// POR QUÉ NO DICE "FALTAN" (revisión de Daniel, 10 de septiembre de
/// 2026). Antes decía "Faltan 42 min" y "Faltan 2 días", y se leía como
/// una cuenta regresiva: parecía que a un objetivo le quedaban 42 minutos
/// de plazo y al otro 2 días. Los TRES cierran juntos el domingo 23:59
/// —eso lo dice [plazoDeLaSemana], una sola vez, abajo—, así que la
/// columna de la derecha no puede sonar a plazo. "Faltan" más una unidad
/// que además es unidad de tiempo ("días") era la combinación exacta que
/// lo hacía sonar así.
///
/// El formato es el MISMO que el del titular de la tarjeta ("1 de 3
/// objetivos") a propósito: dos formas distintas de decir un avance en la
/// misma tarjeta se leen como dos cosas distintas.
///
/// Sin meta devuelve un texto sin número. La tabla de dificultad por
/// rango todavía no existe en ninguna fuente (la define Luis en L7): el
/// día que el servidor no mande la meta, esta función NO inventa una
/// dividiendo el progreso por un porcentaje redondeado.
String avanceDicho(ObjetivoSemanal objetivo) {
  if (objetivo.completo) return 'Completado';

  final meta = objetivo.meta;
  if (meta == null) return 'En curso';

  // Llegó al número pero el servidor todavía no lo dio por cumplido. No
  // se muestra "90 de 90": eso se lee como completado y lo contradiría
  // el círculo vacío de al lado.
  if (objetivo.progreso >= meta) return 'Casi';

  // La unidad concuerda con la META, que es el número que la precede:
  // "1 de 3 días", "0 de 1 día".
  return '${_conMiles(objetivo.progreso)} de ${_conMiles(meta)} '
      '${_unidadCorta(objetivo.unidad, meta)}';
}

/// La unidad, abreviada y concordada con el número.
///
/// "1 dias" era un error visible en pantalla: la unidad venía cruda del
/// JSON y se concatenaba sin mirar la cantidad.
String _unidadCorta(String unidad, int cantidad) {
  final limpia = unidad.toLowerCase();
  if (limpia.startsWith('min')) return 'min';
  if (limpia.startsWith('día') || limpia.startsWith('dia')) {
    return cantidad == 1 ? 'día' : 'días';
  }
  if (limpia.startsWith('paso')) return cantidad == 1 ? 'paso' : 'pasos';
  return unidad;
}

String _conMiles(int v) => v.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

/// Los días de la semana, para decir cuándo cierra.
const List<String> _diasDeLaSemana = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// El domingo en que cierra [semana], en hora de Guatemala.
DateTime _cierreDe(SemanaObjetivos semana) => enHoraDeGuatemala(semana.cierra);

/// El lunes en que arranca [semana], en hora de Guatemala.
DateTime _arranqueDe(SemanaObjetivos semana) =>
    _cierreDe(semana).subtract(const Duration(days: 6));

/// "domingo 20", "lunes 21".
String _diaYNumero(DateTime fecha) =>
    '${_diasDeLaSemana[fecha.weekday - 1]} ${fecha.day}';

/// Cuándo cierran los tres objetivos, y cuándo arranca la semana que
/// sigue.
///
/// Los HORARIOS son fijos y salen del contrato v1: la semana va de lunes
/// 00:00 a domingo 23:59, hora de Guatemala. En reloj de 12 horas eso es
/// **domingo 11:59 p.m.** y **lunes 12:00 a.m.** — las dos de noche.
///
/// Ojo con la p.m.: "domingo a las 11:59 a.m." sería el domingo a media
/// mañana, y adelantaría el cierre doce horas. El motor evalúa a las
/// 23:59:59 (ver `domingoDeLaSemana`), así que acá va p.m.
String plazoDeLaSemana(SemanaObjetivos semana, {int? numeroSiguiente}) {
  final cierra = _diaYNumero(_cierreDe(semana));
  final arranca = _diaYNumero(_arranqueDe(semana));

  switch (semana.estado) {
    case EstadoSemana.cerrada:
      return 'Cerró el $cierra a las 11:59 p.m.';

    case EstadoSemana.futura:
      return 'Arranca el $arranca a las 12:00 a.m. y cierra el $cierra a '
          'las 11:59 p.m.';

    case EstadoSemana.enCurso:
      final base = 'Los tres cierran el $cierra a las 11:59 p.m.';
      if (numeroSiguiente == null) return base;
      // El lunes de la que viene es el día siguiente al domingo que
      // cierra esta: 00:00 arranca apenas termina el 23:59.
      final proximo = _diaYNumero(
        _cierreDe(semana).add(const Duration(days: 1)),
      );
      return '$base La semana $numeroSiguiente arranca el $proximo a las '
          '12:00 a.m.';
  }
}

/// Abre una semana en su propia hoja.
///
/// Hoja y no pantalla: es el mismo contenido de Hoy para otra semana, y
/// se cierra empujándola hacia abajo sin perder el lugar del camino.
void mostrarHojaSemana(
  BuildContext context, {
  required PasoDelPrograma paso,
  required int rangoActual,
  required int totalSemanas,
  int? numeroSiguiente,
}) {
  HapticFeedback.selectionClick();
  showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => _HojaSemana(
      paso: paso,
      rangoActual: rangoActual,
      totalSemanas: totalSemanas,
      numeroSiguiente: numeroSiguiente,
    ),
  );
}

class _HojaSemana extends StatelessWidget {
  const _HojaSemana({
    required this.paso,
    required this.rangoActual,
    required this.totalSemanas,
    this.numeroSiguiente,
  });

  final PasoDelPrograma paso;
  final int rangoActual;
  final int totalSemanas;
  final int? numeroSiguiente;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barrita de arrastre: dice que la hoja se puede empujar
            // hacia abajo antes de que el usuario lo intente.
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            TarjetaSemana(
              paso: paso,
              rangoActual: rangoActual,
              totalSemanas: totalSemanas,
              numeroSiguiente: numeroSiguiente,
              // Sin marco: la hoja YA es la superficie. Una tarjeta con
              // borde adentro de una hoja blanca se lee como una caja
              // dentro de otra caja.
              conMarco: false,
            ),
            // Aire debajo de la franja: pegada al borde de la hoja se
            // siente cortada, y en un iPhone sin botón la barra de inicio
            // le queda encima.
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// La tarjeta.
// ============================================================

class TarjetaSemana extends StatelessWidget {
  const TarjetaSemana({
    super.key,
    required this.paso,
    required this.rangoActual,
    required this.totalSemanas,
    this.numeroSiguiente,
    this.conMarco = true,
  });

  /// La semana con el rango en que deja y lo que paga. Viene ya resuelto
  /// desde [ObjetivosSemana.recorrido]: el monto NO se puede sacar del
  /// número de semana, porque fallar baja un rango y los dos se
  /// desalinean.
  final PasoDelPrograma paso;

  /// El rango en el que va el usuario HOY.
  final int rangoActual;

  final int totalSemanas;

  /// Cómo se llama la semana que sigue, para decir cuándo arranca. Null
  /// cuando esta es la última del programa.
  final int? numeroSiguiente;

  /// False dentro de una hoja modal, que ya es superficie por sí sola.
  final bool conMarco;

  SemanaObjetivos get _semana => paso.semana;

  @override
  Widget build(BuildContext context) {
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_titular(), style: _estiloTitular(context)),
              const SizedBox(height: 6),
              Text(
                _conteo(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              for (final o in _semana.objetivos)
                _FilaObjetivo(
                  objetivo: o,
                  apagada: _semana.estado == EstadoSemana.futura,
                ),
              const SizedBox(height: 14),
              // El plazo va acá abajo y no en cada fila: es el MISMO para
              // los tres. Repetirlo tres veces sería decir tres veces lo
              // mismo, y ponerlo arriba lo separaría de los objetivos a
              // los que se aplica.
              Text(
                plazoDeLaSemana(_semana, numeroSiguiente: numeroSiguiente),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              // Qué paga la marca, entero. Acá sí cabe el cupón completo:
              // en el camino solo entra el nombre de la marca, y de un
              // "Cupón de Ookii" nadie sabe qué se lleva.
              if (_semana.patrocinio != null) ...[
                const SizedBox(height: 14),
                CintaPatrocinio(
                  patrocinio: _semana.patrocinio!,
                  compacta: true,
                  texto: _semana.estado == EstadoSemana.cerrada
                      ? (_semana.subioDeRango
                            ? 'Ganaste ${_semana.patrocinio!.cupon}.'
                            : 'Esta semana pagaba '
                                  '${_semana.patrocinio!.cupon}.')
                      // Sin explicar de nuevo la regla de los tres
                      // objetivos: ya está arriba, en el conteo y en el
                      // plazo. Acá solo se dice qué paga la marca.
                      : 'Esta semana paga ${_semana.patrocinio!.cupon}.',
                ),
              ],
            ],
          ),
        ),
        _FranjaPrograma(
          semana: _semana,
          rangoActual: rangoActual,
          totalSemanas: totalSemanas,
          monedas: paso.monedas,
          cobradas: !paso.proyectado,
        ),
      ],
    );

    if (!conMarco) return contenido;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      // La franja del pie llega hasta el borde y tiene que respetar el
      // radio: sin recortar, sus esquinas cuadradas asoman por fuera.
      clipBehavior: Clip.antiAlias,
      child: contenido,
    );
  }

  /// El titular ubica la semana en el programa.
  ///
  /// Antes contaba los objetivos que faltaban ("Te faltan 2 objetivos").
  /// Ese dato está mejor en chico: lo primero que hay que saber es POR
  /// QUÉ SEMANA se va, y recién después cómo viene.
  String _titular() => 'Semana ${_semana.numero} de $totalSemanas';

  /// El renglón chico: cuántos objetivos van, y cómo terminó la semana si
  /// ya cerró.
  ///
  /// Es UNO solo. Antes había dos —el conteo y una oración explicando la
  /// regla— y la segunda era relleno: se lee una vez y después estorba
  /// todos los días.
  String _conteo() {
    final cumplidos = _semana.cumplidos;
    final total = _semana.objetivos.length;
    final rango = paso.rangoAlCerrar;

    switch (_semana.estado) {
      case EstadoSemana.futura:
        return 'Todavía no empieza';

      case EstadoSemana.cerrada:
        return _semana.subioDeRango
            ? '$cumplidos de $total objetivos · subiste al Rango $rango'
            : '$cumplidos de $total objetivos · bajaste al Rango $rango';

      case EstadoSemana.enCurso:
        return _semana.faltan == 0
            ? '$cumplidos de $total objetivos · al cerrar subís al Rango '
                  '$rango'
            : '$cumplidos de $total objetivos';
    }
  }
}

/// El estilo del titular.
///
/// El tracking negativo a 26 px no es decorativo: a ese tamaño las letras
/// se separan solas y el titular se desarma. Es la misma regla que ya
/// aplica `AppTheme.trackingPara`.
TextStyle _estiloTitular(BuildContext context) =>
    Theme.of(context).textTheme.titleLarge!.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      letterSpacing: -0.6,
      height: 1.15,
    );

// ============================================================
// Un objetivo, en una línea.
// ============================================================

/// Llave de la fila de un objetivo, para agarrarla desde un test.
Key llaveObjetivo(String id) => ValueKey('objetivo-$id');

class _FilaObjetivo extends StatelessWidget {
  const _FilaObjetivo({required this.objetivo, required this.apagada});

  final ObjetivoSemanal objetivo;

  /// Una semana futura no tiene avance real: se muestra apagada para que
  /// no parezca que ya arrancó.
  final bool apagada;

  @override
  Widget build(BuildContext context) {
    final hecho = objetivo.completo;
    final cola = avanceDicho(objetivo);

    return Semantics(
      key: llaveObjetivo(objetivo.id),
      label: '${objetivo.nombre}: $cola',
      excludeSemantics: true,
      child: Container(
        // El separador es un borde de arriba y no un Divider suelto: así
        // la primera fila también queda separada del subtítulo, y no hay
        // que acordarse de no ponerle uno a la última.
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            _Indicador(hecho: hecho),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                objetivo.nombre,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: apagada
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Tope de ancho en vez de flex, y el orden importa: Flutter
            // mide primero los hijos SIN flex, así que la cola se lleva
            // solo lo que necesita —"Listo" ocupa poco— y el nombre se
            // queda con todo el resto. Con un flex fijo el nombre se
            // partía en dos líneas aunque sobrara espacio a la derecha.
            //
            // El tope existe para el otro extremo: con el tamaño de letra
            // de iOS al máximo, "36,600 de 40,000 pasos" empujaba la fila
            // fuera de la tarjeta. Acotada, envuelve. Hay un test a 1.6x.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Text(
                cola,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: hecho ? FontWeight.w600 : FontWeight.w500,
                  color: hecho ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El punto de estado de un objetivo.
///
/// Lleno o vacío, sin estados intermedios: no hay anillo parcial ni
/// porcentaje adentro. Un objetivo al 90% cuenta lo mismo que uno al 0%
/// mientras no esté cumplido, y el indicador tiene que decir eso.
class _Indicador extends StatelessWidget {
  const _Indicador({required this.hecho});

  final bool hecho;

  @override
  Widget build(BuildContext context) => Container(
    width: 19,
    height: 19,
    decoration: BoxDecoration(
      color: hecho ? AppColors.accent : AppColors.azulNiebla,
      shape: BoxShape.circle,
      border: hecho ? null : Border.all(color: AppColors.azulSuave, width: 1.6),
    ),
    child: hecho
        ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
        : null,
  );
}

// ============================================================
// La franja del pie: dónde vas y qué se gana.
// ============================================================

class _FranjaPrograma extends StatelessWidget {
  const _FranjaPrograma({
    required this.semana,
    required this.rangoActual,
    required this.totalSemanas,
    required this.monedas,
    required this.cobradas,
  });

  final SemanaObjetivos semana;
  final int rangoActual;
  final int totalSemanas;
  final int monedas;

  /// True cuando ese monto ya se acreditó; false cuando es lo que se
  /// ganaría al cumplir.
  final bool cobradas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.azulNiebla,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Sin repetir la semana: eso ya lo dice el titular de
                  // arriba. Acá queda el rango, que es lo otro que ubica.
                  'RANGO $rangoActual',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                _TiraSemanas(actual: semana.numero, total: totalSemanas),
              ],
            ),
          ),
          if (monedas > 0) ...[
            const SizedBox(width: 14),
            _ChipRecompensa(monedas: monedas, cobradas: cobradas),
          ],
          // El cupón al lado de las monedas, no en su lugar: son dos
          // premios y se entregan los dos. El logo lo hace distinto de un
          // premio del catálogo sin gastar otro color.
          if (semana.patrocinio != null) ...[
            const SizedBox(width: 8),
            ChipCuponMarca(patrocinio: semana.patrocinio!),
          ],
        ],
      ),
    );
  }
}

/// Llave de la tira de semanas, para los tests.
const Key llaveTiraSemanas = ValueKey('tira-semanas');

/// Las semanas del programa como marcas chiquitas.
///
/// Sin candados y sin números: lo que informa es cuántas quedan y por
/// dónde va, no cuál es cuál. Para eso está el camino completo.
class _TiraSemanas extends StatelessWidget {
  const _TiraSemanas({required this.actual, required this.total});

  final int actual;
  final int total;

  @override
  Widget build(BuildContext context) {
    // FittedBox: las marcas miden 15×5 con 5 de separación, o sea 195 px
    // con diez semanas. En un iPhone angosto eso no entra al lado del
    // chip, y se achican en vez de desbordarse.
    return FittedBox(
      key: llaveTiraSemanas,
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var n = 1; n <= total; n++) ...[
            Container(
              width: 15,
              height: 5,
              decoration: BoxDecoration(
                color: _color(n),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            if (n != total) const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }

  Color _color(int numero) {
    if (numero == actual) {
      // La de ahora, a media tinta: ya empezó pero todavía no cerró.
      return AppColors.accent.withValues(alpha: 0.45);
    }
    if (numero < actual) return AppColors.accent;
    return AppColors.azulTenue;
  }
}

/// Lo que paga esta semana.
class _ChipRecompensa extends StatelessWidget {
  const _ChipRecompensa({required this.monedas, required this.cobradas});

  final int monedas;
  final bool cobradas;

  @override
  Widget build(BuildContext context) => Semantics(
    label: cobradas
        ? 'Esta semana pagó $monedas monedas'
        : 'Cumplirla paga $monedas monedas',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accentSecondary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MonedaAnimada(size: 17, apagado: !cobradas),
          const SizedBox(width: 4),
          Text(
            '+$monedas',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.accentSecondary,
              height: 1,
            ),
          ),
        ],
      ),
    ),
  );
}
