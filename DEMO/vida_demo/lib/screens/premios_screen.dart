import 'package:flutter/material.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/placeholder_imagen.dart';

// ============================================================
// Datos de ejemplo. Todo hardcodeado por ahora (sin backend) y
// organizado en una lista simple de mapas, para que sea fácil de
// reemplazar después con datos reales.
//
// REGLA DURA DEL PROYECTO: acá se gastan MONEDAS, nunca puntos. Los
// puntos solo definen categoría anual y % de cashback y no aparecen en
// ninguna pantalla de Premios.
// ============================================================

/// Saldo de monedas del usuario. Se comparte con las pantallas de
/// detalle y canje exitoso para que el flujo sea consistente.
// ============================================================
// Esta pantalla no lee JSON: el catálogo y el saldo salen de `Datos.i`.
//
// REGLA DURA: acá solo hay MONEDAS. Los PUNTOS nunca aparecen en
// Premios, y canjear monedas nunca descuenta puntos.
// ============================================================

/// Saldo de monedas del usuario.
int get monedasUsuario => Datos.i.resumen.monedas.saldo;

List<Premio> get _premios => Datos.i.catalogo.premios;

List<String> get _categorias => Datos.i.catalogo.categorias;

class PremiosScreen extends StatefulWidget {
  const PremiosScreen({super.key});

  @override
  State<PremiosScreen> createState() => _PremiosScreenState();
}

class _PremiosScreenState extends State<PremiosScreen> {
  String _categoriaSeleccionada = 'Todos';

  @override
  Widget build(BuildContext context) {
    final premiosFiltrados = _categoriaSeleccionada == 'Todos'
        ? _premios
        : _premios.where((p) => p.categoria == _categoriaSeleccionada).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: const AppHeader(),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTituloYSaldo(context),
                          _buildVencimientoPermanente(context),
                          ?_buildAvisoCaducidad(context),
                          const SizedBox(height: 20),
                          _buildChipsCategorias(context),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.7,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) =>
                            _buildTarjetaPremio(context, premiosFiltrados[i]),
                        childCount: premiosFiltrados.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const BottomNavBar(currentIndex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildTituloYSaldo(BuildContext context) {
    return Row(
      children: [
        Text(
          'Premios',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accentSecondary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, color: Colors.black, size: 16),
              const SizedBox(width: 6),
              Text(
                '$monedasUsuario',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Cuándo vence el próximo lote de monedas. SIEMPRE visible, no solo
  /// cuando está por caducar.
  ///
  /// Antes esta información solo aparecía en los últimos 15 días, y en
  /// Progreso había una tarjeta que la repetía. Al quitar esa tarjeta, el
  /// dato tenía que quedar disponible acá todo el tiempo: es plata del
  /// usuario y enterarse dos semanas antes es tarde para planificar.
  Widget _buildVencimientoPermanente(BuildContext context) {
    final lote = Datos.i.resumen.monedas.proximoLoteACaducar;
    if (lote == null) return const SizedBox.shrink();

    // El aviso de urgencia de abajo ya lo dice con más fuerza: no hace
    // falta decirlo dos veces seguidas.
    if (lote.cercaDeCaducar) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${lote.cantidad} de tus monedas vencen en '
              '${lote.diasParaCaducar} días. Las monedas duran 6 meses '
              'desde que las ganás.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// Aviso cuando el lote de monedas más próximo está por caducar. Las
  /// monedas caducan a los 6 meses de acuñadas.
  Widget? _buildAvisoCaducidad(BuildContext context) {
    final lote = Datos.i.resumen.monedas.proximoLoteACaducar;
    if (lote == null || !lote.cercaDeCaducar) return null;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.hourglass_bottom,
              size: 18,
              color: AppColors.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lote.diasParaCaducar == 1
                    ? '${lote.cantidad} de tus monedas caducan mañana. '
                          'Aprovechalas.'
                    : '${lote.cantidad} de tus monedas caducan en '
                          '${lote.diasParaCaducar} días. Aprovechalas.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipsCategorias(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < _categorias.length; i++) ...[
            _buildChip(context, _categorias[i]),
            if (i != _categorias.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String categoria) {
    final activo = categoria == _categoriaSeleccionada;
    return GestureDetector(
      onTap: () => setState(() => _categoriaSeleccionada = categoria),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: activo ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: activo ? null : Border.all(color: AppColors.cardBorder),
        ),
        child: Text(
          categoria,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: activo ? Colors.black : AppColors.textSecondary,
            fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTarjetaPremio(BuildContext context, Premio premio) {
    final costo = premio.costoMonedas;
    final alcanza = monedasUsuario >= costo;
    final faltan = costo - monedasUsuario;

    return GestureDetector(
      onTap: () =>
          Navigator.of(context).pushNamed('/premio-detalle', arguments: premio),
      child: Opacity(
        opacity: alcanza ? 1 : 0.55,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AspectRatio(
                  aspectRatio: 1.4,
                  child: PlaceholderImagen(texto: 'LOGO'),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        premio.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        premio.descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: AppColors.accentSecondary,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$costo',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.accentSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (!alcanza) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'te faltan $faltan',
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
