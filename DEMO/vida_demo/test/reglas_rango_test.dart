import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/reglas_rango.dart';

/// Tres objetivos con dificultad definida, para poder evaluar semanas.
/// Los objetivos reales todavia no tienen tabla de dificultad: estos son
/// de test, no del producto.
///
/// La tabla cubre los ONCE rangos (0 a 10). Antes llegaba solo al 4, y al
/// ampliarse la escalera las semanas que caian fuera dejaban de poder
/// evaluarse: el motor congelaba el rango en vez de moverlo.
const _objetivos = [
  DefinicionObjetivo(
    id: 'pasos_semana',
    nombre: 'Pasos de la semana',
    unidad: 'pasos',
    metaPorRango: {
      0: 20000,
      1: 30000,
      2: 40000,
      3: 50000,
      4: 60000,
      5: 70000,
      6: 80000,
      7: 90000,
      8: 100000,
      9: 110000,
      10: 120000,
    },
  ),
  DefinicionObjetivo(
    id: 'intensidad_semana',
    nombre: 'Minutos de intensidad',
    unidad: 'minutos',
    metaPorRango: {
      0: 30,
      1: 60,
      2: 90,
      3: 120,
      4: 150,
      5: 180,
      6: 210,
      7: 240,
      8: 270,
      9: 300,
      10: 330,
    },
  ),
  DefinicionObjetivo(
    id: 'dias_ritmo_alto',
    nombre: 'Dias con ritmo cardiaco alto',
    unidad: 'dias',
    // Topa en 7: una semana no tiene mas dias.
    metaPorRango: {
      0: 1,
      1: 2,
      2: 3,
      3: 4,
      4: 5,
      5: 5,
      6: 6,
      7: 6,
      8: 7,
      9: 7,
      10: 7,
    },
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
}) =>
    evaluarSemana(rangoPrevio: rango, objetivos: _objetivos, avances: avances);

/// Avances que superan la meta de CUALQUIER rango de la tabla de arriba.
List<AvanceObjetivo> _semanaPerfecta() =>
    _avances(pasos: 200000, minutos: 400, dias: 7);

