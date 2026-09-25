import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/theme.dart';
import 'package:vida_demo/widgets/boton_relieve.dart';

// ============================================================
// El botón de relieve se dibujó una vez con todos los hijos del Stack
// `Positioned`, y así un Stack no tiene tamaño propio: el botón colapsaba
// a cero de ancho y desaparecía de la pantalla sin dar ningún error.
//
// Estos tests fijan que el botón OCUPA espacio y que hundirse no le
// cambia la altura.
// ============================================================

Future<void> _montar(WidgetTester tester, Widget boton) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.temaClaro,
      // Row con Spacer: el caso exacto donde se rompía, porque el botón
      // queda sin ancho impuesto por el padre.
      home: Scaffold(body: Row(children: [const Spacer(), boton])),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('un botón sin ancho impuesto igual ocupa espacio', (
    tester,
  ) async {
    await _montar(
      tester,
      BotonRelieve(label: 'Nuevo duelo', compacto: true, onPressed: () {}),
    );

    final tamano = tester.getSize(find.byType(BotonRelieve));
    expect(tamano.width, greaterThan(60));
    expect(tamano.height, greaterThan(30));
    expect(find.text('Nuevo duelo'), findsOneWidget);
  });

  testWidgets('presionarlo no le cambia la altura', (tester) async {
    await _montar(tester, BotonRelieve(label: 'Aceptar', onPressed: () {}));

    final antes = tester.getSize(find.byType(BotonRelieve));

    // Se mantiene el dedo apoyado: es el estado hundido.
    final gesto = await tester.startGesture(
      tester.getCenter(find.byType(BotonRelieve)),
    );
    await tester.pump(const Duration(milliseconds: 60));

    expect(tester.getSize(find.byType(BotonRelieve)), antes);
    await gesto.up();
  });

  testWidgets('llama a onPressed al soltar', (tester) async {
    var toques = 0;
    await _montar(
      tester,
      BotonRelieve(label: 'Agregar', onPressed: () => toques++),
    );

    await tester.tap(find.byType(BotonRelieve));
    await tester.pumpAndSettle();

    expect(toques, 1);
  });
}
