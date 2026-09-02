import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';

/// El chip de monedas del encabezado tiene que cuadrar con la suma que el
/// usuario puede hacer a ojo mirando las tarjetas de cada semana.
///
/// Antes mostraba el saldo de la billetera, que incluye meses anteriores
/// y descuenta lo gastado en Premios: no cuadraba con nada de lo visible.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  test('el total del encabezado es la suma de las semanas', () {
    final semana = Datos.i.resumen.objetivosSemana;
    final sumaAMano = semana.semanas.fold(0, (s, w) => s + w.monedasGanadas);
    expect(semana.monedasGanadas, sumaAMano);
  });

  test('solo cuentan los objetivos completados', () {
    for (final w in Datos.i.resumen.objetivosSemana.semanas) {
      final esperado = w.objetivos
          .where((o) => o.completo)
          .fold(0, (s, o) => s + o.monedas);
      expect(w.monedasGanadas, esperado, reason: 'semana ${w.numero}');
    }
  });

  test('el total NO es el saldo de la billetera', () {
    // Son dos cantidades distintas a proposito. Si algun dia coinciden
    // por casualidad este test no sirve, pero hoy documenta la diferencia.
    final resumen = Datos.i.resumen;
    expect(resumen.objetivosSemana.monedasGanadas, isNot(resumen.monedas.saldo));
  });
}
