import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/modelos.dart';
import '../hora_guatemala.dart';
import '../screens/semanas_temporada_screen.dart';
import '../theme.dart';

// ============================================================
// LA TEMPORADA EN HOY.
//
// El BOTÓN de las semanas, arriba de la semana en curso: "Semana 3 de
// 13" en grande y "Ver las 13 semanas" debajo. Es lo único levantado del
// bloque. Abre la pantalla con una card por semana, que se recorre
// deslizando.
//
// El renglón "Tus monedas vencen el…" se sacó de Hoy (pedido de Daniel,
// 2 de octubre de 2026). El saldo va al lado del título del bloque.
//
// POCO TEXTO (pedido de Daniel, 2 de octubre de 2026). La marca de la
// semana no va acá: tiene su carrusel con el premio, debajo de los
// objetivos.
// ============================================================

/// "13 de diciembre", en hora de Guatemala.
String fechaLargaTemporada(DateTime fecha) => diaYMes(fecha);

/// Llave del botón que abre las semanas, para los tests.
const Key llaveBotonSemanas = ValueKey('ver-semanas-temporada');

/// El botón que abre las semanas de la temporada.
///
/// Dice además en qué semana vas, así que no hace falta entrar para
/// saberlo. CupertinoButton y no un GestureDetector: trae gratis el
/// atenuado al presionar que un usuario de iPhone ya conoce.
class BotonVerSemanas extends StatelessWidget {
  const BotonVerSemanas({super.key, required this.objetivos});

  final ObjetivosSemana objetivos;

  @override
  Widget build(BuildContext context) {
    final total = objetivos.semanas.length;
    final enCurso = objetivos.enCurso;

    return Semantics(
      button: true,
      label: [
        if (enCurso != null) 'Semana ${enCurso.numero} de $total',
        'Ver las $total semanas',
      ].join('. '),
      excludeSemantics: true,
      child: CupertinoButton(
        key: llaveBotonSemanas,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        onPressed: () {
          HapticFeedback.selectionClick();
          abrirSemanasDeLaTemporada(context, objetivos);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadios.tarjeta),
            // Un degradado apenas perceptible: es lo que lo hace verse
            // como una pieza con volumen y no como un rectángulo pintado.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(AppColors.accent, AppColors.azulMedio, 0.22)!,
                AppColors.accent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: enCurso == null
                            ? '$total semanas'
                            : 'Semana ${enCurso.numero}',
                        children: [
                          if (enCurso != null)
                            TextSpan(
                              text: ' de $total',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.display(
                        24,
                      ).copyWith(color: Colors.white, height: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ver las $total semanas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(
                  CupertinoIcons.arrow_right,
                  size: 19,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
