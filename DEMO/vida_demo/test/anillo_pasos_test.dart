import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/widgets/progress_ring.dart';

// ============================================================
// EL ANILLO DE PASOS TIENE QUE DECIR LO MISMO QUE SU TEXTO.
//
// El bug que arregla (lo vio Daniel el 21 de septiembre de 2026): el
// texto del centro decia "8,000 de 10,000" y el aro de plata se veia a
// un tercio. Pasaba porque el aro se llenaba desde el PISO de su tramo
// (7,000) y el texto contaba desde cero.
//
// La regla ahora es una sola: el aro EN CURSO se llena contra su techo y
// desde cero, que es la misma cuenta que hace el que lee el numero.
// ============================================================

void main() {
  group('Los cortes salen de la tabla oficial', () {
    test('son 0, 7.000, 10.000 y 15.000', () {
      expect(cortesAros, [0, 7000, 10000, 15000]);
    });
  });

  group('El aro en curso coincide con el texto del centro', () {
    test('8.000 pasos llenan el aro de plata cuatro quintos', () {
      // El texto dice "8,000 de 10,000". El aro tiene que decir lo mismo.
      expect(techoDelAroActual(8000), 10000);
      expect(fraccionDelAro(8000, 1), closeTo(0.8, 0.0001));
    });

    test('con 10.000 pasos el aro de plata esta COMPLETO', () {
      expect(fraccionDelAro(10000, 1), 1);
    });

    test('12.000 pasos llenan el de oro cuatro quintos', () {
      expect(techoDelAroActual(12000), 15000);
      expect(fraccionDelAro(12000, 2), closeTo(0.8, 0.0001));
    });

    test('5.000 pasos llenan el de bronce cinco septimos', () {
      expect(techoDelAroActual(5000), 7000);
      expect(fraccionDelAro(5000, 0), closeTo(5 / 7, 0.0001));
    });

    test('la fraccion del aro en curso es pasos / techo, siempre', () {
      // La propiedad que hace que el dibujo y el texto no se puedan
      // separar: sea cual sea el paso, el aro que se esta llenando vale
      // exactamente lo que dice la division del texto.
      for (var pasos = 1; pasos < 15000; pasos += 137) {
        final techo = techoDelAroActual(pasos);
        final indice = cortesAros.indexOf(techo) - 1;
        expect(
          fraccionDelAro(pasos, indice),
          closeTo(pasos / techo, 0.0001),
          reason: 'con $pasos pasos el aro $indice no sigue a su texto',
        );
      }
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
