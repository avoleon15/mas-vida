import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vida_demo/theme.dart';
import 'package:vida_demo/widgets/escalera_cashback.dart';

/// La escalera de cashback no debe desbordar con el texto del sistema en
/// grande. El "BOTTOM OVERFLOWED BY 2.0 PIXELS" salía de un alto fijo en
/// la fila de escalones.
void main() {
  setUpAll(() {
    // Sin esto el test se cuelga bajando fuentes por red.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> montar(WidgetTester tester, double escala) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(escala)),
          child: const TemaVida(
            child: Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: EscaleraCashback(
                  nivelActual: 3,
                  puntosTotal: 11240,
                  techoActividad: 12000,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final escala in [1.0, 1.5, 2.0, 3.0]) {
    testWidgets('no desborda con textScaler $escala', (tester) async {
      await montar(tester, escala);
      expect(tester.takeException(), isNull);
    });
  }

  group('barrido de brillo', () {
    // Alto de un escalon cualquiera de la escalera.
    const alto = 98.0;

    test('arranca fuera del escalon, por abajo', () {
      // y >= alto significa que el borde de arriba de la franja esta en el
      // piso del escalon o mas abajo: no se ve nada todavia.
      expect(desplazamientoBrillo(0, alto), greaterThanOrEqualTo(alto));
    });

    test('al terminar el barrido queda COMPLETAMENTE fuera, por arriba', () {
      // Este es el invariante que se rompio y se vio como un tiron: si la
      // franja termina adentro del escalon, se queda clavada ahi toda la
      // pausa y despues salta.
      final y = desplazamientoBrillo(0.55, alto);
      expect(y, lessThanOrEqualTo(-bandaAltoBrillo));
    });

    test('durante la pausa no vuelve a entrar', () {
      for (final reloj in [0.6, 0.75, 0.9, 1.0]) {
        expect(
          desplazamientoBrillo(reloj, alto),
          lessThanOrEqualTo(-bandaAltoBrillo),
          reason: 'reloj $reloj',
        );
      }
    });

    test('avanza siempre hacia arriba, sin retrocesos', () {
      var anterior = double.infinity;
      for (var i = 0; i <= 100; i++) {
        final y = desplazamientoBrillo(i / 100, alto);
        expect(y, lessThanOrEqualTo(anterior), reason: 'paso $i');
        anterior = y;
      }
    });
  });
}
