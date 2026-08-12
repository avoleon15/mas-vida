import 'dart:math';

import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';

/// Confirmación de canje: recibe los datos del premio canjeado (más
/// 'monedasRestantes', el saldo ya descontado) como argumento de la
/// ruta '/canje-exitoso'.
class CanjeExitosoScreen extends StatelessWidget {
  const CanjeExitosoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final datos =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: const AppHeader(showBackButton: true),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    _buildCheckIcon(context),
                    const SizedBox(height: 20),
                    Text(
                      '¡Canje Exitoso!',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 28),
                    _buildTarjetaCupon(context, datos),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/home', (route) => false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Volver al Inicio',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const BottomNavBar(currentIndex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckIcon(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.accentSecondary.withValues(alpha: 0.22),
            blurRadius: 20,
          ),
        ],
      ),
      child: const Icon(
        Icons.check_circle,
        color: AppColors.accentSecondary,
        size: 96,
      ),
    );
  }

  Widget _buildTarjetaCupon(BuildContext context, Map<String, dynamic> datos) {
    final costo = datos['costoMonedas'] as int;
    final monedasRestantes = datos['monedasRestantes'] as int;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            'Detalles del Cupón',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            (datos['descripcion'] as String).toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          _buildQrPlaceholder(),
          const SizedBox(height: 18),
          Text(
            'Muestra este código en caja para disfrutar tu premio.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          _buildFilaMonedas(
            context,
            Icons.monetization_on,
            '$costo monedas descontadas',
          ),
          const SizedBox(height: 4),
          _buildFilaMonedas(
            context,
            Icons.monetization_on,
            'Te quedan $monedasRestantes monedas',
          ),
        ],
      ),
    );
  }

  Widget _buildFilaMonedas(BuildContext context, IconData icon, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.accentSecondary, size: 16),
        const SizedBox(width: 6),
        Text(
          texto,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// Placeholder visual de un QR: no usamos ningún paquete (qr_flutter no
  /// está en pubspec.yaml todavía), así que dibujamos un patrón simple
  /// que se lea como QR, con marco blanco escaneable en un caso real.
  Widget _buildQrPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      child: const SizedBox(
        width: 160,
        height: 160,
        child: CustomPaint(painter: _QrPatternPainter()),
      ),
    );
  }
}

class _QrPatternPainter extends CustomPainter {
  const _QrPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const columnas = 12;
    final celda = size.width / columnas;
    final negro = Paint()..color = Colors.black;
    final blanco = Paint()..color = Colors.white;
    // Semilla fija para que el patrón se vea siempre igual (no es un QR
    // real, solo un placeholder visual).
    final random = Random(7);

    for (var y = 0; y < columnas; y++) {
      for (var x = 0; x < columnas; x++) {
        if (random.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(x * celda, y * celda, celda, celda),
            negro,
          );
        }
      }
    }

    _dibujarOjo(canvas, negro, blanco, const Offset(0, 0), celda);
    _dibujarOjo(
      canvas,
      negro,
      blanco,
      Offset((columnas - 3) * celda, 0),
      celda,
    );
    _dibujarOjo(
      canvas,
      negro,
      blanco,
      Offset(0, (columnas - 3) * celda),
      celda,
    );
  }

  /// Los tres cuadros de referencia típicos de un código QR en las
  /// esquinas, para que el patrón se lea claramente como QR.
  void _dibujarOjo(
    Canvas canvas,
    Paint negro,
    Paint blanco,
    Offset origen,
    double celda,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(origen.dx, origen.dy, celda * 3, celda * 3),
      negro,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        origen.dx + celda * 0.5,
        origen.dy + celda * 0.5,
        celda * 2,
        celda * 2,
      ),
      blanco,
    );
    canvas.drawRect(
      Rect.fromLTWH(origen.dx + celda, origen.dy + celda, celda, celda),
      negro,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
