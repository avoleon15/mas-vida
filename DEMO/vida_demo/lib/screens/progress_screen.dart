import 'package:flutter/material.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../rachas_recompensas.dart';
import '../reglas_puntos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';

// ============================================================
// Esta pantalla no lee JSON ni calcula puntos: los puntos ya vienen
// calculados por el backend (hoy, por los datos de prueba). El motor de
// `reglas_puntos.dart` solo aporta los techos y la tabla de niveles.
// ============================================================

// ---- Compartido entre las tres vistas (el nivel es anual) ----

/// Nivel anual numérico. El contrato v1 prohíbe Bronze/Silver/Gold/
/// Platinum.
int get nivelActual => Datos.i.resumen.nivel;

int get puntosAnuales => Datos.i.resumen.puntosAno;

/// Siguiente nivel de la tabla, o `null` si ya está en el más alto.
Nivel? get nivelSiguiente {
  final i = niveles.indexWhere((n) => n.numero == nivelActual);
  if (i < 0 || i + 1 >= niveles.length) return null;
  return niveles[i + 1];
}

/// % de cashback del nivel actual. `null` si el nivel todavía no tiene
/// definido su porcentaje (niveles 1 y 2).
double? get porcentajeCashback => nivelPorNumero(nivelActual)?.porcentajeCashback;

int get monedasGanadasMes => Datos.i.resumen.monedas.ganadasEsteMes;

/// Edad del asegurado. Viene de la póliza, NUNCA autodeclarada.
int get edadUsuario => Datos.i.perfil.edad;

/// Techo anual: lo fija el contrato en 12.000 pts, no se deriva de
/// multiplicar el techo diario por los días del año.
int get techoAnualPuntos => Datos.i.resumen.techoAnual;

// ---- Vista Semana ----
class _DiaGrafica {
  const _DiaGrafica(this.letra, this.puntos, this.dia);

  final String letra;
  final int puntos;

  /// `null` para los días de la semana que todavía no ocurrieron.
  final DiaActividad? dia;
}

const List<String> _letrasSemana = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Lunes a domingo de la semana en curso, con los puntos ya acreditados
/// que devolvió el backend. Los días que todavía no ocurrieron van en 0
/// y sin dato asociado.
List<_DiaGrafica> get _actividadSemanal {
  final dias = Datos.i.historial.semanaEnCurso;
  return [
    for (var i = 0; i < 7; i++)
      if (i < dias.length)
        _DiaGrafica(_letrasSemana[i], dias[i].puntosDia, dias[i])
      else
        _DiaGrafica(_letrasSemana[i], 0, null),
  ];
}

/// Índice de hoy dentro de la semana (0 = lunes). Se calcula sobre la
/// fecha del dato, no sobre la hora del dispositivo.
int get _indiceHoy => Datos.i.historial.hoy.fecha.weekday - 1;

int get puntosSemanaActual => Datos.i.resumen.puntosSemana;
int get puntosSemanaAnterior => Datos.i.resumen.puntosSemanaAnterior;

/// Techo real de la semana: 200 pts/día × 7 días.
int get techoPuntosSemana => techoDiario * 7;

int get rachaSemanas => Datos.i.resumen.rachaSemanas;

/// Últimas 8 semanas: true = se cumplió la meta esa semana.
List<bool> get rachaSemanasCumplidas => Datos.i.resumen.rachaHistorial;

// ---- Vista Mes ----

/// El mes agrupado en semanas (una barra = una semana), igual que la
/// vista Año agrupa en meses. Se arma sumando los días reales del
/// historial que caen en cada semana del mes en curso.
List<int> get _actividadSemanalDelMes {
  final dias = Datos.i.historial.mesEnCurso;
  final porSemana = <DateTime, int>{};
  for (final d in dias) {
    final lunes = d.fecha.subtract(Duration(days: d.fecha.weekday - 1));
    porSemana[lunes] = (porSemana[lunes] ?? 0) + d.puntosDia;
  }
  final ordenadas = porSemana.keys.toList()..sort();
  return [for (final k in ordenadas) porSemana[k]!];
}

List<String> get _semanasDelMes =>
    [for (var i = 1; i <= _actividadSemanalDelMes.length; i++) 'Sem $i'];

/// La semana en curso es siempre la última barra que tiene datos.
int get _semanaActualDelMes => _actividadSemanalDelMes.length - 1;

