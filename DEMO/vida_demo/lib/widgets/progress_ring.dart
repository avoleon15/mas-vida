import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Anillo circular de progreso con brillo, como el de "steps today" en
/// Home. El color se recibe por parámetro para poder reflejar la
/// liga/categoría del usuario (Bronze, Silver, Gold, Platinum).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.size,
    this.strokeWidth = 18,
    this.color = AppColors.accent,
  });

  /// Valor entre 0.0 y 1.0.
  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ProgressRingPainter(
          progress: progress.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
          color: color,
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  });

  final double progress;
  final double strokeWidth;
  final Color color;

  // El anillo arranca arriba (12 en punto).
  static const _startAngle = -pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final sweepAngle = 2 * pi * progress;
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    // Variante más oscura del mismo color, para el gradiente del trazo.
    final colorOscuro = Color.lerp(color, Colors.black, 0.35)!;

    final trackPaint = Paint()
      ..color = AppColors.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Sombra suave, no un brillo: sobre fondo claro un glow saturado se
    // ve raro. Alpha y blur bajos, solo para dar algo de profundidad.
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // Gradiente del trazo: apagado donde arranca el progreso, más
    // brillante hacia donde va llegando.
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [colorOscuro, color],
        transform: const GradientRotation(_startAngle),
      ).createShader(arcRect);

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(arcRect, _startAngle, sweepAngle, false, glowPaint);
    canvas.drawArc(arcRect, _startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color;
  }
}
