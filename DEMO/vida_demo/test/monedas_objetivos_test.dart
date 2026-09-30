import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';

/// El producto tiene DOS monedas —PUNTOS (cashback anual) y MONEDAS (se
/// gastan en Premios)— y no se mezclan.
///
/// La regla que se fija: hay DOS objetivos por semana, y cumplir LOS DOS
/// es lo único que paga las MONEDAS de esa semana. Cuántas, lo manda el
/// servidor en la propia semana.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  List<SemanaObjetivos> semanas() => Datos.i.resumen.objetivosSemana.semanas;

  group('La regla son dos checks, y nada más', () {
    test('cada semana trae dos objetivos: pasos y entrenamiento', () {
      for (final w in semanas()) {
        expect(w.objetivos.map((o) => o.id), [
          'pasos_semana',
          'minutos_entrenamiento',
        ], reason: 'semana ${w.numero}');
      }
    });

    test('una semana está cumplida si y solo si cumplió los dos', () {
      for (final w in semanas()) {
        expect(
          w.cumplida,
          w.objetivos.every((o) => o.completo),
          reason: 'semana ${w.numero}',
        );
      }
    });

    test('el mock trae una semana a medias, para poder probar ese caso', () {
      // Si el mock no trae ninguna, los tests de "cumplir uno no paga"
      // pasan sin probar nada: mejor saberlo que tener un verde falso.
      final aMedias = semanas().where(
        (w) =>
            w.estado != EstadoSemana.futura && w.cumplidos > 0 && !w.cumplida,
      );
      expect(aMedias, isNotEmpty);
    });

    test('hay exactamente una semana en curso', () {
      final enCurso = semanas()
          .where((w) => w.estado == EstadoSemana.enCurso)
          .length;
      expect(enCurso, 1);
    });
  });

  group('Qué paga cada semana', () {
    test('cumplir uno solo no paga nada', () {
      for (final w in semanas()) {
        if (w.cumplida) continue;
        expect(w.monedasGanadas, 0, reason: 'semana ${w.numero}');
      }
    });

    test('una semana cerrada con los dos paga sus monedas', () {
      for (final w in semanas()) {
        if (w.estado != EstadoSemana.cerrada || !w.cumplida) continue;
        expect(w.monedasGanadas, w.monedas, reason: 'semana ${w.numero}');
      }
    });

    test('la semana en curso no paga hasta que cierre', () {
      // Aunque tenga los dos cumplidos: se evalúa el domingo 23:59.
      for (final w in semanas()) {
        if (w.estado == EstadoSemana.cerrada) continue;
        expect(w.monedasGanadas, 0, reason: 'semana ${w.numero}');
      }
    });

    test('el total del programa es la suma de lo que pagó cada semana', () {
      final s = Datos.i.resumen.objetivosSemana;
      final suma = s.semanas.fold(0, (a, w) => a + w.monedasGanadas);
      expect(s.monedasGanadas, suma);
    });

    test('el monto sale del servidor, no del número de semana', () {
      // Una semana no paga "numero × algo": trae su propio monto. Si el
      // mock pagara lo mismo en todas, este test no probaría nada.
      final montos = semanas().map((w) => w.monedas).toSet();
      expect(montos.length, greaterThan(1));
    });
  });
}
