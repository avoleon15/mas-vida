import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../datos/modelos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/codigo_qr.dart';
import '../widgets/lluvia_confeti.dart';
import '../widgets/moneda_animada.dart';
import 'premios_screen.dart' show VistaPremios;

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
      // El confeti va en un Stack por ENCIMA de la pantalla entera, no
      // adentro del scroll: tiene que caer sobre todo, incluida la barra
      // de abajo, y seguir cayendo aunque el usuario scrollee.
      body: Stack(
        children: [
          SafeArea(child: _contenido(context, datos)),
          const LluviaConfeti(),
        ],
      ),
    );
  }

  Widget _contenido(BuildContext context, Map<String, dynamic> datos) {
    return Column(
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
                  '¡Canje exitoso!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            children: [
              // Lo primero que se ofrece es ir a donde quedó el cupón:
              // así el usuario aprende desde el primer canje dónde vive.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/premios',
                        (route) => false,
                        arguments: VistaPremios.cupones,
                      ),
                  // Color y forma vienen del tema: ver
                  // elevatedButtonTheme en theme.dart.
                  child: const Text(
                    'Ver mis cupones',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              CupertinoButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
        const BottomNavBar(currentIndex: 3),
      ],
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
    final premio = datos['premio'] as Premio;
    final cupon = datos['cupon'] as CuponCanjeado?;
    final costo = premio.costoMonedas;
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
            'Tu cupón',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            premio.descripcion.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          // El MISMO código que queda en Mis cupones.
          CodigoQr(codigo: cupon?.codigo ?? premio.id, tamano: 160),
          const SizedBox(height: 18),
          Text(
            'Muestra este código en caja para disfrutar tu premio. Lo '
            'guardamos en Premios › Mis cupones.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          _buildFilaMonedas(context, '$costo monedas descontadas'),
          const SizedBox(height: 4),
          _buildFilaMonedas(context, 'Te quedan $monedasRestantes monedas'),
        ],
      ),
    );
  }

  Widget _buildFilaMonedas(BuildContext context, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MonedaAnimada(size: 21),
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
}
