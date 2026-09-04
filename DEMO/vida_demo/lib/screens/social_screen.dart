import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:share_plus/share_plus.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../theme.dart';
import '../widgets/boton_relieve.dart';
import '../widgets/contadores_amigos.dart';
import '../widgets/flujos_social.dart';
import '../widgets/ranking_widgets.dart';
import 'amigos_screen.dart';
import 'ranking_grupo_screen.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';

// ============================================================
// Datos de ejemplo. Todo hardcodeado por ahora (sin backend) y
// organizado en constantes simples, para que sea fácil de
// reemplazar después con datos reales.
// ============================================================

String get nombreUsuario => Datos.i.perfil.nombre;

// ---- Duelos ----
// Los duelos NO otorgan monedas ni premios: son puramente competitivos.
bool get hayDueloActivo => Datos.i.social.duelo.activo;

String get duelloRivalHandle => Datos.i.social.duelo.rivalHandle;
String get duelloTiempoRestante => Datos.i.social.duelo.tiempoRestante;

/// % sobre el propio promedio de cada quien, nunca comparación directa.
double get duelloSuperacionPropia => Datos.i.social.duelo.superacionPropia;
double get duelloSuperacionRival => Datos.i.social.duelo.superacionRival;
// Escala de referencia para las barras de superación (no hay un tope
// natural como en una barra de progreso normal, así que usamos este
// techo solo para que las barras se vean proporcionadas entre sí).
const double _escalaSuperacion = 30;

/// Historial de duelos. Los duelos no dan monedas ni premios.
List<DueloHistorial> get _historialDuelos => Datos.i.social.historialDuelos;

// ---- Conexiones ----
// De otra persona solo se exponen racha, nivel y monedas — NUNCA sus
// pasos ni su historial crudo. La lista completa vive en AmigosScreen.

// ---- Ranking ----

/// Las dos pestañas internas de Social. Por default abre en Amigos.
enum _TabSocial { amigos, ranking }

