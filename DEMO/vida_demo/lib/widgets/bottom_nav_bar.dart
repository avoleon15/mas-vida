import 'package:flutter/material.dart';
import '../theme.dart';

/// Barra inferior reutilizable: se repite igual en todas las pantallas
/// de la app. [currentIndex] indica qué ítem resaltar como activo.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key, required this.currentIndex});

  final int currentIndex;

  static const _items = [
    _NavItemData(icon: Icons.home_rounded, label: 'Hoy', route: '/home'),
    _NavItemData(
      icon: Icons.show_chart_rounded,
      label: 'Progress',
      route: '/progress',
    ),
    _NavItemData(
      icon: Icons.groups_outlined,
      label: 'Social',
      route: '/social',
    ),
    _NavItemData(
      icon: Icons.emoji_events_outlined,
      label: 'Premios',
      route: '/premios',
    ),
    _NavItemData(
      icon: Icons.shield_outlined,
      label: 'Mi Plan',
      route: '/mi-plan',
    ),
  ];

  void _onItemTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (_items[index].route) {
      case '/home':
        Navigator.of(context).pushReplacementNamed('/home');
      case '/progress':
        Navigator.of(context).pushNamed('/progress');
      case '/social':
        Navigator.of(context).pushNamed('/social');
      case '/premios':
        Navigator.of(context).pushNamed('/premios');
      case '/mi-plan':
        Navigator.of(context).pushNamed('/mi-plan');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Barra flotante tipo "píldora": con margen alrededor (no pegada a
    // los bordes), esquinas totalmente redondeadas, borde gris sutil y
    // sombra suave y neutra (no un glow de color) para que se note que
    // flota sobre el contenido.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            return Expanded(
              child: _NavItem(
                icon: item.icon,
                label: item.label,
                selected: index == currentIndex,
                onTap: () => _onItemTap(context, index),
              ),
            );
          }),
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
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );

    // El ítem activo lleva una píldora de fondo verde muy pálido (sobre
    // fondo claro ya no alcanza con el contraste solo); los inactivos
    // van sin ningún borde, solo ícono y texto en gris tenue.
    final child = selected
        ? Container(
            decoration: BoxDecoration(
              color: AppColors.accentSecondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: content,
          )
        : content;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
