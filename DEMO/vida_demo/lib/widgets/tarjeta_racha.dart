import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../datos/fuente_datos.dart';
import '../rachas_recompensas.dart';
import '../theme.dart';
import 'moneda_animada.dart';

// ============================================================
// TU RACHA.
//
// Reemplaza a "Ritmo cardíaco de hoy", que en Progreso era un dato suelto:
// tres bpm que no se conectaban con nada de la pantalla (siguen estando
// donde sí sirven, junto a cada entrenamiento).
//
// La racha sí pertenece acá: Progreso es la pantalla del tiempo, y la
// racha es lo único que mide constancia en vez de esfuerzo de un día.
//
// Regla dura: los hitos pagan MONEDAS, nunca puntos.
// ============================================================

class TarjetaRacha extends StatelessWidget {
  const TarjetaRacha({super.key});

  @override
  Widget build(BuildContext context) {
    final resumen = Datos.i.resumen;
    final racha = resumen.rachaSemanas;
    final hito = proximoHito(racha);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tu racha',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.dentro),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            // Azul lavado, como el resto de la app. Lo único naranja
            // acá es la llama: un detalle chico sobre un fondo azul.
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Encabezado(racha: racha),
              const SizedBox(height: 20),
              _Semanas(historial: resumen.rachaHistorial),
              if (hito != null) ...[
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.cardBorder),
                const SizedBox(height: 16),
                _ProximoHito(racha: racha, hito: hito),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.racha});

  final int racha;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.azulBruma,
            shape: BoxShape.circle,
          ),
          // La llama sigue naranja: es el detalle, no la superficie.
          child: const Icon(
            Icons.local_fire_department,
            size: 28,
            color: AppColors.accentSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$racha', style: AppTheme.display(38)),
                  const SizedBox(width: 6),
                  Text(
                    racha == 1 ? 'semana' : 'semanas',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                racha == 0
                    ? 'Cumplí tu meta esta semana para arrancar una'
                    : 'seguidas cumpliendo tu meta',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Las últimas 8 semanas, una por casilla.
///
/// Es el mismo lenguaje del calendario de cuadritos que ya está en la
/// vista de Año: lleno es semana cumplida, vacío es semana perdida.
class _Semanas extends StatelessWidget {
  const _Semanas({required this.historial});

  final List<bool> historial;

  @override
  Widget build(BuildContext context) {
    // La más reciente a la derecha, como se lee una línea de tiempo.
    final ultimas = historial.length > 8
        ? historial.sublist(historial.length - 8)
        : historial;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÚLTIMAS ${ultimas.length} SEMANAS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < ultimas.length; i++) ...[
              Expanded(child: _Casilla(cumplida: ultimas[i])),
              if (i != ultimas.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({required this.cumplida});

  final bool cumplida;

  @override
  Widget build(BuildContext context) => Semantics(
    label: cumplida ? 'Semana cumplida' : 'Semana no cumplida',
    child: Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cumplida ? AppColors.accent : AppColors.azulBruma,
        borderRadius: BorderRadius.circular(8),
      ),
      // El check hace que la casilla no dependa solo del color: quien no
      // distingue bien los tonos igual ve cuál se cumplió.
      child: cumplida
          ? const Icon(
              CupertinoIcons.checkmark_alt,
              size: 15,
              color: AppColors.card,
            )
          : null,
    ),
  );
}

/// Cuánto falta para las próximas monedas.
class _ProximoHito extends StatelessWidget {
  const _ProximoHito({required this.racha, required this.hito});

  final int racha;
  final HitoRacha hito;

  @override
  Widget build(BuildContext context) {
    final faltan = hito.semanas - racha;
    final avance = (racha / hito.semanas).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                faltan == 1
                    ? 'Te falta 1 semana para tu próxima recompensa'
                    : 'Te faltan $faltan semanas para tu próxima recompensa',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // MONEDAS, nunca puntos: las rachas no dan puntos.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // La moneda sigue naranja en toda la app: es el único
                // sitio donde el naranja significa algo por sí solo.
                const MonedaAnimada(size: 19),
                const SizedBox(width: 3),
                Text(
                  '+${hito.monedas}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.accentSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Barra fina y sin animación de relleno: acá no hay una acción
        // que celebrar, solo una distancia que mostrar.
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: avance,
            minHeight: 5,
            backgroundColor: AppColors.azulBruma,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Vas $racha de ${hito.semanas} semanas',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
