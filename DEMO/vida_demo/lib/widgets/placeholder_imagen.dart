import 'package:flutter/material.dart';
import '../theme.dart';

/// Placeholder visual reutilizable para donde iría una foto/logo real de
/// comercio (todavía no tenemos assets reales). Fondo con rayas
/// diagonales sutiles y un texto centrado (ej. "LOGO", "FOTO DEL
/// COMERCIO").
class PlaceholderImagen extends StatelessWidget {
  const PlaceholderImagen({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color.lerp(AppColors.card, AppColors.accent, 0.12)!,
      child: CustomPaint(
        painter: const _RayasDiagonalesPainter(),
        child: Center(
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _RayasDiagonalesPainter extends CustomPainter {
  const _RayasDiagonalesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.05)
      ..strokeWidth = 10;
    const espacio = 22.0;
    final total = size.width + size.height;
    for (double x = -size.height; x < total; x += espacio) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
