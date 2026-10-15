import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../reglas_puntos.dart';
import '../theme.dart';
import 'hoja_vida.dart';
import 'progress_ring.dart';

// ============================================================
// CÓMO SE GANAN PUNTOS, DETRÁS DE UN BOTÓN EN LA ESQUINA DE "HOY".
//
// Reunión del 2 de octubre de 2026: se fueron las tres cajas de etapas
// (7,000 / 10,000 / 15,000) que vivían debajo del anillo. Lo que
// contaban vive ahora detrás de un botón.
//
// EL BOTÓN VA ARRIBA A LA DERECHA del título "Hoy" (pedido de Daniel, 2
// de octubre de 2026): abajo del anillo, como un renglón gris, pasaba
// de largo. Es una pastilla azul pálido con la (i) y "¿Cómo sumo?" en
// azul de marca: se ve sin gritar, y es lo primero que se encuentra al
// preguntarse de dónde salen los puntos.
//
// Abre una HOJA con la explicación en palabras de todos los días: los
// tres tramos de pasos con lo que llevas hoy en cada uno, el extra por
// entrenar y el máximo del día. Nada de porcentajes de ritmo cardíaco
// ni de siglas.
// ============================================================

/// Llave del botón de la esquina, para los tests.
const Key llaveInfoEtapas = ValueKey('info-etapas');

/// Llave de la hoja que abre.
const Key llaveHojaComoSumar = ValueKey('hoja-como-sumar');

/// La pastilla de la esquina de "Hoy".
class BotonComoSumar extends StatelessWidget {
  const BotonComoSumar({super.key, required this.pasos});

  final int pasos;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cómo sumas puntos',
      excludeSemantics: true,
      child: CupertinoButton(
        key: llaveInfoEtapas,
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        onPressed: () => mostrarComoSumar(context, pasos: pasos),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
          decoration: BoxDecoration(
            color: AppColors.azulBruma,
            borderRadius: BorderRadius.circular(AppRadios.pildora),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.info_circle_fill,
                size: 17,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                '¿Cómo sumo?',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre la explicación de cómo se suman puntos en el día.
void mostrarComoSumar(BuildContext context, {required int pasos}) =>
    mostrarHojaVida<void>(context, hoja: (_) => _HojaComoSumar(pasos: pasos));

class _HojaComoSumar extends StatelessWidget {
  const _HojaComoSumar({required this.pasos});

  final int pasos;

  /// Índice del tramo en curso: 0 camino a 7,000, 1 camino a 10,000, 2
  /// camino a 15,000. Arriba del techo se queda en el último.
  int get _etapaActual {
    for (var i = 1; i < cortesAros.length; i++) {
      if (pasos < cortesAros[i]) return i - 1;
    }
    return cortesAros.length - 2;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final subtitulo = tema.titleSmall?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w800,
    );
    final apoyo = tema.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );

    return HojaVida(
      key: llaveHojaComoSumar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cómo sumas puntos',
            style: AppTheme.display(
              24,
            ).copyWith(color: AppColors.textPrimary, height: 1.1),
          ),
          const SizedBox(height: 6),
          Text(
            'Tus puntos del año de póliza deciden cuánto cashback te devuelven. '
            'Cada día los sumas de dos formas.',
            style: apoyo,
          ),
          const SizedBox(height: AppSpacing.grupo),
          Text('1. Caminando', style: subtitulo),
          const SizedBox(height: 4),
          Text(
            'Mientras más caminas en el día, más puntos te llevas. Cuenta '
            'el tramo más alto al que llegas, no se suman entre sí.',
            style: apoyo,
          ),
          const SizedBox(height: 8),
          _Tramos(pasos: pasos, etapaActual: _etapaActual),
          const SizedBox(height: AppSpacing.grupo),
          Text('2. Entrenando', style: subtitulo),
          const SizedBox(height: 4),
          Text(
            'Si haces ejercicio 30 minutos seguidos o más y tu corazón '
            'se acelera, sumas de 50 a 150 puntos extra. Mientras más '
            'dure y más fuerte sea, más sumas. Lo mide tu reloj.',
            style: apoyo,
          ),
          const SizedBox(height: AppSpacing.grupo),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.azulNiebla,
              borderRadius: BorderRadius.circular(AppRadios.tarjeta),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  CupertinoIcons.info_circle,
                  size: 18,
                  color: AppColors.azulMedio,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lo máximo que puedes sumar en un día son '
                    '$techoDiario puntos. No tienes que hacer nada: '
                    'los contamos solos con los datos de la app Salud.',
                    style: tema.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.grupo),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              borderRadius: BorderRadius.circular(AppRadios.pildora),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tramos extends StatelessWidget {
  const _Tramos({required this.pasos, required this.etapaActual});

  final int pasos;
  final int etapaActual;

  @override
  Widget build(BuildContext context) {
    final cantidad = cortesAros.length - 1;
    final pie = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
      height: 1.35,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cantidad; i++) ...[
          Container(height: 0.5, color: AppColors.separador),
          _Tramo(
            numero: i + 1,
            hasta: cortesAros[i + 1],
            ultima: i == cantidad - 1,
            pasos: pasos,
            metal: AppColors.metal(i),
            color: nombreDelColorDelAro(i),
            alcanzada: pasos >= cortesAros[i + 1],
            activa: i == etapaActual && pasos < techoAros,
          ),
        ],
        Container(height: 0.5, color: AppColors.separador),
        const SizedBox(height: 10),
        Text(
          'Arriba de ${TextoCentroAnillo.formatearMiles(techoAros)} pasos '
          'ya no suman más puntos por caminar.',
          style: pie,
        ),
      ],
    );
  }
}

