import 'package:flutter/material.dart';

// ============================================================
// LA CURVA DEL CAMINO.
//
// Estas tres funciones son lo único que sabe trazar la cinta que une los
// nodos del camino de las semanas.
//
// Acá NO hay widgets ni colores de marca: son solo curva, pincel y
// crecimiento. Quién es azul y quién es pálido lo decide la pantalla.
// ============================================================

/// Un arco suave entre dos puntos.
///
/// Los dos puntos de control salen del MISMO lado del tramo, así que el
/// trazo se comba entero hacia ese lado en vez de cruzar de uno al otro.
/// Eso es lo que deja encadenar tramos —uno combado hacia arriba, el
/// siguiente hacia abajo— y que el camino se lea como una onda larga y
/// no como un zigzag.
///
/// [amplitud] es cuánto se comba, como fracción del largo del tramo, y
/// su SIGNO dice para qué lado: positivo hacia la perpendicular de
/// avance, negativo hacia el otro. [reparto] es qué tan cerca de las
/// puntas caen los controles: cuanto más chico, más pronto arranca la
/// curva y más de costado sale el trazo del nodo. Eso último importa en
/// el giro de fila, que tiene que esquivar lo que hay debajo del nodo.
Path curvaArco(
  Offset a,
  Offset b, {
  double amplitud = 0.12,
  double reparto = 0.3,
}) {
  final d = b - a;
  final largo = d.distance;
  final trazo = Path()..moveTo(a.dx, a.dy);
  if (largo < 0.5) return trazo;

  final perpendicular = Offset(-d.dy, d.dx) / largo;
  final amp = largo * amplitud;

  return trazo..cubicTo(
    a.dx + d.dx * reparto + perpendicular.dx * amp,
    a.dy + d.dy * reparto + perpendicular.dy * amp,
    a.dx + d.dx * (1 - reparto) + perpendicular.dx * amp,
    a.dy + d.dy * (1 - reparto) + perpendicular.dy * amp,
    b.dx,
    b.dy,
  );
}

/// El pincel del camino: trazo redondeado, sin relleno.
Paint pincelCurva(Color color, double grosor) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = grosor
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Dibuja solo la primera fracción [t] de [trazo], para que crezca.
///
/// Con [t] en 1 dibuja el trazo entero por el camino corto, sin medirlo:
/// medir un Path no es gratis y en el estado final no hace falta.
void trazarCurva(Canvas lienzo, Path trazo, Paint pincel, double t) {
  if (t <= 0) return;
  if (t >= 1) {
    lienzo.drawPath(trazo, pincel);
    return;
  }
  for (final medida in trazo.computeMetrics()) {
    lienzo.drawPath(medida.extractPath(0, medida.length * t), pincel);
  }
}
