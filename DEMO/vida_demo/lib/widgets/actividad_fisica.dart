import 'package:flutter/material.dart';
import '../datos/modelos.dart';
import '../theme.dart';
import 'numero_animado.dart' show milesConComa;

// ============================================================
// ACTIVIDAD FÍSICA: ritmo cardíaco del día y entrenamientos recientes.
//
// Es lo que HealthKit entrega tal cual, con el mismo formato del spike de
// Alvaro. Los bpm son datos CRUDOS: el % de FCmáx lo calcula el servidor
// con la edad de la póliza, y acá solo se muestra si vino.
// ============================================================

/// Ritmo cardíaco de hoy: promedio, mínimo y máximo.
class RitmoCardiacoHoy extends StatelessWidget {
  const RitmoCardiacoHoy({super.key, required this.dia});

  final DiaActividad dia;

  @override
  Widget build(BuildContext context) {
    final ritmo = dia.ritmo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ritmo cardíaco de hoy',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.dentro),
        _Tarjeta(
          children: ritmo == null
              ? [
                  // Sin lecturas no se inventa un promedio: se dice.
                  Text(
                    'Hoy todavía no hay lecturas de tu reloj.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ]
              : [
                  _Fila(titulo: 'Promedio', valor: '${ritmo.promedio} bpm'),
                  const _Separador(),
                  _Fila(titulo: 'Más bajo', valor: '${ritmo.minimo} bpm'),
                  const _Separador(),
                  _Fila(titulo: 'Más alto', valor: '${ritmo.maximo} bpm'),
                ],
        ),
      ],
    );
  }
}

// ============================================================
// TU ACTIVIDAD: lo que hiciste en el período que se está mirando.
//
// Reemplaza a "Entrenamientos de los últimos 7 días", que era una lista
// de texto fija a la semana: existía igual en Mes y en Año pero seguía
// contando siete días, así que cambiar el filtro no cambiaba nada abajo.
//
// Dos cosas y en este orden:
//
//   1. TRES CIFRAS del período, y CADA FILTRO TIENE LAS SUYAS. Las
//      mismas tres en los tres tramos serían tres veces la misma
//      pantalla: lo que se quiere saber de una semana (si esta semana
//      voy bien) no es lo que se quiere saber de un año (si mantuve el
//      ritmo). La primera cifra sí se repite —los pasos del tramo—,
//      porque es el ancla que dice de qué tamaño es el período.
//   2. Los ENTRENAMIENTOS, cada uno con los puntos que pagó.
//
// LO QUE NO VA ACÁ:
//
//   · El total de PUNTOS del período: ya está arriba, en grande, en la
//     tarjeta de Puntos. Lo que sí faltaba era de dónde sale cada uno, y
//     eso lo dice cada entrenamiento con su chip.
//   · EL MEJOR DÍA (lo sacó Daniel el 21 de septiembre de 2026). Estaba
//     al lado del total y no llevaba a ninguna parte: enterarse de que
//     el mejor día fueron 12.400 pasos no dice qué hacer hoy, y en un
//     tramo largo es un récord viejo que solo se puede empeorar.
// ============================================================

/// El período que se está mirando. Lo manda la pantalla de Progreso, que
/// es la dueña del selector.
enum TramoActividad {
  semana('esta semana', 'Esta semana no registraste entrenamientos.'),
  mes('este mes', 'Este mes todavía no registraste entrenamientos.'),
  anio('este año', 'Este año todavía no registraste entrenamientos.');

  const TramoActividad(this.cuando, this.vacio);

  /// Cómo se nombra el tramo dentro de una frase: "pasos esta semana".
  final String cuando;

  /// Qué se dice cuando no hubo ni un entrenamiento.
  final String vacio;
}

/// La actividad del período: pasos, mejor día y entrenamientos.
class ActividadDelPeriodo extends StatelessWidget {
  const ActividadDelPeriodo({
    super.key,
    required this.dias,
    required this.tramo,
  });

  /// Los días del período, en orden. Los recorta la pantalla usando los
  /// tramos del modelo, no este widget: dónde empieza una semana en hora
  /// de Guatemala es una regla de negocio, no de presentación.
  final List<DiaActividad> dias;

  final TramoActividad tramo;

  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  /// Cuántos entrenamientos se listan como mucho.
  ///
  /// En Año podrían ser cien: la sección quedaría más larga que el resto
  /// de la pantalla junta. Se muestran los últimos y se dice cuántos
  /// hubo en total, que es lo que hace que el corte no parezca un error.
  static const _tope = 6;

  /// Los días con sesión, del más reciente al más viejo.
  List<DiaActividad> get _conSesion =>
      dias.where((d) => d.sesion != null).toList().reversed.toList();

