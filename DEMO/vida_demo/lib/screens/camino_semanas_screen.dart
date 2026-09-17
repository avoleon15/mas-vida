import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/modelos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/moneda_animada.dart';
import '../widgets/carrusel_patrocinadores.dart';
import '../widgets/cintillo_patrocinador.dart';
import '../widgets/curva_camino.dart';
import '../widgets/patrocinio.dart';
import '../widgets/tarjeta_semana.dart';

// ============================================================
// EL CAMINO DE LAS SEMANAS.
//
// Un nodo por semana, de arriba (la 1) hacia abajo (la última), unidos
// por un trazo que va y vuelve. Se llega desde "Objetivos de la semana"
// en Hoy y se toca un nodo para abrir esa semana.
//
// POR QUÉ SERPENTEA. Una columna recta de círculos se lee como una lista
// y se escanea de un vistazo; un camino que va y vuelve obliga al ojo a
// recorrerlo, que es lo que hace sentir que tiene largo. Es la forma de
// un tablero de mesa y es un patrón de género, no una copia: quedan
// afuera los candados, el relieve grueso, los colores saturados y las
// mascotas. La app es de seguros y tiene que transmitir calma.
//
// LA GRILLA ES LO QUE ORDENA. Tres nodos por fila, todos a la misma
// altura dentro de su fila y a la misma distancia entre sí. Cada nodo
// dice arriba qué semana es, para que la pantalla se recorra sin contar
// círculos.
//
// NO HAY CANDADOS EN NINGÚN NODO. Un candado promete que hay algo que
// hacer para abrirlo, y acá no lo hay: la semana 7 llega el 7, haga lo
// que haga el usuario. Adelante va la RECOMPENSA, no la traba.
//
// SEMANA Y RANGO NO COINCIDEN. Fallar baja un rango, así que en la
// semana 5 se puede estar subiendo apenas al 4. Por eso los montos salen
// de `ObjetivosSemana.recorrido`, que arrastra el rango semana a semana,
// y nunca del número de la semana.
// ============================================================

/// Alto de cada renglón del camino.
///
/// El círculo va clavado en el centro del renglón —por ahí pasa la
/// curva—, así que el renglón tiene que aguantar la mitad del nodo más
/// alto hacia arriba y hacia abajo: halo (44) + aire (5) + etiqueta (19)
/// da 68 arriba, y halo (44) + aire (6) + monedas de dos renglones (32)
/// da 82 abajo. La mitad de 160 son 80. El margen es para cuando el
/// usuario sube el tamaño de letra en iOS.
const double _altoFila = 160;

/// Diámetro de cada tipo de nodo.
const double _dCumplida = 62;
const double _dEnCurso = 74;
const double _dFutura = 58;

/// El halo que rodea al nodo de la semana en curso.
const double _dHalo = 88;

/// Cuántos nodos entran en una fila del camino.
///
/// Antes el camino era una columna de diez renglones: 1.520 px de scroll
/// para ver un programa de diez semanas. Con tres por fila, diez semanas
/// entran en cuatro filas.
///
/// Tres y no cuatro por el ancho de un iPhone: la celda mide 122 px y el
/// nodo de la semana en curso ya ocupa 88 con su halo. Con cuatro
/// columnas los nodos se tocan.
const int _columnasDelCamino = 3;

/// Grosor del anillo con el color de la marca, en el nodo de una semana
/// patrocinada.
///
/// Se dibuja HACIA AFUERA del círculo, con un `Stack` que no ocupa lugar
/// en el layout: el nodo no puede crecer ni moverse por tener marca. El
/// renglón mide 152 px clavados y la curva se dibuja aparte, contra los
/// centros ya calculados — un nodo que cambia de tamaño se despega de su
/// propia curva.
const double _grosorAnilloMarca = 2.5;
const double _aireAnilloMarca = 5;

/// Cuánto puede sobresalir la etiqueta "Semana N" a cada lado del halo.
///
/// La etiqueta es más ancha que el círculo y tiene que quedar centrada
/// sobre él sin correrlo: la curva pasa por el centro del círculo, no por
/// el de la etiqueta.
const double _desbordeEtiqueta = 14;

/// Abre el camino completo de [objetivos].
void abrirCaminoDeSemanas(BuildContext context, ObjetivosSemana objetivos) {
  Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => CaminoSemanasScreen(objetivos: objetivos),
    ),
  );
}