/// Un tramo de la tabla de pasos, en un renglón.
///
/// El metal del tramo (bronce, plata, oro) va solo en el disco del
/// número, que es lo chico: es el mismo metal del aro de arriba y es lo
/// que amarra este renglón con el anillo.
class _Tramo extends StatelessWidget {
  const _Tramo({
    required this.numero,
    required this.hasta,
    required this.ultima,
    required this.pasos,
    required this.metal,
    required this.color,
    required this.alcanzada,
    required this.activa,
  });

  final int numero;
  final int hasta;
  final bool ultima;
  final int pasos;
  final ({Color aro, Color tinta}) metal;

  /// "Bronce", "Plata" u "Oro": el COLOR con que se pinta este tramo en
  /// el anillo de Hoy. No es un nombre de nivel.
  final String color;
  final bool alcanzada;
  final bool activa;

  static String _miles(int v) => TextoCentroAnillo.formatearMiles(v);

  String get _estado {
    if (alcanzada) return 'Completada';
    if (activa) return 'Te faltan ${_miles(hasta - pasos)} pasos';
    return 'Bloqueado';
  }

  @override
  Widget build(BuildContext context) {
    final encendida = alcanzada || activa;
    final meta = ultima ? '${_miles(hasta)}+ pasos' : '${_miles(hasta)} pasos';

    return Semantics(
      label:
          'Etapa $numero, color $color en el anillo: $meta, '
          '${puntosPorPasos(hasta)} puntos. $_estado',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: encendida
                    ? metal.tinta
                    : AppColors.cardBorder.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: encendida
                  ? Text(
                      '$numero',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : const Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          meta,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: encendida
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ColorDelAro(nombre: color, metal: metal),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // El check suelto y naranja: es el cuarto uso del
                      // naranja que deja CLAUDE.md.
                      if (alcanzada) ...[
                        const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: AppColors.accentSecondary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          _estado,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: activa
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                                fontWeight: activa
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '+${puntosPorPasos(hasta)} pts',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: encendida ? AppColors.accent : AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El nombre del color de cada tramo del anillo de pasos, en orden.
///
/// Es la etiqueta del COLOR que se ve en el aro (pedido de Daniel, 2 de
/// octubre de 2026), para que se entienda qué color es cuál. NO es un
/// nivel: los niveles de cashback son "Nivel 3", y nunca llevan nombre
/// de metal.
String nombreDelColorDelAro(int tramo) => switch (tramo) {
  0 => 'Bronce',
  1 => 'Plata',
  _ => 'Oro',
};

/// "● Bronce" en chico: la muestra del color del aro y su nombre.
class _ColorDelAro extends StatelessWidget {
  const _ColorDelAro({required this.nombre, required this.metal});

  final String nombre;
  final ({Color aro, Color tinta}) metal;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
    decoration: BoxDecoration(
      color: metal.aro.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppRadios.pildora),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: metal.aro,
            borderRadius: BorderRadius.circular(AppRadios.pildora),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          nombre,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: metal.tinta,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
