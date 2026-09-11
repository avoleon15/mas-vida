import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../theme.dart';
import 'moneda_animada.dart';

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
                const MonedaAnimada(size: 19),
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

/// El podio: los tres primeros puestos como barras de distinta altura.
///
/// Las columnas van en el orden del podio real —2.o, 1.o, 3.o— para que
/// el más alto quede al centro. La altura de cada barra se lee antes que
/// cualquier número: el que ganó se ve, no se cuenta.
class PodioRanking extends StatelessWidget {
  const PodioRanking({super.key, required this.grupo});

  final GrupoRanking grupo;

  /// Alturas por PUESTO (1.o, 2.o, 3.o), no por columna.
  static const _alturas = [124.0, 96.0, 80.0];

  /// Un solo azul en tres luminosidades: lo que separa un puesto del
  /// siguiente es qué tan oscuro, no el matiz.
  static const _barras = [AppColors.accent, AppColors.nivel3, AppColors.nivel2];

  @override
  Widget build(BuildContext context) {
    final podio = grupo.miembros.take(3).toList();
    if (podio.length < 3) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // El orden de las columnas: 2.o a la izquierda, 1.o al centro.
          for (final puesto in const [2, 1, 3])
            _ColumnaPodio(
              puesto: puesto,
              persona: podio[puesto - 1],
              grupo: grupo,
              alto: _alturas[puesto - 1],
              color: _barras[puesto - 1],
            ),
        ],
      ),
    );
  }
}

class _ColumnaPodio extends StatelessWidget {
  const _ColumnaPodio({
    required this.puesto,
    required this.persona,
    required this.grupo,
    required this.alto,
    required this.color,
  });

  final int puesto;
  final RankingPersona persona;
  final GrupoRanking grupo;
  final double alto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // La MISMA regla que en la tabla: los puntos de los demás solo se ven
    // si el grupo lo decidió; los propios siempre.
    final verPuntos = grupo.mostrarPuntos || persona.esUsuario;
    final esPrimero = puesto == 1;
    final nombre = persona.esUsuario ? 'Tú' : persona.nombre;
    final diametro = esPrimero ? 54.0 : 44.0;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: diametro,
            height: diametro,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Text(
              nombre.characters.first.toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: esPrimero ? 22 : 18,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: persona.esUsuario
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // La barra crece al entrar: el podio se arma delante del
          // usuario en vez de aparecer ya escrito.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutQuart,
            builder: (context, t, child) =>
                SizedBox(height: alto * t, child: child),
            child: _Barra(
              puesto: puesto,
              color: color,
              puntos: verPuntos ? persona.puntosSemana : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({
    required this.puesto,
    required this.color,
    required this.puntos,
  });

  final int puesto;
  final Color color;
  final int? puntos;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      // Si la barra todavía no creció lo suficiente, el contenido no
      // entra: recortarlo es preferible a que reviente el layout.
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$puesto',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (puntos != null) ...[
                const SizedBox(height: 4),
                Text(
                  '$puntos',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.card,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// La tabla completa de un grupo: el podio arriba y del 4.o para abajo
/// las filas de siempre.
class ListaRanking extends StatelessWidget {
  const ListaRanking({super.key, required this.grupo});

  final GrupoRanking grupo;

  @override
  Widget build(BuildContext context) {
    // Con menos de tres no hay podio que armar: se listan todos.
    final hayPodio = grupo.miembros.length >= 3;
    final desde = hayPodio ? 3 : 0;

    return Column(
      children: [
        if (hayPodio) ...[
          PodioRanking(grupo: grupo),
          if (grupo.miembros.length > 3) const SizedBox(height: 12),
        ],
        for (var i = desde; i < grupo.miembros.length; i++) ...[
          FilaRanking(
            posicion: i + 1,
            persona: grupo.miembros[i],
            grupo: grupo,
          ),
          if (i != grupo.miembros.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
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
            const MonedaAnimada(size: 18),
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
