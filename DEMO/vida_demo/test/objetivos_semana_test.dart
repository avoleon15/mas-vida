import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getwidget/getwidget.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/reglas_rango.dart';
import 'package:vida_demo/screens/camino_semanas_screen.dart';
import 'package:vida_demo/widgets/semanas_objetivos.dart';
import 'package:vida_demo/widgets/tarjeta_semana.dart';

import 'ayudas.dart';

/// La sección "Objetivos de la semana" y el camino de las diez semanas.
///
/// Lo que protegen estos tests es el rediseño: que los objetivos tengan
/// NOMBRE a la vista, que lo que falta se diga en unidades reales y no en
/// porcentaje, y que no vuelva ni una barra de progreso ni un action
/// sheet para mostrar un dato.
ObjetivosSemana get objetivos => Datos.i.resumen.objetivosSemana;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  Future<void> montarHome(WidgetTester t) async {
    await montarPantalla(
      t,
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SemanasObjetivos(objetivos: objetivos),
        ),
      ),
    );
    // Un solo pump alcanza: `montarPantalla` monta con "Reducir
    // movimiento". Si algún día hiciera falta un pumpAndSettle acá, es
    // que se le escapó una animación a la accesibilidad.
    await t.pump();
  }

  Future<void> montarCamino(WidgetTester t) async {
    await montarPantalla(t, CaminoSemanasScreen(objetivos: objetivos));
    await t.pump();
  }

  group('Los objetivos tienen nombre a la vista', () {
    testWidgets('los tres nombres se leen sin tocar nada', (t) async {
      await montarHome(t);

      // Es la razón de ser del rediseño. Antes había que tocar un círculo
      // y abrir un action sheet para saber de qué objetivo se trataba.
      for (final o in objetivos.enCurso!.objetivos) {
        expect(
          find.text(o.nombre),
          findsOneWidget,
          reason: '"${o.nombre}" tiene que verse en la tarjeta',
        );
      }
    });

    testWidgets('cada objetivo tiene su fila', (t) async {
      await montarHome(t);
      for (final o in objetivos.enCurso!.objetivos) {
        expect(find.byKey(llaveObjetivo(o.id)), findsOneWidget);
      }
    });
  });

  group('El avance se dice en unidades, nunca en porcentaje', () {
    test('un objetivo pendiente dice el avance y en qué unidad', () {
      final semana = objetivos.enCurso!;
      final pendiente = semana.objetivos.firstWhere((o) => !o.completo);

      expect(avanceDicho(pendiente), contains('${pendiente.progreso}'));
      expect(avanceDicho(pendiente), contains('de ${pendiente.meta}'));
    });

    test('NADA se dice con palabras de plazo', () {
      // La razón de ser del cambio: "Faltan 42 min" y "Faltan 2 días" se
      // leían como cuentas regresivas de cada objetivo, cuando los tres
      // cierran juntos el domingo 23:59. La columna de la derecha es una
      // CANTIDAD y no puede sonar a tiempo restante.
      for (final o in objetivos.enCurso!.objetivos) {
        final dicho = avanceDicho(o);
        expect(dicho, isNot(startsWith('Falta')));
        expect(dicho, isNot(contains('restan')));
        expect(dicho, isNot(contains('queda')));
      }
    });

    test('un objetivo cumplido dice "Completado"', () {
      final cumplido = objetivos.enCurso!.objetivos.firstWhere(
        (o) => o.completo,
      );
      expect(avanceDicho(cumplido), 'Completado');
    });

    test('la unidad concuerda con la meta', () {
      // "1 dias" era un error visible en pantalla. La unidad venía cruda
      // del JSON y se pegaba sin mirar la cantidad.
      const deVarios = ObjetivoSemanal(
        id: 'dias_ritmo_alto',
        nombre: 'Días con ritmo cardíaco alto',
        progreso: 1,
        meta: 3,
        unidad: 'días',
        completo: false,
      );
      expect(avanceDicho(deVarios), '1 de 3 días');

      const deUno = ObjetivoSemanal(
        id: 'dias_ritmo_alto',
        nombre: 'Días con ritmo cardíaco alto',
        progreso: 0,
        meta: 1,
        unidad: 'días',
        completo: false,
      );
      expect(avanceDicho(deUno), '0 de 1 día');
    });

    test('los minutos se abrevian', () {
      const o = ObjetivoSemanal(
        id: 'intensidad_semana',
        nombre: 'Minutos de intensidad',
        progreso: 48,
        meta: 90,
        unidad: 'minutos',
        completo: false,
      );
      expect(avanceDicho(o), '48 de 90 min');
    });

    test('llegar al número sin que el servidor lo acredite no dice el par', () {
      // "90 de 90" al lado de un círculo vacío se lee como un error de la
      // app, no como que el servidor todavía no lo cerró.
      const o = ObjetivoSemanal(
        id: 'intensidad_semana',
        nombre: 'Minutos de intensidad',
        progreso: 90,
        meta: 90,
        unidad: 'minutos',
        completo: false,
      );
      expect(avanceDicho(o), 'Casi');
    });

    test('sin meta NO se inventa un número', () {
      // La tabla de dificultad por rango todavía no existe. Dividir el
      // progreso por un porcentaje redondeado daría una cifra falsa con
      // dos decimales de precisión inventada.
      const o = ObjetivoSemanal(
        id: 'pasos_semana',
        nombre: 'Pasos de la semana',
        progreso: 48,
        meta: null,
        unidad: 'minutos',
        completo: false,
      );
      final dicho = avanceDicho(o);
      expect(dicho, isNot(contains('%')));
      expect(dicho, isNot(contains(RegExp(r'\d'))));
    });

    testWidgets('en pantalla no aparece ningún porcentaje', (t) async {
      await montarHome(t);
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('Ninguna barra de progreso', () {
    testWidgets('ni en la tarjeta de Hoy', (t) async {
      await montarHome(t);
      expect(find.byType(GFProgressBar), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('ni en el camino', (t) async {
      await montarCamino(t);
      expect(find.byType(GFProgressBar), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('El titular ubica la semana', () {
    testWidgets('dice por qué semana va', (t) async {
      await montarHome(t);
      final s = objetivos.enCurso!;
      expect(
        find.text('Semana ${s.numero} de ${objetivos.semanas.length}'),
        findsOneWidget,
      );
    });

    testWidgets('debajo, en chico, cuántos objetivos van', (t) async {
      await montarHome(t);
      final s = objetivos.enCurso!;
      expect(
        find.text('${s.cumplidos} de ${s.objetivos.length} objetivos'),
        findsOneWidget,
      );
    });

    testWidgets('el conteo aparece UNA sola vez', (t) async {
      await montarHome(t);
      // Llegó a estar dos veces: en el subtítulo del header viejo y otra
      // vez en la tarjeta.
      //
      // Se busca la frase COMPLETA, con la palabra "objetivos". Desde que
      // cada fila dice su avance igual ("1 de 3 días"), buscar solo los
      // dos números encuentra también la fila de días cuando coinciden
      // los dígitos, que es otra cosa y no una repetición.
      final s = objetivos.enCurso!;
      expect(
        find.textContaining(
          '${s.cumplidos} de ${s.objetivos.length} objetivos',
        ),
        findsOneWidget,
      );
    });

    testWidgets('nada de oraciones explicando la regla', (t) async {
      await montarHome(t);
      expect(find.textContaining('Con dos no alcanza'), findsNothing);
      expect(find.textContaining('Cumplí los'), findsNothing);
    });
  });

  group('El pie ubica la semana en el programa', () {
    testWidgets('dice el rango, y NO repite la semana', (t) async {
      await montarHome(t);
      // La semana la dice el titular. Repetirla en el pie era decir dos
      // veces lo mismo a diez centímetros de distancia.
      expect(find.text('RANGO ${objetivos.rangoActual}'), findsOneWidget);
      expect(find.textContaining('SEMANA'), findsNothing);
    });

    testWidgets('la tira trae una marca por semana', (t) async {
      await montarHome(t);
      expect(find.byKey(llaveTiraSemanas), findsOneWidget);
    });

    testWidgets('el chip muestra lo que paga cumplir esta semana', (t) async {
      await montarHome(t);
      final paso = objetivos.pasoDe(objetivos.enCurso!.numero)!;
      expect(find.text('+${paso.monedas}'), findsOneWidget);
    });
  });

  group('El camino', () {
    testWidgets('trae un nodo por semana', (t) async {
      await montarCamino(t);
      for (final s in objetivos.semanas) {
        expect(
          find.byKey(llaveNodoSemana(s.numero)),
          findsOneWidget,
          reason: 'falta el nodo de la semana ${s.numero}',
        );
      }
    });

    testWidgets('no hay candados en ningún nodo', (t) async {
      await montarCamino(t);
      // Un candado promete que hay algo que hacer para abrirlo, y no lo
      // hay: la semana 7 llega el 7 haga lo que haga el usuario.
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.lock), findsNothing);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
    });

    testWidgets('marca cuál es la semana en curso', (t) async {
      await montarCamino(t);
      expect(find.text('ESTA SEMANA'), findsOneWidget);
    });

    testWidgets('tocar un nodo abre esa semana en una hoja', (t) async {
      await montarCamino(t);
      final primera = objetivos.semanas.first;

      await t.tap(find.byKey(llaveNodoSemana(primera.numero)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      // La hoja trae la tarjeta de ESA semana, no la de la semana en
      // curso.
      expect(
        find.text('Semana ${primera.numero} de ${objetivos.semanas.length}'),
        findsWidgets,
      );
    });
  });

  group('Semana y rango no coinciden', () {
    test('el monto sale del rango arrastrado, no del número de semana', () {
      // Una semana fallada BAJA el rango, así que el nodo de la semana 5
      // puede estar pagando el rango 4. Si el monto saliera del número de
      // semana, este test se pondría rojo.
      final fallada = SemanaObjetivos(
        numero: 1,
        cierra: DateTime(2026, 9, 6),
        estado: EstadoSemana.cerrada,
        objetivos: const [
          ObjetivoSemanal(
            id: 'a',
            nombre: 'a',
            progreso: 0,
            meta: 10,
            unidad: 'pasos',
            completo: false,
          ),
        ],
      );
      final cumplida = SemanaObjetivos(
        numero: 2,
        cierra: DateTime(2026, 9, 13),
        estado: EstadoSemana.cerrada,
        objetivos: const [
          ObjetivoSemanal(
            id: 'a',
            nombre: 'a',
            progreso: 10,
            meta: 10,
            unidad: 'pasos',
            completo: true,
          ),
        ],
      );

      final programa = ObjetivosSemana(
        rangoActual: 1,
        semanas: [fallada, cumplida],
      );
      final recorrido = programa.recorrido;

      // La 1 falló desde el piso: se queda en 0 y no paga.
      expect(recorrido[0].rangoAlCerrar, rangoMinimo);
      expect(recorrido[0].monedas, 0);
      // La SEGUNDA semana sube apenas al rango 1, no al 2.
      expect(recorrido[1].rangoAlCerrar, 1);
      expect(recorrido[1].monedas, monedasPorSubirA(1));
    });

    test('lo que no cerró viene marcado como proyección', () {
      for (final p in objetivos.recorrido) {
        expect(
          p.proyectado,
          p.semana.estado != EstadoSemana.cerrada,
          reason: 'semana ${p.semana.numero}',
        );
      }
    });

    test('una proyección asume que se cumple todo de acá en adelante', () {
      final pendientes = objetivos.recorrido
          .where((p) => p.proyectado)
          .toList();

      // Cada semana proyectada sube exactamente un escalón sobre la
      // anterior: es el mejor caso, y se dice que es el mejor caso.
      for (var i = 1; i < pendientes.length; i++) {
        expect(
          pendientes[i].rangoAlCerrar,
          (pendientes[i - 1].rangoAlCerrar + 1).clamp(rangoMinimo, rangoMaximo),
        );
      }
    });
  });
}
