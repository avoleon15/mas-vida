import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../hora_guatemala.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/flujos_social.dart';
import '../widgets/hoja_invitar_grupo.dart';
import '../widgets/moneda_animada.dart';
import '../widgets/patrocinio.dart';
import '../widgets/ranking_widgets.dart';
import '../widgets/refresco_vida.dart';
import 'ranking_grupo_screen.dart';

// ============================================================
// SOCIAL (rediseño de Daniel, 25 de septiembre de 2026).
//
// Una sola pantalla, sin pestañas y sin amigos:
//
//   1. LA LIGA, arriba y como la única pieza levantada: es lo único de
//      Social que paga, y la arma la app sin que el usuario haga nada.
//      Cuánto le queda, tu puesto en grande y lo que paga. Tocarla abre
//      la tabla completa.
//   2. MIS COMPETENCIAS, debajo y plana: las que armaste con tu gente.
//      Se crean o se entra con un CÓDIGO que se comparte por WhatsApp o
//      cualquier app. No hay solicitudes ni amigos.
//
// Antes eran dos pestañas —"Mis competencias" y "Liga local"— que nunca
// se veían juntas, y la que da premio quedaba en la segunda.
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

/// Cuántos días le quedan a [grupo], contados en hora de Guatemala.
/// Null si no trae fecha de cierre.
int? diasParaCerrar(GrupoRanking grupo, {DateTime? ahora}) {
  final cierra = grupo.cierra;
  if (cierra == null) return null;
  final c = enHoraDeGuatemala(cierra);
  final h = enHoraDeGuatemala(ahora ?? DateTime.now());
  return DateTime(
    c.year,
    c.month,
    c.day,
  ).difference(DateTime(h.year, h.month, h.day)).inDays;
}

