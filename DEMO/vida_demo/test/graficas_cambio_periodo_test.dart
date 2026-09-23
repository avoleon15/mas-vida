import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/theme.dart';
import 'package:vida_demo/widgets/numero_animado.dart';
import 'package:vida_demo/widgets/tarjeta_puntos.dart';

// ============================================================
// CAMBIAR DE FILTRO EN PROGRESO.
//
// EL BUG (visto por Daniel el 21 de septiembre de 2026). Al pasar de
// Semana a Mes, la línea se disparaba hasta arriba —se salía de su
// tarjeta y pintaba encima del número de puntos— y recién después se
// acomodaba.
//
// Por qué pasaba: `fl_chart` interpolaba entre la serie vieja y la nueva
// punto por punto. Las dos no tienen la misma cantidad de puntos (7 días
// contra 4 o 5 semanas), así que los que sobran arrancaban YA en su
// valor final —el total de una semana entera— mientras el techo del eje
// todavía venía subiendo desde el de un día.
//
// Lo que protegen estos tests es la forma de la solución:
//
//   · Cambiar de período REEMPLAZA la gráfica, no la deforma. Cada una
//     dibuja sus datos contra su propio techo.
//   · La que entra sube desde la base, que es la animación que la app ya
//     usa cuando llegan datos.
//   · Y por lo tanto ningún valor puede quedar por encima del techo: lo
//     único que se anima es una escala de 0 a 1 que multiplica valores
//     que ya estaban adentro.
// ============================================================

Periodo _periodo = Periodo.semana;

Widget _pantalla({bool animaciones = true}) => MaterialApp(
  theme: AppTheme.temaClaro,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: !animaciones),
      child: TemaVida(
        child: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => TarjetaPuntos(
                periodo: _periodo,
                onCambiarPeriodo: (p) => setState(() => _periodo = p),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

/// La gráfica de línea que está al frente. Durante el cambio hay dos: la
/// que se va y la que entra, y la que entra es la última del árbol.
LineChart _lineaAlFrente(WidgetTester t) =>
    t.widgetList<LineChart>(find.byType(LineChart)).last;

List<double> _alturas(LineChart g) =>
    g.data.lineBarsData.first.spots.map((s) => s.y).toList();

Future<void> _cambiarAMes(WidgetTester t) async {
  await t.tap(find.text('Mes'));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  setUp(() {
    _periodo = Periodo.semana;
    reiniciarCompuertaAnimacion();
  });

  testWidgets('ningún valor queda por encima del techo durante el cambio', (
    t,
  ) async {
    // Lo que se mira es lo que CADA gráfica manda a dibujar en cada
    // cuadro: sus valores contra su propio techo. Es la invariante que
    // vuelve imposible el bug —un valor multiplicado por algo entre 0 y
    // 1 nunca queda por encima de sí mismo— y se rompe en cuanto
    // alguien anime el techo, mezcle dos series en una gráfica o
    // arranque el crecimiento desde un número mayor que 1.
    //
    // Que no haya UNA gráfica deformándose entre dos períodos lo cuida
    // el test de abajo, que es la otra mitad del arreglo.
    await t.pumpWidget(_pantalla());
    await t.pumpAndSettle();

    await _cambiarAMes(t);

    var transcurrido = Duration.zero;
    for (final ms in [1, 20, 60, 120, 240, 420, 700]) {
      final hasta = Duration(milliseconds: ms);
      await t.pump(hasta - transcurrido);
      transcurrido = hasta;

      for (final g in t.widgetList<LineChart>(find.byType(LineChart))) {
        for (final y in _alturas(g)) {
          expect(
            y,
            lessThanOrEqualTo(g.data.maxY),
            reason: 'a los $ms ms un valor se salió del techo de su gráfica',
          );
          expect(y, greaterThanOrEqualTo(g.data.minY));
        }
      }
    }
  });

  testWidgets('cambiar de filtro reemplaza la gráfica, no la deforma', (
    t,
  ) async {
    await t.pumpWidget(_pantalla());
    await t.pumpAndSettle();
    final deLaSemana = t.state(find.byType(LineChart).last);

    await _cambiarAMes(t);
    await t.pumpAndSettle();

    // Otra gráfica, no la misma con otros datos: es lo que impide que
    // fl_chart interpole entre dos series que no tienen nada que ver.
    expect(t.state(find.byType(LineChart).last), isNot(same(deLaSemana)));
  });

  testWidgets('la que entra sube desde la base', (t) async {
    await t.pumpWidget(_pantalla());
    await t.pumpAndSettle();

    await _cambiarAMes(t);
    await t.pump(const Duration(milliseconds: 1));

    final alEntrar = _alturas(_lineaAlFrente(t));
    expect(alEntrar, isNotEmpty);
    expect(alEntrar, everyElement(0.0), reason: 'la línea entra desde 0');

    await t.pump(const Duration(milliseconds: 200));
    final aMitad = _alturas(_lineaAlFrente(t));
    for (final y in aMitad) {
      expect(y, greaterThan(0), reason: 'a mitad de camino ya subió algo');
    }

    await t.pumpAndSettle();
    final alFinal = _alturas(_lineaAlFrente(t));
    for (var i = 0; i < alFinal.length; i++) {
      expect(alFinal[i], greaterThanOrEqualTo(aMitad[i]));
    }
  });

  testWidgets('la gráfica que se va desaparece', (t) async {
    await t.pumpWidget(_pantalla());
    await t.pumpAndSettle();

    await _cambiarAMes(t);
    await t.pumpAndSettle();

    // Dos gráficas encimadas para siempre serían un borrón.
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('con "Reducir movimiento" el cambio es instantáneo', (t) async {
    await t.pumpWidget(_pantalla(animaciones: false));
    await t.pump();

    await _cambiarAMes(t);
    // Un solo pump: es lo que hacen los tests de la app. Sin esto, las
    // dos gráficas conviven un cuadro y un test encuentra los datos de
    // los dos períodos a la vez.
    await t.pump();

    expect(find.byType(LineChart), findsOneWidget);
    for (final y in _alturas(_lineaAlFrente(t))) {
      expect(y, greaterThan(0), reason: 'aparece ya dibujada, no en 0');
    }
  });
}
