import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../hora_guatemala.dart';
import '../theme.dart';
import 'hoja_vida.dart';
import 'moneda_animada.dart';

part 'hoja_objetivo.dart';

// ============================================================
// LA TARJETA DE UNA SEMANA.
//
// Es la MISMA pieza en dos lugares: la semana en curso en Hoy y cada
// card de la pantalla de las semanas. Una sola implementación porque son
// literalmente el mismo contenido — si fueran dos, se desincronizan y el
// usuario ve dos versiones de su propia semana.
//
// De arriba abajo:
//
//   1. la semana de titular ("Semana 7"), si se pide: en Hoy y en las
//      cards la dice la pieza de arriba
//   2. si la semana todavía no arranca, el aviso BLOQUEADA: un candado
//      y "Todavía no empieza" en grande, en gris frío, y los objetivos a
//      media luz (pedido de Daniel, 2 de octubre de 2026)
//   3. los DOS objetivos, desplegados uno debajo del otro. Cada uno en
//      un renglón con un lavado de azul: el nombre y lo que paga ("+5"
//      y la moneda), el número en grande y una BARRA a lo ancho. Sin
//      círculos: el anillo de pasos de Hoy es el único de la app
//   4. lo que se le pegue debajo (en Hoy, el premio de la marca)
//   5. el plazo con día, número, mes y hora: "Esta semana termina el
//      domingo 4 de octubre a las 11:59 PM"
//
// Los renglones van PLANOS: un lavado de color sin sombra.
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
  if (limpia.startsWith('entrenamiento') || limpia.startsWith('workout')) {
    return cantidad == 1 ? 'entrenamiento' : 'entrenamientos';
  }
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

/// El lunes en que arranca [semana]: seis días antes del domingo en que
/// cierra. Se resta sobre el instante y la fecha se lee después en hora
/// de Guatemala, nunca dos veces.
DateTime _arranqueDe(SemanaObjetivos semana) =>
    semana.cierra.subtract(const Duration(days: 6));

/// La hora de cierre, como se dice en Guatemala. La semana la cierra el
/// SERVIDOR el domingo a las 23:59:59; el teléfono solo la nombra.
const String horaDeCierre = '11:59 PM';

/// El plazo de la semana, con día, número y mes: "termina el domingo 4
/// de octubre a las 11:59 PM". En MINÚSCULA porque continúa una frase.
///
/// Las fechas se leen SIEMPRE en hora de Guatemala: alguien de viaje ve
/// el mismo cierre que todos.
String plazoCorto(SemanaObjetivos semana) => switch (semana.estado) {
  EstadoSemana.cerrada => 'cerró el ${fechaConDia(semana.cierra)}',
  EstadoSemana.futura => 'arranca el ${fechaConDia(_arranqueDe(semana))}',
  EstadoSemana.enCurso =>
    'termina el ${fechaConDia(semana.cierra)} a las $horaDeCierre',
};

// ============================================================
// La tarjeta.
// ============================================================

class TarjetaSemana extends StatelessWidget {
  const TarjetaSemana({
    super.key,
    required this.semana,
    this.conTitulo = true,
    this.debajoDeLosObjetivos,
  });

  final SemanaObjetivos semana;

  /// False en Hoy y en las cards: ahí la semana ya la dice la pieza de
  /// arriba, y "Semana 3" dos veces seguidas es una de más.
  final bool conTitulo;

  /// Lo que va PEGADO al segundo objetivo, antes del plazo: en Hoy, el
  /// premio de la marca (pedido de Daniel, 2 de octubre de 2026: con aire
  /// en medio se veía como un aviso aparte).
  final Widget? debajoDeLosObjetivos;

  @override
  Widget build(BuildContext context) {
    final futura = semana.estado == EstadoSemana.futura;
    final objetivos = semana.objetivos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. LA SEMANA, de titular.
        if (conTitulo) ...[
          Text(
            'Semana ${semana.numero}',
            style: AppTheme.display(
              26,
            ).copyWith(color: AppColors.textPrimary, height: 1.1),
          ),
          const SizedBox(height: 18),
        ],
        // 2. UNA SEMANA FUTURA ESTÁ BLOQUEADA, y se tiene que ver de un
        // vistazo: el aviso arriba y los objetivos apagados debajo.
        if (futura) ...[
          _TodaviaNoEmpieza(semana: semana),
          const SizedBox(height: 10),
        ],
        // 3. LOS DOS OBJETIVOS, uno debajo del otro.
        for (var i = 0; i < objetivos.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _Objetivo(objetivo: objetivos[i], semana: semana, apagada: futura),
        ],
        if (debajoDeLosObjetivos case final d?) ...[
          const SizedBox(height: 10),
          d,
        ],
        // 4. EL PLAZO, una sola vez para los dos. En una semana futura no
        // va: el aviso de arriba ya dice cuándo arranca.
        if (!futura) ...[const SizedBox(height: 12), _Plazo(semana: semana)],
      ],
    );
  }
}

