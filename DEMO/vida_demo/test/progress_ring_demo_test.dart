import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vida_demo/theme.dart';
import 'package:vida_demo/widgets/progress_ring.dart';
import 'package:vida_demo/widgets/tarjeta_borde_animado.dart';

/// Render del anillo de pasos con su texto de centro, para revisarlo a
/// ojo sin levantar la app entera.
///
///   flutter test --update-goldens test/progress_ring_demo_test.dart
///
/// Nota sobre las fuentes: google_fonts las descarga en tiempo de
/// ejecución, así que en un test no existen y el texto saldría como
/// cajas. Para que el golden sirva de algo cargamos dos TTF locales de
/// Windows bajo los mismos nombres de familia. Las formas de las letras
/// NO son las finales — lo que este golden valida es el layout: que el
/// bloque entre adentro del aro y la jerarquía se lea.
Future<void> _cargarFuentesDePrueba() async {
  // Sin esto google_fonts sale a internet a buscar las fuentes y el test
  // se queda colgado esperando la red.
  GoogleFonts.config.allowRuntimeFetching = false;

  const reemplazos = {
    // Bahnschrift es condensada, como Bebas Neue.
    'BebasNeue': r'C:\Windows\Fonts\bahnschrift.ttf',
    'Inter': r'C:\Windows\Fonts\segoeui.ttf',
  };

  for (final entrada in reemplazos.entries) {
    final archivo = File(entrada.value);
    if (!archivo.existsSync()) continue;
    final cargador = FontLoader(entrada.key)
      ..addFont(
        archivo.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
      );
    await cargador.load();
  }
}

void main() {
  testWidgets('anillo con 0, 2.000, 8.000, 12.000 y 16.000 pasos', (
    tester,
  ) async {
    await _cargarFuentesDePrueba();

    tester.view.physicalSize = const Size(1450, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fila = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final pasos in const [0, 2000, 8000, 12000, 16000])
          Stack(
            alignment: Alignment.center,
            children: [
              ProgressRing(pasos: pasos, size: 260),
              TextoCentroAnillo(pasos: pasos),
            ],
          ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: ColoredBox(
          color: AppColors.background,
          child: Column(
            key: const Key('demo'),
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              fila,
              // La misma fila en escala de grises. Los tres aros tienen
              // que seguir distinguiéndose acá: si se separan sin color,
              // se separan con cualquier tipo de daltonismo.
              ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0, //
                  0.2126, 0.7152, 0.0722, 0, 0, //
                  0.2126, 0.7152, 0.0722, 0, 0, //
                  0, 0, 0, 1, 0, //
                ]),
                child: fila,
              ),
            ],
          ),
        ),
      ),
    );

    // El destello de los 16.000 va a mitad de su primera vuelta.
    await tester.pump(const Duration(milliseconds: 260));

    await expectLater(
      find.byKey(const Key('demo')),
      matchesGoldenFile('goldens/progress_ring_demo.png'),
    );
  });

  testWidgets('tarjeta de borde animado, en tres momentos del giro', (
    tester,
  ) async {
    await _cargarFuentesDePrueba();

    tester.view.physicalSize = const Size(420, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Tres momentos del giro, para ver por dónde va pasando la franja.
    // Cada tarjeta arranca desfasada usando una duración distinta.
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: ColoredBox(
          color: AppColors.background,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              key: const Key('demoTarjeta'),
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final segundos in const [20, 30, 45])
                  SizedBox(
                    width: double.infinity,
                    child: TarjetaBordeAnimado(
                      duracionGiro: Duration(seconds: segundos),
                      child: const Text(
                        'Buenos días, Diego',
                        style: TextStyle(
                          fontFamily: 'BebasNeue',
                          fontSize: 28,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 5));

    await expectLater(
      find.byKey(const Key('demoTarjeta')),
      matchesGoldenFile('goldens/tarjeta_borde_animado.png'),
    );
  });

  test('los cortes de los aros salen de la tabla oficial de pasos', () {
    expect(cortesAros, [0, 7000, 10000, 15000]);
    expect(techoAros, 15000);
  });

  test('el techo del aro en curso cambia solo al cambiar de aro', () {
    expect(techoDelAroActual(0), 7000);
    expect(techoDelAroActual(2000), 7000);
    expect(techoDelAroActual(6999), 7000);
    // Justo en el umbral ya se está llenando el aro siguiente.
    expect(techoDelAroActual(7000), 10000);
    expect(techoDelAroActual(8000), 10000);
    expect(techoDelAroActual(10000), 15000);
    expect(techoDelAroActual(12000), 15000);
    // Arriba del techo se queda clavado: no hay un cuarto aro.
    expect(techoDelAroActual(16000), 15000);
  });

  test('el color del aro en curso acompaña al tramo', () {
    expect(colorDelAroActual(2000), AppColors.aroBronce);
    expect(colorDelAroActual(8000), AppColors.aroPlata);
    expect(colorDelAroActual(12000), AppColors.aroOro);
    expect(colorDelAroActual(16000), AppColors.aroOro);
  });

  test('los miles llevan separador', () {
    expect(TextoCentroAnillo.formatearMiles(0), '0');
    expect(TextoCentroAnillo.formatearMiles(2000), '2,000');
    expect(TextoCentroAnillo.formatearMiles(16000), '16,000');
  });
}
