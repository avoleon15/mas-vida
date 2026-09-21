import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../reglas_puntos.dart';
import 'numero_animado.dart';
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
  /// ¿Ya se cambió de período al menos una vez?
  ///
  /// Es lo que separa "la pantalla se está abriendo" de "el usuario tocó
  /// el selector". La primera vez las gráficas aparecen dibujadas —o
  /// creciendo con la tanda de datos, si es que le toca—; a partir del
  /// primer cambio, cada una entra subiendo desde la base.
  bool _huboCambioDePeriodo = false;

  @override
  void didUpdateWidget(TarjetaPuntos anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.periodo != widget.periodo) _huboCambioDePeriodo = true;
  }

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
          // QUÉ SEMANA DEL MES ES: 1, 2, 3 (pedido de Daniel, 21 de
          // septiembre de 2026).
          //
          // Antes acá iba el día en que arrancaba esa semana ("3", "10",
          // "17", "24") y no se entendía: son números de día sueltos
          // debajo de una gráfica que habla de semanas, así que el
          // primer tramo del mes parecía el tercero.
          //
          // Numerarlas de 1 en adelante sí se entiende, y ahora se puede
          // sin ambigüedad: el eje dice abajo de qué mes son ("semanas
          // de agosto"), que es lo que antes faltaba y hacía que "S1" se
          // confundiera con la pestaña Semana del selector.
          etiqueta: '${i + 1}',
          pasos: porSemana[ordenadas[i]]!.fold(0, (t, d) => t + (d.pasos ?? 0)),
          puntos: porSemana[ordenadas[i]]!.fold(0, (t, d) => t + d.puntosDia),
          hayDatos: true,
        ),
    ];
  }

  /// Nombre del mes en curso, para el nombre del eje.
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
    // EN AÑO NO HAY BARRAS (decisión de Daniel, 21 de septiembre de
    // 2026). Se probó con los puntos mes a mes y no le gustó: doce
    // columnas casi iguales no dicen nada que el mapa de calor no diga
    // mejor, y ese sí muestra el año día por día. En Año la gráfica es
    // el calendario de cuadritos, y una sola.
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
            periodo: widget.periodo,
            crecerAlMontar: _huboCambioDePeriodo,
            serie: serie,
            hayPasos: hayPasos,
            hayBarras: hayBarras,
            subtituloPasos: switch (widget.periodo) {
              Periodo.semana => 'Pasos de la semana',
              // Sin el mes: lo dice el eje, abajo, que es donde están
              // las semanas que hay que ubicar.
              Periodo.mes => 'Pasos por semana',
              Periodo.anio => 'Pasos',
            },
            subtituloBarras: switch (widget.periodo) {
              Periodo.semana => 'Puntos por día',
              Periodo.mes => 'Puntos por semana',
              Periodo.anio => 'Puntos por mes',
            },
            // Qué mide el eje de abajo. En Mes además dice DE QUÉ MES
            // son esas semanas: "1 · 2 · 3" sin el mes son números
            // sueltos.
            nombreEjeX: switch (widget.periodo) {
              Periodo.semana => 'días de la semana',
              Periodo.mes => 'semanas de $_nombreMesActual',
              Periodo.anio => 'meses del año',
            },
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
                  // Los puntos suben desde 0 al entrar. A la izquierda,
                  // porque el "de X pts" va pegado a la derecha y el
                  // ancho ya lo reserva NumeroAnimado.
                  child: NumeroAnimado(
                    valor: puntos,
                    formato: _milesGrafica,
                    estilo: AppTheme.display(46),
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
    required this.periodo,
    required this.crecerAlMontar,
    required this.serie,
    required this.hayPasos,
    required this.hayBarras,
    required this.subtituloPasos,
    required this.subtituloBarras,
    required this.nombreEjeX,
  });

  /// Qué son las marcas del eje de abajo, en las dos gráficas.
  final String nombreEjeX;

  /// True cuando el usuario ya tocó el selector al menos una vez: de ahí
  /// en adelante cada gráfica entra subiendo desde la base.
  final bool crecerAlMontar;

  /// Qué período se está mirando. No se dibuja: sirve de LLAVE, para que
  /// al cambiar de pestaña la gráfica se reemplace en vez de deformarse
  /// hasta la del otro período (ver [_CambioDePeriodo]).
  final Periodo periodo;

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
            _CambioDePeriodo(
              periodo: periodo,
              child: GraficaLineaPasos(
                serie: serie,
                nombreEjeX: nombreEjeX,
                crecerAlMontar: crecerAlMontar,
              ),
            ),
          ],
          if (hayPasos && hayBarras) const SizedBox(height: AppSpacing.grupo),
          if (hayBarras) ...[
            _Subtitulo(texto: subtituloBarras),
            const SizedBox(height: AppSpacing.dentro),
            _CambioDePeriodo(
              periodo: periodo,
              child: GraficaBarrasPuntos(
                serie: serie,
                nombreEjeX: nombreEjeX,
                crecerAlMontar: crecerAlMontar,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cambia la gráfica al cambiar de período: la saliente se desvanece y
/// la entrante SUBE DESDE LA BASE.
///
/// EL BUG QUE ARREGLA (visto por Daniel el 21 de septiembre de 2026). Al
/// pasar de Semana a Mes, la línea se disparaba hasta arriba —se salía
/// de su tarjeta y pintaba encima del número de puntos— y recién después
/// se acomodaba.
///
/// Por qué pasaba: `fl_chart` interpola entre los datos viejos y los
/// nuevos punto por punto, pero las dos series no tienen la misma
/// cantidad de puntos (7 días contra 4 o 5 semanas). Para los puntos que
/// sobran no hay viejo con quien interpolar, así que arrancan YA en su
/// valor final —el total de una semana entera, cinco veces más grande
/// que el de un día— mientras el techo del eje todavía viene subiendo
/// desde el de la semana. Un valor de 60.000 dibujado contra un eje que
/// todavía marca 14.000 cae muy por encima del borde de arriba.
///
/// POR QUÉ ESTA ANIMACIÓN NO PUEDE SALIRSE DE RANGO. No interpola entre
/// las dos series: cada gráfica dibuja SUS datos contra SU propio techo,
/// y lo único que se anima es una escala de 0 a 1 que multiplica los
/// valores. Un valor multiplicado por algo entre 0 y 1 nunca queda por
/// encima de sí mismo, así que nunca pasa el techo — pase lo que pase
/// con los datos, la cantidad de puntos o la diferencia de escala entre
/// un período y otro.
///
/// Y además es la animación que la app ya usa cuando llegan datos: las
/// cosas suben desde la base. Interpolar entre dos períodos tampoco
/// significaría nada —el lunes de la semana y la primera semana del mes
/// no son el mismo dato moviéndose, son dos datos distintos.
///
/// La animación de `fl_chart` sigue prendida para lo que SÍ es el mismo
/// dato moviéndose: un refresco, que trae la misma forma con otros
/// valores.
class _CambioDePeriodo extends StatelessWidget {
  const _CambioDePeriodo({required this.periodo, required this.child});

  final Periodo periodo;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    // Con "Reducir movimiento" el cambio es instantáneo. Sin esto, las
    // dos gráficas conviven un cuadro y un test que hace un solo pump
    // encuentra los datos de los dos períodos a la vez.
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : duracionSalidaDePeriodo,
    // El fundido es el de fábrica, para las dos. La de 150 ms apenas se
    // nota en la que entra —a esa altura su línea recién va por un
    // tercio— y es lo que evita que la saliente desaparezca de golpe.
    switchInCurve: Curves.easeOut,
    switchOutCurve: Curves.easeIn,
    // La llave es el período: es lo que le dice a Flutter que esta es
    // OTRA gráfica y no la misma con otros datos.
    child: KeyedSubtree(key: ValueKey(periodo), child: child),
  );
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

/// Cuánto tarda una gráfica en entrar al cambiar de período.
///
/// Más corta que el crecimiento de una tanda de datos (800 ms): esto es
/// la respuesta a un toque en el selector, y a 800 ms se siente que la
/// app tarda en obedecer. Lo suficientemente larga para que se vea subir.
const Duration duracionCambioDePeriodo = Duration(milliseconds: 420);

/// Cuánto tarda la gráfica saliente en desvanecerse.
///
/// Más corta todavía: las dos conviven en pantalla mientras dura, y dos
/// series encimadas mucho tiempo se leen como un borrón.
const Duration duracionSalidaDePeriodo = Duration(milliseconds: 150);

/// Estilo compartido de los ejes: en color de texto normal, NUNCA del
/// color de la serie.
TextStyle _estiloEje(BuildContext context) =>
    Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontSize: 10,
      fontFeatures: const [FontFeature.tabularFigures()],
    ) ??
    const TextStyle(fontSize: 10);

/// El número de una marca del eje: "1,600" o "14k".
///
/// Se abrevia SOLO a partir de las cinco cifras, que es cuando los miles
/// completos empiezan a comerse el ancho de la gráfica. Antes se
/// abreviaba desde 1.000 y el eje de puntos —que se mueve entre 100 y
/// 2.000— terminaba diciendo "1.6k", que es más difícil de leer que el
/// número entero y encima con un decimal inventado.
String _corto(num v) {
  if (v < 10000) return milesConComa(v.round());
  final miles = v / 1000;
  // Sin decimal cuando no hace falta: la escala ya se redondea a
  // números enteros de miles, y "14.0k" es un decimal que no dice nada.
  final redondo = (miles - miles.roundToDouble()).abs() < 0.05;
  return '${miles.toStringAsFixed(redondo || miles >= 10 ? 0 : 1)}k';
}

/// El techo de una escala, redondeado a un número que se pueda leer.
///
/// POR QUÉ NO ES `máximo × 1.15`. Ese era el techo de antes y dejaba
/// ejes como "14k / 7.1k / 0": números que nadie escribiría a mano y que
/// obligan a leer el eje en vez de mirarlo. Acá el techo se redondea
/// hacia arriba al siguiente escalón lindo —de la familia 1, 2 y 5 por
/// una potencia de diez—, así que el eje siempre cae en cifras enteras y
/// la mitad también.
///
/// El 5% de aire es para que el mejor día no toque el borde de arriba.
double techoLindo(double maximo) {
  if (maximo <= 0) return 1;

  final conAire = maximo * 1.05;
  final escalon = _escalonLindo(conAire);
  return (conAire / escalon).ceil() * escalon;
}

/// El escalón de la familia 1-2-5 con el que se redondea la escala.
double _escalonLindo(double maximo) {
  // Se apunta a OCHO tramos aunque el eje muestre dos números. No es
  // contradictorio: cuanto más fino el escalón, más pegado al dato queda
  // el techo. Con escalones gruesos, 1.500 puntos redondeaban a 2.000 y
  // la barra más alta llegaba a tres cuartos de la gráfica, así que el
  // dibujo se veía vacío arriba. Con ocho, redondea a 1.600.
  final crudo = maximo / 8;
  final magnitud = math.pow(10, (math.log(crudo) / math.ln10).floor()).toDouble();
  final resto = crudo / magnitud;
  final factor = switch (resto) {
    <= 1 => 1.0,
    <= 2 => 2.0,
    <= 5 => 5.0,
    _ => 10.0,
  };
  return magnitud * factor;
}

/// Delega en el formateador único de `numero_animado.dart`: antes esta
/// era una tercera copia del mismo separador de miles.
String _milesGrafica(int v) => milesConComa(v);

/// Cuánto aire queda a cada lado de la línea, en unidades del eje X.
///
/// Sin esto, el primer y el último punto caen JUSTO sobre el borde del
/// área de dibujo: medio círculo del lunes quedaba cortado contra el
/// borde de la tarjeta, y la etiqueta del domingo se metía debajo de la
/// columna del eje de la derecha, encimada con el "0".
///
/// MEDIA COLUMNA, ni más ni menos. Es exactamente lo que deja
/// `BarChartAlignment.spaceAround` en las barras de abajo, así que las
/// dos gráficas reparten sus marcas en los mismos lugares y el lunes de
/// una cae justo sobre el lunes de la otra. Con 0,35 quedaban corridas
/// seis píxeles, que es poco para notarlo de una y suficiente para que
/// la pantalla se vea desalineada.
const double _aireEjeX = 0.5;

/// Etiquetas del eje X, comunes a las dos gráficas.
Widget _etiquetaX(
  BuildContext context,
  List<PuntoPeriodo> serie,
  double valor,
) {
  // SOLO en los valores enteros, que son los que tienen dato. Con el
  // aire de los costados, fl_chart pide además una etiqueta en cada
  // extremo del rango (-0.35 y 6.35): redondeadas caían sobre el primer
  // y el último tramo, y los dibujaban dos veces.
  if ((valor - valor.roundToDouble()).abs() > 0.001) {
    return const SizedBox.shrink();
  }

  final i = valor.round();
  if (i < 0 || i >= serie.length) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(serie[i].etiqueta, style: _estiloEje(context)),
  );
}

/// Cómo se llama el eje, debajo de sus etiquetas.
///
/// POR QUÉ HAY QUE NOMBRARLO (revisión de Daniel, 21 de septiembre de
/// 2026). "L M M J V S D" se entiende solo, pero en Mes el eje decía
/// "3 · 10 · 17 · 24" y esos números no son nada hasta que alguien
/// aclara que son las semanas del mes. Y el eje de arriba mostraba
/// "140 / 70 / 0" sin decir de qué: podían ser puntos, pasos o minutos.
///
/// Va en minúsculas y apagado: es la letra chica del dibujo, no un
/// título. El título de lo que se está midiendo ya está arriba de la
/// gráfica.
Widget _nombreDeEje(BuildContext context, String texto) => Padding(
  padding: const EdgeInsets.only(top: 2),
  child: Text(
    texto,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontSize: 10,
      letterSpacing: 0.3,
      height: 1,
    ),
  ),
);

