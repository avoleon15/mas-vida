import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../reglas_puntos.dart';
import '../theme.dart';

/// Los tres períodos del selector.
enum Periodo {
  semana('Semana'),
  mes('Mes'),
  anio('Año');

  const Periodo(this.etiqueta);
  final String etiqueta;
}

/// Un punto de las gráficas: una etiqueta del eje X y sus dos medidas.
///
/// Pasos y puntos viajan juntos porque salen del mismo día, pero NUNCA se
/// dibujan en la misma gráfica: son dos escalas distintas y mezclarlas en
/// un solo eje es la forma más rápida de mentir con un gráfico.
class PuntoPeriodo {
  const PuntoPeriodo({
    required this.etiqueta,
    required this.pasos,
    required this.puntos,
    required this.hayDatos,
  });

  final String etiqueta;
  final int pasos;
  final int puntos;

  /// False para los tramos que todavía no ocurrieron. No es lo mismo que
  /// cero.
  final bool hayDatos;
}

/// Tarjeta única de "Puntos": el selector de período, el acumulado del
/// período contra su techo, la comparación con el período anterior, y las
/// dos gráficas.
///
/// Reemplaza a las dos tarjetas que había antes, que mostraban lo mismo
/// con distinta cara.
class TarjetaPuntos extends StatefulWidget {
  const TarjetaPuntos({
    super.key,
    required this.periodo,
    required this.onCambiarPeriodo,
  });

  final Periodo periodo;
  final ValueChanged<Periodo> onCambiarPeriodo;

  @override
  State<TarjetaPuntos> createState() => _TarjetaPuntosState();
}

class _TarjetaPuntosState extends State<TarjetaPuntos> {
  // ----------------------------------------------------------
  // Datos del período.
  // ----------------------------------------------------------

  List<PuntoPeriodo> get _serie => switch (widget.periodo) {
    Periodo.semana => _serieSemana,
    Periodo.mes => _serieMes,
    Periodo.anio => _serieAnio,
  };

  static const _letras = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  List<PuntoPeriodo> get _serieSemana {
    final dias = Datos.i.historial.semanaEnCurso;
    return [
      for (var i = 0; i < 7; i++)
        if (i < dias.length)
          PuntoPeriodo(
            etiqueta: _letras[i],
            pasos: dias[i].pasos ?? 0,
            puntos: dias[i].puntosDia,
            hayDatos: dias[i].pasos != null,
          )
        else
          // Los días que todavía no llegaron no son días con cero pasos.
          PuntoPeriodo(
            etiqueta: _letras[i],
            pasos: 0,
            puntos: 0,
            hayDatos: false,
          ),
    ];
  }

  /// El mes agrupado por semanas reales.
  ///
  /// No se asume que un mes tenga cuatro semanas: se agrupa por el lunes
  /// de cada día, así que un mes con cinco lunes da cinco barras solo.
  List<PuntoPeriodo> get _serieMes {
    final porSemana = <DateTime, List<DiaActividad>>{};
    for (final d in Datos.i.historial.mesEnCurso) {
      final lunes = DateTime(
        d.fecha.year,
        d.fecha.month,
        d.fecha.day,
      ).subtract(Duration(days: d.fecha.weekday - 1));
      porSemana.putIfAbsent(lunes, () => []).add(d);
    }
    final ordenadas = porSemana.keys.toList()..sort();
    return [
      for (var i = 0; i < ordenadas.length; i++)
        PuntoPeriodo(
          // El rango de días de esa semana, no "S1".
          //
          // "S1" se confundía con la pestaña Semana del selector: parecía
          // que la gráfica seguía mostrando semanas sueltas. El rango de
          // fechas dice exactamente qué tramo del mes es.
          etiqueta: _diaDeInicio(porSemana[ordenadas[i]]!),
          pasos: porSemana[ordenadas[i]]!.fold(0, (t, d) => t + (d.pasos ?? 0)),
          puntos: porSemana[ordenadas[i]]!.fold(0, (t, d) => t + d.puntosDia),
          hayDatos: true,
        ),
    ];
  }

