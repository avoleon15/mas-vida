import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/moneda_animada.dart';
import '../widgets/curva_camino.dart';
import '../widgets/tarjeta_semana.dart';

// ============================================================
// EL CAMINO DE LAS SEMANAS.
//
// Un nodo por semana, de arriba (la 1) hacia abajo (la última), unidos
// por una curva que serpentea. Se llega desde "Objetivos de la semana"
// en Hoy y se toca un nodo para abrir esa semana.
//
// POR QUÉ SERPENTEA. Una columna recta de círculos se lee como una lista
// y se escanea de un vistazo; una curva obliga al ojo a recorrerla, que
// es lo que hace sentir que es un camino con largo. Es un patrón de
// género, no una copia: quedan afuera los candados, el relieve grueso,
// los colores saturados y las mascotas. La app es de seguros y tiene que
// transmitir calma.
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
/// Tiene que aguantar el nodo más alto —el de la semana en curso— entero:
/// píldora (20) + aire (5) + halo (88) + aire (6) + pie (14) da 133, y a
/// 132 la columna se desbordaba. Los 152 dejan margen para cuando el
/// usuario sube el tamaño de letra en iOS.
const double _altoFila = 152;

/// Diámetro de cada tipo de nodo.
const double _dCumplida = 62;
const double _dEnCurso = 74;
const double _dFutura = 58;

/// El halo que rodea al nodo de la semana en curso.
const double _dHalo = 88;

/// Cuánto se corre cada nodo a los costados, como fracción del ancho.
///
/// Es una onda y no un zigzag de dos carriles: con dos posiciones fijas
/// el camino se lee como una escalera de caracol y se vuelve repetitivo.
const double _amplitud = 0.20;

/// Cuánto avanza la onda por semana, en radianes. Cerca de 1 da algo
/// más de media vuelta por nodo: serpentea sin llegar a hacer rulos.
const double _pasoDeOnda = 0.95;

/// Ancho del pie que va debajo de cada nodo (la moneda y el monto).
const double _anchoPie = 150;

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
    final cobradas = objetivos.monedasGanadas;

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
                        Text(
                          'LAS ${objetivos.semanas.length} SEMANAS',
                          style: AppTheme.sectionTitle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          enCurso == null
                              ? 'Rango ${objetivos.rangoActual}'
                              : 'Vas en la semana ${enCurso.numero} · '
                                    'Rango ${objetivos.rangoActual}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (cobradas > 0) _MonedasCobradas(monedas: cobradas),
                ],
              ),
            ),
            Expanded(
              child: _Camino(
                recorrido: recorrido,
                rangoActual: objetivos.rangoActual,
                totalSemanas: objetivos.semanas.length,
                numeroSiguienteDe: objetivos.numeroDespuesDe,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lo ya cobrado, en el encabezado.
class _MonedasCobradas extends StatelessWidget {
  const _MonedasCobradas({required this.monedas});

  final int monedas;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Llevás $monedas monedas cobradas',
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

  @override
  Widget build(BuildContext context) {
    if (recorrido.isEmpty) return const SizedBox.shrink();

    final quieto = MediaQuery.disableAnimationsOf(context);
    final alto = recorrido.length * _altoFila;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: LayoutBuilder(
        builder: (context, medidas) {
          final ancho = medidas.maxWidth;

          // Los centros los calcula UNA sola vez y los leen tanto el
          // pintor como los nodos. Si cada uno tuviera su cuenta, la
          // curva podría no pasar por los círculos — el mismo problema
          // que ya resolvió la barra inferior sacando el ancho del
          // indicador del ancho de los ítems.
          final centros = [
            for (var i = 0; i < recorrido.length; i++)
              Offset(
                ancho / 2 + math.sin(i * _pasoDeOnda) * ancho * _amplitud,
                (i + 0.5) * _altoFila,
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
                      left: centros[i].dx - _anchoPie / 2,
                      top: centros[i].dy - _altoFila / 2,
                      width: _anchoPie,
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

      trazarCurva(
        lienzo,
        curvaTallo(centros[i], centros[i + 1], amplitud: 0.1),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (enCurso) ...[
                const _PildoraEstaSemana(),
                const SizedBox(height: 5),
              ],
              _Circulo(semana: _semana, cumplida: cumplida, enCurso: enCurso),
              const SizedBox(height: 6),
              _PieDelNodo(paso: widget.paso, cumplida: cumplida),
            ],
          ),
        ),
      ),
    );
  }

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

/// La píldora que flota sobre el nodo de la semana en curso.
class _PildoraEstaSemana extends StatelessWidget {
  const _PildoraEstaSemana();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.accent, width: 1.5),
    ),
    child: Text(
      'ESTA SEMANA',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppColors.accent,
        height: 1,
      ),
    ),
  );
}

/// Lo que paga la semana, debajo del nodo.
class _PieDelNodo extends StatelessWidget {
  const _PieDelNodo({required this.paso, required this.cumplida});

  final PasoDelPrograma paso;
  final bool cumplida;

  @override
  Widget build(BuildContext context) {
    if (paso.monedas <= 0) {
      return Text(
        // Una semana que no pagó no se deja en blanco: el hueco se lee
        // como un error de carga.
        'Sin monedas',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
      );
    }

    final futura = paso.semana.estado == EstadoSemana.futura;

    final texto = cumplida
        ? '+${paso.monedas} cobradas'
        : '+${paso.monedas} al Rango ${paso.rangoAlCerrar}';

    final fila = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MonedaAnimada(size: 15, apagado: paso.proyectado),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
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
    return futura ? Opacity(opacity: 0.75, child: fila) : fila;
  }
}
