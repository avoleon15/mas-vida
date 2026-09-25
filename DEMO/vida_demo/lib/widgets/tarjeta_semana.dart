import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/modelos.dart';
import '../hora_guatemala.dart';
import '../theme.dart';
import 'cintillo_patrocinador.dart';
import 'moneda_animada.dart';
import 'patrocinio.dart';

part 'hoja_objetivo.dart';

// ============================================================
// LA TARJETA DE UNA SEMANA.
//
// Es la MISMA pieza en dos lugares: la sección de Hoy y la hoja que se
// abre al tocar un nodo del camino. Una sola implementación porque son
// literalmente el mismo contenido — si fueran dos, se desincronizan y el
// usuario ve dos versiones de su propia semana.
//
// Cuatro piezas, de arriba abajo, en orden de importancia (rediseño de
// Daniel, 24 de septiembre de 2026):
//
//   1. el BOTÓN DEL CAMINO, que además dice la semana: "Semana 3 de 10".
//      Así no hace falta entrar al camino para saber en cuál vas. En la
//      hoja del camino no hay botón y la semana es un titular.
//   2. la regla en un renglón —"Cumple los dos para ganar"— y el premio:
//      "+10" y la moneda, como en un juego
//   3. los DOS objetivos, lado a lado: número grande, meta y barra fina
//   4. en gris, cuántos van y cuándo cierran; y la marca, si la semana
//      está vendida
//
// SIN CAJAS. Todo se apoya directo sobre el fondo: lo que ordena es el
// tamaño de la letra y el aire, no los bordes. Lo único con superficie
// es el botón del camino, que es la acción más importante de la sección.
// ============================================================

String _conMiles(int v) => v.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

/// La unidad, abreviada y concordada con el número.
///
/// "1 dias" era un error visible en pantalla: la unidad venía cruda del
/// JSON y se concatenaba sin mirar la cantidad.
String _unidadCorta(String unidad, int cantidad) {
  final limpia = unidad.toLowerCase();
  if (limpia.startsWith('min')) return 'min';
  if (limpia.startsWith('paso')) return cantidad == 1 ? 'paso' : 'pasos';
  return unidad;
}

/// Cómo se dice el avance de un objetivo, en una frase: "48 de 90 min".
///
/// Es lo que escucha VoiceOver. En UNIDADES REALES, nunca en porcentaje,
/// y sin "faltan": "Faltan 42 min" se leía como una cuenta regresiva, y
/// los dos objetivos cierran juntos el domingo — eso lo dice
/// [plazoCorto], una sola vez.
///
/// Sin meta no inventa una: la tabla de metas por semana todavía no
/// existe en ninguna fuente (la define Luis).
String avanceDicho(ObjetivoSemanal objetivo) {
  if (objetivo.completo) return 'Completado';

  final meta = objetivo.meta;
  if (meta == null) return 'En curso';

  // Llegó al número pero el servidor todavía no lo dio por cumplido. No
  // se dice "90 de 90": eso se lee como completado.
  if (objetivo.progreso >= meta) return 'Casi';

  return '${_conMiles(objetivo.progreso)} de ${_conMiles(meta)} '
      '${_unidadCorta(objetivo.unidad, meta)}';
}

/// Los días de la semana, para decir cuándo cierra.
const List<String> _diasDeLaSemana = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// El domingo en que cierra [semana], en hora de Guatemala.
DateTime _cierreDe(SemanaObjetivos semana) => enHoraDeGuatemala(semana.cierra);

/// El lunes en que arranca [semana], en hora de Guatemala.
DateTime _arranqueDe(SemanaObjetivos semana) =>
    _cierreDe(semana).subtract(const Duration(days: 6));

/// "domingo 20", "lunes 21".
String _diaYNumero(DateTime fecha) =>
    '${_diasDeLaSemana[fecha.weekday - 1]} ${fecha.day}';

