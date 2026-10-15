import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/reglas_puntos.dart';

/// Tabla anual de cashback confirmada:
///   0: 0–2,499 = 0%   1: 2,500–4,999 = 5%   2: 5,000–9,999 = 7,5%
///   3: 10,000–14,999 = 10%   4: 15,000+ = 20%
///
/// El piso del nivel 4 es 15.000 (confirmado por Alvaro el 19 de
/// septiembre de 2026), por encima del techo de actividad de 12.000: en
/// el piloto el nivel 4 no se alcanza. Es una consecuencia aceptada.
void main() {
  /// El nivel de un acumulado, leído de la tabla: el más alto cuyo piso
  /// se alcanza. La app no lo calcula (lo manda el servidor); acá sirve
  /// para fijar que la tabla no deja huecos.
  int nivelDe(int puntos) =>
      niveles.lastWhere((n) => puntos >= n.puntosMinimos!).numero;

  group('los bordes de la tabla', () {
    test('cada nivel arranca donde debe', () {
      expect(nivelDe(0), 0);
      expect(nivelDe(2499), 0);
      expect(nivelDe(2500), 1);
      expect(nivelDe(4999), 1);
      expect(nivelDe(5000), 2);
      expect(nivelDe(9999), 2);
      expect(nivelDe(10000), 3);
      expect(nivelDe(12000), 3);
      expect(nivelDe(14999), 3);
      expect(nivelDe(15000), 4);
      expect(nivelDe(99999), 4);
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
      // El 15.000 del nivel 4 es el tope para dibujar la escalera, no un
      // limite: nivelParaPuntos no deja a nadie sin nivel por arriba.
      expect(nivelDe(niveles.last.puntosMaximos! + 5000), 4);
    });

    test('el nivel 4 se lee "15,000+", no "15,000 – 15,000"', () {
      expect(nivelPorNumero(4)!.rangoTexto, '15,000+ pts');
    });

    test('el nivel 4 queda fuera de alcance en el piloto', () {
      // Consecuencia aceptada, no un bug: NO se arregla subiendo el techo
      // ni bajando el piso. Si este test falla, alguien volvio a tocar
      // una de las dos cifras.
      expect(nivelPorNumero(4)!.puntosMinimos!, greaterThan(techoAnual));
      expect(nivelDe(techoAnual), 3);
      expect(nivelAlcanzable(nivelPorNumero(4)!), isFalse);
      expect(nivelAlcanzable(nivelPorNumero(3)!), isTrue);
    });

    test('al nivel 3 no se le ofrece un nivel siguiente', () {
      // Decirle "te faltan 3,760 pts" para un nivel al que caminando no
      // llega seria prometer algo que no existe.
      expect(siguienteNivelAlcanzable(2)?.numero, 3);
      expect(siguienteNivelAlcanzable(3), isNull);
      expect(siguienteNivelAlcanzable(4), isNull);
    });
  });
}