  /// El día en que arranca esa semana dentro del mes.
  ///
  /// Solo el número: el mes va una vez en el subtítulo de la gráfica, no
  /// repetido en cada etiqueta.
  ///
  /// Antes acá iba el rango completo ("3-9"). Ocupaba mucho y las semanas
  /// partidas por el borde del mes quedaban como "1-2" o "24-26", que se
  /// leen como errores. Y antes de eso decía "S1", que se confundía con
  /// la pestaña Semana del selector.
  static String _diaDeInicio(List<DiaActividad> dias) {
    final ordenados = [...dias]..sort((a, b) => a.fecha.compareTo(b.fecha));
    return '${ordenados.first.fecha.day}';
  }

  /// Nombre del mes en curso, para el subtítulo de la gráfica.
  static String get _nombreMesActual {
    const nombres = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return nombres[Datos.i.historial.hoy.fecha.month - 1];
  }

  static const _meses = [
    'E', 'F', 'M', 'A', 'M', 'J', //
    'J', 'A', 'S', 'O', 'N', 'D',
  ];

  List<PuntoPeriodo> get _serieAnio {
    final porMes = Datos.i.resumen.actividadPorMes;
    final actual = Datos.i.resumen.mesActualIndice;
    return [
      for (var i = 0; i < porMes.length; i++)
        PuntoPeriodo(
          etiqueta: _meses[i],
          // El resumen anual solo trae puntos por mes, no pasos.
          pasos: 0,
          puntos: porMes[i],
          hayDatos: i <= actual,
        ),
    ];
  }

  int get _puntosDelPeriodo => switch (widget.periodo) {
    Periodo.semana => Datos.i.resumen.puntosSemana,
    Periodo.mes => Datos.i.resumen.puntosMes,
    Periodo.anio => Datos.i.resumen.puntosAno,
  };

  /// Techo del período.
  ///
  /// El año NO es 200 × 365: los puntos por actividad topan en el techo
  /// anual que fija el contrato. La semana y el mes sí salen del techo
  /// diario, y el mes usa los días reales, así que febrero da menos.
  int get _techoDelPeriodo {
    switch (widget.periodo) {
      case Periodo.semana:
        return techoDiario * 7;
      case Periodo.mes:
        final hoy = Datos.i.historial.hoy.fecha;
        return techoDiario * DateTime(hoy.year, hoy.month + 1, 0).day;
      case Periodo.anio:
        return Datos.i.resumen.techoAnual;
    }
  }

  /// Cuánto cambió contra el período anterior, en porcentaje.
  ///
  /// Null cuando no hay período anterior con el cual comparar.
  int? get _cambio {
    if (widget.periodo != Periodo.semana) return null;
    final previo = Datos.i.resumen.puntosSemanaAnterior;
    if (previo <= 0) return null;
    return (((_puntosDelPeriodo - previo) / previo) * 100).round();
  }

  String get _textoComparacion {
    final cambio = _cambio!;
    final previo = Datos.i.resumen.puntosSemanaAnterior;
    // Frase explícita: antes decía solo "53% vs. semana pasada" y no se
    // entendía si eran más o menos, ni respecto de qué.
    if (cambio == 0) return 'Vas igual que la semana pasada, $previo pts';
    if (cambio > 0) {
      return 'Vas $cambio% arriba de la semana pasada, que cerró en '
          '$previo pts';
    }
    return 'Vas ${cambio.abs()}% abajo de la semana pasada, que cerró en '
        '$previo pts';
  }

  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final serie = _serie;
    // La gráfica de línea solo tiene sentido donde hay pasos por tramo.
    // El resumen anual no los trae, así que en Año no se dibuja en vez de
    // mostrar una línea plana en cero que parecería un dato real.
    final hayPasos = serie.any((p) => p.pasos > 0);
    // En Año no hay barras: ahí el calendario de cuadritos cuenta la
    // misma historia con mucho más detalle.
    final hayBarras = widget.periodo != Periodo.anio;

