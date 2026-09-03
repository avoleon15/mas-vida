import 'package:flutter/material.dart';
import '../datos/modelos.dart';
import '../theme.dart';

/// Panel del objetivo de la semana. Va escondido al lado del anillo de
/// pasos y se revela deslizando.
///
/// Mecánica (contrato v1): hay 3 objetivos por semana y una escalera de
/// RANGO con dificultad progresiva. Cumplir los tres SUBE un rango; no
/// cumplirlos BAJA uno. Piso 1, techo 4. Ojo con el nombre: Nivel es la
/// escalera ANUAL de cashback, que sale de los puntos, y no tiene nada
/// que ver con esto. El
/// ciclo va de lunes 00:00 a domingo 23:59, hora de Guatemala.
///
/// La META EN PASOS de cada rango todavía no existe en ninguna fuente
/// (`contrato-v1-corregido.md` la deja pendiente y la define Luis en el
/// motor de reglas), así que acá se muestra "pendiente" en vez de un
/// número inventado.
class PanelObjetivoSemana extends StatelessWidget {
  const PanelObjetivoSemana({
    super.key,
    required this.retos,
    required this.size,
  });

  final EstadoRetos retos;

  /// Mismo lado que el anillo, para que el panel ocupe exactamente el
  /// mismo espacio al deslizar.
  final double size;

  @override
  Widget build(BuildContext context) {
    final rango = retos.rangoActual;
    // Últimas 8 semanas, como en Progress.
    final historial = retos.historial.length > 8
        ? retos.historial.sublist(retos.historial.length - 8)
        : retos.historial;

    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'OBJETIVO DE LA SEMANA',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.dentro),
          Text('Rango $rango', style: AppTheme.display(48)),
          const SizedBox(height: AppSpacing.dentro),
          // La meta real está pendiente: no se inventa un número de pasos.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cardBorder.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Meta en pasos pendiente de definir',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.entre),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Si cumplís los tres subís a rango ${rango < 4 ? rango + 1 : 4}. '
              'Si no, bajás a rango ${rango > 1 ? rango - 1 : 1}.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.entre),
          // Historial: una casilla por semana, llena si se cumplió.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final semana in historial)
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: semana.completado
                        ? AppColors.accentSecondary
                        : AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
