import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../reglas_rango.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/moneda_animada.dart';
import '../widgets/curva_camino.dart';
import '../widgets/insignia_rango.dart';
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
// LA GRILLA ORDENA, LA CINTA ONDULA. Tres nodos por fila, todos a la
// misma altura dentro de su fila y a la misma distancia entre sí: eso no
// se toca, un nodo fuera de la grilla se lee como un error de
// alineación. Lo que se curva es el TRAZO que va de uno a otro — los
// tramos de una fila combados de a uno hacia arriba y de a uno hacia
// abajo, el giro de fila abriéndose hacia el borde. Con tramos rectos y
// esquinas de 90° lo que se veía era el contorno de una tabla.
//
// CADA CÍRCULO DICE QUÉ SEMANA ES, con todas las letras: "SEM 7". En la
// pantalla conviven tres escaleras de números —semanas, rangos y
// monedas— y un número suelto adentro de un círculo puede ser cualquiera
// de las tres. Lo que el usuario necesita saber al mirar adelante es a
// qué SEMANA va a entrar.
//
// UNA SOLA COSA LEVANTADA, Y ES EL CAMINO. No hay tarjetas en esta
// pantalla: el rango es un renglón apoyado sobre el fondo con una línea
// de un pelo debajo, y lo que cada semana paga va sin pastilla blanca.
// Lo único con cuerpo propio es la cinta.
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
/// alto hacia arriba y hacia abajo: halo (44) + aire (5) + etiqueta (20)
/// da 69 arriba, y halo (44) + aire (6) + monedas de UN renglón (20) da
/// 70 abajo. La mitad de 146 son 73, así que sobran 3 px de cada lado
/// para cuando el usuario sube el tamaño de letra en iOS.
///
/// Bajó de 160 a 146 cuando el nodo dejó de llevar etiqueta propia y el
/// pie pasó a un solo renglón. Las filas quedaron más juntas y el camino
/// se lee como un camino y no como una grilla de círculos sueltos: eran
/// 640 px de alto para diez semanas, ahora son 584.
const double _altoFila = 146;

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

/// Cuánto se comba cada tramo del camino, como fracción de su largo.
///
/// Es lo que hace que el recorrido se lea como un CAMINO y no como el
/// contorno de una tabla. Los tramos de una fila se comban de a uno
/// hacia abajo y de a uno hacia arriba —una onda larga, nunca un
/// zigzag—, y el giro de fila se abre hacia el borde de la pantalla,
/// que es la forma que toma una curva de verdad cuando cambia de
/// sentido.
///
/// LOS CENTROS DE LOS NODOS NO SE TOCAN: siguen clavados en la grilla,
/// todos a la misma altura dentro de su fila y a la misma distancia
/// entre sí. Lo único que se curva es el trazo que va de uno al otro.
/// Un nodo fuera de la grilla se lee como un error de alineación; un
/// trazo curvo se lee como un camino.
const double _ondaDelTramo = 0.13;
const double _aperturaDelGiro = 0.26;

/// Qué tan cerca de las puntas caen los controles del giro de fila.
///
/// Chico a propósito: con 0.22 la cinta sale del nodo casi de costado y
/// pasa POR FUERA del renglón de monedas que cuelga debajo. Con el
/// reparto parejo salía derecho hacia abajo y lo atravesaba.
const double _repartoDelGiro = 0.22;