/// Techo real del mes: 200 pts/día × días reales del mes en curso.
int get techoMensualPuntos {
  final hoy = Datos.i.historial.hoy.fecha;
  final diasDelMes = DateTime(hoy.year, hoy.month + 1, 0).day;
  return techoDiario * diasDelMes;
}

int get puntosDelMes => Datos.i.resumen.puntosMes;

// ---- Vista Año ----
const List<String> _mesesAbrev = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', //
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

List<int> get _actividadAnual => Datos.i.resumen.actividadPorMes;
int get _mesActualIndice => Datos.i.resumen.mesActualIndice;

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

_DatosPeriodo get _datosMes => _DatosPeriodo(
  puntosActuales: puntosDelMes,
  metaPuntos: techoMensualPuntos,
  unidadMeta: 'este mes',
  actividad: _actividadSemanalDelMes,
  etiquetasActividad: _semanasDelMes,
  indiceActual: _semanaActualDelMes,
  mostrarEjeY: false,
  monedasGanadas: monedasGanadasMes,
  monedasLabel: 'GANADAS ESTE MES',
  ritmoTitulo: 'Entrenamientos del mes',
  zonaLigero: Datos.i.resumen.zonasMes.ligero,
  zonaModerado: Datos.i.resumen.zonasMes.moderado,
  zonaIntenso: Datos.i.resumen.zonasMes.intenso,
);

