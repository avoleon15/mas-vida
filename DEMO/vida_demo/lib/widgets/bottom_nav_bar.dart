import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

// ============================================================
// LA BARRA INFERIOR.
//
// Píldora flotante con un indicador que se DESLIZA hasta la pestaña
// tocada, en vez de encenderse y apagarse. El movimiento es lo que hace
// que la barra se sienta de iOS.
//
// Está dibujada a mano y no con una animación de Lottie. Se probó con
// una: el archivo traía sus propios íconos y textos incrustados en el
// vector, su propio state machine (que el paquete de Flutter no soporta)
// y un lienzo de 800×600 que había que recortar a ojo. El indicador
// terminaba en la pestaña equivocada y tapaba la etiqueta. Acá el
// indicador se posiciona con el mismo ancho que usan los ítems, así que
// no puede desalinearse.
// ============================================================

/// Cuánto tarda el indicador en llegar a la pestaña nueva.
///
/// Corto a propósito: la barra se ve en todas las pantallas y una
/// animación lenta acá se vuelve molesta a la tercera vez.
const Duration _duracionDeslizar = Duration(milliseconds: 320);

/// Barra inferior reutilizable: se repite igual en todas las pantallas
/// de la app. [currentIndex] indica qué ítem resaltar como activo.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key, required this.currentIndex});

  final int currentIndex;

  static const _items = [
    _NavItemData(icon: Icons.home_rounded, label: 'Hoy', route: '/home'),
    _NavItemData(
      icon: Icons.show_chart_rounded,
      label: 'Progreso',
      route: '/progress',
    ),
    _NavItemData(icon: Icons.groups_rounded, label: 'Social', route: '/social'),
    _NavItemData(
      icon: Icons.emoji_events_rounded,
      label: 'Premios',
      route: '/premios',
    ),
    _NavItemData(
      icon: Icons.shield_rounded,
      label: 'Mi Plan',
      route: '/mi-plan',
    ),
  ];

  void _tocar(BuildContext context, int indice) {
    if (indice == currentIndex) return;
    HapticFeedback.selectionClick();

    final ruta = _items[indice].route;
    if (ruta == '/home') {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushNamed(ruta);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quieto = MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, medidas) {
            // Los cinco ítems reparten el ancho en partes iguales, y el
            // indicador usa ESE mismo ancho. Por eso siempre cae justo
            // debajo del ítem, sin números medidos a ojo.
            final anchoItem = medidas.maxWidth / _items.length;

            return Stack(
              children: [
                AnimatedPositioned(
                  duration: quieto ? Duration.zero : _duracionDeslizar,
                  // easeOutCubic: arranca rápido y frena al llegar, que
                  // es como se mueven las cosas en iOS. Sin rebote: el
                  // indicador no es un elemento con el que se juega.
                  curve: Curves.easeOutCubic,
                  left: anchoItem * currentIndex,
                  top: 0,
                  bottom: 0,
                  width: anchoItem,
                  // El margen deja aire entre la píldora y los ítems de
                  // al lado: pegada al borde se lee como una columna, no
                  // como algo que se posó ahí.
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: AppColors.azulBruma,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      SizedBox(
                        width: anchoItem,
                        child: _NavItem(
                          data: _items[i],
                          selected: i == currentIndex,
                          onTap: () => _tocar(context, i),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      // opaque: el toque vale en todo el alto del ítem, no solo encima
      // de la letra. Un blanco de 4 px de alto es imposible de pegarle.
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // El horizontal no es decorativo: sin él las etiquetas de dos
        // ítems vecinos se tocan y la fila se lee como una sola palabra
        // larga. Con aire, FittedBox achica la que no entre.
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // El ícono crece un poco al seleccionarse. Es el único
            // cambio de tamaño de la barra: alcanza para que el ojo
            // sepa dónde está sin que nada salte.
            AnimatedScale(
              duration: _duracionDeslizar,
              curve: Curves.easeOutCubic,
              scale: selected ? 1.12 : 1,
              child: Icon(data.icon, size: 20, color: color),
            ),
            const SizedBox(height: 3),
            // FittedBox: "Progreso" es la etiqueta más larga y en una
            // pantalla angosta no entra. Se achica en vez de cortarse
            // con puntos suspensivos.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                data.label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