class CaminoSemanasScreen extends StatelessWidget {
  const CaminoSemanasScreen({super.key, required this.objetivos});

  final ObjetivosSemana objetivos;

  /// Las semanas patrocinadas que todavía no arrancaron.
  ///
  /// Van detrás del botón "Patrocinadores de las próximas semanas" y no a
  /// la vista: el protagonista de la pantalla es el camino, y la marca
  /// que importa hoy —la de la semana en curso— ya está arriba del todo.
  ///
  /// La en curso NO entra: esa ya tiene su tarjeta, y decirla dos veces
  /// en la misma pantalla es ruido.
  List<SemanaObjetivos> get _loQueViene => [
    for (final s in objetivos.semanas)
      if (s.tienePatrocinio && s.estado == EstadoSemana.futura) s,
  ];

  @override
  Widget build(BuildContext context) {
    final recorrido = objetivos.recorrido;
    final enCurso = objetivos.enCurso;
    final ganadas = objetivos.monedasGanadas;
    final loQueViene = _loQueViene;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // AppHeader y no CupertinoSliverNavigationBar: CLAUDE.md pide
            // el mismo encabezado en TODAS las pantallas, y las otras
            // doce lo cumplen. Una sola pantalla sin el logo y sin la
            // foto de perfil se lee como si fuera de otra app.
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: AppHeader(showBackButton: true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // El titular es la SEMANA EN CURSO, no el programa
                        // entero. Cuántas semanas son ya lo dice el camino
                        // de abajo de un vistazo; en qué semana va el
                        // usuario, no.
                        Text(
                          enCurso == null
                              ? 'LAS ${objetivos.semanas.length} SEMANAS'
                              : 'SEMANA ${enCurso.numero}',
                          style: AppTheme.sectionTitle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          // Quién patrocina la semana se dice ACÁ y no
                          // adentro de la tarjeta de abajo: sobre la foto
                          // de la marca el texto necesita una sombra que
                          // ensucia el logo que la marca pagó por mostrar.
                          //
                          // Sin marca no se menciona el patrocinio: el
                          // renglón dice dónde va el usuario y listo.
                          // Nunca "esta semana no hay patrocinador".
                          enCurso?.patrocinio != null
                              ? 'Patrocinada por '
                                    '${enCurso!.patrocinio!.marca}'
                              : 'Rango ${objetivos.rangoActual} · '
                                    '${objetivos.semanas.length} semanas',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (ganadas > 0) _MonedasGanadas(monedas: ganadas),
                ],
              ),
            ),
            // Una sola tira que scrollea: cintillo, camino y carrusel se
            // mueven juntos. Antes el camino tenía su propio scroll, y
            // con algo debajo habrían quedado dos scrolls anidados, que
            // es la forma más rápida de que ninguno de los dos responda
            // bien al dedo.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  children: [
                    // El cintillo solo existe si la semana EN CURSO está
                    // vendida. Si no, no se dibuja nada —ni un hueco ni
                    // un "esta semana no hay patrocinador"— y el camino
                    // sube: la pantalla se ve como si nunca hubiera
                    // existido la sección.
                    if (enCurso?.patrocinio != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: CintilloPatrocinador(
                          semana: enCurso!.numero,
                          marca: enCurso.patrocinio!.marca,
                          // La lista sale del repositorio, no de acá: hoy
                          // el mock repite la única foto del catálogo.
                          fotos: enCurso.patrocinio!.fotos,
                          fondoMarca: enCurso.patrocinio!.fondo,
                        ),
                      ),
                    // Igual que la tarjeta: sin semanas patrocinadas por
                    // delante, el botón no existe. Un botón que abre una
                    // hoja vacía es peor que no tener botón.
                    if (loQueViene.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: _BotonProximosPatrocinadores(
                          semanas: loQueViene,
                        ),
                      ),
                    _Camino(
                      recorrido: recorrido,
                      rangoActual: objetivos.rangoActual,
                      totalSemanas: objetivos.semanas.length,
                      numeroSiguienteDe: objetivos.numeroDespuesDe,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Llave del botón de próximos patrocinadores, para los tests.
const Key llaveBotonProximosPatrocinadores = ValueKey('proximos-patrocinadores');

/// Botón chico que abre quiénes patrocinan las semanas que vienen.
///
/// Es un botón y no una sección a la vista a propósito: el protagonista
/// de esta pantalla es el camino, y las marcas que todavía no llegaron
/// son un dato de curiosidad. Adentro sí se muestran en grande.
class _BotonProximosPatrocinadores extends StatelessWidget {
  const _BotonProximosPatrocinadores({required this.semanas});

  final List<SemanaObjetivos> semanas;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    // CupertinoButton y no un GestureDetector con un Container: trae
    // gratis el atenuado al presionar que un usuario de iPhone ya
    // conoce (ver CLAUDE.md).
    child: CupertinoButton(
      key: llaveBotonProximosPatrocinadores,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      minimumSize: Size.zero,
      borderRadius: BorderRadius.circular(14),
      color: AppColors.azulNiebla,
      onPressed: () => _mostrarProximosPatrocinadores(context, semanas),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.ticket,
            size: 15,
            color: AppColors.azulMedio,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Patrocinadores de las próximas semanas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 13,
            color: AppColors.azulMedio,
          ),
        ],
      ),
    ),
  );
}