/// Línea de pasos del período, estilo Strava.
///
/// UNA sola serie y UN solo eje, así que no lleva leyenda: el subtítulo
/// de arriba ya dice qué es. Los puntos no llevan su número encima; el
/// valor aparece al tocar o arrastrar.
///
/// SIN EJE Y LATERAL. Toda la escala se dice en un rótulo arriba a la
/// derecha —"14k pasos", que es hasta dónde llega el dibujo— y el 0 es
/// la base, que se ve. Tres razones:
///
///   · Un eje a la derecha le comía 58 px de ancho a ESTA gráfica y no
///     a la de barras, así que las dos quedaban con anchos distintos:
///     una arriba de la otra, sus dos ejes de días no coincidían y el
///     lunes de una caía sobre el martes de la otra.
///   · La etiqueta del domingo se metía debajo de esa columna y quedaba
///     encimada con el "0".
///   · Es la misma forma que ya usan las barras: el valor arriba, el
///     dibujo abajo, nada a los costados.
///
/// Al llegar una tanda de datos la línea SUBE desde la base, con la misma
/// duración y la misma curva que el número grande de arriba (ver
/// [CrecerAlRefrescar]). Lo que se mueve son los valores, no la escala:
/// el eje y la grilla se quedan quietos en su lugar definitivo, así la
/// línea crece contra una referencia fija en vez de que se estire la
/// pantalla entera.
class GraficaLineaPasos extends StatelessWidget {
  const GraficaLineaPasos({
    super.key,
    required this.serie,
    required this.nombreEjeX,
    this.crecerAlMontar = false,
  });

