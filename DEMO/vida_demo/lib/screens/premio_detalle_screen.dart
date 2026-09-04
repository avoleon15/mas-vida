import 'package:flutter/material.dart';
import '../datos/modelos.dart';
import '../theme.dart';
import '../widgets/placeholder_imagen.dart';
import '../widgets/moneda_animada.dart';
import 'premios_screen.dart' show monedasUsuario;

/// Detalle de un premio: recibe los datos del premio seleccionado como
/// argumento de la ruta '/premio-detalle' (un Map, igual al que arma la
/// lista de ejemplo en premios_screen.dart).
class PremioDetalleScreen extends StatelessWidget {
  const PremioDetalleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final premio = ModalRoute.of(context)!.settings.arguments as Premio;
    final costo = premio.costoMonedas;
    final alcanza = monedasUsuario >= costo;
    final saldoRestante = monedasUsuario - costo;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      const SizedBox(
                        width: double.infinity,
                        height: 240,
                        child: PlaceholderImagen(texto: 'FOTO DEL COMERCIO'),
                      ),
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 12,
                        left: 16,
                        child: _buildBotonAtras(context),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${premio.nombre.toUpperCase()} · '
                          '${premio.zona.toUpperCase()}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                letterSpacing: 1.2,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          premio.descripcion.toUpperCase(),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 14),
                        _buildPillCosto(context, costo, alcanza, saldoRestante),
                        const SizedBox(height: 18),
                        Text(
                          premio.detalle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                        ),
                        const SizedBox(height: 20),
                        _buildCondicionesCard(context, premio.condiciones),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: alcanza
                          ? () => Navigator.of(context).pushNamed(
                              '/canje-exitoso',
                              arguments: {
                                'premio': premio,
                                'monedasRestantes': saldoRestante,
                              },
                            )
                          : null,
                      // El color y la forma los pone el tema
                      // (elevatedButtonTheme). Antes acá había un
                      // foregroundColor negro sobre el azul de marca y
                      // el botón no se leía.
                      child: Text(
                        alcanza
                            ? 'CANJEAR POR $costo MONEDAS'
                            : 'TE FALTAN ${costo - monedasUsuario} MONEDAS',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Se descuentan al confirmar. No hay devoluciones.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonAtras(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
      ),
    );
  }

  /// Píldora con el costo en monedas, más un texto al lado con el saldo
  /// que quedaría (o cuánto falta, si no alcanza).
  Widget _buildPillCosto(
    BuildContext context,
    int costo,
    bool alcanza,
    int saldoRestante,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accentSecondary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.accentSecondary.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MonedaAnimada(size: 21),
              const SizedBox(width: 6),
              Text(
                '$costo monedas',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.accentSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          alcanza
              ? 'Te quedan $saldoRestante'
              : 'Te faltan ${costo - monedasUsuario}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildCondicionesCard(BuildContext context, String condiciones) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONDICIONES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            condiciones,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: AppColors.cardBorder, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Vence',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '30 días desde el canje',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
