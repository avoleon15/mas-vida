import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/theme.dart';
import 'package:vida_demo/widgets/carrusel_patrocinadores.dart';

// ============================================================
// EL CARRUSEL CON LAS ANIMACIONES ENCENDIDAS.
//
// El resto de la suite corre con "Reducir movimiento" (ver
// `test/ayudas.dart`), así que el avance automático —lo único que puede
// colgar un test— no se ejercita en ningún otro lado. Acá se prende a
// mano.
//
// NINGÚN test de este archivo puede usar `pumpAndSettle`: con el avance
// andando no hay "asentarse" que valga y el test moriría de timeout. Se
// avanza el reloj a mano, con `pump(duración)`.
//
// Y todos terminan desmontando el carrusel, para que `dispose` cancele el
// Timer: si quedara vivo, el framework marca el test como fallado por
// temporizador pendiente. Eso también prueba que `dispose` limpia.
// ============================================================

SemanaObjetivos _semana(int numero, String marca) => SemanaObjetivos(
  numero: numero,
  cierra: DateTime.utc(2026, 10, 11, 5, 59, 59),
  estado: EstadoSemana.futura,
  objetivos: const [],
  monedas: 0,
  patrocinio: Patrocinio(
    id: marca.toLowerCase(),
    marca: marca,
    logo: 'assets/img/premios/restaurantes/${marca.toLowerCase()}.webp',
    cupon: 'Cupón de $marca',
  ),
);

final _dos = [_semana(4, 'Ookii'), _semana(8, 'Montanos')];

Widget _pantalla(List<SemanaObjetivos> semanas, {bool animaciones = true}) =>
    MaterialApp(
      theme: AppTheme.temaClaro,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: !animaciones),
          child: TemaVida(
            child: Scaffold(
              body: Center(child: CarruselLoQueViene(semanas: semanas)),
            ),
          ),
        ),
      ),
    );

/// En qué tarjeta está parado el carrusel.
double _pagina(WidgetTester t) =>
    t.widget<PageView>(find.byType(PageView)).controller!.page!;

/// Desmonta el carrusel para que `dispose` cancele el Timer.
Future<void> _desmontar(WidgetTester t) async {
  await t.pumpWidget(const MaterialApp(home: SizedBox()));
}

void main() {
  testWidgets('solo avanza cuando le toca', (t) async {
    await t.pumpWidget(_pantalla(_dos));
    expect(_pagina(t), 0);

    // A los 5 segundos todavía no se movió.
    await t.pump(const Duration(seconds: 5));
    expect(_pagina(t), 0);

    // A los 6 arranca el cambio y a los 900 ms ya llegó.
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(milliseconds: 900));
    expect(_pagina(t), 1);

    await _desmontar(t);
  });

  testWidgets('vuelve a la primera al terminar', (t) async {
    await t.pumpWidget(_pantalla(_dos));

    // Dos vueltas: con dos tarjetas, la segunda tiene que volver al
    // principio. Si frenara en la última, el carrusel quedaría muerto.
    for (var i = 0; i < 2; i++) {
      await t.pump(const Duration(seconds: 6));
      await t.pump(const Duration(milliseconds: 900));
    }
    expect(_pagina(t), 0);

    await _desmontar(t);
  });

  testWidgets('el usuario toca y el avance automático se apaga', (t) async {
    await t.pumpWidget(_pantalla(_dos));

    // Un toque en el carrusel: no arrastra ni cambia de tarjeta, solo
    // avisa que el usuario está mirando ESTA.
    await t.tap(find.byType(PageView));
    await t.pump();

    // Pasan dos ciclos enteros y la tarjeta sigue siendo la misma. Que la
    // app te arrebate lo que estás mirando enfurece.
    await t.pump(const Duration(seconds: 7));
    await t.pump(const Duration(seconds: 7));
    expect(_pagina(t), 0);

    await _desmontar(t);
  });

  testWidgets('con "Reducir movimiento" no arranca ningún temporizador', (
    t,
  ) async {
    await t.pumpWidget(_pantalla(_dos, animaciones: false));

    // Sin esta rama, un Timer perpetuo cuelga `pumpAndSettle` en TODA la
    // suite, que corre con las animaciones apagadas.
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 20));
    expect(_pagina(t), 0);

    await _desmontar(t);
  });

  testWidgets('con una sola tarjeta no hay avance que hacer', (t) async {
    await t.pumpWidget(_pantalla([_dos.first]));

    await t.pump(const Duration(seconds: 7));
    expect(_pagina(t), 0);

    await _desmontar(t);
  });
}