/// Grosor de la cinta del camino.
///
/// Una CINTA y no un cable. CLAUDE.md pide una sola cosa levantada por
/// pantalla, y acá esa cosa es el camino: a 5 px era un alambre entre
/// círculos y el ojo no tenía dónde apoyarse, a 9 px el recorrido tiene
/// cuerpo propio y se lee como el protagonista.
const double _grosorCinta = 9;

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

  @override
  Widget build(BuildContext context) {
    final recorrido = objetivos.recorrido;
    final enCurso = objetivos.enCurso;
    final ganadas = objetivos.monedasGanadas;

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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // El titular nombra la PANTALLA, no la semana en
                        // curso: acá abajo está el programa entero, y un
                        // titular que dice "SEMANA 3" arriba de diez
                        // nodos se lee como si la pantalla fuera de esa
                        // sola semana. En qué semana va se dice en el
                        // renglón de abajo, que es su tamaño.
                        Text('TU CAMINO', style: AppTheme.sectionTitle),
                        const SizedBox(height: 2),
                        Text(
                          // Solo la semana. El rango se fue a su tarjeta,
                          // que es donde además se explica cómo se sube;
                          // acá arriba los dos juntos eran dos escaleras
                          // distintas en el mismo renglón.
                          enCurso == null
                              ? '${objetivos.semanas.length} semanas'
                              : 'Semana ${enCurso.numero} de '
                                    '${objetivos.semanas.length}',
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
            // Una sola tira que scrollea: la tarjeta de rango y el camino
            // se mueven juntos. Antes el camino tenía su propio scroll, y
            // con algo debajo habrían quedado dos scrolls anidados, que
            // es la forma más rápida de que ninguno de los dos responda
            // bien al dedo.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  children: [
                    // EL PATROCINADOR YA NO VIVE ACÁ (decisión de Daniel,
                    // 21 de septiembre de 2026). Estaba la foto de la
                    // marca de la semana en curso a pantalla completa y,
                    // debajo, un botón con las marcas de las semanas que
                    // vienen: dos bloques de publicidad antes de ver el
                    // camino, que es el protagonista de la pantalla.
                    //
                    // Ahora cada marca aparece al ABRIR su semana, que es
                    // el momento en que el usuario preguntó por ella. En
                    // el camino quedan las dos señales chicas de siempre:
                    // el logo montado en el borde del nodo y el anillo
                    // con el color de la marca.
                    _RenglonRango(
                      rango: objetivos.rangoActual,
                      // El siguiente sale de las reglas y no de
                      // `rango + 1`: en el tope de la escalera no hay
                      // siguiente y la frase cambia.
                      siguiente: objetivos.rangoActual < rangoMaximo
                          ? objetivos.rangoActual + 1
                          : null,
                    ),
                    _Camino(
                      recorrido: recorrido,
                      rangoActual: objetivos.rangoActual,
                      totalSemanas: objetivos.semanas.length,
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

/// Llave del renglón de rango, para los tests.
const Key llaveRenglonRango = ValueKey('renglon-rango');

/// En qué rango va el usuario y CÓMO SE SUBE.
///
/// La segunda mitad es la razón de existir de este renglón. El medallón
/// ya estaba en la pantalla —suelto, al lado del título—, pero en ningún
/// lado decía qué hace subir una muesca: el usuario veía una escalera de
/// diez escalones y ninguna regla para moverse.
///
/// Es UNA oración y dice las dos direcciones. Que se pueda BAJAR no es
/// un detalle que se pueda callar: es la mitad de la mecánica, y
/// enterarse un lunes de que se bajó sin que nadie lo hubiera avisado se
/// siente un castigo escondido.
///
/// YA NO ES UNA TARJETA (decisión de Daniel, 22 de septiembre de 2026).
/// Era un bloque de `azulNiebla` con radio propio arriba del camino, y
/// CLAUDE.md pide UNA sola cosa levantada por pantalla: acá esa cosa es
/// el camino. Con la superficie afuera, el medallón se apoya directo
/// sobre el fondo y lo único que separa esta información del recorrido
/// es una línea de un pelo, que es lo que hace iOS.
///
/// Sin números de monedas acá: cuánto paga cada escalón está debajo de
/// cada nodo del camino, que es donde se compara uno contra otro.
class _RenglonRango extends StatelessWidget {
  const _RenglonRango({required this.rango, required this.siguiente});

  final int rango;

  /// El escalón que sigue, o null si ya está en el último.
  final int? siguiente;

  @override
  Widget build(BuildContext context) {
    final siguiente = this.siguiente;

    return Column(
      key: llaveRenglonRango,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Row(
            children: [
              // Más grande que antes (56 -> 68): era lo único de la
              // pantalla que habla del usuario y estaba del tamaño de un
              // ícono.
              InsigniaRango(rango: rango, tamano: 68),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rango $rango de $rangoMaximo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      siguiente == null
                          // En el tope no se promete un escalón que no
                          // existe, pero se sigue pudiendo bajar.
                          ? 'Llegaste al último. Cumplí los tres objetivos '
                                'de la semana para quedarte acá.'
                          : 'Cumplí los tres objetivos de la semana y subís '
                                'al $siguiente. Si no, bajás uno.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // La línea de un pelo que reemplaza al borde de la tarjeta. Corta
        // de lado a lado y no de margen a margen: así se lee como el
        // corte entre dos secciones y no como el contorno de una caja.
        Container(height: 0.5, color: AppColors.separador),
      ],
    );
  }
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
  });

  final List<PasoDelPrograma> recorrido;
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
  static List<({int columna, int fila})> _serpentina(
    int cuantas,
    int columnas,
  ) {
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
                : const Duration(milliseconds: 1200),
            curve: Curves.easeInOutCubic,
            builder: (context, t, _) {
              // El camino se DIBUJA, tramo por tramo, y cada nodo
              // aparece cuando la cinta llega hasta él. Es lo que
              // convierte una grilla de círculos en un recorrido: se ve
              // de dónde viene y hacia dónde sigue.
              final tramos = math.max(recorrido.length - 1, 1);
              double aparicionDe(int i) => quieto
                  ? 1
                  // El 0.9 le da ventaja al nodo sobre la cinta: si
                  // apareciera justo cuando el trazo lo toca, la punta
                  // de la cinta se vería llegar a un lugar vacío.
                  : (t * tramos - i + 0.9).clamp(0.0, 1.0);

              return SizedBox(
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
                          aparicion: aparicionDe(i),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Dibuja SOLO la cinta que une los nodos.
///
/// Ni círculos, ni números, ni monedas: todo eso son widgets. Un pintor
/// que también dibujara los nodos no podría recibir toques, no tendría
/// etiqueta para VoiceOver y no crecería si el usuario sube el tamaño de
/// letra en iOS.
///
/// NINGÚN TRAMO ES RECTO. Cada uno se comba hacia un lado —los de una
/// fila alternando arriba y abajo, el giro abriéndose hacia el borde—,
/// así que lo que se ve es una cinta que ondula y no el contorno de una
/// tabla. Los CENTROS siguen en la grilla: lo que se curva es el trazo
/// entre uno y otro, nunca el lugar del nodo.
class _PintorCamino extends CustomPainter {
  const _PintorCamino({
    required this.centros,
    required this.recorrido,
    required this.crecimiento,
  });

  final List<Offset> centros;
  final List<PasoDelPrograma> recorrido;
  final double crecimiento;

  /// Si el tramo que SALE de la semana [i] ya se caminó.
  ///
  /// Manda la semana de arriba: ese es el tramo por el que se bajó. Si
  /// no se cumplió, queda pálido. Nada se marchita ni se pinta de rojo —
  /// la app tiene que transmitir calma, no reproche.
  bool _caminado(int i) =>
      !recorrido[i].proyectado && recorrido[i].semana.subioDeRango;

  /// El último tramo ya caminado, o null si no hay ninguno.
  int? _hastaDonde() {
    for (var i = centros.length - 2; i >= 0; i--) {
      if (_caminado(i)) return i;
    }
    return null;
  }

  /// El pincel de lo ya caminado.
  ///
  /// Un degradado del azul de apoyo al de marca y no un color plano, por
  /// lo mismo que lo llevan las barras de las gráficas: es lo que hace
  /// que la cinta se vea como un volumen y no como un rectángulo de
  /// color.
  ///
  /// Se estira sobre LO CAMINADO y no sobre el lienzo entero: lo
  /// recorrido vive siempre arriba, así que medido contra la caja
  /// completa saldría todo del mismo azul pálido y el degradado no se
  /// vería.
  Paint _pincelVivo(Offset desde, Offset hasta) =>
      pincelCurva(AppColors.accent, _grosorCinta)
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [AppColors.azulMedio, AppColors.accent],
        ).createShader(Rect.fromPoints(desde, hasta).inflate(_grosorCinta * 2));

  @override
  void paint(Canvas lienzo, Size caja) {
    final tramos = centros.length - 1;
    if (tramos <= 0) return;

    final hasta = _hastaDonde();
    final vivo = hasta == null
        ? null
        : _pincelVivo(centros.first, centros[hasta + 1]);
    final apagado = pincelCurva(AppColors.azulBruma, _grosorCinta);

    // Cuántos tramos horizontales van dibujados: es lo que alterna la
    // onda. Uno se comba hacia abajo y el siguiente hacia arriba, así
    // que una fila entera es una sola ese larga.
    var horizontales = 0;

    for (var i = 0; i < tramos; i++) {
      final a = centros[i];
      final b = centros[i + 1];
      final esHorizontal = (a.dy - b.dy).abs() < 0.5;

      final Path trazo;
      if (esHorizontal) {
        // El signo se mide contra la perpendicular de AVANCE, que se da
        // vuelta cuando la fila vuelve hacia la izquierda. Corregirlo
        // con la dirección es lo que mantiene la misma onda en toda la
        // pantalla en vez de espejarla fila por medio.
        final haciaLaDerecha = b.dx > a.dx;
        final lado = (horizontales.isEven ? 1 : -1) * (haciaLaDerecha ? 1 : -1);
        horizontales++;
        trazo = curvaArco(a, b, amplitud: _ondaDelTramo * lado);
      } else {
        // El giro de fila se abre hacia AFUERA, hacia el borde más
        // cercano: abierto hacia adentro se cruzaría con la columna del
        // medio.
        final porLaDerecha = a.dx > caja.width / 2;
        trazo = curvaArco(
          a,
          b,
          amplitud: _aperturaDelGiro * (porLaDerecha ? -1 : 1),
          reparto: _repartoDelGiro,
        );
      }

      final avance = (crecimiento * tramos - i).clamp(0.0, 1.0);
      if (avance <= 0) continue;

      trazarCurva(lienzo, trazo, apagado, avance);
      if (vivo != null && _caminado(i)) {
        trazarCurva(lienzo, trazo, vivo, avance);
      }
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
    required this.aparicion,
  });

  final PasoDelPrograma paso;
  final int rangoActual;
  final int totalSemanas;

  /// Cuánto lleva aparecido este nodo, de 0 a 1.
  ///
  /// Lo reparte el camino según cuándo la cinta llega hasta acá: los
  /// nodos no entran todos juntos, entran en fila detrás del trazo.
  final double aparicion;

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
  );

  @override
  Widget build(BuildContext context) {
    final aparicion = widget.aparicion;

    return Semantics(
      button: true,
      label: 'Semana ${_semana.numero}, ${_dicho()}',
      excludeSemantics: true,
      child: Opacity(
        // Entra creciendo y no deslizándose: un nodo que se desliza se
        // despega de la cinta, que ya está dibujada en su lugar.
        opacity: Curves.easeOut.transform(aparicion),
        child: Transform.scale(
          scale: 0.76 + 0.24 * Curves.easeOutBack.transform(aparicion),
          child: _cuerpo(context),
        ),
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    final estado = _semana.estado;
    final cumplida = estado == EstadoSemana.cerrada && _semana.subioDeRango;
    final enCurso = estado == EstadoSemana.enCurso;
    final patrocinio = _semana.patrocinio;

    return GestureDetector(
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
            // LA ETIQUETA "SEMANA N" QUEDÓ SOLO EN LA QUE CORRE.
            //
            // La llevaban los diez nodos, y eran diez cajitas blancas
            // con borde flotando sobre el camino: el ojo leía la
            // grilla de etiquetas y no el recorrido. Ahora el número
            // vive DENTRO del círculo en los tres estados —antes la
            // semana cumplida mostraba un check y por eso hacía falta
            // rotularla por fuera—, así que la etiqueta sobraba.
            //
            // La que queda es la de la semana en curso, rellena de
            // azul: es la que dice "acá estás", y es la única que no
            // se puede deducir mirando el círculo.
            //
            // Márgenes negativos: la etiqueta es más ancha que el halo
            // y tiene que quedar centrada sobre él sin correr el
            // círculo. `heightFactor` la deja pegada al borde de abajo
            // de su caja.
            if (enCurso)
              Positioned(
                left: -_desbordeEtiqueta,
                right: -_desbordeEtiqueta,
                bottom:
                    _altoFila / 2 + _diametroVisible(cumplida, enCurso) / 2 + 5,
                child: Center(
                  heightFactor: 1,
                  child: _EtiquetaSemana(numero: _semana.numero),
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

  /// Qué le dice el nodo a VoiceOver.
  ///
  /// Lleva el rango que el pie del nodo dejó de escribir: en la pantalla
  /// esa relación la explica la tarjeta de arriba, pero alguien que
  /// recorre el camino con el lector de a un nodo por vez nunca la
  /// escuchó, y "más 20 monedas" solo no dice a dónde lleva.
  String _dicho() {
    final paso = widget.paso;

    return switch (_semana.estado) {
      EstadoSemana.cerrada when _semana.subioDeRango =>
        'cumplida, ganaste ${paso.monedas} monedas y subiste al rango '
            '${paso.rangoAlCerrar}',
      EstadoSemana.cerrada => 'cerrada, no subiste de rango',
      EstadoSemana.enCurso =>
        'esta semana, ${_semana.cumplidos} de '
            '${_semana.objetivos.length} objetivos, '
            '${_loQuePaga(paso)}',
      EstadoSemana.futura => 'empieza más adelante, ${_loQuePaga(paso)}',
    };
  }

  /// "paga 20 monedas al subir al rango 4", o nada si no paga.
  ///
  /// Una semana que no sube de rango no paga: decir "paga 0 monedas"
  /// sería anunciar un premio que no existe.
  String _loQuePaga(PasoDelPrograma paso) => paso.monedas <= 0
      ? 'sin monedas'
      : 'paga ${paso.monedas} monedas al subir al rango '
            '${paso.rangoAlCerrar}';
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
///
/// LOS TRES ESTADOS DICEN QUÉ SEMANA SON, y lo que los separa es el
/// color, no el contenido: cumplida en azul sólido, la que corre en
/// blanco con el borde azul y su halo, la futura en azul pálido.
///
/// Y lo dicen con todas las letras —"SEM 7" y no un 7 suelto—. En esta
/// pantalla conviven tres escaleras de números: semanas, rangos y
/// monedas. Un número solo adentro de un círculo puede ser cualquiera de
/// las tres, y lo que el usuario necesita saber al mirar adelante es a
/// qué SEMANA va a entrar. Tres letras lo resuelven sin colgarle una
/// etiqueta al nodo: rotular los diez por fuera eran diez cajitas
/// blancas flotando sobre el camino, y el ojo terminaba leyendo la
/// grilla de etiquetas en vez del recorrido.
///
/// La cumplida mostraba un check en vez del número. El check decía algo
/// que el color ya dice —esta se cumplió— y a cambio escondía lo único
/// que el color no puede decir: cuál semana es.
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
    if (cumplida) return _cumplida(context);
    return _apagada(context);
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

  /// "SEM" chiquito arriba del número, los dos adentro del círculo.
  ///
  /// El rótulo va más apagado que el número: dice de qué se habla, no
  /// cuál es. Si los dos pesaran igual, la palabra competiría con el
  /// dato, que es lo que se compara de un nodo al otro.
  static Widget _dice(
    BuildContext context,
    int numero,
    Color color,
    double tamano,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'SEM',
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          height: 1,
          color: color.withValues(alpha: 0.72),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        '$numero',
        maxLines: 1,
        style: AppTheme.display(tamano).copyWith(color: color, height: 1),
      ),
    ],
  );

  Widget _cumplida(BuildContext context) => Container(
    width: _dCumplida,
    height: _dCumplida,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.accent,
      shape: BoxShape.circle,
      boxShadow: _relieve(AppColors.azulSombra),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: _dice(context, semana.numero, Colors.white, 23),
      ),
    ),
  );

  Widget _enCurso(BuildContext context) => SizedBox(
    width: _dHalo,
    height: _dHalo,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // El halo dice "acá estás" sin necesitar otro color: es el mismo
        // azul, más pálido y más grande. RESPIRA, muy despacio y muy
        // poco: es lo único de la pantalla que se mueve solo, y en una
        // app que tiene que transmitir calma un latido lento es lo que
        // separa un "estás acá" de un cartel parpadeando.
        const _HaloQueRespira(diametro: _dHalo),
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
                  // Sin el "SEM" de los otros dos: arriba de este nodo
                  // está la única etiqueta del camino, que ya dice
                  // "Semana 3" con todas las letras. Repetirlo adentro
                  // sería decirlo dos veces en 30 px.
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

  /// La que todavía no llegó, y también la que cerró SIN cumplirse.
  ///
  /// Las dos van pálidas porque las dos son lo mismo para el camino: por
  /// ahí no se subió. La cerrada se distingue con un borde sólido —no
  /// con rojo ni con una cruz—: la app tiene que transmitir calma, y
  /// debajo del nodo ya dice "Sin monedas".
  Widget _apagada(BuildContext context) {
    final fallada = semana.estado == EstadoSemana.cerrada;

    return Container(
      width: _dFutura,
      height: _dFutura,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.azulBruma,
        shape: BoxShape.circle,
        border: fallada
            ? Border.all(color: AppColors.azulSuave, width: 2)
            : null,
        boxShadow: _relieve(AppColors.azulTenue),
      ),
      // Sin candado, a propósito: no hay nada que el usuario pueda hacer
      // para "abrir" esta semana. Llega cuando llega.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: _dice(context, semana.numero, AppColors.azulMedio, 21),
        ),
      ),
    );
  }
}

/// El halo de la semana en curso, latiendo muy despacio.
///
/// Crece un 6% en tres segundos y vuelve. Es el único movimiento
/// perpetuo del camino y tiene que quedar en el borde de lo que se nota:
/// lo que hace es que el ojo vuelva solo al "acá estás" después de
/// recorrer las diez semanas.
///
/// Se queda quieto si el usuario pidió "Reducir movimiento" en iOS — y
/// por ahí pasan también los tests, que con un latido eterno nunca
/// terminarían de asentarse.
class _HaloQueRespira extends StatefulWidget {
  const _HaloQueRespira({required this.diametro});

  final double diametro;

  @override
  State<_HaloQueRespira> createState() => _HaloQueRespiraState();
}

class _HaloQueRespiraState extends State<_HaloQueRespira>
    with SingleTickerProviderStateMixin {
  late final AnimationController _latido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _latido.stop();
    } else if (!_latido.isAnimating) {
      _latido.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _latido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _latido,
      builder: (context, hijo) => Transform.scale(
        scale: 1 + 0.06 * Curves.easeInOut.transform(_latido.value),
        child: hijo,
      ),
      child: Container(
        width: widget.diametro,
        height: widget.diametro,
        decoration: const BoxDecoration(
          color: AppColors.azulBruma,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

/// Llave de la etiqueta de la semana EN CURSO.
const Key llaveEtiquetaEnCurso = ValueKey('etiqueta-semana-en-curso');

/// La etiqueta "Semana N" que flota sobre el nodo de la semana en curso.
///
/// Es la ÚNICA etiqueta del camino: la llevaban los diez nodos y el ojo
/// terminaba leyendo diez cajitas en vez del recorrido. Rellena de azul
/// de marca, que es lo que la hace saltar sin meter otro color.
///
/// Va sobre fondo sólido y no suelta sobre el fondo de la pantalla: el
/// tramo vertical del camino entra al nodo justo por ahí, y una línea
/// azul cruzando el texto se lee como un tachón.
class _EtiquetaSemana extends StatelessWidget {
  const _EtiquetaSemana({required this.numero});

  final int numero;

  @override
  Widget build(BuildContext context) => Container(
    key: llaveEtiquetaEnCurso,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      'Semana $numero',
      maxLines: 1,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
        color: Colors.white,
        height: 1.2,
      ),
    ),
  );
}

/// Lo que paga la semana, DEBAJO del nodo y centrado.
///
/// Abajo y no al lado: con tres columnas en el ancho de un iPhone no
/// queda lugar para poner nada a los costados del círculo.
///
/// SOLO EL NÚMERO. Decía "+15 al Rango 3", en dos renglones y en los
/// diez nodos: la misma frase diez veces, con el rango cambiando de a
/// uno. Cómo se sube de rango lo explica ahora la tarjeta de arriba, una
/// sola vez y con palabras; acá abajo lo único que hace falta es cuánto
/// paga cada semana, que es lo que se compara de un nodo al otro.
class _PieDelNodo extends StatelessWidget {
  const _PieDelNodo({required this.paso, required this.cumplida});

  final PasoDelPrograma paso;
  final bool cumplida;

  /// El fondo que separa el texto de la cinta que pasa por detrás.
  ///
  /// Va del color del FONDO DE PANTALLA y no de blanco. Era una pastilla
  /// blanca y sumaba diez tarjetitas más a una pantalla que ya tenía
  /// demasiadas cajas; del color del fondo hace el mismo trabajo —cortar
  /// la cinta para que no cruce el renglón de las monedas— sin que se
  /// vea ninguna caja.
  ///
  /// El corte es chico porque el giro de fila sale del nodo de costado
  /// (ver [_repartoDelGiro]): la cinta esquiva casi todo el renglón en
  /// vez de atravesarlo por el medio.
  static Widget _sobreElFondo(Widget hijo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.fondoDePantalla,
      borderRadius: BorderRadius.circular(AppRadios.pildora),
    ),
    child: hijo,
  );

  @override
  Widget build(BuildContext context) {
    if (paso.monedas <= 0) {
      return Center(
        heightFactor: 1,
        child: _sobreElFondo(
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

    final fila = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MonedaAnimada(size: 14, apagado: paso.proyectado),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            '+${paso.monedas}',
            maxLines: 1,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 12,
              height: 1.2,
              fontWeight: cumplida ? FontWeight.w800 : FontWeight.w600,
              // Naranja solo lo YA GANADO: el naranja está reservado a
              // las monedas de verdad, y las de una semana que todavía
              // no cerró son una proyección.
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
      child: _sobreElFondo(futura ? Opacity(opacity: 0.75, child: fila) : fila),
    );
  }
}