/// La hoja con las marcas que vienen.
void _mostrarProximosPatrocinadores(
  BuildContext context,
  List<SemanaObjetivos> semanas,
) {
  HapticFeedback.selectionClick();
  showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => _HojaProximosPatrocinadores(semanas: semanas),
  );
}

class _HojaProximosPatrocinadores extends StatelessWidget {
  const _HojaProximosPatrocinadores({required this.semanas});

  final List<SemanaObjetivos> semanas;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Lo que viene', style: AppTheme.sectionTitle),
            const SizedBox(height: 4),
            Text(
              semanas.length == 1
                  ? 'Una semana más ya tiene marca aliada.'
                  : '${semanas.length} semanas más ya tienen marca aliada.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            CarruselLoQueViene(semanas: semanas),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Lo ya ganado, en el encabezado.
class _MonedasGanadas extends StatelessWidget {
  const _MonedasGanadas({required this.monedas});

  final int monedas;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Llevás $monedas monedas ganadas',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MonedaAnimada(size: 20),
        const SizedBox(width: 5),
        Text(
          '$monedas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.accentSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

// ============================================================
// El camino.
// ============================================================

class _Camino extends StatelessWidget {
  const _Camino({
    required this.recorrido,
    required this.rangoActual,
    required this.totalSemanas,
    required this.numeroSiguienteDe,
  });

  final List<PasoDelPrograma> recorrido;
  final int? Function(int) numeroSiguienteDe;
  final int rangoActual;
  final int totalSemanas;

  /// Dónde cae cada semana: en qué columna y en qué fila.
  ///
  /// SERPENTINA POR FILAS, como un tablero de mesa: la fila 1 va de
  /// izquierda a derecha, la 2 vuelve de derecha a izquierda, la 3 otra
  /// vez hacia la derecha. Con diez semanas y tres columnas queda
  /// 1-2-3 / 6-5-4 / 7-8-9 / 10.
  ///
  /// POR QUÉ ASÍ Y NO POR COLUMNAS. La versión anterior saltaba de
  /// columna una fila adentro, y eso dejaba celdas vacías arriba y abajo
  /// de la grilla y dos diagonales largas cruzando la pantalla: se leía
  /// desordenado. Yendo por filas la grilla queda llena y el giro cae
  /// SIEMPRE en la misma columna, así que el tramo entre una fila y la
  /// siguiente es vertical y corto. Ningún tramo es diagonal.
  ///
  /// Devuelve (columna, fila) por semana, en el orden del recorrido.
  static List<({int columna, int fila})> _serpentina(int cuantas, int columnas) {
    final lugares = <({int columna, int fila})>[];

    for (var i = 0; i < cuantas; i++) {
      final fila = i ~/ columnas;
      final lugarEnLaFila = i % columnas;
      // Las filas impares se leen al revés: así la última de una fila
      // queda justo encima de la primera de la de abajo.
      lugares.add((
        columna: fila.isEven ? lugarEnLaFila : columnas - 1 - lugarEnLaFila,
        fila: fila,
      ));
    }

    return lugares;
  }

  @override
  Widget build(BuildContext context) {
    if (recorrido.isEmpty) return const SizedBox.shrink();

    final quieto = MediaQuery.disableAnimationsOf(context);
    // Un programa de dos semanas usa dos columnas, no tres con una
    // vacía: la grilla tiene que quedar llena para verse pareja.
    final columnas = math.min(_columnasDelCamino, recorrido.length);
    final lugares = _serpentina(recorrido.length, columnas);
    final filas = lugares.map((l) => l.fila).reduce(math.max) + 1;
    final alto = filas * _altoFila;

    // Sin scroll propio: el camino es UNA pieza de alto conocido adentro
    // del scroll de la pantalla, que es el que mueve también a la tarjeta
    // del patrocinador de arriba.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: LayoutBuilder(
        builder: (context, medidas) {
          final ancho = medidas.maxWidth;
          final anchoCelda = ancho / columnas;

          // Los centros —los del CÍRCULO— los calcula UNA sola vez y los
          // leen tanto el pintor como los nodos. Si cada uno tuviera su
          // cuenta, la curva podría no pasar por los círculos — el mismo
          // problema que ya resolvió la barra inferior sacando el ancho
          // del indicador del ancho de los ítems.
          final centros = [
            for (final l in lugares)
              Offset(
                (l.columna + 0.5) * anchoCelda,
                (l.fila + 0.5) * _altoFila,
              ),
          ];

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: quieto ? 1.0 : 0.0, end: 1.0),
            duration: quieto
                ? Duration.zero
                : const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => SizedBox(
              width: ancho,
              height: alto,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PintorCamino(
                        centros: centros,
                        recorrido: recorrido,
                        crecimiento: t,
                      ),
                    ),
                  ),
                  for (var i = 0; i < recorrido.length; i++)
                    Positioned(
                      left: centros[i].dx - anchoCelda / 2,
                      top: centros[i].dy - _altoFila / 2,
                      width: anchoCelda,
                      height: _altoFila,
                      child: _Nodo(
                        key: llaveNodoSemana(recorrido[i].semana.numero),
                        paso: recorrido[i],
                        rangoActual: rangoActual,
                        totalSemanas: totalSemanas,
                        numeroSiguiente: numeroSiguienteDe(
                          recorrido[i].semana.numero,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Dibuja SOLO la curva que une los nodos.
///
/// Ni círculos, ni números, ni monedas: todo eso son widgets. Un pintor
/// que también dibujara los nodos no podría recibir toques, no tendría
/// etiqueta para VoiceOver y no crecería si el usuario sube el tamaño de
/// letra en iOS.
class _PintorCamino extends CustomPainter {
  const _PintorCamino({
    required this.centros,
    required this.recorrido,
    required this.crecimiento,
  });

  final List<Offset> centros;
  final List<PasoDelPrograma> recorrido;
  final double crecimiento;

  @override
  void paint(Canvas lienzo, Size caja) {
    for (var i = 0; i < centros.length - 1; i++) {
      // Un tramo se pinta como recorrido si la semana de ARRIBA se
      // cumplió: ese es el tramo por el que se bajó. Si no, queda pálido
      // y delgado. Nada se marchita ni se pinta de rojo — la app tiene
      // que transmitir calma, no reproche.
      final recorrida =
          !recorrido[i].proyectado && recorrido[i].semana.subioDeRango;

      // Amplitud 0: tramo RECTO. Con la serpentina por filas dos nodos
      // seguidos comparten fila o columna, así que cada tramo es
      // horizontal o vertical, y el giro de 90° cae siempre en el centro
      // de un nodo —tapado por su propio círculo—. Una S encima de eso
      // solo ensuciaba una forma que ya es simétrica.
      trazarCurva(
        lienzo,
        curvaTallo(centros[i], centros[i + 1], amplitud: 0),
        pincelCurva(
          recorrida ? AppColors.accent : AppColors.azulTenue,
          recorrida ? 6 : 5,
        ),
        crecimiento,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorCamino anterior) =>
      anterior.crecimiento != crecimiento || anterior.centros != centros;
}

// ============================================================
// Un nodo.
// ============================================================

/// Llave del nodo de una semana, para agarrarlo desde un test.
Key llaveNodoSemana(int numero) => ValueKey('nodo-semana-$numero');

/// Llave del CÍRCULO de una semana, que es por donde pasa la curva.
///
/// Existe para que un test pueda comprobar que el círculo queda en el
/// mismo lugar tenga logo o no: es lo que se rompería sin el carril fijo.
Key llaveCirculoSemana(int numero) => ValueKey('circulo-semana-$numero');

class _Nodo extends StatefulWidget {
  const _Nodo({
    super.key,
    required this.paso,
    required this.rangoActual,
    required this.totalSemanas,
    required this.numeroSiguiente,
  });

  final PasoDelPrograma paso;
  final int rangoActual;
  final int totalSemanas;
  final int? numeroSiguiente;

  @override
  State<_Nodo> createState() => _NodoState();
}

class _NodoState extends State<_Nodo> {
  bool _presionado = false;

  SemanaObjetivos get _semana => widget.paso.semana;

  void _abrir() => mostrarHojaSemana(
    context,
    paso: widget.paso,
    rangoActual: widget.rangoActual,
    totalSemanas: widget.totalSemanas,
    numeroSiguiente: widget.numeroSiguiente,
  );

  @override
  Widget build(BuildContext context) {
    final estado = _semana.estado;
    final cumplida = estado == EstadoSemana.cerrada && _semana.subioDeRango;
    final enCurso = estado == EstadoSemana.enCurso;
    final patrocinio = _semana.patrocinio;

    return Semantics(
      button: true,
      label: 'Semana ${_semana.numero}, ${_dicho()}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _abrir,
        behavior: HitTestBehavior.opaque,
        // El feedback va en el press, no al soltar: esperar al touch-up
        // se siente muerto.
        onTapDown: (_) => setState(() => _presionado = true),
        onTapUp: (_) => setState(() => _presionado = false),
        onTapCancel: () => setState(() => _presionado = false),
        child: AnimatedScale(
          scale: _presionado ? 0.93 : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          // Todo se apila alrededor del CENTRO de la celda, y el círculo
          // queda clavado ahí: es por donde pasa el trazo, que se dibuja
          // aparte. Con tres columnas no hay ancho para poner nada al
          // lado, así que la semana va arriba, las monedas abajo y el
          // logo de la marca montado en el borde del círculo.
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // El anillo de marca va PRIMERO, debajo del círculo, y como
              // hijo posicionado no mide para el layout: el nodo queda
              // exactamente del mismo tamaño y en el mismo lugar tenga
              // marca o no.
              if (patrocinio != null)
                Center(
                  child: _AnilloDeMarca(
                    color: acentoDeMarca(patrocinio),
                    diametro: _diametroDe(cumplida, enCurso),
                  ),
                ),
              Center(
                child: SizedBox(
                  key: llaveCirculoSemana(_semana.numero),
                  width: _dHalo,
                  height: _dHalo,
                  child: Center(
                    child: _Circulo(
                      semana: _semana,
                      cumplida: cumplida,
                      enCurso: enCurso,
                    ),
                  ),
                ),
              ),
              // El logo del local, montado sobre el borde del círculo a
              // la derecha y un poco arriba. `Transform` no ocupa lugar
              // en el layout, así que el círculo no se corre ni un píxel.
              //
              // A las 2 del reloj y no a las 1:30: en la esquina de
              // arriba el logo pisaba la etiqueta de la semana, y más
              // abajo taparía el tramo horizontal del camino, que sale
              // del nodo justo a la altura del centro.
              if (patrocinio != null)
                Transform.translate(
                  offset: Offset(
                    _diametroVisible(cumplida, enCurso) * 0.43,
                    -_diametroVisible(cumplida, enCurso) * 0.30,
                  ),
                  child: LogoPatrocinio(patrocinio: patrocinio, tamano: 26),
                ),
              // Qué semana es, ARRIBA del círculo y en todos los nodos.
              // Adentro del círculo el número solo se lee de cerca; acá
              // la pantalla se recorre sin contar nodos.
              //
              // Márgenes negativos: la etiqueta es más ancha que el halo
              // y tiene que quedar centrada sobre él sin correr el
              // círculo. `heightFactor` la deja pegada al borde de abajo
              // de su caja.
              Positioned(
                left: -_desbordeEtiqueta,
                right: -_desbordeEtiqueta,
                bottom:
                    _altoFila / 2 + _diametroVisible(cumplida, enCurso) / 2 + 5,
                child: Center(
                  heightFactor: 1,
                  child: _EtiquetaSemana(
                    numero: _semana.numero,
                    enCurso: enCurso,
                  ),
                ),
              ),
              // Lo que paga la semana, DEBAJO del círculo y centrado.
              Positioned(
                left: 0,
                right: 0,
                top: _altoFila / 2 + _diametroVisible(cumplida, enCurso) / 2 + 6,
                child: _PieDelNodo(paso: widget.paso, cumplida: cumplida),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// El diámetro del círculo según su estado, para que el anillo de
  /// marca lo rodee a la distancia justa en los tres casos.
  double _diametroDe(bool cumplida, bool enCurso) {
    if (enCurso) return _dEnCurso;
    if (cumplida) return _dCumplida;
    return _dFutura;
  }

  /// Lo que el nodo OCUPA de verdad, que no siempre es su círculo: el de
  /// la semana en curso lleva un halo más grande alrededor.
  ///
  /// Lo usan el logo y las monedas para no quedar montados encima de ese
  /// halo; el anillo de marca sí usa el círculo, porque va pegado a él.
  double _diametroVisible(bool cumplida, bool enCurso) =>
      enCurso ? _dHalo : _diametroDe(cumplida, enCurso);

  String _dicho() => switch (_semana.estado) {
    EstadoSemana.cerrada when _semana.subioDeRango =>
      'cumplida, subiste al rango ${widget.paso.rangoAlCerrar}',
    EstadoSemana.cerrada => 'cerrada, no subiste de rango',
    EstadoSemana.enCurso =>
      'esta semana, ${_semana.cumplidos} de '
          '${_semana.objetivos.length} objetivos',
    EstadoSemana.futura => 'empieza más adelante',
  };
}

/// El anillo con el color de la marca, alrededor del nodo de una semana
/// patrocinada.
///
/// Es un anillo fino y con aire, no un relleno: la app es de seguros y
/// tiene que transmitir calma. Un nodo pintado del color de la marca
/// competiría con los otros nueve y rompería la lectura del camino, que
/// es de qué semana está cumplida y cuál va.
class _AnilloDeMarca extends StatelessWidget {
  const _AnilloDeMarca({required this.color, required this.diametro});

  final Color color;

  /// El diámetro del círculo al que rodea. El anillo se dibuja por fuera.
  final double diametro;

  @override
  Widget build(BuildContext context) {
    final lado = diametro + _aireAnilloMarca * 2;

    return IgnorePointer(
      // El toque es del nodo entero; este anillo es decoración y no puede
      // robarle el gesto.
      child: Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: 0.55),
            width: _grosorAnilloMarca,
          ),
        ),
      ),
    );
  }
}

/// El círculo del nodo.
class _Circulo extends StatelessWidget {
  const _Circulo({
    required this.semana,
    required this.cumplida,
    required this.enCurso,
  });

  final SemanaObjetivos semana;
  final bool cumplida;
  final bool enCurso;

  @override
  Widget build(BuildContext context) {
    if (enCurso) return _enCurso(context);
    if (cumplida) return _cumplida();
    return _futura(context);
  }

  /// La sombra sólida: un bloque de color desplazado, sin difuminar.
  ///
  /// Da volumen sin el glow que CLAUDE.md prohíbe sobre fondo claro, y el
  /// color sale derivado del azul de marca —igual que en
  /// `boton_relieve.dart`— para que no se despegue de la paleta si el
  /// azul cambia.
  static List<BoxShadow> _relieve(Color color) => [
    BoxShadow(color: color, offset: const Offset(0, 3), blurRadius: 0),
  ];

  Widget _cumplida() => Container(
    width: _dCumplida,
    height: _dCumplida,
    decoration: BoxDecoration(
      color: AppColors.accent,
      shape: BoxShape.circle,
      boxShadow: _relieve(AppColors.azulSombra),
    ),
    child: const Icon(Icons.check_rounded, size: 30, color: Colors.white),
  );

  Widget _enCurso(BuildContext context) => SizedBox(
    width: _dHalo,
    height: _dHalo,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // El halo dice "acá estás" sin necesitar otro color: es el mismo
        // azul, más pálido y más grande.
        Container(
          width: _dHalo,
          height: _dHalo,
          decoration: const BoxDecoration(
            color: AppColors.azulBruma,
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: _dEnCurso,
          height: _dEnCurso,
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 3),
            boxShadow: _relieve(AppColors.azulSuave),
          ),
          // FittedBox: el círculo tiene diámetro fijo pero el texto crece
          // si el usuario subió el tamaño de letra en iOS.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${semana.numero}',
                    style: AppTheme.display(
                      26,
                    ).copyWith(color: AppColors.accent, height: 1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${semana.cumplidos} DE ${semana.objetivos.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: AppColors.azulMedio,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _futura(BuildContext context) => Container(
    width: _dFutura,
    height: _dFutura,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.azulBruma,
      shape: BoxShape.circle,
      boxShadow: _relieve(AppColors.azulTenue),
    ),
    // Sin candado, a propósito: no hay nada que el usuario pueda hacer
    // para "abrir" esta semana. Llega cuando llega.
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          '${semana.numero}',
          style: AppTheme.display(
            22,
          ).copyWith(color: AppColors.azulMedio, height: 1),
        ),
      ),
    ),
  );
}

/// Llave de la etiqueta de la semana EN CURSO.
///
/// Es la única que va rellena de azul: es lo que dice "acá estás" ahora
/// que todos los nodos llevan etiqueta.
const Key llaveEtiquetaEnCurso = ValueKey('etiqueta-semana-en-curso');

/// La etiqueta "Semana N" que flota sobre cada nodo.
///
/// Va sobre fondo sólido y no suelta sobre el fondo de la pantalla: el
/// tramo vertical del camino entra al nodo justo por ahí, y una línea
/// azul cruzando el texto se lee como un tachón.
class _EtiquetaSemana extends StatelessWidget {
  const _EtiquetaSemana({required this.numero, required this.enCurso});

  final int numero;
  final bool enCurso;

  @override
  Widget build(BuildContext context) => Container(
    key: enCurso ? llaveEtiquetaEnCurso : null,
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      // La en curso rellena de azul de marca; las demás sobre blanco,
      // que es lo que hace que la del medio salte sin usar otro color.
      color: enCurso ? AppColors.accent : AppColors.card,
      borderRadius: BorderRadius.circular(999),
      border: enCurso
          ? null
          : Border.all(color: AppColors.cardBorder, width: 1),
    ),
    child: Text(
      'Semana $numero',
      maxLines: 1,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: enCurso ? FontWeight.w800 : FontWeight.w700,
        letterSpacing: 0.1,
        color: enCurso ? Colors.white : AppColors.azulMedio,
        height: 1.2,
      ),
    ),
  );
}

/// Lo que paga la semana, DEBAJO del nodo y centrado.
///
/// Abajo y no al lado: con tres columnas en el ancho de un iPhone no
/// queda lugar para poner nada a los costados del círculo.
class _PieDelNodo extends StatelessWidget {
  const _PieDelNodo({required this.paso, required this.cumplida});

  final PasoDelPrograma paso;
  final bool cumplida;

  /// El fondo sólido detrás del texto.
  ///
  /// El tramo vertical del camino sale del nodo justo por acá, y sin
  /// fondo la línea azul cruza el renglón de las monedas. El blanco corta
  /// la línea sin agregar un color más.
  static Widget _sobreBlanco(Widget hijo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(999),
    ),
    child: hijo,
  );

  @override
  Widget build(BuildContext context) {
    if (paso.monedas <= 0) {
      return Center(
        heightFactor: 1,
        child: _sobreBlanco(
          Text(
            // Una semana que no pagó no se deja en blanco: el hueco se
            // lee como un error de carga.
            'Sin monedas',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final futura = paso.semana.estado == EstadoSemana.futura;

    final texto = cumplida
        ? '+${paso.monedas} ganadas'
        : '+${paso.monedas} al Rango ${paso.rangoAlCerrar}';

    final fila = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MonedaAnimada(size: 14, apagado: paso.proyectado),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            texto,
            // Dos renglones: una celda de tres columnas es angosta y "al
            // Rango 10" no entra de una sola línea.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              height: 1.2,
              fontWeight: cumplida ? FontWeight.w800 : FontWeight.w600,
              color: cumplida
                  ? AppColors.accentSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );

    // Las futuras van más apagadas: su monto es una proyección, no plata
    // que ya esté. Mostrarla igual de firme que la cobrada sería prometer
    // algo que todavía no pasó.
    return Center(
      heightFactor: 1,
      child: _sobreBlanco(futura ? Opacity(opacity: 0.75, child: fila) : fila),
    );
  }
}
