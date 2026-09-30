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
import '../widgets/patrocinio.dart';
import '../widgets/ranking_widgets.dart';
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
                    Text(
                      grupo.nombre,
                      style: AppTheme.sectionTitle.copyWith(fontSize: 28),
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
                    const EtiquetaSeccion('TABLA DEL MES'),
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
        ?grupo.franjaEdad,
        personas,
      ].join(' · ');
    }
    final dias = diasParaCerrar(grupo);
    return dias == null
        ? personas
        : '$personas · ${cuandoCierra(dias).toLowerCase()}';
  }
}

/// Lo que paga La Liga: monedas al podio y, si el mes tiene marca, un
/// cupón además. Nunca en lugar de las monedas.
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
      if (liga.patrocinio case final p?) ...[
        const SizedBox(height: AppSpacing.entre),
        CintaPatrocinio(
          patrocinio: p,
          texto: 'Los 3 primeros se llevan además ${p.cupon}.',
        ),
      ],
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
        onPressed: () => _mostrarReglas(context),
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

  void _mostrarReglas(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
      builder: (_) => _HojaReglasLiga(liga: liga),
    );
  }

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
      const Icon(
        CupertinoIcons.eye_slash,
        size: 14,
        color: AppColors.textSecondary,
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          esLiga
              ? 'En La Liga nadie ve los puntos de nadie, solo la posición. '
                    'Los tuyos solo los ves tú.'
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

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
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
                    'Cada mes te sorteamos con hasta 30 personas de tu edad'
                    '${liga.franjaEdad == null ? '' : ' (${liga.franjaEdad})'}. '
                    'No tienes que hacer nada para entrar.',
                estilo: estilo,
              ),
              _Regla(
                icono: CupertinoIcons.eye_slash,
                texto:
                    'Nadie ve los puntos de nadie, solo la posición. Tú sí '
                    'ves los tuyos.',
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
        ),
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
