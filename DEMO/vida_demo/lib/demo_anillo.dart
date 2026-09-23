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
      theme: AppTheme.temaClaro,
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
///
/// Van las DOS versiones de cada uno, porque las dos se usan:
///
///   · `aro`   — el trazo del anillo.
///   · `tinta` — el borde, el círculo del número y la pastilla de los
///               puntos de la tarjeta de esa etapa en Hoy. Lleva blanco
///               encima, así que acá se muestra así.
///
/// Cada fila se repite en escala de grises justo debajo. Si dos
/// muestras de la misma fila no se distinguen en grises, no se
/// distinguen con daltonismo.
///
/// La fila que TIENE que pasar esa prueba es la del aro: son tres arcos
/// del mismo anillo y el color es lo único que los separa. La de la
/// tinta va siempre dentro de una tarjeta que ya se identifica por su
/// número y su ícono, así que ahí los grises son información, no un
/// requisito.
class _MuestrasDeColor extends StatelessWidget {
  const _MuestrasDeColor();

  static const _filas = <(String, Color Function(int))>[
    ('Aro · el trazo del anillo', _aro),
    ('Tinta · borde, círculo y pastilla de la tarjeta', _tinta),
  ];

  static Color _aro(int i) => AppColors.metal(i).aro;
  static Color _tinta(int i) => AppColors.metal(i).tinta;

  static const _nombres = ['Bronce', 'Plata', 'Oro'];

  @override
  Widget build(BuildContext context) {
    /// Un hex legible, para poder copiarlo de la pantalla.
    String hex(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';

    Widget tira(Color Function(int) de, bool enGrises) {
      final fila = Row(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Container(
                height: 62,
                margin: const EdgeInsets.only(right: 8),
                color: de(i),
                alignment: Alignment.center,
                child: Text(
                  '${_nombres[i]}\n${hex(de(i))}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    // La tinta es oscura y lleva contenido blanco
                    // encima; las otras dos son claras.
                    color: de == _tinta ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (titulo, de) in _filas) ...[
          Text(
            titulo,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          tira(de, false),
          const SizedBox(height: 4),
          tira(de, true),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}
