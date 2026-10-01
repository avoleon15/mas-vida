import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_demo/datos/healthkit_bridge.dart';
import 'package:vida_demo/screens/permisos_salud_screen.dart';

import 'ayudas.dart';

// ============================================================
// LA PANTALLA DE PERMISOS DE APPLE SALUD.
//
// Lo que se protege: que explique para qué es cada dato ANTES de pedir,
// que después diga qué se ve de verdad con lo que devuelve el nativo, y
// que a quien no tiene reloj no se le hable como si hubiera hecho algo
// mal.
// ============================================================

ResultadoPermisos _resultado(
  EstadoPermisos estado, {
  bool pasos = true,
  bool ritmo = true,
  bool entrenos = true,
}) => ResultadoPermisos(
  estado: estado,
  tipos: TiposVisibles(
    pasos: pasos,
    ritmoCardiaco: ritmo,
    entrenamientos: entrenos,
  ),
);

void main() {
  // Sin plugin en los tests: el almacén que recuerda que ya se pidió el
  // permiso usa valores simulados.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> montar(
    WidgetTester t, {
    Future<ResultadoPermisos> Function()? solicitar,
    VoidCallback? alTerminar,
  }) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await montarPantalla(
      t,
      PermisosSaludScreen(solicitar: solicitar, alTerminar: alTerminar),
    );
    await t.pump();
  }

  Future<void> pedir(WidgetTester t) async {
    await t.tap(find.byKey(llaveBotonPermisos));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('antes de pedir explica para qué es cada dato', (t) async {
    await montar(t);
    expect(find.text('Pasos'), findsOneWidget);
    expect(find.text('Ritmo cardíaco'), findsOneWidget);
    expect(find.text('Entrenamientos'), findsOneWidget);
    expect(
      find.textContaining('Necesitamos ver tus pasos para calcular tus puntos'),
      findsOneWidget,
    );
    // Y la promesa de privacidad dice la verdad: resumen diario, con
    // consentimiento aparte, nunca el dato crudo.
    expect(find.textContaining('un resumen de cada día'), findsOneWidget);
    expect(find.text('Permitir acceso a Salud'), findsOneWidget);
  });

  testWidgets('con todo visible dice que está listo', (t) async {
    await montar(
      t,
      solicitar: () async => _resultado(EstadoPermisos.concedido),
    );
    await pedir(t);
    expect(find.text('¡Listo! Ya vemos tus datos'), findsOneWidget);
  });

  testWidgets('sin reloj no acusa: lo dice como algo normal', (t) async {
    await montar(
      t,
      solicitar: () async =>
          _resultado(EstadoPermisos.concedido, ritmo: false, entrenos: false),
    );
    await pedir(t);

    // La mayoría del piloto no tiene reloj. Decirle a todos que arreglen
    // un permiso sería ruido para casi todos.
    expect(find.text('Ya vemos tus pasos'), findsOneWidget);
    expect(find.textContaining('no usas reloj, y está bien'), findsOneWidget);
    expect(find.textContaining('Si sí usas un reloj'), findsOneWidget);
    expect(find.text('Sin datos'), findsNWidgets(2));
  });

  testWidgets('sin pasos pide revisar Ajustes y deja volver a revisar', (
    t,
  ) async {
    await montar(
      t,
      solicitar: () async => _resultado(
        EstadoPermisos.sinDatosVisibles,
        pasos: false,
        ritmo: false,
        entrenos: false,
      ),
    );
    await pedir(t);
    expect(find.text('Todavía no vemos tus pasos'), findsOneWidget);
    expect(find.textContaining('Ajustes › Salud'), findsOneWidget);
    expect(find.text('Volver a revisar'), findsOneWidget);
  });

  testWidgets('si el nativo falla, no se queda colgada', (t) async {
    await montar(
      t,
      solicitar: () async => throw PlatformException(code: 'PERMISOS_ERROR'),
    );
    await pedir(t);
    expect(find.text('No pudimos conectar con Salud'), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsOneWidget);
  });

  testWidgets('en el arranque se puede dejar para después', (t) async {
    var termino = false;
    await montar(t, alTerminar: () => termino = true);
    await t.tap(find.text('Ahora no'));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(termino, isTrue);
  });

  testWidgets('habla de tú, nunca de vos', (t) async {
    await montar(
      t,
      solicitar: () async =>
          _resultado(EstadoPermisos.concedido, ritmo: false, entrenos: false),
    );
    await pedir(t);
    for (final vos in ['usás', 'revisá', 'tenés', 'podés', 'activalo']) {
      expect(find.textContaining(vos), findsNothing, reason: vos);
    }
  });
}
