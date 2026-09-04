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
    expect(find.text('Enviadas'), findsOneWidget);
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

  testWidgets('cancelar una solicitud enviada la saca', (tester) async {
    final social = Datos.i.social;
    final antes = social.solicitudesEnviadas.length;

    await _montar(tester, pestania: 2);
    await tester.tap(find.text('Cancelar').first);
    await tester.pumpAndSettle();

    expect(social.solicitudesEnviadas.length, antes - 1);
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