    return Column(
      children: [
        _TarjetaNumero(
          periodo: widget.periodo,
          onCambiarPeriodo: widget.onCambiarPeriodo,
          puntos: _puntosDelPeriodo,
          techo: _techoDelPeriodo,
          cambio: _cambio,
          textoComparacion: _cambio == null ? null : _textoComparacion,
        ),
        // Las gráficas en su propia tarjeta: mezclarlas con el número
        // grande en una sola hacía que la vista se perdiera entre el dato
        // y los dibujos.
        if (hayPasos || hayBarras) ...[
          const SizedBox(height: AppSpacing.entre),
          _TarjetaGraficas(
            serie: serie,
            hayPasos: hayPasos,
            hayBarras: hayBarras,
            subtituloPasos: switch (widget.periodo) {
              Periodo.semana => 'Pasos de la semana',
              // El mes se dice una sola vez acá, no en cada etiqueta.
              Periodo.mes => 'Pasos por semana de $_nombreMesActual',
              Periodo.anio => 'Pasos',
            },
            subtituloBarras: widget.periodo == Periodo.semana
                ? 'Puntos por día'
                : 'Puntos por semana de $_nombreMesActual',
          ),
        ],
      ],
    );
  }
}

/// Tarjeta del número: el selector de período, el acumulado contra su
/// techo y la comparación con el período anterior.
///
/// Va aparte de las gráficas a propósito. Con el número grande y los dos
/// gráficos en una sola tarjeta, la vista se perdía entre el dato y los
/// dibujos: no quedaba claro dónde terminaba una cosa y empezaba la otra.
///
/// Lleva un tinte azul muy suave para separarse de las tarjetas blancas
/// de gráficas que vienen debajo.
class _TarjetaNumero extends StatelessWidget {
  const _TarjetaNumero({
    required this.periodo,
    required this.onCambiarPeriodo,
    required this.puntos,
    required this.techo,
    required this.cambio,
    required this.textoComparacion,
  });

  final Periodo periodo;
  final ValueChanged<Periodo> onCambiarPeriodo;
  final int puntos;
  final int techo;
  final int? cambio;
  final String? textoComparacion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Degradado muy suave hacia el azul de marca: le da presencia al
        // dato principal sin salirse de la paleta.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card,
            Color.lerp(AppColors.accent, AppColors.card, 0.93)!,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          // Sombra suave, nunca un glow (ver CLAUDE.md).
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mismo estilo que "Pasos de la semana" y "Puntos por día": los
          // tres son títulos del mismo rango y tienen que verse igual.
          // Antes era una etiqueta chica con tracking, que lo dejaba por
          // debajo de sus propios subtítulos.
          const _Subtitulo(texto: 'Puntos'),
          const SizedBox(height: AppSpacing.dentro),

          // El selector vive DENTRO de esta tarjeta: antes flotaba suelto
          // arriba y no se leía a qué le cambiaba el período.
          _SelectorPeriodo(
            seleccionado: periodo,
            onChanged: (p) {
              HapticFeedback.selectionClick();
              onCambiarPeriodo(p);
            },
          ),
          const SizedBox(height: AppSpacing.entre),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _milesGrafica(puntos),
                    style: AppTheme.display(46),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'de ${_milesGrafica(techo)} pts',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          if (cambio != null && textoComparacion != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  cambio! >= 0 ? Icons.trending_up : Icons.trending_down,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    textoComparacion!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta de las gráficas. Blanca y sin tinte, para que el color quede
/// en los datos y no en el fondo.
class _TarjetaGraficas extends StatelessWidget {
  const _TarjetaGraficas({
    required this.serie,
    required this.hayPasos,
    required this.hayBarras,
    required this.subtituloPasos,
    required this.subtituloBarras,
  });

  final List<PuntoPeriodo> serie;
  final bool hayPasos;
  final bool hayBarras;
  final String subtituloPasos;
  final String subtituloBarras;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hayPasos) ...[
            _Subtitulo(texto: subtituloPasos),
            const SizedBox(height: AppSpacing.dentro),
            // Una sola serie: sin leyenda, el subtítulo ya dice qué es.
            GraficaLineaPasos(serie: serie),
          ],
          if (hayPasos && hayBarras) const SizedBox(height: AppSpacing.grupo),
          if (hayBarras) ...[
            _Subtitulo(texto: subtituloBarras),
            const SizedBox(height: AppSpacing.dentro),
            GraficaBarrasPuntos(serie: serie),
          ],
        ],
      ),
    );
  }
}

