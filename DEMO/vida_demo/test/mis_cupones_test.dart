import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/screens/premios_screen.dart';
import 'package:vida_demo/widgets/mis_cupones.dart';

import 'ayudas.dart';

// ============================================================
// PREMIOS › MIS CUPONES.
//
// Lo que se protege: que los códigos comprados se puedan volver a
// encontrar (antes se veían una sola vez, en el canje exitoso), que el
// que vence primero vaya arriba, que lo usado no se confunda con lo que
// se puede usar, y que un cupón dure 60 días.
// ============================================================

List<CuponCanjeado> get _cupones => Datos.i.catalogo.cupones;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  Future<void> montar(WidgetTester t, {VistaPremios? vista}) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await montarPantalla(t, PremiosScreen(vistaInicial: vista));
    await t.pump();
  }

  testWidgets('Premios abre en la tienda y el selector dice cuántos hay', (
    t,
  ) async {
    await montar(t);
    expect(find.byKey(llaveSelectorPremios), findsOneWidget);
    expect(find.text('Tienda'), findsOneWidget);
    expect(find.text('Mis cupones'), findsOneWidget);
    final activos = cuponesActivos(_cupones).length;
    expect(find.text('$activos'), findsOneWidget);
    // En la tienda no se ven los cupones.
    expect(find.byKey(llaveCupon(_cupones.first.id)), findsNothing);
  });

  testWidgets('tocar "Mis cupones" muestra los cupones y oculta el buscador', (
    t,
  ) async {
    await montar(t);
    await t.tap(find.text('Mis cupones'));
    await t.pumpAndSettle();

    for (final c in _cupones) {
      expect(find.byKey(llaveCupon(c.id)), findsOneWidget, reason: c.id);
    }
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('el que vence primero va arriba', (t) async {
    await montar(t, vista: VistaPremios.cupones);
    final activos = cuponesActivos(_cupones);
    for (var i = 1; i < activos.length; i++) {
      expect(
        t.getTopLeft(find.byKey(llaveCupon(activos[i].id))).dy,
        greaterThan(t.getTopLeft(find.byKey(llaveCupon(activos[i - 1].id))).dy),
      );
    }
  });

  testWidgets('los usados y vencidos van abajo, aparte', (t) async {
    await montar(t, vista: VistaPremios.cupones);
    expect(find.text('USADOS Y VENCIDOS'), findsOneWidget);
    final titulo = t.getTopLeft(find.text('USADOS Y VENCIDOS')).dy;
    for (final c in _cupones) {
      final y = t.getTopLeft(find.byKey(llaveCupon(c.id))).dy;
      if (c.activo) {
        expect(y, lessThan(titulo), reason: c.id);
      } else {
        expect(y, greaterThan(titulo), reason: c.id);
      }
    }
  });

  testWidgets('tocar un cupón abre su código en grande', (t) async {
    await montar(t, vista: VistaPremios.cupones);
    final c = cuponesActivos(_cupones).first;
    await t.tap(find.byKey(llaveCupon(c.id)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.byKey(llaveHojaCodigo), findsOneWidget);
    expect(find.text(c.codigo), findsOneWidget);
    expect(find.textContaining('Muéstralo en caja'), findsOneWidget);
  });

  for (final escala in [1.3, 1.6]) {
    testWidgets('con la letra de iOS a $escala nada se desborda', (t) async {
      t.view.physicalSize = const Size(375, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await montarPantalla(
        t,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(escala)),
            child: const PremiosScreen(vistaInicial: VistaPremios.cupones),
          ),
        ),
      );
      await t.pump();
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('sin cupones invita a la tienda', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var fueALaTienda = false;
    await montarPantalla(
      t,
      Scaffold(
        body: MisCupones(
          cupones: const [],
          onIrALaTienda: () => fueALaTienda = true,
        ),
      ),
    );
    await t.pump();
    expect(find.text('Todavía no tienes cupones'), findsOneWidget);
    await t.tap(find.text('Explorar la tienda'));
    expect(fueALaTienda, isTrue);
  });

  test('canjear deja el cupón guardado, arriba y por 60 días', () {
    final premio = Datos.i.catalogo.premios.first;
    final antes = _cupones.length;
    final cupon = registrarCanje(premio, ahora: DateTime(2026, 9, 8));

    expect(_cupones.length, antes + 1);
    expect(_cupones.first.id, cupon.id);
    expect(cupon.activo, isTrue);
    expect(cupon.comercio, premio.nombre);
    expect(cupon.vence, '2026-11-07');
    expect(cupon.diasParaVencer, 60);
    _cupones.remove(cupon);
  });

  test('el mock no trae ningún cupón que dure más de 60 días', () {
    for (final c in _cupones) {
      final desde = DateTime.parse(c.canjeado);
      final hasta = DateTime.parse(c.vence);
      expect(hasta.difference(desde).inDays, 60, reason: c.id);
    }
  });
}
