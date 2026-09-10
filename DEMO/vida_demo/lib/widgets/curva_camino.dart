import 'package:flutter/material.dart';

// ============================================================
// LA CURVA DEL CAMINO.
//
// Estas tres funciones son lo único que sabe trazar la curva que une los
// nodos del camino de las semanas.
//
// Acá NO hay widgets ni colores de marca: son solo curva, pincel y
// crecimiento. Quién es azul y quién es pálido lo decide la pantalla.
// ============================================================

/// Una curva suave entre dos puntos.
///
/// Los puntos de control salen perpendiculares al vector entre las dos
/// anclas, uno para cada lado: así serpentea sola, sin números mágicos
/// que haya que reajustar cuando cambia el tamaño de la caja. Es lo que
/// hace que el camino no sea una línea recta.
///
/// [amplitud] es cuánto se curva, como fracción del largo del tramo.
Path curvaTallo(Offset a, Offset b, {double amplitud = 0.17}) {
  final d = b - a;
  final largo = d.distance;
  final trazo = Path()..moveTo(a.dx, a.dy);
  if (largo < 0.5) return trazo;

  final perpendicular = Offset(-d.dy, d.dx) / largo;
  final amp = largo * amplitud;

  return trazo..cubicTo(
    a.dx + d.dx * 0.35 + perpendicular.dx * amp,
    a.dy + d.dy * 0.35 + perpendicular.dy * amp,
    a.dx + d.dx * 0.65 - perpendicular.dx * amp,
    a.dy + d.dy * 0.65 - perpendicular.dy * amp,
    b.dx,
    b.dy,
  );
}

/// El pincel del camino: trazo redondeado, sin relleno.
Paint pincelCurva(Color color, double grosor) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = grosor
  ..strokeCap = StrokeCap.round;

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
