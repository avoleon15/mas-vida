import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/screens/progress_screen.dart';
import 'package:vida_demo/reglas_puntos.dart';
import 'package:vida_demo/theme.dart';
import 'package:vida_demo/widgets/como_sumar.dart';

import 'ayudas.dart';

// ============================================================
// Las etapas de pasos (detrás de la (i) de Hoy desde el 2 de octubre de
// 2026) y un pedido de Daniel del 21 de septiembre de 2026:
//
//   · Cada etapa lleva el metal de SU tramo del anillo (1 bronce,
//     2 plata, 3 oro).
//   · El encabezado de Progreso dice un número y nada más: se fue la
//     barra contra el techo del período.
// ============================================================

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  Future<void> montarEtapas(WidgetTester t, int pasos) async {
    t.view.physicalSize = const Size(390, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await montarPantalla(t, Scaffold(body: BotonComoSumar(pasos: pasos)));
    await t.pump();
  }

  Future<void> abrir(WidgetTester t) async {
    await t.tap(find.byKey(llaveInfoEtapas));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  group('Las etapas viven detrás de "¿Cómo sumo?"', () {
    testWidgets('sin tocar, solo se ve el botón', (t) async {
      await montarEtapas(t, 8432);
      expect(find.text('¿Cómo sumo?'), findsOneWidget);
      expect(find.text('7,000 pasos'), findsNothing);
    });

    testWidgets('abierto muestra los tres tramos con sus puntos', (t) async {
      await montarEtapas(t, 8432);
      await abrir(t);

      expect(find.text('7,000 pasos'), findsOneWidget);
      expect(find.text('10,000 pasos'), findsOneWidget);
      expect(find.text('15,000+ pasos'), findsOneWidget);
      for (final pts in ['+25 pts', '+50 pts', '+100 pts']) {
        expect(find.text(pts), findsOneWidget);
      }
    });

    testWidgets('dice qué tramo está cumplido, cuál corre y cuál falta', (
      t,
    ) async {
      await montarEtapas(t, 8432);
      await abrir(t);

      expect(find.text('Completada'), findsOneWidget);
      expect(find.text('Te faltan 1,568 pasos'), findsOneWidget);
      expect(find.text('Bloqueado'), findsOneWidget);
    });

    testWidgets('cada tramo lleva el metal de su aro en el número', (t) async {
      await montarEtapas(t, 16000);
      await abrir(t);

      // Con 16.000 pasos los tres están encendidos: cada disco va en la
      // tinta de su metal, el mismo del aro del anillo.
      final discos = t
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle)
          .map((d) => d.color)
          .toList();
      for (var i = 0; i < 3; i++) {
        expect(discos, contains(AppColors.metal(i).tinta));
      }
    });

    testWidgets('explica también el extra por entrenar y el máximo', (t) async {
      await montarEtapas(t, 8432);
      await abrir(t);
      expect(find.text('2. Entrenando'), findsOneWidget);
      expect(find.textContaining('$techoDiario puntos'), findsOneWidget);
    });

    testWidgets('"Entendido" la cierra', (t) async {
      await montarEtapas(t, 8432);
      await abrir(t);
      await t.tap(find.text('Entendido'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(llaveHojaComoSumar), findsNothing);
    });

    testWidgets('los tres metales son tres colores distintos', (t) async {
      final metales = [for (var i = 0; i < 3; i++) AppColors.metal(i)];

      expect(metales.map((m) => m.aro).toSet().length, 3);
      expect(metales.map((m) => m.tinta).toSet().length, 3);
    });
  });

  group('El encabezado de Progreso es un número y nada más', () {
    Future<void> montar(WidgetTester t) async {
      t.view.physicalSize = const Size(390, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await montarPantalla(t, const ProgressScreen());
      await t.pump();
    }

    testWidgets('no queda ninguna barra contra el techo del período', (
      t,
    ) async {
      await montar(t);

      for (final filtro in ['Semana', 'Mes', 'Año']) {
        await t.tap(find.text(filtro));
        await t.pump();
        expect(
          find.textContaining('posibles'),
          findsNothing,
          reason: 'el techo del período no se nombra en $filtro',
        );
      }
    });

    testWidgets('la comparación contra el período anterior se queda', (
      t,
    ) async {
      await montar(t);

      // Es la única referencia que queda, y es contra ti mismo.
      expect(find.textContaining('la semana pasada'), findsOneWidget);
    });
  });
}
