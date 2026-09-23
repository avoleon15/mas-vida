import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';

/// Una semana es del mes de su LUNES.
///
/// Agosto de 2026 arranca sábado: el 1 y el 2 son la cola de la semana
/// del 27 de julio, y por eso agosto tiene CUATRO semanas y no cinco.
void main() {
  Historial historialQueTerminaEl(DateTime ultimo, {int dias = 40}) {
    return Historial(
      zonaHoraria: 'America/Guatemala',
      dias: [
        for (var i = dias - 1; i >= 0; i--)
          DiaActividad(
            fecha: ultimo.subtract(Duration(days: i)),
            origen: OrigenDatos.healthkit,
            pasos: 8000,
            puntosPasos: 25,
            puntosIntensidad: 0,
            puntosBrutos: 25,
            puntosDia: 25,
            topeAplicado: false,
            fuentes: const [],
            sesion: null,
            marcadoParaRevision: false,
            reversion: null,
            enCurso: false,
            ritmo: null,
          ),
      ],
    );
  }

  test('agosto de 2026 tiene cuatro semanas, no cinco', () {
    final h = historialQueTerminaEl(DateTime(2026, 8, 26));
    final semanas = h.semanasDelMes;

    expect(semanas.length, 4);
    expect(
      semanas.map((s) => s.first.fecha.day).toList(),
      [3, 10, 17, 24],
      reason: 'cada semana arranca en su lunes de agosto',
    );
  });

  test('el 1 y el 2 de agosto no son "semana 1": son de la semana de julio', () {
    final h = historialQueTerminaEl(DateTime(2026, 8, 26));
    final primera = h.semanasDelMes.first;

    expect(primera.length, 7, reason: 'la primera barra es una semana entera');
    expect(
      primera.any((d) => d.fecha.day <= 2),
      isFalse,
      reason: 'el 1 y el 2 cayeron en la semana del 27 de julio',
    );
  });

  test('la única semana corta es la última, porque va en curso', () {
    final h = historialQueTerminaEl(DateTime(2026, 8, 26));
    final semanas = h.semanasDelMes;

    for (final s in semanas.take(semanas.length - 1)) {
      expect(s.length, 7);
    }
    expect(semanas.last.length, 3, reason: 'lunes 24 a miércoles 26');
  });

  test('un mes que arranca lunes da semanas enteras desde el día 1', () {
    // Junio de 2026 arranca lunes.
    final h = historialQueTerminaEl(DateTime(2026, 6, 28));
    final semanas = h.semanasDelMes;

    expect(semanas.length, 4);
    expect(semanas.first.first.fecha.day, 1);
  });

  test('antes del primer lunes del mes se devuelve la semana en curso sola', () {
    // Sábado 1 de agosto de 2026: agosto todavía no tiene un lunes
    // propio, así que no tiene ninguna semana propia.
    final h = historialQueTerminaEl(DateTime(2026, 8, 1));
    final semanas = h.semanasDelMes;

    expect(semanas.length, 1, reason: 'una barra, sin nada al lado');
    expect(semanas.single, h.semanaEnCurso);
  });

  test('los días aplanados son exactamente los de las semanas del mes', () {
    final h = historialQueTerminaEl(DateTime(2026, 8, 26));

    expect(
      h.diasDeLasSemanasDelMes.length,
      h.semanasDelMes.fold<int>(0, (t, s) => t + s.length),
    );
    expect(h.diasDeLasSemanasDelMes.first.fecha.day, 3);
    expect(h.diasDeLasSemanasDelMes.last.fecha.day, 26);
  });

  test('el mock real también da cuatro semanas de agosto', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
    expect(Datos.i.historial.semanasDelMes.length, 4);
  });
}
