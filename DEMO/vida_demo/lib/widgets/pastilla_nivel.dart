import 'package:flutter/material.dart';

import '../reglas_puntos.dart';
import '../theme.dart';
import 'numero_animado.dart' show milesConComa;

// ============================================================
// EL NIVEL DEL AÑO, EN CHICO.
//
// Las dos piezas del bloque "Este año" de Hoy: la pastilla con el nivel
// y su porcentaje, y cuánto falta para el siguiente. La escalera
// completa vive en Mi Plan, adentro de la tarjeta del cashback.
// ============================================================

/// "10" o "7,5". Coma decimal, como se usa acá.
String porcentajeDicho(double v) =>
    v == v.roundToDouble() ? '${v.round()}' : v.toString().replaceAll('.', ',');

/// Pastilla con el nivel actual y su porcentaje de cashback.
class PastillaNivel extends StatelessWidget {
  const PastillaNivel({super.key, required this.nivel});

  final int nivel;

  @override
  Widget build(BuildContext context) {
    final datos = nivelPorNumero(nivel);
    final color = AppColors.colorForNivel(nivel);
    final pct = datos?.porcentajeCashback;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        // Sin porcentaje definido no se inventa uno.
        pct == null
            ? 'Nivel $nivel'
            : 'Nivel $nivel · ${porcentajeDicho(pct)}% de cashback',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// La barra de cuánto falta para el nivel siguiente.
class AvanceAlSiguienteNivel extends StatelessWidget {
  const AvanceAlSiguienteNivel({
    super.key,
    required this.puntosTotal,
    required this.nivelActual,
  });

  final int puntosTotal;
  final int nivelActual;

  /// El nivel de arriba, o null si ya está en el último que se alcanza.
  Nivel? _siguienteNivel() => siguienteNivelAlcanzable(nivelActual);

  @override
  Widget build(BuildContext context) {
    final siguiente = _siguienteNivel();
    final estiloApoyo = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    if (siguiente == null) {
      return Text(
        nivelPorNumero(nivelActual + 1) == null
            ? 'Estás en el nivel más alto de cashback'
            : 'Llegaste al nivel más alto que da la actividad física',
        style: estiloApoyo,
      );
    }
    if (!siguiente.definido) {
      return Text(
        'El nivel ${siguiente.numero} todavía no tiene rango definido',
        style: estiloApoyo,
      );
    }

    final piso = nivelPorNumero(nivelActual)?.puntosMinimos ?? 0;
    final techo = siguiente.puntosMinimos!;
    final avance = techo > piso
        ? ((puntosTotal - piso) / (techo - piso)).clamp(0.0, 1.0)
        : 1.0;
    final faltan = techo - puntosTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: avance,
            minHeight: 7,
            backgroundColor: AppColors.cardBorder,
            valueColor: AlwaysStoppedAnimation(
              AppColors.colorForNivel(siguiente.numero),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Te faltan ${milesConComa(faltan)} pts',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: ' para el nivel ${siguiente.numero}'),
            ],
          ),
          style: estiloApoyo,
        ),
      ],
    );
  }
}
