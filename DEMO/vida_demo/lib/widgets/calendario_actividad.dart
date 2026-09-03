import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../datos/modelos.dart';
import '../reglas_puntos.dart';
import '../theme.dart';

/// Mini calendario de actividad, estilo mapa de calor.
///
/// UN SOLO TONO de claro a oscuro. Nada de un color por etapa: el ojo
/// tiene que leer "más oscuro = más" sin pensarlo, y con varios matices
/// eso deja de funcionar — sobre todo para alguien daltónico.
///
/// Tres estados bien distintos:
///  - SIN DATOS: casilla vacía con borde punteadito de color. No sabemos
///    qué pasó ese día.
///  - CERO PASOS: casilla rellena en el tono más claro. Sí sabemos qué
///    pasó: no se movió. No es lo mismo y no puede verse igual.
///  - CON PASOS: cuanto más oscuro, más pasos.
class CalendarioActividad extends StatefulWidget {
  const CalendarioActividad({super.key, required this.dias});

  final List<DiaActividad> dias;

  @override
  State<CalendarioActividad> createState() => _CalendarioActividadState();
}

class _CalendarioActividadState extends State<CalendarioActividad> {
  DiaActividad? _seleccionado;

  final _scroll = ScrollController();

  /// Ancho de una columna: la casilla más su separación.
  static const double _anchoColumna = 18;

  @override
  void initState() {
    super.initState();
    // Con los doce meses el calendario no entra en pantalla. Se abre
    // mostrando el mes en curso en vez de enero, que es lo que el usuario
    // quiere ver primero.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final destino = (_columnaDelMesActual - 1) * _anchoColumna;
      _scroll.jumpTo(destino.clamp(0.0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Los días indexados por fecha, para poder recorrer el calendario
  /// completo y saber cuáles NO tienen dato.
  Map<DateTime, DiaActividad> get _porFecha => {
    for (final d in widget.dias)
      DateTime(d.fecha.year, d.fecha.month, d.fecha.day): d,
  };

  /// El AÑO COMPLETO, del 1 de enero al 31 de diciembre.
  ///
  /// Se muestran los doce meses aunque el usuario haya empezado a
  /// registrar en julio: los meses sin datos quedan con las casillas
  /// vacías, que ya se distinguen de un día con cero pasos. Antes esto
  /// arrancaba en el primer día del historial, y la vista de Año empezaba
  /// en un mes cualquiera.
  ///
  /// Arranca en el lunes de la semana que contiene al 1 de enero, para
  /// que las columnas queden alineadas por día de la semana.
  List<DateTime> get _fechas {
    if (widget.dias.isEmpty) return const [];
    final anio = widget.dias.last.fecha.year;
    final enero = DateTime(anio, 1, 1);
    final inicio = enero.subtract(Duration(days: enero.weekday - 1));
    final fin = DateTime(anio, 12, 31);
    return [
      for (var d = inicio; !d.isAfter(fin); d = d.add(const Duration(days: 1)))
        d,
    ];
  }

  /// Índice de columna del mes en curso, para abrir el calendario ahí.
  int get _columnaDelMesActual {
    final hoy = widget.dias.last.fecha;
    final fechas = _fechas;
    for (var i = 0; i < fechas.length; i += 7) {
      if (fechas[i].month == hoy.month && fechas[i].year == hoy.year) {
        return i ~/ 7;
      }
    }
    return 0;
  }

  /// Escala del mapa de calor. Se corta contra el escalón de pasos que ya
  /// paga el máximo: por encima de eso no hay más puntos, así que tampoco
  /// tiene sentido seguir oscureciendo.
  static const int _tope = 15000;

  /// Alto de la fila de rótulos de mes.
  static const double _altoMeses = 16;

  static const _mesesCortos = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', //
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  /// El nombre del mes solo en la primera columna que lo estrena.
  static String _rotuloMes(List<DateTime> fechas, int i) {
    final mes = fechas[i].month;
    if (i == 0) return _mesesCortos[mes - 1];
    return fechas[i - 7].month == mes ? '' : _mesesCortos[mes - 1];
  }

  Color _color(DiaActividad? dia) {
    if (dia == null || dia.pasos == null) {
      // Sin datos: no se rellena.
      return Colors.transparent;
    }
    final pasos = dia.pasos!;
    if (pasos == 0) {
      // Cero pasos SÍ es un dato: se rellena, en el tono más claro.
      return AppColors.accent.withValues(alpha: 0.08);
    }
    final t = (pasos / _tope).clamp(0.0, 1.0);
    // De 0.18 a 1: el piso evita que un día flojo se confunda con el
    // relleno del día en cero.
    return AppColors.accent.withValues(alpha: 0.18 + t * 0.82);
  }

  void _tocar(DiaActividad? dia) {
    if (dia == null) return;
    HapticFeedback.selectionClick();
    setState(() => _seleccionado = _seleccionado == dia ? null : dia);
  }

  @override
  Widget build(BuildContext context) {
    final fechas = _fechas;
    if (fechas.isEmpty) return const SizedBox.shrink();
    final porFecha = _porFecha;

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
          Text(
            'TUS DÍAS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: AppSpacing.entre),

          // Una columna por semana, siete filas de lunes a domingo, con
          // los meses rotulados arriba. Igual que el de GitHub.
          SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hueco de la fila de meses, para que las letras de
                    // los días queden alineadas con sus filas.
                    const SizedBox(height: _altoMeses),
                    _ColumnaEtiquetas(),
                  ],
                ),
                const SizedBox(width: 6),
                for (var i = 0; i < fechas.length; i += 7)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // El rótulo del mes va en la primera columna de
                        // cada mes, no en todas.
                        //
                        // "Ene" es más ancho que una casilla, así que va
                        // en un OverflowBox: si contara para el ancho, las
                        // columnas de inicio de mes quedarían más anchas
                        // que el resto y la grilla se desalinearía.
                        SizedBox(
                          width: 14,
                          height: _altoMeses,
                          child: OverflowBox(
                            maxWidth: 60,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _rotuloMes(fechas, i),
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                        ),
                        for (var j = i; j < i + 7 && j < fechas.length; j++)
                          _Casilla(
                            fecha: fechas[j],
                            dia: porFecha[fechas[j]],
                            color: _color(porFecha[fechas[j]]),
                            seleccionada:
                                _seleccionado != null &&
                                porFecha[fechas[j]] == _seleccionado,
                            onTap: () => _tocar(porFecha[fechas[j]]),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.entre),
          _Detalle(dia: _seleccionado),
          const SizedBox(height: AppSpacing.entre),
          const _Leyenda(),
        ],
      ),
    );
  }
}

