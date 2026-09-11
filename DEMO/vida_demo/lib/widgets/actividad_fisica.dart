import 'package:flutter/material.dart';
import '../datos/modelos.dart';
import '../theme.dart';

// ============================================================
// ACTIVIDAD FÍSICA: ritmo cardíaco del día y entrenamientos recientes.
//
// Es lo que HealthKit entrega tal cual, con el mismo formato del spike de
// Alvaro. Los bpm son datos CRUDOS: el % de FCmáx lo calcula el servidor
// con la edad de la póliza, y acá solo se muestra si vino.
// ============================================================

/// Ritmo cardíaco de hoy: promedio, mínimo y máximo.
class RitmoCardiacoHoy extends StatelessWidget {
  const RitmoCardiacoHoy({super.key, required this.dia});

  final DiaActividad dia;

  @override
  Widget build(BuildContext context) {
    final ritmo = dia.ritmo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ritmo cardíaco de hoy',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.dentro),
        _Tarjeta(
          children: ritmo == null
              ? [
                  // Sin lecturas no se inventa un promedio: se dice.
                  Text(
                    'Hoy todavía no hay lecturas de tu reloj.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ]
              : [
                  _Fila(titulo: 'Promedio', valor: '${ritmo.promedio} bpm'),
                  const _Separador(),
                  _Fila(titulo: 'Más bajo', valor: '${ritmo.minimo} bpm'),
                  const _Separador(),
                  _Fila(titulo: 'Más alto', valor: '${ritmo.maximo} bpm'),
                ],
        ),
      ],
    );
  }
}

/// Los entrenamientos de los últimos 7 días.
class EntrenamientosRecientes extends StatelessWidget {
  const EntrenamientosRecientes({super.key, required this.dias});

  final List<DiaActividad> dias;

  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  /// Los días con sesión, del más reciente al más viejo.
  List<DiaActividad> get _conSesion {
    final ultimos = dias.length > 7 ? dias.sublist(dias.length - 7) : dias;
    return ultimos.where((d) => d.sesion != null).toList().reversed.toList();
  }

  static String _cuando(DiaActividad d) {
    final f = d.fecha;
    final fecha = '${f.day} de ${_meses[f.month - 1]}';
    final inicio = d.sesion?.inicio;
    if (inicio == null) return fecha;
    final hora = inicio.hour > 12 ? inicio.hour - 12 : inicio.hour;
    final ampm = inicio.hour >= 12 ? 'pm' : 'am';
    final minutos = inicio.minute.toString().padLeft(2, '0');
    return '$fecha · ${hora == 0 ? 12 : hora}:$minutos $ampm';
  }

  /// HealthKit devuelve el tipo en inglés. Se traduce acá, no en el
  /// modelo: es presentación, no dato.
  static String _tipo(String actividad) => switch (actividad.toLowerCase()) {
    'running' => 'Correr',
    'walking' => 'Caminata',
    'cycling' => 'Ciclismo',
    'swimming' => 'Natación',
    'hiit' => 'HIIT',
    'strength' || 'functionalstrengthtraining' => 'Fuerza',
    'yoga' => 'Yoga',
    _ => actividad,
  };

  @override
  Widget build(BuildContext context) {
    final conSesion = _conSesion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Entrenamientos de los últimos 7 días',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.dentro),
        _Tarjeta(
          children: conSesion.isEmpty
              ? [
                  Text(
                    'No registraste entrenamientos esta semana.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ]
              : [
                  for (var i = 0; i < conSesion.length; i++) ...[
                    _Entrenamiento(
                      titulo: _tipo(conSesion[i].sesion!.tipoActividad),
                      cuando: _cuando(conSesion[i]),
                      sesion: conSesion[i].sesion!,
                    ),
                    if (i != conSesion.length - 1) const _Separador(),
                  ],
                ],
        ),
      ],
    );
  }
}

class _Entrenamiento extends StatelessWidget {
  const _Entrenamiento({
    required this.titulo,
    required this.cuando,
    required this.sesion,
  });

  final String titulo;
  final String cuando;
  final SesionIntensidad sesion;

  @override
  Widget build(BuildContext context) {
    final estiloNota = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(cuando, style: estiloNota),
              if (sesion.fcPromedio != null)
                Text(
                  'FC promedio: ${sesion.fcPromedio} bpm',
                  style: estiloNota,
                ),
              // Una sesión que no acredita tiene que decir por qué, o el
              // usuario no entiende de dónde salen sus puntos.
              if (!sesion.cuentaParaPuntos)
                Text(
                  'No llegó a los 30 min continuos, no suma puntos',
                  style: estiloNota,
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.dentro),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${sesion.duracionMin} min',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (sesion.cuentaParaPuntos)
              Text('+${sesion.puntosIntensidad} pts', style: estiloNota),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// Piezas compartidas
// ============================================================

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _Fila extends StatelessWidget {
  const _Fila({required this.titulo, required this.valor});

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          titulo,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
        ),
      ),
      Text(
        valor,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppColors.textSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: AppColors.cardBorder),
  );
}
