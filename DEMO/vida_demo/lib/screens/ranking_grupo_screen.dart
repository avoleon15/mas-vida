import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../datos/modelos.dart';
import '../hora_guatemala.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/boton_relieve.dart';
import '../widgets/hoja_invitar_grupo.dart';
import '../widgets/hoja_vida.dart';
import '../widgets/patrocinio.dart';
import '../widgets/ranking_widgets.dart';
import '../widgets/chip_monedas.dart' show BotonInfo;
import 'social_screen.dart' show cuandoCierra, diasParaCerrar;

// ============================================================
// LA TABLA DE UNA COMPETENCIA O DE LA LIGA.
//
// Social muestra cómo vas; acá está la tabla entera. La Liga trae además
// lo que paga, sus reglas y compartir tu puesto. Una competencia tuya
// trae el botón para invitar con su código.
// ============================================================

const List<String> _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

class RankingGrupoScreen extends StatelessWidget {
  const RankingGrupoScreen({super.key, required this.grupo});

  final GrupoRanking grupo;

  bool get _esLiga => grupo.tipo == TipoGrupo.desconocidos;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: AppHeader(showBackButton: true),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // La marca va AL LADO del nombre de la liga (pedido
                    // de Daniel, 2 de octubre de 2026): es lo que la
                    // alianza compró y tiene que verse antes que la tabla.
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            grupo.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sectionTitle.copyWith(fontSize: 28),
                          ),
                        ),
                        if (grupo.patrocinio case final p?) ...[
                          const SizedBox(width: 12),
                          Flexible(child: MarcaDeLaLiga(patrocinio: p)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitulo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.grupo),
                    ResumenGrupo(grupo: grupo, mostrarNombre: false),
                    if (_esLiga) ...[
                      const SizedBox(height: AppSpacing.entre),
                      _PremiosDeLaLiga(liga: grupo),
                    ] else ...[
                      // Invitar vive acá: el código es de ESTA competencia.
                      const SizedBox(height: 12),
                      _BotonInvitar(grupo: grupo),
                    ],
                    const SizedBox(height: AppSpacing.seccion),
                    Row(
                      children: [
                        const Expanded(child: EtiquetaSeccion('TABLA DEL MES')),
                        // Las reglas a un toque de la tabla: cómo se
                        // ordena y qué pasa con un empate.
                        if (_esLiga)
                          BotonInfo(
                            semantica: 'Reglas de La Liga',
                            onPressed: () => mostrarReglasLiga(context, grupo),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Una competencia recién creada tiene un solo
                    // integrante: una "tabla" de uno es una espera.
                    if (grupo.miembros.length <= 1)
                      _SoloTu(grupo: grupo)
                    else
                      ListaRanking(grupo: grupo),
                    if (!grupo.mostrarPuntos) ...[
                      const SizedBox(height: AppSpacing.entre),
                      _NotaPrivacidad(esLiga: _esLiga),
                    ],
                    if (_esLiga) ...[
                      const SizedBox(height: AppSpacing.grupo),
                      _AccionesLiga(liga: grupo),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _subtitulo {
    final n = grupo.miembros.length;
    final personas = '$n ${n == 1 ? "persona" : "personas"}';
    if (_esLiga) {
      final arranca = grupo.arranca;
      final mes = arranca == null
          ? null
          : _meses[enHoraDeGuatemala(arranca).month - 1];
      return [
        if (mes != null) mes[0].toUpperCase() + mes.substring(1),
        personas,
      ].join(' · ');
    }
    final dias = diasParaCerrar(grupo);
    return dias == null
        ? personas
        : '$personas · ${cuandoCierra(dias).toLowerCase()}';
  }
}

/// Lo que paga La Liga: monedas al podio. El cupón de la marca, si el
/// mes tiene una, lo cuentan las reglas: la marca ya está junto al
/// título y una cinta más repetía quién patrocina.
class _PremiosDeLaLiga extends StatelessWidget {
  const _PremiosDeLaLiga({required this.liga});

  final GrupoRanking liga;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (liga.premiosMonedas.isNotEmpty)
        Row(
          children: [
            for (var i = 0; i < liga.premiosMonedas.length; i++) ...[
              PremioPodio(puesto: i + 1, monedas: liga.premiosMonedas[i]),
              if (i != liga.premiosMonedas.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
    ],
  );
}

/// Las dos acciones de La Liga, como texto: se consultan de vez en
/// cuando y no pueden pesar más que la tabla.
class _AccionesLiga extends StatelessWidget {
  const _AccionesLiga({required this.liga});

  final GrupoRanking liga;

  // Como renglones de lista, igual que "Crear o unirme" en Social: se
  // consultan de vez en cuando y no pueden pesar más que la tabla.
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(height: 0.5, color: AppColors.separador),
      _FilaAccion(
        icono: CupertinoIcons.info,
        texto: 'Cómo funciona',
        onPressed: () => mostrarReglasLiga(context, liga),
      ),
      if (liga.estoyUnido) ...[
        Container(height: 0.5, color: AppColors.separador),
        _FilaAccion(
          icono: CupertinoIcons.share,
          texto: 'Compartir mi puesto',
          onPressed: () => _compartirPuesto(context),
        ),
      ],
    ],
  );

  /// La hoja de compartir de iOS con tu puesto. Solo el tuyo: nunca los
  /// puntos ni los nombres de los demás.
  Future<void> _compartirPuesto(BuildContext context) async {
    HapticFeedback.selectionClick();
    // En iPad la hoja de compartir necesita un ancla o revienta.
    final caja = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Voy ${liga.posicionUsuario}.º de ${liga.miembros.length} en '
            '${liga.nombre} de +Vida 💪',
        sharePositionOrigin: caja == null
            ? null
            : caja.localToGlobal(Offset.zero) & caja.size,
      ),
    );
  }
}

/// Un renglón con acción: ícono en un disco azul pálido, texto y chevron.
class _FilaAccion extends StatelessWidget {
  const _FilaAccion({
    required this.icono,
    required this.texto,
    required this.onPressed,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    onPressed: onPressed,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.azulBruma,
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    ),
  );
}

class _BotonInvitar extends StatelessWidget {
  const _BotonInvitar({required this.grupo});

  final GrupoRanking grupo;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: CupertinoButton(
      onPressed: () => mostrarInvitarAlGrupo(context, grupo),
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.azulBruma,
          borderRadius: BorderRadius.circular(AppRadios.pildora),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.share, size: 17, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(
              'Invitar con el código',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Una competencia donde todavía no entró nadie más.
class _SoloTu extends StatelessWidget {
  const _SoloTu({required this.grupo});

  final GrupoRanking grupo;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    decoration: BoxDecoration(
      color: AppColors.azulNiebla,
      borderRadius: BorderRadius.circular(AppRadios.tarjeta),
    ),
    child: Column(
      children: [
        const Icon(
          CupertinoIcons.person_2,
          size: 28,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 12),
        Text(
          'Por ahora estás solo aquí',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Comparte el código por WhatsApp y la tabla arranca cuando entre '
          'alguien.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        BotonRelieve(
          label: 'Compartir el código',
          icono: CupertinoIcons.share,
          onPressed: () => mostrarInvitarAlGrupo(context, grupo),
        ),
      ],
    ),
  );
}

/// Cuando no se ven los puntos de los demás, hay que decirlo: si no, la
/// tabla parece incompleta o rota.
class _NotaPrivacidad extends StatelessWidget {
  const _NotaPrivacidad({required this.esLiga});

  final bool esLiga;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(CupertinoIcons.eye, size: 14, color: AppColors.textSecondary),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          esLiga
              ? 'En La Liga se ven los puntos de todos, pero nunca los '
                    'pasos de nadie.'
              : 'Esta competencia eligió no mostrar los puntos de cada '
                    'quien. Solo se ve la posición.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
      ),
    ],
  );
}

/// Las reglas de La Liga, en una hoja aparte: importan la primera vez y
/// estorban a partir de la segunda.
/// Abre las reglas de La Liga en una hoja.
///
/// Se abre desde la (i) de la tarjeta de La Liga en Social, desde la (i)
/// de la tabla y desde "Cómo funciona". Una sola hoja para las tres.
void mostrarReglasLiga(BuildContext context, GrupoRanking liga) =>
    mostrarHojaVida<void>(context, hoja: (_) => _HojaReglasLiga(liga: liga));

/// La marca que patrocina el mes de la liga, al lado del nombre: el logo
/// y "Patrocinada por Montanos", con el nombre en el color de la marca.
class MarcaDeLaLiga extends StatelessWidget {
  const MarcaDeLaLiga({super.key, required this.patrocinio});

  final Patrocinio patrocinio;

  @override
  Widget build(BuildContext context) {
    final acento = acentoDeMarca(patrocinio);

    // Una PASTILLA al lado del título (pedido de Daniel, 2 de octubre de
    // 2026): el logo y el nombre en el color de la marca, sobre un
    // lavado de ese mismo color. Se lee como "esta liga es de Ookii" sin
    // necesitar una oración ni una cinta aparte.
    return Semantics(
      label: 'Patrocinada por ${patrocinio.marca}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: acento.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadios.pildora),
          border: Border.all(color: acento.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: SizedBox(
                width: 26,
                height: 26,
                child: LogoPatrocinio(patrocinio: patrocinio, tamano: 26),
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                patrocinio.marca,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: acento,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HojaReglasLiga extends StatelessWidget {
  const _HojaReglasLiga({required this.liga});

  final GrupoRanking liga;

  /// El ciclo, con las fechas del mes en curso.
  static String _reglaDelCiclo(GrupoRanking liga) {
    final periodo = periodoDelCiclo(liga);
    if (periodo == null) {
      return 'Dura un mes: del 1 al último día. Al cerrar arranca otra.';
    }
    final rango = periodo[0].toLowerCase() + periodo.substring(1);
    return 'Dura un mes: la de ahora va $rango, y al cerrar arranca otra '
        'con gente nueva.';
  }

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );

    return HojaVida(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cómo funciona La Liga',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.entre),
          _Regla(
            icono: CupertinoIcons.person_3,
            texto:
                'Compites con todos los asegurados de +Vida que tienen su '
                'póliza verificada. No tienes que hacer nada para entrar.',
            estilo: estilo,
          ),
          // El puntaje y el desempate (reunión del 2 de octubre de
          // 2026). Los pasos de los demás nunca se muestran: el
          // servidor los usa para ordenar y acá solo se explica por
          // qué alguien con tus mismos puntos puede ir arriba.
          _Regla(
            icono: CupertinoIcons.bolt,
            texto:
                'Compites con los puntos que sumas en el mes, los mismos '
                'de tu cashback.',
            estilo: estilo,
          ),
          _Regla(
            icono: CupertinoIcons.arrow_up_arrow_down,
            texto:
                'Si empatas en puntos con alguien, queda arriba quien '
                'caminó más pasos en el mes.',
            estilo: estilo,
          ),
          _Regla(
            icono: CupertinoIcons.eye_slash,
            texto:
                'Se ven los puntos de todos, pero nunca los pasos de '
                'nadie.',
            estilo: estilo,
          ),
          _Regla(
            icono: CupertinoIcons.money_dollar_circle,
            texto:
                'Los tres primeros se llevan MONEDAS, que se gastan en '
                'Premios. Nunca puntos: los puntos son de tu cashback y '
                'no se ganan compitiendo.',
            estilo: estilo,
          ),
          if (liga.patrocinio case final p?)
            _Regla(
              icono: CupertinoIcons.ticket,
              texto:
                  'Este mes la patrocina ${p.marca}: los tres primeros se '
                  'llevan además ${p.cupon}.',
              estilo: estilo,
            ),
          _Regla(
            icono: CupertinoIcons.clock,
            texto: _reglaDelCiclo(liga),
            estilo: estilo,
          ),
          const SizedBox(height: AppSpacing.entre),
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

class _Regla extends StatelessWidget {
  const _Regla({required this.icono, required this.texto, this.estilo});

  final IconData icono;
  final String texto;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(child: Text(texto, style: estilo)),
      ],
    ),
  );
}
