import 'package:flutter/material.dart';
import '../rachas_recompensas.dart';
import '../reglas_puntos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';

// ============================================================
// Datos de ejemplo. Todo hardcodeado por ahora (sin backend) y
// organizado en constantes simples por vista, para que sea fácil
// de reemplazar después con datos reales.
// ============================================================

// ---- Compartido entre las tres vistas (Nivel Actual es anual) ----
const String categoriaActual = 'Silver';
const String categoriaSiguiente = 'Gold';
const int puntosAnuales = 12450;
const int umbralSiguienteCategoria = 20000; // umbral hacia Gold
const double porcentajeCashback = 7.5;
const int monedasGanadasMes = 3;

// Edad del usuario, para la tabla de puntos por pasos (ver
// reglas_puntos.dart). IMPORTANTE: en producción esto viene de los
// datos de la póliza que provee la aseguradora, nunca autodeclarado por
// el usuario. Dejala en 45 para probar el caso general, o cambiala a 70
// para probar el caso 65+.
const int edadUsuario = 45;
const bool esUsuario65Mas = edadUsuario >= 65;

// Año de referencia para los techos reales (afecta si febrero cuenta
// 28 o 29 días). Se toma del calendario real, no se inventa.
final int _anioReferencia = DateTime.now().year;
// Techo real del año: 500 pts/día (tope diario) × días reales del año
// (365 o 366 si es bisiesto).
final int techoAnualPuntos = techoAnual(_anioReferencia);

// TECHO DIARIO ABSOLUTO (regla del proyecto): 200 pts por pasos + 300
// pts por ritmo cardíaco = 500 pts máximo que se puede ganar en un solo
// día. Ningún dato de ejemplo de un día individual puede superar esto
// (una semana, mes o año sí, porque son sumas de varios días).

// ---- Vista Semana ----
class _DiaActividad {
  const _DiaActividad(this.letra, this.puntos);

  final String letra;
  final int puntos;
}

// Lunes a domingo. "hoy" (Jueves) queda resaltado en la gráfica. Los
// puntos de cada día salen del motor de reglas real (reglas_puntos.dart):
// pasos + minutos/intensidad de ritmo cardíaco, con el tope real de 500
// pts/día ya aplicado.
final List<_DiaActividad> _actividadSemanal = [
  _DiaActividad('L', puntosTotalesDelDia(pasos: 9100, edad: edadUsuario)),
  _DiaActividad(
    'M',
    puntosTotalesDelDia(
      pasos: 12300,
      edad: edadUsuario,
      minutosCardio: 65,
      porcentajeRcmPromedio: 72,
    ),
  ),
  _DiaActividad(
    'M',
    puntosTotalesDelDia(pasos: 6800, edad: edadUsuario),
  ), // Miércoles
  _DiaActividad(
    'J', // Hoy: el mejor día de la semana, cerca del techo diario.
    puntosTotalesDelDia(
      pasos: 15000,
      edad: edadUsuario,
      minutosCardio: 95,
      porcentajeRcmPromedio: 75,
    ),
  ),
  _DiaActividad('V', puntosTotalesDelDia(pasos: 5900, edad: edadUsuario)),
  _DiaActividad(
    'S',
    puntosTotalesDelDia(
      pasos: 10800,
      edad: edadUsuario,
      minutosCardio: 65,
      porcentajeRcmPromedio: 61,
    ),
  ),
  _DiaActividad('D', puntosTotalesDelDia(pasos: 4200, edad: edadUsuario)),
];
const int _indiceHoy = 3;

// Suma real de _actividadSemanal (50+400+0+500+0+300+0).
const int puntosSemanaActual = 1250;
const int puntosSemanaAnterior = 1080;
// Techo real de la semana: 500 pts/día (tope diario) × 7 días.
final int techoPuntosSemana = techoSemanal();
const int rachaSemanas = 12;
// Últimas 8 semanas: true = se cumplió la meta esa semana.
const List<bool> rachaSemanasCumplidas = [
  true,
  true,
  true,
  false,
  true,
  true,
  true,
  true,
];
// Ritmo cardíaco de un solo entrenamiento (el último).
const int zonaLigero = 20;
const int zonaModerado = 50;
const int zonaIntenso = 30;
const int tendenciaZonaIntensa = 10;

