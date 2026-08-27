import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/reglas_puntos.dart';
import 'package:vida_demo/screens/home_screen.dart';
import 'package:vida_demo/screens/mi_plan_screen.dart';
import 'package:vida_demo/screens/premios_screen.dart';
import 'package:vida_demo/screens/progress_screen.dart';
import 'package:vida_demo/screens/social_screen.dart';
import 'package:vida_demo/theme.dart';

/// Verifica que los datos de prueba respetan las reglas del contrato y
/// que las pantallas montan con ellos.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Datos.cargar();
  });

  group('Datos de prueba', () {
    test('el historial trae 35 días', () {
      expect(Datos.i.historial.dias.length, 35);
    });

    test('ningún día supera el techo diario de 200 pts', () {
      for (final d in Datos.i.historial.dias) {
        expect(
          d.puntosDia,
          lessThanOrEqualTo(techoDiario),
          reason: 'El día ${d.fecha} acredita ${d.puntosDia} pts',
        );
      }
    });

    test('los puntos de cada día coinciden con el motor de reglas', () {
      for (final d in Datos.i.historial.dias) {
        if (d.sinPermiso) continue;
        final esperado = calcularDia(
          pasos: d.pasos!,
          edad: Datos.i.perfil.edad,
          minutosSesion: d.sesion?.duracionMin ?? 0,
          porcentajeFcm: d.sesion?.porcentajeFcm ?? 0,
          sesionContinua: d.sesion?.continua ?? true,
          manual: d.esManual,
        );
        expect(
          d.puntosDia,
          esperado.puntosAcreditados,
          reason: 'Descuadre el ${d.fecha}',
        );
      }
    });

    test('el día sin permiso tiene pasos null, no cero', () {
      final sinPermiso = Datos.i.historial.dias.where((d) => d.sinPermiso);
      expect(sinPermiso, isNotEmpty);
      for (final d in sinPermiso) {
        expect(d.pasos, isNull);
      }
    });

    test('el acumulado anual deja al usuario en un nivel real', () {
      final resumen = Datos.i.resumen;
      expect(nivelParaPuntos(resumen.puntosAno), resumen.nivel);
      expect(nivelPorNumero(resumen.nivel)!.definido, isTrue);
    });

    test('el acumulado anual no supera el techo de 12.000', () {
      expect(Datos.i.resumen.puntosAno, lessThanOrEqualTo(techoAnual));
    });

    test('la actividad por mes suma el acumulado anual', () {
      final suma = Datos.i.resumen.actividadPorMes.reduce((a, b) => a + b);
      expect(suma, Datos.i.resumen.puntosAno);
    });

    test('la semana en curso coincide con la suma del historial', () {
      final suma = Datos.i.historial.semanaEnCurso
          .map((d) => d.puntosDia)
          .reduce((a, b) => a + b);
      expect(suma, Datos.i.resumen.puntosSemana);
    });

    test('el mes en curso coincide con la suma del historial', () {
      final suma = Datos.i.historial.mesEnCurso
          .map((d) => d.puntosDia)
          .reduce((a, b) => a + b);
      expect(suma, Datos.i.resumen.puntosMes);
    });

    test('están cubiertos los casos de borde pedidos', () {
      final dias = Datos.i.historial.dias;
      bool hay(bool Function(DiaActividad) f) => dias.any(f);

      expect(hay((d) => d.pasos == 6999 && d.puntosDia == 0), isTrue,
          reason: '6.999 pasos → 0 pts');
      expect(hay((d) => d.pasos == 7000 && d.puntosDia == 25), isTrue,
          reason: '7.000 pasos → 25 pts');
      expect(hay((d) => d.pasos == 12400 && d.puntosPasos == 50), isTrue,
          reason: '12.400 pasos → 50 pts');
      expect(hay((d) => d.pasos == 23000 && d.puntosPasos == 100), isTrue,
          reason: '23.000 pasos → 100 pts');
      expect(hay((d) => d.sesion?.cuentaParaPuntos == false), isTrue,
          reason: 'sesión de menos de 30 min');
      expect(hay((d) => d.sesion?.puntosIntensidad == 100), isTrue,
          reason: '42 min al 74% de FCM');
      expect(hay((d) => d.esManual && d.puntosDia == 0), isTrue,
          reason: 'pasos manuales → 0 pts');
      expect(hay((d) => d.sinPermiso), isTrue, reason: 'día sin permiso');
      expect(hay((d) => d.marcadoParaRevision && d.puntosDia > 0), isTrue,
          reason: 'atípico marcado que sigue acreditando');
      expect(hay((d) => d.reversion != null), isTrue, reason: 'reversión');
      expect(hay((d) => d.huboPrecedencia), isTrue,
          reason: 'precedencia entre fuentes');
    });

    test('la precedencia toma la fuente con más pasos, nunca la suma', () {
      for (final d in Datos.i.historial.dias.where((d) => d.huboPrecedencia)) {
        final maximo = d.fuentes
            .map((f) => f.pasos)
            .reduce((a, b) => a > b ? a : b);
        expect(d.pasos, maximo);
        expect(d.fuentePrevalece!.pasos, maximo);
      }
    });

    test('hay un lote de monedas cerca de caducar', () {
      expect(Datos.i.resumen.monedas.proximoLoteACaducar!.cercaDeCaducar,
          isTrue);
    });

    test('los lotes de monedas suman el saldo', () {
      final suma = Datos.i.resumen.monedas.lotes
          .map((l) => l.cantidad)
          .reduce((a, b) => a + b);
      expect(suma, Datos.i.resumen.monedas.saldo);
    });

    test('el historial de retos tiene una semana ganada y una perdida', () {
      final h = Datos.i.resumen.retos.historial;
      expect(h.any((s) => s.completado), isTrue);
      expect(h.any((s) => !s.completado), isTrue);
    });

    test('el cashback proyectado es el % del nivel sobre la prima', () {
      final pct = nivelPorNumero(Datos.i.resumen.nivel)!.porcentajeCashback!;
      final prima = 18000; // Q18,000 de la póliza mock
      expect(Datos.i.resumen.cashback.proyectadoQ, (prima * pct / 100).round());
    });

    test('ningún premio expone su costo en quetzales', () {
      // El valor de una moneda en quetzales todavía no existe.
      expect(Datos.i.resumen.monedas.valorEnQuetzales, isNull);
    });
  });

  group('Las pantallas montan con los datos de prueba', () {
    Future<void> montar(WidgetTester tester, Widget pantalla) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: pantalla),
      );
      await tester.pump();
    }

    testWidgets('Home', (t) async {
      await montar(t, const HomeScreen());
      expect(find.textContaining('Nivel'), findsWidgets);
    });

    testWidgets('Progress', (t) async {
      await montar(t, const ProgressScreen());
      expect(find.textContaining('Nivel'), findsWidgets);
    });

    testWidgets('Social', (t) async {
      await montar(t, const SocialScreen());
      expect(find.textContaining('Duelos'), findsWidgets);
    });

    testWidgets('Premios', (t) async {
      await montar(t, const PremiosScreen());
      expect(find.text('Premios'), findsWidgets);
    });

    testWidgets('Mi Plan', (t) async {
      await montar(t, const MiPlanScreen());
      expect(find.text('Mi Plan'), findsWidgets);
    });
  });
}
