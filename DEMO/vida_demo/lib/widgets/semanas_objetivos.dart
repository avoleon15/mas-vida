import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/modelos.dart';
import '../screens/camino_semanas_screen.dart';
import '../theme.dart';
import 'tarjeta_semana.dart';

// ============================================================
// "OBJETIVOS DE LA SEMANA" EN HOY.
//
// Es la tarjeta de la semana en curso y un enlace al camino completo. Y
// nada más.
//
// Lo que había antes era un tallo dibujado: tres nodos, tres brotes que
// crecían con el avance, y una curva pintada a mano. Se veía bien pero
// no decía lo que hay que hacer — los objetivos no tenían el nombre a la
// vista, y para leerlos había que tocar un brote y abrir un action
// sheet. Un dato que cabe en la tarjeta no puede costar dos taps.
//
// El recorrido de las diez semanas tampoco vive acá: es material de
// consulta y tiene su propia pantalla.
// ============================================================

class SemanasObjetivos extends StatelessWidget {
  const SemanasObjetivos({super.key, required this.objetivos});

  final ObjetivosSemana objetivos;

  /// La semana sobre la que el usuario todavía puede hacer algo. Si ya
  /// cerraron todas, la última.
  PasoDelPrograma? get _paso {
    final recorrido = objetivos.recorrido;
    if (recorrido.isEmpty) return null;

    for (final p in recorrido) {
      if (p.semana.estado == EstadoSemana.enCurso) return p;
    }
    for (final p in recorrido.reversed) {
      if (p.semana.estado == EstadoSemana.cerrada) return p;
    }
    return recorrido.first;
  }

  @override
  Widget build(BuildContext context) {
    final paso = _paso;
    if (paso == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ARRIBA de la tarjeta, no abajo. Debajo quedaba después de la
        // franja azul del pie y se leía como un pie de página más: nadie
        // llegaba hasta ahí. Acá es lo primero que se ve de la sección y
        // funciona como entrada al recorrido.
        _BotonRecorrido(
          totalSemanas: objetivos.semanas.length,
          onPressed: () {
            HapticFeedback.selectionClick();
            abrirCaminoDeSemanas(context, objetivos);
          },
        ),
        const SizedBox(height: AppSpacing.dentro),
        TarjetaSemana(
          paso: paso,
          rangoActual: objetivos.rangoActual,
          totalSemanas: objetivos.semanas.length,
          numeroSiguiente: objetivos.numeroDespuesDe(paso.semana.numero),
        ),
      ],
    );
  }
}

/// La entrada al camino de las semanas.
///
/// Es una barra con fondo y no un texto azul suelto: un enlace de texto
/// al lado de una tarjeta blanca con borde se pierde, y este es el único
/// camino hacia el recorrido completo. Con relleno propio se lee como
/// algo en lo que se puede tocar antes de leer qué dice.
class _BotonRecorrido extends StatelessWidget {
  const _BotonRecorrido({required this.totalSemanas, required this.onPressed});

  final int totalSemanas;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // CupertinoButton y no un GestureDetector: trae gratis el atenuado al
    // presionar que un usuario de iPhone ya conoce.
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          // azulBruma: es el relleno de "seleccionable" de la app. No va
          // en `accent` entero porque no es la acción principal de la
          // pantalla — la principal es cumplir los objetivos de abajo.
          color: AppColors.azulBruma,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.route_rounded, size: 19, color: AppColors.accent),
            const SizedBox(width: 10),
            // Expanded: con el tamaño de letra de iOS al máximo este
            // renglón ya no entra de una línea. Así envuelve en vez de
            // empujar la fila fuera del borde — hay un test a 1.6x.
            Expanded(
              child: Text(
                'Ver las $totalSemanas semanas',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}
