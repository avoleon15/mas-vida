import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/modelos.dart';
import '../reglas_rango.dart';
import '../theme.dart';
import 'cintillo_patrocinador.dart';
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
//   al pie  -> la entrada al camino completo, y nada más
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
//
// 4. LOS DOS PÁRRAFOS DEL PIE (revisión de Daniel, 21 de septiembre de
//    2026). Abajo de los objetivos había dos bloques de texto: el plazo
//    en dos oraciones ("Los tres cierran el domingo 20 a las 11:59 p.m.
//    La semana 4 arranca el lunes 21 a las 12:00 a.m.") y el renglón de
//    la marca. Cuatro renglones de letra chica para cerrar una tarjeta
//    cuyo trabajo es decir qué falta hacer esta semana.
//
//    El plazo no se perdió: subió al renglón del conteo, alineado a la
//    derecha, en tres palabras. Sigue dicho UNA sola vez y sigue siendo
//    uno solo para los tres objetivos, que es la regla que lo puso ahí.
//    Cuándo arranca la que sigue se fue del todo: es el día siguiente al
//    cierre, y decirlo obligaba a leer una segunda fecha para no
//    enterarse de nada nuevo.
//
//    En su lugar, el pie es el botón que abre el camino: es la única
//    acción de la tarjeta, y estaba arriba —flotando entre el
//    encabezado de la sección y la tarjeta—, donde se leía como un
//    rótulo y no como algo que se toca.
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
/// —eso lo dice [plazoCorto], una sola vez, arriba del todo y al lado
/// del conteo—, así que la columna de la derecha no puede sonar a
/// plazo. "Faltan" más una unidad
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

/// El plazo de la semana, en tres palabras.
///
/// Va al lado del conteo de objetivos, alineado a la derecha, y es lo
/// único que se dice del calendario en toda la tarjeta.
///
/// SIN LA HORA. Decía "a las 11:59 p.m." y el cuidado era real —"11:59
/// a.m." adelantaría el cierre doce horas—, pero esa ambigüedad la
/// traía la oración larga. "Cierran el domingo 20" no se lee como
/// mediodía: una semana termina cuando termina el domingo. La hora
/// exacta la sigue decidiendo el servidor (23:59:59, ver
/// `domingoDeLaSemana`); acá no hace falta nombrarla.
///
/// En MINÚSCULA porque continúa el renglón del conteo, no lo abre.
String plazoCorto(SemanaObjetivos semana) => switch (semana.estado) {
  EstadoSemana.cerrada => 'cerró el ${_diaYNumero(_cierreDe(semana))}',
  EstadoSemana.futura => 'arranca el ${_diaYNumero(_arranqueDe(semana))}',
  // En plural: el plazo es de los tres objetivos a la vez, y esa es
  // justamente la confusión que hay que evitar (ver [avanceDicho]).
  EstadoSemana.enCurso => 'cierran el ${_diaYNumero(_cierreDe(semana))}',
};

/// Abre una semana en su propia hoja.
///
/// Hoja y no pantalla: es el mismo contenido de Hoy para otra semana, y
/// se cierra empujándola hacia abajo sin perder el lugar del camino.
void mostrarHojaSemana(
  BuildContext context, {
  required PasoDelPrograma paso,
  required int rangoActual,
  required int totalSemanas,
}) {
  HapticFeedback.selectionClick();
  showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => _HojaSemana(
      paso: paso,
      rangoActual: rangoActual,
      totalSemanas: totalSemanas,
    ),
  );
}

class _HojaSemana extends StatelessWidget {
  const _HojaSemana({
    required this.paso,
    required this.rangoActual,
    required this.totalSemanas,
  });

  final PasoDelPrograma paso;
  final int rangoActual;
  final int totalSemanas;

