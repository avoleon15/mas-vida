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
            color: AppColors.accent,
            fontWeight: FontWeight.w800,
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
// CADA FILTRO MUESTRA OTRA COSA (revisión de Daniel, 21 de septiembre
// de 2026). No alcanza con cambiar los números: mirar "mi actividad" de
// una semana y de un año son dos preguntas distintas, y la lista de
// entrenamientos uno por uno —que es la respuesta de la semana— en un
// año sería un rollo de cien filas que nadie lee.
//
//   SEMANA → cada ENTRENAMIENTO, con los puntos que pagó. Es el único
//            tramo donde una sesión suelta todavía se recuerda.
//   MES    → cada SEMANA del mes, con sus pasos y sus puntos. La semana
//            es la unidad en la que se mueve el rango, así que es la
//            que dice si el mes viene bien o mal.
//   AÑO    → cada MES, con sus puntos. Es lo que construye el nivel de
//            cashback, que se define por los puntos del año.
//
// Arriba de la lista, siempre, DOS CIFRAS del tramo, y también cambian.
//
// LO QUE NO VA ACÁ:
//
//   · El total de PUNTOS del período: ya está arriba, en grande, en la
//     tarjeta de Puntos totales. Acá va repartido, que es lo que el
//     total no puede decir.
//   · EL MEJOR DÍA (lo sacó Daniel). Estaba al lado del total y no
//     llevaba a ninguna parte: enterarse de que el mejor día fueron
//     12.400 pasos no dice qué hacer hoy, y en un tramo largo es un
//     récord viejo que solo se puede empeorar.
// ============================================================

/// El período que se está mirando. Lo manda la pantalla de Progreso, que
/// es la dueña del selector.
enum TramoActividad {
  semana('esta semana', 'Esta semana todavía no hay entrenamientos.'),
  mes('este mes', 'Este mes todavía no hay semanas con actividad.'),
  anio('este año', 'Este año todavía no hay meses con actividad.');

  const TramoActividad(this.cuando, this.vacio);

  /// Cómo se nombra el tramo dentro de una frase: "pasos esta semana".
  final String cuando;

  /// Qué se dice cuando no hay ni una fila que mostrar.
  final String vacio;
}

/// La actividad del período: dos cifras y el detalle que le toca al
/// tramo.
class ActividadDelPeriodo extends StatelessWidget {
  const ActividadDelPeriodo({
    super.key,
    required this.dias,
    required this.tramo,
    this.puntosPorMes = const [],
  });

  /// Los días del período, en orden. Los recorta la pantalla usando los
  /// tramos del modelo, no este widget: dónde empieza una semana en hora
  /// de Guatemala es una regla de negocio, no de presentación.
  final List<DiaActividad> dias;

  final TramoActividad tramo;

  /// Puntos de cada mes del año, de enero a diciembre.
  ///
  /// Solo se usa en el tramo AÑO, y sale del resumen anual y no de
  /// [dias] porque lo que la app guarda día por día son las últimas
  /// semanas: contando esos días, el año empezaría en julio.
  final List<int> puntosPorMes;

  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  /// Cuántas filas se listan como mucho.
  ///
  /// La sección no puede quedar más larga que el resto de la pantalla
  /// junta. Se muestran las últimas y se dice cuántas quedaron afuera,
  /// que es lo que hace que el corte no parezca un error.
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

  /// Cuántos meses del año llevan actividad.
  int get _mesesConActividad => puntosPorMes.where((p) => p > 0).length;

  /// El mes que se está mirando, tomado del ÚLTIMO día con dato.
  ///
  /// Del dato y no del reloj del teléfono: el mes que la pantalla está
  /// mostrando es el de los días que le llegaron, y cambiar la fecha del
  /// iPhone no puede cambiarle el denominador a una cifra.
  DateTime get _mesMirado => dias.isEmpty ? DateTime.now() : dias.last.fecha;

  /// Cuántos días tiene ese mes.
  ///
  /// Se calcula, nunca se escribe: septiembre tiene 30, octubre 31 y
  /// febrero 28 o 29. El día CERO del mes siguiente es el último del
  /// actual, que es la forma de preguntarlo sin tabla ni año bisiesto
  /// escrito a mano.
  int get _diasDelMes => DateTime(_mesMirado.year, _mesMirado.month + 1, 0).day;

  /// Promedio de puntos por mes con actividad.
  ///
  /// El total de puntos del año ya está arriba; lo que no estaba en
  /// ningún lado es a qué ritmo mensual se está yendo.
  int get _promedioMensual {
    final meses = _mesesConActividad;
    if (meses == 0) return 0;
    return (puntosPorMes.fold(0, (t, p) => t + p) / meses).round();
  }