/// "Quedan 5 días", "Cierra hoy", "Cerró".
String cuandoCierra(int dias) => switch (dias) {
  < 0 => 'Cerró',
  0 => 'Cierra hoy',
  1 => 'Queda 1 día',
  _ => 'Quedan $dias días',
};

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: AppHeader(),
            ),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: datosRecargados,
                builder: (context, _, _) {
                  final liga = Datos.i.social.ligaLocal;
                  return CustomScrollView(
                    physics: fisicaConRefresco,
                    slivers: [
                      const RefrescoVida(),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SOCIAL', style: AppTheme.sectionTitle),
                              const SizedBox(height: 20),
                              if (liga == null)
                                const _SinLiga()
                              else
                                TarjetaLiga(
                                  liga: liga,
                                  onTap: () => _abrir(liga),
                                ),
                              const SizedBox(height: AppSpacing.seccion),
                              ..._misCompetencias(context),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const BottomNavBar(currentIndex: 2),
          ],
        ),
      ),
    );
  }

  // ---- Mis competencias ----

  List<Widget> _misCompetencias(BuildContext context) {
    final grupos = Datos.i.social.deConocidos;
    final filtro = _busqueda.trim().toLowerCase();
    final visibles = filtro.isEmpty
        ? grupos
        : grupos.where((g) => g.nombre.toLowerCase().contains(filtro)).toList();

    return [
      const EtiquetaSeccion('MIS COMPETENCIAS'),
      const SizedBox(height: 4),
      Text(
        'Con tu gente, por código. Duran un mes.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 8),
      // El buscador aparece recién cuando hay suficientes como para
      // necesitarlo. Con tres, solo ocupa lugar.
      if (grupos.length >= 5) ...[
        const SizedBox(height: 8),
        CupertinoSearchTextField(
          placeholder: 'Buscar competencia',
          onChanged: (t) => setState(() => _busqueda = t),
        ),
        const SizedBox(height: 8),
      ],
      if (grupos.isNotEmpty && visibles.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Ninguna competencia se llama así.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      for (final g in visibles) ...[
        _FilaGrupo(grupo: g, onTap: () => _abrir(g)),
        Container(height: 0.5, color: AppColors.separador),
      ],
      _FilaCrearOUnirse(onPressed: _menuGrupos, primera: grupos.isEmpty),
    ];
  }

  void _abrir(GrupoRanking grupo) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => RankingGrupoScreen(grupo: grupo),
      ),
    );
  }

  /// Crear o unirse, en un action sheet de iOS.
  Future<void> _menuGrupos() async {
    HapticFeedback.selectionClick();

    final accion = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Mis competencias'),
        message: const Text(
          'Arma una con tu gente y compárteles el código, o entra a una '
          'con el código que te pasaron.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('crear'),
            child: const Text('Crear una competencia'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('unirse'),
            child: const Text('Unirme con un código'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );

    if (accion == null || !mounted) return;

    switch (accion) {
      case 'crear':
        final creada = await mostrarCrearGrupo(context);
        if (creada == null || !mounted) return;
        // Se limpia la búsqueda: con un filtro puesto, la recién creada
        // podría no aparecer y parecería que no se creó.
        setState(() => _busqueda = '');
        // Lo que sigue a crear es invitar: la hoja con el código se abre
        // sola, lista para mandarlo por WhatsApp.
        mostrarInvitarAlGrupo(context, creada, recienCreada: true);
      case 'unirse':
        await mostrarUnirseGrupo(context);
    }
  }
}

// ============================================================
// LA LIGA
// ============================================================

/// Llave de la tarjeta de La Liga, para los tests.
const Key llaveTarjetaLiga = ValueKey('tarjeta-liga');

/// La Liga en Social: la única pieza levantada de la pantalla.
class TarjetaLiga extends StatelessWidget {
  const TarjetaLiga({super.key, required this.liga, required this.onTap});

  final GrupoRanking liga;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final puesto = liga.posicionUsuario;
    final yo = liga.usuario;
    final total = liga.miembros.length;
    final podio = liga.premiosMonedas.length;
    final dias = diasParaCerrar(liga);
    final mes = liga.arranca == null
        ? null
        : _meses[enHoraDeGuatemala(liga.arranca!).month - 1];

    return Semantics(
      key: llaveTarjetaLiga,
      button: true,
      label:
          'La Liga${mes == null ? '' : ' de $mes'}. '
          '${yo == null ? 'Todavía no estás en la tabla' : 'Vas en el puesto $puesto de $total'}. '
          'Toca para ver la tabla.',
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadios.tarjeta),
            boxShadow: AppSombras.tarjeta,
          ),
          // Tres renglones y nada más: qué es y cuánto le queda, tu
          // puesto, y lo que paga. La franja de edad, los puntos y las
          // reglas viven en la tabla.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      mes == null
                          ? 'LA LIGA'
                          : 'LA LIGA · ${mes.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.subsectionTitle,
                    ),
                  ),
                  if (dias != null)
                    Text(
                      cuandoCierra(dias),
                      style: tema.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (yo == null)
                Text(
                  'Todavía no estás en la tabla de este mes.',
                  style: tema.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                // El puesto, en grande: es lo que se viene a ver.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$puesto.º',
                      style: AppTheme.display(
                        56,
                      ).copyWith(color: AppColors.textPrimary, height: 0.95),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'de $total',
                          style: tema.titleSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ChipTendencia(tendencia: yo.tendencia),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Container(height: 0.5, color: AppColors.separador),
              const SizedBox(height: 12),
              // Lo que paga, en un renglón, y el chevron de la tabla.
              Row(
                children: [
                  // Los premios se achican juntos si no caben (letra de
                  // iOS grande).
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          for (var i = 0; i < podio; i++) ...[
                            _Premio(
                              puesto: i + 1,
                              monedas: liga.premiosMonedas[i],
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (liga.patrocinio case final p?)
                            LogoPatrocinio(patrocinio: p, tamano: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: AppColors.azulMedio,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "1.º 🪙10": lo que paga un puesto del podio, suelto y sin caja.
class _Premio extends StatelessWidget {
  const _Premio({required this.puesto, required this.monedas});

  final int puesto;
  final int monedas;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$puesto.º',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(width: 4),
      const MonedaAnimada(size: 16),
      const SizedBox(width: 2),
      Text(
        '$monedas',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

/// Sin La Liga todavía: la app la arma sola, así que no hay nada que
/// tocar, solo esperar.
class _SinLiga extends StatelessWidget {
  const _SinLiga();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.azulNiebla,
      borderRadius: BorderRadius.circular(AppRadios.tarjeta),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LA LIGA', style: AppTheme.subsectionTitle),
        const SizedBox(height: 8),
        Text(
          'Cada mes te sorteamos en una liga con gente de tu edad. Te '
          'avisamos cuando arranque la próxima.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

// ============================================================
// MIS COMPETENCIAS
// ============================================================

/// Una competencia en la lista: inicial, nombre, cuánta gente y cuánto
/// le queda, y tu puesto. Sin caja: una lista es una lista.
class _FilaGrupo extends StatelessWidget {
  const _FilaGrupo({required this.grupo, required this.onTap});

  final GrupoRanking grupo;
  final VoidCallback onTap;

  String get _subtitulo {
    final n = grupo.miembros.length;
    final base = '$n ${n == 1 ? "persona" : "personas"}';
    final dias = diasParaCerrar(grupo);
    return dias == null ? base : '$base · ${cuandoCierra(dias).toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final posicion = grupo.posicionUsuario;

    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _AvatarGrupo(grupo: grupo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grupo.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (posicion > 0) ...[
              const SizedBox(width: 8),
              Text(
                '$posicion.º',
                style: AppTheme.display(18).copyWith(
                  color: posicion == 1
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(width: 6),
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
}

/// La inicial de la competencia en un círculo. El tono sale del nombre:
/// la misma competencia siempre tiene el mismo, y todos son del azul de
/// marca para que la lista no se vuelva un arcoíris.
class _AvatarGrupo extends StatelessWidget {
  const _AvatarGrupo({required this.grupo});

  final GrupoRanking grupo;

  static const _tonos = [
    AppColors.nivel4,
    AppColors.nivel3,
    AppColors.nivel2,
    AppColors.nivel1,
  ];

  @override
  Widget build(BuildContext context) {
    final semilla = grupo.nombre.codeUnits.fold<int>(0, (a, c) => a + c);
    final color = _tonos[semilla % _tonos.length];

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        grupo.nombre.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Llave de "Crear o unirme", para los tests.
const Key llaveCrearOUnirse = ValueKey('crear-o-unirse');

/// Crear o unirse: un renglón más de la lista, con el signo más en un
/// disco azul. Sin caja con borde: es parte de la lista, no un botón
/// que compita con La Liga.
class _FilaCrearOUnirse extends StatelessWidget {
  const _FilaCrearOUnirse({required this.onPressed, required this.primera});

  final VoidCallback onPressed;

  /// Sin competencias todavía, el renglón explica qué es.
  final bool primera;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    key: llaveCrearOUnirse,
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.azulBruma,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.add,
              size: 20,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crear o unirme',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (primera)
                  Text(
                    'Arma una con tu gente y compárteles el código',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
