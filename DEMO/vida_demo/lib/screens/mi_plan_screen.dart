import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';

// ============================================================
// Datos de ejemplo (hardcodeados, sin backend todavía), consistentes
// con los que usa Home para el mismo usuario demo.
//
// REGLA DURA DEL PROYECTO: acá NUNCA aparecen monedas — esa es la
// moneda que se gasta en Premios. Mi Plan es solo puntos/cashback/
// datos de póliza.
// ============================================================

class _Tier {
  const _Tier(this.nombre, this.rangoPuntos, this.porcentajeCashback);

  final String nombre;
  final String rangoPuntos;
  final double porcentajeCashback;
}

const List<_Tier> _tiers = [
  _Tier('Bronze', '5,000 – 9,999 pts', 5),
  _Tier('Silver', '10,000 – 19,999 pts', 7.5),
  _Tier('Gold', '20,000 – 29,999 pts', 10),
  _Tier('Platinum', '30,000+ pts', 20),
];

const String categoriaActual = 'Silver';
const int cashbackAcumulado = 450; // en quetzales, acumulado este año
const int puntosAnuales = 12450;

// Proyección simple de fin de año a partir del ritmo actual (placeholder:
// en producción esto sale de una regresión sobre el histórico real del
// usuario, no de una regla fija).
const String categoriaProyectada = 'Gold';
const int cashbackProyectado = 1180;

// ---- Detalles de póliza ----
const String numeroPoliza = 'GT-48213';
const String titularYDependientes = 'Diego Piña + 2 dependientes';
const String tipoPlan = 'Gastos Médicos Mayores — Plan Individual';
const String sumaAsegurada = 'Q500,000';
const String deducible = 'Q5,000 por evento';
const String coaseguro = '10% después del deducible';
const String vigencia = '1 ene 2026 – 31 dic 2026';
const String fechaRenovacion = '1 ene 2027';
const String primaAnual = 'Q18,000';
const String formaPago = 'Mensual';
const String redCobertura = 'Red nacional + emergencias internacionales';
const String estadoPoliza = 'Al día';

class MiPlanScreen extends StatelessWidget {
  const MiPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: const AppHeader(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text('Mi Plan', style: AppTheme.sectionTitle),
                    const SizedBox(height: 20),
                    _buildCashbackCard(context),
                    const SizedBox(height: 20),
                    _buildProyeccionCard(context),
                    const SizedBox(height: 20),
                    _buildCalendarioCard(context),
                    const SizedBox(height: 20),
                    _buildTablaCategorias(context),
                    const SizedBox(height: 20),
                    _buildNotaRegulatoria(context),
                    const SizedBox(height: 28),
                    _buildTituloPoliza(context),
                    const SizedBox(height: 16),
                    _buildCardIdentificacion(context),
                    const SizedBox(height: 16),
                    _buildCardCoberturaYMontos(context),
                    const SizedBox(height: 16),
                    _buildCardPagosYVigencia(context),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const BottomNavBar(currentIndex: 4),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Cashback (puntos/categoría) — ya existente conceptualmente, ahora
  // implementado en Flutter.
  // ============================================================

  Widget _buildCashbackCard(BuildContext context) {
    final tierActual = _tiers.firstWhere((t) => t.nombre == categoriaActual);
    final colorTier = AppColors.colorForTier(categoriaActual);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'Cashback acumulado',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Q$cashbackAcumulado',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: colorTier,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'este año, en categoría $categoriaActual '
            '(${_formatPercent(tierActual.porcentajeCashback)}% de cashback)',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(
            '${_formatNumber(puntosAnuales)} pts acumulados este año',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProyeccionCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, color: AppColors.accentSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'A tu ritmo actual, terminarías el '),
                  TextSpan(
                    text: 'año en categoría $categoriaProyectada',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ', con aproximadamente '),
                  TextSpan(
                    text: 'Q$cashbackProyectado de cashback',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarioCard(BuildContext context) {
    const pasos = [
      (
        icono: Icons.event_outlined,
        texto: 'Corte de categoría anual: 31 de diciembre',
      ),
      (
        icono: Icons.calculate_outlined,
        texto: 'Cálculo de tu cashback: primeros 30 días de enero',
      ),
      (
        icono: Icons.payments_outlined,
        texto: 'Pago: dentro de 30 días después de pagar tu siguiente prima',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'Calendario de tu cashback',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < pasos.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(pasos[i].icono, color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    pasos[i].texto,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            if (i != pasos.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildTablaCategorias(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categorías anuales',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _tiers.length; i++) ...[
            _buildFilaTier(context, _tiers[i]),
            if (i != _tiers.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildFilaTier(BuildContext context, _Tier tier) {
    final esActual = tier.nombre == categoriaActual;
    final color = AppColors.colorForTier(tier.nombre);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(
            tier.nombre,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: esActual ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            tier.rangoPuntos,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Text(
          '${_formatPercent(tier.porcentajeCashback)}%',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (esActual) ...[
          const SizedBox(width: 8),
          Icon(Icons.check_circle, color: color, size: 16),
        ],
      ],
    );
  }

  Widget _buildNotaRegulatoria(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tu cashback siempre se devuelve como dinero, después del '
              'pago de tu prima. Nunca se descuenta directamente de tu '
              'póliza.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Detalles de tu Póliza — datos que la aseguradora expone al
  // asegurado. Agrupados por tema en vez de una sola lista larga.
  // ============================================================

  Widget _buildTituloPoliza(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.shield_outlined, color: AppColors.textPrimary),
        const SizedBox(width: 8),
        Text(
          'Detalles de tu Póliza',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCardIdentificacion(BuildContext context) {
    return _buildCardDatos(context, filas: [
      ('Número de póliza', numeroPoliza, null),
      ('Titular y dependientes', titularYDependientes, null),
      ('Tipo de plan', tipoPlan, null),
      ('Estado de la póliza', estadoPoliza, AppColors.accentSecondary),
    ]);
  }

  Widget _buildCardCoberturaYMontos(BuildContext context) {
    return _buildCardDatos(context, filas: [
      ('Suma asegurada anual', sumaAsegurada, null),
      ('Deducible', deducible, null),
      ('Coaseguro', coaseguro, null),
      ('Red de cobertura', redCobertura, null),
    ]);
  }

  Widget _buildCardPagosYVigencia(BuildContext context) {
    return _buildCardDatos(context, filas: [
      ('Vigencia', vigencia, null),
      ('Fecha de renovación', fechaRenovacion, null),
      ('Prima anual', primaAnual, null),
      ('Forma de pago', formaPago, null),
    ]);
  }

  /// Tarjeta genérica de filas "etiqueta a la izquierda, valor a la
  /// derecha". Cada fila es (etiqueta, valor, color) — color es null
  /// salvo que el valor necesite un color especial (ej. estado "Al día"
  /// en verde).
  Widget _buildCardDatos(
    BuildContext context, {
    required List<(String, String, Color?)> filas,
  }) {
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
          for (var i = 0; i < filas.length; i++) ...[
            _buildFilaDato(context, filas[i]),
            if (i != filas.length - 1) ...[
              const SizedBox(height: 12),
              Divider(color: AppColors.cardBorder, height: 1),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFilaDato(BuildContext context, (String, String, Color?) fila) {
    final (etiqueta, valor, color) = fila;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            valor,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color ?? AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  static String _formatPercent(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  static String _formatNumber(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buffer.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }
}
