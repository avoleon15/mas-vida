import 'dart:math';
import 'package:flutter/material.dart';
import '../reglas_puntos.dart';
import '../theme.dart';

// ------------------------------------------------------------
// Cortes de los aros
// ------------------------------------------------------------

/// Cortes de los tres aros de pasos. Se derivan de la tabla oficial
/// (`tablaPasos` en reglas_puntos.dart) en vez de repetir los umbrales
/// acá, así que si mañana cambia la tabla, los aros la siguen solos.
///
/// Da `[0, 7000, 10000, 15000]`: el aro 1 va de 0 a 7.000, el aro 2 de
/// 7.000 a 10.000 y el aro 3 de 10.000 a 15.000.
final List<int> cortesAros = [
  0,
  ...tablaPasos.reversed.map((escalon) => escalon.pasosMinimos),
];

/// Pasos a partir de los cuales ya no queda aro por llenar. Arriba de
/// este número no hay más puntos por pasos, así que tampoco hay un cuarto
/// aro ni una segunda vuelta.
final int techoAros = cortesAros.last;

/// Color de cada aro, en el mismo orden que los tramos de [cortesAros].
const List<Color> _coloresAros = [
  AppColors.aroBronce,
  AppColors.aroPlata,
  AppColors.aroOro,
];

/// Reflejo metálico de cada aro, en el mismo orden que [_coloresAros].
/// Los tres son metálicos: el color plano de [_coloresAros] queda solo
/// para el halo y para el filete del texto del centro.
const List<List<Color>> _brilloAros = [
  AppColors.brilloBronce,
  AppColors.brilloPlata,
  AppColors.brilloOro,
];

/// Techo del aro EN CURSO — el segundo número del texto del centro
/// ("Llevás 8.000 pasos de 10.000").
///
/// Cambia solo al cambiar de aro, no con cada paso, y arriba del techo se
/// queda clavado en el último corte. No es la meta del día: que este
/// número y el llenado del aro no coincidan es una decisión de producto,
/// no un desfase que haya que arreglar.
int techoDelAroActual(int pasos) {
  for (final corte in cortesAros.skip(1)) {
    if (pasos < corte) return corte;
  }
  return techoAros;
}

/// Color del aro EN CURSO. Lo usa el texto del centro para amarrarse al
/// aro que se está llenando ahora mismo. Arriba del techo se queda en
/// dorado.
Color colorDelAroActual(int pasos) {
  for (var i = 1; i < cortesAros.length; i++) {
    if (pasos < cortesAros[i]) return _coloresAros[i - 1];
  }
  return _coloresAros.last;
}

// ------------------------------------------------------------
// Widget
// ------------------------------------------------------------

/// Anillo de pasos de Home. Un solo aro, del mismo diámetro y grosor de
/// siempre, que se pinta en tres tramos apilados: gris (0 a 7.000), plata
/// (7.000 a 10.000) y dorado (10.000 a 15.000).
///
/// Cada tramo arranca vacío al cruzar su umbral y se llena al llegar al
/// siguiente. Un tramo terminado no desaparece: queda como aro completo y
/// el siguiente se pinta ENCIMA, no al lado. Con 12.000 pasos se ve el
/// plata lleno y el dorado a dos quintos encima de él.
///
/// El aro se reinicia cada día; acá no se acumula nada entre días.
class ProgressRing extends StatefulWidget {
  const ProgressRing({
    super.key,
    required this.pasos,
    required this.size,
    this.strokeWidth = 18,
    this.sigmaHalo = 12,
    this.opacidadHalo = 0.22,
    this.animarCelebracion = true,
  });

  /// Pasos del día ya resueltos (deduplicados). Este widget solo pinta:
  /// no calcula puntos ni valida nada.
  final int pasos;

  final double size;
  final double strokeWidth;

  /// Qué tan difuso es el halo del tramo en curso. Más sigma = más
  /// desborde a los lados del trazo.
  final double sigmaHalo;

  /// Qué tan visible es ese halo (0.0 a 1.0).
  final double opacidadHalo;

  /// Si el aro galáctico de los 15.000 gira. En false queda quieto en su
  /// primer cuadro (útil para tests y screenshots).
  final bool animarCelebracion;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;

  /// El aro llegó al techo del día: se muestra galáctico.
  bool get _completo => widget.pasos >= techoAros;