  final List<PuntoPeriodo> serie;

  /// Qué son las marcas de abajo: "días", "semanas del mes", "meses".
  final String nombreEjeX;

  /// True cuando esta gráfica entra por un cambio de período: sube desde
  /// la base en vez de aparecer dibujada.
  final bool crecerAlMontar;

  static const double alto = 150;

  @override
  Widget build(BuildContext context) {
    final conDatos = serie.where((p) => p.hayDatos).toList();
    if (conDatos.length < 2) return const SizedBox.shrink();

    final maximo = conDatos
        .map((p) => p.pasos)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final tope = techoLindo(maximo);

    return SizedBox(
      height: alto,
      child: Column(
        children: [
          // El techo de la escala, arriba a la derecha: dice hasta dónde
          // llega el dibujo y en qué unidad, sin ocupar ancho.
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_corto(tope)} pasos',
              style: _estiloEje(context),
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: CrecerAlRefrescar(
              crecerAlMontar: crecerAlMontar,
              duracionAlMontar: duracionCambioDePeriodo,
              builder: (context, avance, animando) => LineChart(
                LineChartData(
                  minY: 0,
                  maxY: tope,
                  // El rango va un poco más allá del primer y del
                  // último punto: es lo que los despega de los bordes
                  // (ver [_aireEjeX]).
                  minX: -_aireEjeX,
                  maxX: (serie.length - 1) + _aireEjeX,
                  // Candado: la línea no puede salirse de su caja por
                  // arriba ni por abajo. Es lo que dejó a la gráfica
                  // pintando encima de la tarjeta de puntos cuando un
                  // valor quedaba fuera de escala a mitad de una
                  // animación. Arriba y abajo nada más: recortar a los
                  // costados cortaría por la mitad a los puntos de las
                  // puntas.
                  clipData: const FlClipData.vertical(),
                  // Sin grilla: no hay números al costado a los que
                  // llevar la vista, así que serían rayas por decorar.
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    // Nada a los costados: el ancho del dibujo tiene que
                    // ser el mismo que el de las barras de abajo, o los
                    // dos ejes de días no coinciden.
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      axisNameSize: 16,
                      axisNameWidget: _nombreDeEje(context, nombreEjeX),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (v, meta) =>
                            _etiquetaX(context, serie, v),
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    // Área de toque generosa: apuntarle a una marca de
                    // 8px con el dedo es imposible.
                    touchSpotThreshold: 26,
                    getTouchedSpotIndicator: (barra, indices) => [
                      for (final _ in indices)
                        TouchedSpotIndicatorData(
                          const FlLine(
                            color: AppColors.accent,
                            strokeWidth: 1,
                          ),
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
                            FlSpot(i.toDouble(), serie[i].pasos * avance),
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
                // Mientras crece manda el avance, no fl_chart: su
                // animación de cambio interpolaría entre dos cuadros que
                // YA son parte de la interpolación de arriba, y la línea
                // llegaría tarde y con rebote. Fuera del crecimiento
                // vuelve a estar prendida, para los refrescos: ahí la
                // serie tiene la misma forma con otros valores, que es lo
                // único que tiene sentido interpolar. El cambio de
                // período NO pasa por acá — lo resuelve
                // `_CambioDePeriodo` reemplazando la gráfica entera.
                duration: animando
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barras de puntos del período.
///
/// Las de contexto en azul lavado y solo la del tramo en curso en azul
/// de marca. El color NO se reasigna al cambiar de período: cada cosa
/// conserva el suyo siempre.
///
/// SIN EJE Y y SIN NADA a los costados: cada barra lleva su número
/// exacto encima, y la fila de números ocupa exactamente el mismo ancho
/// que la gráfica. El eje decía "140 / 70 / 0" al lado de unas barras
/// que ya tenían escrito su valor arriba: tres números de más para leer
/// el mismo dato con menos precisión.
///
/// POR QUÉ NO QUEDA NINGÚN HUECO A LA IZQUIERDA. Quedó uno de 34 px
/// —el que ocupaba el eje— y con él la fila de números salió corrida
/// media columna respecto de sus barras: el "50" del lunes caía sobre el
/// martes. `fl_chart` solo reserva el lado cuando de verdad dibuja algo
/// ahí, así que la única forma de que las dos filas coincidan es que
/// ninguna de las dos reserve nada. Qué son esos números lo dice el
/// título de la gráfica ("Puntos por día"), no un rótulo suelto.
///
/// Esto vale mientras las barras sean pocas —siete días, cinco o seis
/// semanas—, que es lo único que dibuja esta gráfica: el año no tiene
/// barras, tiene mapa de calor.
class GraficaBarrasPuntos extends StatelessWidget {
  const GraficaBarrasPuntos({
    super.key,
    required this.serie,
    required this.nombreEjeX,
    this.crecerAlMontar = false,
  });

  final List<PuntoPeriodo> serie;

  /// Qué son las marcas de abajo: "días", "semanas del mes", "meses".
  final String nombreEjeX;

  /// True cuando estas barras entran por un cambio de período: suben
  /// desde la base en vez de aparecer dibujadas.
  final bool crecerAlMontar;

  static const double alto = 180;

  @override
  Widget build(BuildContext context) {
    final maximo = serie
        .map((p) => p.puntos)
        .fold(0, (a, b) => a > b ? a : b)
        .toDouble();
    final tope = techoLindo(maximo);
    final actual = serie.lastIndexWhere((p) => p.hayDatos);

    return SizedBox(
      height: alto,
      child: Column(
        children: [
          // Los puntos de cada barra, arriba. Van en color de texto
          // normal, nunca del color de la serie, y solo la actual va en
          // negrita.
          //
          // A la izquierda, en la franja que ocuparía el eje, la unidad:
          // dicha una vez alcanza para nombrar toda la fila, y así no
          // hace falta escribir "pts" en cada barra.
          Row(
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
          const SizedBox(height: 4),
          Expanded(
            child: CrecerAlRefrescar(
              crecerAlMontar: crecerAlMontar,
              duracionAlMontar: duracionCambioDePeriodo,
              builder: (context, avance, animando) => BarChart(
                BarChartData(
                  minY: 0,
                  maxY: tope,
                  // Sin grilla, igual que la línea: cada barra ya tiene
                  // su número arriba, así que una raya a media altura no
                  // ayuda a leer nada.
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  alignment: BarChartAlignment.spaceAround,
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    // Sin eje Y y sin hueco reservado: cada barra ya
                    // tiene su número exacto arriba, y la fila de esos
                    // números tampoco reserva nada, así que las dos
                    // reparten el mismo ancho y cada número cae sobre su
                    // barra.
                    leftTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      axisNameSize: 16,
                      axisNameWidget: _nombreDeEje(context, nombreEjeX),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
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
                            toY: serie[i].puntos * avance,
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
                // Igual que en la línea: mientras crecen las barras manda
                // el avance, y la animación de cambio de fl_chart queda
                // para los refrescos. El cambio de período reemplaza la
                // gráfica entera (ver `_CambioDePeriodo`).
                duration: animando
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
