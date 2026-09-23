import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../datos/fuente_datos.dart';
import 'numero_animado.dart';
import '../theme.dart';

/// Los tres períodos del selector.
enum Periodo {
  semana('Semana', 'de la semana'),
  mes('Mes', 'del mes'),
  anio('Año', 'del año');

  const Periodo(this.etiqueta, this.enFrase);

  /// Cómo se llama el período en el selector.
  final String etiqueta;

  /// Cómo se nombra el período dentro de una frase: "PUNTOS DE LA
  /// SEMANA". El rótulo de la tarjeta héroe tiene que decir DE QUÉ
  /// período es el número, porque el número cambia con el selector.
  final String enFrase;
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
/// período, la comparación con el período anterior, y las dos gráficas.
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
  /// No se asume que un mes tenga cuatro semanas: las cuenta el modelo
  /// (`semanasDelMes`), que son las semanas cuyo LUNES cae en el mes, así
  /// que un mes con cinco lunes da cinco barras y uno con cuatro da
  /// cuatro. Cada barra es una semana entera; la única corta es la
  /// última, porque va en curso.
  List<PuntoPeriodo> get _serieMes {
    final semanas = Datos.i.historial.semanasDelMes;
    return [
      for (var i = 0; i < semanas.length; i++)
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
          //
          // El ordinal EXIGE que toda barra sea una semana entera: si la
          // primera fuera la cola de la semana del mes pasado, "1"
          // mentiría. De eso se encarga `semanasDelMes`.
          etiqueta: '${i + 1}',
          pasos: semanas[i].fold(0, (t, d) => t + (d.pasos ?? 0)),
          puntos: semanas[i].fold(0, (t, d) => t + d.puntosDia),
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
    // DOS GRÁFICAS: los pasos del tramo y los puntos del tramo.
    //
    // La de puntos se probó sacándola —el total ya está en grande
    // arriba— y Daniel la pidió de vuelta el 21 de septiembre de 2026:
    // el número dice CUÁNTO, y la gráfica dice de qué días salió, que es
    // lo que deja ver si fue parejo o fue un solo día bueno.
    //
    // En Año no hay ninguna de las dos: el resumen anual no trae pasos y
    // los puntos mes a mes no le aportaban nada al mapa de calor, que es
    // la vista del año.
    final hayPasos = serie.any((p) => p.pasos > 0);
    final hayBarras =
        widget.periodo != Periodo.anio && serie.any((p) => p.puntos > 0);

    return Column(
      children: [
        _TarjetaNumero(
          periodo: widget.periodo,
          onCambiarPeriodo: widget.onCambiarPeriodo,
          puntos: _puntosDelPeriodo,
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
            subtituloPuntos: switch (widget.periodo) {
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

/// EL ENCABEZADO DE PROGRESO: el selector de período, el acumulado del
/// período y cómo se viene contra el período anterior.
///
/// NO ES UNA TARJETA Y NO ES EL HÉROE DE LA PANTALLA (decisión de
/// Daniel, 21 de septiembre de 2026). Se probó como tarjeta oscura con
/// el número a 64 px y el resultado fue el contrario del buscado: la
/// pieza llamaba toda la atención y las gráficas —que son lo que esta
/// pantalla vino a mostrar— quedaban de relleno debajo.
///
/// Acá el total es CONTEXTO, no el protagonista: dice cuánto llevás en
/// el período para que las gráficas de abajo se puedan leer. Por eso no
/// tiene superficie propia, el número volvió a 44 px y todo el apoyo va
/// en gris de texto. Lo que tiene que saltar son los dibujos.
class _TarjetaNumero extends StatelessWidget {
  const _TarjetaNumero({
    required this.periodo,
    required this.onCambiarPeriodo,
    required this.puntos,
    required this.cambio,
    required this.textoComparacion,
  });

  final Periodo periodo;
  final ValueChanged<Periodo> onCambiarPeriodo;
  final int puntos;
  final int? cambio;
  final String? textoComparacion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // El selector arriba de todo y DENTRO de la tarjeta: es lo que
        // manda sobre todo lo que sigue —el número, las gráficas y la
        // lista de actividad—, así que va primero y no debajo de un
        // rótulo. Antes flotaba suelto arriba y no se leía a qué le
        // cambiaba el período.
        _SelectorPeriodo(
          seleccionado: periodo,
          onChanged: (p) {
            HapticFeedback.selectionClick();
            onCambiarPeriodo(p);
          },
        ),
        const SizedBox(height: AppSpacing.grupo),

        // EL ORDEN DE LECTURA (corrección de Daniel, 21 de septiembre
        // de 2026). Antes iba número → rótulo → techo → comparación:
        // cuatro renglones de tamaños distintos, y había que leerlos
        // todos para entender qué era el 200. Ahora son tres cosas y
        // se leen en este orden:
        //
        //   1. QUÉ ES  — el rótulo, chico, arriba del número.
        //   2. CUÁNTO  — el número, grande.
        //   3. CÓMO VA — una sola línea de apoyo debajo.
        //
        // El rótulo volvió ARRIBA porque el número cambia con el
        // selector: sin saber antes de qué período es, "200" no
        // significa nada.
        Text(
          'PUNTOS ${periodo.enFrase.toUpperCase()}',
          style: AppTheme.subsectionTitle,
        ),
        const SizedBox(height: AppSpacing.dentro),

        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          // Los puntos suben desde 0 al entrar.
          child: NumeroAnimado(
            valor: puntos,
            formato: _milesGrafica,
            estilo: AppTheme.display(44).copyWith(color: AppColors.accent),
          ),
        ),
        const SizedBox(height: AppSpacing.entre),

        // NI BARRA NI TECHO (pedido de Daniel, 21 de septiembre de
        // 2026). El encabezado dice UN número: cuántos puntos llevás.
        //
        // Lo que se sacó es la barra de "200 de 1.400 posibles" con su
        // renglón. El techo era el máximo teórico del período (el tope
        // diario por los días), y contra ese número cualquier semana
        // real se dibuja casi vacía: la barra decía "vas muy mal" todas
        // las semanas, que es lo contrario de lo que esta pantalla
        // tiene que hacer. El número solo no miente.
        //
        // OJO: con esto el encabezado ya no muestra la META del
        // período, que CLAUDE.md sí pide en Progreso. Queda la
        // comparación contra el período anterior, que es la otra mitad
        // de esa línea.

        // La comparación es la única referencia que queda, y es la que
        // sirve: contra vos mismo la semana pasada, no contra un máximo
        // que nadie alcanza.
        if (cambio != null && textoComparacion != null) ...[
          const SizedBox(height: 4),
          _LineaCambio(cambio: cambio!, texto: textoComparacion!),
        ],
      ],
    );
  }
}

/// Cómo venís contra el período anterior.
///
/// Era una frase de dos renglones en NARANJA ("Vas 53% abajo de la
/// semana pasada, que cerró en 425 pts"): lo más ruidoso del encabezado
/// siendo lo menos importante, y encima el naranja tiene cuatro usos
/// definidos y este no es ninguno (ver CLAUDE.md).
///
/// Acá va del mismo gris que el resto del apoyo, con una flecha
/// adelante. Que suba o baje se lee por la FLECHA, no por el color: los
/// dos casos van igual. Pintar de rojo una semana floja es regañar al
/// usuario, que es lo último que tiene que hacer una app que se supone
/// que motiva.
class _LineaCambio extends StatelessWidget {
  const _LineaCambio({required this.cambio, required this.texto});

  final int cambio;

  /// La frase entera, que la sigue armando la tarjeta.
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            cambio >= 0
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            texto,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// LAS GRÁFICAS SON EL HÉROE DE PROGRESO (decisión de Daniel, 21 de
/// septiembre de 2026), y esta es la ÚNICA pieza de la pantalla con
/// superficie propia.
///
/// La jerarquía está invertida a propósito. Antes todo vivía en
/// tarjetas blancas idénticas —el número, las gráficas, la actividad—
/// y nada destacaba. Se probó al revés, con una tarjeta oscura para el
/// número, y salió peor: lo que llamaba la atención era el total y los
/// dibujos quedaban de relleno debajo.
///
/// Así que ahora TODO va plano sobre el fondo de la pantalla y solo
/// las gráficas tienen tarjeta. Cuando una sola cosa está levantada,
/// esa cosa es la que se mira: no hace falta que grite, alcanza con
/// que sea la única.
class _TarjetaGraficas extends StatelessWidget {
  const _TarjetaGraficas({
    required this.periodo,
    required this.crecerAlMontar,
    required this.serie,
    required this.hayPasos,
    required this.hayBarras,
    required this.subtituloPasos,
    required this.subtituloPuntos,
    required this.nombreEjeX,
  });

  /// Qué son las marcas del eje de abajo.
  final String nombreEjeX;

  /// True cuando el usuario ya tocó el selector al menos una vez: de ahí
  /// en adelante la gráfica entra subiendo desde la base.
  final bool crecerAlMontar;

  /// Qué período se está mirando. No se dibuja: sirve de LLAVE, para que
  /// al cambiar de pestaña la gráfica se reemplace en vez de deformarse
  /// hasta la del otro período (ver [_CambioDePeriodo]).
  final Periodo periodo;

  final List<PuntoPeriodo> serie;
  final bool hayPasos;
  final bool hayBarras;
  final String subtituloPasos;
  final String subtituloPuntos;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        // Sombra, no borde: un contorno dibujado hace ver la tarjeta
        // trazada con lápiz. La sombra la levanta del fondo, que es
        // justo lo que tiene que pasar acá.
        boxShadow: AppSombras.tarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hayPasos) ...[
            _Subtitulo(texto: subtituloPasos),
            const SizedBox(height: AppSpacing.dentro),
            // Una sola serie por gráfica: sin leyenda, el subtítulo ya
            // dice qué es.
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
            _Subtitulo(texto: subtituloPuntos),
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

/// El título de una gráfica.
///
/// En AZUL DE MARCA desde que las gráficas dejaron de vivir en una
/// tarjeta: sin la caja que las agrupaba, lo único que dice dónde empieza
/// cada bloque es su título, así que tiene que pesar como un encabezado y
/// no como una línea de texto más.
class _Subtitulo extends StatelessWidget {
  const _Subtitulo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.accent,
      fontWeight: FontWeight.w800,
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
        backgroundColor: AppColors.azulBruma,
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
                      ? AppColors.accent
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
  final magnitud = math
      .pow(10, (math.log(crudo) / math.ln10).floor())
      .toDouble();
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
/// SIN EJE Y LATERAL. Arriba a la derecha va un rótulo con los PASOS
/// ACUMULADOS del tramo —la suma exacta de los puntos que se dibujan— y
/// el 0 es la base, que se ve. Tres razones para no poner el eje:
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

  /// Subió de 150 a 210: la altura es lo que le da presencia a una
  /// gráfica. A 150, la curva de una semana buena y la de una floja
  /// se veían casi iguales, porque no había recorrido vertical donde
  /// notar la diferencia.
  static const double alto = 210;

  /// La suma de los pasos que la gráfica dibuja.
  ///
  /// Sale de LA MISMA lista que los puntos del dibujo —solo los tramos
  /// con dato—, así que el rótulo no puede desincronizarse de la curva:
  /// si un día entra o sale de la serie, entra o sale de esta suma.
  ///
  /// Y por eso cuadra con el resto de la pantalla: la serie de la semana
  /// son los días de `semanaEnCurso` y la del mes son esos mismos días
  /// agrupados, que es de donde "Tu actividad" saca su total de pasos.
  static int pasosAcumulados(List<PuntoPeriodo> serie) =>
      serie.where((p) => p.hayDatos).fold(0, (t, p) => t + p.pasos);

  @override
  Widget build(BuildContext context) {
    final conDatos = serie.where((p) => p.hayDatos).toList();
    if (conDatos.length < 2) return const SizedBox.shrink();

    final maximo = conDatos
        .map((p) => p.pasos)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final tope = techoLindo(maximo);
    final acumulado = pasosAcumulados(serie);

    return SizedBox(
      height: alto,
      child: Column(
        children: [
          // LOS PASOS ACUMULADOS DEL TRAMO, arriba a la derecha
          // (pedido de Daniel, 21 de septiembre de 2026).
          //
          // Antes decía el techo de la escala ("14k pasos"), que es un
          // número que no existe en ningún lado: sale de redondear el
          // mejor día hacia arriba y no es ni una meta ni un total. El
          // acumulado sí es un dato del usuario, y es el que se puede
          // verificar sumando lo que la gráfica dibuja.
          //
          // Completo y con comas, no abreviado: "29,932" es la suma
          // exacta y "30k" sería otro número redondeado.
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_milesGrafica(acumulado)} pasos acumulados',
              // NO va con el estilo del eje (pedido de Daniel, 21 de
              // septiembre de 2026). Las etiquetas del eje son el
              // andamio de la gráfica y se miran de reojo; esto es un
              // dato del usuario, el total de lo que la curva dibuja.
              // En gris de eje y a 10 px quedaba de pie de página.
              style: _estiloEje(context).copyWith(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
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
                  // UNA CUADRÍCULA MUY TENUE, solo horizontal.
                  //
                  // Dos líneas: la mitad de la escala y el techo. No
                  // llevan número —el techo ya está escrito arriba a la
                  // derecha— y no están para leer valores exactos, sino
                  // para que el ojo tenga contra qué medir la altura de
                  // la línea. Sin ellas el dibujo flota.
                  //
                  // `cardBorder` a media opacidad: es el mismo gris
                  // azulado del borde de las tarjetas, así que la
                  // cuadrícula pertenece a la paleta en vez de meter un
                  // color nuevo. Verticales no: serían siete rayas para
                  // separar lo que las etiquetas de abajo ya separan.
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: tope / 2,
                    checkToShowHorizontalLine: (v) => v > 0,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.cardBorder.withValues(alpha: 0.7),
                      strokeWidth: 1,
                    ),
                  ),
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
                          // SOLO LOS PASOS (pedido de Daniel, 21 de
                          // septiembre de 2026). Esta gráfica se llama
                          // "Pasos de la semana", y los puntos de cada
                          // tramo ya los dibuja entera la gráfica de
                          // barras de abajo: decirlos también acá es
                          // contar lo mismo dos veces, y obliga a un
                          // tooltip de dos renglones para el dato que
                          // sí se vino a buscar.
                          LineTooltipItem(
                            '${_milesGrafica(s.y.round())} pasos',
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
                      // 3px: a 2 la línea se leía como un trazo de
                      // referencia y no como el dato principal de la
                      // pantalla.
                      barWidth: 3,
                      // DEGRADADO A LO LARGO DEL TRAZO, del azul medio
                      // al azul de marca. Es el mismo azul en dos
                      // luminosidades, así que no mete un color nuevo,
                      // pero le saca a la línea el aire de trazo plano.
                      gradient: const LinearGradient(
                        colors: [AppColors.azulMedio, AppColors.accent],
                      ),
                      // Puntas redondeadas: una línea cortada en
                      // escuadra se ve como un pedazo de algo más
                      // grande.
                      isStrokeCapRound: true,
                      // UNA MARCA POR DÍA (pedido de Daniel, 21 de
                      // septiembre de 2026). Esto REVIERTE la regla de
                      // "una sola marca, la del tramo en curso" que
                      // dice CLAUDE.md: la curva ya no se mira sola, se
                      // toca, y sin un punto visible no se sabe dónde
                      // hay que tocar ni cuántos días entraron.
                      //
                      // `spots` ya trae solo los días CON dato, así que
                      // los días que todavía no llegaron no reciben
                      // marca: la cantidad de puntos dice por sí sola
                      // hasta dónde va la semana.
                      //
                      // Lo que sostiene la forma de la curva es el
                      // TAMAÑO, no la ausencia: hoy va grande y los
                      // días cerrados van chicos, así que las marcas se
                      // leen como un acompañamiento de la línea y no
                      // como siete botones en fila. Todas con anillo
                      // blanco, para que se despeguen aunque caigan
                      // sobre el área pintada.
                      dotData: FlDotData(
                        getDotPainter: (s, p, b, i) {
                          final hoy = i == b.spots.length - 1;
                          return FlDotCirclePainter(
                            radius: hoy ? 5 : 3,
                            color: AppColors.accent,
                            strokeWidth: hoy ? 3 : 2,
                            strokeColor: AppColors.card,
                          );
                        },
                      ),
                      // El área de abajo, más presente: era casi
                      // invisible (0,18) y es la mitad de lo que hace
                      // que una gráfica de línea se vea terminada.
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.accent.withValues(alpha: 0.28),
                            AppColors.accent.withValues(alpha: 0.02),
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
/// POR QUÉ VOLVIÓ. Se sacó un rato —el total de puntos ya está en grande
/// arriba— y Daniel la pidió de vuelta el 21 de septiembre de 2026: el
/// número dice CUÁNTO, y esta gráfica dice DE QUÉ DÍAS salió, que es lo
/// que deja ver si la semana fue pareja o fue un solo día bueno. Son dos
/// lecturas distintas del mismo dato, no la misma dos veces.
///
/// SIN EJE Y y SIN NADA a los costados: cada barra lleva su número
/// exacto encima, que es más preciso que leerlo contra un eje. Y sin
/// hueco a la izquierda, porque `fl_chart` solo reserva un lado cuando
/// dibuja algo ahí: con un hueco de un lado y no del otro, la fila de
/// números salía corrida media columna respecto de sus barras.
class GraficaBarrasPuntos extends StatelessWidget {
  const GraficaBarrasPuntos({
    super.key,
    required this.serie,
    required this.nombreEjeX,
    this.crecerAlMontar = false,
  });

  final List<PuntoPeriodo> serie;

  /// Qué son las marcas de abajo: "días de la semana", "semanas de
  /// agosto".
  final String nombreEjeX;

  /// True cuando estas barras entran por un cambio de período: suben
  /// desde la base en vez de aparecer dibujadas.
  final bool crecerAlMontar;

  /// Subió de 172 a 215, por lo mismo que la de pasos: con más alto,
  /// la diferencia entre 25 y 100 pts se ve de una.
  static const double alto = 215;

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
          // Los puntos de cada barra, arriba. En color de texto normal,
          // nunca del color de la serie, y solo el del tramo en curso en
          // negrita.
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
                  // La misma cuadrícula tenue que la gráfica de pasos:
                  // las dos están una debajo de la otra y tienen que
                  // verse de la misma familia.
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: tope / 2,
                    checkToShowHorizontalLine: (v) => v > 0,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.cardBorder.withValues(alpha: 0.7),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  alignment: BarChartAlignment.spaceAround,
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    // Nada a los costados: el ancho del dibujo tiene que
                    // ser el mismo que el de la gráfica de pasos, o los
                    // dos ejes de días no coinciden y el lunes de una
                    // cae sobre el martes de la otra.
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
                            width: 24,
                            // Puntas superiores bien redondeadas (eran 4,
                            // que a esta altura de barra no se notaba),
                            // pegadas a la base.
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                            // DEGRADADO VERTICAL, más claro abajo: es lo
                            // que hace que una barra se vea como un
                            // volumen y no como un rectángulo de color.
                            // Las dos rampas son del mismo azul — la del
                            // tramo en curso entera, las de contexto
                            // lavadas.
                            gradient: i == actual
                                ? const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      AppColors.nivel3,
                                      AppColors.accent,
                                    ],
                                  )
                                : const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      AppColors.azulBruma,
                                      AppColors.azulSuave,
                                    ],
                                  ),
                          ),
                        ],
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
