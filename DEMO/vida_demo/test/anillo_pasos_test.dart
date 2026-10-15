import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/widgets/progress_ring.dart';

// ============================================================
// CADA ARO SE LLENA DENTRO DE SU TRAMO (Daniel, 8 de octubre de 2026).
//
// El de plata va de 7.000 a 10.000: con 7.150 pasos apenas asoma encima
// del bronce completo. Antes (21 de septiembre) se medía desde cero y con
// 7.150 pasos salía casi lleno, que no tenía sentido.
// ============================================================

void main() {
  group('Los cortes salen de la tabla oficial', () {
    test('son 0, 7.000, 10.000 y 15.000', () {
      expect(cortesAros, [0, 7000, 10000, 15000]);
    });
  });

  group('El aro en curso se llena dentro de su tramo', () {
    test('7.150 pasos: la plata apenas arranca', () {
      expect(fraccionDelAro(7150, 0), 1);
      expect(fraccionDelAro(7150, 1), closeTo(0.05, 0.0001));
    });

    test('8.500 pasos llenan la plata a la mitad', () {
      expect(techoDelAroActual(8500), 10000);
      expect(fraccionDelAro(8500, 1), closeTo(0.5, 0.0001));
    });

    test('con 10.000 pasos el aro de plata esta COMPLETO', () {
      expect(fraccionDelAro(10000, 1), 1);
    });

    test('12.500 pasos llenan el de oro a la mitad', () {
      expect(techoDelAroActual(12500), 15000);
      expect(fraccionDelAro(12500, 2), closeTo(0.5, 0.0001));
    });

    test('5.000 pasos llenan el de bronce cinco septimos', () {
      expect(techoDelAroActual(5000), 7000);
      expect(fraccionDelAro(5000, 0), closeTo(5 / 7, 0.0001));
    });

    test('la fraccion del aro en curso es lo caminado en su tramo', () {
      for (var pasos = 1; pasos < 15000; pasos += 137) {
        final techo = techoDelAroActual(pasos);
        final indice = cortesAros.indexOf(techo) - 1;
        final piso = cortesAros[indice];
        expect(
          fraccionDelAro(pasos, indice),
          closeTo((pasos - piso) / (techo - piso), 0.0001),
          reason: 'con $pasos pasos el aro $indice no sigue a su tramo',
        );
      }
    });

    test('la animacion pasa pasos con decimales y avanza continuo', () {
      expect(fraccionDelAro(7001.5, 1), greaterThan(0));
      expect(fraccionDelAro(7001.5, 1), lessThan(0.001));
    });
  });

  group('Los tramos de abajo y de arriba', () {
    test('un tramo terminado queda completo, no desaparece', () {
      // Con 12.000 pasos, bronce y plata siguen enteros debajo del oro.
      expect(fraccionDelAro(12000, 0), 1);
      expect(fraccionDelAro(12000, 1), 1);
    });

    test('un tramo que no arranco queda en cero', () {
      // Con 8.000 pasos el oro todavia no existe. Antes de arreglar
      // esto, `pasos / hasta` le habria dado 8.000/15.000 y el oro se
      // habria pintado a medias encima de la plata.
      expect(fraccionDelAro(8000, 2), 0);
    });

    test('justo en el corte, el de abajo cierra y el de arriba no abre', () {
      expect(fraccionDelAro(7000, 0), 1);
      expect(fraccionDelAro(7000, 1), 0);
    });

    test('pasado el techo, los tres quedan completos', () {
      expect(fraccionDelAro(20000, 0), 1);
      expect(fraccionDelAro(20000, 1), 1);
      expect(fraccionDelAro(20000, 2), 1);
    });

    test('con cero pasos no se pinta ningun aro', () {
      expect(fraccionDelAro(0, 0), 0);
      expect(fraccionDelAro(0, 1), 0);
      expect(fraccionDelAro(0, 2), 0);
    });
  });
}
