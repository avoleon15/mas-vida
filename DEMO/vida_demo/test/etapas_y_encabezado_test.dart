import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/screens/progress_screen.dart';
import 'package:vida_demo/theme.dart';
import 'package:vida_demo/widgets/stepper_etapas.dart';

import 'ayudas.dart';

// ============================================================
// Dos pedidos de Daniel del 21 de septiembre de 2026:
//
//   · Cada tarjeta de etapa lleva el metal de SU tramo del anillo
//     (1 bronce, 2 plata, 3 oro), sin importar en qué estado esté.
//   · El encabezado de Progreso dice un número y nada más: se fue la
//     barra contra el techo del período.
// ============================================================

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  /// La decoración de la tarjeta de la etapa [n].
  ///
  /// Se busca por el rótulo y se sube al Container que lo envuelve: la
  /// tarjeta es el ancestro más cercano, y así el test no depende del
  /// orden en que el PageView construya las páginas.
  BoxDecoration cajaDeEtapa(WidgetTester t, int n) {
    final caja = t.widget<Container>(
      find
          .ancestor(of: find.text('ETAPA $n'), matching: find.byType(Container))
          .first,
    );
    return caja.decoration! as BoxDecoration;
  }

  Color bordeDeEtapa(WidgetTester t, int n) =>
      cajaDeEtapa(t, n).border!.top.color;

  Future<void> montarEtapas(WidgetTester t, int pasos) async {
    t.view.physicalSize = const Size(390, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await montarPantalla(t, StepperEtapas(pasos: pasos));
    await t.pump();
  }

  group('Cada etapa lleva el metal de su tramo del anillo', () {
    // El metal va en el BORDE, no en el fondo: la superficie se queda
    // blanca. El carrusel arranca parado en la etapa en curso y
    // construye esa y la de al lado, así que cada caso entra por los
    // pasos que dejan a la vista la tarjeta que se quiere mirar.

    testWidgets('la etapa 1 en curso se bordea de bronce', (t) async {
      await montarEtapas(t, 3000);

      expect(bordeDeEtapa(t, 1), AppColors.tintaBronce);
    });

    testWidgets('la etapa 2 en curso se bordea de plata', (t) async {
      await montarEtapas(t, 8432);

      expect(bordeDeEtapa(t, 2), AppColors.tintaPlata);
    });

    testWidgets('la etapa 3 se bordea de oro', (t) async {
      await montarEtapas(t, 16000);

      expect(bordeDeEtapa(t, 3), AppColors.tintaOro);
    });

    testWidgets('ninguna tarjeta se pinta entera', (t) async {
      await montarEtapas(t, 8432);

      // La etapa en curso y la cumplida van sobre blanco. Se probó con
      // el fondo del metal y tres tarjetas de color seguidas ensucian
      // la pantalla.
      expect(cajaDeEtapa(t, 2).color, AppColors.card);
    });

    testWidgets('una etapa cumplida se queda en su metal, no se pasa al azul', (
      t,
    ) async {
      // 8.432 pasos dejan la etapa 1 cumplida, pero el carrusel arranca
      // parado en la 2: hay que volver a ella deslizando.
      await montarEtapas(t, 8432);
      await t.drag(find.byType(PageView), const Offset(400, 0));
      await t.pumpAndSettle();

      expect(find.text('Completada'), findsOneWidget);
      // Antes el borde de la cumplida iba en azulSuave y la etapa 1 no
      // tenía nada que ver con el tramo de bronce del anillo de arriba.
      expect(bordeDeEtapa(t, 1), AppColors.tintaBronce);
      expect(bordeDeEtapa(t, 1), isNot(AppColors.azulSuave));
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

      // Es la única referencia que queda, y es contra vos mismo.
      expect(find.textContaining('la semana pasada'), findsOneWidget);
    });
  });
}
