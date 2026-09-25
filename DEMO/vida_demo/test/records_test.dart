import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/screens/records_screen.dart';

import 'ayudas.dart';

// ============================================================
// TUS RÉCORDS.
//
// La pantalla eran cinco secciones y doce tarjetas idénticas, una
// debajo de la otra. Lo que protege este test es la poda: que el mejor
// día abra en grande, que los demás récords vivan en baldosas y que las
// notas que explicaban las reglas del producto no vuelvan —esas viven
// en Mi Plan y en Premios, no debajo de un número—.
// ============================================================

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  Future<void> montar(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await montarPantalla(t, const RecordsScreen());
    await t.pump();
  }

  testWidgets('el mejor día abre la pantalla', (t) async {
    await montar(t);

    expect(find.text('TUS RÉCORDS'), findsOneWidget);
    expect(find.text('TU MEJOR DÍA'), findsOneWidget);

    final mejor = Datos.i.historial.dias
        .where((d) => d.pasos != null)
        .reduce((a, b) => (a.pasos ?? 0) >= (b.pasos ?? 0) ? a : b);
    expect(find.text(_miles(mejor.pasos!)), findsOneWidget);
  });

  testWidgets('los demás récords están, en baldosas', (t) async {
    await montar(t);

    // Los títulos son de dos o tres palabras: en una baldosa no entra
    // una oración.
    expect(find.text('Tu mejor día en puntos'), findsOneWidget);
    expect(find.text('Tu mejor mes'), findsOneWidget);
    expect(find.text('Tu racha más larga'), findsOneWidget);
  });

  testWidgets('no vuelven las notas que explicaban las reglas', (t) async {
    await montar(t);

    // Cada total llevaba debajo un renglón con una regla del producto.
    // Son reglas, no récords: viven en Mi Plan y en Premios.
    expect(find.textContaining('nunca se gastan'), findsNothing);
    expect(find.textContaining('caducan a los 90 días'), findsNothing);
    expect(find.textContaining('No acreditan puntos'), findsNothing);
  });

  testWidgets('los totales siguen estando', (t) async {
    await montar(t);

    expect(find.text('TOTALES'), findsOneWidget);
    expect(find.text('Pasos registrados'), findsOneWidget);
    expect(find.text('Puntos del año'), findsOneWidget);
    expect(find.text('Nivel ${Datos.i.resumen.nivel}'), findsOneWidget);
    // Lo que vuelve auditable el puntaje: de qué reloj salió cada día.
    expect(find.text('DE DÓNDE SALEN TUS DATOS'), findsOneWidget);
  });
}

String _miles(int v) => v.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);
