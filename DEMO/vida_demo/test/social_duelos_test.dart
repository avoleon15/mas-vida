import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/screens/social_screen.dart';
import 'package:vida_demo/widgets/contadores_amigos.dart';
import 'package:vida_demo/widgets/numero_animado.dart' show milesConComa;

import 'ayudas.dart';

// ============================================================
// LA PESTAÑA AMIGOS DE SOCIAL.
//
// Lo que este archivo protege son cuatro decisiones del 22 de septiembre
// de 2026:
//
//   · LOS TRES NÚMEROS VAN PRIMEROS, como en un perfil de Instagram, y
//     dicen tres cosas DISTINTAS: quién te sigue, qué está esperando
//     respuesta y qué tenés en juego ahora.
//   · NO HAY LISTA DE AMIGOS. Era la misma lista que abre el contador
//     de arriba, y entre dos listas de gente el duelo —lo único que
//     está pasando— quedaba aplastado.
//   · UN DUELO DICE CONTRA QUIÉN ES Y CÓMO SE GANA. Sin la regla a la
//     vista, dos barras al lado se leen como una carrera de pasos, que
//     es justo lo que un duelo no es.
//   · EL HISTORIAL TIENE NOMBRES. Eran cinco siluetas grises iguales.
// ============================================================

Future<void> montar(WidgetTester t) async {
  t.view.physicalSize = const Size(390, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  await montarPantalla(t, const SocialScreen());
  await t.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  group('Los tres números van primeros', () {
    testWidgets('dicen tres cosas distintas', (t) async {
      await montar(t);
      final social = Datos.i.social;

      // Acotado a la fila: "Amigos" es también el nombre de la pestaña
      // que está justo arriba.
      Finder enLaFila(String texto) => find.descendant(
        of: find.byType(ContadoresAmigos),
        matching: find.text(texto),
      );

      expect(enLaFila('Amigos'), findsOneWidget);
      expect(enLaFila('Solicitudes'), findsOneWidget);
      // "Duelos activos" y no "Duelos": el número cuenta los que están
      // corriendo, no los que se jugaron en la vida.
      expect(find.text('Duelos activos'), findsOneWidget);

      expect(find.text('${social.conexiones.length}'), findsWidgets);
      expect(find.text('${social.solicitudesRecibidas.length}'), findsWidgets);
    });

    testWidgets('están arriba del duelo', (t) async {
      await montar(t);

      // El orden es la decisión: antes la pestaña abría con el bloque de
      // duelos y los números vivían al fondo, después del historial.
      expect(
        t
            .getTopLeft(
              find.descendant(
                of: find.byType(ContadoresAmigos),
                matching: find.text('Amigos'),
              ),
            )
            .dy,
        lessThan(t.getTopLeft(find.text('DUELO ACTIVO')).dy),
      );
    });
  });

  group('Social ya no lista a los amigos', () {
    testWidgets('no está la lista ni su "ver todos"', (t) async {
      await montar(t);

      expect(find.text('Tus amigos'), findsNothing);
      expect(find.text('Ver todos'), findsNothing);
    });

    testWidgets('una conexión que no está en duelo no aparece', (t) async {
      await montar(t);

      // La rival del duelo SÍ se nombra, así que se busca a otra: si la
      // lista volviera, esta aparecería.
      final duelo = Datos.i.social.duelo;
      final jugados = Datos.i.social.historialDuelos
          .map((d) => d.rival)
          .toSet();
      final otra = Datos.i.social.conexiones.firstWhere(
        (c) => c.handle != duelo.rivalHandle && !jugados.contains(c.handle),
      );
      expect(find.text(otra.nombre), findsNothing);
    });
  });

  group('El duelo es un RETO con meta', () {
    testWidgets('lo primero que se lee es a qué se retaron', (t) async {
      await montar(t);
      final d = Datos.i.social.duelo;

      // Un duelo es un número al que los dos van. Sin verlo, el resto de
      // la tarjeta no significa nada.
      expect(find.text('${milesConComa(d.metaPasos)} pasos'), findsOneWidget);
      expect(find.text('${d.plazo}, contra ${d.rivalDicho}'), findsOneWidget);
    });

    testWidgets('la meta está arriba de los marcadores', (t) async {
      await montar(t);
      final d = Datos.i.social.duelo;

      expect(
        t.getTopLeft(find.text('${milesConComa(d.metaPasos)} pasos')).dy,
        lessThan(t.getTopLeft(find.text('Vos')).dy),
      );
    });

    testWidgets('de cada uno dice pasos, meta y cuánto falta', (t) async {
      await montar(t);
      final d = Datos.i.social.duelo;

      // Antes decía "+18% sobre tu promedio", que no se puede usar: no
      // dice cuánto falta ni qué hacer hoy.
      expect(find.text(milesConComa(d.pasosPropios)), findsOneWidget);
      expect(find.text(milesConComa(d.pasosRival)), findsOneWidget);
      expect(find.text(' de ${milesConComa(d.metaPasos)}'), findsNWidgets(2));
      expect(
        find.textContaining('Le faltan ${milesConComa(d.faltanRival)}'),
        findsOneWidget,
      );
    });

    testWidgets('a vos te dice además a qué ritmo tenés que ir', (t) async {
      await montar(t);
      final d = Datos.i.social.duelo;
      final ritmo = d.ritmoNecesario!;

      // Es lo único que la tarjeta puede pedirte hoy. Del rival no se
      // muestra: su ritmo no es algo que vos puedas hacer.
      expect(
        find.text(
          'Te faltan ${milesConComa(d.faltanPropios)} · '
          '${milesConComa(ritmo)} por día',
        ),
        findsOneWidget,
      );
    });

    testWidgets('el rival se nombra, no es solo un arroba', (t) async {
      await montar(t);
      final d = Datos.i.social.duelo;

      expect(find.textContaining(d.rivalDicho), findsWidgets);
    });

    testWidgets('dice cómo vas en pasos, no en porcentajes', (t) async {
      await montar(t);
      final d = Datos.i.social.duelo;

      expect(
        find.text('Vas arriba por ${milesConComa(d.ventaja)} pasos'),
        findsOneWidget,
      );
      // Y cómo se gana, que es lo que dos barras al lado no cuentan.
      expect(
        find.textContaining('Gana el primero que llegue a la meta'),
        findsOneWidget,
      );
    });
  });

  group('El historial tiene nombres', () {
    testWidgets('cada duelo jugado dice contra quién fue', (t) async {
      await montar(t);
      final historial = Datos.i.social.historialDuelos;

      for (final d in historial) {
        expect(
          find.text(d.dicho),
          findsWidgets,
          reason: 'el duelo contra ${d.rival} no dice contra quién fue',
        );
      }
    });

    testWidgets('el resultado se dice con palabras, no con una W', (t) async {
      await montar(t);
      final historial = Datos.i.social.historialDuelos;
      final ganados = historial.where((d) => d.ganado).length;

      expect(find.text('Ganaste'), findsNWidgets(ganados));
      expect(find.text('Perdiste'), findsNWidgets(historial.length - ganados));
      // Y el marcador, que es lo que un historial contesta de un vistazo.
      expect(
        find.text('Ganaste $ganados de ${historial.length}'),
        findsOneWidget,
      );
    });
  });

  group('Retar a alguien', () {
    testWidgets('ya no es un botón con relieve arriba del duelo', (t) async {
      await montar(t);

      expect(find.text('Nuevo duelo'), findsNothing);
      expect(find.text('Retar a alguien'), findsOneWidget);
    });

    testWidgets('cierra el bloque, debajo del duelo', (t) async {
      await montar(t);

      // Donde el ojo termina de leer lo que ya hay y empieza lo que se
      // puede hacer.
      expect(
        t.getTopLeft(find.text('Retar a alguien')).dy,
        greaterThan(t.getTopLeft(find.text('DUELO ACTIVO')).dy),
      );
    });
  });
}
