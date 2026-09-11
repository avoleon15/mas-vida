import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/theme.dart';
import 'package:vida_demo/widgets/numero_animado.dart';
import 'package:vida_demo/widgets/tarjeta_puntos.dart';

// ============================================================
// LAS GRÁFICAS DE PROGRESO CRECEN CON LA TANDA DE DATOS.
//
// Es la misma regla que la de los números: la animación pertenece a la
// TANDA DE DATOS, no al widget. Se reproduce al abrir la app y en cada
// refresco, y NO por cambiar de pestaña.
//
// El bug que arregla: el refresco suele traer los mismos datos, y la
// animación que trae fl_chart es de CAMBIO. Sin diferencia que
// interpolar, el número grande subía desde 0 y las gráficas se quedaban
// quietas.
// ============================================================

/// La misma serie para los tres períodos: lo que se prueba es la
/// animación, no de dónde salen los datos.
const _serie = [
  PuntoPeriodo(etiqueta: 'L', pasos: 12000, puntos: 50, hayDatos: true),
  PuntoPeriodo(etiqueta: 'M', pasos: 9000, puntos: 125, hayDatos: true),
  PuntoPeriodo(etiqueta: 'M', pasos: 8000, puntos: 25, hayDatos: true),
];

Widget _pantalla({bool animaciones = true}) => MaterialApp(
  theme: AppTheme.temaClaro,
  home: ValueListenableBuilder<int>(
    valueListenable: datosRecargados,
    builder: (context, _, _) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: !animaciones),
        child: TemaVida(
          child: Scaffold(
            body: Column(
              children: const [
                GraficaLineaPasos(serie: _serie),
                GraficaBarrasPuntos(serie: _serie),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

/// El alto de la línea en el cuadro que se está viendo.
List<double> _alturasLinea(WidgetTester t) => t
    .widget<LineChart>(find.byType(LineChart))
    .data
    .lineBarsData
    .first
    .spots
    .map((s) => s.y)
    .toList();

/// El alto de cada barra en el cuadro que se está viendo.
List<double> _alturasBarras(WidgetTester t) => t
    .widget<BarChart>(find.byType(BarChart))
    .data
    .barGroups
    .map((g) => g.barRods.first.toY)
    .toList();

void main() {
  setUp(reiniciarCompuertaAnimacion);

  testWidgets('al abrir la app las dos gráficas crecen desde la base', (
    t,
  ) async {
    await t.pumpWidget(_pantalla());

    expect(_alturasLinea(t), everyElement(0.0), reason: 'la línea arranca en 0');
    expect(
      _alturasBarras(t),
      everyElement(0.0),
      reason: 'las barras arrancan en 0',
    );

    await t.pump(const Duration(milliseconds: 400));
    for (final y in _alturasLinea(t)) {
      expect(y, greaterThan(0));
    }
    expect(_alturasLinea(t).first, lessThan(12000));

    await t.pumpAndSettle();
    expect(_alturasLinea(t), [12000.0, 9000.0, 8000.0]);
    expect(_alturasBarras(t), [50.0, 125.0, 25.0]);
  });

  testWidgets('refrescar las vuelve a animar, aunque el dato no cambie', (
    t,
  ) async {
    await t.pumpWidget(_pantalla());
    await t.pumpAndSettle();

    // Un refresco que devuelve EXACTAMENTE los mismos datos, que es lo
    // que pasa hoy con los JSON de prueba. Es el caso que no andaba.
    datosRecargados.value++;
    await t.pump();

    expect(_alturasLinea(t), everyElement(0.0));
    expect(_alturasBarras(t), everyElement(0.0));

    await t.pumpAndSettle();
    expect(_alturasLinea(t), [12000.0, 9000.0, 8000.0]);
    expect(_alturasBarras(t), [50.0, 125.0, 25.0]);
  });

  testWidgets('cambiar de pantalla NO las vuelve a animar', (t) async {
    await t.pumpWidget(_pantalla());
    await t.pumpAndSettle();

    // Lo que hace la barra de abajo: desmontar y volver a montar.
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    await t.pumpWidget(_pantalla());

    expect(
      _alturasBarras(t),
      [50.0, 125.0, 25.0],
      reason: 'al volver a la pantalla las gráficas ya están dibujadas',
    );
  });

  testWidgets('el número y la gráfica terminan juntos', (t) async {
    // No es un detalle estético: si duraran distinto, el número quedaría
    // parado esperando a la gráfica o al revés.
    await t.pumpWidget(_pantalla());
    await t.pump(duracionNumeroAnimado);
    await t.pump();

    expect(_alturasLinea(t), [12000.0, 9000.0, 8000.0]);
    expect(_alturasBarras(t), [50.0, 125.0, 25.0]);
  });

  testWidgets('con animaciones apagadas aparecen ya dibujadas', (t) async {
    await t.pumpWidget(_pantalla(animaciones: false));
    // Un solo pump: es lo que hacen los tests de la app.
    expect(_alturasLinea(t), [12000.0, 9000.0, 8000.0]);
    expect(_alturasBarras(t), [50.0, 125.0, 25.0]);
  });
}