class _Subtitulo extends StatelessWidget {
  const _Subtitulo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
  );
}

// ============================================================
// Selector de período
// ============================================================

/// Selector segmentado nativo de iOS.
///
/// Es el `CupertinoSlidingSegmentedControl` del sistema, no una imitación:
/// trae gratis el deslizamiento de la píldora, el rebote al soltar y el
/// comportamiento que un usuario de iPhone ya conoce de Ajustes y Salud.
class _SelectorPeriodo extends StatelessWidget {
  const _SelectorPeriodo({required this.seleccionado, required this.onChanged});

  final Periodo seleccionado;
  final ValueChanged<Periodo> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<Periodo>(
        groupValue: seleccionado,
        backgroundColor: AppColors.cardBorder.withValues(alpha: 0.5),
        thumbColor: AppColors.card,
        padding: const EdgeInsets.all(3),
        onValueChanged: (p) {
          if (p != null) onChanged(p);
        },
        children: {
          for (final p in Periodo.values)
            p: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(
                p.etiqueta,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: p == seleccionado
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: p == seleccionado
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
        },
      ),
    );
  }
}

// ============================================================
// Gráficas — fl_chart
// ============================================================

/// Estilo compartido de los ejes: en color de texto normal, NUNCA del
/// color de la serie.
TextStyle _estiloEje(BuildContext context) =>
    Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontSize: 10,
      fontFeatures: const [FontFeature.tabularFigures()],
    ) ??
    const TextStyle(fontSize: 10);

/// 12,400 -> "12.4k". Con los miles completos el eje se come el ancho de
/// la gráfica.
String _corto(num v) {
  if (v < 1000) return '${v.round()}';
  final miles = v / 1000;
  return '${miles.toStringAsFixed(miles >= 10 ? 0 : 1)}k';
}

String _milesGrafica(int v) => v.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

/// Cuadrícula tenue, compartida por las dos gráficas: orienta sin
/// competir con los datos.
FlGridData _grilla(double intervalo) => FlGridData(
  show: true,
  drawVerticalLine: false,
  horizontalInterval: intervalo,
  getDrawingHorizontalLine: (_) =>
      const FlLine(color: AppColors.cardBorder, strokeWidth: 1),
);

/// Etiquetas del eje X, comunes a las dos gráficas.
Widget _etiquetaX(
  BuildContext context,
  List<PuntoPeriodo> serie,
  double valor,
) {
  final i = valor.round();
  if (i < 0 || i >= serie.length) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(serie[i].etiqueta, style: _estiloEje(context)),
  );
}

/// Línea de pasos del período, estilo Strava.
///
/// UNA sola serie y UN solo eje, así que no lleva leyenda: el subtítulo
/// de arriba ya dice qué es. Los puntos no llevan su número encima; el
/// valor aparece al tocar o arrastrar.
class GraficaLineaPasos extends StatelessWidget {
  const GraficaLineaPasos({super.key, required this.serie});

  final List<PuntoPeriodo> serie;

  static const double alto = 150;

