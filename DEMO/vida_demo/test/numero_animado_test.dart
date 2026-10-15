import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/widgets/numero_animado.dart';

/// Cuándo se anima un número y cuándo no.
///
/// La regla es que la animación pertenece a la TANDA DE DATOS y no al
/// widget: se reproduce al abrir la app y en cada refresco, nunca por
/// cambiar de pestaña. Como la barra de abajo navega con
/// `pushReplacementNamed`, cada cambio de pestaña remonta la pantalla, y
/// sin esa regla los números volverían a subir desde 0 todo el tiempo.
Widget _pantalla({bool animaciones = true}) => MaterialApp(
  home: ValueListenableBuilder<int>(
    valueListenable: datosRecargados,
    builder: (context, _, _) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: !animaciones),
        child: Center(
          child: NumeroAnimado(
            valor: 12480,
            formato: milesConComa,
            estilo: const TextStyle(fontSize: 40),
          ),
        ),
      ),
    ),
  ),
);

String _visible(WidgetTester t) =>
    t.widgetList<Text>(find.byType(Text)).last.data!;

void main() {
  setUp(reiniciarCompuertaAnimacion);

  testWidgets('al abrir la app sube desde 0 hasta el valor', (tester) async {
    await tester.pumpWidget(_pantalla());

    expect(_visible(tester), '0', reason: 'arranca en 0');

    await tester.pump(const Duration(milliseconds: 400));
    final medio = _visible(tester);
    final valorMedio = int.parse(medio.replaceAll(',', ''));
    expect(valorMedio, greaterThan(0));
    expect(valorMedio, lessThan(12480));

    await tester.pumpAndSettle();
    expect(_visible(tester), '12,480');
  });

  testWidgets('cambiar de pantalla NO vuelve a animar', (tester) async {
    await tester.pumpWidget(_pantalla());
    await tester.pumpAndSettle();

    // Lo que hace la barra de abajo: desmontar y volver a montar.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpWidget(_pantalla());

    expect(
      _visible(tester),
      '12,480',
      reason: 'al volver a la pantalla el número ya está escrito',
    );
  });

  testWidgets('refrescar vuelve a animar, aunque el dato no cambie', (
    tester,
  ) async {
    await tester.pumpWidget(_pantalla());
    await tester.pumpAndSettle();

    // Un refresco que devuelve EXACTAMENTE los mismos datos, que es lo
    // que pasa hoy con los JSON de prueba.
    datosRecargados.value++;
    await tester.pump();
    expect(_visible(tester), '0', reason: 'el refresco lo rebobina');

    await tester.pumpAndSettle();
    expect(_visible(tester), '12,480');
  });

  testWidgets('con animaciones apagadas aparece ya escrito', (tester) async {
    await tester.pumpWidget(_pantalla(animaciones: false));
    // Un solo pump: es lo que hacen los tests de la app.
    expect(find.text('12,480'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}