void main() {
  group('El programa y la escalera son del mismo largo', () {
    test('hay una semana por rango', () {
      // Es la regla que hace legible todo lo demas: una semana perfecta
      // vale un escalon, asi que cumplir todas las semanas llega justo al
      // techo. Si estos dos numeros se separan, el tallo de Hoy dibuja un
      // recorrido que la escalera no puede pagar.
      expect(semanasDelPrograma, rangoMaximo);
    });

    test('cumplir todas las semanas llega exactamente al techo', () {
      var rango = rangoMinimo;
      for (var semana = 0; semana < semanasDelPrograma; semana++) {
        rango = _cerrar(rango: rango, avances: _semanaPerfecta()).rangoNuevo;
      }
      expect(rango, rangoMaximo);
    });
  });

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

    test('cumplir DOS no sube el rango ni paga monedas', () {
      final r = _cerrar(
        rango: 2,
        avances: _avances(pasos: 40000, minutos: 90, dias: 0),
      );
      expect(r.objetivosCumplidos, 2);
      // Dos de tres BAJA, no se queda: la regla no tiene punto medio.
      expect(r.movimiento, MovimientoRango.baja);
      expect(r.rangoNuevo, 1);
      expect(r.monedasGanadas, 0);
      expect(r.ganaMonedas, isFalse);
    });

    test('cumplir UNO no sube el rango ni paga monedas', () {
      final r = _cerrar(rango: 2, avances: _avances(pasos: 40000));
      expect(r.objetivosCumplidos, 1);
      expect(r.movimiento, MovimientoRango.baja);
      expect(r.monedasGanadas, 0);
    });

    test('cumplir dos vale lo MISMO que cumplir cero', () {
      // Es la regla que se dejo de contar cuando existia el XP: con XP,
      // dos objetivos dejaban un sobrante que se arrastraba. Ahora no
      // queda nada. Si alguien vuelve a meter credito parcial, esto se
      // pone rojo.
      final dos = _cerrar(
        rango: 5,
        avances: _avances(pasos: 100000, minutos: 300, dias: 0),
      );
      final cero = _cerrar(rango: 5, avances: _avances());

      expect(dos.rangoNuevo, cero.rangoNuevo);
      expect(dos.monedasGanadas, cero.monedasGanadas);
      expect(dos.movimiento, cero.movimiento);
    });

    test('subir de rango paga 5 monedas por escalon alcanzado', () {
      final r = _cerrar(
        rango: 2,
        avances: _avances(pasos: 50000, minutos: 120, dias: 5),
      );
      expect(r.movimiento, MovimientoRango.sube);
      expect(r.rangoNuevo, 3);
      // Llegar al rango 3 paga 15: el monto sale del rango ALCANZADO,
      // no del que se traia.
      expect(r.monedasGanadas, 15);
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
      final r = _cerrar(rango: 1, avances: _semanaPerfecta());
      // Arrasar con los objetivos no salta dos rangos.
      expect(r.rangoNuevo, 2);
    });

    test('el movimiento es de UN escalon como maximo, para abajo', () {
      final r = _cerrar(rango: 4, avances: _avances());
      expect(r.rangoNuevo, 3);
    });
  });

  group('Piso y techo', () {
    test('el piso es 0 y el techo es 10', () {
      expect(rangoMinimo, 0);
      expect(rangoMaximo, 10);
    });

    test('desde el piso no se baja mas', () {
      final r = _cerrar(rango: rangoMinimo, avances: _avances());
      expect(r.rangoNuevo, rangoMinimo);
      expect(r.movimiento, MovimientoRango.seQueda);
    });

    test('desde el techo no se sube mas', () {
      final r = _cerrar(rango: rangoMaximo, avances: _semanaPerfecta());
      expect(r.rangoNuevo, rangoMaximo);
      expect(r.movimiento, MovimientoRango.seQueda);
    });
  });

  group('El rango NO se reinicia', () {
    // El reinicio mensual existio y se fue: era incompatible con un
    // programa de diez semanas corridas. Diez semanas cruzan dos veces de
    // mes, asi que con el reinicio nadie pasaba del rango 4 y la escalera
    // de 10 era inalcanzable por construccion.
    //
    // Estos tests fijan que no vuelva por la puerta de atras.

    test('evaluar una semana no depende de ninguna fecha', () {
      // Si el motor volviera a mirar el calendario, esta firma no
      // compilaria. El test es la firma misma: `evaluarSemana` no recibe
      // fechas, y por eso el mismo avance da siempre el mismo resultado.
      final unaVez = _cerrar(rango: 3, avances: _semanaPerfecta());
      final otraVez = _cerrar(rango: 3, avances: _semanaPerfecta());
      expect(unaVez.rangoNuevo, otraVez.rangoNuevo);
      expect(unaVez.monedasGanadas, otraVez.monedasGanadas);
    });

    test('una racha larga no se corta sola a mitad del programa', () {
      // Con el reinicio mensual, el rango caia al piso alrededor de la
      // quinta semana. Acá sube sin interrupciones.
      var rango = rangoMinimo;
      final recorrido = <int>[];
      for (var semana = 0; semana < semanasDelPrograma; semana++) {
        rango = _cerrar(rango: rango, avances: _semanaPerfecta()).rangoNuevo;
        recorrido.add(rango);
      }
      expect(recorrido, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });
  });

  group('El ciclo de la semana sigue siendo lunes a domingo', () {
    // Semana del lunes 26 de enero al domingo 1 de febrero de 2026:
    // arranca en enero y cierra en febrero. Que una semana se parta entre
    // dos meses ya no cambia nada del rango, pero el ciclo sigue yendo de
    // lunes 00:00 a domingo 23:59 (hora de Guatemala).
    final lunesEnero = DateTime(2026, 1, 26);
    final domingoFebrero = DateTime(2026, 2, 1);

    test('el lunes y el domingo de esa semana son los esperados', () {
      expect(lunesDeLaSemana(domingoFebrero), lunesEnero);
      expect(domingoDeLaSemana(lunesEnero).day, 1);
      expect(domingoDeLaSemana(lunesEnero).month, DateTime.february);
    });

    test('el domingo se evalua a las 23:59:59', () {
      final cierre = domingoDeLaSemana(lunesEnero);
      expect(cierre.hour, 23);
      expect(cierre.minute, 59);
      expect(cierre.second, 59);
    });

    test('cualquier dia de la semana cae en el mismo lunes', () {
      final lunes = <DateTime>{
        for (var d = 0; d < 7; d++)
          lunesDeLaSemana(lunesEnero.add(Duration(days: d))),
      };
      expect(lunes.length, 1);
      expect(lunes.single, lunesEnero);
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

  group('Objetivos sin dificultad definida', () {
    test('no se evalua, el rango se congela y no paga monedas', () {
      // Los tres objetivos reales del producto todavia no tienen tabla de
      // dificultad: mientras no la tengan, el rango no se mueve.
      final r = evaluarSemana(
        rangoPrevio: 3,
        objetivos: objetivosProvisionales,
        avances: _semanaPerfecta(),
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
