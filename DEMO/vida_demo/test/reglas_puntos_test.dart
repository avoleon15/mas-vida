import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/reglas_puntos.dart';

// Las tablas que la app dibuja (tramos de pasos y niveles), contra el
// contrato v1. Los puntos los calcula el servidor: acá solo se fija que
// lo que se le MUESTRA al usuario diga las mismas reglas.

void main() {
  group('Puntos por pasos', () {
    test('por debajo del piso de 7.000 no acredita nada', () {
      expect(puntosPorPasos(0), 0);
      expect(puntosPorPasos(6999), 0);
    });

    test('7.000 exactos acreditan 25 pts', () {
      expect(puntosPorPasos(7000), 25);
    });

    test('el escalón de 25 llega hasta antes de 10.000', () {
      expect(puntosPorPasos(9999), 25);
    });

    test('de 10.000 a 15.000 acredita 50 pts', () {
      expect(puntosPorPasos(10000), 50);
      expect(puntosPorPasos(12400), 50);
      expect(puntosPorPasos(14999), 50);
    });

    test('desde 15.000 acredita 100 pts', () {
      expect(puntosPorPasos(15000), 100);
      expect(puntosPorPasos(23000), 100);
    });

    test('caminar más de 15.000 no da puntos adicionales', () {
      expect(puntosPorPasos(23000), puntosPorPasos(46000));
    });
  });

  group('Niveles', () {
    // La tabla completa y sus bordes viven en niveles_cashback_test.dart.
    test('los cinco niveles están definidos', () {
      for (var i = 0; i <= 4; i++) {
        expect(nivelPorNumero(i)!.definido, isTrue, reason: 'nivel $i');
      }
    });

    test('nivel 3 va de 10.000 a 14.999 con 10% de cashback', () {
      final n = nivelPorNumero(3)!;
      expect(n.puntosMinimos, 10000);
      expect(n.puntosMaximos, 14999);
      expect(n.porcentajeCashback, 10);
    });

    test('nivel 4 arranca en 15.000 con 20% de cashback', () {
      final n = nivelPorNumero(4)!;
      expect(n.puntosMinimos, 15000);
      expect(n.porcentajeCashback, 20);
    });

    test('el techo de actividad deja al usuario en el nivel 3', () {
      // Con el chequeo fuera de v1, 12.000 es lo máximo del año: nivel 3,
      // 10% de cashback. El nivel 4 queda fuera de alcance en el piloto.
      expect(nivelPorNumero(3)!.puntosMinimos, lessThanOrEqualTo(techoAnual));
      expect(nivelPorNumero(4)!.puntosMinimos, greaterThan(techoAnual));
    });
  });
}