  /// Las DOS cifras de este tramo.
  List<({String valor, String etiqueta})> get _cifras => switch (tramo) {
    TramoActividad.semana => [
      (valor: _milesPasos(_pasos), etiqueta: 'pasos esta semana'),
      (valor: _milesPasos(_promedioDiario), etiqueta: 'promedio por día'),
    ],
    TramoActividad.mes => [
      (valor: _milesPasos(_pasos), etiqueta: 'pasos este mes'),
      (
        // "20 de 30" y no "20" solo. Un número suelto no tiene contra
        // qué medirse: veinte días activos son casi el mes entero o dos
        // tercios de él según cuánto dure, y eso es lo que el usuario
        // quiere saber. El mes se NOMBRA para que quede claro que la
        // cuenta arranca de cero el 1: el mes que viene son días nuevos
        // y un denominador nuevo.
        valor: '$_diasConPuntos de $_diasDelMes',
        etiqueta: 'días activos de ${_meses[_mesMirado.month - 1]}',
      ),
    ],
    TramoActividad.anio => [
      (valor: '$_mesesConActividad', etiqueta: 'meses con actividad'),
      (
        // "promedio de" con todas las letras: "puntos por mes" al lado
        // de un 1.405 se leía como si cada mes hubiera pagado eso, y lo
        // que dice es a qué ritmo mensual viene el año.
        valor: _milesPasos(_promedioMensual),
        etiqueta: 'promedio de puntos por mes',
      ),
    ],
  };

  /// Las semanas del mes, de la más reciente a la más vieja.
  ///
  /// Se agrupa por el LUNES de cada día, igual que la gráfica de arriba,
  /// así que las dos cuentan las mismas semanas y las numeran igual.
  List<_Tramo> get _semanasDelMes {
    final porSemana = <DateTime, List<DiaActividad>>{};
    for (final d in dias) {
      final lunes = DateTime(
        d.fecha.year,
        d.fecha.month,
        d.fecha.day,
      ).subtract(Duration(days: d.fecha.weekday - 1));
      porSemana.putIfAbsent(lunes, () => []).add(d);
    }

    final lunes = porSemana.keys.toList()..sort();
    final tramos = <_Tramo>[];
    for (var i = lunes.length - 1; i >= 0; i--) {
      final deLaSemana = porSemana[lunes[i]]!;
      final pasos = deLaSemana.fold(0, (t, d) => t + (d.pasos ?? 0));
      final activos = deLaSemana.where((d) => d.puntosDia > 0).length;
      tramos.add(
        _Tramo(
          marca: '${i + 1}',
          titulo: 'Semana ${i + 1}',
          detalle: activos == 0
              ? '${_milesPasos(pasos)} pasos'
              : '${_milesPasos(pasos)} pasos · $activos '
                    '${activos == 1 ? 'día activo' : 'días activos'}',
          puntos: deLaSemana.fold(0, (t, d) => t + d.puntosDia),
        ),
      );
    }
    return tramos;
  }

  /// Los meses del año con actividad, del más reciente al más viejo.
  List<_Tramo> get _mesesDelAnio => [
    for (var i = puntosPorMes.length - 1; i >= 0; i--)
      if (puntosPorMes[i] > 0)
        _Tramo(
          // La inicial en el medallón y el nombre al lado: la misma
          // palabra en dos tamaños, que es lo que deja recorrer la
          // lista sin leerla entera.
          marca: _enMayuscula(_meses[i]).substring(0, 1),
          titulo: _enMayuscula(_meses[i]),
          detalle: '',
          puntos: puntosPorMes[i],
        ),
  ];

  static String _enMayuscula(String palabra) =>
      palabra[0].toUpperCase() + palabra.substring(1);

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

