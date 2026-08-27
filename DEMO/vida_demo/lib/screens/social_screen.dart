import 'package:flutter/material.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../theme.dart';
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
/// De otra persona solo se exponen racha, nivel y monedas — NUNCA sus
/// pasos ni su historial crudo.
List<Conexion> get _conexiones => Datos.i.social.conexiones;

// ---- Ranking ----
List<String> get _gruposRanking => Datos.i.social.gruposRanking;

/// El ranking muestra POSICIÓN, nunca los puntos de los demás.
Map<String, List<RankingPersona>> get _rankingPorGrupo =>
    Datos.i.social.rankingPorGrupo;

/// Las dos pestañas internas de Social. Por default abre en Amigos.
enum _TabSocial { amigos, ranking }

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  _TabSocial _tab = _TabSocial.amigos;
  String _grupoSeleccionado = _gruposRanking.first;

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
            OutlinedButton(
              // TODO: crear lib/screens/nuevo_duelo_screen.dart, registrar
              // la ruta '/nuevo-duelo' en main.dart y navegar con
              // Navigator.of(context).pushNamed('/nuevo-duelo').
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Nuevo duelo',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
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
            backgroundColor: AppColors.cardBorder,
            valueColor: AlwaysStoppedAnimation(
              destacado ? AppColors.accentSecondary : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// Estado sin duelos activos: invitación simple a retar a un amigo.
  Widget _buildSinDuelo(BuildContext context) {
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
            'Sin duelos activos',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // TODO: crear lib/screens/nuevo_duelo_screen.dart, registrar
              // la ruta '/nuevo-duelo' en main.dart y navegar ahí.
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Retar a un amigo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fila deslizable con los últimos duelos: gana (W, acento) o pierde
  /// (L, gris) marcado sobre el avatar del rival.
  Widget _buildHistorialDuelos(BuildContext context) {
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

  Widget _buildConexionesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Amigos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            GestureDetector(
              // TODO: crear lib/screens/agregar_amigo_screen.dart, registrar
              // la ruta '/agregar-amigo' en main.dart y navegar ahí.
              onTap: () {},
              child: Text(
                '+ Agregar',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _conexiones.length; i++) ...[
          _buildConexionRow(context, _conexiones[i]),
          if (i != _conexiones.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
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

  /// Perfil reducido de la conexión: nunca muestra pasos ni actividad
  /// cruda de otra persona, solo lo que ya comparte públicamente en la
  /// app (racha, categoría, monedas).
  void _mostrarPerfilConexion(BuildContext context, Conexion conexion) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatPerfil(
                    context,
                    icon: Icons.local_fire_department,
                    valor: '${conexion.rachaSemanas} sem',
                    label: 'RACHA',
                  ),
                  _buildStatPerfil(
                    context,
                    icon: Icons.workspace_premium_outlined,
                    valor: 'Nivel ${conexion.nivel}',
                    label: 'NIVEL',
                    colorValor: AppColors.colorForNivel(conexion.nivel),
                  ),
                  _buildStatPerfil(
                    context,
                    icon: Icons.monetization_on,
                    valor: '${conexion.monedasTotales}',
                    label: 'MONEDAS',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      // TODO: implementar bloqueo real de la conexión.
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Bloquear',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      // TODO: implementar eliminación real de la conexión.
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Eliminar conexión',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatPerfil(
    BuildContext context, {
    required IconData icon,
    required String valor,
    required String label,
    Color? colorValor,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(height: 6),
        Text(
          valor,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colorValor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Pestaña Ranking
  // ============================================================

  List<Widget> _buildRanking(BuildContext context) {
    final ranking = _rankingPorGrupo[_grupoSeleccionado]!;

    return [
      _buildChipsGrupos(context),
      const SizedBox(height: 20),
      Text(
        _grupoSeleccionado,
        style: AppTheme.sectionTitle.copyWith(fontSize: 24),
      ),
      const SizedBox(height: 16),
      _buildPosicionPropia(context, ranking),
      const SizedBox(height: 20),
      _buildListaRanking(context, ranking),
      const SizedBox(height: 24),
      _buildBotonUnirseGrupo(context),
    ];
  }

  Widget _buildChipsGrupos(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final grupo in _gruposRanking) ...[
            _buildChip(
              context,
              label: grupo,
              seleccionado: grupo == _grupoSeleccionado,
              onTap: () => setState(() => _grupoSeleccionado = grupo),
            ),
            const SizedBox(width: 10),
          ],
          _buildChip(
            context,
            label: 'Crear grupo',
            seleccionado: false,
            esCrear: true,
            // TODO: crear una pantalla para armar un grupo nuevo y
            // navegar ahí en vez de dejar este callback vacío.
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required bool seleccionado,
    required VoidCallback onTap,
    bool esCrear = false,
  }) {
    final colorTexto = seleccionado || esCrear
        ? AppColors.accent
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: seleccionado ? AppColors.accent : AppColors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (esCrear) ...[
              const Icon(Icons.add, size: 14, color: AppColors.accent),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorTexto,
                fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosicionPropia(
    BuildContext context,
    List<RankingPersona> ranking,
  ) {
    final indice = ranking.indexWhere((p) => p.esUsuario);
    final persona = ranking[indice];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.cardBorder,
            child: Icon(Icons.person, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Posición #${indice + 1}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _buildTendenciaIcon(context, persona.tendencia),
        ],
      ),
    );
  }

  Widget _buildListaRanking(
    BuildContext context,
    List<RankingPersona> ranking,
  ) {
    return Column(
      children: [
        for (var i = 0; i < ranking.length; i++) ...[
          _buildRankingRow(context, i + 1, ranking[i]),
          if (i != ranking.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildRankingRow(
    BuildContext context,
    int posicion,
    RankingPersona persona,
  ) {
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
          SizedBox(
            width: 24,
            child: _buildPosicionIndicador(context, posicion),
          ),
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
          _buildTendenciaIcon(context, persona.tendencia),
        ],
      ),
    );
  }

  Widget _buildPosicionIndicador(BuildContext context, int posicion) {
    if (posicion <= 3) {
      const colores = [
        AppColors.nivel3,
        AppColors.nivel2,
        AppColors.nivel1,
      ];
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

  Widget _buildTendenciaIcon(BuildContext context, Tendencia tendencia) {
    switch (tendencia) {
      case Tendencia.subida:
        return const Icon(
          Icons.arrow_upward,
          color: AppColors.accentSecondary,
          size: 16,
        );
      case Tendencia.bajada:
        return const Icon(
          Icons.arrow_downward,
          color: AppColors.textSecondary,
          size: 16,
        );
      case Tendencia.igual:
        return const Icon(
          Icons.remove,
          color: AppColors.textSecondary,
          size: 16,
        );
    }
  }

  Widget _buildBotonUnirseGrupo(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        // TODO: crear una pantalla para unirse/crear un grupo y navegar
        // ahí en vez de dejar este callback vacío.
        onPressed: () {},
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_add_outlined, size: 16),
            SizedBox(width: 8),
            Text('Unirme a un grupo'),
          ],
        ),
      ),
    );
  }
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activo ? AppColors.cardBorder : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: activo ? AppColors.textPrimary : AppColors.textSecondary,
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
