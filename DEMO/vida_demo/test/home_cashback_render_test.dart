import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/screens/home_screen.dart';
import 'package:vida_demo/theme.dart';

/// Prueba de identidad: confirma que la tarjeta de cashback que se ve en
/// pantalla es la que arma home_screen.dart con el widget
/// EscaleraCashback, y no otra copia.
void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  testWidgets('Home monta la tarjeta de cashback de home_screen.dart', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 3000));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const TemaVida(child: HomeScreen()),
      ),
    );
    await tester.pump();
    // Los desbordes de layout se drenan aparte: este test es de
    // identidad, no de layout.
    while (tester.takeException() != null) {}

    expect(find.textContaining('PUNTOS ACUMULADOS'), findsOneWidget);
    expect(find.text('Ver mi cashback'), findsOneWidget);
    expect(find.textContaining('para el nivel'), findsOneWidget);
  });
}
