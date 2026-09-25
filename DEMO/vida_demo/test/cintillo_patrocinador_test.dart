import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/theme.dart';
import 'package:vida_demo/widgets/cintillo_patrocinador.dart';
import 'package:vida_demo/widgets/placeholder_imagen.dart';

// ============================================================
// EL CINTILLO CON LAS ANIMACIONES ENCENDIDAS.
//
// El resto de la suite corre con "Reducir movimiento" (ver
// `test/ayudas.dart`), así que el `repeat()` —lo único que puede colgar
// un test— no se ejercita en ningún otro lado. Acá se prende a mano.
//
// NINGÚN test con animaciones puede usar `pumpAndSettle`: una animación
// que se repite para siempre no se asienta nunca y el test moriría de
// timeout. Se avanza el reloj a mano con `pump(duración)` y se desmonta
// al final para que `dispose` corte el controlador.
// ============================================================

const _foto = 'assets/img/premios/restaurantes/ookii.webp';

Widget _pantalla(List<String> fotos, {bool animaciones = true}) => MaterialApp(
  theme: AppTheme.temaClaro,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: !animaciones),
      child: TemaVida(
        child: Scaffold(
          body: CintilloPatrocinador(
            semana: 3,
            marca: 'Ookii',
            fotos: fotos,
            fondoMarca: '#000000',
          ),
        ),
      ),
    ),
  ),
);

/// Dónde está la PRIMERA foto en la pantalla.
///
/// Se mide la posición real y no el valor del controlador: es lo que el
/// usuario ve. Mientras el cintillo está quieto no se mueve; cuando rota,
/// la primera foto se va hacia la izquierda (x cada vez más negativo).
double _xDeLaPrimeraFoto(WidgetTester t) =>
    t.getTopLeft(find.byType(FotoComercio).first).dx;

Future<void> _desmontar(WidgetTester t) async {
  await t.pumpWidget(const MaterialApp(home: SizedBox()));
}

void main() {
  testWidgets('con tres fotos rota solo', (t) async {
    await t.pumpWidget(_pantalla(const [_foto, _foto, _foto]));
    final arranque = _xDeLaPrimeraFoto(t);

    // A mitad del ciclo ya se corrió hacia la izquierda.
    await t.pump(const Duration(seconds: 3));
    expect(_xDeLaPrimeraFoto(t), lessThan(arranque));

    await _desmontar(t);
  });

  testWidgets('con "Reducir movimiento" se queda en la primera', (t) async {
    await t.pumpWidget(
      _pantalla(const [_foto, _foto, _foto], animaciones: false),
    );
    final arranque = _xDeLaPrimeraFoto(t);

    // Sin esta rama, un controlador en `repeat()` cuelga `pumpAndSettle`
    // en TODA la suite, que corre con las animaciones apagadas.
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 20));
    expect(_xDeLaPrimeraFoto(t), arranque);

    await _desmontar(t);
  });

  testWidgets('con una sola foto no hay nada que rotar', (t) async {
    await t.pumpWidget(_pantalla(const [_foto]));
    final arranque = _xDeLaPrimeraFoto(t);

    await t.pump(const Duration(seconds: 7));
    expect(_xDeLaPrimeraFoto(t), arranque);

    await _desmontar(t);
  });

  testWidgets('quién patrocina se dice para VoiceOver', (t) async {
    // En pantalla el rótulo NO va acá: lo dice el título de la pantalla,
    // que es "SEMANA 3 · Patrocinada por Montanos". Pero quien no ve la
    // pantalla necesita saber de qué es esta foto.
    await t.pumpWidget(_pantalla(const [_foto, _foto, _foto]));

    expect(
      find.bySemanticsLabel('Semana 3, patrocinada por Ookii'),
      findsOneWidget,
    );

    await _desmontar(t);
  });
}
