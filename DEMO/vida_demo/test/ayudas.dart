import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/theme.dart';

// ============================================================
// Cómo se monta una pantalla en un test.
//
// Ojo con `disableAnimations`: la app tiene animaciones que se repiten
// para siempre (la moneda de Lottie, el borde que gira de Hoy). Con
// ellas vivas, `pumpAndSettle` NUNCA termina de asentarse y el test se
// cuelga hasta el timeout.
//
// Encenderlo acá no es un truco para esquivar eso: es el mismo camino
// que toma la app cuando el usuario activa "Reducir movimiento" en iOS.
// Los tests corren por la rama que un usuario real puede pedir.
// ============================================================

/// Monta [pantalla] con el tema de +Vida y sin animaciones perpetuas.
///
/// [TemaVida] es obligatorio: los componentes de shadcn_ui revientan si
/// no encuentran un ShadTheme arriba en el árbol.
Future<void> montarPantalla(WidgetTester tester, Widget pantalla) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.temaClaro,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: TemaVida(child: pantalla),
        ),
      ),
    ),
  );
}
