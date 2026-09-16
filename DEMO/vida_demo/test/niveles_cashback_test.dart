import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/reglas_puntos.dart';

/// Tabla anual de cashback confirmada:
///   0: 0–2,499 = 0%   1: 2,500–4,999 = 5%   2: 5,000–9,999 = 7,5%
///   3: 10,000-11,999 = 10%   4: 12,000-15,000 = 20%
void main() {
  group('nivelParaPuntos', () {
    test('los bordes de cada nivel caen donde deben', () {
      expect(nivelParaPuntos(0), 0);
      expect(nivelParaPuntos(2499), 0);
      expect(nivelParaPuntos(2500), 1);
      expect(nivelParaPuntos(4999), 1);
      expect(nivelParaPuntos(5000), 2);
      expect(nivelParaPuntos(9999), 2);
      expect(nivelParaPuntos(10000), 3);
      expect(nivelParaPuntos(11999), 3);
      expect(nivelParaPuntos(12000), 4);
      expect(nivelParaPuntos(15000), 4);
      expect(nivelParaPuntos(99999), 4);
    });
  });

  group('tabla de niveles', () {
    test('no deja huecos ni traslapes entre un nivel y el siguiente', () {
      for (var i = 0; i < niveles.length - 1; i++) {
        expect(
          niveles[i].puntosMaximos! + 1,
          niveles[i + 1].puntosMinimos,
          reason: 'el nivel ${niveles[i].numero} no pega con el siguiente',
        );
      }
    });

    test('todos los niveles tienen rango y porcentaje definidos', () {
      for (final n in niveles) {
        expect(n.definido, isTrue, reason: 'nivel ${n.numero}');
      }
    });

    test('nadie cae fuera de la tabla por arriba del ultimo techo', () {
      // El nivel 4 tiene techo declarado (15.000), pero nivelParaPuntos
      // no debe dejar a nadie sin nivel si algun dia se pasa de ahi.
      expect(nivelParaPuntos(niveles.last.puntosMaximos! + 5000), 4);
    });

    test('el nivel 4 arranca donde topa la actividad fisica', () {
      // techoAnual topa SOLO los puntos por actividad. El nivel 4 empieza
      // justo ahi: de ese punto en adelante los puntos vienen de los
      // chequeos medicos. Si este test falla, el mensaje de la escalera
      // sobre los chequeos dejo de ser cierto.
      expect(niveles.last.puntosMinimos!, techoAnual);
    });
  });
}
