import 'package:flutter/material.dart';
import '../datos/modelos.dart';
import '../theme.dart';
import 'progress_ring.dart';

/// Tarjeta de los puntos de hoy, con el desglose de dónde sale la cifra.
///
/// EL DESGLOSE SE VE SIEMPRE (reunión del 2 de octubre de 2026). Antes
/// era plegable y cerrado mostraba solo el número: había que tocar para
/// saber de dónde salían los puntos, y es justo lo que la persona quiere
/// entender al mirar el número. Ahora explica de una las dos vías que
/// dan puntos en el día: los pasos (tabla escalonada) y la intensidad
/// del workout (matriz de duración x % de FCM).
///
/// Todos los números vienen ya calculados por el servidor en
/// [DiaActividad]: acá no se recalcula nada.
class DesglosePuntosHoy extends StatelessWidget {
  const DesglosePuntosHoy({super.key, required this.dia});

  final DiaActividad dia;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // Degradado muy suave hacia el azul de marca: entra tan diluido
        // que funciona como un tinte de papel, no como un relleno.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card,
            Color.lerp(AppColors.accent, AppColors.card, 0.93)!,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          // Sombra suave azulada, nunca un glow: sobre fondo claro un
          // brillo saturado se ve mal (ver CLAUDE.md).
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _Cabecera(puntos: dia.puntosDia),
          _Detalle(dia: dia),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.puntos});

  final int puntos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Medalla del ícono: le da un ancla visual al número.
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.azulBruma,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt, color: AppColors.accent, size: 28),
          ),
          const SizedBox(width: AppSpacing.entre),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$puntos', style: AppTheme.display(52)),
                Text(
                  'PUNTOS HOY',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
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

class _Detalle extends StatelessWidget {
  const _Detalle({required this.dia});

  final DiaActividad dia;

  @override
  Widget build(BuildContext context) {
    final sesion = dia.sesion;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: AppSpacing.entre),

          // Vía 1: pasos.
          _Fila(
            icono: Icons.directions_walk,
            titulo: 'Pasos',
            detalle: dia.pasos == null
                ? 'Sin permiso para leer tu actividad'
                : '${TextoCentroAnillo.formatearMiles(dia.pasos!)} pasos',
            puntos: dia.puntosPasos,
          ),
          const SizedBox(height: AppSpacing.entre),

          // Vía 2: intensidad del workout.
          if (sesion == null)
            const _Fila(
              icono: Icons.favorite_border,
              titulo: 'Entrenamiento',
              detalle: 'Hoy no registraste ninguno',
              puntos: 0,
            )
          else
            _Fila(
              icono: Icons.favorite_border,
              titulo: sesion.tipoActividad,
              detalle: sesion.cuentaParaPuntos
                  ? '${sesion.duracionMin} min al ${sesion.porcentajeFcm}% '
                        'de tu ritmo máximo'
                  : '${sesion.duracionMin} min · no llegó a los 30 min '
                        'continuos, no acredita',
              puntos: sesion.cuentaParaPuntos ? dia.puntosIntensidad : 0,
            ),

          // Si el día pegó contra el techo hay que decirlo: si no, el
          // total no cuadra con la suma de las filas de arriba.
          if (dia.topeAplicado) ...[
            const SizedBox(height: AppSpacing.entre),
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.dentro),
                Expanded(
                  child: Text(
                    'Sumaste ${dia.puntosBrutos} puntos, pero el máximo por '
                    'día es ${dia.puntosDia}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.puntos,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final int puntos;

  @override
  Widget build(BuildContext context) {
    // Una fila sin puntos se muestra apagada: comunica "esto no te sumó"
    // sin necesitar una etiqueta que lo diga.
    final activa = puntos > 0;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: activa
                ? AppColors.azulBruma
                : AppColors.cardBorder.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icono,
            size: 20,
            color: activa ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.entre),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                detalle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Text(
          '+$puntos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: activa ? AppColors.accent : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
