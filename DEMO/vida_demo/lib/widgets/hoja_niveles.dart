import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/fuente_datos.dart';
import '../reglas_puntos.dart';
import '../theme.dart';
import 'escalera_cashback.dart';
import 'numero_animado.dart' show milesConComa;

// ============================================================
// LA HOJA DE NIVELES.
//
// Los puntos del año, el nivel en el que caen y la escalera completa de
// cashback — la misma que vivía en Hoy, tal cual.
//
// POR QUÉ SE MUDÓ ACÁ (decisión de Daniel, 22 de septiembre de 2026).
// Estaba siempre abierta en Hoy, debajo del anillo de pasos: una
// gráfica de cinco barras que el usuario ya conoce de memoria a la
// segunda semana, ocupando media pantalla todos los días para contestar
// una pregunta que se hace una vez por mes. Hoy quedó con el dato —los
// puntos, el nivel y cuánto falta— y la gráfica pasó a abrirse cuando se
// pregunta por ella: tocando el medallón del nivel en Mi Plan.
//
// Es el mismo movimiento que ya hizo el resto de la app: las reglas de
// la liga se fueron a una hoja, el historial de monedas también. Lo que
// se consulta a veces no vive a la vista siempre.
// ============================================================

/// Abre la hoja con la escalera de niveles.
void mostrarHojaNiveles(BuildContext context) {
  HapticFeedback.selectionClick();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
    builder: (_) => const _HojaNiveles(),
  );
}

class _HojaNiveles extends StatelessWidget {
  const _HojaNiveles();

  @override
  Widget build(BuildContext context) {
    final resumen = Datos.i.resumen;
    final puntos = resumen.puntosAno;
    final nivel = resumen.nivel;

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
            // para abajo sin escribirlo.
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PUNTOS ACUMULADOS ${resumen.anio}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              milesConComa(puntos),
                              style: AppTheme.display(52),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.entre),
                        Expanded(child: PastillaNivel(nivel: nivel)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.dentro),
                    AvanceAlSiguienteNivel(
                      puntosTotal: puntos,
                      nivelActual: nivel,
                    ),
                    const SizedBox(height: AppSpacing.grupo),
                    // La escalera es interactiva: toda la explicación de
                    // los niveles vive adentro, un renglón a la vez, en
                    // vez de tres párrafos fijos.
                    EscaleraCashback(
                      nivelActual: nivel,
                      puntosTotal: puntos,
                      techoActividad: resumen.techoAnual,
                    ),
                    const SizedBox(height: AppSpacing.entre),
                    Text(
                      // La nota regulatoria viaja con cualquier pantalla
                      // que hable de cashback: se devuelve como dinero
                      // DESPUÉS del pago de la prima, nunca como
                      // descuento (Superintendencia de Bancos).
                      'Tu cashback se devuelve como dinero, después del pago '
                      'de tu prima. Nunca se descuenta de tu póliza.',
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

// ============================================================
// Piezas que comparten Hoy y esta hoja.
//
// Vivían adentro de `home_screen.dart` cuando la escalera vivía ahí.
// Ahora las usan las dos pantallas, así que viven en el medio: dos
// copias de la misma pastilla se despegan a la primera corrección.
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

  /// El nivel de arriba, o null si ya está en el último.
  Nivel? _siguienteNivel() => nivelPorNumero(nivelActual + 1);

  @override
  Widget build(BuildContext context) {
    final siguiente = _siguienteNivel();
    final estiloApoyo = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    if (siguiente == null) {
      return Text('Estás en el nivel más alto de cashback', style: estiloApoyo);
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
