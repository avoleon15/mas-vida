import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/reglas_puntos.dart';

// Tests del motor de reglas contra el contrato v1 congelado.
//
// Este motor NO es la fuente de verdad en producción (los puntos los
// calcula el backend), pero sirve para verificar el motor de Luis contra
// las mismas reglas.

void main() {
  group('Puntos por pasos', () {
    test('por debajo del piso de 7.000 no acredita nada', () {
      expect(puntosPorPasos(0), 0);
      expect(puntosPorPasos(6999), 0);
    });

    test('7.000 exactos acreditan 25 pts', () {
      expect(puntosPorPasos(7000), 25);
    });

    test('el escalón de 25 llega hasta antes de 10.000', () {
      expect(puntosPorPasos(9999), 25);
    });

    test('de 10.000 a 15.000 acredita 50 pts', () {
      expect(puntosPorPasos(10000), 50);
      expect(puntosPorPasos(12400), 50);
      expect(puntosPorPasos(14999), 50);
    });

    test('desde 15.000 acredita 100 pts', () {
      expect(puntosPorPasos(15000), 100);
      expect(puntosPorPasos(23000), 100);
    });

    test('caminar más de 15.000 no da puntos adicionales', () {
      expect(puntosPorPasos(23000), puntosPorPasos(46000));
    });
  });

  group('FCM', () {
    test('es 219 − edad, no 220', () {
      expect(frecuenciaCardiacaMaxima(45), 174);
      expect(frecuenciaCardiacaMaxima(62), 157);
    });
  });

  group('Puntos por intensidad', () {
    test('una sesión de menos de 30 min no cuenta', () {
      expect(
        puntosPorIntensidad(minutos: 28, porcentajeFcm: 71, continua: true),
        0,
      );
    });

    test('una sesión no continua no cuenta aunque sume los minutos', () {
      expect(
        puntosPorIntensidad(minutos: 42, porcentajeFcm: 74, continua: false),
        0,
      );
    });

    test('42 min al 74% de FCM acredita 100 pts (ancla del contrato)', () {
      expect(
        puntosPorIntensidad(minutos: 42, porcentajeFcm: 74, continua: true),
        100,
      );
    });

    test('una celda sin definir devuelve null, nunca un número inventado', () {
      expect(
        puntosPorIntensidad(minutos: 60, porcentajeFcm: 80, continua: true),
        isNull,
      );
    });
  });

  group('Bonus 60+', () {
    test('no aplica por debajo de 60 años', () {
      expect(aplicarBonus60Mas(100, 45), 100);
      expect(aplicarBonus60Mas(100, 59), 100);
    });

    test('multiplica ×1.25 desde los 60', () {
      expect(aplicarBonus60Mas(100, 60), 125);
      expect(aplicarBonus60Mas(100, 62), 125);
    });

    test('nunca se aplica a los puntos de pasos', () {
      // El bonus vive en la vía de intensidad: un día solo de pasos da lo
      // mismo a los 45 que a los 62.
      final joven = calcularDia(pasos: 23000, edad: 45);
      final mayor = calcularDia(pasos: 23000, edad: 62);
      expect(joven.puntosAcreditados, mayor.puntosAcreditados);
    });
  });

  group('Total del día y techo diario', () {
    test('suma las dos vías el mismo día', () {
      final dia = calcularDia(
        pasos: 9100,
        edad: 45,
        minutosSesion: 42,
        porcentajeFcm: 74,
      );
      expect(dia.puntosPasos, 25);
      expect(dia.puntosIntensidad, 100);
      expect(dia.puntosAcreditados, 125);
    });

    test('los datos manuales no acreditan ningún punto', () {
      final dia = calcularDia(pasos: 11200, edad: 45, manual: true);
      expect(dia.puntosPasos, 0);
      expect(dia.puntosAcreditados, 0);
    });

    test('llegar exactamente a 200 no marca el tope como aplicado', () {
      final dia = calcularDia(
        pasos: 17800,
        edad: 45,
        minutosSesion: 42,
        porcentajeFcm: 74,
      );
      expect(dia.puntosBrutos, 200);
      expect(dia.puntosAcreditados, 200);
      expect(dia.topeAplicado, isFalse);
    });

    test('pasar de 200 acredita 200 y marca la bandera', () {
      // Se fuerza con el bonus 60+, la única vía que hoy permite pasar de
      // 200 con los números definidos: 100 de pasos + 125 de intensidad.
      final dia = calcularDia(
        pasos: 23000,
        edad: 62,
        minutosSesion: 42,
        porcentajeFcm: 74,
      );
      expect(dia.puntosBrutos, 225);
      expect(dia.puntosAcreditados, techoDiario);
      expect(dia.topeAplicado, isTrue);
    });
  });

  group('Niveles', () {
    test('los niveles 1 y 2 no están definidos', () {
      expect(nivelPorNumero(1)!.definido, isFalse);
      expect(nivelPorNumero(2)!.definido, isFalse);
      expect(nivelPorNumero(1)!.rangoTexto, 'Pendiente de definir');
    });

    test('nivel 3 va de 10.000 a 15.000 con 10% de cashback', () {
      final n = nivelPorNumero(3)!;
      expect(n.puntosMinimos, 10000);
      expect(n.puntosMaximos, 15000);
      expect(n.porcentajeCashback, 10);
    });

    test('nivel 4 es 15.000+ con 20% de cashback', () {
      final n = nivelPorNumero(4)!;
      expect(n.puntosMinimos, 15000);
      expect(n.porcentajeCashback, 20);
    });

    test('por debajo de 10.000 el nivel es desconocido, no inventado', () {
      expect(nivelParaPuntos(0), isNull);
      expect(nivelParaPuntos(9999), isNull);
    });

    test('mapea el acumulado a nivel 3 o 4 según corresponda', () {
      expect(nivelParaPuntos(11240), 3);
      expect(nivelParaPuntos(15000), 4);
    });

    test('el techo anual de 12.000 deja el nivel 4 fuera de alcance', () {
      expect(nivelParaPuntos(techoAnual), 3);
      expect(nivelPorNumero(4)!.puntosMinimos! > techoAnual, isTrue);
    });
  });
}
