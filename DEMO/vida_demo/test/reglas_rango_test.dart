import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/reglas_rango.dart';

/// Tres objetivos con dificultad definida, para poder evaluar semanas.
/// Los objetivos reales todavia no tienen tabla de dificultad: estos son
/// de test, no del producto.
const _objetivos = [
  DefinicionObjetivo(
    id: 'pasos_semana',
    nombre: 'Pasos de la semana',
    unidad: 'pasos',
    metaPorRango: {1: 30000, 2: 40000, 3: 50000, 4: 60000},
  ),
  DefinicionObjetivo(
    id: 'intensidad_semana',
    nombre: 'Minutos de intensidad',
    unidad: 'minutos',
    metaPorRango: {1: 60, 2: 90, 3: 120, 4: 150},
  ),
  DefinicionObjetivo(
    id: 'dias_ritmo_alto',
    nombre: 'Dias con ritmo cardiaco alto',
    unidad: 'dias',
    metaPorRango: {1: 2, 2: 3, 3: 4, 4: 5},
  ),
];

List<AvanceObjetivo> _avances({int pasos = 0, int minutos = 0, int dias = 0}) =>
    [
      AvanceObjetivo(id: 'pasos_semana', logrado: pasos),
      AvanceObjetivo(id: 'intensidad_semana', logrado: minutos),
      AvanceObjetivo(id: 'dias_ritmo_alto', logrado: dias),
    ];

ResultadoSemana _cerrar({
  required int rango,
  required List<AvanceObjetivo> avances,
  DateTime? cierre,
  DateTime? cierrePrevio,
}) => evaluarSemana(
  rangoPrevio: rango,
  objetivos: _objetivos,
  avances: avances,
  // Domingo 18 de enero de 2026, dentro del mismo mes que el previo.
  cierre: cierre ?? DateTime(2026, 1, 18),
  cierrePrevio: cierrePrevio ?? DateTime(2026, 1, 11),
);