_DatosPeriodo get _datosAnio => _DatosPeriodo(
  puntosActuales: puntosAnuales,
  metaPuntos: techoAnualPuntos,
  unidadMeta: 'este año',
  actividad: _actividadAnual,
  etiquetasActividad: _mesesAbrev,
  indiceActual: _mesActualIndice,
  mostrarEjeY: true,
  monedasGanadas: Datos.i.resumen.monedasGanadasAnio,
  monedasLabel: 'GANADAS ESTE AÑO',
  ritmoTitulo: 'Entrenamientos del año',
  zonaLigero: Datos.i.resumen.zonasAnio.ligero,
  zonaModerado: Datos.i.resumen.zonasAnio.moderado,
  zonaIntenso: Datos.i.resumen.zonasAnio.intenso,
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
          _buildRetosSemanales(context),
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
            // El techo diario real es `techoDiario` (200). El 500 que
            // decía este texto era del modelo viejo.
            'Podés ganar hasta $techoDiario pts por día entre pasos y ritmo '
                'cardíaco',
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
  /// Retos semanales por nivel de dificultad progresiva (contrato v1):
  /// completar el reto SUBE un nivel, fallarlo BAJA uno. No es una meta
  /// de puntos y no paga puntos — el reto cumplido acuña MONEDAS.
  Widget _buildRetosSemanales(BuildContext context) {
    final retos = Datos.i.resumen.retos;

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
              const Icon(Icons.flag_outlined, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                'Reto semanal',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Nivel ${retos.nivelActual}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.accentSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            // La dificultad de cada nivel todavía no está documentada:
            // se dice, no se inventa un número.
            'La meta de este nivel todavía no está definida.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(
            'ÚLTIMAS SEMANAS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          for (final semana in retos.historial)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    semana.completado
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 15,
                    color: semana.completado
                        ? AppColors.accentSecondary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      semana.completado
                          ? 'Nivel ${semana.nivel} completado — subiste a '
                                'nivel ${semana.nivel + 1}'
                          : 'Nivel ${semana.nivel} no completado — bajaste a '
                                'nivel ${semana.nivel - 1}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

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
          // El ajuste por edad ya no vive en la tabla de pasos (que es
          // igual para todos), sino en el bonus de intensidad de 60+.
          if (edadUsuario >= 60) ...[
            const SizedBox(height: 6),
            Text(
              'Tus metas están adaptadas para vos',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < _actividadSemanal.length; i++) ...[
            _buildBarraDia(
              context,
              _actividadSemanal[i],
              i == _indiceHoy,
              maxPuntos,
            ),
            ?_buildNotaDia(context, _actividadSemanal[i].dia),
          ],
        ],
      ),
    );
  }

  Widget _buildBarraDia(
    BuildContext context,
    _DiaGrafica dia,
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

  /// Nota bajo la barra de un día cuando pasó algo que el usuario tiene
  /// que poder entender: sin permiso, dato manual, techo diario, sesión
  /// que no llegó a los 30 min, precedencia entre fuentes, revisión o
  /// reversión.
  ///
  /// Se explica LA REGLA general, no el veredicto interno del motor: el
  /// contrato v1 es explícito en no exponer por qué se descartó una
  /// muestra, porque saberlo es saber cómo evadirlo.
  Widget? _buildNotaDia(BuildContext context, DiaActividad? dia) {
    if (dia == null) return null;

    final notas = <(IconData, String)>[];

    if (dia.sinPermiso) {
      notas.add((
        Icons.lock_outline,
        'Sin permiso para leer tu actividad este día. Activalo en '
            'Ajustes → Salud.',
      ));
    }
    if (dia.esManual) {
      notas.add((
        Icons.edit_off_outlined,
        'Los pasos ingresados a mano en la app de Salud no acreditan '
            'puntos.',
      ));
    }
    if (dia.topeAplicado) {
      notas.add((
        Icons.flag_outlined,
        'Llegaste al techo de $techoDiario pts del día. Lo de más no '
            'suma, pero igual cuenta para tu racha.',
      ));
    }
    final sesion = dia.sesion;
    if (sesion != null && !sesion.cuentaParaPuntos) {
      notas.add((
        Icons.timer_outlined,
        'Tu sesión de ${sesion.duracionMin} min no llegó a los '
            '$minutosMinimosSesion minutos continuos que pide la tabla.',
      ));
    }
    if (dia.huboPrecedencia) {
      final gana = dia.fuentePrevalece;
      notas.add((
        Icons.watch_outlined,
        'Dos dispositivos reportaron pasos distintos. Se tomó '
            '${gana?.nombre ?? 'la fuente con más pasos'}, nunca la suma '
            'de ambos.',
      ));
    }
    if (dia.marcadoParaRevision) {
      notas.add((
        Icons.pending_outlined,
        'Este día quedó marcado para revisión. Tus puntos siguen '
            'acreditados mientras lo revisamos.',
      ));
    }
    final rev = dia.reversion;
    if (rev != null) {
      notas.add((
        Icons.undo,
        'Se revirtieron ${rev.puntosRevertidos} pts de este día '
            '(${rev.motivo}).',
      ));
    }

    if (notas.isEmpty) return null;

    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icono, texto) in notas)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icono, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      texto,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
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
    final siguiente = nivelSiguiente;
    // Sin siguiente nivel definido no hay umbral contra el cual medir: la
    // barra se llena con el avance hacia el techo anual, que sí existe.
    final umbral = siguiente?.puntosMinimos ?? techoAnualPuntos;
    final progreso = puntosAnuales / umbral;

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
                'NIVEL $nivelActual',
                // Cada nivel en su propio color, igual que el anillo de
                // Home.
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.colorForNivel(nivelActual),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                siguiente == null ? '—' : 'NIVEL ${siguiente.numero}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.colorForNivel(siguiente?.numero),
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
            '${_formatNumber(umbral)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          if (siguiente != null && !siguiente.definido) ...[
            const SizedBox(height: 6),
            Text(
              'El nivel ${siguiente.numero} todavía no tiene definido su '
              'rango de puntos.',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final colorNivel = AppColors.colorForNivel(nivelActual);
              final pct = porcentajeCashback;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colorNivel.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colorNivel.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      pct == null ? Icons.help_outline : Icons.percent,
                      color: colorNivel,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        // Nivel sin definir: se dice, no se inventa un %.
                        pct == null
                            ? 'CASHBACK DE ESTE NIVEL PENDIENTE DE DEFINIR'
                            : '${_formatPorcentaje(pct)}% CASHBACK ACTIVO',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorNivel,
                          fontWeight: FontWeight.w700,
                        ),
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
      AppColors.nivel3,
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
          _buildZonasBarra(context, Datos.i.resumen.zonasSemana.ligero, Datos.i.resumen.zonasSemana.moderado, Datos.i.resumen.zonasSemana.intenso),
          const SizedBox(height: 14),
          Text(
            'Tu tiempo en zona intensa subió $Datos.i.resumen.zonasSemana.tendenciaIntensa% en tus '
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
      (nombre: 'Intenso', valor: intenso, color: AppColors.nivel3),
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

/// 10.0 → "10", 7.5 → "7.5". Evita mostrar "10.0% de cashback".
String _formatPorcentaje(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

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
