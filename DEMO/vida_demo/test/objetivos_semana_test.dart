import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/screens/semanas_temporada_screen.dart';
import 'package:vida_demo/theme.dart';
import 'package:vida_demo/widgets/pase_temporada.dart';
import 'package:vida_demo/widgets/patrocinio.dart';
import 'package:vida_demo/widgets/premio_semana.dart';
import 'package:vida_demo/widgets/semanas_objetivos.dart';
import 'package:vida_demo/widgets/tarjeta_semana.dart';

import 'ayudas.dart';

/// La sección "Esta semana" de Hoy y la pantalla con las semanas de la
/// temporada.
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

  group('Los objetivos tienen nombre a la vista', () {
    testWidgets('los dos nombres se leen sin tocar nada', (t) async {
      await montarHome(t);

      // Es la razón de ser del rediseño. Antes había que tocar un círculo
      // y abrir un action sheet para saber de qué objetivo se trataba.
      // En la columna va el nombre corto ("Pasos", "Entrenamiento");
      // VoiceOver dice el nombre completo.
      for (final corto in ['Pasos', 'Entrenamientos']) {
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

      // Sin las comas de miles: "41,200" es 41200.
      expect(
        avanceDicho(pendiente).replaceAll(',', ''),
        contains('${pendiente.progreso}'),
      );
      expect(
        avanceDicho(pendiente).replaceAll(',', ''),
        contains('de ${pendiente.meta}'),
      );
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
        monedas: 5,
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
        monedas: 5,
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
        monedas: 5,
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
        monedas: 5,
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

  group('La tarjeta de la semana', () {
    testWidgets('una semana cerrada dice cuántos objetivos se cumplieron', (
      t,
    ) async {
      // La temporada del mock arranca esta semana: todavía no hay una
      // cerrada, así que se arma una.
      final s = SemanaObjetivos(
        numero: 13,
        cierra: DateTime.utc(2026, 9, 28, 5, 59, 59),
        estado: EstadoSemana.cerrada,
        objetivos: const [
          ObjetivoSemanal(
            id: 'pasos_semana',
            nombre: 'Pasos de la semana',
            progreso: 47000,
            meta: 45000,
            unidad: 'pasos',
            completo: true,
            monedas: 5,
          ),
          ObjetivoSemanal(
            id: 'workouts_semana',
            nombre: 'Entrenamientos de la semana',
            progreso: 0,
            meta: 1,
            unidad: 'entrenamientos',
            completo: false,
            monedas: 5,
          ),
        ],
      );
      await montarPantalla(
        t,
        Scaffold(body: TarjetaSemana(semana: s, conTitulo: false)),
      );
      await t.pump();
      expect(
        find.textContaining(
          '${s.cumplidos} de ${s.objetivos.length} objetivos',
        ),
        findsOneWidget,
      );
    });

    testWidgets('los dos objetivos van desplegados, uno debajo del otro', (
      t,
    ) async {
      await montarHome(t);
      final [primero, segundo] = objetivos.enCurso!.objetivos;

      // Lado a lado se veían apretados (pedido de Daniel, 2 de octubre
      // de 2026): cada uno tiene su renglón a lo ancho.
      final a = t.getRect(find.byKey(llaveObjetivo(primero.id)));
      final b = t.getRect(find.byKey(llaveObjetivo(segundo.id)));
      expect(b.top, greaterThan(a.bottom));
      expect(b.left, a.left);
      expect(b.width, a.width);
    });

    testWidgets('una semana futura avisa en grande que no empieza', (t) async {
      final futura = objetivos.semanas.firstWhere(
        (s) => s.estado == EstadoSemana.futura,
      );
      await montarPantalla(
        t,
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: TarjetaSemana(semana: futura, conTitulo: false),
          ),
        ),
      );
      await t.pump();

      final aviso = find.text('Todavía no empieza');
      expect(aviso, findsOneWidget);
      // Más grande que la letra chica del pie, y ARRIBA de los objetivos.
      expect(t.widget<Text>(aviso).style!.fontSize, greaterThan(16));
      expect(
        t.getTopLeft(aviso).dy,
        lessThan(
          t.getTopLeft(find.byKey(llaveObjetivo(futura.objetivos.first.id))).dy,
        ),
      );
    });

    testWidgets('el plazo se dice UNA vez, abajo del premio, con la hora', (
      t,
    ) async {
      await montarHome(t);
      final enCurso = objetivos.enCurso!;
      final plazo = find.text('Esta semana ${plazoCorto(enCurso)}');

      // Pedido de Daniel, 2 de octubre de 2026: "Esta semana termina el
      // domingo 4 de octubre a las 11:59 PM", debajo del patrocinio.
      expect(plazo, findsOneWidget);
      expect(find.textContaining('11:59 PM'), findsOneWidget);
      expect(
        t.getTopLeft(plazo).dy,
        greaterThan(t.getTopLeft(find.byKey(llavePremioSemana)).dy),
      );
    });

    test(
      'el plazo nombra el día, el número y el mes, en hora de Guatemala',
      () {
        // La semana en curso del mock cierra el domingo 4 de octubre a las
        // 23:59:59 de Guatemala, que en UTC ya es lunes 5.
        final enCurso = objetivos.enCurso!;
        expect(
          plazoCorto(enCurso),
          'termina el domingo 4 de octubre a las 11:59 PM',
        );
        final siguiente = objetivos.semanas[enCurso.numero];
        expect(plazoCorto(siguiente), 'arranca el lunes 5 de octubre');
      },
    );

    testWidgets('sin párrafos de calendario', (t) async {
      await montarHome(t);
      expect(find.textContaining('Los tres cierran'), findsNothing);
      expect(find.textContaining('12:00'), findsNothing);
    });

    testWidgets('el premio va pegado al segundo objetivo', (t) async {
      await montarHome(t);
      final segundo = objetivos.enCurso!.objetivos.last;
      final abajoDelSegundo = t
          .getRect(find.byKey(llaveObjetivo(segundo.id)))
          .bottom;
      final arribaDelPremio = t.getRect(find.byKey(llavePremioSemana)).top;
      expect(arribaDelPremio - abajoDelSegundo, lessThanOrEqualTo(12));
    });

    testWidgets('una semana futura está bloqueada, con candado', (t) async {
      final futura = objetivos.semanas.firstWhere(
        (s) => s.estado == EstadoSemana.futura,
      );
      await montarPantalla(
        t,
        Scaffold(body: TarjetaSemana(semana: futura, conTitulo: false)),
      );
      await t.pump();
      expect(find.byKey(llaveTodaviaNoEmpieza), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.lock_fill), findsWidgets);
      // Los objetivos, a media luz.
      expect(
        find.descendant(
          of: find.byKey(llaveObjetivo(futura.objetivos.first.id)),
          matching: find.byType(Opacity),
        ),
        findsOneWidget,
      );
    });

    testWidgets('las monedas de los dos objetivos van en el mismo lugar', (
      t,
    ) async {
      await montarHome(t);
      final [a, b] = objetivos.enCurso!.objetivos;
      final ra = t.getRect(find.byKey(llaveMonedasObjetivo(a.id)));
      final rb = t.getRect(find.byKey(llaveMonedasObjetivo(b.id)));
      // "Pasos" es más corto que "Entrenamiento", y aun así la pastilla
      // queda pegada al mismo borde.
      expect(ra.right, rb.right);
    });

    testWidgets('el avance es una barra, no un círculo', (t) async {
      await montarHome(t);
      // El anillo de pasos de Hoy es el único círculo de avance de la
      // app (pedido de Daniel, 2 de octubre de 2026).
      expect(find.byType(CircularProgressIndicator), findsNothing);
      for (final o in objetivos.enCurso!.objetivos) {
        expect(
          find.descendant(
            of: find.byKey(llaveObjetivo(o.id)),
            matching: find.byType(FractionallySizedBox),
          ),
          findsOneWidget,
          reason: o.id,
        );
      }
    });

    testWidgets('la marca va abajo, en un renglón chico', (t) async {
      await montarHome(t);
      final s = objetivos.enCurso!;
      final premio = find.byKey(llavePremioSemana);
      expect(premio, findsOneWidget);
      // Chico: la foto grande le quitaba la mirada a los objetivos. El
      // carrusel vive en la card de la semana.
      expect(t.getSize(premio).height, lessThan(80));
      expect(find.byKey(llaveCarruselPremio), findsNothing);
      // Debajo de los objetivos, y diciendo qué se gana.
      expect(
        t.getTopLeft(premio).dy,
        greaterThan(
          t.getTopLeft(find.byKey(llaveObjetivo(s.objetivos.first.id))).dy,
        ),
      );
      expect(find.text(s.patrocinio!.cupon), findsOneWidget);
      // Y sin la frase de antes, que ya no hace falta.
      expect(find.textContaining('la patrocina'), findsNothing);
      expect(find.textContaining('Cumple los dos para'), findsNothing);
    });
  });

  // Reunión del 2 de octubre de 2026: cada objetivo paga sus propias
  // monedas y la semana se marca completada solo con los dos.
  group('Cada objetivo paga lo suyo', () {
    SemanaObjetivos cerrada({required bool cumplida, int monedas = 5}) =>
        SemanaObjetivos(
          numero: 1,
          cierra: DateTime(2026, 9, 6),
          estado: EstadoSemana.cerrada,
          objetivos: [
            ObjetivoSemanal(
              id: 'pasos_semana',
              nombre: 'Pasos de la semana',
              progreso: 40000,
              meta: 30000,
              unidad: 'pasos',
              completo: true,
              monedas: monedas,
            ),
            ObjetivoSemanal(
              id: 'minutos_entrenamiento',
              nombre: 'Minutos de entrenamiento',
              progreso: cumplida ? 80 : 20,
              meta: 60,
              unidad: 'minutos',
              completo: cumplida,
              monedas: monedas,
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

    test('las monedas de la semana son la suma de sus objetivos', () {
      expect(cerrada(cumplida: true).monedas, 10);
    });

    test('con uno solo cumplido, la semana paga ese y no se completa', () {
      final s = cerrada(cumplida: false);
      expect(s.monedasGanadas, 5);
      expect(s.cumplida, isFalse);
    });

    test('con los dos, paga los dos y se completa', () {
      final s = cerrada(cumplida: true);
      expect(s.monedasGanadas, 10);
      expect(s.cumplida, isTrue);
    });

    test('una semana en curso todavía no pagó nada', () {
      expect(objetivos.enCurso!.monedasGanadas, 0);
    });

    testWidgets('en curso, cada objetivo muestra su "+N"', (t) async {
      await montarHome(t);
      for (final o in objetivos.enCurso!.objetivos) {
        expect(
          find.descendant(
            of: find.byKey(llaveMonedasObjetivo(o.id)),
            matching: find.text('+${o.monedas}'),
          ),
          findsOneWidget,
          reason: o.id,
        );
      }
    });

    testWidgets('cerrada con uno solo, el que falló no promete nada', (
      t,
    ) async {
      await montarSemana(t, cerrada(cumplida: false));
      expect(find.byKey(llaveMonedasObjetivo('pasos_semana')), findsOneWidget);
      expect(
        find.byKey(llaveMonedasObjetivo('minutos_entrenamiento')),
        findsNothing,
      );
    });

    testWidgets('cerrada con los dos, dice que se completó', (t) async {
      await montarSemana(t, cerrada(cumplida: true));
      expect(
        find.bySemanticsLabel(RegExp('Ganaste 5 monedas')),
        findsNWidgets(2),
      );
    });

    testWidgets('un objetivo que no paga monedas no dice "+0"', (t) async {
      await montarSemana(t, cerrada(cumplida: true, monedas: 0));
      expect(find.text('+0'), findsNothing);
    });
  });

  group('El botón de las semanas', () {
    testWidgets('dice en qué semana vas y cuántas son', (t) async {
      await montarHome(t);
      final s = objetivos.enCurso!;
      final total = objetivos.semanas.length;
      expect(find.byKey(llaveBotonSemanas), findsOneWidget);
      expect(find.text('Ver las $total semanas'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Semana ${s.numero} de $total. Ver las $total '
          'semanas',
        ),
        findsOneWidget,
      );
    });

    testWidgets('va arriba de los dos objetivos', (t) async {
      await montarHome(t);
      final primero = objetivos.enCurso!.objetivos.first;
      expect(
        t.getTopLeft(find.byKey(llaveBotonSemanas)).dy,
        lessThan(t.getTopLeft(find.byKey(llaveObjetivo(primero.id))).dy),
      );
    });

    testWidgets('Hoy ya no dice cuándo vencen las monedas', (t) async {
      await montarHome(t);
      expect(find.textContaining('vencen el'), findsNothing);
    });

    testWidgets('el saldo vive en la pantalla de la temporada', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await montarPantalla(t, SemanasTemporadaScreen(objetivos: objetivos));
      await t.pump();
      expect(find.text('Temporada ${objetivos.temporada!.numero}'), findsOne);

      // Tocarlo cuenta la temporada en tres datos.
      await t.tap(find.byKey(llaveChipTemporada));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(llaveHojaTemporada), findsOneWidget);
      expect(find.text('${objetivos.monedasGanadas}'), findsOneWidget);
      expect(find.textContaining('con los dos objetivos'), findsOneWidget);
      expect(
        find.text(fechaLargaTemporada(objetivos.temporada!.cierra)),
        findsOneWidget,
      );
    });

    testWidgets('ya no hay resumen "Tu temporada" debajo del carrusel', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await montarPantalla(t, SemanasTemporadaScreen(objetivos: objetivos));
      await t.pump();
      expect(find.text('TU TEMPORADA'), findsNothing);
    });
  });

  group('Las semanas de la temporada', () {
    Future<void> montarSemanas(WidgetTester t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await montarPantalla(t, SemanasTemporadaScreen(objetivos: objetivos));
      await t.pump();
    }

    testWidgets('el botón de Hoy las abre', (t) async {
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await montarHome(t);
      await t.tap(find.byKey(llaveBotonSemanas));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(SemanasTemporadaScreen), findsOneWidget);
      // Deja terminar la invitación a deslizar, que corre sola al abrir.
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('la flecha de volver la cierra', (t) async {
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await montarHome(t);
      await t.tap(find.byKey(llaveBotonSemanas));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byIcon(Icons.arrow_back).first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(SemanasTemporadaScreen), findsNothing);
      expect(find.byKey(llaveBotonSemanas), findsOneWidget);
    });

    testWidgets('abre en la semana en curso, con sus objetivos', (t) async {
      await montarSemanas(t);
      final s = objetivos.enCurso!;
      final card = find.byKey(llaveCardSemana(s.numero));
      expect(card, findsOneWidget);
      // Centrada: su centro cae en el centro de la pantalla.
      expect((t.getCenter(card).dx - 195).abs(), lessThan(2));
      for (final o in s.objetivos) {
        expect(
          find.descendant(of: card, matching: find.byKey(llaveObjetivo(o.id))),
          findsOneWidget,
        );
      }
    });

    testWidgets('las cards de los costados asoman por el borde', (t) async {
      await montarSemanas(t);
      final s = objetivos.enCurso!;
      // La anterior y la siguiente están construidas y una parte se ve:
      // es lo que dice "hay más para los lados".
      // La semana 1 no tiene una anterior: asoma solo la de la derecha.
      final vecinas = [
        s.numero - 1,
        s.numero + 1,
      ].where((n) => n >= 1 && n <= objetivos.semanas.length);
      for (final vecina in vecinas) {
        final card = find.byKey(llaveCardSemana(vecina));
        expect(card, findsOneWidget, reason: 'semana $vecina');
        final caja = t.getRect(card);
        expect(caja.right > 0 && caja.left < 390, isTrue);
        expect(caja.left < 0 || caja.right > 390, isTrue);
      }
    });

    testWidgets('deslizar pasa a la semana siguiente', (t) async {
      await montarSemanas(t);
      final siguiente = objetivos.enCurso!.numero + 1;
      await t.drag(find.byKey(llaveCarruselSemanas), const Offset(-300, 0));
      await t.pumpAndSettle();
      expect(
        (t.getCenter(find.byKey(llaveCardSemana(siguiente))).dx - 195).abs(),
        lessThan(2),
      );
      expect(
        find.bySemanticsLabel(
          'Estás viendo la semana $siguiente de ${objetivos.semanas.length}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('la semana vendida lleva el carrusel del premio', (t) async {
      await montarSemanas(t);
      final s = objetivos.enCurso!;
      expect(
        find.descendant(
          of: find.byKey(llaveCardSemana(s.numero)),
          matching: find.byKey(llaveCarruselPremio),
        ),
        findsOneWidget,
      );
      expect(find.textContaining(s.patrocinio!.cupon), findsWidgets);
    });

    testWidgets('una semana sin marca no deja un hueco al pie', (t) async {
      await montarSemanas(t);
      // La siguiente a la en curso no tiene marca en el mock: en vez del
      // carrusel lleva lo que paga, del mismo alto.
      final sin = objetivos.semanas.firstWhere(
        (s) => s.patrocinio == null && s.numero > objetivos.enCurso!.numero,
      );
      final card = find.byKey(llaveCardSemana(sin.numero));
      expect(
        find.descendant(of: card, matching: find.byKey(llaveCarruselPremio)),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.text('VA A PAGAR')),
        findsOneWidget,
      );
    });

    testWidgets('la semana vendida lleva el logo de su marca', (t) async {
      await montarSemanas(t);
      final s = objetivos.enCurso!;
      expect(
        find.descendant(
          of: find.byKey(llaveCardSemana(s.numero)),
          matching: find.byType(LogoPatrocinio),
        ),
        findsWidgets,
      );
    });
  });
}
