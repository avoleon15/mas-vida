import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getwidget/getwidget.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/reglas_rango.dart';
import 'package:vida_demo/screens/camino_semanas_screen.dart';
import 'package:vida_demo/widgets/patrocinio.dart';
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
      // Sin el "de 10": cuantas tiene el programa lo dice el boton de
      // arriba ("Ver las 10 semanas"). Aca solo hace falta en cual va.
      expect(find.text('Semana ${s.numero}'), findsWidgets);
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
    testWidgets('no repite la semana ni rotula el rango', (t) async {
      await montarHome(t);
      // La semana la dice el titular. Repetirla en el pie era decir dos
      // veces lo mismo a diez centímetros de distancia.
      expect(find.textContaining('SEMANA'), findsNothing);
      // Y el rango tampoco: ese dato vive en la insignia del camino, un
      // medallon con el numero adentro y diez muescas alrededor. Aca era
      // un rotulo suelto encima de una tira que cuenta SEMANAS, o sea
      // explicando mal a lo que tenia debajo.
      expect(find.text('RANGO ${objetivos.rangoActual}'), findsNothing);
      expect(find.textContaining('RANGO'), findsNothing);
    });

    testWidgets('la marca de la semana va al lado del titular', (t) async {
      await montarHome(t);
      final marca = objetivos.enCurso!.patrocinio!.marca;

      // La pildora con el logo y el color de la marca, no la cinta de
      // dos renglones que estaba al fondo de la tarjeta.
      expect(find.bySemanticsLabel('Patrocinada por $marca'), findsOneWidget);
      // La cinta vieja decia "PATROCINA MONTANOS" en un bloque aparte,
      // con el logo repetido y dos renglones de texto.
      expect(find.textContaining('PATROCINA $marca'), findsNothing);

      // El rotulo dice QUE es esa marca ahi, no solo su nombre.
      expect(find.text('PATROCINADO POR'), findsOneWidget);

      // Y a la DERECHA del titular, no debajo.
      final titular = t.getTopLeft(
        find.text('Semana ${objetivos.enCurso!.numero}'),
      );
      expect(
        t.getTopLeft(find.byType(ChipMarcaSemana)).dx,
        greaterThan(titular.dx),
      );
    });

    testWidgets('el titular no se corta con puntos suspensivos', (t) async {
      await montarHome(t);
      // "Semana 3 de 10" mas la tarjetita de la marca no entran en un
      // iPhone: el titular terminaba en "Semana 3 de ...", que pierde el
      // numero que importa y encima se ve roto.
      expect(find.textContaining('…'), findsNothing);
      expect(find.textContaining('Semana 3 de'), findsNothing);
    });

    testWidgets('la franja del pie ya no existe', (t) async {
      await montarHome(t);
      final paso = objetivos.pasoDe(objetivos.enCurso!.numero)!;

      // La tira de diez marcas decia por que semana va, que es lo mismo
      // que el titular dice con palabras quince centimetros mas arriba.
      expect(find.byKey(const ValueKey('tira-semanas')), findsNothing);
      // Y el chip de monedas vive en el nodo del camino, que es donde
      // se compara contra lo que pagan las otras nueve semanas.
      expect(find.text('+${paso.monedas}'), findsNothing);
    });
  });

  group('El pie de la tarjeta es el botón del camino', () {
    testWidgets('se ve sin tocar nada y dice cuántas semanas son', (t) async {
      await montarHome(t);
      expect(find.byKey(llaveBotonCamino), findsOneWidget);
      expect(
        find.text('Ver las ${objetivos.semanas.length} semanas'),
        findsOneWidget,
      );
    });

    testWidgets('va DEBAJO de los tres objetivos, no arriba de todo', (
      t,
    ) async {
      await montarHome(t);
      final ultimo = objetivos.enCurso!.objetivos.last;

      // Estaba flotando entre el encabezado de la seccion y la tarjeta,
      // pegado a otro renglon azul: se leia como un rotulo mas.
      expect(
        t.getTopLeft(find.byKey(llaveBotonCamino)).dy,
        greaterThan(t.getTopLeft(find.byKey(llaveObjetivo(ultimo.id))).dy),
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

    testWidgets('el plazo se dice UNA vez, al lado del conteo', (t) async {
      await montarHome(t);
      final enCurso = objetivos.enCurso!;

      // Sigue siendo uno solo para los tres objetivos —esa es la regla
      // que lo puso ahi—, pero ahora son tres palabras y no un bloque.
      expect(find.text(plazoCorto(enCurso)), findsOneWidget);
      expect(
        t.getTopLeft(find.text(plazoCorto(enCurso))).dy,
        lessThan(
          t.getTopLeft(find.byKey(llaveObjetivo(enCurso.objetivos.first.id))).dy,
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
