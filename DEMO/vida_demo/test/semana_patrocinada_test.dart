import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/screens/camino_semanas_screen.dart';
import 'package:vida_demo/widgets/patrocinio.dart';

import 'ayudas.dart';

// ============================================================
// LOS LOGOS DE ALIANZAS EN EL CAMINO (revisión de UI del 9 de septiembre
// de 2026).
//
// Lo que hay que proteger no es que el logo aparezca —eso se ve— sino lo
// otro: que el camino se vea IGUAL con logo y sin logo. Si la burbuja de
// una semana patrocinada creciera o se corriera, el camino temblaría al
// bajar y la curva dejaría de pasar por los círculos.
// ============================================================

ObjetivosSemana get objetivos => Datos.i.resumen.objetivosSemana;

Future<void> montarCamino(WidgetTester t) async {
  await montarPantalla(t, CaminoSemanasScreen(objetivos: objetivos));
  await t.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  group('No todas las semanas están patrocinadas', () {
    test('el mock tiene semanas con marca y semanas sin marca', () {
      final conMarca = objetivos.semanas.where((s) => s.tienePatrocinio);
      final sinMarca = objetivos.semanas.where((s) => !s.tienePatrocinio);

      // Las dos cosas tienen que existir, o el diseño solo se estaría
      // probando en uno de sus dos estados.
      expect(conMarca, isNotEmpty);
      expect(sinMarca, isNotEmpty);
    });

    testWidgets('sale un logo por semana patrocinada, ni uno más', (t) async {
      await montarCamino(t);

      final patrocinadas = objetivos.semanas
          .where((s) => s.tienePatrocinio)
          .length;
      expect(find.byType(LogoPatrocinio), findsNWidgets(patrocinadas));
    });
  });

  group('La burbuja no se mueve por tener logo', () {
    testWidgets('todos los círculos miden y se alinean igual', (t) async {
      await montarCamino(t);

      // Se compara el nodo de una semana patrocinada contra el de una sin
      // patrocinar, en el mismo estado (futura), que es donde un cambio
      // de tamaño saltaría.
      final futurasConMarca = objetivos.semanas.where(
        (s) => s.estado == EstadoSemana.futura && s.tienePatrocinio,
      );
      final futurasSinMarca = objetivos.semanas.where(
        (s) => s.estado == EstadoSemana.futura && !s.tienePatrocinio,
      );
      expect(futurasConMarca, isNotEmpty);
      expect(futurasSinMarca, isNotEmpty);

      Size medir(int numero) =>
          t.getSize(find.byKey(llaveNodoSemana(numero)));

      final conMarca = medir(futurasConMarca.first.numero);
      final sinMarca = medir(futurasSinMarca.first.numero);
      expect(
        conMarca,
        sinMarca,
        reason: 'el nodo cambia de tamaño según si la semana está vendida',
      );
    });

    testWidgets('el carril del logo existe aunque no haya logo', (t) async {
      await montarCamino(t);

      // El círculo queda a la MISMA distancia del borde del nodo en las
      // diez semanas. Si el carril del logo apareciera solo cuando hay
      // marca, los nodos patrocinados tendrían su círculo corrido y la
      // curva —que se dibuja aparte, contra los centros calculados— ya no
      // pasaría por ellos.
      double sangria(int numero) =>
          t.getCenter(find.byKey(llaveCirculoSemana(numero))).dx -
          t.getTopLeft(find.byKey(llaveNodoSemana(numero))).dx;

      final primera = sangria(objetivos.semanas.first.numero);
      for (final s in objetivos.semanas) {
        expect(
          sangria(s.numero),
          closeTo(primera, 0.01),
          reason: 'el círculo de la semana ${s.numero} está corrido',
        );
      }
    });
  });

  group('El premio de una semana patrocinada', () {
    testWidgets('dice la marca en el camino', (t) async {
      await montarCamino(t);
      final marca = objetivos.semanas
          .firstWhere((s) => s.tienePatrocinio)
          .patrocinio!
          .marca;
      expect(find.textContaining('Cupón de $marca'), findsWidgets);
    });

    testWidgets('el cupón NO reemplaza a las monedas de la semana', (t) async {
      await montarCamino(t);

      // La semana patrocinada sigue mostrando su monto en monedas. Si
      // alguien cambia el premio de rango por el cupón, esto se cae.
      final paso = objetivos.recorrido.firstWhere(
        (p) => p.semana.tienePatrocinio && p.monedas > 0,
      );
      expect(find.textContaining('+${paso.monedas}'), findsWidgets);
    });
  });
}
