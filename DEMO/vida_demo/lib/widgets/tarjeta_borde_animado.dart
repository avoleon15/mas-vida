import 'package:flutter/material.dart';
import '../theme.dart';

/// Tarjeta con un borde azul que se ilumina y va girando.
///
/// El truco es el mismo de la versión en CSS: no hay un borde animado de
/// verdad, sino una franja de color girando por detrás y un relleno
/// interno que la tapa todo menos [grosorBorde] píxeles del contorno. Lo
/// que se ve moverse es esa franja asomando por el borde.
///
/// El giro es MUY lento a propósito: a la velocidad del original marea, y
/// la app tiene que transmitir calma.
class TarjetaBordeAnimado extends StatefulWidget {
  const TarjetaBordeAnimado({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.fondo = AppColors.tarjetaAzulClaro,
    this.colorBorde = AppColors.tarjetaBordeAzul,
    this.radio = 10,
    // Fino a propósito: el borde tiene que dar color, no robar la
    // atención del contenido.
    this.grosorBorde = 2.5,
    this.duracionGiro = const Duration(seconds: 60),
  });

  final Widget child;
  final EdgeInsets padding;

  /// Relleno interno de la tarjeta. Azul claro por defecto. Tiene que ser
  /// OPACO: con alpha se transparenta el fondo de la pantalla.
  final Color fondo;

  /// Color sólido de la franja que gira por el borde.
  final Color colorBorde;

  final double radio;

  /// Cuántos píxeles del contorno quedan sin tapar. Es el ancho visible
  /// del borde iluminado.
  final double grosorBorde;

  /// Cuánto tarda una vuelta completa. Más grande = más lento.
  final Duration duracionGiro;

  @override
  State<TarjetaBordeAnimado> createState() => _TarjetaBordeAnimadoState();
}

class _TarjetaBordeAnimadoState extends State<TarjetaBordeAnimado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: widget.duracionGiro,
    )..repeat();
  }

  @override
  void didUpdateWidget(TarjetaBordeAnimado anterior) {
    super.didUpdateWidget(anterior);
    if (widget.duracionGiro != anterior.duracionGiro) {
      _controlador.duration = widget.duracionGiro;
      _controlador.repeat();
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radioInterno = widget.radio - widget.grosorBorde;

    // RepaintBoundary para que el giro no arrastre a repintarse al resto
    // del Home en cada frame.
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radio),
        child: Stack(
          children: [
            // 1. Base del borde: lo que se ve donde la franja naranja no
            // está pasando en este momento.
            const Positioned.fill(child: ColoredBox(color: AppColors.cardBorder)),

            // 2. La franja que gira. Va en un OverflowBox para poder ser
            // más grande que la tarjeta (tiene que cubrirla en diagonal)
            // sin afectar el tamaño del Stack.
            Positioned.fill(
              child: Center(
                child: OverflowBox(
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: RotationTransition(
                    turns: _controlador,
                    child: SizedBox(
                      // Angosta: cuanto más finita la franja, más corto
                      // el tramo de borde que se ve encendido a la vez.
                      // Alta para cubrir la tarjeta en diagonal al girar.
                      width: 80,
                      height: 900,
                      child: ColoredBox(color: widget.colorBorde),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Relleno interno: tapa la franja y deja asomando solo el
            // contorno.
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(widget.grosorBorde),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.fondo,
                    borderRadius: BorderRadius.circular(radioInterno),
                  ),
                ),
              ),
            ),

            // 4. El contenido. Es el único hijo sin posicionar, así que es
            // el que le da el tamaño al Stack.
            Padding(
              padding: widget.padding + EdgeInsets.all(widget.grosorBorde),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
