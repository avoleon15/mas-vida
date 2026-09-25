import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/hora_guatemala.dart';
import 'package:vida_demo/screens/ranking_grupo_screen.dart';
import 'package:vida_demo/screens/social_screen.dart';

import 'ayudas.dart';

// ============================================================
// LOS CICLOS DE COMPETENCIA (revisión de UI del 9 de septiembre de 2026).
//
// La Liga y las competencias con conocidos corren las dos por MES, del
// día 1 al último día del mes en hora de Guatemala (decisión de Alvaro,
// 22 de septiembre de 2026). Los objetivos corren por SEMANA, y esos no
// son un ranking.
//
// La liga llegó a correr por semana (cerraba un domingo, un bug) y
// después por trimestre (modelo viejo). Estos tests están para que no
// vuelva ninguna de las dos.
// ============================================================

Future<void> _abrirLiga(WidgetTester tester) async {
  await montarPantalla(tester, const SocialScreen());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Liga local'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  group('La liga local corre por mes', () {
    test('su ciclo es mensual', () {
      expect(Datos.i.social.ligaLocal!.ciclo, CicloRanking.mes);
    });

    test('cierra el último día de un mes, nunca un domingo cualquiera', () {
      final liga = Datos.i.social.ligaLocal!;
      final cierra = enHoraDeGuatemala(liga.cierra!);

      // El día siguiente cae en otro mes: eso ES ser el último del mes.
      // Se comprueba así y no con una fecha fija para que el test siga
      // sirviendo cuando el mock avance de mes.
      final siguiente = cierra.add(const Duration(days: 1));
      expect(
        siguiente.month,
        isNot(cierra.month),
        reason: 'el ciclo tiene que cerrar el último día del mes',
      );
    });

    test('arranca el día 1 y dura un solo mes', () {
      final liga = Datos.i.social.ligaLocal!;
      final arranca = enHoraDeGuatemala(liga.arranca!);
      final cierra = enHoraDeGuatemala(liga.cierra!);

      expect(arranca.day, 1);
      final meses =
          (cierra.year - arranca.year) * 12 + cierra.month - arranca.month + 1;
      expect(meses, 1, reason: 'la liga no puede abarcar dos meses');
    });

    testWidgets('la pantalla dice el mes, no la semana', (tester) async {
      await _abrirLiga(tester);
      expect(find.textContaining('trimestre'), findsNothing);
      expect(find.textContaining('este mes'), findsWidgets);
      expect(find.textContaining('esta semana'), findsNothing);
    });
  });

  group('Las competencias con conocidos corren por mes', () {
    test('todas las del mock son mensuales', () {
      for (final g in Datos.i.social.deConocidos) {
        expect(g.ciclo, CicloRanking.mes, reason: 'el grupo ${g.nombre}');
      }
    });

    testWidgets('la tabla de un grupo dice el mes', (tester) async {
      final grupo = Datos.i.social.deConocidos.first;
      await montarPantalla(tester, RankingGrupoScreen(grupo: grupo));
      await tester.pumpAndSettle();

      expect(find.textContaining('este mes'), findsWidgets);
      expect(find.textContaining('esta semana'), findsNothing);
    });
  });

  group('El ciclo semanal de los retos NO se tocó', () {
    test('las semanas del programa siguen cerrando un domingo', () {
      for (final s in Datos.i.resumen.objetivosSemana.semanas) {
        expect(
          enHoraDeGuatemala(s.cierra).weekday,
          DateTime.sunday,
          reason: 'la semana ${s.numero} tiene que cerrar un domingo',
        );
      }
    });
  });

  group('El patrocinio del ciclo', () {
    test('la liga trae marca, logo y cupón', () {
      final p = Datos.i.social.ligaLocal!.patrocinio!;
      expect(p.marca, isNotEmpty);
      expect(p.logo, isNotEmpty);
      expect(p.cupon, isNotEmpty);
    });

    test('el cupón se SUMA a las monedas del podio, no las reemplaza', () {
      // Es la regla que más fácil se rompe al "simplificar": si alguien
      // cambia el premio del podio por el cupón, esto se pone rojo.
      final liga = Datos.i.social.ligaLocal!;
      expect(liga.premiosMonedas.length, 3);
      expect(liga.tienePatrocinio, isTrue);
    });

    testWidgets('la marca aparece en la tarjeta de la liga', (tester) async {
      await _abrirLiga(tester);
      final marca = Datos.i.social.ligaLocal!.patrocinio!.marca;
      expect(find.textContaining(marca.toUpperCase()), findsWidgets);
    });
  });
}