void main() {
  group('Movimiento del rango', () {
    test('cumplir los TRES objetivos sube un rango', () {
      final r = _cerrar(
        rango: 2,
        avances: _avances(pasos: 40000, minutos: 90, dias: 3),
      );
      expect(r.objetivosCumplidos, 3);
      expect(r.movimiento, MovimientoRango.sube);
      expect(r.rangoNuevo, 3);
    });

    test('cumplir DOS gana monedas pero no sube el rango', () {
      final r = _cerrar(
        rango: 2,
        avances: _avances(pasos: 40000, minutos: 90, dias: 0),
      );
      expect(r.objetivosCumplidos, 2);
      expect(r.movimiento, isNot(MovimientoRango.sube));
      expect(r.ganaMonedas, isTrue);
    });

    test('cumplir UNO gana monedas pero no sube el rango', () {
      final r = _cerrar(rango: 2, avances: _avances(pasos: 40000));
      expect(r.objetivosCumplidos, 1);
      expect(r.movimiento, isNot(MovimientoRango.sube));
      expect(r.ganaMonedas, isTrue);
    });

    test('no cumplir los tres BAJA un rango', () {
      final r = _cerrar(
        rango: 3,
        avances: _avances(pasos: 50000, minutos: 120, dias: 0),
      );
      expect(r.movimiento, MovimientoRango.baja);
      expect(r.rangoNuevo, 2);
    });

    test('no cumplir ninguno tambien baja, y no paga monedas', () {
      final r = _cerrar(rango: 3, avances: _avances());
      expect(r.objetivosCumplidos, 0);
      expect(r.rangoNuevo, 2);
      expect(r.ganaMonedas, isFalse);
    });

    test('el movimiento es de UN escalon como maximo, para arriba', () {
      final r = _cerrar(
        rango: 1,
        avances: _avances(pasos: 999999, minutos: 9999, dias: 7),
      );
      // Arrasar con los objetivos no salta dos rangos.
      expect(r.rangoNuevo, 2);
    });

    test('el movimiento es de UN escalon como maximo, para abajo', () {
      final r = _cerrar(rango: 4, avances: _avances());
      expect(r.rangoNuevo, 3);
    });
  });

  group('Piso y techo', () {
    test('desde el rango 1 no se baja mas', () {
      final r = _cerrar(rango: rangoMinimo, avances: _avances());
      expect(r.rangoNuevo, rangoMinimo);
      expect(r.movimiento, MovimientoRango.seQueda);
    });

    test('desde el rango 4 no se sube mas', () {
      final r = _cerrar(
        rango: rangoMaximo,
        avances: _avances(pasos: 60000, minutos: 150, dias: 5),
      );
      expect(r.rangoNuevo, rangoMaximo);
      expect(r.movimiento, MovimientoRango.seQueda);
    });
  });

  group('A que mes pertenece una semana', () {
    // Semana del lunes 26 de enero al domingo 1 de febrero de 2026:
    // arranca en enero y cierra en febrero.
    final lunesEnero = DateTime(2026, 1, 26);
    final domingoFebrero = DateTime(2026, 2, 1);

    test('el lunes y el domingo de esa semana son los esperados', () {
      expect(lunesDeLaSemana(domingoFebrero), lunesEnero);
      expect(domingoDeLaSemana(lunesEnero).day, 1);
      expect(domingoDeLaSemana(lunesEnero).month, DateTime.february);
    });

    test('una semana partida cae en UN solo mes, no en los dos', () {
      // Cualquier dia de la semana da el mismo mes: es la propiedad que
      // impide que una semana cuente doble.
      final meses = <DateTime>{
        for (var d = 0; d < 7; d++)
          mesDeLaSemana(lunesEnero.add(Duration(days: d))),
      };
      expect(meses.length, 1);
    });

    test('con la regla del DOMINGO, la semana partida es de febrero', () {
      expect(
        mesDeLaSemana(lunesEnero, regla: ReglaMesDeLaSemana.porDomingo),
        DateTime(2026, 2),
      );
    });

    test('con la regla del LUNES, la misma semana seria de enero', () {
      // El motor soporta las dos reglas: cambiar de una a otra es cambiar
      // `reglaMesVigente`, no reescribir nada.
      expect(
        mesDeLaSemana(lunesEnero, regla: ReglaMesDeLaSemana.porLunes),
        DateTime(2026, 1),
      );
    });

    test('un mes con cinco lunes no rompe nada', () {
      // Junio de 2026 tiene lunes 1, 8, 15, 22 y 29.
      final lunes = [
        1,
        8,
        15,
        22,
        29,
      ].map((d) => lunesDeLaSemana(DateTime(2026, 6, d)).day).toList();
      expect(lunes, [1, 8, 15, 22, 29]);
    });
  });

  group('Reinicio al empezar mes nuevo', () {
    test('el rango vuelve al piso en la primera semana del mes', () {
      // Cierre del domingo 1 de febrero contra el domingo 25 de enero.
      final r = _cerrar(
        rango: 4,
        avances: _avances(),
        cierre: DateTime(2026, 2, 1),
        cierrePrevio: DateTime(2026, 1, 25),
      );
      expect(r.reinicioPorMesNuevo, isTrue);
      // Vuelve al piso, y desde el piso ya no puede bajar mas.
      expect(r.rangoNuevo, rangoMinimo);
    });

    test('dos semanas del mismo mes no reinician', () {
      final r = _cerrar(
        rango: 3,
        avances: _avances(pasos: 50000, minutos: 120, dias: 4),
        cierre: DateTime(2026, 1, 18),
        cierrePrevio: DateTime(2026, 1, 11),
      );
      expect(r.reinicioPorMesNuevo, isFalse);
      expect(r.rangoNuevo, 4);
    });

    test('tras reiniciar, cumplir los tres sube desde el piso', () {
      final r = _cerrar(
        rango: 4,
        avances: _avances(pasos: 30000, minutos: 60, dias: 2),
        cierre: DateTime(2026, 2, 1),
        cierrePrevio: DateTime(2026, 1, 25),
      );
      // Se evalua contra las metas del rango 1, no contra las del 4.
      expect(r.reinicioPorMesNuevo, isTrue);
      expect(r.rangoNuevo, rangoMinimo + 1);
    });
  });

  group('Objetivos sin dificultad definida', () {
    test('no se evalua, el rango se congela y no paga monedas', () {
      // Los tres objetivos reales del producto todavia no tienen tabla de
      // dificultad: mientras no la tengan, el rango no se mueve.
      final r = evaluarSemana(
        rangoPrevio: 3,
        objetivos: objetivosProvisionales,
        avances: _avances(pasos: 999999, minutos: 9999, dias: 7),
        cierre: DateTime(2026, 1, 18),
        cierrePrevio: DateTime(2026, 1, 11),
      );
      expect(r.evaluable, isFalse);
      expect(r.rangoNuevo, 3);
      expect(r.movimiento, MovimientoRango.seQueda);
      expect(r.ganaMonedas, isFalse);
    });
  });

  group('Los objetivos son datos, no codigo', () {
    test('se pueden cambiar los tres sin tocar el motor', () {
      const otros = [
        DefinicionObjetivo(
          id: 'pisos_subidos',
          nombre: 'Pisos subidos',
          unidad: 'pisos',
          metaPorRango: {1: 20},
        ),
        DefinicionObjetivo(
          id: 'dias_activos',
          nombre: 'Dias activos',
          unidad: 'dias',
          metaPorRango: {1: 5},
        ),
        DefinicionObjetivo(
          id: 'sesiones_largas',
          nombre: 'Sesiones de 45 min',
          unidad: 'sesiones',
          metaPorRango: {1: 2},
        ),
      ];

      final r = evaluarSemana(
        rangoPrevio: 1,
        objetivos: otros,
        avances: const [
          AvanceObjetivo(id: 'pisos_subidos', logrado: 25),
          AvanceObjetivo(id: 'dias_activos', logrado: 5),
          AvanceObjetivo(id: 'sesiones_largas', logrado: 2),
        ],
        cierre: DateTime(2026, 1, 18),
        cierrePrevio: DateTime(2026, 1, 11),
      );
      expect(r.evaluable, isTrue);
      expect(r.objetivosCumplidos, 3);
      expect(r.rangoNuevo, 2);
    });

    test('siempre son exactamente tres', () {
      expect(objetivosProvisionales.length, objetivosPorSemana);
    });
  });
}