  @override
  Widget build(BuildContext context) {
    // LA MARCA DE LA SEMANA SE VE ACÁ (decisión de Daniel, 21 de
    // septiembre de 2026).
    //
    // La tarjeta con las fotos del local estaba arriba del camino, a
    // pantalla completa y siempre: la marca de la semana en curso le
    // pasaba por delante a todo el que entraba a ver el recorrido.
    // Ahora se ve al ABRIR la semana —la que sea, no solo la que
    // corre—, que es el momento en que el usuario preguntó por ella.
    //
    // Y solo si ESA semana está vendida. Sin marca no se dibuja nada:
    // ni un hueco, ni un cartel que anuncie la ausencia.
    final patrocinio = paso.semana.patrocinio;

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
            if (patrocinio != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: CintilloPatrocinador(
                  semana: paso.semana.numero,
                  marca: patrocinio.marca,
                  // La lista sale del repositorio, no de acá: hoy el
                  // mock repite la única foto del catálogo.
                  fotos: patrocinio.fotos,
                  fondoMarca: patrocinio.fondo,
                ),
              ),
            TarjetaSemana(
              paso: paso,
              rangoActual: rangoActual,
              totalSemanas: totalSemanas,
              // Sin la píldora de la marca cuando arriba están sus
              // fotos: el logo quedaría dos veces en cinco centímetros.
              conChipMarca: patrocinio == null,
              // Sin botón al pie: esta hoja se abre DESDE el camino. Un
              // "Ver las 10 semanas" acá llevaría a donde el usuario ya
              // está parado.
              //
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
    this.onVerCamino,
    this.conMarco = true,
    this.conChipMarca = true,
  });

  /// La semana con el rango en que deja y lo que paga. Viene ya resuelto
  /// desde [ObjetivosSemana.recorrido]: el monto NO se puede sacar del
  /// número de semana, porque fallar baja un rango y los dos se
  /// desalinean.
  final PasoDelPrograma paso;

  /// El rango en el que va el usuario HOY.
  final int rangoActual;

  final int totalSemanas;

  /// Qué hace el botón del pie. Null en la hoja del camino: ahí el botón
  /// no se dibuja, porque el camino ya está abierto.
  final VoidCallback? onVerCamino;

  /// False dentro de una hoja modal, que ya es superficie por sí sola.
  final bool conMarco;

  /// False cuando la marca ya se está viendo en grande arriba de la
  /// tarjeta: el mismo logo dos veces en la misma hoja es uno de más.
  final bool conChipMarca;

  SemanaObjetivos get _semana => paso.semana;

