import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/widgets/semanas_objetivos.dart';

import 'ayudas.dart';

/// El aviso de fin de temporada (contrato, "Monedas y seasons"): 7 días
/// antes de que cierre se avisa que las monedas vuelven a cero.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  // La temporada 4 de 2026 cierra el domingo 3 de enero de 2027, 23:59.
  final temporada = Temporada(
    numero: 4,
    inicia: DateTime.parse('2026-09-28T00:00:00-06:00'),
    cierra: DateTime.parse('2027-01-03T23:59:59-06:00'),
  );

  test('faltando más de 7 días no avisa', () {
    final viernes2 = DateTime.parse('2026-10-02T12:00:00-06:00');
    expect(diasParaReiniciarMonedas(temporada, ahora: viernes2), isNull);
  });

  test('7 días antes empieza a avisar, y cuenta en hora de Guatemala', () {
    final domingo27 = DateTime.parse('2026-12-27T08:00:00-06:00');
    expect(diasParaReiniciarMonedas(temporada, ahora: domingo27), 7);
    // 23:30 del 2 de enero en Guatemala ya es 3 de enero en UTC: igual
    // falta un día.
    final sabado2Noche = DateTime.parse('2027-01-02T23:30:00-06:00');
    expect(diasParaReiniciarMonedas(temporada, ahora: sabado2Noche), 1);
  });

  testWidgets('en Hoy se ve arriba de los objetivos', (t) async {
    final o = Datos.i.resumen.objetivosSemana;
    await montarPantalla(
      t,
      Scaffold(
        body: SingleChildScrollView(
          child: SemanasObjetivos(
            objetivos: o,
            ahora: o.temporada!.cierra.subtract(const Duration(days: 3)),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.byKey(llaveAvisoFinTemporada), findsOneWidget);
  });

  testWidgets('con el mock de hoy no aparece', (t) async {
    await montarPantalla(
      t,
      Scaffold(
        body: SingleChildScrollView(
          child: SemanasObjetivos(
            objetivos: Datos.i.resumen.objetivosSemana,
            ahora: DateTime.parse('2026-10-02T12:00:00-06:00'),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.byKey(llaveAvisoFinTemporada), findsNothing);
  });
}
