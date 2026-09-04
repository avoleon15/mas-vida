import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../rachas_recompensas.dart';
import '../theme.dart';
import 'moneda_animada.dart';

// ============================================================
// HISTORIAL DE MONEDAS.
//
// Se abre tocando el chip de monedas del encabezado de "Objetivos de la
// semana". Junta en un solo lugar de dónde salieron:
//
//   1. Los objetivos cumplidos, semana por semana.
//   2. Las recompensas por constancia (los 5 hitos de racha).
//
// Las recompensas por constancia vivían sueltas en Progreso, donde no se
// entendía con qué se relacionaban. Acá quedan al lado de lo que las
// paga.
//
// Regla dura: acá van MONEDAS, nunca puntos. Los puntos mueven el
// cashback anual y no se mezclan con esto.
// ============================================================

/// Abre la hoja del historial de monedas.
void mostrarHojaMonedas(BuildContext context) {
  HapticFeedback.selectionClick();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
    builder: (_) => const _HojaMonedas(),
  );
}

class _HojaMonedas extends StatelessWidget {
  const _HojaMonedas();

  @override
  Widget build(BuildContext context) {
    final semana = Datos.i.resumen.objetivosSemana;

    return Container(
      // Alta, pero no pantalla completa: se sigue viendo que hay algo
      // atrás y se puede cerrar arrastrando.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barrita de arrastre: dice que la hoja se puede empujar
            // hacia abajo antes de que el usuario lo intente.
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tus monedas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: AppColors.textSecondary,
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Total(semana: semana),
                    const SizedBox(height: AppSpacing.seccion),

                    const _Etiqueta('DE TUS OBJETIVOS'),
                    const SizedBox(height: AppSpacing.dentro),
                    _HistorialSemanas(semanas: semana.semanas),
                    const SizedBox(height: AppSpacing.seccion),

                    const _Etiqueta('RECOMPENSAS POR CONSTANCIA'),
                    const SizedBox(height: AppSpacing.dentro),
                    const _Hitos(),
                    const SizedBox(height: AppSpacing.entre),
                    Text(
                      // Las monedas se gastan y caducan: decirlo acá evita
                      // que alguien las junte creyendo que duran para
                      // siempre.
                      'Las monedas se gastan en Premios y caducan a los 6 '
                      'meses de ganadas.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.semana});

  final ObjetivosSemana semana;

  @override
  Widget build(BuildContext context) {
    final saldo = Datos.i.resumen.monedas.saldo;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card,
            Color.lerp(AppColors.accent, AppColors.card, 0.93)!,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.accentSecondary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Center(child: MonedaAnimada(size: 32)),
          ),
          const SizedBox(width: AppSpacing.entre),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${semana.monedasGanadas} este mes',
                  style: AppTheme.display(34),
                ),
                Text(
                  // El saldo es otra cosa: incluye meses anteriores y
                  // descuenta lo gastado en Premios.
                  '$saldo en total disponibles',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Qué pagó cada semana, y por qué.
class _HistorialSemanas extends StatelessWidget {
  const _HistorialSemanas({required this.semanas});

  final List<SemanaObjetivos> semanas;

  @override
  Widget build(BuildContext context) {
    // De la más reciente a la más vieja: el historial se lee para atrás.
    final conMonedas = semanas.reversed
        .where((s) => s.estado != EstadoSemana.futura)
        .toList();

    if (conMonedas.isEmpty) {
      return _Tarjeta(
        children: [
          Text(
            'Todavía no cerraste ninguna semana.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return _Tarjeta(
      children: [
        for (var i = 0; i < conMonedas.length; i++) ...[
          _FilaSemana(semana: conMonedas[i]),
          if (i != conMonedas.length - 1) const _Separador(),
        ],
      ],
    );
  }
}

class _FilaSemana extends StatelessWidget {
  const _FilaSemana({required this.semana});

  final SemanaObjetivos semana;

  @override
  Widget build(BuildContext context) {
    final cumplidos = semana.objetivos.where((o) => o.completo).toList();
    final estiloNota = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
      height: 1.3,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Semana ${semana.numero}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (cumplidos.isEmpty)
                Text('No cumpliste ningún objetivo', style: estiloNota)
              else
                // Qué objetivo pagó qué. Sin esto el número de monedas de
                // la semana es un total sin explicación.
                for (final o in cumplidos)
                  Text('${o.nombre} · +${o.monedas}', style: estiloNota),
              if (semana.subioDeRango)
                Text(
                  'Cumpliste los tres: subiste de rango',
                  style: estiloNota?.copyWith(
                    color: AppColors.accentSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.dentro),
        Text(
          '+${semana.monedasGanadas}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: semana.monedasGanadas > 0
                ? AppColors.accentSecondary
                : AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Los cinco hitos de racha. Se mudaron acá desde Progreso, donde estaban
/// sueltos y no se entendía con qué se relacionaban.
class _Hitos extends StatelessWidget {
  const _Hitos();

  @override
  Widget build(BuildContext context) {
    final racha = Datos.i.resumen.rachaSemanas;

    return _Tarjeta(
      children: [
        for (var i = 0; i < hitosRacha.length; i++) ...[
          _FilaHito(hito: hitosRacha[i], racha: racha),
          if (i != hitosRacha.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FilaHito extends StatelessWidget {
  const _FilaHito({required this.hito, required this.racha});

  final HitoRacha hito;
  final int racha;

  @override
  Widget build(BuildContext context) {
    final alcanzado = racha >= hito.semanas;
    final color = alcanzado
        ? AppColors.accentSecondary
        : AppColors.textSecondary;

    return Row(
      children: [
        Icon(
          alcanzado ? Icons.check_circle : Icons.radio_button_unchecked,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${hito.semanas} semanas seguidas',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: alcanzado
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontWeight: alcanzado ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        MonedaAnimada(size: 19, apagado: !alcanzado),
        const SizedBox(width: 4),
        Text(
          '+${hito.monedas}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Piezas compartidas
// ============================================================

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.4,
    ),
  );
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.fondoDePantalla,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: AppColors.cardBorder),
  );
}
