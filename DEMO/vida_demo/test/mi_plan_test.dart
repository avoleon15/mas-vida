import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/screens/mi_plan_screen.dart';
import 'package:vida_demo/theme.dart';

/// Mi Plan: arriba una zona FIJA —el titulo, el cashback del año y el
/// riel de cuatro categorias— y abajo lo unico que cambia: la proyeccion
/// y el calendario, o UNA categoria de poliza.
void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  /// Monta la pantalla con el tema de +Vida y sin animaciones, igual que
  /// lo hace iOS con "Reducir movimiento" activo.
  ///
  /// El alto por defecto es generoso a proposito: la zona de abajo
  /// scrollea, y con un viewport de telefono los `find` de lo que queda
  /// fuera de cuadro no encontrarian nada. Los tests que miran el scroll
  /// o la zona fija usan un alto de telefono de verdad.
  Future<void> montar(
    WidgetTester tester, {
    Size size = const Size(430, 2600),
    double escala = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.temaClaro,
        // El MediaQuery va DENTRO del MaterialApp: afuera, MaterialApp
        // reinyecta el suyo desde la vista y se come el textScaler.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(escala),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: const TemaVida(child: MiPlanScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Las cuatro etiquetas del riel, en orden.
  const categorias = ['Póliza', 'Cobertura', 'Pagos', 'Contacto'];

  /// Los titulos de las cuatro fajas, en el mismo orden.
  const fajas = [
    'Tu póliza',
    'Tu cobertura',
    'Pagos y prima',
    'Tu aseguradora',
  ];

  // ----------------------------------------------------------
  // Layout
  // ----------------------------------------------------------

  testWidgets('no desborda en la pantalla mas chica que soportamos', (
    tester,
  ) async {
    // iPhone SE: 320 de ancho logico es el piso realista, y ahi los
    // cuatro botones del riel tienen 64 px cada uno.
    await montar(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    // Y con una categoria abierta, que es el caso mas cargado.
    await _elegir(tester, 'Contacto');
    expect(tester.takeException(), isNull);
  });

  testWidgets('no desborda con el texto del sistema en grande', (tester) async {
    // Con el texto asi de grande el cabezal deja de estar fijo y vuelve
    // a scrollear con todo lo demas.
    await montar(tester, size: const Size(430, 3200), escala: 1.6);
    expect(tester.takeException(), isNull);
    await _elegir(tester, 'Contacto');
    expect(tester.takeException(), isNull);
  });

  // ----------------------------------------------------------
  // La zona fija
  // ----------------------------------------------------------

  testWidgets('el cabezal y el riel no se van con el scroll', (tester) async {
    await montar(tester, size: const Size(390, 844));
    await _elegir(tester, 'Contacto');

    final montoAntes = tester.getTopLeft(find.text('Q1,800')).dy;
    final rielAntes = tester.getTopLeft(_boton('Pagos')).dy;

    // Se scrollea la zona de abajo hasta el fondo.
    await tester.drag(find.text('Tu aseguradora'), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Q1,800')).dy,
      montoAntes,
      reason: 'el monto del año se movio',
    );
    expect(
      tester.getTopLeft(_boton('Pagos')).dy,
      rielAntes,
      reason: 'el riel se movio',
    );
  });

  testWidgets('los cuatro botones miden lo mismo y van en una fila', (
    tester,
  ) async {
    await montar(tester);

    final tamanos = [
      for (final etiqueta in categorias) tester.getSize(_boton(etiqueta)),
    ];
    for (final tamano in tamanos) {
      expect(tamano, tamanos.first, reason: 'los botones no miden lo mismo');
    }

    final alturas = {
      for (final etiqueta in categorias) tester.getTopLeft(_boton(etiqueta)).dy,
    };
    expect(alturas.length, 1, reason: 'los cuatro arrancan a la misma altura');

    // Y en orden, de izquierda a derecha.
    final equis = [
      for (final etiqueta in categorias) tester.getTopLeft(_boton(etiqueta)).dx,
    ];
    expect(equis, orderedEquals([...equis]..sort()));
  });

  testWidgets('el riel va debajo del monto del año', (tester) async {
    await montar(tester);
    expect(
      tester.getTopLeft(_boton('Póliza')).dy,
      greaterThan(tester.getBottomLeft(find.text('Q1,800')).dy),
    );
  });

  // ----------------------------------------------------------
  // La zona que cambia
  // ----------------------------------------------------------

  testWidgets('al entrar se ve la plata, y ningun dato de poliza', (
    tester,
  ) async {
    await montar(tester);

    expect(find.text('Tu proyección al siguiente nivel'), findsOneWidget);
    expect(find.text('Calendario de pagos'), findsOneWidget);

    for (final faja in fajas) {
      expect(find.text(faja), findsNothing, reason: '$faja no deberia');
    }
    expect(find.text('Número de póliza'), findsNothing);
    expect(find.text('Deducible'), findsNothing);
    expect(find.text('Prima anual'), findsNothing);
    expect(find.text('Emergencias, 24/7'), findsNothing);
    expect(find.byType(CupertinoListSection), findsNothing);
  });

  testWidgets('tocar un boton abre SOLO esa categoria', (tester) async {
    await montar(tester);
    await _elegir(tester, 'Pagos');

    // La faja dice que se abrio, con el nombre completo.
    expect(find.text('ESTÁS VIENDO'), findsOneWidget);
    expect(find.text('Pagos y prima'), findsOneWidget);
    expect(find.text('Prima anual'), findsOneWidget);
    expect(find.byType(CupertinoListSection), findsOneWidget);

    // Y nada de las otras tres, ni de la plata.
    expect(find.text('Tu cobertura'), findsNothing);
    expect(find.text('Deducible'), findsNothing);
    expect(find.text('Emergencias, 24/7'), findsNothing);
    expect(find.text('Calendario de pagos'), findsNothing);
  });

  testWidgets('cambiar de boton reemplaza la categoria abierta', (
    tester,
  ) async {
    await montar(tester);

    await _elegir(tester, 'Cobertura');
    expect(find.text('Deducible'), findsOneWidget);

    await _elegir(tester, 'Contacto');
    expect(find.text('Emergencias, 24/7'), findsOneWidget);
    expect(find.text('Cómo usar tu seguro'), findsOneWidget);
    expect(find.text('Deducible'), findsNothing);
    // El panel de Aseguradora no es una lista agrupada.
    expect(find.byType(CupertinoListSection), findsNothing);
  });

  testWidgets('volver a tocar el boton abierto devuelve a la plata', (
    tester,
  ) async {
    await montar(tester);

    await _elegir(tester, 'Cobertura');
    expect(find.text('Deducible'), findsOneWidget);

    await _elegir(tester, 'Cobertura');
    expect(find.text('Deducible'), findsNothing);
    expect(find.text('Calendario de pagos'), findsOneWidget);
  });

  testWidgets('la X de la faja tambien devuelve a la plata', (tester) async {
    await montar(tester);
    await _elegir(tester, 'Pagos');

    await tester.tap(find.bySemanticsLabel('Cerrar Pagos y prima'));
    await tester.pumpAndSettle();

    expect(find.text('Prima anual'), findsNothing);
    expect(find.text('Calendario de pagos'), findsOneWidget);
  });

  testWidgets('el boton de la categoria abierta se prende, y es azul', (
    tester,
  ) async {
    await montar(tester);

    // Sin elegir nada, ninguno prendido es la respuesta honesta.
    for (final etiqueta in categorias) {
      expect(
        _colorDe(tester, etiqueta),
        AppColors.textPrimary,
        reason: '$etiqueta no deberia arrancar prendido',
      );
    }

    await _elegir(tester, 'Pagos');

    expect(_colorDe(tester, 'Pagos'), Colors.white);
    expect(_colorDe(tester, 'Cobertura'), AppColors.textPrimary);
  });

  // ----------------------------------------------------------
  // El cabezal: la plata
  // ----------------------------------------------------------

  testWidgets('el cabezal muestra el monto y el nivel en el medallon', (
    tester,
  ) async {
    await montar(tester);
    // 10% de la prima de Q18,000.
    expect(find.text('Q1,800'), findsOneWidget);
    // El medallon: la etiqueta y el nivel, no un nombre en ingles.
    expect(find.text('NIVEL'), findsOneWidget);
    expect(find.bySemanticsLabel('Nivel 3'), findsOneWidget);
    expect(find.textContaining('Bronze'), findsNothing);
    expect(find.textContaining('Silver'), findsNothing);
    expect(find.textContaining('Gold'), findsNothing);
    expect(find.textContaining('Platinum'), findsNothing);
  });

  testWidgets('la nota regulatoria nunca se va de la pantalla', (tester) async {
    await montar(tester, size: const Size(390, 844));
    expect(find.textContaining('se devuelve como dinero'), findsOneWidget);

    // Vive en el cabezal, que es fijo: sigue ahi con una categoria
    // abierta y despues de scrollear.
    await _elegir(tester, 'Contacto');
    await tester.drag(find.text('Tu aseguradora'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.textContaining('se devuelve como dinero'), findsOneWidget);
  });

  testWidgets('la prima va completa y sin tachar, y nunca dice descuento', (
    tester,
  ) async {
    await montar(tester);
    await _elegir(tester, 'Pagos');

    // La prima aparece entera en el renglon de apoyo del cabezal y en el
    // panel de Pagos.
    expect(find.textContaining('Q18,000'), findsWidgets);

    // Ni un solo texto tachado en toda la pantalla: tachar la prima
    // diria "pagas menos", que es lo que la Superintendencia de Bancos
    // no permite.
    for (final texto in tester.widgetList<Text>(find.byType(Text))) {
      expect(
        texto.style?.decoration,
        isNot(TextDecoration.lineThrough),
        reason: 'ningun texto de Mi Plan puede ir tachado',
      );
    }

    expect(find.textContaining('descuento'), findsNothing);
    expect(find.textContaining('ahorro en tu póliza'), findsNothing);
    // Y tampoco "aplicado", que se lee como aplicado A la prima.
    expect(find.textContaining('Cashback aplicado'), findsNothing);
  });

  testWidgets('la proyeccion dice cuanto falta y que pagaria el nivel 4', (
    tester,
  ) async {
    await montar(tester);
    // 11,240 de 12,000: faltan 760 para el nivel 4.
    expect(find.textContaining('760 pts', findRichText: true), findsOneWidget);
    // 20% de Q18,000.
    expect(find.textContaining('Q3,600', findRichText: true), findsOneWidget);
    // Nunca promete un nivel por una regresion que no existe.
    expect(find.textContaining('A tu ritmo'), findsNothing);
  });

  // ----------------------------------------------------------
  // La poliza
  // ----------------------------------------------------------

  testWidgets('el marcador de datos sin verificar se ve sin tocar nada', (
    tester,
  ) async {
    await montar(tester);
    // Va en el boton de Contacto, visible de entrada: alguien puede
    // marcar el telefono de emergencias sin abrir la categoria.
    expect(
      find.bySemanticsLabel('Contacto, datos sin verificar'),
      findsOneWidget,
    );
    // El texto viejo del acordeon ya no esta en ningun lado.
    expect(find.text('Sin verificar'), findsNothing);

    // Y el banner completo aparece con el panel.
    await _elegir(tester, 'Contacto');
    expect(
      find.textContaining('no la uses en una emergencia real'),
      findsWidgets,
    );
  });

  testWidgets('un valor largo de poliza no se trunca en una linea', (
    tester,
  ) async {
    await montar(tester, size: const Size(320, 1400));
    await _elegir(tester, 'Cobertura');

    // CupertinoListTile le pone maxLines: 1 + ellipsis a lo que le
    // pasan: si esto vuelve a 1, "Red nacional + emergencias
    // internacionales" se muestra como "Red nacional + emerg..." y el
    // dato deja de servir.
    final valor = tester.widget<Text>(
      find.text('Red nacional + emergencias internacionales'),
    );
    expect(valor.maxLines, greaterThan(1));
  });

  testWidgets('la vigencia no se repite en dos lugares', (tester) async {
    await montar(tester);
    await _elegir(tester, 'Póliza');
    expect(find.textContaining('1 ene 2026'), findsOneWidget);
    expect(find.text('Vigencia'), findsOneWidget);
    expect(find.text('Al día'), findsOneWidget);

    await _elegir(tester, 'Pagos');
    expect(find.text('Vigencia'), findsNothing);
    expect(find.text('Forma de pago'), findsOneWidget);
  });

  testWidgets('regla dura: en Mi Plan no aparecen monedas', (tester) async {
    await montar(tester);
    for (final etiqueta in categorias) {
      await _elegir(tester, etiqueta);
      expect(find.textContaining('moneda'), findsNothing);
      expect(find.textContaining('Moneda'), findsNothing);
      expect(find.textContaining('medalla'), findsNothing);
    }
  });
}

/// Toca un boton del riel y espera.
///
/// El `ensureVisible` es por las pantallas cortas: ahi el cabezal deja
/// de estar fijo y viaja adentro del scroll, asi que el riel puede
/// arrancar fuera de cuadro y el toque no llegaria.
Future<void> _elegir(WidgetTester tester, String etiqueta) async {
  await tester.ensureVisible(_boton(etiqueta));
  await tester.pumpAndSettle();
  await tester.tap(_boton(etiqueta));
  await tester.pumpAndSettle();
}

/// El boton entero del riel. Es el que hay que medir y tocar: el `Text`
/// de adentro mide lo que mide la palabra.
Finder _boton(String etiqueta) => find.ancestor(
  of: find.text(etiqueta),
  matching: find.byType(CupertinoButton),
);

/// El color con el que se pinta la etiqueta de un segmento.
///
/// Se lee del `AnimatedDefaultTextStyle` que la envuelve y no del `Text`
/// directo: el color se anima al pasar de apagado a encendido, asi que
/// el estilo vive en el envoltorio y el `Text` lo trae en null.
Color? _colorDe(WidgetTester tester, String etiqueta) {
  final estilo = tester.widget<AnimatedDefaultTextStyle>(
    find
        .ancestor(
          of: find.descendant(
            of: _boton(etiqueta),
            matching: find.text(etiqueta),
          ),
          matching: find.byType(AnimatedDefaultTextStyle),
        )
        .first,
  );
  return estilo.style.color;
}
