import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/reglas_rango.dart';
import 'package:vida_demo/widgets/insignia_rango.dart';

import 'ayudas.dart';

// ============================================================
// LA INSIGNIA DE RANGO.
//
// Lo que hay que proteger:
//
//   · QUE NO VUELVA EL XP. El anillo enciende muescas ENTERAS. Media
//     muesca sería un medidor de avance dentro de un rango, y
//     `reglas_rango.dart` sacó ese medidor a propósito: el rango se mueve
//     por cumplir los tres objetivos, no por juntar puntitos.
//   · QUE EL MEDALLÓN NO CAMBIE DE TAMAÑO CON EL NÚMERO. El rango 10
//     tiene dos dígitos y el 2 uno solo; si el disco creciera, el
//     encabezado se movería solo al subir de rango.
//   · QUE LOS EXTREMOS NO REVIENTEN. El rango 0 es el piso real de la
//     escalera —ahí arranca cualquiera— y el 10 es el techo.
// ============================================================

Future<void> montarInsignia(WidgetTester t, int rango) => montarPantalla(
  t,
  Scaffold(body: Center(child: InsigniaRango(rango: rango))),
);

void main() {
  testWidgets('dice el rango y el largo de la escalera', (t) async {
    await montarInsignia(t, 2);

    expect(find.text('2'), findsOneWidget);
    // Para quien no ve el anillo, el medallón tiene que decir de cuántos
    // escalones es ese 2. El número suelto no dice nada.
    expect(find.bySemanticsLabel('Rango 2 de $rangoMaximo'), findsOneWidget);
  });

  testWidgets('el piso de la escalera se dibuja igual', (t) async {
    // El rango 0 no es un caso raro: es donde arranca cualquiera. Un
    // anillo que reviente acá lo ve el usuario en su primera semana.
    await montarInsignia(t, rangoMinimo);

    expect(find.text('0'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('el techo entra en el mismo medallón', (t) async {
    await montarInsignia(t, rangoMaximo);
    final conDosDigitos = t.getSize(find.byType(InsigniaRango));
    expect(find.text('$rangoMaximo'), findsOneWidget);

    await montarInsignia(t, 2);
    final conUnDigito = t.getSize(find.byType(InsigniaRango));

    // El 10 se achica adentro del disco; lo que NO puede es agrandar el
    // medallón, o el encabezado se mueve solo al subir de rango.
    expect(conDosDigitos, conUnDigito);
  });

  testWidgets('un rango fuera de la escalera no la desborda', (t) async {
    // Si el servidor se equivoca y manda un rango más alto que el techo,
    // la pantalla no puede reventar ni pintar muescas de más.
    await montarInsignia(t, rangoMaximo + 5);

    expect(t.takeException(), isNull);
  });
}