  /// Además de mostrarse galáctico, la nebulosa gira.
  bool get _celebra => _completo && widget.animarCelebracion;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      // Lento: la nebulosa gira despacio, no marea.
      duration: const Duration(seconds: 14),
    );
    _sincronizarAnimacion();
  }

  @override
  void didUpdateWidget(ProgressRing anterior) {
    super.didUpdateWidget(anterior);
    _sincronizarAnimacion();
  }

  /// El aro galáctico gira mientras el día siga arriba de 15.000. Es el
  /// único caso en que queda una animación corriendo en Home, y es un
  /// estado poco frecuente: llegar al techo del día.
  void _sincronizarAnimacion() {
    if (_celebra) {
      if (!_controlador.isAnimating) _controlador.repeat();
    } else {
      _controlador.stop();
      _controlador.value = 0;
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lienzo = Size.square(widget.size);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          // Capa base. Va en su propio RepaintBoundary para que el
          // destello no la obligue a repintarse en cada frame.
          RepaintBoundary(
            child: CustomPaint(
              size: lienzo,
              painter: _AnilloPasosPainter(
                pasos: widget.pasos,
                strokeWidth: widget.strokeWidth,
                sigmaHalo: widget.sigmaHalo,
                opacidadHalo: widget.opacidadHalo,
              ),
            ),
          ),
          // Al llegar al techo, la nebulosa se dibuja ENCIMA del aro de
          // oro ya completo y lo tapa por entero.
          if (_completo)
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controlador,
                builder: (context, _) {
                  return CustomPaint(
                    size: lienzo,
                    painter: _AnilloGalacticoPainter(
                      fase: _controlador.value,
                      strokeWidth: widget.strokeWidth,
                      sigmaHalo: widget.sigmaHalo,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Texto del centro del anillo. Es la frase de siempre ("Llevás X pasos
/// de Y"), solo que compuesta en tres alturas en vez de en un renglón
/// corrido: el número queda de protagonista y la frase se sigue leyendo
/// de arriba hacia abajo.
///
/// Vive acá y no en Home para que se pueda probar junto con el aro.
class TextoCentroAnillo extends StatelessWidget {
  const TextoCentroAnillo({super.key, required this.pasos});

  final int pasos;

  /// Miles con separador de coma: 12000 -> "12,000".
  static String formatearMiles(int valor) {
    final digitos = valor.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      buffer.write(digitos[i]);
      final faltan = digitos.length - i - 1;
      if (faltan > 0 && faltan % 3 == 0) buffer.write(',');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final estiloEtiqueta = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('LLEVÁS', style: estiloEtiqueta?.copyWith(letterSpacing: 2.5)),
        const SizedBox(height: 2),
        Text(
          formatearMiles(pasos),
          // Bebas Neue, la misma display font de los encabezados de
          // sección. Al ser condensada, un número de cinco dígitos entra
          // cómodo adentro del aro.
          style: AppTheme.sectionTitle.copyWith(
            fontSize: 62,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        // "PASOS" va ARRIBA del filete, cerrando el número.
        Text('PASOS', style: estiloEtiqueta?.copyWith(letterSpacing: 1.5)),
        const SizedBox(height: 8),
        // Filete del color del aro en curso: es lo que amarra el número
        // con el aro que se está llenando.
        Container(
          width: 30,
          height: 2,
          decoration: BoxDecoration(
            color: colorDelAroActual(pasos),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          // El número es el techo del ARO EN CURSO, no la meta del día:
          // cambia solo al cambiar de aro. Que no calce con el llenado
          // del aro es a propósito — el número de arriba dice cuántos
          // pasos lleva hoy, el color dice en qué aro va.
          'de ${formatearMiles(techoDelAroActual(pasos))}',
          style: estiloEtiqueta?.copyWith(letterSpacing: 1.5),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Pintura
// ------------------------------------------------------------

class _AnilloPasosPainter extends CustomPainter {
  _AnilloPasosPainter({
    required this.pasos,
    required this.strokeWidth,
    required this.sigmaHalo,
    required this.opacidadHalo,
  });

  final int pasos;
  final double strokeWidth;
  final double sigmaHalo;
  final double opacidadHalo;

  // El anillo arranca arriba (12 en punto).
  static const _startAngle = -pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // 1. Track: blanco apenas apagado. Es todo lo que se ve con 0 pasos.
    final trackPaint = Paint()
      ..color = AppColors.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Los tres tramos, cada uno encima del anterior.
    for (var i = 0; i < _coloresAros.length; i++) {
      final desde = cortesAros[i];
      final hasta = cortesAros[i + 1];
      final fraccion = ((pasos - desde) / (hasta - desde)).clamp(0.0, 1.0);
      // Si este tramo ni arrancó, los de más arriba tampoco: cortamos.
      if (fraccion <= 0) break;
      _pintarAro(
        canvas,
        center,
        radius,
        arcRect,
        _coloresAros[i],
        _brilloAros[i],
        fraccion,
      );
    }
  }

  void _pintarAro(
    Canvas canvas,
    Offset center,
    double radius,
    Rect arcRect,
    Color color,
    List<Color> brillo,
    double fraccion,
  ) {
    // El trazo se pinta con el degradado metálico que le da la vuelta al
    // aro. El color plano se sigue usando para el halo, que tiene que ser
    // un tono solo.
    final aroPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: brillo,
        transform: const GradientRotation(_startAngle),
      ).createShader(arcRect);

    if (fraccion >= 1.0) {
      // Círculo cerrado, no un arco de 360°: así los dos StrokeCap.round
      // no se encinan en las 12 y no queda un bulto raro. Es también lo
      // que hace que justo en 7.000 y en 10.000 el aro que se completa
      // quede limpio y el siguiente arranque en cero sin parpadeo.
      canvas.drawCircle(center, radius, aroPaint);
      return;
    }

    // Halo suave debajo del tramo en curso: desborda a los lados del
    // trazo y ayuda a leer hasta dónde llegó.
    final haloPaint = Paint()
      ..color = color.withValues(alpha: opacidadHalo)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigmaHalo);

    final barrido = 2 * pi * fraccion;
    canvas.drawArc(arcRect, _startAngle, barrido, false, haloPaint);
    canvas.drawArc(arcRect, _startAngle, barrido, false, aroPaint);

    // Marcas de INICIO y FIN del tramo recorrido. Ambas se derivan del
    // color del metal: no entra ningún color nuevo.
    // La de inicio es discreta (dónde abre el aro); la de fin es la
    // principal, con su propio halo, porque es el "vas aquí".
    final oscuro = Color.lerp(color, Colors.black, 0.35)!;

    canvas.drawCircle(
      _puntoEnAro(center, radius, _startAngle),
      strokeWidth * 0.16,
      Paint()..color = oscuro.withValues(alpha: 0.7),
    );

    final puntoFin = _puntoEnAro(center, radius, _startAngle + barrido);
    canvas.drawCircle(
      puntoFin,
      strokeWidth * 0.5,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigmaHalo),
    );
    canvas.drawCircle(
      puntoFin,
      strokeWidth * 0.26,
      Paint()..color = Color.lerp(color, Colors.white, 0.45)!,
    );
  }

  Offset _puntoEnAro(Offset center, double radius, double angulo) {
    return Offset(
      center.dx + radius * cos(angulo),
      center.dy + radius * sin(angulo),
    );
  }

  @override
  bool shouldRepaint(covariant _AnilloPasosPainter oldDelegate) {
    return oldDelegate.pasos != pasos ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.sigmaHalo != sigmaHalo ||
        oldDelegate.opacidadHalo != opacidadHalo;
  }
}

/// Aro galáctico: el premio de llegar a los 15.000. Una nebulosa
/// multicolor que da vueltas despacio sobre el aro de oro ya completo.
///
/// Se dibuja opaca y encima del oro, así que lo tapa por completo. Es el
/// único estado del anillo que usa color libremente, porque no comunica
/// ningún dato: lo que informa es que el aro está lleno.
class _AnilloGalacticoPainter extends CustomPainter {
  _AnilloGalacticoPainter({
    required this.fase,
    required this.strokeWidth,
    required this.sigmaHalo,
  });

  /// Va de 0.0 a 1.0 y se repite: es la vuelta de la nebulosa.
  final double fase;
  final double strokeWidth;
  final double sigmaHalo;

  static const _startAngle = -pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final giro = _startAngle + 2 * pi * fase;

    final nebulosa = SweepGradient(
      colors: AppColors.aroGalactico,
      transform: GradientRotation(giro),
    ).createShader(arcRect);

    // Halo del mismo degradado, por fuera del trazo: es lo que le da el
    // aire de nebulosa en vez de un simple aro de colores.
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.1
      ..shader = nebulosa
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigmaHalo);
    canvas.drawCircle(center, radius, haloPaint);

    // El aro nítido. Círculo cerrado, así que no hay cap que se encime.
    final aroPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = nebulosa;
    canvas.drawCircle(center, radius, aroPaint);
  }

  @override
  bool shouldRepaint(covariant _AnilloGalacticoPainter oldDelegate) {
    return oldDelegate.fase != fase ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.sigmaHalo != sigmaHalo;
  }
}
