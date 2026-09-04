import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../theme.dart';

// ============================================================
// Piezas de ranking que comparten la pantalla Social y la pantalla de un
// grupo. Están acá y no duplicadas en cada una para que la regla de
// privacidad de los puntos viva en UN solo lugar (ver [FilaRanking]).
// ============================================================

/// Etiqueta de sección, en versalitas.
class EtiquetaSeccion extends StatelessWidget {
  const EtiquetaSeccion(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.4,
    ),
  );
}

/// La flecha de tendencia, suelta.
class IconoTendencia extends StatelessWidget {
  const IconoTendencia({super.key, required this.tendencia, this.size = 16});

  final Tendencia tendencia;
  final double size;

  @override
  Widget build(BuildContext context) => switch (tendencia) {
    Tendencia.subida => Icon(
      Icons.arrow_upward,
      color: AppColors.accentSecondary,
      size: size,
    ),
    Tendencia.bajada => Icon(
      Icons.arrow_downward,
      color: AppColors.textSecondary,
      size: size,
    ),
    Tendencia.igual => Icon(
      Icons.remove,
      color: AppColors.textSecondary,
      size: size,
    ),
  };
}

/// La tendencia con su palabra al lado, para las tarjetas de resumen.
class ChipTendencia extends StatelessWidget {
  const ChipTendencia({super.key, required this.tendencia});

  final Tendencia tendencia;

  String get _texto => switch (tendencia) {
    Tendencia.subida => 'Subiste',
    Tendencia.bajada => 'Bajaste',
    Tendencia.igual => 'Igual',
  };

  @override
  Widget build(BuildContext context) {
    final color = tendencia == Tendencia.subida
        ? AppColors.accentSecondary
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconoTendencia(tendencia: tendencia, size: 13),
          const SizedBox(width: 4),
          Text(
            _texto,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que se lleva un puesto del podio. Siempre MONEDAS, nunca puntos:
/// los puntos mueven el cashback y no se ganan compitiendo.
class PremioPodio extends StatelessWidget {
  const PremioPodio({super.key, required this.puesto, required this.monedas});

  final int puesto;
  final int monedas;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Text(
              '$puesto.o',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.monetization_on,
                  size: 14,
                  color: AppColors.accentSecondary,
                ),
                const SizedBox(width: 3),
                Text(
                  '$monedas',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// La tabla completa de un grupo.
class ListaRanking extends StatelessWidget {
  const ListaRanking({super.key, required this.grupo});

  final GrupoRanking grupo;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < grupo.miembros.length; i++) ...[
        FilaRanking(posicion: i + 1, persona: grupo.miembros[i], grupo: grupo),
        if (i != grupo.miembros.length - 1) const SizedBox(height: 8),
      ],
    ],
  );
}

/// Una fila de la tabla.
class FilaRanking extends StatelessWidget {
  const FilaRanking({
    super.key,
    required this.posicion,
    required this.persona,
    required this.grupo,
  });

  final int posicion;
  final RankingPersona persona;
  final GrupoRanking grupo;

  @override
  Widget build(BuildContext context) {
    // Los puntos de los DEMÁS solo se ven si el grupo lo decidió al
    // crearse, y nunca en una liga de desconocidos: mostrarlos ahí sería
    // darle el nivel de actividad de alguien a gente que no eligió como
    // contacto.
    final verPuntos = grupo.mostrarPuntos || persona.esUsuario;
    // En una liga con premio, el podio se marca.
    final enPodio =
        grupo.premiosMonedas.isNotEmpty &&
        posicion <= grupo.premiosMonedas.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: persona.esUsuario
            ? AppColors.accent.withValues(alpha: 0.08)
            : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: persona.esUsuario
              ? AppColors.accent.withValues(alpha: 0.3)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 24, child: _Posicion(posicion: posicion)),
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.cardBorder,
            child: Icon(Icons.person, color: AppColors.textSecondary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              persona.esUsuario ? 'Tú' : persona.nombre,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: persona.esUsuario
                    ? FontWeight.w700
                    : FontWeight.w600,
              ),
            ),
          ),
          if (verPuntos) ...[
            Text(
              '${persona.puntosSemana}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (enPodio) ...[
            const Icon(
              Icons.monetization_on,
              size: 14,
              color: AppColors.accentSecondary,
            ),
            const SizedBox(width: 3),
            Text(
              '${grupo.premiosMonedas[posicion - 1]}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.accentSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconoTendencia(tendencia: persona.tendencia),
        ],
      ),
    );
  }
}

/// Trofeo para el podio, número normal para el resto.
class _Posicion extends StatelessWidget {
  const _Posicion({required this.posicion});

  final int posicion;

  @override
  Widget build(BuildContext context) {
    if (posicion <= 3) {
      const colores = [AppColors.nivel3, AppColors.nivel2, AppColors.nivel1];
      return Icon(Icons.emoji_events, color: colores[posicion - 1], size: 20);
    }
    return Center(
      child: Text(
        '$posicion',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Tarjeta de resumen: dónde vas en un grupo y cómo venís.
class ResumenGrupo extends StatelessWidget {
  const ResumenGrupo({
    super.key,
    required this.grupo,
    this.mostrarNombre = true,
  });

  final GrupoRanking grupo;

  /// En la pantalla del grupo el nombre ya está en el título, no hace
  /// falta repetirlo adentro de la tarjeta.
  final bool mostrarNombre;

  @override
  Widget build(BuildContext context) {
    final indice = grupo.miembros.indexWhere((p) => p.esUsuario);
    if (indice < 0) return const SizedBox.shrink();
    final persona = grupo.miembros[indice];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mostrarNombre) ...[
            Text(
              grupo.nombre.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // La posición es el dato principal: por eso va grande y
              // sola. Lo demás la acompaña.
              Text('#${indice + 1}', style: AppTheme.display(40)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'de ${grupo.miembros.length}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              ChipTendencia(tendencia: persona.tendencia),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            // Los propios puntos SIEMPRE se ven: son del usuario. Lo que
            // el grupo decide es si se ven los de los DEMÁS.
            '${persona.puntosSemana} pts esta semana',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
