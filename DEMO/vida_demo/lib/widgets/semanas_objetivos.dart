import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../hora_guatemala.dart';
import '../theme.dart';
import 'pase_temporada.dart';
import 'premio_semana.dart';
import 'tarjeta_semana.dart';

// ============================================================
// "ESTA SEMANA" EN HOY.
//
// De arriba abajo:
//
//   1. el botón "Semana 3 de 13 · Ver las 13 semanas", que abre una
//      card por semana para deslizar de lado (pedido de Daniel, 2 de
//      octubre de 2026)
//   2. la semana en curso, con sus dos objetivos desplegados
//   3. si una marca compró la semana, un renglón chico con el premio,
//      PEGADO al segundo objetivo. El carrusel con la foto vive en la
//      card de la semana
//   4. el plazo: "Esta semana termina el domingo 4 de octubre a las
//      11:59 PM"
//
// El saldo de monedas ya no va en Hoy (pedido de Daniel, 2 de octubre
// de 2026): vive en la pantalla de la temporada, al lado del título.
// ============================================================

/// Cuántos días faltan para que cierre [temporada] y se reinicien las
/// monedas, si faltan 7 o menos; si no, null.
///
/// El aviso de fin de temporada (contrato, "Monedas y seasons"): 7 días
/// antes se avisa que el saldo vuelve a cero. El cierre lo manda el
/// servidor; acá solo se cuentan los días que faltan para avisar.
int? diasParaReiniciarMonedas(Temporada? temporada, {DateTime? ahora}) {
  if (temporada == null) return null;
  final hoy = enHoraDeGuatemala(ahora ?? DateTime.now());
  final cierre = enHoraDeGuatemala(temporada.cierra);
  final dias = DateTime(
    cierre.year,
    cierre.month,
    cierre.day,
  ).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
  return dias >= 0 && dias <= 7 ? dias : null;
}

/// Llave del aviso de fin de temporada, para los tests.
const Key llaveAvisoFinTemporada = ValueKey('aviso-fin-temporada');

class SemanasObjetivos extends StatelessWidget {
  const SemanasObjetivos({super.key, required this.objetivos, this.ahora});

  final ObjetivosSemana objetivos;

  /// El "ahora" para el aviso de fin de temporada. Solo lo pasan los
  /// tests; la app usa la hora real.
  final DateTime? ahora;

  /// La semana sobre la que el usuario todavía puede hacer algo. Si ya
  /// cerraron todas, la última cerrada.
  SemanaObjetivos? get _semana {
    final semanas = objetivos.semanas;
    if (semanas.isEmpty) return null;

    return objetivos.enCurso ??
        semanas.lastWhere(
          (s) => s.estado == EstadoSemana.cerrada,
          orElse: () => semanas.first,
        );
  }

  @override
  Widget build(BuildContext context) {
    final semana = _semana;
    if (semana == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BotonVerSemanas(objetivos: objetivos),
        if (diasParaReiniciarMonedas(objetivos.temporada, ahora: ahora)
            case final dias?) ...[
          const SizedBox(height: AppSpacing.entre),
          _AvisoFinTemporada(dias: dias, cierre: objetivos.temporada!.cierra),
        ],
        const SizedBox(height: AppSpacing.grupo),
        TarjetaSemana(
          semana: semana,
          conTitulo: false,
          // Pegado al segundo objetivo, antes del plazo.
          debajoDeLosObjetivos: semana.patrocinio == null
              ? null
              : PremioSemanaChico(semana: semana),
        ),
      ],
    );
  }
}

/// "Tus monedas se reinician en 3 días": en naranja, porque es una alerta
/// real —lo que no se gaste se pierde— y es uno de los usos del naranja.
class _AvisoFinTemporada extends StatelessWidget {
  const _AvisoFinTemporada({required this.dias, required this.cierre});

  final int dias;
  final DateTime cierre;

  @override
  Widget build(BuildContext context) {
    final cuando = switch (dias) {
      0 => 'hoy a las 11:59 PM',
      1 => 'mañana',
      _ => 'en $dias días',
    };
    return Semantics(
      key: llaveAvisoFinTemporada,
      label:
          'Tus monedas se reinician $cuando, el ${fechaConDia(cierre)}. '
          'Úsalas antes en Premios.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.accentSecondary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              size: 20,
              color: AppColors.accentSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Tus monedas se reinician $cuando. ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: 'Úsalas antes en Premios.'),
                  ],
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
