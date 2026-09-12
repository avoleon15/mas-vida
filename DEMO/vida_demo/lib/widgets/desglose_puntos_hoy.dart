import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../datos/modelos.dart';
import '../theme.dart';
import 'progress_ring.dart';

/// Tarjeta de los puntos de hoy, con el desglose plegable de dónde sale
/// la cifra.
///
/// Cerrada muestra el número grande y ya. Abierta explica las dos vías
/// que dan puntos en el día: los pasos (tabla escalonada) y la intensidad
/// del workout (matriz de duración x % de FCM).
///
/// Todos los números vienen ya calculados por el servidor en
/// [DiaActividad]: acá no se recalcula nada.
class DesglosePuntosHoy extends StatefulWidget {
  const DesglosePuntosHoy({super.key, required this.dia});

  final DiaActividad dia;

  @override
  State<DesglosePuntosHoy> createState() => _DesglosePuntosHoyState();
}

class _DesglosePuntosHoyState extends State<DesglosePuntosHoy> {
  bool _abierta = false;

  void _alternar() {
    // La háptica va en el momento causal: cuando la tarjeta se abre, no
    // cuando termina la animación.
    HapticFeedback.selectionClick();
    setState(() => _abierta = !_abierta);
  }

  @override
  Widget build(BuildContext context) {
    final dia = widget.dia;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // Degradado muy suave hacia el naranja de marca. Es la excepción
        // a la regla de que el naranja va solo en detalles chicos: acá
        // entra tan diluido (12% sobre blanco) que funciona como un tinte
        // de papel, no como un relleno naranja.
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
          // Toda la cabecera es tocable, no solo el botón: es un blanco
          // mucho más grande y no hay que apuntarle fino al chevron.
          _CabeceraPresionable(
            onTap: _alternar,
            abierta: _abierta,
            puntos: dia.puntosDia,
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: _abierta
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _Detalle(dia: dia),
          ),
        ],
      ),
    );
  }
}

class _CabeceraPresionable extends StatefulWidget {
  const _CabeceraPresionable({
    required this.onTap,
    required this.abierta,
    required this.puntos,
  });

  final VoidCallback onTap;
  final bool abierta;
  final int puntos;

  @override
  State<_CabeceraPresionable> createState() => _CabeceraPresionableState();
}

class _CabeceraPresionableState extends State<_CabeceraPresionable> {
  bool _presionada = false;

  void _marcar(bool v) {
    if (_presionada != v) setState(() => _presionada = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // El hundido responde en el instante del press, no al soltar.
      onTapDown: (_) => _marcar(true),
      onTapUp: (_) => _marcar(false),
      onTapCancel: () => _marcar(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _presionada ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Medalla del ícono: le da un ancla visual al número.
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.azulBruma,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt,
                  color: AppColors.accent,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.entre),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.puntos}', style: AppTheme.display(52)),
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
              // El chevron gira al abrir: dice hacia dónde va la tarjeta
              // antes de que termine de abrirse.
              AnimatedRotation(
                turns: widget.abierta ? 0.5 : 0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
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
              titulo: 'Workout',
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