  @override
  Widget build(BuildContext context) {
    final conDatos = serie.where((p) => p.hayDatos).toList();
    if (conDatos.length < 2) return const SizedBox.shrink();

    final maximo = conDatos
        .map((p) => p.pasos)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    // Un poco de aire arriba para que el mejor día no toque el techo.
    final tope = maximo <= 0 ? 1000.0 : maximo * 1.15;

    return SizedBox(
      height: alto,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: tope,
          minX: 0,
          maxX: (serie.length - 1).toDouble(),
          gridData: _grilla(tope / 2),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            // La guía de cuántos pasos son, a la derecha.
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: tope / 2,
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(_corto(v), style: _estiloEje(context)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (v, meta) => _etiquetaX(context, serie, v),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            // Área de toque generosa: apuntarle a una marca de 8px con el
            // dedo es imposible.
            touchSpotThreshold: 26,
            getTouchedSpotIndicator: (barra, indices) => [
              for (final _ in indices)
                TouchedSpotIndicatorData(
                  const FlLine(color: AppColors.accent, strokeWidth: 1),
                  FlDotData(
                    getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                      radius: 6,
                      color: AppColors.accent,
                      strokeWidth: 2,
                      strokeColor: AppColors.card,
                    ),
                  ),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.textPrimary,
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${_milesGrafica(s.y.round())} pasos\n'
                    '${serie[s.x.round()].puntos} pts',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < serie.length; i++)
                  if (serie[i].hayDatos)
                    FlSpot(i.toDouble(), serie[i].pasos.toDouble()),
              ],
              isCurved: true,
              curveSmoothness: 0.22,
              // 2px, como pide la guía.
              barWidth: 2,
              color: AppColors.accent,
              dotData: FlDotData(
                getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.accent,
                  strokeWidth: 0,
                  strokeColor: Colors.transparent,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.18),
                    AppColors.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

/// Barras de puntos del período.
///
/// Las de contexto en gris y solo la actual en naranja. El color NO se
/// reasigna al cambiar de período: cada cosa conserva el suyo siempre.
class GraficaBarrasPuntos extends StatelessWidget {
  const GraficaBarrasPuntos({super.key, required this.serie});

  final List<PuntoPeriodo> serie;

  static const double alto = 180;

  /// Mismo valor que el `reservedSize` del eje Y. Se comparte para que la
  /// fila de números de arriba caiga sobre las barras.
  static const double _anchoEjeY = 34;

  @override
  Widget build(BuildContext context) {
    final maximo = serie
        .map((p) => p.puntos)
        .fold(0, (a, b) => a > b ? a : b)
        .toDouble();
    final tope = maximo <= 0 ? 100.0 : maximo * 1.12;
    final actual = serie.lastIndexWhere((p) => p.hayDatos);

    return SizedBox(
      height: alto,
      child: Column(
        children: [
          // Los puntos de cada barra, arriba. Van en color de texto
          // normal, nunca del color de la serie, y solo la actual va en
          // negrita.
          //
          // El padding izquierdo es el mismo `reservedSize` del eje, para
          // que cada número caiga sobre su barra.
          Padding(
            padding: const EdgeInsets.only(left: _anchoEjeY),
            child: Row(
              children: [
                // Un Expanded por barra, con el número centrado.
                //
                // Antes esto era `spaceAround` con los textos sueltos, y
                // los días sin datos son cadenas vacías de ancho cero: al
                // repartir el espacio sobrante entre elementos de ancho
                // distinto, los números se corrían de sus barras. Con
                // Expanded cada uno ocupa exactamente la misma franja que
                // su barra, que es como las reparte fl_chart.
                for (var i = 0; i < serie.length; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        serie[i].hayDatos ? '${serie[i].puntos}' : '',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: i == actual
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: i == actual
                              ? FontWeight.w800
                              : FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: tope,
                gridData: _grilla(tope / 2),
                borderData: FlBorderData(show: false),
                alignment: BarChartAlignment.spaceAround,
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: tope / 2,
                      getTitlesWidget: (v, meta) =>
                          Text(_corto(v), style: _estiloEje(context)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) =>
                          _etiquetaX(context, serie, v),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary,
                    tooltipBorderRadius: BorderRadius.circular(8),
                    getTooltipItem: (grupo, gi, barra, bi) => BarTooltipItem(
                      '${serie[grupo.x].puntos} pts',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < serie.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: serie[i].puntos.toDouble(),
                          width: 22,
                          // Puntas superiores redondeadas, pegadas a la base.
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          // La barra del período en curso, en azul de
                          // marca; las de contexto, en azul lavado.
                          color: i == actual
                              ? AppColors.accent
                              : AppColors.azulBruma,
                        ),
                      ],
                      // El número de puntos arriba de cada barra, en color de
                      // texto normal y nunca del color de la serie.
                      showingTooltipIndicators: const [],
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}
