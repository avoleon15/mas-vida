import 'package:flutter/material.dart';
import '../rachas_recompensas.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/progress_ring.dart';

// Racha activa del usuario, en semanas seguidas cumpliendo la meta
// semanal. Mismo dato de ejemplo que usan Progress y Social.
const int rachaSemanas = 12;

/// Un nivel de la categoría anual (Bronze/Silver/Gold/Platinum) y el
/// porcentaje de cashback que otorga sobre la póliza.
class _Tier {
  const _Tier(this.nombre, this.porcentajeCashback);

  final String nombre;
  final double porcentajeCashback;
}

const List<_Tier> _tiers = [
  _Tier('Bronze', 5),
  _Tier('Silver', 7.5),
  _Tier('Gold', 10),
  _Tier('Platinum', 20),
];

// ============================================================
// Datos de ejemplo de "Metas Mensuales" (hardcodeados, sin backend
// todavía). OJO: este es un sistema DISTINTO a la meta semanal
// adaptativa de Progress (esa paga puntos/categoría). Acá se pagan
// MONEDAS — la moneda que se gasta en Premios y caduca a 90 días.
// ============================================================

// Avance general del mes (0.0 a 1.0). Ejemplo simple, sin fórmula real
// todavía.
const double avanceMetaBase = 0.55;

// Las 4 metas ya elegidas este mes. Una viene marcada como completa
// para mostrar el banner de "meta completada" en la demo.
const List<Map<String, dynamic>> _metasDelMes = [
  {
    'nombre': 'Camina 50km este mes',
    'progreso': 32,
    'objetivo': 50,
    'unidad': 'km',
    'monedas': 10,
    'completa': false,
  },
  {
    'nombre': '3 entrenos de fuerza',
    'progreso': 3,
    'objetivo': 3,
    'unidad': 'entrenos',
    'monedas': 8,
    'completa': true,
  },
  {
    'nombre': '2 clases de yoga',
    'progreso': 1,
    'objetivo': 2,
    'unidad': 'clases',
    'monedas': 6,
    'completa': false,
  },
  {
    'nombre': '20,000 pasos extra',
    'progreso': 14000,
    'objetivo': 20000,
    'unidad': 'pasos',
    'monedas': 12,
    'completa': false,
  },
];

// Solo el día 1 del mes se eligen las metas nuevas. Se deja en false
// para la demo; cambiala a mano para ver la tarjeta de selección.
const bool esMomentoDeElegir = false;

// 8 opciones calibradas entre las que se eligen las 4 metas del mes.
const List<String> _opcionesMetas = [
  'Camina 40km',
  '5 entrenos de fuerza',
  '2 clases de yoga',
  '15,000 pasos extra',
  '4 entrenos de cardio',
  '30km en bici',
  '3 clases de spinning',
  '10km de trote',
];

