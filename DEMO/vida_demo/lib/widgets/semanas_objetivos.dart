import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../datos/modelos.dart';
import '../theme.dart';

/// Las semanas del mes, cada una plegable, con sus 3 objetivos adentro.
///
/// Una semana cerrada muestra lo que pasó; la que está en curso arranca
/// abierta, porque es la única sobre la que el usuario todavía puede
/// hacer algo; las futuras van cerradas y apagadas.
///
/// Un mes puede tener 5 semanas: acá se renderizan las que vengan, no se
/// asume que sean cuatro.
class SemanasObjetivos extends StatelessWidget {
  const SemanasObjetivos({super.key, required this.semanas});

  final List<SemanaObjetivos> semanas;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < semanas.length; i++) ...[
          _TarjetaSemana(semana: semanas[i]),
          if (i != semanas.length - 1)
            const SizedBox(height: AppSpacing.dentro),
        ],
      ],
    );
  }
}

class _TarjetaSemana extends StatefulWidget {
  const _TarjetaSemana({required this.semana});

  final SemanaObjetivos semana;

  @override
  State<_TarjetaSemana> createState() => _TarjetaSemanaState();
}

class _TarjetaSemanaState extends State<_TarjetaSemana> {
  late bool _abierta = widget.semana.estado == EstadoSemana.enCurso;

  void _alternar() {
    // Háptica en el momento causal: cuando se abre, no al terminar la
    // animación.
    HapticFeedback.selectionClick();
    setState(() => _abierta = !_abierta);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.semana;
    final enCurso = s.estado == EstadoSemana.enCurso;
    final futura = s.estado == EstadoSemana.futura;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: futura
            ? AppColors.cardBorder.withValues(alpha: 0.25)
            : AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          // El borde grueso marca la semana sobre la que todavía se puede
          // hacer algo.
          color: enCurso ? AppColors.accent : AppColors.cardBorder,
          width: enCurso ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          _Cabecera(semana: s, abierta: _abierta, onTap: _alternar),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: _abierta
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _Detalle(semana: s),
          ),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.semana,
    required this.abierta,
    required this.onTap,
  });

  final SemanaObjetivos semana;
  final bool abierta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final futura = semana.estado == EstadoSemana.futura;
    final cerrada = semana.estado == EstadoSemana.cerrada;

    return GestureDetector(
      // Toda la cabecera es tocable, no solo el chevron: es un blanco
      // mucho más grande.
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.entre),
        child: Row(
          children: [
            _Insignia(semana: semana),
            const SizedBox(width: AppSpacing.dentro),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semana ${semana.numero}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: futura
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _resumen(semana),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Las monedas ya acuñadas de esa semana. Nunca puntos.
            if (!futura && semana.monedasGanadas > 0) ...[
              _ChipMonedas(cantidad: semana.monedasGanadas, apagado: cerrada),
              const SizedBox(width: AppSpacing.dentro),
            ],
            AnimatedRotation(
              turns: abierta ? 0.5 : 0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// El renglón chico de abajo del título: qué pasó (o qué está pasando)
  /// esa semana.
  static String _resumen(SemanaObjetivos s) {
    final total = s.objetivos.length;
    return switch (s.estado) {
      EstadoSemana.futura => 'Todavía no empieza',
      // Cumplir los tres es lo único que sube de rango: se dice explícito
      // para que la regla se aprenda mirando el historial.
      EstadoSemana.cerrada =>
        s.subioDeRango
            ? '$total de $total · subiste de rango'
            : '${s.cumplidos} de $total · no subiste de rango',
      EstadoSemana.enCurso => '${s.cumplidos} de $total cumplidos',
    };
  }
}

/// El círculo de la izquierda. Carga el estado en el ícono, no solo en el
/// color: así se distingue también en blanco y negro.
class _Insignia extends StatelessWidget {
  const _Insignia({required this.semana});

  final SemanaObjetivos semana;

  @override
  Widget build(BuildContext context) {
    final (fondo, icono, colorIcono) = switch (semana.estado) {
      EstadoSemana.cerrada when semana.subioDeRango => (
        AppColors.accentSecondary,
        Icons.check_rounded,
        Colors.white,
      ),
      EstadoSemana.cerrada => (
        AppColors.cardBorder,
        Icons.remove_rounded,
        AppColors.textSecondary,
      ),
      EstadoSemana.enCurso => (
        AppColors.accent,
        Icons.play_arrow_rounded,
        Colors.white,
      ),
      EstadoSemana.futura => (
        AppColors.cardBorder.withValues(alpha: 0.7),
        Icons.lock_outline_rounded,
        AppColors.textSecondary,
      ),
    };

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
      child: Icon(icono, size: 19, color: colorIcono),
    );
  }
}

class _ChipMonedas extends StatelessWidget {
  const _ChipMonedas({required this.cantidad, required this.apagado});

  final int cantidad;
  final bool apagado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentSecondary.withValues(alpha: apagado ? 0.12 : 0.2),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on,
            size: 13,
            color: AppColors.accentSecondary,
          ),
          const SizedBox(width: 3),
          Text(
            '$cantidad',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.semana});

  final SemanaObjetivos semana;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.entre,
        0,
        AppSpacing.entre,
        AppSpacing.entre,
      ),
      child: Column(
        children: [
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: AppSpacing.entre),
          for (var i = 0; i < semana.objetivos.length; i++) ...[
            _FilaObjetivo(
              objetivo: semana.objetivos[i],
              apagado: semana.estado == EstadoSemana.futura,
            ),
            if (i != semana.objetivos.length - 1)
              const SizedBox(height: AppSpacing.entre),
          ],
          const SizedBox(height: AppSpacing.entre),
          Text(
            // La regla, dicha donde se aplica.
            'Los tres cumplidos suben un rango. Menos de tres, baja uno.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaObjetivo extends StatelessWidget {
  const _FilaObjetivo({required this.objetivo, required this.apagado});

  final ObjetivoSemanal objetivo;
  final bool apagado;

  @override
  Widget build(BuildContext context) {
    final avance = objetivo.avance;
    final hecho = objetivo.completo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              hecho
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 17,
              color: hecho
                  ? AppColors.accentSecondary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                objetivo.nombre,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: apagado
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _ChipMonedas(cantidad: objetivo.monedas, apagado: apagado || hecho),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            // Sin meta definida no hay avance que mostrar: la barra queda
            // vacía en vez de inventar una posición.
            value: avance ?? 0,
            minHeight: 5,
            backgroundColor: AppColors.cardBorder,
            valueColor: AlwaysStoppedAnimation(
              hecho ? AppColors.accentSecondary : AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          // La meta en número todavía no está definida en ninguna fuente,
          // así que se muestra el avance crudo y nunca un número
          // inventado. Cuando el servidor sí reporta qué tan lleno va, se
          // usa ese porcentaje en vez de repetir que falta la meta.
          _pie(objetivo),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// El renglón chico debajo de la barra.
  static String _pie(ObjetivoSemanal o) {
    final base = '${_miles(o.progreso)} ${o.unidad}';
    if (o.completo) return '$base · completado';
    // Con meta definida se dice contra qué se mide.
    final meta = o.meta;
    if (meta != null) return '${_miles(o.progreso)} de ${_miles(meta)} ${o.unidad}';
    // Sin meta pero con avance reportado por el servidor: el porcentaje
    // es cierto aunque el número de la meta no esté documentado acá.
    final avance = o.avance;
    if (avance != null && avance > 0) {
      return '$base · ${(avance * 100).round()}% del objetivo';
    }
    return '$base · meta pendiente de definir';
  }

  static String _miles(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
}
