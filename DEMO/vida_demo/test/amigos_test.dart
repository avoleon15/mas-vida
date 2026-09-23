import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/screens/amigos_screen.dart';
import 'package:vida_demo/theme.dart';

// ============================================================
// La pantalla de Amigos: contadores, solicitudes y la regla de qué se
// puede ver de alguien que todavía no es tu contacto.
// ============================================================

Future<void> _montar(WidgetTester tester, {int pestania = 0}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.temaClaro,
      home: TemaVida(child: AmigosScreen(pestaniaInicial: pestania)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  testWidgets('los contadores muestran los totales reales', (tester) async {
    await _montar(tester);
    final social = Datos.i.social;

    expect(find.text('Amigos'), findsWidgets);
    expect(find.text('${social.conexiones.length}'), findsWidgets);
    expect(find.text('Solicitudes'), findsOneWidget);
    // Y NO hay pestaña de enviadas (decisión de Daniel, 22 de septiembre
    // de 2026): ver la lista de lo que mandaste no lleva a ninguna
    // parte. Que ya la mandaste se dice donde alguien lo preguntaría de
    // nuevo — al buscar a esa persona para agregarla.
    expect(find.text('Enviadas'), findsNothing);
  });

  testWidgets('aceptar una solicitud la vuelve amistad', (tester) async {
    final social = Datos.i.social;
    final antesAmigos = social.conexiones.length;
    final antesSolicitudes = social.solicitudesRecibidas.length;
    final quien = social.solicitudesRecibidas.first;

    await _montar(tester, pestania: 1);
    await tester.tap(find.text('Aceptar').first);
    await tester.pumpAndSettle();

    expect(social.solicitudesRecibidas.length, antesSolicitudes - 1);
    expect(social.conexiones.length, antesAmigos + 1);
    expect(social.conexiones.any((c) => c.handle == quien.handle), isTrue);
  });

  testWidgets('a quien ya le mandaste no se le puede mandar de nuevo', (
    tester,
  ) async {
    await _montar(tester);
    final yaMandada = Datos.i.social.solicitudesEnviadas.first;

    // Lo mismo que hace Instagram: buscás a alguien y el botón te dice
    // en qué estás con esa persona. Antes la lista de enviadas vivía en
    // una pestaña propia y el botón siempre decía "Enviar", así que la
    // misma solicitud se podía mandar infinitas veces.
    await tester.tap(find.text('Agregar un amigo'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(CupertinoTextField).last,
      yaMandada.handle,
    );
    await tester.pumpAndSettle();

    expect(find.text('Solicitud enviada'), findsOneWidget);
    expect(find.text('Enviar solicitud'), findsNothing);
  });

  testWidgets('a un amigo tampoco: ya lo es', (tester) async {
    await _montar(tester);
    final amigo = Datos.i.social.conexiones.first;

    await tester.tap(find.text('Agregar un amigo'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(CupertinoTextField).last, amigo.handle);
    await tester.pumpAndSettle();

    expect(find.text('Ya son amigos'), findsOneWidget);
  });

  testWidgets('una solicitud no expone racha ni nivel', (tester) async {
    await _montar(tester, pestania: 1);

    // De alguien que todavía no aceptaste solo se ve nombre, usuario y
    // amigos en común. La racha se gana al aceptar.
    for (final s in Datos.i.social.solicitudesRecibidas) {
      expect(find.text(s.nombre), findsOneWidget);
    }
    expect(find.textContaining('sem'), findsNothing);
    expect(find.textContaining('Nivel'), findsNothing);
  });
}