/// El renglón del plazo, al pie: un reloj y la frase.
///
/// En curso: "Esta semana termina el domingo 4 de octubre a las 11:59
/// PM". Cerrada: cuántos objetivos se cumplieron y cuándo cerró.
class _Plazo extends StatelessWidget {
  const _Plazo({required this.semana});

  final SemanaObjetivos semana;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      color: AppColors.textSecondary,
      height: 1.35,
    );
    final enCurso = semana.estado == EstadoSemana.enCurso;
    final texto = enCurso
        ? 'Esta semana ${plazoCorto(semana)}'
        : '${semana.cumplidos} de ${semana.objetivos.length} objetivos'
              '  ·  ${plazoCorto(semana)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            enCurso ? CupertinoIcons.clock : CupertinoIcons.flag,
            size: 15,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(texto, style: estilo)),
      ],
    );
  }
}

/// Llave del aviso de una semana que todavía no empieza.
const Key llaveTodaviaNoEmpieza = ValueKey('todavia-no-empieza');

/// "Todavía no empieza" en grande, con un candado: la semana está
/// BLOQUEADA. Gris frío y no azul (pedido de Daniel, 2 de octubre de
/// 2026): en azul pálido se leía como un renglón más de la semana, y lo
/// que tiene que decir es que todavía no se puede jugar.
class _TodaviaNoEmpieza extends StatelessWidget {
  const _TodaviaNoEmpieza({required this.semana});

  final SemanaObjetivos semana;

  @override
  Widget build(BuildContext context) {
    final abre = 'Se abre el ${fechaConDia(_arranqueDe(semana))}';
    return Semantics(
      key: llaveTodaviaNoEmpieza,
      label: 'Todavía no empieza. $abre',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
        decoration: BoxDecoration(
          color: AppColors.cardBorder,
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadios.pildora),
              ),
              child: const Icon(
                CupertinoIcons.lock_fill,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Todavía no empieza',
                    style: AppTheme.display(
                      19,
                    ).copyWith(color: AppColors.textPrimary, height: 1.15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    abre,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
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
}

// ============================================================
// El premio de la semana.
// ============================================================

/// Llave del premio de un objetivo, para los tests.
Key llaveMonedasObjetivo(String id) => ValueKey('monedas-objetivo-$id');

/// "+5" y la moneda. Naranja porque son MONEDAS, que es el único lugar
/// donde el naranja significa algo por sí solo.
class _Premio extends StatelessWidget {
  const _Premio({
    super.key,
    required this.monedas,
    required this.cobrado,
    this.chico = false,
  });

  final int monedas;

  /// Si ya se acreditaron. Solo cambia lo que escucha VoiceOver.
  final bool cobrado;

  /// La versión del renglón del objetivo, más chica que la del detalle.
  final bool chico;

  @override
  Widget build(BuildContext context) => Semantics(
    label: cobrado ? 'Ganaste $monedas monedas' : 'Paga $monedas monedas',
    excludeSemantics: true,
    child: Container(
      padding: chico
          ? const EdgeInsets.fromLTRB(9, 3, 6, 3)
          : const EdgeInsets.fromLTRB(12, 5, 8, 5),
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
              chico ? 15 : 20,
            ).copyWith(color: AppColors.accentSecondary, height: 1),
          ),
          const SizedBox(width: 4),
          MonedaAnimada(size: chico ? 17 : 22),
        ],
      ),
    ),
  );
}

// ============================================================
// Un objetivo: su renglón con el número en grande y una barra.
// ============================================================

/// Llave de un objetivo, para agarrarlo desde un test.
Key llaveObjetivo(String id) => ValueKey('objetivo-$id');

/// El ícono de cada objetivo, por su id. Uno que no se conoce va con la
/// bandera de la sección: el objetivo se muestra igual.
IconData iconoDeObjetivo(String id) => switch (id) {
  'pasos_semana' => Icons.directions_walk_rounded,
  // El segundo objetivo es la CANTIDAD de workouts de la semana
  // (contrato, demo 1), no los minutos.
  'workouts_semana' => Icons.fitness_center_rounded,
  _ => Icons.flag_outlined,
};

/// El nombre corto: "Pasos de la semana" sobra, "de la semana" ya lo
/// dice la sección. Uno que no se conoce va con el nombre del servidor.
String _nombreCorto(ObjetivoSemanal o) => switch (o.id) {
  'pasos_semana' => 'Pasos',
  'workouts_semana' => 'Entrenamientos',
  _ => o.nombre,
};

/// Un objetivo en su renglón, como una tarjeta de la app Fitness pero
/// PLANA (un lavado de azul, sin sombra):
///
///   [ícono] Pasos ›                      +5 🪙
///   41,200 ✓                de 40,000 pasos
///   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
///
/// SIN CÍRCULOS (pedido de Daniel, 2 de octubre de 2026): el anillo de
/// pasos de Hoy es el único círculo de avance de la app. Una barra a lo
/// ancho dice de lejos cuánto falta y ocupa menos.
///
/// No se marca y no tiene nada con forma de casilla: los objetivos los
/// cierra el SERVIDOR el domingo a las 11:59 PM con los datos de Apple
/// Health (prueba con usuario, 22 de septiembre de 2026). Tocarlo abre
/// el detalle.
class _Objetivo extends StatelessWidget {
  const _Objetivo({
    required this.objetivo,
    required this.semana,
    required this.apagada,
  });