/// Dentro de Ranking, dos mundos que NO se mezclan.
///
/// Un grupo privado lo armaste vos con gente que conocés y puede mostrar
/// puntos. La liga local es contra desconocidos, nunca muestra puntos y
/// reparte monedas. Mezclarlas en la misma lista hacía que la liga
/// pareciera un grupo más.
enum _VistaRanking { misGrupos, ligaLocal }

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  _TabSocial _tab = _TabSocial.amigos;
  _VistaRanking _vista = _VistaRanking.misGrupos;
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: const AppHeader(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text('Social', style: AppTheme.sectionTitle),
                    const SizedBox(height: 20),
                    _SelectorTab(
                      seleccionado: _tab,
                      onChanged: (tab) => setState(() => _tab = tab),
                    ),
                    const SizedBox(height: 20),
                    if (_tab == _TabSocial.amigos)
                      ..._buildAmigos(context)
                    else
                      ..._buildRanking(context),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const BottomNavBar(currentIndex: 2),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Pestaña Amigos
  // ============================================================

  List<Widget> _buildAmigos(BuildContext context) {
    return [
      _buildDuelosSection(context),
      const SizedBox(height: 16),
      _buildHistorialDuelos(context),
      const SizedBox(height: 28),
      _buildConexionesSection(context),
    ];
  }

  Widget _buildDuelosSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              'Duelos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // Retar a alguien es elegir a un amigo: el botón lleva a la
            // lista en vez de a una pantalla propia que repetiría lo
            // mismo.
            //
            // TODO: falta la pantalla de armar el duelo (apuesta,
            // duración, confirmación del rival).
            BotonRelieve(
              label: 'Nuevo duelo',
              icono: Icons.add,
              compacto: true,
              onPressed: _abrirAmigos,
            ),
          ],
        ),
        const SizedBox(height: 16),
        hayDueloActivo
            ? _buildDueloActivoCard(context)
            : _buildSinDuelo(context),
      ],
    );
  }

  /// Duelo en curso: superación relativa sobre el propio promedio (no
  /// puntos crudos comparados directo entre dos personas distintas).
  Widget _buildDueloActivoCard(BuildContext context) {
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
          Row(
            children: [
              Text(
                'Duelo vs $duelloRivalHandle',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                duelloTiempoRestante,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildBarraSuperacion(
            context,
            label: 'Tú',
            porcentaje: duelloSuperacionPropia,
            destacado: true,
          ),
          const SizedBox(height: 12),
          _buildBarraSuperacion(
            context,
            label: duelloRivalHandle,
            porcentaje: duelloSuperacionRival,
            destacado: false,
          ),
        ],
      ),
    );
  }

  Widget _buildBarraSuperacion(
    BuildContext context, {
    required String label,
    required double porcentaje,
    required bool destacado,
  }) {
    final pronombre = destacado ? 'tu' : 'su';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: +${_formatPercent(porcentaje)}% sobre $pronombre promedio',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (porcentaje / _escalaSuperacion).clamp(0.05, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.azulBruma,
            valueColor: AlwaysStoppedAnimation(
              destacado ? AppColors.accent : AppColors.azulSuave,
            ),
          ),
        ),
      ],
    );
  }

  /// Estado sin duelos activos.
  ///
  /// Si el usuario todavía no tiene amigos, ofrecerle "retar a un amigo"
  /// es mandarlo a una lista vacía: primero hay que conseguir a alguien
  /// a quien retar.
  Widget _buildSinDuelo(BuildContext context) {
    final sinAmigos = Datos.i.social.conexiones.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.accent.withValues(alpha: 0.12),
            child: const Icon(
              Icons.sports_kabaddi,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            sinAmigos
                ? 'Agregá a alguien para poder retarlo'
                : 'Sin duelos activos',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          BotonRelieve(
            label: sinAmigos ? 'Agregar un amigo' : 'Retar a un amigo',
            icono: sinAmigos ? Icons.person_add_alt_1 : Icons.sports_kabaddi,
            anchoCompleto: true,
            onPressed: sinAmigos
                ? () => mostrarAgregarAmigo(context)
                : _abrirAmigos,
          ),
        ],
      ),
    );
  }

  /// Fila deslizable con los últimos duelos: gana (W, acento) o pierde
  /// (L, gris) marcado sobre el avatar del rival.
  Widget _buildHistorialDuelos(BuildContext context) {
    // Sin duelos jugados no hay historial que mostrar: el título solo,
    // encima de una fila vacía, parece un error de carga.
    if (_historialDuelos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HISTORIAL DE DUELOS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _historialDuelos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) =>
                _buildBurbujaDuelo(context, _historialDuelos[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildBurbujaDuelo(BuildContext context, DueloHistorial duelo) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.cardBorder,
            child: Icon(Icons.person, color: AppColors.textSecondary),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: duelo.ganado
                    ? AppColors.accentSecondary
                    : AppColors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: Text(
                duelo.ganado ? 'W' : 'L',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: duelo.ganado ? Colors.black : AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Amigos: los tres contadores y un asomo de la lista.
  ///
  /// Los contadores están ACÁ y no escondidos dentro de otra pantalla:
  /// cuántos amigos tenés y cuántas solicitudes te esperan es lo primero
  /// que se viene a ver, y no puede costar un toque de más.
  Widget _buildConexionesSection(BuildContext context) {
    final social = Datos.i.social;
    final primeros = social.conexiones.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ContadoresAmigos(onTocar: (i) => _abrirAmigos(pestania: i)),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'Tus amigos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (social.conexiones.length > primeros.length)
              CupertinoButton(
                onPressed: _abrirAmigos,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                child: Row(
                  children: [
                    Text(
                      'Ver todos',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 15,
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (primeros.isEmpty)
          _buildSinAmigos(context)
        else
          for (var i = 0; i < primeros.length; i++) ...[
            _buildConexionRow(context, primeros[i]),
            if (i != primeros.length - 1) const SizedBox(height: 12),
          ],
      ],
    );
  }

  /// Todavía no tiene a nadie.
  ///
  /// Un estado vacío sin salida es una pared: acá el botón de agregar es
  /// lo único que hay, porque es lo único que se puede hacer.
  Widget _buildSinAmigos(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.accent.withValues(alpha: 0.12),
            child: const Icon(
              CupertinoIcons.person_2,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Aún no tenés amigos',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Agregá a alguien con su usuario y compará rachas.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          BotonRelieve(
            label: 'Agregar',
            icono: CupertinoIcons.person_add,
            anchoCompleto: true,
            onPressed: () => mostrarAgregarAmigo(context),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirAmigos({int pestania = 0}) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => AmigosScreen(pestaniaInicial: pestania),
      ),
    );
    // Al volver puede haber amigos nuevos o menos solicitudes.
    if (mounted) setState(() {});
  }

  Widget _buildConexionRow(BuildContext context, Conexion conexion) {
    return GestureDetector(
      onTap: () => _mostrarPerfilConexion(context, conexion),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.cardBorder,
              child: Icon(Icons.person, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conexion.nombre,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    conexion.handle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _buildRachaBadge(context, conexion.rachaSemanas),
          ],
        ),
      ),
    );
  }

  Widget _buildRachaBadge(BuildContext context, int semanas) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department,
            color: AppColors.accentSecondary,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '$semanas sem',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.accentSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Perfil reducido de la conexión.
  ///
  /// Solo racha. El NIVEL y las MONEDAS se sacaron a propósito: el nivel
  /// se deriva del cashback, o sea de la prima de la póliza, y las
  /// monedas son saldo. Las dos juntas dejan estimar cuánta plata mueve
  /// una persona, y eso no se le muestra a nadie más — menos en
  /// Guatemala. Esto reemplaza a la regla vieja de CLAUDE.md, que pedía
  /// mostrar racha, categoría y monedas.
  void _mostrarPerfilConexion(BuildContext context, Conexion conexion) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (hoja) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.cardBorder,
              child: Icon(
                Icons.person,
                color: AppColors.textSecondary,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              conexion.nombre,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              conexion.handle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            if (conexion.rachaSemanas > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentSecondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      size: 17,
                      color: AppColors.accentSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${conexion.rachaSemanas} semanas de racha',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'Todavía no tiene una racha activa.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: BotonRelieve(
                    label: 'Cancelar',
                    color: AppColors.textSecondary,
                    anchoCompleto: true,
                    onPressed: () => Navigator.of(hoja).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BotonRelieve(
                    label: 'Eliminar',
                    // Azul como todo lo demás: lo destructivo lo marca
                    // la confirmación de iOS, no el color del botón.
                    anchoCompleto: true,
                    onPressed: () {
                      Navigator.of(hoja).pop();
                      _eliminarConexion(conexion);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarConexion(Conexion conexion) async {
    final confirmado = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('¿Eliminar a ${conexion.nombre}?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Van a dejar de verse en tus competencias y duelos.'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;
    setState(() => Datos.i.social.conexiones.remove(conexion));
  }

  // ============================================================
  // Pestaña Ranking
  // ============================================================

  /// Ranking se parte en dos mundos que NO se mezclan: tus grupos
  /// privados, y la liga local con desconocidos. Antes convivían en la
  /// misma fila de chips, y "Liga local" parecía un grupo más — cuando en
  /// realidad se juega con otras reglas y con gente que no elegiste.
  List<Widget> _buildRanking(BuildContext context) {
    return [
      _SelectorVista(
        seleccionado: _vista,
        onChanged: (v) {
          HapticFeedback.selectionClick();
          setState(() => _vista = v);
        },
      ),
      const SizedBox(height: 24),
      if (_vista == _VistaRanking.misGrupos)
        ..._buildMisGrupos(context)
      else
        ..._buildLigaLocal(context),
    ];
  }

  // ---- Mis grupos ----

  /// Lista de grupos estilo chats: buscador arriba, una fila por grupo,
  /// y cada fila abre su tabla.
  ///
  /// Antes era un carrusel horizontal. Con tres grupos se veía bien; con
  /// doce, encontrar uno era scrollear a ciegas hacia la derecha. Una
  /// lista vertical con buscador escala sin que nada se esconda.
  List<Widget> _buildMisGrupos(BuildContext context) {
    final grupos = Datos.i.social.deConocidos;
    if (grupos.isEmpty) return [_buildSinGrupos(context)];

    final filtro = _busqueda.trim().toLowerCase();
    final visibles = filtro.isEmpty
        ? grupos
        : grupos.where((g) => g.nombre.toLowerCase().contains(filtro)).toList();

    return [
      _ResumenSocial(grupos: grupos),
      const SizedBox(height: 24),
      const EtiquetaSeccion('MIS COMPETENCIAS'),
      const SizedBox(height: 12),
      // El buscador aparece recién cuando hay suficientes grupos como
      // para necesitarlo. Con dos, solo ocupa lugar.
      if (grupos.length >= 5) ...[
        CupertinoSearchTextField(
          placeholder: 'Buscar competencia',
          onChanged: (t) => setState(() => _busqueda = t),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
      ],
      if (visibles.isEmpty)
        _buildSinResultados(context)
      else
        for (final g in visibles) ...[
          _FilaGrupo(grupo: g, onTap: () => _abrirGrupo(g)),
          const SizedBox(height: 8),
        ],
      const SizedBox(height: 8),
      _FilaCrearGrupo(onPressed: _menuGrupos),
    ];
  }

  void _abrirGrupo(GrupoRanking grupo) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => RankingGrupoScreen(grupo: grupo),
      ),
    );
  }

  Widget _buildSinResultados(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Text(
        'Ninguna competencia se llama así.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    ),
  );

  Widget _buildSinGrupos(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.person_2,
            size: 32,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Todavía no estás en ninguna competencia.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          BotonRelieve(
            label: 'Crear o unirme',
            icono: CupertinoIcons.plus_circle,
            onPressed: _menuGrupos,
          ),
        ],
      ),
    );
  }

  // ---- Liga local ----

  List<Widget> _buildLigaLocal(BuildContext context) {
    final liga = Datos.i.social.ligaLocal;
    if (liga == null) return [_buildSinLiga(context)];

    return [
      _buildTarjetaLiga(context, liga),
      const SizedBox(height: 16),
      _buildAccionesLiga(context, liga),
      const SizedBox(height: 24),
      const EtiquetaSeccion('TABLA DE LA ZONA'),
      const SizedBox(height: 12),
      ListaRanking(grupo: liga),
    ];
  }

  /// La tarjeta principal de la liga. Lleva naranja porque es lo distinto
  /// de la pantalla: dice de un vistazo "esto no es tu grupo privado".
  Widget _buildTarjetaLiga(BuildContext context, GrupoRanking liga) {
    final indice = liga.miembros.indexWhere((p) => p.esUsuario);
    final persona = indice < 0 ? null : liga.miembros[indice];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card,
            Color.lerp(AppColors.accent, AppColors.card, 0.93)!,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.location_solid,
                size: 16,
                color: AppColors.azulMedio,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  // La zona es el área de la liga, nunca la ubicación de
                  // nadie: la app no comparte ubicación de personas.
                  liga.zona ?? 'Tu zona',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (liga.nivelActividad != null)
                _EtiquetaNivel(nivel: liga.nivelActividad!),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            liga.nombre,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.entre),
          if (persona == null)
            Text(
              'Todavía no estás compitiendo en esta liga.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('#${indice + 1}', style: AppTheme.display(40)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'de ${liga.miembros.length} participantes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                ChipTendencia(tendencia: persona.tendencia),
              ],
            ),
          if (persona != null) ...[
            const SizedBox(height: 4),
            Text(
              '${persona.puntosSemana} pts esta semana',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (liga.premiosMonedas.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.entre),
            Row(
              children: [
                for (var i = 0; i < liga.premiosMonedas.length; i++) ...[
                  PremioPodio(puesto: i + 1, monedas: liga.premiosMonedas[i]),
                  if (i != liga.premiosMonedas.length - 1)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Si no estás unido, la única acción posible es unirte. Si ya estás,
  /// unirte no existe: quedan reglas y compartir.
  Widget _buildAccionesLiga(BuildContext context, GrupoRanking liga) {
    if (!liga.estoyUnido) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: () => _mostrarReglasLiga(liga),
          child: const Text('Unirme a la liga local'),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _BotonSecundario(
            icono: CupertinoIcons.doc_text,
            label: 'Ver reglas',
            onPressed: () => _mostrarReglasLiga(liga),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BotonSecundario(
            icono: CupertinoIcons.share,
            label: 'Compartir',
            onPressed: () => _compartirPosicion(liga),
          ),
        ),
      ],
    );
  }

  Widget _buildSinLiga(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        'Todavía no hay una liga abierta en tu zona. Te avisamos cuando '
        'haya suficiente gente cerca.',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  void _mostrarReglasLiga(GrupoRanking liga) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
      builder: (_) => _HojaReglasLiga(liga: liga),
    );
  }

  /// Abre la hoja de compartir de iOS con tu posición en la liga.
  ///
  /// Se comparte SOLO tu puesto, nunca los puntos ni los pasos de nadie
  /// más: el texto habla del usuario y no expone a los otros competidores.
  Future<void> _compartirPosicion(GrupoRanking liga) async {
    final indice = liga.miembros.indexWhere((p) => p.esUsuario);
    if (indice < 0) return;

    HapticFeedback.selectionClick();
    // En iPad la hoja de compartir necesita un ancla o revienta: se le
    // pasa el rectángulo de la pantalla desde donde salió.
    final caja = context.findRenderObject() as RenderBox?;

    await SharePlus.instance.share(
      ShareParams(
        text:
            'Voy #${indice + 1} de ${liga.miembros.length} en la '
            '${liga.nombre} de +Vida 💪',
        sharePositionOrigin: caja == null
            ? null
            : caja.localToGlobal(Offset.zero) & caja.size,
      ),
    );
  }

  // ---- Crear / unirse ----

  /// Las tres acciones sobre grupos, juntas en un action sheet de iOS.
  ///
  /// Antes "Crear grupo" era un chip más (parecía un grupo llamado "Crear
  /// grupo") y "Unirme" un botón hasta abajo de la tabla, que además no
  /// tenía nada que ver con el grupo que estabas viendo: estás adentro de
  /// Familia, no te sirve que te ofrezcan unirte a algo ahí.
  Future<void> _menuGrupos() async {
    HapticFeedback.selectionClick();

    final accion = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Competencias'),
        message: const Text(
          'Competí en tabla con gente que ya conocés: la oficina, la '
          'familia, tus amigos.',
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
        final creado = await mostrarCrearGrupo(context);
        // Se limpia la búsqueda: si había un filtro puesto, el grupo
        // recién creado podría no coincidir y parecería que no se creó.
        if (creado && mounted) setState(() => _busqueda = '');
      case 'unirse':
        await mostrarUnirseGrupo(context);
    }
  }

  // ---- Tabla, compartida por las dos vistas ----
}

/// Selector de pestaña tipo "segmented control": Amigos / Ranking. Mismo
/// estilo que el selector de período de la pantalla Progress.
class _SelectorTab extends StatelessWidget {
  const _SelectorTab({required this.seleccionado, required this.onChanged});

  final _TabSocial seleccionado;
  final ValueChanged<_TabSocial> onChanged;

  static const _opciones = [
    (label: 'Amigos', valor: _TabSocial.amigos),
    (label: 'Ranking', valor: _TabSocial.ranking),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardBorder.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final opcion in _opciones)
            Expanded(
              child: _buildTab(
                context,
                opcion.label,
                opcion.valor == seleccionado,
                () => onChanged(opcion.valor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    String label,
    bool activo,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // Relleno azul sólido para el activo: es el interruptor
          // principal de la pantalla y tiene que pesar más que el
          // selector de abajo.
          color: activo ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: activo
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: activo ? AppColors.card : AppColors.textSecondary,
            fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

String _formatPercent(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toString();
}

/// Cómo venís en Social, arriba de todo.
///
/// Sin esto la pestaña abría con una lista de nombres y nada más: no
/// había un solo número tuyo en pantalla. Acá va lo que compite en todos
/// los grupos a la vez — tus puntos de la semana — y en cuántos vas
/// primero.
class _ResumenSocial extends StatelessWidget {
  const _ResumenSocial({required this.grupos});

  final List<GrupoRanking> grupos;

  @override
  Widget build(BuildContext context) {
    final resumen = Datos.i.resumen;
    final diferencia = resumen.puntosSemana - resumen.puntosSemanaAnterior;
    final primeros = grupos
        .where((g) => g.miembros.isNotEmpty && g.miembros.first.esUsuario)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Azul de marca, muy diluido: es una superficie mediana-grande y
        // el azul no puede taparla entera.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card,
            Color.lerp(AppColors.accent, AppColors.card, 0.9)!,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const EtiquetaSeccion('TU SEMANA'),
              const Spacer(),
              if (resumen.rachaSemanas > 0)
                _ChipRacha(semanas: resumen.rachaSemanas),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${resumen.puntosSemana}', style: AppTheme.display(40)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(
                  'pts',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          Text(
            _comparacion(diferencia),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.emoji_events,
                size: 18,
                color: AppColors.accentSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  primeros == 0
                      ? 'Todavía no vas primero en ninguna competencia'
                      : 'Vas primero en $primeros de ${grupos.length} '
                            '${grupos.length == 1 ? "competencia" : "competencias"}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _comparacion(int diferencia) {
    if (diferencia == 0) return 'Igual que la semana pasada';
    final signo = diferencia > 0 ? '+' : '−';
    final palabra = diferencia > 0 ? 'más' : 'menos';
    return '$signo${diferencia.abs()} pts $palabra que la semana pasada';
  }
}

/// La racha, como pastilla. Naranja: es un detalle chico que tiene que
/// saltar a la vista.
class _ChipRacha extends StatelessWidget {
  const _ChipRacha({required this.semanas});

  final int semanas;

  @override
  Widget build(BuildContext context) => ShadBadge.raw(
    variant: ShadBadgeVariant.secondary,
    backgroundColor: AppColors.accentSecondary.withValues(alpha: 0.18),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_fire_department,
          size: 14,
          color: AppColors.accentSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          '$semanas ${semanas == 1 ? "semana" : "semanas"}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

/// Selector de vista dentro de Ranking: Mis grupos / Liga local.
///
/// Deliberadamente NO es otra píldora. Apilado debajo del selector de
/// Amigos/Ranking se veían como dos controles del mismo peso, y no lo
/// son: arriba se cambia de sección, acá solo se cambia de tabla. El
/// subrayado dice "estás adentro de algo" en vez de "elegí una de dos".
class _SelectorVista extends StatelessWidget {
  const _SelectorVista({required this.seleccionado, required this.onChanged});

  final _VistaRanking seleccionado;
  final ValueChanged<_VistaRanking> onChanged;

  static const _opciones = [
    (
      label: 'Mis competencias',
      icono: CupertinoIcons.person_2_fill,
      valor: _VistaRanking.misGrupos,
    ),
    (
      label: 'Liga local',
      icono: CupertinoIcons.location_solid,
      valor: _VistaRanking.ligaLocal,
    ),
  ];

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final o in _opciones)
        _Pestania(
          label: o.label,
          icono: o.icono,
          activa: o.valor == seleccionado,
          onTap: () => onChanged(o.valor),
        ),
    ],
  );
}

class _Pestania extends StatelessWidget {
  const _Pestania({
    required this.label,
    required this.icono,
    required this.activa,
    required this.onTap,
  });

  final String label;
  final IconData icono;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = activa ? AppColors.accent : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icono, size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: activa ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            // El subrayado crece desde el centro al cambiar de pestaña,
            // en vez de aparecer de golpe.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 3,
              width: activa ? 28 : 0,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una fila de la lista de grupos. Se lee como un chat: inicial, nombre,
/// una línea de contexto, y el chevron que dice que abre algo.
class _FilaGrupo extends StatelessWidget {
  const _FilaGrupo({required this.grupo, required this.onTap});

  final GrupoRanking grupo;
  final VoidCallback onTap;

  /// Cuánta gente hay y cuánto le queda a la competencia.
  ///
  /// El plazo solo aplica a las competencias que alguien creó con una
  /// fecha de cierre. La liga local no cierra: se reinicia sola cada
  /// semana, y decirle "quedan 3 días" sería mentir.
  static String _subtituloGrupo(GrupoRanking g) {
    final n = g.miembros.length;
    final base = '$n ${n == 1 ? "integrante" : "integrantes"}';

    final cierra = g.cierra;
    if (cierra == null || g.tipo != TipoGrupo.conocidos) return base;

    final dias = cierra.difference(DateTime.now()).inDays;
    if (dias < 0) return '$base · terminó';
    if (dias == 0) return '$base · termina hoy';
    if (dias == 1) return '$base · queda 1 día';
    if (dias < 30) return '$base · quedan $dias días';

    final meses = (dias / 30).round();
    return '$base · ${meses == 1 ? "queda 1 mes" : "quedan $meses meses"}';
  }

  @override
  Widget build(BuildContext context) {
    final posicion = grupo.miembros.indexWhere((m) => m.esUsuario) + 1;

    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
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
                    _subtituloGrupo(grupo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Sin abrir el grupo ya sabés cómo vas: eso es lo que hace
            // que la lista sirva y no sea solo un índice.
            if (posicion > 0) _BadgePosicion(posicion: posicion),
            const SizedBox(width: 4),
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

/// La inicial del grupo en un círculo.
///
/// El color sale del nombre, no de una lista fija: así dos grupos
/// distintos casi nunca se ven iguales, y el mismo grupo siempre tiene el
/// mismo color. Todos son tonos del azul de marca, para que la pantalla
/// no se vuelva un arcoíris.
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
    final color = _tonos[grupo.nombre.hashCode.abs() % _tonos.length];

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

/// Tu puesto en el grupo. Naranja si estás en el podio: es un detalle
/// chico que tiene que saltar a la vista.
class _BadgePosicion extends StatelessWidget {
  const _BadgePosicion({required this.posicion});

  final int posicion;

  @override
  Widget build(BuildContext context) {
    final enPodio = posicion <= 3;
    final color = enPodio ? AppColors.accentSecondary : AppColors.accent;

    return ShadBadge.raw(
      variant: ShadBadgeVariant.secondary,
      backgroundColor: color.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (enPodio) ...[
            Icon(Icons.emoji_events, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            '#$posicion',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// La última fila de la lista: crear o unirse. Va al final, después de lo
/// que ya existe, para no competir con los grupos del usuario.
class _FilaCrearGrupo extends StatelessWidget {
  const _FilaCrearGrupo({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.plus_circle,
            size: 22,
            color: AppColors.accent,
          ),
          const SizedBox(width: 12),
          Text(
            'Crear o unirme a una competencia',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

/// El nivel de actividad de la liga, como etiqueta chica.
class _EtiquetaNivel extends StatelessWidget {
  const _EtiquetaNivel({required this.nivel});

  final String nivel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.accentSecondary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      nivel,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.accentSecondary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Botón secundario de la liga: ver reglas, compartir.
class _BotonSecundario extends StatelessWidget {
  const _BotonSecundario({
    required this.icono,
    required this.label,
    required this.onPressed,
  });

  final IconData icono;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Las reglas de la liga local, en una hoja aparte.
///
/// Antes este texto vivía siempre visible arriba de la tabla. Es
/// importante la primera vez y ruido a partir de la segunda: acá está
/// cuando se busca, y no estorba el resto del tiempo.
class _HojaReglasLiga extends StatelessWidget {
  const _HojaReglasLiga({required this.liga});

  final GrupoRanking liga;

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
                'Cómo funciona la liga local',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.entre),
              _Regla(
                icono: CupertinoIcons.location_solid,
                texto:
                    'Competís con gente de ${liga.zona ?? "tu zona"} que se '
                    'mueve parecido a vos.',
                estilo: estilo,
              ),
              _Regla(
                icono: CupertinoIcons.eye_slash,
                texto:
                    'Nadie ve los puntos de nadie, solo la posición. Vos sí '
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
              _Regla(
                icono: CupertinoIcons.clock,
                texto: liga.cierra == null
                    ? 'La liga se reinicia cada semana.'
                    : 'Cierra el domingo y arranca una nueva el lunes.',
                estilo: estilo,
              ),
              const SizedBox(height: AppSpacing.entre),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
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
