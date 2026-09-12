import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/widgets/flujos_social.dart';

// ============================================================
// Cuándo termina una competencia.
//
// Sumar meses no es sumar 30 días, y ahí es donde esto se rompe sin que
// nadie lo note: el usuario elige "1 mes" en enero y la app le dice que
// termina en marzo.
// ============================================================

void main() {
  test('solo se puede competir 1, 2 o 3 meses', () {
    expect(mesesDeCompetencia, [1, 2, 3]);
  });

  test('cae el mismo día del mes', () {
    final desde = DateTime(2026, 9, 4);

    expect(cierreDeCompetencia(1, desde: desde), DateTime(2026, 10, 4));
    expect(cierreDeCompetencia(2, desde: desde), DateTime(2026, 11, 4));
    expect(cierreDeCompetencia(3, desde: desde), DateTime(2026, 12, 4));
  });

  test('cruza de año sin perderse', () {
    final desde = DateTime(2026, 11, 20);
    expect(cierreDeCompetencia(3, desde: desde), DateTime(2027, 2, 20));
  });

  test('si el día no existe en el mes destino, se corta al último', () {
    // 31 de enero + 1 mes NO es el 3 de marzo. Dart normaliza el
    // desborde solo, así que sin el recorte esto se iría de mes.
    expect(
      cierreDeCompetencia(1, desde: DateTime(2026, 1, 31)),
      DateTime(2026, 2, 28),
    );
    // 2028 sí es bisiesto: el recorte tiene que dar 29, no 28 fijo.
    expect(
      cierreDeCompetencia(1, desde: DateTime(2028, 1, 31)),
      DateTime(2028, 2, 29),
    );
    // 31 de marzo + 1 mes: abril tiene 30.
    expect(
      cierreDeCompetencia(1, desde: DateTime(2026, 3, 31)),
      DateTime(2026, 4, 30),
    );
  });

  test('la competencia siempre termina en el futuro', () {
    final hoy = DateTime.now();
    for (final meses in mesesDeCompetencia) {
      expect(cierreDeCompetencia(meses).isAfter(hoy), isTrue);
    }
  });
}
