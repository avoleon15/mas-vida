import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/screens/semanas_temporada_screen.dart';
import 'package:vida_demo/widgets/patrocinio.dart';

import 'ayudas.dart';

// ============================================================
// LAS SEMANAS PATROCINADAS.
//
// Lo que hay que proteger:
//
//   · LA MARCA SE VE EN SU CARD, con su logo arriba.
//   · QUE NADA ANUNCIE UNA AUSENCIA: sin patrocinador la card no lleva
//     logo ni cartel.
//   · QUE EL CUPÓN NO REEMPLACE A LAS MONEDAS.
// ============================================================

ObjetivosSemana get objetivos => Datos.i.resumen.objetivosSemana;

Future<void> montarSemanas(WidgetTester t) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await montarPantalla(t, SemanasTemporadaScreen(objetivos: objetivos));
  await t.pump();
}

/// Desliza el carrusel hasta que la card de [s] quede al centro.
Future<void> irA(WidgetTester t, SemanaObjetivos s) async {
  final hacia = s.numero < objetivos.enCurso!.numero ? 300.0 : -300.0;
  for (var i = 0; i < objetivos.semanas.length; i++) {
    final card = find.byKey(llaveCardSemana(s.numero));
    if (card.evaluate().isNotEmpty && (t.getCenter(card).dx - 195).abs() < 2) {
      return;
    }
    await t.drag(find.byKey(llaveCarruselSemanas), Offset(hacia, 0));
    await t.pumpAndSettle();
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  test('el mock tiene semanas con marca y semanas sin marca', () {
    expect(objetivos.semanas.where((s) => s.patrocinio != null), isNotEmpty);
    expect(objetivos.semanas.where((s) => s.patrocinio == null), isNotEmpty);
  });

  testWidgets('una semana vendida lleva el logo de su marca', (t) async {
    await montarSemanas(t);
    final s = objetivos.semanas.firstWhere((s) => s.patrocinio != null);
    await irA(t, s);
    expect(
      find.descendant(
        of: find.byKey(llaveCardSemana(s.numero)),
        matching: find.byType(LogoPatrocinio),
      ),
      findsWidgets,
    );
  });

  testWidgets('una semana sin marca no lleva logo ni cartel', (t) async {
    await montarSemanas(t);
    final s = objetivos.semanas.firstWhere(
      (s) => s.patrocinio == null && s.estado != EstadoSemana.enCurso,
    );
    await irA(t, s);
    expect(
      find.descendant(
        of: find.byKey(llaveCardSemana(s.numero)),
        matching: find.byType(LogoPatrocinio),
      ),
      findsNothing,
    );
    expect(find.textContaining('sin patrocinador'), findsNothing);
  });

  test('el cupón NO reemplaza a las monedas de la semana', () {
    // Si alguien cambia las monedas de la semana por el cupón, esto se
    // cae.
    for (final s in objetivos.semanas.where((s) => s.patrocinio != null)) {
      expect(s.monedas, greaterThan(0), reason: 'semana ${s.numero}');
    }
  });
}