/// El plazo de la semana, en tres palabras.
///
/// Es lo único que se dice del calendario en toda la tarjeta. SIN LA
/// HORA: "cierran el domingo 20" no se lee como mediodía, una semana
/// termina cuando termina el domingo. La hora exacta la decide el
/// servidor (23:59:59).
///
/// En MINÚSCULA porque continúa el renglón del conteo, no lo abre.
String plazoCorto(SemanaObjetivos semana) => switch (semana.estado) {
  EstadoSemana.cerrada => 'cerró el ${_diaYNumero(_cierreDe(semana))}',
  EstadoSemana.futura => 'arranca el ${_diaYNumero(_arranqueDe(semana))}',
  // En plural: el plazo es de los dos objetivos a la vez.
  EstadoSemana.enCurso => 'cierran el ${_diaYNumero(_cierreDe(semana))}',
};

/// Abre una semana en su propia hoja.
///
/// Hoja y no pantalla: es el mismo contenido de Hoy para otra semana, y
/// se cierra empujándola hacia abajo sin perder el lugar del camino.
void mostrarHojaSemana(
  BuildContext context, {
  required SemanaObjetivos semana,
}) {
  HapticFeedback.selectionClick();
  showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => _HojaSemana(semana: semana),
  );
}

class _HojaSemana extends StatelessWidget {
  const _HojaSemana({required this.semana});

  final SemanaObjetivos semana;

