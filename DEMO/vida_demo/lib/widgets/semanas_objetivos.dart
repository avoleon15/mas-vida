import 'package:flutter/widgets.dart';

import '../datos/modelos.dart';
import '../screens/camino_semanas_screen.dart';
import 'tarjeta_semana.dart';

// ============================================================
// "OBJETIVOS DE LA SEMANA" EN HOY.
//
// Es la tarjeta de la semana en curso, con el camino colgado de su pie.
// Y nada más.
//
// Lo que había antes era un tallo dibujado: tres nodos, tres brotes que
// crecían con el avance, y una curva pintada a mano. Se veía bien pero
// no decía lo que hay que hacer — los objetivos no tenían el nombre a la
// vista, y para leerlos había que tocar un brote y abrir un action
// sheet. Un dato que cabe en la tarjeta no puede costar dos taps.
//
// El camino de las semanas tampoco vive acá: es material de
// consulta y tiene su propia pantalla.
// ============================================================

class SemanasObjetivos extends StatelessWidget {
  const SemanasObjetivos({super.key, required this.objetivos});

  final ObjetivosSemana objetivos;

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

    // Una sola pieza: la semana, con el camino colgado de su pie.
    return TarjetaSemana(
      semana: semana,
      totalSemanas: objetivos.semanas.length,
      onVerCamino: () => abrirCaminoDeSemanas(context, objetivos),
    );
  }
}
