import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/widgets/flujos_social.dart';

// ============================================================
// Cuándo termina una competencia entre conocidos.
//
// Dura UN MES y no se elige (revisión de UI del 9 de septiembre de 2026;
// antes el usuario podía pedir 1, 2 o 3).
//
// Sumar un mes no es sumar 30 días, y ahí es donde esto se rompe sin que
// nadie lo note: el usuario crea la competencia el 31 de enero y la app
// le dice que termina el 3 de marzo.
// ============================================================

void main() {
  test('una competencia dura un mes, siempre', () {
    expect(mesesDeCompetencia, 1);
  });

  test('cae el mismo día del mes siguiente', () {
    expect(
      cierreDeCompetencia(desde: DateTime(2026, 9, 4)),
      DateTime(2026, 10, 4),
    );
  });

  test('cruza de año sin perderse', () {
    expect(
      cierreDeCompetencia(desde: DateTime(2026, 12, 20)),
      DateTime(2027, 1, 20),
    );
  });

  test('si el día no existe en el mes destino, se corta al último', () {
    // 31 de enero + 1 mes NO es el 3 de marzo. Dart normaliza el
    // desborde solo, así que sin el recorte esto se iría de mes.
    expect(
      cierreDeCompetencia(desde: DateTime(2026, 1, 31)),
      DateTime(2026, 2, 28),
    );
    // 2028 sí es bisiesto: el recorte tiene que dar 29, no 28 fijo.
    expect(
      cierreDeCompetencia(desde: DateTime(2028, 1, 31)),
      DateTime(2028, 2, 29),
    );
    // 31 de marzo + 1 mes: abril tiene 30.
    expect(
      cierreDeCompetencia(desde: DateTime(2026, 3, 31)),
      DateTime(2026, 4, 30),
    );
  });

  test('la competencia siempre termina en el futuro', () {
    expect(cierreDeCompetencia().isAfter(DateTime.now()), isTrue);
  });
}
