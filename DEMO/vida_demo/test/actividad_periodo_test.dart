import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/screens/progress_screen.dart';
import 'package:vida_demo/widgets/calendario_actividad.dart';

import 'ayudas.dart';

// ============================================================
// "TU ACTIVIDAD" EN PROGRESO.
//
// Reemplaza a "Entrenamientos de los últimos 7 días", que era una lista
// fija a la semana: existía igual en Mes y en Año pero seguía contando
// siete días, así que cambiar el filtro no cambiaba nada abajo del
// selector.
//
// Lo que hay que proteger:
//
//   · Que el tramo cambie con el filtro. Es la razón del rediseño.
//   · Que cada entrenamiento diga los puntos que pagó, y que el que no
//     pagó diga por qué en vez de mostrar un "+0".
//   · Que la racha no vuelva: vive en Hoy y en Social.
// ============================================================

Historial get historial => Datos.i.historial;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  Future<void> montar(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await montarPantalla(t, const ProgressScreen());
    await t.pump();
  }

  group('La sección cambia con el filtro', () {
    testWidgets('en Semana cuenta la semana en curso', (t) async {
      await montar(t);

      expect(find.text('Tu actividad'), findsOneWidget);
      expect(find.textContaining('pasos esta semana'), findsOneWidget);

      final pasos = historial.semanaEnCurso.fold<int>(
        0,
        (s, d) => s + (d.pasos ?? 0),
      );
      expect(find.text(_miles(pasos)), findsWidgets);
    });

    testWidgets('en Mes cuenta el mes en curso', (t) async {
      await montar(t);
      await t.tap(find.text('Mes'));
      await t.pump();

      // Antes esta sección decía "los últimos 7 días" en los tres
      // filtros, y en Mes y en Año ni siquiera se dibujaba.
      expect(find.textContaining('pasos este mes'), findsOneWidget);
      expect(find.textContaining('pasos esta semana'), findsNothing);

      final pasos = historial.mesEnCurso.fold<int>(
        0,
        (s, d) => s + (d.pasos ?? 0),
      );
      expect(find.text(_miles(pasos)), findsWidgets);
    });

    testWidgets('en Año también está', (t) async {
      await montar(t);
      await t.tap(find.text('Año'));
      await t.pump();

      expect(find.text('Tu actividad'), findsOneWidget);
      expect(find.textContaining('pasos este año'), findsOneWidget);
    });

    testWidgets('el mejor día ya no está', (t) async {
      await montar(t);

      // Lo sacó Daniel: no lleva a ninguna parte. Enterarse de que el
      // mejor día fueron 12,400 pasos no dice qué hacer hoy, y en un
      // tramo largo es un récord viejo que solo se puede empeorar.
      expect(find.textContaining('mejor día'), findsNothing);
    });

    testWidgets('cada filtro trae su propia segunda cifra', (t) async {
      await montar(t);

      // SEMANA: el ritmo del día a día.
      expect(find.text('promedio por día'), findsOneWidget);

      await t.tap(find.text('Mes'));
      await t.pump();

      // MES: cuántos días se movió. Ver lo mismo en los tres filtros
      // sería tres veces la misma pantalla.
      expect(find.text('promedio por día'), findsNothing);
      expect(find.textContaining('días activos'), findsOneWidget);

      await t.tap(find.text('Año'));
      await t.pump();

      // AÑO: si sostuvo el ritmo mes a mes.
      expect(find.textContaining('días activos'), findsNothing);
      expect(find.text('promedio por mes'), findsOneWidget);
    });

    testWidgets('son DOS cifras y ni una más', (t) async {
      // La tercera nunca llevaba a ninguna parte: "3 de 3 días que
      // sumaron puntos" en una semana que va por el miércoles se lee
      // como un pleno que todavía no existe, y contar los
      // entrenamientos del año arriba de la lista que los muestra es
      // contarlos dos veces.
      await montar(t);
      expect(find.textContaining('días que sumaron puntos'), findsNothing);

      await t.tap(find.text('Mes'));
      await t.pump();
      expect(find.text('minutos de entreno'), findsNothing);

      await t.tap(find.text('Año'));
      await t.pump();
      expect(find.text('entrenamientos'), findsNothing);
    });

    testWidgets('los días activos salen del dato, no del piso de pasos', (
      t,
    ) async {
      await montar(t);
      await t.tap(find.text('Mes'));
      await t.pump();

      // No se recalculan los 7.000 pasos acá: se pregunta si el
      // servidor acreditó algo ese día.
      final activos = historial.mesEnCurso
          .where((d) => d.puntosDia > 0)
          .length;
      expect(find.text('$activos'), findsWidgets);
    });
  });

  group('Cada entrenamiento dice lo que pagó', () {
    testWidgets('el que sumó muestra sus puntos', (t) async {
      await montar(t);

      final conPuntos = historial.semanaEnCurso.where(
        (d) => d.sesion != null && d.sesion!.cuentaParaPuntos,
      );
      expect(conPuntos, isNotEmpty, reason: 'el mock tiene que traer uno');

      for (final d in conPuntos) {
        expect(
          find.text('+${d.sesion!.puntosIntensidad} pts'),
          findsWidgets,
          reason: 'falta el chip de puntos del ${d.fecha.day}',
        );
      }
    });

    testWidgets('el que no sumó dice "Sin puntos" y por qué', (t) async {
      await montar(t);

      final sinPuntos = historial.semanaEnCurso.where(
        (d) => d.sesion != null && !d.sesion!.cuentaParaPuntos,
      );
      expect(sinPuntos, isNotEmpty, reason: 'el mock tiene que traer uno');

      // "+0 pts" se lee como si algo hubiera sumado nada. Lo que pasó es
      // que esa sesión no entró en la cuenta, y eso hay que decirlo.
      expect(find.text('Sin puntos'), findsWidgets);
      expect(find.text('+0 pts'), findsNothing);
      expect(find.textContaining('30 min continuos'), findsOneWidget);
    });
  });

  group('Las gráficas dicen qué miden', () {
    testWidgets('el eje de abajo se nombra en las dos gráficas', (t) async {
      await montar(t);
      // "L M M J V S D" se entiende solo, pero el de Mes son números
      // sueltos ("1 · 2 · 3") y no son nada hasta que alguien aclara
      // que son las semanas de agosto.
      expect(find.text('días de la semana'), findsWidgets);

      await t.tap(find.text('Mes'));
      await t.pump();
      expect(find.textContaining('semanas de '), findsWidgets);
    });

    testWidgets('en Mes las semanas se numeran de 1 en adelante', (t) async {
      await montar(t);
      await t.tap(find.text('Mes'));
      await t.pump();

      // Antes el eje decía el día en que arrancaba cada semana ("3",
      // "10", "17"): números de día sueltos debajo de una gráfica que
      // habla de semanas, así que el primer tramo del mes parecía el
      // tercero.
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('la escala de pasos dice hasta dónde llega', (t) async {
      await montar(t);

      // Sin eje lateral: el techo va en un rótulo arriba a la derecha,
      // con la unidad. El eje le comía 58 px de ancho a la línea y no a
      // las barras, así que las dos quedaban desalineadas entre sí.
      expect(find.textContaining('pasos'), findsWidgets);
    });

    testWidgets('en Año la gráfica es el mapa de calor y nada más', (t) async {
      await montar(t);
      await t.tap(find.text('Año'));
      await t.pump();

      // Se probaron los puntos mes a mes en columnas y no aportaban:
      // doce barras casi iguales no dicen nada que el mapa de calor no
      // diga mejor, y ese muestra el año día por día.
      expect(find.text('Puntos por mes'), findsNothing);
      expect(find.byType(BarChart), findsNothing);
      expect(find.byType(CalendarioActividad), findsOneWidget);
    });
  });

  testWidgets('la racha ya no vive en Progreso', (t) async {
    await montar(t);

    // Se ve en Hoy —en el saludo— y en Social. Entera y con su historial
    // de ocho semanas era la tarjeta más alta de la pantalla.
    expect(find.text('Tu racha'), findsNothing);
    expect(find.textContaining('ÚLTIMAS 8 SEMANAS'), findsNothing);
  });
}

String _miles(int v) =>
    v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