  @override
  Widget build(BuildContext context) {
    final alPie = onVerCamino;

    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          // Menos aire abajo cuando hay botón: el relleno del botón ya
          // separa la última fila del borde, y sumados los dos dejaban
          // un hueco en el medio de la tarjeta.
          padding: EdgeInsets.fromLTRB(20, 24, 20, alPie == null ? 20 : 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // EL TITULAR Y LA MARCA, EN LA MISMA LÍNEA.
              //
              // La marca de la semana estaba abajo del todo, en un
              // bloque propio con su logo y dos renglones de texto: se
              // leía después de los tres objetivos y del plazo, o sea
              // último, cuando es lo que hace distinta a esta semana de
              // las otras nueve. Arriba, al lado del número de semana,
              // se ve de entrada y sin ocupar un renglón nuevo.
              //
              // La marca va PEGADA A LA DERECHA y arriba de todo, en su
              // esquina. El titular se queda con lo que sobre: es una
              // palabra y un número, así que sobra de más.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _titular(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _estiloTitular(context),
                    ),
                  ),
                  if (conChipMarca)
                    if (_semana.patrocinio case final p?) ...[
                      const SizedBox(width: 10),
                      ChipMarcaSemana(patrocinio: p),
                    ],
                ],
              ),
              const SizedBox(height: 6),
              // EL RENGLÓN DE APOYO: cómo viene la semana a la
              // izquierda, cuándo cierra a la derecha. Dos datos, un
              // renglón, ningún bloque nuevo.
              //
              // El plazo NO lleva flex y va después: Flutter mide
              // primero a los hijos sin flex, así que se lleva lo que
              // necesita —son tres palabras— y el conteo se queda con
              // todo el resto. Es la misma mecánica que la cola de cada
              // objetivo, y el tope existe por lo mismo: con el tamaño
              // de letra de iOS al máximo, sin acotarlo, empuja el
              // conteo fuera de la tarjeta.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _conteo(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    // 150 y no 130: "cierran el domingo 20" entra en dos
                    // renglones justos: más angosto se parte en tres y
                    // deja el conteo de la izquierda flotando solo.
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      plazoCorto(_semana),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (final o in _semana.objetivos)
                _FilaObjetivo(
                  objetivo: o,
                  apagada: _semana.estado == EstadoSemana.futura,
                ),
              // QUÉ PAGA LA MARCA: solo cuando YA SE GANÓ.
              //
              // "Esta semana paga Entrada gratis en Montanos" se fue: es
              // una promesa, y la promesa ya la hace la píldora de la
              // marca arriba, al lado del titular. Lo que sí se dice es
              // lo que el usuario SE LLEVÓ, porque eso no lo dice
              // ninguna otra pieza —el nodo del camino solo muestra las
              // monedas— y de "Cupón de Montanos" nadie sabe qué ganó.
              if (_semana.patrocinio case final p?)
                if (_semana.estado == EstadoSemana.cerrada &&
                    _semana.subioDeRango) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Ganaste ${p.cupon}.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: acentoDeMarca(p),
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ],
            ],
          ),
        ),
        if (alPie != null)
          _PieCamino(totalSemanas: totalSemanas, onPressed: alPie),
        // LA FRANJA AZUL DEL PIE SE SACÓ ENTERA, y lo que quedó en su
        // lugar es un botón, no otra franja de datos.
        //
        // Llevaba tres cosas y ninguna se ganaba el lugar acá:
        //
        //   · La tira de diez marcas. Decía por qué semana va, que es
        //     exactamente lo que ya dice el titular con palabras
        //     ("Semana 3 de 10") a quince centímetros de distancia.
        //   · El rótulo "RANGO N", que además rotulaba mal a esa tira:
        //     la tira cuenta semanas, no rangos. El rango vive en la
        //     insignia del camino.
        //   · El chip de monedas. Está en el nodo de esta semana,
        //     adentro del camino, que es donde se compara contra los de
        //     las otras nueve — que es para lo que sirve saber cuánto
        //     paga cada una.
      ],
    );

    if (!conMarco) return contenido;

    return Container(
      // Recorta: el botón del pie tiene relleno propio y llega hasta el
      // borde. Sin el recorte, sus esquinas cuadradas asoman por fuera
      // del redondeo de la tarjeta.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: contenido,
    );
  }

  /// El titular ubica la semana en el programa.
  ///
  /// Antes contaba los objetivos que faltaban ("Te faltan 2 objetivos").
  /// Ese dato está mejor en chico: lo primero que hay que saber es POR
  /// QUÉ SEMANA se va, y recién después cómo viene.
  ///
  /// SIN EL "DE 10". A 26 px, "Semana 3 de 10" más la tarjeta de la
  /// marca al lado no entran en un iPhone: el titular terminaba cortado
  /// en "Semana 3 de …", que es la peor de las dos opciones —se pierde
  /// el número que importa y encima se ve roto—. Cuántas semanas tiene
  /// el programa lo dice el botón del pie ("Ver las 10 semanas") y el
  /// camino entero; acá lo único que hace falta es en cuál va.
  String _titular() => 'Semana ${_semana.numero}';

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
// El pie: la entrada al camino.
// ============================================================

/// Llave del botón que abre el camino, para agarrarlo desde un test.
const Key llaveBotonCamino = ValueKey('ver-camino-semanas');

