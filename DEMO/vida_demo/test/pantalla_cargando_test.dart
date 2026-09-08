import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:vida_demo/widgets/logo_vida.dart';
import 'package:vida_demo/widgets/pantalla_cargando.dart';

import 'ayudas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el archivo de la animación se lee y tiene las 3 capas', () async {
    final composicion = await AssetLottie('assets/lottie/cargando.json').load();
    expect(composicion.duration.inMilliseconds, 2500);
    expect(composicion.bounds.width, 600);
    expect(composicion.bounds.height, 300);
  });

  testWidgets('la pantalla muestra la animación, no el de reserva', (
    tester,
  ) async {
    await montarPantalla(tester, const PantallaCargando());
    await tester.pumpAndSettle();

    expect(find.byType(LottieBuilder), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(find.text('Cargando'), findsOneWidget);
    // El nombre lo pone el logo, no un texto: si el archivo faltara,
    // LogoVida caería a su plan B escrito y esto lo delata.
    expect(find.byType(LogoVida), findsOneWidget);
    expect(find.text('+VIDA'), findsNothing);
  });
}
