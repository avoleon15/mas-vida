import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

/// El botón de acción principal de +Vida: ancho completo, azul de marca,
/// ícono a la izquierda del texto.
///
/// Existe como widget compartido para que no haya dos recetas del mismo
/// botón: "Ver mi cashback" en Hoy y "Ver mis récords" en Progreso son el
/// mismo elemento y tienen que verse idénticos siempre.
///
/// Es un [CupertinoButton], no un `GestureDetector` con animación propia:
/// el atenuado al presionar es el del sistema, así que se siente igual
/// que cualquier botón de iOS (ver la regla de UI en CLAUDE.md).
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.icono,
    required this.onPressed,
    this.anchoCompleto = true,
  });

  final String texto;
  final IconData icono;
  final VoidCallback onPressed;

  /// False para la versión compacta, que se encoge a su contenido y sirve
  /// como acción al lado de un título. El color, el radio y la sombra son
  /// los mismos: lo único que cambia es cuánto ocupa.
  final bool anchoCompleto;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          // Sombra suave, nunca un glow: sobre fondo claro un brillo
          // saturado se ve mal (ver CLAUDE.md).
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CupertinoButton(
        // Azul: es una acción, y el azul es el color de acción de la app.
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(14),
        padding: anchoCompleto
            ? const EdgeInsets.symmetric(vertical: 15)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        minimumSize: anchoCompleto ? null : Size.zero,
        onPressed: onPressed,
        child: SizedBox(
          width: anchoCompleto ? double.infinity : null,
          child: Row(
            mainAxisSize: anchoCompleto ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: anchoCompleto ? 19 : 16, color: Colors.white),
              SizedBox(width: anchoCompleto ? AppSpacing.dentro : 6),
              Flexible(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (anchoCompleto
                              ? Theme.of(context).textTheme.titleSmall
                              : Theme.of(context).textTheme.labelLarge)
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