  /// Pasos del período. Un día sin permiso no es un día de cero pasos,
  /// pero para un total no hay nada mejor que no sumarlo.
  int get _pasos => dias.fold(0, (t, d) => t + (d.pasos ?? 0));

  /// Los días que TIENEN dato. Son el denominador de todos los
  /// promedios: dividir entre siete cuando la semana va por el miércoles
  /// daría un promedio diario que nadie reconoce como suyo.
  int get _diasConDato => dias.where((d) => d.pasos != null).length;

  /// Los días que acreditaron puntos. Es el piso de 7.000 pasos del
  /// contrato, pero no se recalcula acá: se pregunta si el servidor
  /// acreditó algo.
  int get _diasConPuntos => dias.where((d) => d.puntosDia > 0).length;

  /// Promedio de pasos por día con dato.
  int get _promedioDiario =>
      _diasConDato == 0 ? 0 : (_pasos / _diasConDato).round();

  /// Promedio de pasos por mes empezado. En Año, un total de seis
  /// dígitos no dice nada solo; el promedio mensual sí se compara contra
  /// el mes que uno tiene en la cabeza.
  int get _promedioMensual {
    final meses = dias.map((d) => '${d.fecha.year}-${d.fecha.month}').toSet();
    if (meses.isEmpty) return 0;
    return (_pasos / meses.length).round();
  }

  /// Las DOS cifras de este tramo.
  ///
  /// Dos y no tres (poda de Daniel, 21 de septiembre de 2026). Eran tres
  /// y la tercera nunca llevaba a ninguna parte: "3 de 3 días que
  /// sumaron puntos" en una semana que va por el miércoles se lee como
  /// un pleno que en realidad todavía no existe, y contar los
  /// entrenamientos del año arriba de la lista que los muestra es
  /// contarlos dos veces.
  ///
  /// La primera es la misma en los tres —los pasos del período, el ancla
  /// que dice de qué tamaño es el tramo— y la segunda cambia: en una
  /// semana importa el ritmo del día a día, en un mes cuántos días se
  /// movió, y en un año si sostuvo el ritmo mes a mes.
  List<({String valor, String etiqueta})> get _cifras => switch (tramo) {
    TramoActividad.semana => [
      (valor: _milesPasos(_pasos), etiqueta: 'pasos esta semana'),
      (valor: _milesPasos(_promedioDiario), etiqueta: 'promedio por día'),
    ],
    TramoActividad.mes => [
      (valor: _milesPasos(_pasos), etiqueta: 'pasos este mes'),
      (
        valor: '$_diasConPuntos',
        etiqueta: _diasConPuntos == 1 ? 'día activo' : 'días activos',
      ),
    ],
    TramoActividad.anio => [
      (valor: _milesPasos(_pasos), etiqueta: 'pasos este año'),
      (valor: _milesPasos(_promedioMensual), etiqueta: 'promedio por mes'),
    ],
  };

  static String _fechaCorta(DateTime f) => '${f.day} de ${_meses[f.month - 1]}';

  /// HealthKit devuelve el tipo en inglés. Se traduce acá, no en el
  /// modelo: es presentación, no dato.
  static String _tipo(String actividad) => switch (actividad.toLowerCase()) {
    'running' => 'Correr',
    'walking' => 'Caminata',
    'cycling' => 'Ciclismo',
    'swimming' => 'Natación',
    'hiit' => 'HIIT',
    'strength' || 'functionalstrengthtraining' => 'Fuerza',
    'yoga' => 'Yoga',
    _ => actividad,
  };

