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

    // Una sola pieza: la tarjeta de la semana, con el camino colgado de
    // su pie. El botón vivía acá afuera, arriba de la tarjeta, y quedaba
    // pegado al encabezado de la sección: dos renglones azules seguidos
    // que se leían como un mismo rótulo. Adentro de la tarjeta es
    // claramente otra cosa — el renglón que sigue a los objetivos.
    return TarjetaSemana(
      paso: paso,
      rangoActual: objetivos.rangoActual,
      totalSemanas: objetivos.semanas.length,
      onVerCamino: () => abrirCaminoDeSemanas(context, objetivos),
    );
  }
}