class _ColumnaEtiquetas extends StatelessWidget {
  // Solo lunes, miércoles y viernes: con las siete la columna se satura.
  static const _letras = ['L', '', 'M', '', 'V', '', ''];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final l in _letras)
          SizedBox(
            height: 18,
            child: Text(
              l,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 9,
              ),
            ),
          ),
      ],
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({
    required this.fecha,
    required this.dia,
    required this.color,
    required this.seleccionada,
    required this.onTap,
  });

  final DateTime fecha;
  final DiaActividad? dia;
  final Color color;
  final bool seleccionada;
  final VoidCallback onTap;

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  static String _miles(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );

  /// El resumen que sale al pasar por encima.
  String get _resumen {
    final d = dia;
    final cuando = '${fecha.day} de ${_meses[fecha.month - 1]}';
    if (d == null || d.pasos == null) return '$cuando · sin datos';
    return '$cuando\n${_miles(d.pasos!)} pasos · ${d.puntosDia} pts';
  }

  @override
  Widget build(BuildContext context) {
    final sinDatos = dia == null || dia!.pasos == null;

    return Tooltip(
      message: _resumen,
      // Con mouse sale solo al pasar por encima; con dedo, al tocar y
      // mantener. La selección de abajo sigue funcionando con un toque
      // normal, así que las dos formas conviven.
      triggerMode: TooltipTriggerMode.longPress,
      waitDuration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 11),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          // 18px de alto con 4 de separación: el área de toque es
          // bastante más grande que la marca de color.
          width: 14,
          height: 18,
          alignment: Alignment.center,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: seleccionada
                  ? Border.all(color: AppColors.textPrimary, width: 1.5)
                  : sinDatos
                  // Sin datos: contorno tenue y sin relleno. Se distingue
                  // a simple vista del día en cero, que sí va relleno.
                  ? Border.all(color: AppColors.cardBorder, width: 1)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.dia});

  final DiaActividad? dia;

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  Widget build(BuildContext context) {
    final d = dia;
    if (d == null) {
      return Text(
        'Tocá un día para ver sus pasos y sus puntos.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      );
    }

    final fecha = '${d.fecha.day} de ${_meses[d.fecha.month - 1]}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fecha,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            d.pasos == null
                ? 'Sin datos de ese día'
                : '${_miles(d.pasos!)} pasos · ${d.puntosDia} pts',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  static String _miles(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
}

/// Leyenda mínima. El degradado se entiende solo, pero el estado "sin
/// datos" no: eso sí hay que decirlo.
class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary);

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: AppColors.cardBorder),
          ),
        ),
        const SizedBox(width: 5),
        Text('sin datos', style: estilo),
        const Spacer(),
        Text('menos', style: estilo),
        const SizedBox(width: 5),
        for (final a in [0.08, 0.32, 0.56, 0.8, 1.0])
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: a),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        const SizedBox(width: 2),
        Text('más', style: estilo),
      ],
    );
  }
}

/// El escalón de pasos que ya paga el máximo. Se deja acá arriba para que
/// el tope del mapa de calor no sea un número suelto.
const int _maximoEscalonPasos = 15000;

/// Comprobación en tiempo de compilación: el tope del mapa tiene que
/// seguir al escalón que paga el máximo de la tabla oficial.
// ignore: unused_element
void _verificarTope() {
  assert(_maximoEscalonPasos == tablaPasos.first.pasosMinimos);
}
