import 'package:flutter/material.dart';
import 'theme.dart';
import 'widgets/progress_ring.dart';

/// Pantalla de revisión del anillo de pasos. NO es parte de la app: es un
/// punto de entrada aparte para mirar todos los estados juntos, con las
/// fuentes y las animaciones reales.
///
///   flutter run -d chrome -t lib/demo_anillo.dart
///
/// Se puede borrar sin tocar nada del producto.
void main() => runApp(const DemoAnilloApp());

/// Los pasos de cada anillo de la muestra, con el nombre del estado.
const _casos = <(String, int)>[
  ('0 pasos · vacío', 0),
  ('2,000 · bronce a 2/7', 2000),
  ('7,000 · bronce lleno', 7000),
  ('8,000 · plata a 1/3', 8000),
  ('10,000 · plata lleno', 10000),
  ('12,000 · oro a 2/5', 12000),
  ('16,000 · galáctico', 16000),
];

// Matriz que convierte a escala de grises usando la luminosidad real de
// cada canal. Si los aros se distinguen acá, se distinguen con cualquier
// tipo de daltonismo.
const _aEscalaDeGrises = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

class DemoAnilloApp extends StatelessWidget {
  const DemoAnilloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EN COLOR', style: AppTheme.sectionTitle),
                const SizedBox(height: 12),
                const _FilaDeAnillos(),
                const SizedBox(height: 40),
                Text('EN ESCALA DE GRISES', style: AppTheme.sectionTitle),
                const SizedBox(height: 4),
                const Text(
                  'Si acá se distinguen bronce, plata y oro, se distinguen '
                  'con cualquier daltonismo.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                const ColorFiltered(
                  colorFilter: _aEscalaDeGrises,
                  child: _FilaDeAnillos(),
                ),
                const SizedBox(height: 40),
                Text('LOS COLORES SOLOS', style: AppTheme.sectionTitle),
                const SizedBox(height: 12),
                const _MuestrasDeColor(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilaDeAnillos extends StatelessWidget {
  const _FilaDeAnillos();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        for (final (etiqueta, pasos) in _casos)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ProgressRing(pasos: pasos, size: 220),
                  TextoCentroAnillo(pasos: pasos),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 220,
                child: Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Los tres metales como muestras planas, para compararlos sin la forma
/// del aro de por medio.
class _MuestrasDeColor extends StatelessWidget {
  const _MuestrasDeColor();

  @override
  Widget build(BuildContext context) {
    const metales = <(String, Color)>[
      ('Bronce #CD7F32', AppColors.aroBronce),
      ('Plata #C0C0C0', AppColors.aroPlata),
      ('Oro #FFD700', AppColors.aroOro),
    ];

    Widget tira(bool enGrises) {
      final fila = Row(
        children: [
          for (final (nombre, color) in metales)
            Expanded(
              child: Container(
                height: 70,
                margin: const EdgeInsets.only(right: 8),
                color: color,
                alignment: Alignment.center,
                child: Text(
                  nombre,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      );
      return enGrises
          ? ColorFiltered(colorFilter: _aEscalaDeGrises, child: fila)
          : fila;
    }

    return Column(
      children: [tira(false), const SizedBox(height: 8), tira(true)],
    );
  }
}