  @override
  Widget build(BuildContext context) {
    // La marca de la semana se ve al ABRIR la semana —la que sea, no solo
    // la que corre—, que es el momento en que el usuario preguntó por
    // ella. Y solo si ESA semana está vendida: sin marca no se dibuja
    // nada, ni un hueco ni un cartel que anuncie la ausencia.
    final patrocinio = semana.patrocinio;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barrita de arrastre: dice que la hoja se puede empujar
            // hacia abajo antes de que el usuario lo intente.
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (patrocinio != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: CintilloPatrocinador(
                  semana: semana.numero,
                  marca: patrocinio.marca,
                  // La lista sale del repositorio, no de acá: hoy el
                  // mock repite la única foto del catálogo.
                  fotos: patrocinio.fotos,
                  fondoMarca: patrocinio.fondo,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: TarjetaSemana(
                semana: semana,
                // Sin la píldora de la marca cuando arriba están sus
                // fotos: el logo quedaría dos veces en cinco centímetros.
                conMarca: patrocinio == null,
                // Sin botón al pie: esta hoja se abre DESDE el camino.
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// La tarjeta.
// ============================================================

class TarjetaSemana extends StatelessWidget {
  const TarjetaSemana({
    super.key,
    required this.semana,
    this.totalSemanas = 0,
    this.onVerCamino,
    this.conMarca = true,
  });

  final SemanaObjetivos semana;

  /// Cuántas semanas tiene el programa, para el botón del camino. Solo
  /// hace falta cuando hay botón.
  final int totalSemanas;

  /// Qué hace el botón del camino. Null en la hoja del camino: ahí el
  /// botón no se dibuja, porque el camino ya está abierto.
  final VoidCallback? onVerCamino;

  /// False cuando la marca ya se está viendo en grande arriba de la
  /// tarjeta: el mismo logo dos veces en la misma hoja es uno de más.
  final bool conMarca;

  @override
  Widget build(BuildContext context) {
    final alCamino = onVerCamino;
    final apagada = semana.estado == EstadoSemana.futura;
    final objetivos = semana.objetivos;
    final secundario = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      color: AppColors.textSecondary,
      height: 1.35,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. LA SEMANA. En Hoy la dice el botón del camino, que es la
        // pieza que manda; en la hoja del camino no hay botón y la dice
        // un titular.
        if (alCamino != null)
          _BotonCamino(
            semana: semana.numero,
            totalSemanas: totalSemanas,
            onPressed: alCamino,
          )
        else
          Text(
            'Semana ${semana.numero}',
            style: AppTheme.display(
              26,
            ).copyWith(color: AppColors.textPrimary, height: 1.1),
          ),
        // LA MARCA, PEGADA A LA SEMANA (pedido de Daniel, 24 de septiembre
        // de 2026). Al pie de todo se leía como patrocinadora de la
        // sección entera; justo debajo de "Semana 3" y con "Esta semana"
        // en la frase se entiende que es de ESTA semana nada más.
        if (conMarca)
          if (semana.patrocinio case final p?) ...[
            const SizedBox(height: 12),
            _RenglonMarca(patrocinio: p, estado: semana.estado),
          ],
        // El cupón de la marca solo se nombra cuando YA SE GANÓ.
        if (semana.patrocinio case final p?)
          if (semana.monedasGanadas > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Ganaste ${p.cupon}',
              style: secundario?.copyWith(
                color: acentoDeMarca(p),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        const SizedBox(height: 22),
        // 2. LA REGLA DE LA SEMANA, en un renglón: hay que cumplir los
        // dos, y lo que paga. Es lo único que hace falta saber para
        // entender qué son los dos números de abajo.
        Row(
          children: [
            Expanded(child: Text(_regla(), style: secundario)),
            const SizedBox(width: 12),
            ?_premio(),
          ],
        ),
        const SizedBox(height: 14),
        // 3. LOS DOS OBJETIVOS, lado a lado, separados por una línea de
        // un pelo. Sin cajas: número grande, meta en chico y una barra.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < objetivos.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 0.5,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    color: AppColors.separador,
                  ),
                Expanded(
                  child: _Objetivo(
                    objetivo: objetivos[i],
                    semana: semana,
                    apagada: apagada,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 4. EL PIE, en gris: cuántos van y el plazo, UNA sola vez para
        // los dos. Wrap y no Row: con la letra de iOS grande, el plazo
        // baja entero al renglón de abajo.
        Wrap(
          children: [
            Text(
              apagada
                  ? 'Todavía no empieza'
                  : '${semana.cumplidos} de ${objetivos.length} objetivos',
              style: secundario,
            ),
            Text('  ·  ', style: secundario),
            Text(plazoCorto(semana), style: secundario),
          ],
        ),
      ],
    );
  }

  /// Lo que pide la semana, en cuatro palabras. En pasado cuando ya
  /// cerró.
  String _regla() => switch (semana.estado) {
    EstadoSemana.cerrada when semana.cumplida => 'Cumpliste los dos',
    EstadoSemana.cerrada => 'No se cumplieron los dos',
    _ => 'Cumple los dos para ganar',
  };

  /// "+10" con la moneda, o null si la semana no paga ni va a pagar.
  ///
  /// Una semana cerrada sin los dos no pagó, y una que paga 0 no promete
  /// nada: un "+0" sería anunciar un premio que no existe.
  Widget? _premio() {
    final m = semana.monedas;
    if (m <= 0) return null;

    final cerrada = semana.estado == EstadoSemana.cerrada;
    if (cerrada && !semana.cumplida) return null;

    return _Premio(monedas: m, cobrado: cerrada);
  }
}

/// Quién acompaña la semana: el logo y "Patrocinada por Montanos", con
/// el nombre en el color de la marca. Suelto, sin caja: es lo que la
/// alianza compró, su cara y su color, y no necesita un marco para verse.
class _RenglonMarca extends StatelessWidget {
  const _RenglonMarca({required this.patrocinio, required this.estado});

  final Patrocinio patrocinio;

  /// Para conjugar la frase: la semana en curso "la patrocina", una
  /// cerrada "la patrocinó" y una futura "la va a patrocinar".
  final EstadoSemana estado;

  String get _verbo => switch (estado) {
    EstadoSemana.enCurso => 'Esta semana la patrocina ',
    EstadoSemana.cerrada => 'Esta semana la patrocinó ',
    EstadoSemana.futura => 'Esta semana la patrocinará ',
  };

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);

    return Semantics(
      label: '$_verbo${patrocinio.marca}',
      excludeSemantics: true,
      child: Row(
        children: [
          LogoPatrocinio(patrocinio: patrocinio, tamano: 26),
          const SizedBox(width: 10),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: _verbo,
                children: [
                  TextSpan(
                    text: patrocinio.marca,
                    style: TextStyle(
                      color: acentoDeMarca(patrocinio),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              style: estilo,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// El premio de la semana.
// ============================================================

/// Llave del premio de la semana, para los tests.
const Key llaveMonedasSemana = ValueKey('monedas-semana');

/// "+10" y la moneda. Naranja porque son MONEDAS, que es el único lugar
/// donde el naranja significa algo por sí solo.
class _Premio extends StatelessWidget {
  const _Premio({required this.monedas, required this.cobrado});

  final int monedas;

  /// Si ya se acreditaron. Solo cambia lo que escucha VoiceOver: la
  /// moneda va entera en los dos casos, porque es el premio que está en
  /// juego y un "+10" junto a una moneda gris no se lee como premio.
  final bool cobrado;

  @override
  Widget build(BuildContext context) => Semantics(
    key: llaveMonedasSemana,
    label: cobrado
        ? 'Ganaste $monedas monedas'
        : 'Cumple los dos y ganas $monedas monedas',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
      decoration: BoxDecoration(
        color: AppColors.accentSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadios.pildora),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+$monedas',
            style: AppTheme.display(
              20,
            ).copyWith(color: AppColors.accentSecondary, height: 1),
          ),
          const SizedBox(width: 4),
          const MonedaAnimada(size: 22),
        ],
      ),
    ),
  );
}

// ============================================================
// Un objetivo: el número en grande y una barra fina.
// ============================================================

/// Llave de un objetivo, para agarrarlo desde un test.
Key llaveObjetivo(String id) => ValueKey('objetivo-$id');

/// El ícono de cada objetivo, por su id. Uno que no se conoce va con la
/// bandera de la sección: el objetivo se muestra igual.
IconData _iconoDe(String id) => switch (id) {
  'pasos_semana' => Icons.directions_walk_rounded,
  'minutos_entrenamiento' => Icons.timer_outlined,
  _ => Icons.flag_outlined,
};

/// El nombre corto, para la columna: "Pasos de la semana" no entra en
/// media pantalla y "de la semana" ya lo dice la sección. Uno que no se
/// conoce va con el nombre que manda el servidor.
String _nombreCorto(ObjetivoSemanal o) => switch (o.id) {
  'pasos_semana' => 'Pasos',
  'minutos_entrenamiento' => 'Entrenamiento',
  _ => o.nombre,
};

/// Un objetivo en su columna: el nombre chico arriba, el avance en
/// GRANDE, la meta debajo y una barra fina que dice de lejos cuánto
/// falta. Como las estadísticas de la app Fitness: el número es lo que
/// se mira, y todo lo demás lo explica.
///
/// No se toca y no tiene nada con forma de casilla: los objetivos los
/// cierra el SERVIDOR el domingo 23:59 con los datos de Apple Health, y
/// la primera persona que probó la app intentó tocar un círculo con un
/// check para marcarlo (prueba con usuario, 22 de septiembre de 2026).
class _Objetivo extends StatelessWidget {
  const _Objetivo({
    required this.objetivo,
    required this.semana,
    required this.apagada,
  });

  final ObjetivoSemanal objetivo;

  /// La semana del objetivo, para el detalle: su plazo y lo que paga.
  final SemanaObjetivos semana;

  /// Una semana futura no tiene avance real: la barra va vacía y el
  /// número grande es la meta, para que no parezca que ya arrancó en
  /// cero.
  final bool apagada;

  /// Cuánto se llena la barra, de 0 a 1.
  double get _lleno {
    if (objetivo.completo) return 1;
    final meta = objetivo.meta;
    if (apagada || meta == null || meta == 0) return 0;
    return (objetivo.progreso / meta).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final meta = objetivo.meta;
    final hecho = objetivo.completo;
    final chico = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      color: AppColors.textSecondary,
      height: 1.2,
    );

    // El número grande: el avance, o la meta si la semana no arrancó.
    final grande = apagada && meta != null ? meta : objetivo.progreso;
    // Lo que va debajo: contra qué se mide ese número.
    final debajo = switch (meta) {
      null => _unidadCorta(objetivo.unidad, objetivo.progreso),
      _ when apagada => '${_unidadCorta(objetivo.unidad, meta)} de meta',
      _ => 'de ${_conMiles(meta)} ${_unidadCorta(objetivo.unidad, meta)}',
    };

    // SE TOCA PARA VER EL DETALLE (pedido de Daniel, 24 de septiembre de
    // 2026): un número grande invita a tocarlo para saber más. Lo que se
    // abre es una hoja de información —cuánto llevas, cómo se cuenta y
    // cuándo se cierra—, NUNCA una casilla: el objetivo lo cierra el
    // servidor, y nada acá tiene forma de marcarse (prueba con usuario
    // del 22 de septiembre). El chevron al lado del nombre es lo que
    // dice que se abre algo.
    return Semantics(
      key: llaveObjetivo(objetivo.id),
      label: '${objetivo.nombre}: ${avanceDicho(objetivo)}',
      hint: 'Toca para ver el detalle',
      button: true,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: () =>
            mostrarDetalleObjetivo(context, objetivo: objetivo, semana: semana),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _iconoDe(objetivo.id),
                  size: 16,
                  color: AppColors.azulMedio,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _nombreCorto(objetivo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: chico?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.azulMedio,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 13,
                  color: AppColors.azulMedio,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // FittedBox: "148,300" con la letra de iOS grande no entra en
            // media pantalla, y un número partido no se lee.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _conMiles(grande),
                    maxLines: 1,
                    style: AppTheme.display(28).copyWith(
                      color: apagada
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  // El check SUELTO, en naranja: es el cuarto uso del
                  // naranja que deja CLAUDE.md. Sin círculo y sin relleno.
                  if (hecho) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.check_rounded,
                      size: 22,
                      color: AppColors.accentSecondary,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              debajo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: chico,
            ),
            // Sin meta no hay contra qué medir: no se dibuja una barra
            // que inventa un avance.
            if (meta != null) ...[
              const SizedBox(height: 12),
              _Barra(lleno: _lleno),
            ],
          ],
        ),
      ),
    );
  }
}

/// La barra fina de un objetivo: vacía en el gris de las barras, llena
/// con el degradado de las gráficas. Crece desde cero al aparecer, salvo
/// con "Reducir movimiento".
class _Barra extends StatelessWidget {
  const _Barra({required this.lleno, this.alto = 6});

  final double lleno;

  /// Grosor: 6 en la tarjeta, más gruesa en el detalle.
  final double alto;

  @override
  Widget build(BuildContext context) {
    final quieta = MediaQuery.disableAnimationsOf(context);

    // A lo ancho de la columna: sin el ancho explícito, el riel medía lo
    // mismo que el relleno y la barra parecía siempre completa.
    return Container(
      width: double.infinity,
      height: alto,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cardBorder,
        borderRadius: BorderRadius.circular(AppRadios.pildora),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: quieta ? lleno : 0, end: lleno),
        duration: quieta ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: v,
          heightFactor: 1,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.circular(AppRadios.pildora),
              ),
              gradient: LinearGradient(
                colors: [AppColors.azulMedio, AppColors.accent],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// El botón del camino.
// ============================================================

/// Llave del botón que abre el camino, para agarrarlo desde un test.
const Key llaveBotonCamino = ValueKey('ver-camino-semanas');

/// La entrada al camino, y LA pieza de la sección: va primera y es la
/// única con color de marca y sombra.
///
/// Además es la que dice en qué semana vas —"Semana 3 de 10"—, así que
/// no hace falta entrar al camino para saberlo, y la semana no necesita
/// una etiqueta aparte. Sin dibujos adentro: el texto y la flecha
/// alcanzan.
class _BotonCamino extends StatelessWidget {
  const _BotonCamino({
    required this.semana,
    required this.totalSemanas,
    required this.onPressed,
  });

  final int semana;
  final int totalSemanas;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final deCuantas = totalSemanas > 0 ? ' de $totalSemanas' : '';

    // CupertinoButton y no un GestureDetector: trae gratis el atenuado
    // al presionar que un usuario de iPhone ya conoce (ver CLAUDE.md).
    return Semantics(
      button: true,
      label: 'Semana $semana$deCuantas. Ver tu camino',
      excludeSemantics: true,
      child: CupertinoButton(
        key: llaveBotonCamino,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        onPressed: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadios.tarjeta),
            // Un degradado apenas perceptible, del azul de marca hacia
            // abajo a la derecha: es lo que lo hace verse como una pieza
            // con volumen y no como un rectángulo pintado.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(AppColors.accent, AppColors.azulMedio, 0.22)!,
                AppColors.accent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Semana $semana',
                        children: [
                          TextSpan(
                            text: deCuantas,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.display(
                        24,
                      ).copyWith(color: Colors.white, height: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ver tu camino',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(
                  CupertinoIcons.arrow_right,
                  size: 19,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
