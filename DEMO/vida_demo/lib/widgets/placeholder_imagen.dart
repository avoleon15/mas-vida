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

/// El logo de un comercio, con el placeholder de reserva.
///
/// Una sola pieza para las dos pantallas de Premios: si el premio no
/// trae imagen, o el archivo no está en assets todavía, se ve el
/// placeholder rayado en vez de un hueco gris o un error rojo. Así se
/// pueden ir agregando los comercios de a uno sin tocar código.
class FotoComercio extends StatelessWidget {
  const FotoComercio({
    super.key,
    required this.ruta,
    required this.texto,
    this.fondo,
    this.margen = 18,
  });

  /// Ruta del asset, o null si el premio todavía no tiene imagen.
  final String? ruta;

  /// Qué dice el placeholder cuando no hay imagen.
  final String texto;

  /// Color detrás del logo, en hex "#RRGGBB". Blanco si no viene.
  final String? fondo;

  /// Aire alrededor del logo. Sin esto los logos anchos tocan los bordes
  /// de la tarjeta y se leen como un banner, no como una marca.
  final double margen;

  /// El hex del catálogo convertido a color, o blanco si viene mal
  /// escrito. Un hex malo en el JSON no puede tumbar el catálogo entero.
  Color get _color {
    final hex = fondo?.replaceFirst('#', '');
    if (hex == null || hex.length != 6) return Colors.white;
    final valor = int.tryParse(hex, radix: 16);
    return valor == null ? Colors.white : Color(0xFF000000 | valor);
  }

  @override
  Widget build(BuildContext context) {
    final ruta = this.ruta;
    if (ruta == null || ruta.isEmpty) {
      return PlaceholderImagen(texto: texto);
    }

    // El fondo lo pone el catálogo, no la tarjeta: la mayoría de los
    // logos viene con fondo blanco o transparente, pero los que son
    // blancos sobre negro necesitan el suyo o desaparecen.
    return ColoredBox(
      color: _color,
      child: Padding(
        padding: EdgeInsets.all(margen),
        child: Image.asset(
          ruta,
          // contain, NUNCA cover: son logos, no fotos de local. Con cover
          // se recorta la marca y quedan medias palabras.
          fit: BoxFit.contain,
          // Los logos son chicos (algunos de 100 px de ancho) y se
          // estiran a la tarjeta. Sin esto Flutter los suaviza tanto que
          // se ven borrosos.
          filterQuality: FilterQuality.medium,
          // El archivo puede no estar todavía: el catálogo tiene que
          // seguir funcionando mientras se consiguen los logos.
          errorBuilder: (_, _, _) => PlaceholderImagen(texto: texto),
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
