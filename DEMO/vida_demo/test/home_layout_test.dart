import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/screens/home_screen.dart';
import 'package:vida_demo/theme.dart';

/// Monta Home entera (con el scroll desplegado) y falla si hay cualquier
/// desborde de layout.
///
/// Cubre los dos casos que más rompen: la pantalla mas angosta que
/// soportamos y el texto del sistema en grande.
void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  Future<void> montar(WidgetTester tester, Size size, double escala) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    // El MediaQuery va DENTRO del MaterialApp: puesto afuera, MaterialApp
    // reinyecta el suyo desde la vista y se come el textScaler, con lo
    // cual el test de "texto en grande" no probaba nada.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: const TemaVida(child: HomeScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('no desborda en la pantalla mas chica que soportamos', (
    tester,
  ) async {
    // iPhone SE: 320 de ancho logico es el piso realista.
    await montar(tester, const Size(320, 2600), 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no desborda con el texto del sistema en grande', (tester) async {
    await montar(tester, const Size(430, 4200), 1.6);
    expect(tester.takeException(), isNull);
  });
}
