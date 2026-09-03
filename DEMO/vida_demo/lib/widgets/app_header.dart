import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import '../theme.dart';

/// Encabezado reutilizable: se repite igual en todas las pantallas de
/// la app ("+VIDA" a la izquierda, avatar del usuario a la derecha).
///
/// En pantallas de detalle que necesiten volver atrás, activar
/// [showBackButton] agrega una flecha "←" a la izquierda de todo.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.showBackButton = false, this.onBack});

  final bool showBackButton;

  /// Acción al tocar la flecha de volver. Si no se provee, hace pop de
  /// la pantalla actual.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            if (showBackButton) ...[
              IconButton(
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 20,
              ),
              const SizedBox(width: 12),
            ],
            Text(
              '+VIDA',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            // GFAvatar de getwidget: mismo lugar, pero con el borde y
            // el tamaño estandarizados de la librería. Los colores siguen
            // saliendo de nuestros tokens.
            const GFAvatar(
              size: GFSize.SMALL,
              shape: GFAvatarShape.circle,
              backgroundColor: AppColors.cardBorder,
              child: Icon(Icons.person, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Línea que se desvanece hacia los bordes en vez de un borde
        // plano: separa el header del contenido sin verse forzada.
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.accent.withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
