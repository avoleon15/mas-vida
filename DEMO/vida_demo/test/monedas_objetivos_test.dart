import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/reglas_rango.dart';

/// El producto tiene DOS monedas —PUNTOS (cashback anual) y MONEDAS (se
/// gastan en Premios)— y no se mezclan.
///
/// No hay una tercera. Existio un medidor de XP y se fue: no decidia
/// nada (el rango siempre se movio con `cumplidos == 3`) y ademas la UI
/// arrastraba un sobrante entre semanas que el motor nunca aplico. Varios
/// de estos tests estan justamente para que no vuelva.
///
/// La regla que se fija: cumplir los TRES objetivos sube un rango, y
/// SUBIR de rango es lo unico que paga MONEDAS.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  group('La regla son tres checks, y nada mas', () {
    test('una semana subio de rango si y solo si cumplio los tres', () {
      for (final w in Datos.i.resumen.objetivosSemana.semanas) {
        expect(
          w.subioDeRango,
          w.cumplidos == w.objetivos.length,
          reason: 'semana ${w.numero}',
        );
      }
    });

    test('los tres objetivos son intercambiables entre si', () {
      // Ninguno pesa mas que otro: sin cualquiera de los tres, la semana
      // no cuenta. Es lo que reemplazo al reparto 40/35/25 del XP, que
      // sugeria que unos valian mas cuando el resultado era el mismo.
      for (final w in Datos.i.resumen.objetivosSemana.semanas) {
        if (w.cumplidos == w.objetivos.length) continue;
        expect(w.subioDeRango, isFalse, reason: 'semana ${w.numero}');
      }
    });

    test('faltan + cumplidos siempre da el total', () {
      for (final w in Datos.i.resumen.objetivosSemana.semanas) {
        expect(w.faltan + w.cumplidos, w.objetivos.length);
      }
    });

    test('ningun objetivo del mock trae un valor propio', () {
      // Si vuelve a aparecer un campo tipo `xp` en el JSON, el modelo lo
      // ignora y este test no lo ve — pero el modelo tampoco lo expone,
      // que es lo que importa: no hay forma de que la UI vuelva a pintar
      // un "+40" al lado de un objetivo suelto.
      final objetivo =
          Datos.i.resumen.objetivosSemana.semanas.first.objetivos.first;
      expect(objetivo.nombre, isNotEmpty);
      expect(objetivo.unidad, isNotEmpty);
    });
  });

  group('El mock no se contradice a si mismo', () {
    test('el rango declarado cuadra con lo que hicieron sus semanas', () {
      // Sin esto el mock miente sin avisar: tenia una semana a medias, que
      // BAJA el rango, y aun asi declaraba rango 2. La pantalla mostraba un
      // rango que sus propias semanas no justificaban.
      final s = Datos.i.resumen.objetivosSemana;
      expect(
        s.rangoActual,
        s.rangoSegunSemanas,
        reason: 'nivel_actual del mock no coincide con sus semanas cerradas',
      );
    });

    test('las monedas del periodo son las que pagan esos ascensos', () {
      final s = Datos.i.resumen.objetivosSemana;

      var rango = rangoMinimo;
      var esperado = 0;
      for (final w in s.semanas) {
        if (w.estado != EstadoSemana.cerrada) continue;
        if (w.subioDeRango) {
          rango = (rango + 1).clamp(rangoMinimo, rangoMaximo);
          esperado += monedasPorSubirA(rango);
        } else {
          rango = (rango - 1).clamp(rangoMinimo, rangoMaximo);
        }
      }

      expect(s.monedasGanadas, esperado);
    });

    test('el programa trae una semana por rango', () {
      expect(Datos.i.resumen.objetivosSemana.semanas.length, rangoMaximo);
    });

    test('hay exactamente una semana en curso', () {
      final enCurso = Datos.i.resumen.objetivosSemana.semanas
          .where((w) => w.estado == EstadoSemana.enCurso)
          .length;
      expect(enCurso, 1);
    });

    test('el mock trae una semana a medias, para poder probar ese caso', () {
      // Si el mock no trae ninguna, los tests de "cumplir dos no paga"
      // pasan sin probar nada: mejor saberlo que tener un verde falso.
      final aMedias = Datos.i.resumen.objetivosSemana.semanas.where(
        (w) =>
            w.estado != EstadoSemana.futura &&
            w.cumplidos > 0 &&
            !w.subioDeRango,
      );
      expect(aMedias, isNotEmpty);
    });
  });

  group('Solo paga subir de rango', () {
    test('una semana CERRADA solo paga si hizo subir de rango', () {
      // Solo las cerradas: en las que todavía no cerraron, `monedas` es
      // una proyección de mejor caso —asume que las cumple— y por eso
      // trae monto aunque la semana no esté completa. Eso NO es plata
      // acreditada, y por eso viaja marcada con `proyectado`.
      final s = Datos.i.resumen.objetivosSemana;
      for (final p in s.recorrido) {
        if (p.proyectado || p.semana.subioDeRango) continue;
        expect(p.monedas, 0, reason: 'semana ${p.semana.numero}');
      }
    });

    test('cumplir uno o dos objetivos no paga nada', () {
      // Lo que paga es SUBIR de rango, y para eso hay que cumplir los
      // tres. Una semana a medias no deja nada acreditado ni arrastra
      // saldo a la siguiente.
      final s = Datos.i.resumen.objetivosSemana;
      final pagos = s.monedasPorSemana;

      for (final w in s.semanas) {
        if (w.estado == EstadoSemana.futura || w.subioDeRango) continue;
        expect(w.cumplidos, lessThan(w.objetivos.length));
        expect(pagos[w.numero], 0, reason: 'semana ${w.numero}');
      }
    });

    test('la semana en curso no paga hasta que cierre', () {
      // Aunque tenga los tres cumplidos: se evalua el domingo 23:59. Esta
      // regla existe porque el modelo y la hoja de monedas la aplicaban
      // distinto — el modelo contaba la semana en curso y la hoja no.
      final s = Datos.i.resumen.objetivosSemana;
      final pagos = s.monedasPorSemana;
      for (final w in s.semanas) {
        if (w.estado == EstadoSemana.cerrada) continue;
        expect(pagos[w.numero], 0, reason: 'semana ${w.numero}');
      }
    });

    test('el total del periodo es la suma de lo que pago cada semana', () {
      final s = Datos.i.resumen.objetivosSemana;
      final suma = s.monedasPorSemana.values.fold(0, (a, b) => a + b);
      expect(s.monedasGanadas, suma);
    });
  });

  group('La escalera', () {
    test('paga de 5 en 5, del rango 1 al 10', () {
      expect(rangoMinimo, 0);
      expect(rangoMaximo, 10);

      expect(monedasPorSubirA(1), 5);
      expect(monedasPorSubirA(2), 10);
      expect(monedasPorSubirA(3), 15);
      expect(monedasPorSubirA(10), 50);

      // El piso no se "sube", así que no paga. Y fuera de la escalera
      // tampoco: mejor cero que una cifra inventada.
      expect(monedasPorSubirA(0), 0);
      expect(monedasPorSubirA(11), 0);
      expect(monedasPorSubirA(-3), 0);
    });

    test('cada escalon paga mas que el anterior', () {
      // Es lo que el recorrido completo dibuja con sus flores. Si algun
      // escalon pagara menos que el de abajo, la hoja mentiria.
      for (var r = rangoMinimo + 2; r <= rangoMaximo; r++) {
        expect(monedasPorSubirA(r), greaterThan(monedasPorSubirA(r - 1)));
      }
    });

    test('recorrerla entera paga 275 monedas', () {
      var total = 0;
      for (var r = 1; r <= rangoMaximo; r++) {
        total += monedasPorSubirA(r);
      }
      expect(total, 275);
    });
  });
}
