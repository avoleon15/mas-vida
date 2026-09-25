import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getwidget/getwidget.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/theme.dart';
import 'package:vida_demo/screens/camino_semanas_screen.dart';
import 'package:vida_demo/widgets/semanas_objetivos.dart';
import 'package:vida_demo/widgets/tarjeta_semana.dart';

import 'ayudas.dart';

/// La sección "Objetivos de la semana" y el camino de las semanas.
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
    // Tamaño de iPhone y no el 800x600 apaisado que trae flutter_test por
    // defecto: en una ventana ancha la tarjeta del patrocinador —que es
    // apaisada— empuja el camino fuera de cuadro y los toques no llegan
    // a los nodos.
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await montarPantalla(t, CaminoSemanasScreen(objetivos: objetivos));
    await t.pump();
  }

  group('Los objetivos tienen nombre a la vista', () {
    testWidgets('los dos nombres se leen sin tocar nada', (t) async {
      await montarHome(t);

      // Es la razón de ser del rediseño. Antes había que tocar un círculo
      // y abrir un action sheet para saber de qué objetivo se trataba.
      // En la columna va el nombre corto ("Pasos", "Entrenamiento");
      // VoiceOver dice el nombre completo.
      for (final corto in ['Pasos', 'Entrenamiento']) {
        expect(find.text(corto), findsOneWidget);
      }
      for (final o in objetivos.enCurso!.objetivos) {
        expect(
          find.bySemanticsLabel(RegExp('^${o.nombre}: ')),
          findsOneWidget,
          reason: '"${o.nombre}" tiene que estar en la tarjeta',
        );
      }
    });

    testWidgets('cada objetivo tiene su columna', (t) async {
      await montarHome(t);
      for (final o in objetivos.enCurso!.objetivos) {
        expect(find.byKey(llaveObjetivo(o.id)), findsOneWidget);
      }
    });
  });

  group('Un objetivo no se puede marcar', () {
    testWidgets('ninguna fila tiene forma de casilla', (t) async {
      await montarHome(t);

      // La primera persona que probó la app intentó TOCAR el círculo
      // para marcar el objetivo. No hay nada que marcar: los dos los
      // cierra el servidor el domingo 23:59 con los datos de Apple
      // Health, así que un control que no controla nada se siente una
      // app rota. En su lugar va un riel: una barra de 3,5 px pegada al
      // borde izquierdo, que nadie toca.
      for (final o in objetivos.enCurso!.objetivos) {
        final redondos = t
            .widgetList<Container>(
              find.descendant(
                of: find.byKey(llaveObjetivo(o.id)),
                matching: find.byType(Container),
              ),
            )
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .where((d) => d.shape == BoxShape.circle);

        expect(
          redondos,
          isEmpty,
          reason: '"${o.nombre}" volvió a tener un círculo tocable',
        );
      }
    });

    testWidgets('tocarlo abre el detalle, que no tiene nada que marcar', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await montarHome(t);
      final o = objetivos.enCurso!.objetivos.last;

      // Tocar un objetivo abre INFORMACIÓN (pedido de Daniel, 24 de
      // septiembre de 2026), nunca lo marca: lo cierra el servidor. La
      // hoja lo dice con todas las letras.
      await t.tap(find.byKey(llaveObjetivo(o.id)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      expect(find.byKey(llaveDetalleObjetivo), findsOneWidget);
      expect(find.text(o.nombre), findsOneWidget);
      expect(find.text('Cómo se cuenta'), findsOneWidget);
      expect(find.textContaining('No tienes que marcar nada'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(CupertinoCheckbox), findsNothing);
      expect(find.byType(CupertinoSwitch), findsNothing);
    });

    testWidgets('el cumplido se marca con un check suelto, en naranja', (
      t,
    ) async {
      await montarHome(t);

      final hecho = objetivos.enCurso!.objetivos.firstWhere((o) => o.completo);
      final check = t.widget<Icon>(
        find.descendant(
          of: find.byKey(llaveObjetivo(hecho.id)),
          matching: find.byIcon(Icons.check_rounded),
        ),
      );

      // Es uno de los cuatro lugares donde CLAUDE.md deja entrar el
      // naranja: el check de una etapa completada, suelto y sin relleno.
      expect(check.color, AppColors.accentSecondary);
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
      // leían como cuentas regresivas de cada objetivo, cuando los dos
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
      // "1 pasos" era un error visible en pantalla. La unidad venía cruda
      // del JSON y se pegaba sin mirar la cantidad.
      const deUno = ObjetivoSemanal(
        id: 'pasos_semana',
        nombre: 'Pasos de la semana',
        progreso: 0,
        meta: 1,
        unidad: 'pasos',
        completo: false,
      );
      expect(avanceDicho(deUno), '0 de 1 paso');
    });

    test('los minutos se abrevian', () {
      const o = ObjetivoSemanal(
        id: 'minutos_entrenamiento',
        nombre: 'Minutos de entrenamiento',
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
        id: 'minutos_entrenamiento',
        nombre: 'Minutos de entrenamiento',
        progreso: 90,
        meta: 90,
        unidad: 'minutos',
        completo: false,
      );
      expect(avanceDicho(o), 'Casi');
    });

    test('sin meta NO se inventa un número', () {
      // La tabla de metas por semana todavía no existe. Dividir el
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

  // Los objetivos de Hoy SÍ llevan una barra fina desde el rediseño del
  // 24 de septiembre de 2026: con dos objetivos y el número en grande, la
  // barra es lo que dice de un vistazo cuánto falta.
  group('Ninguna barra de progreso en el camino', () {
    testWidgets('ni una', (t) async {
      await montarCamino(t);
      expect(find.byType(GFProgressBar), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('El titular ubica la semana', () {
    testWidgets('el botón del camino dice por qué semana va', (t) async {
      await montarHome(t);
      final s = objetivos.enCurso!;
      // La semana vive EN el botón: se ve sin entrar al camino, y no
      // necesita una etiqueta aparte.
      expect(
        find.descendant(
          of: find.byKey(llaveBotonCamino),
          matching: find.text(
            'Semana ${s.numero} de ${objetivos.semanas.length}',
          ),
        ),
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

    testWidgets('los dos objetivos van lado a lado', (t) async {
      await montarHome(t);
      final [primero, segundo] = objetivos.enCurso!.objetivos;

      // Dos columnas, como las estadísticas de Fitness: el número grande
      // de cada uno se compara de un vistazo.
      final a = t.getTopLeft(find.byKey(llaveObjetivo(primero.id)));
      final b = t.getTopLeft(find.byKey(llaveObjetivo(segundo.id)));
      expect(b.dy, a.dy);
      expect(b.dx, greaterThan(a.dx));
    });
  });

  group('Lo que paga la semana', () {
    testWidgets('en curso dice "+N" y la moneda, como en un juego', (t) async {
      await montarHome(t);
      final s = objetivos.enCurso!;
      expect(
        find.descendant(
          of: find.byKey(llaveMonedasSemana),
          matching: find.text('+${s.monedas}'),
        ),
        findsOneWidget,
      );
      // Sin oración: el premio se ve, no se lee.
      expect(find.textContaining('ganas'), findsNothing);
      expect(find.textContaining('ganás'), findsNothing);
    });

    SemanaObjetivos cerrada({required bool cumplida, int monedas = 10}) =>
        SemanaObjetivos(
          numero: 1,
          cierra: DateTime(2026, 9, 6),
          estado: EstadoSemana.cerrada,
          monedas: monedas,
          objetivos: [
            const ObjetivoSemanal(
              id: 'pasos_semana',
              nombre: 'Pasos de la semana',
              progreso: 40000,
              meta: 30000,
              unidad: 'pasos',
              completo: true,
            ),
            ObjetivoSemanal(
              id: 'minutos_entrenamiento',
              nombre: 'Minutos de entrenamiento',
              progreso: cumplida ? 80 : 20,
              meta: 60,
              unidad: 'minutos',
              completo: cumplida,
            ),
          ],
        );

    Future<void> montarSemana(WidgetTester t, SemanaObjetivos s) async {
      await montarPantalla(
        t,
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: TarjetaSemana(semana: s),
          ),
        ),
      );
      await t.pump();
    }

    testWidgets('cerrada con los dos, muestra lo que ganó', (t) async {
      await montarSemana(t, cerrada(cumplida: true));
      expect(find.text('+10'), findsOneWidget);
      expect(find.bySemanticsLabel('Ganaste 10 monedas'), findsOneWidget);
    });

    testWidgets('cerrada con uno solo, no muestra premio', (t) async {
      await montarSemana(t, cerrada(cumplida: false));
      expect(find.byKey(llaveMonedasSemana), findsNothing);
    });

    testWidgets('una semana que no paga monedas no dice "0 monedas"', (
      t,
    ) async {
      await montarSemana(t, cerrada(cumplida: true, monedas: 0));
      expect(find.byKey(llaveMonedasSemana), findsNothing);
      expect(find.textContaining('0 monedas'), findsNothing);
    });
  });

  group('El pie ubica la semana en el programa', () {
    testWidgets('no repite la semana', (t) async {
      await montarHome(t);
      // La semana la dice el titular. Repetirla en el pie era decir dos
      // veces lo mismo a diez centímetros de distancia.
      expect(find.textContaining('SEMANA'), findsNothing);
    });

    testWidgets('la marca va pegada a la semana y dice que es de ESTA', (
      t,
    ) async {
      await montarHome(t);
      final s = objetivos.enCurso!;
      final marca = s.patrocinio!.marca;
      final renglon = find.bySemanticsLabel('Esta semana la patrocina $marca');

      // Al pie de todo se leía como patrocinadora de la sección entera
      // (pedido de Daniel, 24 de septiembre de 2026). Va entre el botón de
      // la semana y los objetivos, y la frase dice "Esta semana".
      expect(renglon, findsOneWidget);
      final y = t.getTopLeft(renglon).dy;
      expect(y, greaterThan(t.getTopLeft(find.byKey(llaveBotonCamino)).dy));
      expect(
        y,
        lessThan(
          t.getTopLeft(find.byKey(llaveObjetivo(s.objetivos.first.id))).dy,
        ),
      );
    });

    testWidgets('la semana se dice una sola vez', (t) async {
      await montarHome(t);
      // La dice el botón. Una píldora "Semana 3" arriba de un botón que
      // dice "Semana 3 de 10" es la misma cosa dos veces.
      expect(find.textContaining('Semana '), findsOneWidget);
    });
  });

  group('El botón del camino encabeza la sección', () {
    testWidgets('se ve sin tocar nada y dice cuántas semanas son', (t) async {
      await montarHome(t);
      expect(find.byKey(llaveBotonCamino), findsOneWidget);
      expect(find.text('Ver tu camino'), findsOneWidget);
      expect(
        find.textContaining('de ${objetivos.semanas.length}'),
        findsOneWidget,
      );
    });

    testWidgets('va ARRIBA de los dos objetivos', (t) async {
      await montarHome(t);
      final primero = objetivos.enCurso!.objetivos.first;

      // Es la pieza más importante de la sección (rediseño de Daniel, 24
      // de septiembre de 2026): al pie quedaba última, debajo de dos
      // píldoras que pesaban más que ella.
      expect(
        t.getTopLeft(find.byKey(llaveBotonCamino)).dy,
        lessThan(t.getTopLeft(find.byKey(llaveObjetivo(primero.id))).dy),
      );
    });

    testWidgets('abre el camino', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      await montarHome(t);
      await t.tap(find.byKey(llaveBotonCamino));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      expect(find.byType(CaminoSemanasScreen), findsOneWidget);
    });

    testWidgets('en su lugar ya no hay parrafos', (t) async {
      await montarHome(t);

      // Dos oraciones de calendario para cerrar una tarjeta cuyo trabajo
      // es decir que falta hacer esta semana.
      expect(find.textContaining('Los tres cierran'), findsNothing);
      expect(find.textContaining('11:59'), findsNothing);
      expect(find.textContaining('12:00'), findsNothing);
      // Y la promesa del cupon tampoco: ya la hace la pildora de la
      // marca, arriba, al lado del titular.
      expect(find.textContaining('Esta semana paga'), findsNothing);
    });

    testWidgets('el plazo se dice UNA vez, abajo', (t) async {
      await montarHome(t);
      final enCurso = objetivos.enCurso!;

      // Uno solo para los dos objetivos, y debajo de ellos: es la letra
      // chica de la sección, no lo primero que se lee.
      expect(find.text(plazoCorto(enCurso)), findsOneWidget);
      expect(
        t.getTopLeft(find.text(plazoCorto(enCurso))).dy,
        greaterThan(
          t
              .getTopLeft(find.byKey(llaveObjetivo(enCurso.objetivos.first.id)))
              .dy,
        ),
      );
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

    testWidgets('cada nodo dice qué semana es, adentro del círculo', (t) async {
      await montarCamino(t);

      // El numero vive DENTRO del circulo en los tres estados. Antes la
      // semana cumplida mostraba un check, y por eso los diez nodos
      // necesitaban una etiqueta "Semana N" encima: diez cajitas blancas
      // flotando sobre el camino, que es lo que el ojo terminaba leyendo
      // en vez del recorrido.
      for (final s in objetivos.semanas) {
        expect(
          find.descendant(
            of: find.byKey(llaveCirculoSemana(s.numero)),
            matching: find.text('${s.numero}'),
          ),
          findsOneWidget,
          reason: 'el nodo de la semana ${s.numero} no dice cuál es',
        );
      }
    });

    testWidgets('solo la semana en curso lleva etiqueta', (t) async {
      await montarCamino(t);

      expect(find.byKey(llaveEtiquetaEnCurso), findsOneWidget);
      for (final s in objetivos.semanas) {
        if (s.estado == EstadoSemana.enCurso) continue;
        expect(
          find.text('Semana ${s.numero}'),
          findsNothing,
          reason: 'la semana ${s.numero} volvió a rotularse',
        );
      }
    });

    testWidgets('marca cuál es la semana en curso', (t) async {
      await montarCamino(t);

      // Una sola etiqueta rellena de azul, y es la de la semana que
      // corre: es lo que dice "acá estás" ahora que todos los nodos
      // llevan etiqueta.
      expect(find.byKey(llaveEtiquetaEnCurso), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(llaveEtiquetaEnCurso),
          matching: find.text('Semana ${objetivos.enCurso!.numero}'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tocar un nodo abre esa semana en una hoja', (t) async {
      await montarCamino(t);
      final primera = objetivos.semanas.first;

      await t.tap(find.byKey(llaveNodoSemana(primera.numero)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      // La hoja trae la tarjeta de ESA semana, no la de la semana en
      // curso.
      expect(find.text('Semana ${primera.numero}'), findsWidgets);
    });
  });
}
