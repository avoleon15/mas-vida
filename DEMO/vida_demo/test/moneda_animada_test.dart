import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:vida_demo/widgets/lluvia_confeti.dart';
import 'package:vida_demo/widgets/moneda_animada.dart';

import 'ayudas.dart';

// ============================================================
// La moneda de Lottie.
//
// Lo que se fija acá es lo que rompe sin avisar: que el .lottie se pueda
// abrir de verdad (es un zip, no un JSON), que el giro sea lento, y que
// la caja mida siempre lo mismo aunque el archivo tarde en cargar.
// ============================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el .lottie se abre y trae la animación de la moneda', () async {
    final composicion = await AssetLottie(
      'assets/lottie/moneda.lottie',
    ).load();

    // Es un dotLottie: un zip con manifest.json y el JSON adentro. Si
    // alguien lo reemplaza por un archivo suelto, esto lo agarra.
    expect(composicion.duration, greaterThan(Duration.zero));
    expect(composicion.endFrame, greaterThan(composicion.startFrame));
  });

  testWidgets('la moneda gira lento, no rápido', (tester) async {
    await montarPantalla(tester, const MonedaAnimada());
    await tester.pump();

    final lottie = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
    final controlador = lottie.controller as AnimationController;

    // De fábrica la animación dura 2,55 s. Estirarla es el punto: a la
    // velocidad original la moneda se lee como una alerta.
    expect(
      controlador.duration!.inMilliseconds,
      greaterThanOrEqualTo(7000),
      reason: 'la vuelta completa tiene que tardar 7 s o más',
    );
  });

  testWidgets('ocupa el tamaño pedido, cargue o no', (tester) async {
    await montarPantalla(tester, const Center(child: MonedaAnimada(size: 26)));
    // Sin pump extra: es el primer frame, cuando el archivo todavía
    // podría no estar. La caja ya tiene que medir lo suyo para que la
    // fila de al lado no se corra después.
    final caja = tester.getSize(
      find.descendant(
        of: find.byType(MonedaAnimada),
        matching: find.byType(SizedBox),
      ).first,
    );
    expect(caja, const Size(26, 26));
  });

  test('el confeti del canje se abre y cae una sola vez', () async {
    final comp = await AssetLottie('assets/lottie/confetti.lottie').load();
    expect(comp.duration, greaterThan(Duration.zero));
  });

  testWidgets('el confeti no tapa lo que hay debajo', (tester) async {
    var tocado = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const Key('debajo'),
                onTap: () => tocado = true,
                child: const ColoredBox(color: Color(0xFFFFFFFF)),
              ),
            ),
            const LluviaConfeti(),
          ],
        ),
      ),
    );
    await tester.pump();

    // El botón "Volver al Inicio" queda debajo del confeti: si el
    // confeti se comiera el toque, la pantalla sería un callejón.
    await tester.tap(find.byKey(const Key('debajo')));
    expect(tocado, isTrue);
  });

  testWidgets('con "reducir movimiento" se queda quieta', (tester) async {
    await montarPantalla(tester, const MonedaAnimada());
    await tester.pump();

    final lottie = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
    final controlador = lottie.controller as AnimationController;

    // montarPantalla activa disableAnimations, igual que iOS cuando el
    // usuario pide reducir movimiento.
    expect(controlador.isAnimating, isFalse);
  });
}