const int monedasEsteMes = 3;
const int techoMonedasMensual = 8;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Datos de ejemplo (hardcodeados por ahora, sin backend todavía).
  static const int pasos = 8432;
  static const int metaPasos = 10000;
  static const int puntosTotal = 12450;
  static const int cashbackAcumulado = 450; // en quetzales
  static const String categoriaActual = 'Silver';
  static const int puntosParaSiguienteNivel = 3200;
  static const String nombreUsuario = 'Diego';
  // Avance dentro del nivel actual (Silver), en lo que se recibe el dato
  // real del backend con los umbrales de puntos por nivel.
  static const double progresoNivelActual = 0.40;

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
                    _buildSaludo(context),
                    const SizedBox(height: 6),
                    _buildRachaLinea(context),
                    const SizedBox(height: 24),
                    Center(
                      child: _StepsRing(
                        steps: pasos,
                        goal: metaPasos,
                        color: AppColors.colorForTier(categoriaActual),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTiempoRestante(context),
                    const SizedBox(height: 28),
                    _buildPointsCard(context),
                    const SizedBox(height: 28),
                    _buildCashbackSection(context),
                    const SizedBox(height: 28),
                    _buildMetasMensualesSection(context),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const BottomNavBar(currentIndex: 0),
          ],
        ),
      ),
    );
  }

  /// Saludo dinámico según la hora del día, con el nombre del usuario.
  /// Reemplaza al antiguo título fijo "HOY". Sin fondo: solo una sombra
  /// suave detrás del texto para que no quede tan plano.
  Widget _buildSaludo(BuildContext context) {
    return Text(
      '${_saludoSegunHora()}, $nombreUsuario',
      style: AppTheme.sectionTitle.copyWith(
        fontSize: 28,
        shadows: [
          Shadow(
            color: AppColors.textPrimary.withValues(alpha: 0.10),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }

  /// Línea de racha activa bajo el saludo. Si al usuario le falta
  /// exactamente 1 semana para el próximo hito de monedas, se agrega un
  /// texto destacado en color de acento; si no, queda la línea simple.
  Widget _buildRachaLinea(BuildContext context) {
    final hito = proximoHito(rachaSemanas);
    final aUnaSemana = hito != null && hito.semanas - rachaSemanas == 1;

    return Row(
      children: [
        const Icon(
          Icons.local_fire_department,
          color: AppColors.accentSecondary,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          'Racha de $rachaSemanas semanas',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        if (aUnaSemana) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '¡1 semana más para +${hito.monedas} monedas!',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// "Buenos días" antes de las 12pm, "Buenas tardes" entre 12pm y 7pm,
  /// "Buenas noches" después de las 7pm.
  static String _saludoSegunHora() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// Tiempo que falta del día para cumplir la meta de pasos. Va debajo
  /// del anillo (que adentro solo muestra pasos y meta).
  Widget _buildTiempoRestante(BuildContext context) {
    return Center(
      child: Text(
        'Te quedan ${_horasRestantesDelDia()}h del día',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  /// Horas que quedan del día actual hasta la medianoche, redondeadas.
  static int _horasRestantesDelDia() {
    final ahora = DateTime.now();
    final medianoche = DateTime(ahora.year, ahora.month, ahora.day + 1);
    return (medianoche.difference(ahora).inMinutes / 60).round();
  }

  /// Tarjeta de puntos totales. Los puntos nunca se gastan: solo se
  /// muestran (definen categoría y % de cashback), por eso no lleva
  /// ningún botón de canje.
  ///
  /// El texto va centrado en base al ancho TOTAL de la tarjeta (no al
  /// espacio que queda libre después del ícono), por eso usamos un Stack:
  /// el ícono se ubica aparte, pegado a la izquierda con Positioned.
  Widget _buildPointsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatNumber(puntosTotal),
                textAlign: TextAlign.center,
                // Tamaño intermedio: menor al de pasos, mayor al de
                // cashback.
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 32,
                ),
              ),
              Text(
                'PUNTOS TOTALES',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                child: Icon(Icons.star, color: AppColors.accent, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sección "Tu Cashback": monto acumulado, categoría actual con su %
  /// protagonista, y qué tan cerca está del siguiente nivel. El cashback
  /// siempre se devuelve como dinero después del pago de la prima (regla
  /// regulatoria de Guatemala) — nunca se le llama "descuento" ni "ahorro
  /// en tu prima".
  Widget _buildCashbackSection(BuildContext context) {
    final tierActual = _tiers.firstWhere(
      (tier) => tier.nombre == categoriaActual,
    );
    final siguienteTier = _tiers[_tiers.indexOf(tierActual) + 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              'Tu Cashback',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.of(context).pushNamed('/mi-plan'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver mi plan ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
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
              Text(
                'Q$cashbackAcumulado acumulados este año',
                // El más chico de los tres números principales de la
                // pantalla (pasos > puntos > cashback).
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              _buildCashbackDestacado(context, tierActual),
              const SizedBox(height: 24),
              _buildTierSteps(context),
              const SizedBox(height: 16),
              Text(
                '${_formatNumber(puntosParaSiguienteNivel)} pts para llegar '
                'a ${siguienteTier.nombre} y ganar '
                '${_formatPercent(siguienteTier.porcentajeCashback)}% '
                'de cashback',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// El % de cashback de la categoría actual, grande y protagonista,
  /// junto con el nombre de la categoría. Es lo primero que se entiende
  /// de un vistazo: "cuánto te está dando tu categoría hoy".
  Widget _buildCashbackDestacado(BuildContext context, _Tier tierActual) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${_formatPercent(tierActual.porcentajeCashback)}%',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: AppColors.colorForTier(tierActual.nombre),
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'de cashback en tu\ncategoría ${tierActual.nombre}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  /// Medidor simple de 4 escalones (uno por categoría). Los escalones
  /// hasta la categoría actual se ven rellenos en color de acento; el
  /// resto queda apagado. Reemplaza al camino de círculos anterior por
  /// algo más fácil de leer de un vistazo.
  Widget _buildTierSteps(BuildContext context) {
    final currentIndex = _tiers.indexWhere(
      (tier) => tier.nombre == categoriaActual,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _tiers.length; i++) ...[
              if (i != 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: i <= currentIndex
                        ? AppColors.accentSecondary
                        : AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < _tiers.length; i++)
              Expanded(
                child: Text(
                  _tiers[i].nombre,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: i == currentIndex
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: i == currentIndex
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Sección "Metas Mensuales": sistema aparte del de puntos/cashback de
  /// arriba. Acá se ganan MONEDAS (se gastan en Premios, caducan a 90
  /// días), nunca puntos.
  Widget _buildMetasMensualesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flag_outlined, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              'Metas Mensuales',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildMetaBaseCard(context),
        const SizedBox(height: 20),
        _buildFilaMetasDelMes(context),
        if (esMomentoDeElegir) ...[
          const SizedBox(height: 20),
          const _SeleccionDeMetas(),
        ],
        const SizedBox(height: 20),
        _buildContadorMonedas(context),
      ],
    );
  }

  /// Meta base adaptativa del mes: avance general (no depende de las 4
  /// metas elegidas, es un indicador aparte de actividad del mes).
  Widget _buildMetaBaseCard(BuildContext context) {
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
          Text(
            'Meta base del mes',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: avanceMetaBase,
              minHeight: 8,
              backgroundColor: AppColors.cardBorder,
              valueColor: const AlwaysStoppedAnimation(
                AppColors.accentSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_diasRestantesDelMes()} días restantes este mes',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Días que faltan del mes actual, calculado con DateTime.now().
  static int _diasRestantesDelMes() {
    final ahora = DateTime.now();
    final ultimoDiaDelMes = DateTime(ahora.year, ahora.month + 1, 0).day;
    return ultimoDiaDelMes - ahora.day;
  }

  /// Las 4 metas elegidas este mes, en filas angostas (no tarjetas
  /// grandes): nombre, avance, monedas que paga y si ya se completó.
  Widget _buildFilaMetasDelMes(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _metasDelMes.length; i++) ...[
          _buildFilaMeta(context, _metasDelMes[i]),
          if (i != _metasDelMes.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildFilaMeta(BuildContext context, Map<String, dynamic> meta) {
    final progreso = meta['progreso'] as int;
    final objetivo = meta['objetivo'] as int;
    final completa = meta['completa'] as bool;
    final fraccion = objetivo == 0
        ? 0.0
        : (progreso / objetivo).clamp(0.0, 1.0);
    final colorProgreso = completa
        ? AppColors.accentSecondary
        : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta['nombre'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fraccion,
                      minHeight: 4,
                      backgroundColor: AppColors.cardBorder,
                      valueColor: AlwaysStoppedAnimation(colorProgreso),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatNumber(progreso)} / ${_formatNumber(objetivo)} '
                    '${meta['unidad']}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: AppColors.accentSecondary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${meta['monedas']}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.accentSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Icon(
                  completa ? Icons.check_circle : Icons.check_circle_outline,
                  color: completa
                      ? AppColors.accentSecondary
                      : AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
        if (completa) ...[
          const SizedBox(height: 8),
          _buildBannerMetaCompletada(context, meta),
        ],
      ],
    );
  }

  /// Simula el estado de una notificación de meta completada (parte
  /// fija del layout de la demo, no una notificación push real).
  Widget _buildBannerMetaCompletada(
    BuildContext context,
    Map<String, dynamic> meta,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.celebration,
            color: AppColors.accentSecondary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '¡Meta completada! +${meta['monedas']} monedas agregadas '
              'a tu saldo',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.accentSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Monedas acuñadas este mes vs. el techo mensual del sistema de
  /// Metas Mensuales.
  Widget _buildContadorMonedas(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              const Icon(
                Icons.monetization_on,
                color: AppColors.accentSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '$monedasEsteMes / $techoMonedasMensual monedas este mes',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: monedasEsteMes / techoMonedasMensual,
              minHeight: 8,
              backgroundColor: AppColors.cardBorder,
              valueColor: const AlwaysStoppedAnimation(
                AppColors.accentSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Formatea un porcentaje sin decimales de sobra (7.5 -> "7.5",
  /// 10.0 -> "10").
  static String _formatPercent(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  static String _formatNumber(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buffer.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }
}

class _StepsRing extends StatelessWidget {
  const _StepsRing({
    required this.steps,
    required this.goal,
    required this.color,
  });

  final int steps;
  final int goal;
  // Color de la liga actual del usuario: el anillo cambia según en qué
  // categoría está (Bronze, Silver, Gold, Platinum).
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // El arco relleno es la proporción real pasos/meta (ej. 8432 de
        // 10000 = 84% del anillo).
        ProgressRing(progress: steps / goal, size: 260, color: color),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              HomeScreen._formatNumber(steps),
              // El número más grande y protagonista de toda la pantalla.
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 60,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'PASOS DE HOY',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Meta: ${HomeScreen._formatNumber(goal)} pasos',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tarjeta de selección de las 4 metas del mes. Solo aparece el día 1
/// del mes (ver [esMomentoDeElegir]). Tiene su propio estado (cuáles
/// opciones van marcadas) por eso es un StatefulWidget aparte, en vez
/// de mover toda la pantalla Home a stateful.
class _SeleccionDeMetas extends StatefulWidget {
  const _SeleccionDeMetas();

  @override
  State<_SeleccionDeMetas> createState() => _SeleccionDeMetasState();
}

class _SeleccionDeMetasState extends State<_SeleccionDeMetas> {
  final Set<String> _seleccionadas = {};

  void _alternarSeleccion(String opcion) {
    setState(() {
      if (_seleccionadas.contains(opcion)) {
        _seleccionadas.remove(opcion);
      } else if (_seleccionadas.length < 4) {
        _seleccionadas.add(opcion);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          Text(
            'Elegí tus 4 metas del mes',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Elegiste ${_seleccionadas.length} de 4',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opcion in _opcionesMetas)
                _buildOpcion(context, opcion),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // TODO: guardar las 4 metas elegidas (backend) y actualizar
              // _metasDelMes con la selección real.
              onPressed: _seleccionadas.length == 4 ? () {} : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppColors.cardBorder,
                disabledForegroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Confirmar mis 4 metas',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Una vez elegidas, tus metas quedan fijas hasta el próximo mes.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildOpcion(BuildContext context, String opcion) {
    final seleccionada = _seleccionadas.contains(opcion);
    return GestureDetector(
      onTap: () => _alternarSeleccion(opcion),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionada ? AppColors.accent : AppColors.cardBorder,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          opcion,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: seleccionada ? Colors.black : AppColors.textSecondary,
            fontWeight: seleccionada ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
