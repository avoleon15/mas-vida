import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/widgets/hoja_monedas.dart';

import 'ayudas.dart';

// ============================================================
// HOJA DE MONEDAS: qué pagó cada semana.
//
// Cada objetivo paga por separado (CLAUDE.md, "Las 2 monedas"). La hoja
// decía "Cumpliste los dos: por eso pagó N monedas" y "No cumpliste los
// dos: no hubo monedas", la regla de antes del 2 de octubre: quien cumplía
// solo los pasos y ganaba monedas leía que no había ganado nada.
// ============================================================

ObjetivoSemanal _objetivo(
  String nombre, {
  required bool completo,
  int monedas = 5,
}) => ObjetivoSemanal(
  id: nombre.toLowerCase(),
  nombre: nombre,
  progreso: completo ? 100 : 10,
  meta: 100,
  unidad: 'u',
  completo: completo,
  monedas: monedas,
);

SemanaObjetivos _semana(
  List<ObjetivoSemanal> objetivos, {
  EstadoSemana estado = EstadoSemana.cerrada,
}) => SemanaObjetivos(
  numero: 3,
  cierra: DateTime(2026, 10, 11, 23, 59),
  estado: estado,
  objetivos: objetivos,
);

void main() {
  Future<void> montar(WidgetTester t, SemanaObjetivos semana) async {
    t.view.physicalSize = const Size(390, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await montarPantalla(t, Scaffold(body: FilaSemanaMonedas(semana: semana)));
    await t.pump();
  }

  testWidgets('cumplir solo un objetivo paga ese objetivo, y la hoja lo dice', (
    t,
  ) async {
    await montar(
      t,
      _semana([
        _objetivo('Pasos', completo: true, monedas: 5),
        _objetivo('Workouts', completo: false, monedas: 8),
      ]),
    );

    expect(find.text('Pasos · +5 monedas'), findsOneWidget);
    expect(find.textContaining('Workouts'), findsNothing);
    expect(find.text('+5'), findsOneWidget);
    // La regla vieja no vuelve.
    expect(find.textContaining('Cumpliste los dos'), findsNothing);
    expect(find.textContaining('No cumpliste los dos'), findsNothing);
    expect(find.textContaining('no hubo monedas'), findsNothing);
  });

  testWidgets('cumplir los dos suma las monedas de cada uno', (t) async {
    await montar(
      t,
      _semana([
        _objetivo('Pasos', completo: true, monedas: 5),
        _objetivo('Workouts', completo: true, monedas: 8),
      ]),
    );

    expect(find.text('Pasos · +5 monedas'), findsOneWidget);
    expect(find.text('Workouts · +8 monedas'), findsOneWidget);
    expect(find.text('+13'), findsOneWidget);
  });

  testWidgets('con una sola moneda dice "moneda", no "1 monedas"', (t) async {
    await montar(t, _semana([_objetivo('Pasos', completo: true, monedas: 1)]));

    expect(find.text('Pasos · +1 moneda'), findsOneWidget);
    expect(find.textContaining('1 monedas'), findsNothing);
  });

  testWidgets('sin ningún objetivo cumplido lo dice, sin inventar monedas', (
    t,
  ) async {
    await montar(
      t,
      _semana([
        _objetivo('Pasos', completo: false),
        _objetivo('Workouts', completo: false),
      ]),
    );

    expect(find.text('No cumpliste ningún objetivo'), findsOneWidget);
    expect(find.text('+0'), findsOneWidget);
    expect(find.textContaining('monedas'), findsNothing);
  });

  testWidgets('una semana en curso todavía no pagó: solo dice cumplido', (
    t,
  ) async {
    await montar(
      t,
      _semana([
        _objetivo('Pasos', completo: true, monedas: 5),
        _objetivo('Workouts', completo: false),
      ], estado: EstadoSemana.enCurso),
    );

    expect(find.text('Pasos · cumplido'), findsOneWidget);
    expect(find.text('+0'), findsOneWidget);
  });
}
