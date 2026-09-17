import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/screens/premios_screen.dart';

import 'ayudas.dart';

/// Todas las tarjetas del catálogo son IGUALES: lo único que compra el
/// comercio destacado es el sello y el primer lugar. Acá se cuida esa
/// regla —que es la que se rompió cuando se probó darle una tarjeta
/// apaisada— y que reordenar no desarme el catálogo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Datos.cargar();
  });

  Premio premio(String id, {bool destacado = false}) => Premio(
    id: id,
    nombre: id,
    zona: 'Guatemala',
    categoria: 'Restaurantes',
    descripcion: '',
    detalle: '',
    condiciones: '',
    costoMonedas: 10,
    vence: '2026-12-31',
    destacado: destacado,
  );

  List<Premio> lista(int cuantos, {Set<int> destacados = const {}}) => [
    for (var i = 0; i < cuantos; i++)
      premio('p$i', destacado: destacados.contains(i)),
  ];

  group('Orden del catálogo', () {
    test('el destacado va primero', () {
      final orden = destacadosPrimero(lista(12, destacados: {7}));
      expect(orden.first.id, 'p7');
    });

    test('varios destacados van adelante en su orden', () {
      final orden = destacadosPrimero(lista(12, destacados: {3, 9}));
      expect(orden.take(2).map((p) => p.id), ['p3', 'p9']);
    });

    test('sin destacados no toca nada', () {
      // El catálogo viene mezclado a propósito para que en "Todos" las
      // categorías queden intercaladas. Reordenar de gusto lo desarma.
      final original = lista(12);
      expect(destacadosPrimero(original), same(original));
    });

    test('no pierde ni duplica ningún premio', () {
      for (final destacados in [<int>{}, {0}, {2, 5}, {1, 2, 3, 4, 5, 6, 7}]) {
        final original = lista(12, destacados: destacados);
        final orden = destacadosPrimero(original);

        expect(orden.length, original.length);
        expect(
          orden.map((p) => p.id).toSet(),
          original.map((p) => p.id).toSet(),
          reason: 'Con destacados en $destacados se perdió o duplicó alguno',
        );
      }
    });

    test('los premios que no son destacados conservan su orden', () {
      final orden = destacadosPrimero(lista(9, destacados: {4}));
      final resto = orden.where((p) => !p.destacado).map((p) => p.id).toList();

      expect(resto, ['p0', 'p1', 'p2', 'p3', 'p5', 'p6', 'p7', 'p8']);
    });
  });

  group('Catálogo en pantalla', () {
    testWidgets('todas las tarjetas miden lo mismo', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await montarPantalla(tester, const PremiosScreen());
      await tester.pump();

      expect(tester.takeException(), isNull);

      // La del destacado incluida: el sello va montado sobre el logo
      // justamente para que no le cambie el alto a la tarjeta.
      final medidas = tester
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .map((w) => tester.getSize(find.byWidget(w)))
          .where((s) => s.width > 100 && s.height > 100)
          .toSet();

      expect(
        medidas.length,
        1,
        reason: 'Hay tarjetas de tamaños distintos: $medidas',
      );
      expect(find.text('Destacado'), findsWidgets);
    });

    testWidgets('el catálogo de verdad tiene destacados que ubicar', (
      tester,
    ) async {
      // Si el mock se queda sin destacados, la pantalla sigue andando
      // pero este archivo deja de probar lo que dice probar.
      expect(
        Datos.i.catalogo.premios.where((p) => p.destacado),
        isNotEmpty,
        reason: 'Nadie está ejercitando el sello con datos reales',
      );
    });
  });
}
