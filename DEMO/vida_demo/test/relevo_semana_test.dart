import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/reglas_rango.dart';

// ============================================================
// EL RELEVO DE SEMANA: LUNES 00:00, HORA DE GUATEMALA.
//
// Quién decide qué semana corre es el SERVIDOR. Lo que se prueba acá es
// lo único que hace el teléfono: volver a preguntar en el momento justo,
// y no antes.
//
// Que no lo decida el teléfono no es un detalle de arquitectura: si lo
// decidiera, cambiar la zona horaria en Ajustes abriría una semana nueva
// antes de tiempo, con tres objetivos nuevos y un rango más para ganar.
// ============================================================

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  tearDown(cancelarRelevoDeSemana);

  group('Cuándo se vuelve a preguntar', () {
    test('espera hasta el cierre, más un segundo de gracia', () {
      final cierre = DateTime.utc(2026, 9, 21, 5, 59, 59); // domingo 23:59 GT
      final ahora = cierre.subtract(const Duration(hours: 3));

      expect(
        esperaHastaElRelevo(cierre, ahora),
        const Duration(hours: 3, seconds: 1),
      );
    });

    test('el segundo de gracia evita la carrera con el servidor', () {
      // El servidor evalúa a las 23:59:59. Preguntar en ese mismo
      // instante puede traer todavía la semana vieja.
      final cierre = DateTime.utc(2026, 9, 21, 5, 59, 59);
      expect(esperaHastaElRelevo(cierre, cierre), const Duration(seconds: 1));
    });

    test('si el cierre ya pasó no pregunta en bucle', () {
      // Una tanda atrasada —el servidor todavía manda la semana vieja—
      // dejaría a la app preguntando sin parar: pregunta, le contestan lo
      // mismo, y como sigue vencida vuelve a preguntar en el acto.
      final cierre = DateTime.utc(2026, 9, 21, 5, 59, 59);
      final espera = esperaHastaElRelevo(
        cierre,
        cierre.add(const Duration(hours: 2)),
      );

      expect(espera, greaterThan(Duration.zero));
      expect(espera, const Duration(minutes: 5));
    });
  });

  group('La semana cargada', () {
    test('la del mock cierra un domingo a las 23:59 de Guatemala', () {
      final cierre = enHoraDeGuatemala(cierreDeLaSemanaEnCurso()!);

      expect(cierre.weekday, DateTime.sunday);
      expect(cierre.hour, 23);
      expect(cierre.minute, 59);
    });

    test('no está vencida antes de su cierre', () {
      final cierre = cierreDeLaSemanaEnCurso()!;
      expect(
        semanaVencida(ahora: cierre.subtract(const Duration(minutes: 1))),
        isFalse,
      );
    });

    test('está vencida apenas pasa el cierre', () {
      // Lunes 00:00 en Guatemala: ahí ya tiene que correr la semana
      // siguiente, así que lo que está en pantalla quedó viejo.
      final cierre = cierreDeLaSemanaEnCurso()!;
      expect(
        semanaVencida(ahora: cierre.add(const Duration(seconds: 2))),
        isTrue,
      );
    });

    test('la comparación no depende del huso del teléfono', () {
      // El mismo instante, escrito en dos husos distintos, tiene que dar
      // la misma respuesta: alguien de viaje ve el mismo cierre.
      final cierre = cierreDeLaSemanaEnCurso()!;
      final despues = cierre.add(const Duration(minutes: 30));

      expect(semanaVencida(ahora: despues.toUtc()), isTrue);
      expect(semanaVencida(ahora: despues.toLocal()), isTrue);
    });
  });
}
