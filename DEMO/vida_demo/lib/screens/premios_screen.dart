import 'package:flutter/material.dart';
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
const int monedasUsuario = 40;

const List<Map<String, dynamic>> _premios = [
  {
    'nombre': 'Café 4a Calle',
    'zona': 'Zona 10',
    'categoria': 'Cafés',
    'descripcion': 'Bebida caliente gratis',
    'detalle':
        'Cualquier bebida caliente de 12 oz. Válido en las tres '
        'sucursales de la ciudad.',
    'condiciones':
        'Un cupón por persona al mes. No acumulable con otras '
        'promociones. Mostrá el código en caja antes de pagar.',
    'costoMonedas': 20,
  },
  {
    'nombre': 'Gimnasio Cumbre',
    'zona': 'Zona 9',
    'categoria': 'Gimnasios',
    'descripcion': 'Mes de clases grupales',
    'detalle':
        'Acceso a todas las clases grupales del gimnasio durante un '
        'mes completo.',
    'condiciones':
        'Aplica para nuevos inscritos o membresías vencidas. Presentá '
        'tu DPI al activar el cupón.',
    'costoMonedas': 40,
  },
  {
    'nombre': 'Farmacia Vida Sana',
    'zona': 'Zona 1',
    'categoria': 'Farmacias',
    'descripcion': '15% en vitaminas',
    'detalle':
        'Descuento aplicable en toda la línea de vitaminas y '
        'suplementos de la farmacia.',
    'condiciones':
        'No acumulable con otras promociones. Válido únicamente en '
        'tienda física.',
    'costoMonedas': 30,
  },
  {
    'nombre': 'Deportes Xelajú',
    'zona': 'Zona 14',
    'categoria': 'Gimnasios',
    'descripcion': 'Q150 de crédito',
    'detalle':
        'Crédito aplicable en cualquier producto de la tienda, sin '
        'fecha de vencimiento dentro del período de validez.',
    'condiciones':
        'Crédito no acumulable con otras promociones. Un cupón '
        'por cliente.',
    'costoMonedas': 80,
  },
];

const List<String> _categorias = ['Todos', 'Gimnasios', 'Cafés', 'Farmacias'];

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
        : _premios
              .where((p) => p['categoria'] == _categoriaSeleccionada)
              .toList();

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

  Widget _buildTarjetaPremio(
    BuildContext context,
    Map<String, dynamic> premio,
  ) {
    final costo = premio['costoMonedas'] as int;
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
                        premio['nombre'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        premio['descripcion'] as String,
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
