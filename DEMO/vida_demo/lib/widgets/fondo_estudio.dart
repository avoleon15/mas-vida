import 'dart:math' show Random;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import '../theme.dart';

/// Telón de fondo del preview web: lo que se ve DETRÁS del marco de iPhone.
/// Solo aplica en Web/desktop; en el build real de iOS la app ocupa toda la
/// pantalla y este widget nunca se usa.
///
/// Idea: se mantiene oscuro a propósito — la app es de tema claro, así que
/// un fondo oscuro hace que el celular resalte. Lo que se le quita es lo
/// monótono: en vez de un negro plano, un degradado tintado con el azul
/// marino de la marca, dos halos suaves (verde detrás del celular, azul
/// descentrado) y anillos concéntricos muy tenues que hacen eco del anillo
/// de pasos de Home.
///
/// Todo va a opacidad muy baja (3%–13%): la idea es que se sienta, no que
/// se note ni compita con el contenido de la pantalla.
class FondoEstudio extends StatelessWidget {
  const FondoEstudio({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        // Degradado base: azul marino muy oscuro (derivado de textPrimary
        // #1A2E35) hacia casi negro. Nunca negro puro — el tinte es lo que
        // le da vida respecto al #0D0D0D anterior.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF16262E),
            Color(0xFF0D1619),
            Color(0xFF0A1013),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _PintorFondo(),
        child: child,
      ),
    );
  }
}

class _PintorFondo extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final rect = Offset.zero & size;

    // 1) Halo verde detrás del celular: da la sensación de que el
    // dispositivo está iluminado y lo despega del fondo.
    final radioHalo = size.shortestSide * 0.78;
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.accentSecondary.withValues(alpha: 0.13),
          AppColors.accentSecondary.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: centro, radius: radioHalo));
    canvas.drawCircle(centro, radioHalo, halo);

    // 2) Halo azul descentrado (arriba a la izquierda). Rompe la simetría
    // perfecta, que es justo lo que hace que un fondo se vea "de molde".
    final centroAzul = Offset(size.width * 0.17, size.height * 0.20);
    final radioAzul = size.shortestSide * 0.55;
    final haloAzul = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.accent.withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: centroAzul, radius: radioAzul));
    canvas.drawCircle(centroAzul, radioAzul, haloAzul);

    // 3) Anillos concéntricos: eco visual del anillo de pasos de Home.
    // Quedan casi ocultos detrás del celular; solo se asoman a los lados,
    // que es exactamente el efecto buscado.
    final anillo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.035);
    for (var i = 1; i <= 5; i++) {
      canvas.drawCircle(centro, size.shortestSide * (0.30 + i * 0.15), anillo);
    }

    // 4) Viñeta: oscurece las esquinas para que la vista caiga al centro.
    final vineta = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.38),
        ],
        stops: const [0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vineta);

    // 5) Grano fino encima de todo. Además de dar textura, rompe el
    // "banding": los degradados suaves sobre áreas grandes producen bandas
    // visibles en pantallas de 8 bits, y el ruido las disuelve.
    // Semilla fija para que el patrón sea siempre el mismo y no "vibre"
    // entre repintados.
    final random = Random(42);
    final cantidad = (size.width * size.height / 1400).clamp(0, 6000).toInt();
    final puntos = List<Offset>.generate(
      cantidad,
      (_) => Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      ),
    );
    final grano = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.022);
    canvas.drawPoints(PointMode.points, puntos, grano);
  }

  // El fondo es estático: no depende de estado, así que nunca se repinta.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