/// El pie de la tarjeta, que es la única acción que tiene.
///
/// PEGADO A LA TARJETA Y NO FLOTANDO ARRIBA. Antes era una barra suelta
/// entre el encabezado de la sección y la tarjeta: ahí arriba, con el
/// mismo relleno azul que usan los rótulos de la app, se leía como un
/// título de sección más y no como algo que se toca. Al pie, cerrando
/// la tarjeta de lado a lado y con el chevron a la derecha, es la forma
/// que iOS usa para "seguir hacia adentro" — la misma de una celda de
/// tabla.
///
/// `azulNiebla` y no `accent`: la acción principal de la pantalla es
/// cumplir los tres objetivos de arriba, no irse a mirar el camino. El
/// botón tiene que verse sin gritar.
class _PieCamino extends StatelessWidget {
  const _PieCamino({required this.totalSemanas, required this.onPressed});

  final int totalSemanas;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // CupertinoButton y no un GestureDetector: trae gratis el atenuado
    // al presionar que un usuario de iPhone ya conoce (ver CLAUDE.md).
    return CupertinoButton(
      key: llaveBotonCamino,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      borderRadius: BorderRadius.zero,
      onPressed: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
        decoration: const BoxDecoration(
          color: AppColors.azulNiebla,
          // La misma línea que separa un objetivo del siguiente: el pie
          // es el renglón que sigue, no una pieza aparte.
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: Row(
          children: [
            // Sin ícono a la izquierda. El chevron ya dice que lleva a
            // otro lado, y dos marcas para una sola acción es una de
            // más en una tarjeta que se está tratando de aligerar.
            Expanded(
              child: Text(
                'Ver las $totalSemanas semanas',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

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
            _Riel(hecho: hecho, apagada: apagada),
            const SizedBox(width: 14),
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
              constraints: const BoxConstraints(maxWidth: 124),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // El check SUELTO, sin círculo y sin relleno: es uno de
                  // los cuatro lugares donde CLAUDE.md deja entrar el
                  // naranja, y acá hace el trabajo que hacía el círculo
                  // de la izquierda sin prometer que se puede tocar. Va
                  // pegado a la palabra que ya dice lo mismo, así que se
                  // lee como una marca y no como un control.
                  if (hecho) ...[
                    const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: AppColors.accentSecondary,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      cola,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: hecho ? FontWeight.w600 : FontWeight.w500,
                        color: hecho
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El estado de un objetivo, como un RIEL y no como una casilla.
///
/// POR QUÉ SE FUE EL CÍRCULO (prueba con usuario, 22 de septiembre de
/// 2026). Era un círculo de 19 px con un check adentro, o sea la forma
/// exacta de un checkbox de iOS, y la primera persona que probó la app
/// intentó tocarlo para marcar el objetivo. No hay nada que marcar: los
/// tres objetivos los cierra el SERVIDOR el domingo 23:59 con los datos
/// de Apple Health. Una casilla promete una acción que no existe, y
/// descubrir que no hace nada se siente una app rota.
///
/// Un riel no promete nada. Es una barra de 3,5 px pegada al borde
/// izquierdo de la fila: se lee como el margen de color de una lista, no
/// como un control. Nadie toca una línea.
///
/// Y SIGUE SIENDO BINARIO, lleno o vacío, sin anillo parcial ni
/// porcentaje: un objetivo al 90% cuenta lo mismo que uno al 0% mientras
/// no esté cumplido. Cuánto lleva ya lo dice la columna de la derecha,
/// en unidades reales ("48 de 90 min"), que es donde se puede leer.
class _Riel extends StatelessWidget {
  const _Riel({required this.hecho, required this.apagada});

  final bool hecho;

  /// Una semana futura no arrancó: su riel va más pálido todavía, para
  /// que no se lea como un objetivo en curso que va en cero.
  final bool apagada;

  @override
  Widget build(BuildContext context) => Container(
    width: 3.5,
    height: 22,
    decoration: BoxDecoration(
      // Azul de marca el cumplido, azul pálido el que falta: lo que
      // separa los dos estados es la LUMINOSIDAD, igual que en los
      // niveles de cashback y en las muescas del rango.
      color: hecho
          ? AppColors.accent
          : (apagada ? AppColors.azulNiebla : AppColors.azulBruma),
      borderRadius: BorderRadius.circular(AppRadios.pildora),
    ),
  );
}
