import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/screens/camino_semanas_screen.dart';
import 'package:vida_demo/theme.dart';
import 'package:vida_demo/widgets/curva_camino.dart';

import 'ayudas.dart';

// ============================================================
// QUE EL CAMINO NO SE VUELVA UNA TABLA.
//
// Lo que protege este archivo son las tres cosas que hacen que el
// recorrido se lea como un camino y no como el contorno de una grilla:
//
//   · QUE LOS TRAMOS SE COMBEN, y que se comben de a uno hacia cada
//     lado. Con la amplitud en cero el trazo vuelve a ser una línea
//     recta con esquinas de 90°, que es de donde se venía.
//   · QUE CADA CÍRCULO DIGA QUÉ SEMANA ES, con todas las letras. Un
//     número suelto puede ser la semana o las monedas: las dos
//     escaleras viven en esta pantalla.
//   · QUE NO VUELVAN LAS TARJETAS. CLAUDE.md pide UNA sola cosa
//     levantada por pantalla, y acá esa cosa es el camino.
// ============================================================

ObjetivosSemana get objetivos => Datos.i.resumen.objetivosSemana;

Future<void> montarCamino(WidgetTester t) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  await montarPantalla(t, CaminoSemanasScreen(objetivos: objetivos));
  await t.pump();
}

/// Dónde pasa el trazo a mitad de camino entre sus dos puntas.
Offset mitadDe(Path trazo) {
  final medida = trazo.computeMetrics().first;
  return medida.getTangentForOffset(medida.length / 2)!.position;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  group('El trazo se comba', () {
    const a = Offset.zero;
    const b = Offset(120, 0);

    test('la amplitud positiva lo manda de un lado y la negativa del otro', () {
      // Es lo que deja encadenar una onda larga: un tramo hacia abajo, el
      // siguiente hacia arriba. Si `curvaArco` combara siempre para el
      // mismo lado, una fila serían tres jorobas iguales.
      expect(mitadDe(curvaArco(a, b, amplitud: 0.2)).dy, greaterThan(8));
      expect(mitadDe(curvaArco(a, b, amplitud: -0.2)).dy, lessThan(-8));
    });

    test('los dos controles salen del MISMO lado', () {
      // Con uno de cada lado el tramo sería una ese que cruza la recta en
      // el medio: dos jorobas por tramo, que es un zigzag y no una onda.
      // Un arco de un solo lado deja la curva ENTERA de ese lado.
      final trazo = curvaArco(a, b, amplitud: 0.2);
      for (final medida in trazo.computeMetrics()) {
        for (var i = 1; i < 10; i++) {
          final punto = medida
              .getTangentForOffset(medida.length * i / 10)!
              .position;
          expect(
            punto.dy,
            greaterThanOrEqualTo(0),
            reason: 'el trazo cruzó al otro lado en el $i/10',
          );
        }
      }
    });

    test('sin amplitud vuelve a ser una recta', () {
      // El caso que hay que poder detectar: es exactamente como se veía
      // el camino antes, y es lo que hacía que la pantalla se leyera como
      // el contorno de una tabla.
      expect(mitadDe(curvaArco(a, b, amplitud: 0)).dy, closeTo(0, 0.01));
    });

    test('el reparto adelanta la curva hacia la punta', () {
      // Es lo que hace que el giro de fila salga del nodo de costado y
      // esquive el renglón de monedas que cuelga debajo. Con el reparto
      // parejo, a un cuarto del tramo el trazo todavía va casi derecho.
      Offset aUnCuarto(double reparto) {
        final medida = curvaArco(
          const Offset(0, 0),
          const Offset(0, 146),
          amplitud: 0.26,
          reparto: reparto,
        ).computeMetrics().first;
        return medida.getTangentForOffset(medida.length * 0.25)!.position;
      }

      expect(aUnCuarto(0.22).dx.abs(), greaterThan(aUnCuarto(0.4).dx.abs()));
    });
  });

  group('Cada círculo dice qué semana es', () {
    testWidgets('las semanas que no corren llevan el rótulo SEM', (t) async {
      await montarCamino(t);

      // "SEM 7" y no un 7 suelto: en esta pantalla hay números de semana
      // y de monedas, y adentro de un círculo los dos se ven igual. Lo que el usuario necesita saber al mirar adelante es a
      // qué SEMANA va a entrar.
      final quietas = objetivos.semanas
          .where((s) => s.estado != EstadoSemana.enCurso)
          .length;
      expect(find.text('SEM'), findsNWidgets(quietas));

      for (final s in objetivos.semanas) {
        if (s.estado == EstadoSemana.enCurso) continue;
        expect(
          find.descendant(
            of: find.byKey(llaveCirculoSemana(s.numero)),
            matching: find.text('SEM'),
          ),
          findsOneWidget,
          reason: 'el círculo de la semana ${s.numero} no dice que es semana',
        );
      }
    });

    testWidgets('la que corre no lo repite: ya lo dice su etiqueta', (t) async {
      await montarCamino(t);

      // Arriba de ese nodo está la única etiqueta del camino y dice
      // "Semana 3" con todas las letras. Meterle "SEM" adentro sería
      // decir lo mismo dos veces en 30 px.
      expect(
        find.descendant(
          of: find.byKey(llaveCirculoSemana(objetivos.enCurso!.numero)),
          matching: find.text('SEM'),
        ),
        findsNothing,
      );
    });
  });

  group('Una sola cosa levantada, y es el camino', () {
    testWidgets('lo que paga la semana no va en una pastilla blanca', (
      t,
    ) async {
      await montarCamino(t);

      // Diez pastillas blancas flotando sobre el camino eran diez
      // tarjetitas más. El fondo que corta la cinta ahora es del color
      // del fondo de pantalla: hace el mismo trabajo sin verse.
      final monedas = objetivos.enCurso!.monedas;
      final fondo = t.widget<Container>(
        find
            .ancestor(
              of: find.text('+$monedas').first,
              matching: find.byType(Container),
            )
            .first,
      );

      expect((fondo.decoration! as BoxDecoration).color, isNot(AppColors.card));
    });
  });
}
