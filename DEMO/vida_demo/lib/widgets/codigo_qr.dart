import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

// ============================================================
// EL CÓDIGO DE UN CUPÓN.
//
// Una sola pieza para las dos pantallas donde se muestra: el canje
// exitoso y Premios › Mis cupones. Tiene que ser el MISMO dibujo en las
// dos, o el usuario duda de cuál es el bueno.
//
// OJO: todavía es un QR DE MUESTRA. `qr_flutter` no está en pubspec.yaml y
// el formato del código lo define el backend, así que se dibuja un patrón
// con la forma de un QR —los tres "ojos" en las esquinas y módulos
// sueltos— sacado del texto del código. Mismo código, mismo dibujo; dos
// cupones distintos, dos dibujos distintos. El día que haya QR real,
// cambia este archivo y nada más.
// ============================================================

class CodigoQr extends StatelessWidget {
  const CodigoQr({
    super.key,
    required this.codigo,
    this.tamano = 200,
    this.conMarco = true,
    this.apagado = false,
  });

  final String codigo;
  final double tamano;

  /// Las cuatro esquinas en azul de marca alrededor del código, como el
  /// visor de la cámara: dicen "esto se escanea" sin una palabra.
  final bool conMarco;

  /// Un cupón usado o vencido: el código se ve pero en gris, para que
  /// nadie lo muestre en caja.
  final bool apagado;

  @override
  Widget build(BuildContext context) {
    final qr = Container(
      padding: EdgeInsets.all(tamano * 0.06),
      color: Colors.white,
      child: SizedBox.square(
        dimension: tamano,
        child: CustomPaint(
          painter: _PatronQr(
            semilla: _semillaDe(codigo),
            color: apagado ? AppColors.azulSuave : AppColors.textPrimary,
          ),
        ),
      ),
    );

    return Semantics(
      label: 'Código del cupón $codigo',
      image: true,
      excludeSemantics: true,
      child: conMarco
          ? CustomPaint(
              foregroundPainter: const _Esquinas(),
              child: Padding(padding: EdgeInsets.all(tamano * 0.07), child: qr),
            )
          : qr,
    );
  }
}

/// Un número estable a partir del código (FNV-1a). No `hashCode`: en
/// Dart no está garantizado que dé lo mismo entre una ejecución y otra, y
/// el dibujo de un cupón no puede cambiar de un día para el siguiente.
int _semillaDe(String codigo) {
  var h = 0x811c9dc5;
  for (final c in codigo.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// El patrón: 21 × 21 módulos, que es el tamaño del QR más chico.
class _PatronQr extends CustomPainter {
  const _PatronQr({required this.semilla, required this.color});

  final int semilla;
  final Color color;

  static const int _modulos = 21;

  @override
  void paint(Canvas canvas, Size size) {
    final m = size.width / _modulos;
    final tinta = Paint()..color = color;
    final azar = Random(semilla);

    bool enOjo(int x, int y) {
      bool cerca(int ox, int oy) =>
          x >= ox - 1 && x <= ox + 7 && y >= oy - 1 && y <= oy + 7;
      return cerca(0, 0) || cerca(_modulos - 7, 0) || cerca(0, _modulos - 7);
    }

    for (var y = 0; y < _modulos; y++) {
      for (var x = 0; x < _modulos; x++) {
        if (enOjo(x, y) || !azar.nextBool()) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x * m, y * m, m, m).deflate(m * 0.06),
            Radius.circular(m * 0.25),
          ),
          tinta,
        );
      }
    }

    for (final o in [
      Offset.zero,
      Offset((_modulos - 7) * m, 0),
      Offset(0, (_modulos - 7) * m),
    ]) {
      _ojo(canvas, o, m, tinta);
    }
  }

  /// Un "ojo": anillo de 7 módulos con un cuadro de 3 al centro.
  void _ojo(Canvas canvas, Offset o, double m, Paint tinta) {
    final exterior = RRect.fromRectAndRadius(
      Rect.fromLTWH(o.dx, o.dy, m * 7, m * 7),
      Radius.circular(m * 1.6),
    );
    final interior = RRect.fromRectAndRadius(
      Rect.fromLTWH(o.dx + m, o.dy + m, m * 5, m * 5),
      Radius.circular(m * 1.1),
    );
    canvas.drawDRRect(exterior, interior, tinta);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx + m * 2, o.dy + m * 2, m * 3, m * 3),
        Radius.circular(m * 0.8),
      ),
      tinta,
    );
  }

  @override
  bool shouldRepaint(_PatronQr old) =>
      old.semilla != semilla || old.color != color;
}

/// Las cuatro esquinas del visor.
class _Esquinas extends CustomPainter {
  const _Esquinas();

  @override
  void paint(Canvas canvas, Size size) {
    final largo = size.width * 0.14;
    final pincel = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final r = size.width * 0.05;
    final w = size.width;
    final h = size.height;

    Path esquina(Offset a, Offset vertice, Offset b) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(
        vertice.dx + (a.dx - vertice.dx).sign * r,
        vertice.dy + (a.dy - vertice.dy).sign * r,
      )
      ..quadraticBezierTo(
        vertice.dx,
        vertice.dy,
        vertice.dx + (b.dx - vertice.dx).sign * r,
        vertice.dy + (b.dy - vertice.dy).sign * r,
      )
      ..lineTo(b.dx, b.dy);

    for (final p in [
      esquina(Offset(0, largo), Offset.zero, Offset(largo, 0)),
      esquina(Offset(w - largo, 0), Offset(w, 0), Offset(w, largo)),
      esquina(Offset(w, h - largo), Offset(w, h), Offset(w - largo, h)),
      esquina(Offset(largo, h), Offset(0, h), Offset(0, h - largo)),
    ]) {
      canvas.drawPath(p, pincel);
    }
  }

  @override
  bool shouldRepaint(_Esquinas old) => false;
}