  final ObjetivoSemanal objetivo;

  /// La semana del objetivo, para el detalle: su plazo y lo que paga.
  final SemanaObjetivos semana;

  /// Una semana futura está bloqueada: el renglón va apagado, y el número
  /// grande es la meta, para que no parezca que ya arrancó.
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
    final tinta = apagada ? AppColors.textSecondary : AppColors.azulMedio;

    // El número grande: el avance, o la meta si la semana no arrancó.
    final grande = apagada && meta != null ? meta : objetivo.progreso;
    // Lo que va a la derecha: contra qué se mide ese número.
    final contra = switch (meta) {
      null => _unidadCorta(objetivo.unidad, objetivo.progreso),
      _ when apagada => '${_unidadCorta(objetivo.unidad, meta)} de meta',
      _ => 'de ${_conMiles(meta)} ${_unidadCorta(objetivo.unidad, meta)}',
    };

    final renglon = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        // Un lavado de azul que se aclara hacia la derecha: le da color
        // sin levantarlo. Bloqueada, un tono parejo.
        gradient: LinearGradient(
          colors: apagada
              ? [AppColors.azulNiebla, AppColors.azulNiebla]
              : [AppColors.azulBruma, AppColors.azulNiebla],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // El nombre, y a la derecha lo que paga.
          Row(
            children: [
              Icon(iconoDeObjetivo(objetivo.id), size: 17, color: tinta),
              const SizedBox(width: 6),
              // Expanded y no Flexible + Spacer: con los dos, el espacio
              // libre se partía a medias y la pastilla de las monedas
              // quedaba más a la izquierda en "Pasos" que en
              // "Entrenamiento". Así queda pegada al borde en los dos.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _nombreCorto(objetivo),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: chico?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tinta,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(CupertinoIcons.chevron_right, size: 12, color: tinta),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Lo que paga ESTE objetivo. Si la semana cerró sin
              // cumplirlo, ya no paga y no se promete nada.
              if (_paga)
                _Premio(
                  key: llaveMonedasObjetivo(objetivo.id),
                  monedas: objetivo.monedas,
                  cobrado: semana.estado == EstadoSemana.cerrada,
                  chico: true,
                ),
            ],
          ),
          const SizedBox(height: 8),
          // El número en grande y, a la derecha, contra qué se mide.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // FittedBox: "148,300" con la letra de iOS grande no
              // entra, y un número partido no se lee.
              Flexible(
                child: FittedBox(
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
                      // El check SUELTO, en naranja: el cuarto uso del
                      // naranja que deja CLAUDE.md. Sin círculo.
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
              ),
              const SizedBox(width: 10),
              // Flexible: "de 1 entrenamiento" con la letra grande de iOS
              // no entraba al lado del número.
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    contra,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: chico,
                  ),
                ),
              ),
            ],
          ),
          // Sin meta no hay contra qué medir: no se dibuja una barra
          // que inventa un avance.
          if (meta != null) ...[
            const SizedBox(height: 10),
            _Barra(lleno: _lleno, fondo: Colors.white),
          ],
        ],
      ),
    );

    return Semantics(
      key: llaveObjetivo(objetivo.id),
      label: '${objetivo.nombre}: ${avanceDicho(objetivo)}$_premioDicho',
      hint: 'Toca para ver el detalle',
      button: true,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        onPressed: () =>
            mostrarDetalleObjetivo(context, objetivo: objetivo, semana: semana),
        // Bloqueada, todo el renglón a media luz: se ve la meta que viene,
        // pero se nota que todavía no se juega.
        child: apagada ? Opacity(opacity: 0.55, child: renglon) : renglon,
      ),
    );
  }

  /// Lo que paga, para VoiceOver: el renglón excluye la semántica de lo
  /// que lleva adentro, así que la pastilla no se escucharía sola.
  String get _premioDicho {
    if (!_paga) return '';
    return semana.estado == EstadoSemana.cerrada
        ? '. Ganaste ${objetivo.monedas} monedas'
        : '. Paga ${objetivo.monedas} monedas';
  }

  bool get _paga =>
      objetivo.monedas > 0 &&
      !(semana.estado == EstadoSemana.cerrada && !objetivo.completo);
}

/// La barra fina de un objetivo: vacía en el gris de las barras, llena
/// con el degradado de las gráficas. Crece desde cero al aparecer, salvo
/// con "Reducir movimiento".
class _Barra extends StatelessWidget {
  const _Barra({
    required this.lleno,
    this.alto = 6,
    this.fondo = AppColors.cardBorder,
  });

  final double lleno;

  /// El riel vacío. Blanco sobre el lavado azul del renglón: ahí el gris
  /// de las barras no se distinguía del fondo.
  final Color fondo;

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
        color: fondo,
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