  /// Cada actividad con su ícono. El que no esté en la lista cae en el
  /// genérico: nunca un hueco donde debería haber un ícono.
  static IconData _icono(String actividad) => switch (actividad.toLowerCase()) {
    'running' => Icons.directions_run_rounded,
    'walking' => Icons.directions_walk_rounded,
    'cycling' => Icons.pedal_bike_rounded,
    'swimming' => Icons.pool_rounded,
    'hiit' => Icons.bolt_rounded,
    'strength' || 'functionalstrengthtraining' => Icons.fitness_center_rounded,
    'yoga' => Icons.self_improvement_rounded,
    _ => Icons.favorite_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final conSesion = _conSesion;
    final mostrados = conSesion.take(_tope).toList();
    final cifras = _cifras;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tu actividad',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.dentro),
        _Tarjeta(
          children: [
            // Las dos cifras del período, lado a lado. La primera es el
            // total de pasos y va en azul de marca; la segunda, en
            // apoyo: es lo que EXPLICA ese total, no otro total con el
            // que competir.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cifras.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Expanded(
                    child: _Cifra(
                      valor: cifras[i].valor,
                      etiqueta: cifras[i].etiqueta,
                      apagada: i > 0,
                    ),
                  ),
                ],
              ],
            ),
            if (mostrados.isEmpty) ...[
              const _Separador(),
              Text(
                tramo.vacio,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ] else
              for (var i = 0; i < mostrados.length; i++) ...[
                const _Separador(),
                _Entrenamiento(
                  icono: _icono(mostrados[i].sesion!.tipoActividad),
                  titulo: _tipo(mostrados[i].sesion!.tipoActividad),
                  cuando: _fechaCorta(mostrados[i].fecha),
                  sesion: mostrados[i].sesion!,
                ),
              ],
            // Cuántos quedaron afuera. Sin esto, el corte en seis se lee
            // como que no hubo más.
            if (conSesion.length > mostrados.length) ...[
              const SizedBox(height: 14),
              Text(
                'Y ${conSesion.length - mostrados.length} más ${tramo.cuando}.',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Miles con coma, delegando en el formateador único de la app.
String _milesPasos(int v) => milesConComa(v);

/// Una cifra del período con su rótulo debajo.
class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.valor,
    required this.etiqueta,
    this.apagada = false,
  });

  final String valor;
  final String etiqueta;
  final bool apagada;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // FittedBox: las dos cajas miden lo mismo y adentro puede caer un
      // "29,932" o un "428,581". El número se achica solo si le hace
      // falta, en vez de cortarse con puntos suspensivos.
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          valor,
          maxLines: 1,
          style: AppTheme.display(apagada ? 26 : 30).copyWith(
            color: apagada ? AppColors.azulMedio : AppColors.accent,
            height: 1,
          ),
        ),
      ),
      const SizedBox(height: 3),
      Text(
        etiqueta,
        maxLines: 2,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          height: 1.25,
        ),
      ),
    ],
  );
}

/// Un entrenamiento: qué fue, cuándo, y cuántos puntos pagó.
///
/// EL ÍCONO NO ES DECORACIÓN. La lista era cuatro renglones de texto por
/// sesión y todos empezaban igual ("Correr", "Correr", "Correr"): para
/// distinguir una de otra había que leer la fecha. Con el ícono adelante
/// —y con el tipo de actividad decidiendo cuál— la lista se recorre
/// mirando, no leyendo.
///
/// Los PUNTOS van en un chip a la derecha, en azul. No en naranja: el
/// naranja es de las monedas, y estos son puntos —la otra moneda, la que
/// no se gasta—. Confundirlas en la misma pantalla en la que hay un chip
/// de monedas sería el peor lugar para hacerlo.
class _Entrenamiento extends StatelessWidget {
  const _Entrenamiento({
    required this.icono,
    required this.titulo,
    required this.cuando,
    required this.sesion,
  });

  final IconData icono;
  final String titulo;
  final String cuando;
  final SesionIntensidad sesion;

  /// La línea de detalle: cuándo, cuánto duró y a qué ritmo.
  ///
  /// Se arma con lo que HAY. Sin pulsómetro no se escribe "· null bpm"
  /// ni se deja el punto colgando.
  String get _detalle => [
    cuando,
    '${sesion.duracionMin} min',
    if (sesion.fcPromedio != null) '${sesion.fcPromedio} bpm',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final suma = sesion.cuentaParaPuntos && sesion.puntosIntensidad > 0;
    final estiloNota = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.azulNiebla,
            shape: BoxShape.circle,
          ),
          child: Icon(icono, size: 21, color: AppColors.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(_detalle, style: estiloNota),
              // Una sesión que no acredita tiene que decir por qué, o el
              // usuario no entiende de dónde salen sus puntos.
              if (!suma)
                Text(
                  'No llegó a los 30 min continuos',
                  style: estiloNota?.copyWith(fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _ChipPuntos(puntos: suma ? sesion.puntosIntensidad : 0),
      ],
    );
  }
}

/// Los puntos que pagó un entrenamiento.
class _ChipPuntos extends StatelessWidget {
  const _ChipPuntos({required this.puntos});

  final int puntos;

  @override
  Widget build(BuildContext context) {
    final suma = puntos > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: suma ? AppColors.azulBruma : AppColors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        // Sin puntos NO se escribe "+0 pts": un cero con signo de más se
        // lee como si algo hubiera sumado nada, y lo que pasó es que
        // esta sesión no entró en la cuenta.
        suma ? '+$puntos pts' : 'Sin puntos',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: suma ? AppColors.accent : AppColors.textSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ============================================================
// Piezas compartidas
// ============================================================

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _Fila extends StatelessWidget {
  const _Fila({required this.titulo, required this.valor});

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          titulo,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
        ),
      ),
      Text(
        valor,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppColors.textSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: AppColors.cardBorder),
  );
}