// ---- Vista Mes ----
// El mes agrupado en semanas (una barra = una semana), igual que la
// vista Año agrupa en meses. Suma cerca de los 2,340 pts del mes.
const List<int> _actividadSemanalDelMes = [520, 680, 340, 800];
const List<String> _semanasDelMes = ['Sem 1', 'Sem 2', 'Sem 3', 'Sem 4'];
const int _semanaActualDelMes = 1; // El día 14 cae en la Semana 2

// ---- Vista Año ----
const List<String> _mesesAbrev = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', //
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];
// Suma 12,450: igual a puntosAnuales, para que quede consistente.
const List<int> _actividadAnual = [
  900, 1050, 800, 1200, 950, 1100, //
  1300, 1150, 900, 1000, 1050, 1050,
];
const int _mesActualIndice = 6; // Julio

/// Agrupa los datos que necesita una vista "agregada" (Mes o Año): meta,
/// actividad, monedas y ritmo cardíaco. Semana queda aparte porque
/// tiene elementos propios (racha, comparación semanal) que no aplican
/// en las otras dos.
class _DatosPeriodo {
  const _DatosPeriodo({
    required this.puntosActuales,
    required this.metaPuntos,
    required this.unidadMeta,
    required this.actividad,
    required this.etiquetasActividad,
    required this.indiceActual,
    required this.mostrarEjeY,
    required this.monedasGanadas,
    required this.monedasLabel,
    required this.ritmoTitulo,
    required this.zonaLigero,
    required this.zonaModerado,
    required this.zonaIntenso,
  });

  final int puntosActuales;
  final int metaPuntos;
  final String unidadMeta;
  final List<int> actividad;
  final List<String> etiquetasActividad;
  final int indiceActual;
  // true en Año: con 12 barras un número al lado de cada una satura, así
  // que se usa un eje de referencia en vez de etiquetar barra por barra.
  final bool mostrarEjeY;
  final int monedasGanadas;
  final String monedasLabel;
  final String ritmoTitulo;
  final int zonaLigero;
  final int zonaModerado;
  final int zonaIntenso;
}

// Techo real del mes: 500 pts/día × días reales de julio (31).
final int techoMensualPuntos = techoMensual(_anioReferencia, 7);

final _datosMes = _DatosPeriodo(
  puntosActuales: 2340,
  metaPuntos: techoMensualPuntos,
  unidadMeta: 'este mes',
  actividad: _actividadSemanalDelMes,
  etiquetasActividad: _semanasDelMes,
  indiceActual: _semanaActualDelMes,
  mostrarEjeY: false,
  monedasGanadas: monedasGanadasMes,
  monedasLabel: 'GANADAS ESTE MES',
  ritmoTitulo: 'Entrenamientos del mes',
  zonaLigero: 25,
  zonaModerado: 45,
  zonaIntenso: 30,
);

final _datosAnio = _DatosPeriodo(
  puntosActuales: puntosAnuales,
  metaPuntos: techoAnualPuntos,
  unidadMeta: 'este año',
  actividad: _actividadAnual,
  etiquetasActividad: _mesesAbrev,
  indiceActual: _mesActualIndice,
  mostrarEjeY: true,
  monedasGanadas: 14,
  monedasLabel: 'GANADAS ESTE AÑO',
  ritmoTitulo: 'Entrenamientos del año',
  zonaLigero: 22,
  zonaModerado: 48,
  zonaIntenso: 30,
);

