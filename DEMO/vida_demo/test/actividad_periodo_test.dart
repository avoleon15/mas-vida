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

      // NO es el mes calendario: son los días de las SEMANAS del mes
      // (las que tienen su lunes adentro). Agosto de 2026 arranca
      // sábado, y el 1 y el 2 se cuentan en la semana de julio.
      final pasos = historial.diasDeLasSemanasDelMes.fold<int>(
        0,
        (s, d) => s + (d.pasos ?? 0),
      );
      expect(find.text(_miles(pasos)), findsWidgets);
    });

    testWidgets('en Año cuenta los meses, no los días', (t) async {
      await montar(t);
      await t.tap(find.text('Año'));
      await t.pump();

      expect(find.text('Tu actividad'), findsOneWidget);
      // Los meses salen del resumen anual: lo que la app guarda día por
      // día son las últimas semanas, así que contando esos días el año
      // empezaría en julio.
      final conActividad = Datos.i.resumen.actividadPorMes
          .where((p) => p > 0)
          .length;
      expect(find.text('meses con actividad'), findsOneWidget);
      expect(find.text('$conActividad'), findsWidgets);
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

      // MES: cuántos días se movió, SOBRE los que tiene el mes. Ver lo
      // mismo en los tres filtros sería tres veces la misma pantalla.
      expect(find.text('promedio por día'), findsNothing);
      // Exacto y no `textContaining`: cada semana de la lista dice
      // tambien "X pasos · N dias activos" en su renglon de detalle.
      expect(find.textContaining('días activos de'), findsOneWidget);

      await t.tap(find.text('Año'));
      await t.pump();

      // AÑO: si sostuvo el ritmo mes a mes.
      expect(find.textContaining('días activos'), findsNothing);
      // "promedio de" con todas las letras: "puntos por mes" al lado de
      // un 1.405 se leía como si cada mes hubiera pagado eso.
      expect(find.text('promedio de puntos por mes'), findsOneWidget);
      expect(find.text('puntos por mes'), findsNothing);
    });

    testWidgets('el mes se mide contra los días que tiene ESE mes', (t) async {
      await montar(t);
      await t.tap(find.text('Mes'));
      await t.pump();

      // El denominador se calcula, nunca se escribe: septiembre tiene
      // 30, octubre 31 y febrero 28 o 29. El mes que viene la cifra
      // tiene que arrancar de cero y cambiar de denominador sola.
      final dias = Datos.i.historial.diasDeLasSemanasDelMes;
      final mes = dias.last.fecha;
      final cuantos = DateTime(mes.year, mes.month + 1, 0).day;
      final activos = dias.where((d) => d.puntosDia > 0).length;

      expect(find.text('$activos de $cuantos'), findsOneWidget);
      // Y se dice de QUÉ mes: un "20 de 30" suelto no deja ver que la
      // cuenta arranca de cero el día 1.
      const meses = [
        'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
      ];
      expect(
        find.text('días activos de ${meses[mes.month - 1]}'),
        findsOneWidget,
      );
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
      final activos = historial.diasDeLasSemanasDelMes
          .where((d) => d.puntosDia > 0)
          .length;
      expect(find.textContaining('$activos de '), findsOneWidget);
    });
  });

  group('La lista cambia con el filtro', () {
    testWidgets('Semana lista entrenamientos', (t) async {
      await montar(t);

      // Es el único tramo donde una sesión suelta todavía se recuerda.
      expect(find.text('Correr'), findsWidgets);
      expect(find.textContaining('Semana 1'), findsNothing);
    });

    testWidgets('Mes lista las semanas del mes', (t) async {
      await montar(t);
      await t.tap(find.text('Mes'));
      await t.pump();

      // La semana es la unidad en la que se mueve el rango, así que es
      // la que dice si el mes viene bien o mal.
      expect(find.text('Semana 1'), findsOneWidget);
      expect(find.text('Semana 2'), findsOneWidget);
      // Y ya no la lista de sesiones una por una.
      expect(find.text('Correr'), findsNothing);
    });

    testWidgets('Año lista los meses', (t) async {
      await montar(t);
      await t.tap(find.text('Año'));
      await t.pump();

      // Los puntos del año son los que construyen el nivel de cashback.
      expect(find.text('Agosto'), findsOneWidget);
      expect(find.text('Correr'), findsNothing);
      expect(find.textContaining('Semana 1'), findsNothing);
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

    testWidgets('Semana y Mes llevan las dos gráficas', (t) async {
      // El número grande dice CUÁNTOS puntos, y la gráfica de puntos de
      // qué días salieron: si la semana fue pareja o fue un solo día
      // bueno. Son dos lecturas, no la misma dos veces.
      await montar(t);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('Puntos por día'), findsOneWidget);

      await t.tap(find.text('Mes'));
      await t.pump();
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('Puntos por semana'), findsOneWidget);
    });

    testWidgets('el rótulo de la línea es la suma de lo que dibuja', (t) async {
      // "Pasos acumulados" tiene que cuadrar con los días que la app
      // tiene cargados, no con un techo redondeado.
      await montar(t);

      final pasos = historial.semanaEnCurso.fold<int>(
        0,
        (s, d) => s + (d.pasos ?? 0),
      );
      expect(find.text('${_miles(pasos)} pasos acumulados'), findsOneWidget);

      await t.tap(find.text('Mes'));
      await t.pump();

      final delMes = historial.diasDeLasSemanasDelMes.fold<int>(
        0,
        (s, d) => s + (d.pasos ?? 0),
      );
      expect(find.text('${_miles(delMes)} pasos acumulados'), findsOneWidget);
    });

    testWidgets('en Año la gráfica es el mapa de calor y nada más', (t) async {
      await montar(t);
      await t.tap(find.text('Año'));
      await t.pump();

      expect(find.byType(BarChart), findsNothing);
      expect(find.byType(LineChart), findsNothing);
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

String _miles(int v) => v.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);
