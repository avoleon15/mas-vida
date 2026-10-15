import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/widgets/calendario_actividad.dart';

import 'ayudas.dart';

// ============================================================
// EL MAPA DE CALOR DEL AÑO.
//
// Una casilla por día VIVIDO, y ni una más. Antes la cuadrícula llegaba
// al 31 de diciembre: en septiembre eso son tres meses y medio de
// casillas vacías a la derecha —más de una cuarta parte del dibujo—
// esperando a existir, y el año propio se veía a medio hacer.
//
// Los meses anteriores al primer dato SÍ se dibujan, vacíos: esos días
// existieron aunque la app no estuviera instalada, y son los que le dan
// al año su forma.
// ============================================================

/// El lunes de la semana que contiene al 1 de enero, que es donde
/// arranca la cuadrícula para que las columnas queden alineadas por día
/// de la semana.
DateTime primerLunes(int anio) {
  final enero = DateTime(anio, 1, 1);
  return enero.subtract(Duration(days: enero.weekday - 1));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  Future<void> montar(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await montarPantalla(
      t,
      Scaffold(
        body: SingleChildScrollView(
          child: CalendarioActividad(dias: Datos.i.historial.dias),
        ),
      ),
    );
    await t.pump();
  }

  testWidgets('hay una casilla por día vivido y ninguna del futuro', (t) async {
    await montar(t);

    final hoy = Datos.i.historial.dias.last.fecha;
    final desde = primerLunes(hoy.year);
    final esperadas =
        DateTime(hoy.year, hoy.month, hoy.day).difference(desde).inDays + 1;

    // Cada casilla es un Tooltip con el resumen del día.
    expect(find.byType(Tooltip), findsNWidgets(esperadas));
  });

  testWidgets('la última casilla dibujada es la de hoy', (t) async {
    await montar(t);

    const meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final hoy = Datos.i.historial.dias.last.fecha;

    // Las casillas se construyen columna por columna, de arriba abajo,
    // así que la última del árbol es el último día dibujado. Si el
    // futuro volviera a la cuadrícula, esta sería la del 31 de
    // diciembre.
    final ultima = t.widgetList<Tooltip>(find.byType(Tooltip)).last;
    expect(ultima.message, startsWith('${hoy.day} de ${meses[hoy.month - 1]}'));
  });

  testWidgets('los meses anteriores al primer dato sí se dibujan', (t) async {
    await montar(t);

    // Sin ellos el año no tendría forma: enero existió aunque la app no
    // estuviera instalada.
    final hoy = Datos.i.historial.dias.last.fecha;
    if (hoy.month == 1) return;

    final mensajes = t
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((w) => w.message ?? '')
        .toList();

    expect(mensajes.any((m) => m.contains(' de ene')), isTrue);
  });
}
