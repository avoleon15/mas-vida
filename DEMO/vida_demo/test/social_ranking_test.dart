import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/screens/ranking_grupo_screen.dart';
import 'package:vida_demo/screens/social_screen.dart';
import 'package:vida_demo/theme.dart';

// ============================================================
// La pestaña Ranking separa dos mundos que NO se pueden mezclar: los
// grupos privados y la liga local con desconocidos.
//
// Estos tests fijan esa separación y la regla de privacidad de los
// puntos, que es lo que no se puede romper sin exponer a alguien.
// ============================================================

Future<void> _montar(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.temaClaro,
      home: const TemaVida(child: SocialScreen()),
    ),
  );
  // Ir a la pestaña Ranking (la pantalla abre en Amigos).
  await tester.tap(find.text('Ranking'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  group('Ranking separa grupos de la liga local', () {
    testWidgets('la liga local no aparece entre mis grupos', (tester) async {
      await _montar(tester);

      // Los grupos de conocidos sí están en la lista.
      expect(find.text('Familia'), findsOneWidget);
      expect(find.text('Oficina'), findsOneWidget);

      // La liga NO. No se puede buscar su nombre, porque el segmento se
      // llama igual: se busca lo que solo sale en su tarjeta.
      final liga = Datos.i.social.ligaLocal!;
      expect(find.text(liga.zona!), findsNothing);
      // Y hay exactamente una fila por grupo privado, ni una de más.
      expect(
        find.byIcon(CupertinoIcons.chevron_right),
        findsNWidgets(Datos.i.social.deConocidos.length),
      );
    });

    testWidgets('la liga local vive en su propio segmento', (tester) async {
      await _montar(tester);

      await tester.tap(find.text('Liga local'));
      await tester.pumpAndSettle();

      final liga = Datos.i.social.ligaLocal!;
      expect(find.text(liga.nombre), findsWidgets);
      // Y ahí ya no se listan los grupos privados.
      expect(find.text('Familia'), findsNothing);
    });
  });

  group('Lista de grupos', () {
    testWidgets('cada grupo abre su propia tabla', (tester) async {
      await _montar(tester);

      // La tarjeta de resumen empuja la lista fuera de la pantalla de
      // prueba (800x600): hay que traer la fila a la vista antes.
      await tester.ensureVisible(find.text('Familia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Familia'));
      await tester.pumpAndSettle();

      expect(find.byType(RankingGrupoScreen), findsOneWidget);
    });

    testWidgets('el buscador filtra por nombre', (tester) async {
      await _montar(tester);

      // El buscador solo aparece cuando hay suficientes grupos como para
      // necesitarlo; con los del mock todavía no.
      if (find.byType(CupertinoSearchTextField).evaluate().isEmpty) {
        expect(Datos.i.social.deConocidos.length, lessThan(5));
        return;
      }

      await tester.enterText(find.byType(CupertinoSearchTextField), 'fami');
      await tester.pumpAndSettle();

      expect(find.text('Familia'), findsOneWidget);
      expect(find.text('Oficina'), findsNothing);
    });
  });

  group('Privacidad de los puntos', () {
    test('una liga de desconocidos nunca muestra puntos', () {
      // Aunque el JSON diga que sí: el tipo manda.
      final liga = GrupoRanking(
        id: 'x',
        nombre: 'Liga',
        tipo: TipoGrupo.desconocidos,
        mostrarPuntos: true,
        miembros: const [],
      );
      expect(liga.mostrarPuntos, isFalse);
    });

    test('un grupo de conocidos respeta lo que eligió quien lo creó', () {
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

    testWidgets('en la liga solo se ven los puntos propios', (tester) async {
      final liga = Datos.i.social.ligaLocal!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.temaClaro,
          home: TemaVida(child: RankingGrupoScreen(grupo: liga)),
        ),
      );
      await tester.pumpAndSettle();

      final yo = liga.miembros.firstWhere((m) => m.esUsuario);
      expect(find.text('${yo.puntosSemana}'), findsOneWidget);

      // Los de los demás no están en ningún lado.
      for (final otro in liga.miembros.where((m) => !m.esUsuario)) {
        expect(
          find.text('${otro.puntosSemana}'),
          findsNothing,
          reason: 'se filtraron los puntos de ${otro.nombre}',
        );
      }
    });
  });
}