  /// Las filas del tramo, ya recortadas, y cuántas quedaron afuera.
  (List<Widget>, int) get _filas {
    switch (tramo) {
      case TramoActividad.semana:
        final todas = _conSesion;
        final visibles = todas.take(_tope).toList();
        return (
          [
            for (final d in visibles)
              _Entrenamiento(
                icono: _icono(d.sesion!.tipoActividad),
                titulo: _tipo(d.sesion!.tipoActividad),
                cuando: _fechaCorta(d.fecha),
                sesion: d.sesion!,
              ),
          ],
          todas.length - visibles.length,
        );

      case TramoActividad.mes:
        final todas = _semanasDelMes;
        final visibles = todas.take(_tope).toList();
        return (
          [for (final t in visibles) _FilaTramo(tramo: t)],
          todas.length - visibles.length,
        );

      case TramoActividad.anio:
        final todas = _mesesDelAnio;
        final visibles = todas.take(_tope).toList();
        return (
          [for (final t in visibles) _FilaTramo(tramo: t)],
          todas.length - visibles.length,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cifras = _cifras;
    final (filas, afuera) = _filas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En azul de marca, como los títulos de las gráficas: sin la
        // tarjeta que agrupaba la sección, el título es lo único que
        // dice dónde empieza.
        Text(
          'Tu actividad',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.dentro),
        _Tarjeta(
          children: [
            // Las dos cifras del período, lado a lado. La primera va en
            // azul de marca; la segunda, en apoyo: es lo que EXPLICA ese
            // total, no otro total con el que competir.
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
            if (filas.isEmpty) ...[
              const _Separador(),
              Text(
                tramo.vacio,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ] else
              for (final fila in filas) ...[const _Separador(), fila],
            // Cuántas quedaron afuera. Sin esto, el corte en seis se lee
            // como que no hubo más.
            if (afuera > 0) ...[
              const SizedBox(height: 14),
              Text(
                'Y $afuera más ${tramo.cuando}.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Una fila que no es un entrenamiento: una semana del mes o un mes del
/// año.
class _Tramo {
  const _Tramo({
    required this.marca,
    required this.titulo,
    required this.detalle,
    required this.puntos,
  });

  /// Lo que va adentro del medallón: el número de la semana o la inicial
  /// del mes.
  final String marca;

  final String titulo;

  /// Vacío cuando no hay nada que agregar, y entonces no se dibuja ese
  /// renglón: mejor una fila de una línea que una con un hueco.
  final String detalle;

  final int puntos;
}

/// Una semana del mes o un mes del año, con lo que pagó.
///
/// Misma forma que la fila de un entrenamiento —medallón, título,
/// detalle, chip— para que las tres vistas de "Tu actividad" se sientan
/// la misma sección y no tres pantallas distintas. Lo que cambia es qué
/// va adentro del medallón: un ícono para un entrenamiento, un número o
/// una letra para un tramo de tiempo.
class _FilaTramo extends StatelessWidget {
  const _FilaTramo({required this.tramo});

  final _Tramo tramo;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _Medallon(
        child: Text(
          tramo.marca,
          style: AppTheme.display(
            17,
          ).copyWith(color: AppColors.accent, height: 1),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tramo.titulo,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            if (tramo.detalle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                tramo.detalle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(width: 10),
      _ChipPuntos(puntos: tramo.puntos),
    ],
  );
}

/// El círculo pálido que abre cada fila.
class _Medallon extends StatelessWidget {
  const _Medallon({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    // azulBruma y no azulNiebla: desde que la sección dejó de vivir en
    // una tarjeta blanca, el medallón se apoya sobre el fondo de la
    // pantalla, y contra ese fondo el tono más pálido no se veía.
    decoration: const BoxDecoration(
      color: AppColors.azulBruma,
      shape: BoxShape.circle,
    ),
    child: child,
  );
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
        _Medallon(child: Icon(icono, size: 21, color: AppColors.accent)),
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
        // El apagado va en cardBorder: `background` es EL FONDO DE LA
        // PANTALLA, así que desde que la lista no está sobre una tarjeta
        // blanca, un chip de ese color era un chip invisible.
        color: suma ? AppColors.azulBruma : AppColors.cardBorder,
        borderRadius: BorderRadius.circular(AppRadios.pildora),
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

/// El contenedor de una lista: NO es una tarjeta.
///
/// Era una caja blanca con borde, idéntica a las otras dos de Progreso
/// (decisión de Daniel, 21 de septiembre de 2026). Una lista de
/// entrenamientos, de semanas o de lecturas del reloj es una LISTA, y en
/// iOS una lista se separa con una línea de un pelo y aire, no metiendo
/// todo adentro de una caja con contorno.
///
/// Lo que queda es el contenido apoyado sobre el fondo de la pantalla,
/// alineado con el título de arriba y con el resto de los bloques. Sin
/// el padding de 20 px, además, las filas arrancan en el mismo margen
/// que todo lo demás.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
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

/// La línea de un pelo que separa dos filas.
///
/// Medio píxel, en el azul de los bordes diluido: es lo que reemplaza al
/// borde de la tarjeta. Una línea que se nota se lee como una división;
/// una que apenas se insinúa solo ordena, que es lo que hace falta acá.
class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Divider(height: 0.5, thickness: 0.5, color: AppColors.separador),
  );
}
