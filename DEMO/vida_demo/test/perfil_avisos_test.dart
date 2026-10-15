import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/screens/perfil_screen.dart';

import 'ayudas.dart';

// ============================================================
// PERFIL: los avisos.
//
// La racha salió de la app (Hoy el 2 de octubre, Perfil y Récords el 6).
// Lo que protege este test: que su interruptor no vuelva, y que el único
// aviso que queda siga ahí.
// ============================================================

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  testWidgets('los avisos son solo el recordatorio diario, sin racha', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await montarPantalla(t, const PerfilScreen());
    await t.pump();

    expect(find.text('AVISOS'), findsOneWidget);
    expect(find.text('Recordatorio diario'), findsOneWidget);
    expect(find.text('Racha en riesgo'), findsNothing);
    expect(find.textContaining('racha'), findsNothing);
  });
}