/// Los tres períodos del selector. Cada uno cambia el contenido completo
/// de la pantalla (no solo la tarjeta de meta).
enum _Periodo { semana, mes, anio }

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  _Periodo _periodo = _Periodo.semana;

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
                    Text('Progreso Semanal', style: AppTheme.sectionTitle),
                    const SizedBox(height: 20),
                    _SelectorPeriodo(
                      seleccionado: _periodo,
                      onChanged: (periodo) =>
                          setState(() => _periodo = periodo),
                    ),
                    const SizedBox(height: 20),
                    ..._buildContenido(context),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const BottomNavBar(currentIndex: 1),
          ],
        ),
      ),
    );
  }

  /// Arma la lista de secciones según el período elegido. Nivel Actual y
  /// el botón de récords se repiten igual en las tres vistas.
  List<Widget> _buildContenido(BuildContext context) {
    switch (_periodo) {
      case _Periodo.semana:
        return [
          _buildMetaSemanalCard(context),
          const SizedBox(height: 20),
          _buildRecompensasConstancia(context),
          const SizedBox(height: 28),
          _buildActividadSemana(context),
          const SizedBox(height: 20),
          _buildNivelActual(context),
          const SizedBox(height: 20),
          _buildMonedas(
            context,
            ganadas: monedasGanadasMes,
            label: 'GANADAS ESTE MES',
          ),
          const SizedBox(height: 20),
          _buildRitmoCardiacoSemana(context),
          const SizedBox(height: 20),
          _buildBotonRecords(context),
        ];
      case _Periodo.mes:
        return _buildVistaAgregada(context, _datosMes);
      case _Periodo.anio:
        return _buildVistaAgregada(context, _datosAnio);
    }
  }

  List<Widget> _buildVistaAgregada(BuildContext context, _DatosPeriodo datos) {
    return [
      _buildMetaAgregada(context, datos),
      const SizedBox(height: 28),
      _buildActividadAgregada(context, datos),
      const SizedBox(height: 20),
      _buildNivelActual(context),
      const SizedBox(height: 20),
      _buildMonedas(
        context,
        ganadas: datos.monedasGanadas,
        label: datos.monedasLabel,
      ),
      const SizedBox(height: 20),
      _buildRitmoCardiacoAgregado(context, datos),
      const SizedBox(height: 20),
      _buildBotonRecords(context),
    ];
  }

  /// Tarjeta de meta semanal: puntos vs. meta, comparación con la
  /// semana pasada, barra de progreso y la racha activa. Exclusiva de
  /// la vista Semana.
  Widget _buildMetaSemanalCard(BuildContext context) {
    final progreso = puntosSemanaActual / techoPuntosSemana;

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
            '$puntosSemanaActual / $techoPuntosSemana pts esta semana',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _buildComparacionSemanal(context),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progreso.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.cardBorder,
              valueColor: const AlwaysStoppedAnimation(
                AppColors.accentSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Podés ganar hasta 500 pts por día entre pasos y ritmo cardíaco',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: AppColors.accentSecondary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Racha de $rachaSemanas semanas',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(rachaSemanasCumplidas.length, (i) {
              final cumplida = rachaSemanasCumplidas[i];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cumplida
                            ? AppColors.accentSecondary
                            : AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          _buildProgresoProximoHito(context),
        ],
      ),
    );
  }

  /// Progreso hacia el próximo hito de monedas por constancia. Si ya se
  /// alcanzaron todos los hitos definidos, no muestra nada más.
  Widget _buildProgresoProximoHito(BuildContext context) {
    final hito = proximoHito(rachaSemanas);
    if (hito == null) {
      return Text(
        '¡Alcanzaste todos los hitos de constancia! 🎉',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.accentSecondary,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final semanasFaltantes = hito.semanas - rachaSemanas;
    final progreso = rachaSemanas / hito.semanas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progreso.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.cardBorder,
            valueColor: const AlwaysStoppedAnimation(AppColors.accentSecondary),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.monetization_on,
              color: AppColors.accentSecondary,
              size: 14,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                semanasFaltantes == 1
                    ? 'Te falta 1 semana para ganar ${hito.monedas} monedas'
                    : 'Te faltan $semanasFaltantes semanas para ganar '
                          '${hito.monedas} monedas',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Tarjeta "Recompensas por constancia": los 5 hitos de racha con
  /// check verde en los ya alcanzados y en gris los pendientes.
  Widget _buildRecompensasConstancia(BuildContext context) {
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
              const Icon(
                Icons.emoji_events_outlined,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'Recompensas por constancia',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < hitosRacha.length; i++) ...[
            _buildFilaHito(context, hitosRacha[i]),
            if (i != hitosRacha.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildFilaHito(BuildContext context, HitoRacha hito) {
    final alcanzado = rachaSemanas >= hito.semanas;
    final color = alcanzado ? AppColors.accentSecondary : AppColors.textSecondary;

    return Row(
      children: [
        Icon(
          alcanzado ? Icons.check_circle : Icons.radio_button_unchecked,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${hito.semanas} semanas seguidas',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: alcanzado ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: alcanzado ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        Icon(Icons.monetization_on, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '+${hito.monedas}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// Badge chiquito con el cambio vs. la semana pasada. Una semana con
  /// menos puntos no se marca en rojo/alarma — solo un tono neutro, esto
  /// no es un castigo.
  Widget _buildComparacionSemanal(BuildContext context) {
    final cambio =
        ((puntosSemanaActual - puntosSemanaAnterior) /
                puntosSemanaAnterior *
                100)
            .round();
    final esPositivo = cambio >= 0;
    final color = esPositivo
        ? AppColors.accentSecondary
        : AppColors.textSecondary;
    final flecha = esPositivo ? '↑' : '↓';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$flecha ${cambio.abs()}% vs. semana pasada',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Tarjeta de meta para Mes/Año: puntos acumulados vs. la meta del
  /// período, con su barra de progreso. Más simple que la de Semana: acá
  /// no hay comparación ni racha.
  Widget _buildMetaAgregada(BuildContext context, _DatosPeriodo datos) {
    final progreso = datos.puntosActuales / datos.metaPuntos;

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
            '${_formatNumber(datos.puntosActuales)} / '
            '${_formatNumber(datos.metaPuntos)} pts ${datos.unidadMeta}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progreso.clamp(0.0, 1.0),
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

  /// Gráfica de actividad semanal: una barra horizontal por día, con el
  /// día actual resaltado en verde (logro del día).
  Widget _buildActividadSemana(BuildContext context) {
    final maxPuntos = _actividadSemanal
        .map((dia) => dia.puntos)
        .reduce((a, b) => a > b ? a : b);

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
                'Actividad',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'PUNTOS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          if (esUsuario65Mas) ...[
            const SizedBox(height: 6),
            Text(
              'Tus metas están adaptadas para vos',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < _actividadSemanal.length; i++)
            _buildBarraDia(
              context,
              _actividadSemanal[i],
              i == _indiceHoy,
              maxPuntos,
            ),
        ],
      ),
    );
  }

  Widget _buildBarraDia(
    BuildContext context,
    _DiaActividad dia,
    bool esHoy,
    int maxPuntos,
  ) {
    final fraccion = maxPuntos == 0 ? 0.0 : dia.puntos / maxPuntos;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              dia.letra,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraccion,
                minHeight: 12,
                backgroundColor: AppColors.cardBorder,
                valueColor: AlwaysStoppedAnimation(
                  esHoy
                      ? AppColors.accentSecondary
                      : AppColors.textSecondary.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              '${dia.puntos}',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: esHoy ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Gráfica de actividad para Mes/Año: una barra ancha por semana (Mes)
  /// o por mes (Año), con su etiqueta debajo. Las columnas se reparten
  /// todo el ancho de la tarjeta (sin huecos grandes entre ellas) y el
  /// período actual se resalta con degradado. En Mes cada barra lleva su
  /// número de puntos encima; en Año (12 barras) eso satura, así que en
  /// su lugar se usa un eje de referencia a la derecha con cuadrícula.
  Widget _buildActividadAgregada(BuildContext context, _DatosPeriodo datos) {
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
            'Actividad',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          datos.mostrarEjeY
              ? _buildBarrasConEje(context, datos)
              : _buildBarrasConNumeros(context, datos),
        ],
      ),
    );
  }

  /// Versión con el número de puntos encima de cada barra. Solo para
  /// vistas con pocas barras (Mes: 4-5 semanas) donde sí se lee bien.
  Widget _buildBarrasConNumeros(BuildContext context, _DatosPeriodo datos) {
    final maxValor = datos.actividad.reduce((a, b) => a > b ? a : b);

    Widget barra(int i) {
      final resaltada = i == datos.indiceActual;
      final numero = '${_formatNumber(datos.actividad[i])} pts';

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              resaltada
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentSecondary.withValues(
                          alpha: 0.18,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        numero,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.accentSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : Text(
                      numero,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 110,
                child: _BarraVertical(
                  valor: datos.actividad[i],
                  maxValor: maxValor,
                  resaltada: resaltada,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                datos.etiquetasActividad[i],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: resaltada
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: resaltada ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [for (var i = 0; i < datos.actividad.length; i++) barra(i)],
    );
  }

  /// Versión con eje de referencia (escala de 250 en 250) y cuadrícula
  /// sutil de fondo, en vez de un número por barra. Pensada para vistas
  /// con muchas barras (Año: 12 meses), donde solo importa a qué nivel
  /// llegó cada una.
  Widget _buildBarrasConEje(BuildContext context, _DatosPeriodo datos) {
    const chartHeight = 110.0;
    const paso = 250;
    final maxValor = datos.actividad.reduce((a, b) => a > b ? a : b);
    final escalaMax = ((maxValor / paso).ceil()) * paso;
    final escalones = [for (var v = escalaMax; v >= 0; v -= paso) v];

    Widget barra(int i) {
      final resaltada = i == datos.indiceActual;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: SizedBox(
            width: double.infinity,
            height: chartHeight,
            child: _BarraVertical(
              valor: datos.actividad[i],
              maxValor: escalaMax,
              resaltada: resaltada,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                height: chartHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final valor in escalones)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: (valor / escalaMax) * chartHeight,
                        child: Container(
                          height: 1,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.12,
                          ),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < datos.actividad.length; i++)
                          barra(i),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 34,
              height: chartHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final valor in escalones)
                    Positioned(
                      right: 0,
                      bottom: (valor / escalaMax) * chartHeight - 6,
                      child: Text(
                        _formatNumber(valor),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < datos.actividad.length; i++)
                    Expanded(
                      child: Center(
                        child: Text(
                          datos.etiquetasActividad[i],
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: i == datos.indiceActual
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: i == datos.indiceActual
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const SizedBox(width: 34),
          ],
        ),
      ],
    );
  }

  /// Nivel actual: categoría y la siguiente, barra de progreso hacia el
  /// umbral de la próxima categoría, puntos anuales y el % de cashback
  /// activo. Es información anual: igual en las tres vistas.
  Widget _buildNivelActual(BuildContext context) {
    final progreso = puntosAnuales / umbralSiguienteCategoria;

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
              const Icon(
                Icons.workspace_premium_outlined,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'Nivel Actual',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                categoriaActual.toUpperCase(),
                // Cada categoría en su propio color (dorado para Gold,
                // plateado para Silver, etc.), igual que el anillo de Home.
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.colorForTier(categoriaActual),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                categoriaSiguiente.toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.colorForTier(categoriaSiguiente),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progreso.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.cardBorder,
              valueColor: const AlwaysStoppedAnimation(
                AppColors.accentSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'PUNTOS ANUALES: ${_formatNumber(puntosAnuales)} / '
            '${_formatNumber(umbralSiguienteCategoria)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final colorTier = AppColors.colorForTier(categoriaActual);
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colorTier.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colorTier.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.percent, color: colorTier, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '$porcentajeCashback% CASHBACK ACTIVO',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorTier,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Tarjeta de monedas ganadas. Las monedas son una moneda aparte de
  /// los puntos: se gastan en Premios y vencen a los 90 días.
  Widget _buildMonedas(
    BuildContext context, {
    required int ganadas,
    required String label,
  }) {
    const coloresMonedas = [
      AppColors.accentSecondary,
      AppColors.tierGold,
      AppColors.textSecondary,
    ];

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$ganadas Monedas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(coloresMonedas.length, (i) {
                  final color = coloresMonedas[i];
                  return Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Icon(Icons.monetization_on, size: 16, color: color),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'VENCE EN 90 DÍAS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Ritmo cardíaco del último entrenamiento, por zonas de intensidad.
  /// Obligatorio: si la app pide permiso de heartRate, Apple exige
  /// mostrarle al usuario su propia gráfica de frecuencia cardíaca.
  Widget _buildRitmoCardiacoSemana(BuildContext context) {
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
              const Icon(Icons.favorite, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                'Ritmo Cardíaco',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Último Entrenamiento',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _buildZonasBarra(context, zonaLigero, zonaModerado, zonaIntenso),
          const SizedBox(height: 14),
          Text(
            'Tu tiempo en zona intensa subió $tendenciaZonaIntensa% en tus '
            'últimos 5 entrenamientos.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Ritmo cardíaco para Mes/Año: el promedio de zonas de todos los
  /// entrenamientos del período, no uno solo.
  Widget _buildRitmoCardiacoAgregado(
    BuildContext context,
    _DatosPeriodo datos,
  ) {
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
              const Icon(Icons.favorite, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                'Ritmo Cardíaco',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            datos.ritmoTitulo,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _buildZonasBarra(
            context,
            datos.zonaLigero,
            datos.zonaModerado,
            datos.zonaIntenso,
          ),
        ],
      ),
    );
  }

  Widget _buildZonasBarra(
    BuildContext context,
    int ligero,
    int moderado,
    int intenso,
  ) {
    final zonas = [
      (nombre: 'Ligero', valor: ligero, color: AppColors.textSecondary),
      (nombre: 'Moderado', valor: moderado, color: AppColors.accent),
      (nombre: 'Intenso', valor: intenso, color: AppColors.tierGold),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < zonas.length; i++) ...[
              if (i != 0) const SizedBox(width: 4),
              Expanded(
                flex: zonas[i].valor,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: zonas[i].color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final zona in zonas)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: zona.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${zona.nombre} ${zona.valor}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  /// Botón secundario (borde de acento, sin relleno) hacia la pantalla
  /// de récords personales, que todavía no existe.
  Widget _buildBotonRecords(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        // TODO: crear lib/screens/records_screen.dart y navegar ahí.
        onPressed: () {},
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ver mis récords'),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward, size: 16),
          ],
        ),
      ),
    );
  }
}

/// Una barra vertical de gráfico: crece desde abajo según [valor] sobre
/// [maxValor]. La resaltada (día/mes actual) usa verde (logro del período).
class _BarraVertical extends StatelessWidget {
  const _BarraVertical({
    required this.valor,
    required this.maxValor,
    required this.resaltada,
  });

  final int valor;
  final int maxValor;
  final bool resaltada;

  @override
  Widget build(BuildContext context) {
    final fraccion = maxValor == 0 ? 0.0 : valor / maxValor;
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: fraccion.clamp(0.03, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: resaltada
                ? null
                : AppColors.textSecondary.withValues(alpha: 0.35),
            gradient: resaltada
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.accentSecondary.withValues(alpha: 0.65),
                      AppColors.accentSecondary,
                    ],
                  )
                : null,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
              bottomLeft: Radius.circular(3),
              bottomRight: Radius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selector de período tipo "segmented control": Semana / Mes / Año.
class _SelectorPeriodo extends StatelessWidget {
  const _SelectorPeriodo({required this.seleccionado, required this.onChanged});

  final _Periodo seleccionado;
  final ValueChanged<_Periodo> onChanged;

  static const _opciones = [
    (label: 'Semana', valor: _Periodo.semana),
    (label: 'Mes', valor: _Periodo.mes),
    (label: 'Año', valor: _Periodo.anio),
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

String _formatNumber(int value) {
  final s = value.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final posFromEnd = s.length - i;
    buffer.write(s[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
