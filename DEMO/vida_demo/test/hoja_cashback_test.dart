import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/screens/home_screen.dart';
import 'package:vida_demo/theme.dart';

/// "Ver mi cashback" abre una HOJA, no un desplegable.
///
/// Home ya tiene varios acordeones, asi que este boton se cambio a una
/// hoja que sube desde abajo. Estos tests fijan ese comportamiento.
void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  Future<void> montar(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 2600));
    tester.view.physicalSize = const Size(430, 2600);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.temaClaro,
        home: const TemaVida(child: HomeScreen()),
      ),
    );
    await tester.pump();
  }

  /// pumpAndSettle no sirve en esta pantalla: el borde animado del saludo
  /// y el brillo de la escalera giran en bucle, asi que nunca "settlea".
  Future<void> avanzar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('el monto no se ve hasta que se toca el boton', (tester) async {
    await montar(tester);
    expect(find.text('TE REGRESAN'), findsNothing);
  });

  testWidgets('tocar el boton abre la hoja con el monto', (tester) async {
    await montar(tester);
    await tester.tap(find.text('Ver mi cashback'), warnIfMissed: false);
    await avanzar(tester);

    expect(find.text('TE REGRESAN'), findsOneWidget);
    // El aviso regulatorio viaja SIEMPRE con el monto.
    expect(find.textContaining('después de pagar tu prima'), findsOneWidget);
  });

  testWidgets('la X cierra la hoja', (tester) async {
    await montar(tester);
    await tester.tap(find.text('Ver mi cashback'), warnIfMissed: false);
    await avanzar(tester);

    await tester.tap(find.byTooltip('Cerrar'));
    await avanzar(tester);

    expect(find.text('TE REGRESAN'), findsNothing);
  });

  testWidgets('el boton no cambia de etiqueta: ya no es un desplegable', (
    tester,
  ) async {
    await montar(tester);
    await tester.tap(find.text('Ver mi cashback'), warnIfMissed: false);
    await avanzar(tester);

    expect(find.text('Ocultar'), findsNothing);
    expect(find.text('Ver mi cashback'), findsOneWidget);
  });
}
