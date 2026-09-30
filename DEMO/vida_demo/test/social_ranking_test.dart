import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/screens/ranking_grupo_screen.dart';
import 'package:vida_demo/screens/social_screen.dart';
import 'package:vida_demo/widgets/avatar_usuario.dart';
import 'package:vida_demo/widgets/ranking_widgets.dart';

import 'ayudas.dart';

// ============================================================
// SOCIAL: La Liga arriba y Mis competencias debajo, en una sola pantalla
// (rediseño del 25 de septiembre de 2026). Sin amigos ni solicitudes: a
// una competencia se entra con un código.
//
// Lo que no se puede romper: que los puntos de la gente de La Liga nunca
// se vean, y que la distancia al podio se diga en PUESTOS y no en puntos.
// ============================================================

GrupoRanking get _liga => Datos.i.social.ligaLocal!;

Future<void> _montar(WidgetTester t) async {
  t.view.physicalSize = const Size(390, 1400);
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

  group('Una sola pantalla', () {
    testWidgets('no hay pestañas: La Liga y Mis competencias juntas', (
      t,
    ) async {
      await _montar(t);
      expect(find.byKey(llaveTarjetaLiga), findsOneWidget);
      expect(find.text('MIS COMPETENCIAS'), findsOneWidget);
      for (final g in Datos.i.social.deConocidos) {
        expect(find.text(g.nombre), findsOneWidget, reason: g.nombre);
      }
      // Nada de la estructura vieja.
      expect(find.text('Liga local'), findsNothing);
      expect(find.textContaining('TU SEMANA'), findsNothing);
    });

    testWidgets('La Liga va arriba de Mis competencias', (t) async {
      await _montar(t);
      expect(
        t.getTopLeft(find.byKey(llaveTarjetaLiga)).dy,
        lessThan(t.getTopLeft(find.text('MIS COMPETENCIAS')).dy),
      );
    });
  });

  group('La Liga', () {
    testWidgets('dice el puesto y de cuántos', (t) async {
      await _montar(t);
      expect(find.text('${_liga.posicionUsuario}.º'), findsOneWidget);
      expect(find.text('de ${_liga.miembros.length}'), findsOneWidget);
      // Ya no se arma por zona.
      expect(find.textContaining('Zona'), findsNothing);
    });

    testWidgets('la tarjeta va limpia: sin foto, puntos ni franja', (t) async {
      await _montar(t);
      final tarjeta = find.byKey(llaveTarjetaLiga);
      expect(
        find.descendant(of: tarjeta, matching: find.byType(AvatarUsuario)),
        findsNothing,
      );
      expect(
        find.descendant(of: tarjeta, matching: find.textContaining('pts')),
        findsNothing,
      );
      expect(
        find.descendant(of: tarjeta, matching: find.text(_liga.franjaEdad!)),
        findsNothing,
      );
    });

    testWidgets('la franja de edad sale en la tabla', (t) async {
      await montarPantalla(t, RankingGrupoScreen(grupo: _liga));
      await t.pump();
      expect(find.textContaining(_liga.franjaEdad!), findsOneWidget);
    });

    testWidgets('tocarla abre la tabla', (t) async {
      await _montar(t);
      await t.tap(find.byKey(llaveTarjetaLiga));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(RankingGrupoScreen), findsOneWidget);
    });
  });

  group('Mis competencias', () {
    testWidgets('cada competencia abre su tabla', (t) async {
      await _montar(t);
      await t.tap(find.text('Familia'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(RankingGrupoScreen), findsOneWidget);
    });

    testWidgets('crear o unirse ofrece las dos cosas, sin solicitudes', (
      t,
    ) async {
      await _montar(t);
      await t.tap(find.byKey(llaveCrearOUnirse));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Crear una competencia'), findsOneWidget);
      expect(find.text('Unirme con un código'), findsOneWidget);
      expect(find.textContaining('olicitud'), findsNothing);
    });

    testWidgets('crear una competencia abre el código para compartir', (
      t,
    ) async {
      await _montar(t);
      await t.tap(find.byKey(llaveCrearOUnirse));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Crear una competencia'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      await t.enterText(find.byType(EditableText).first, 'Los del gym');
      await t.pump();
      await t.tap(find.text('Crear competencia'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));

      // Lo que sigue a crear es invitar, sin ir a buscar dónde.
      expect(find.text('¡Los del gym está lista!'), findsOneWidget);
      expect(find.text('Compartir'), findsOneWidget);

      Datos.i.social.grupos.removeWhere((g) => g.nombre == 'Los del gym');
    });
  });

  group('La tabla', () {
    testWidgets('en La Liga solo se ven los puntos propios', (t) async {
      t.view.physicalSize = const Size(390, 2000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await montarPantalla(t, RankingGrupoScreen(grupo: _liga));
      await t.pump();

      for (final otro in _liga.miembros.where((m) => !m.esUsuario)) {
        expect(
          find.textContaining('${otro.puntosPeriodo}'),
          findsNothing,
          reason: 'se filtraron los puntos de ${otro.nombre}',
        );
      }
    });

    testWidgets('dice TABLA DEL MES, no de la semana', (t) async {
      await montarPantalla(t, RankingGrupoScreen(grupo: _liga));
      await t.pump();
      expect(find.text('TABLA DEL MES'), findsOneWidget);
      expect(find.textContaining('SEMANA'), findsNothing);
    });

    testWidgets('los tres primeros van en el podio y no en la tabla', (
      t,
    ) async {
      final grupo = Datos.i.social.deConocidos.firstWhere(
        (g) => g.miembros.length > 3,
      );
      t.view.physicalSize = const Size(390, 2000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await montarPantalla(t, RankingGrupoScreen(grupo: grupo));
      await t.pump();

      expect(find.byType(PodioRanking), findsOneWidget);
      expect(
        find.byType(FilaRanking),
        findsNWidgets(grupo.miembros.length - 3),
      );
    });
  });

  group('Privacidad de los puntos', () {
    test('La Liga nunca muestra puntos, aunque el JSON diga que sí', () {
      final liga = GrupoRanking(
        id: 'x',
        nombre: 'La Liga',
        tipo: TipoGrupo.desconocidos,
        mostrarPuntos: true,
        miembros: const [],
      );
      expect(liga.mostrarPuntos, isFalse);
    });

    test('una competencia respeta lo que eligió quien la creó', () {
      GrupoRanking conocidos({required bool ver}) => GrupoRanking(
        id: 'x',
        nombre: 'Oficina',
        tipo: TipoGrupo.conocidos,
        mostrarPuntos: ver,
        miembros: const [],
      );
      expect(conocidos(ver: true).mostrarPuntos, isTrue);
      expect(conocidos(ver: false).mostrarPuntos, isFalse);
    });
  });
}
