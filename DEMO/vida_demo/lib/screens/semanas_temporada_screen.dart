import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../hora_guatemala.dart';
import '../navegacion.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/chip_monedas.dart';
import '../widgets/despliegue.dart';
import '../widgets/hoja_vida.dart';
import '../widgets/moneda_animada.dart';
import '../widgets/patrocinio.dart';
import '../widgets/premio_semana.dart';
import '../widgets/tarjeta_semana.dart';

// ============================================================
// LAS SEMANAS DE LA TEMPORADA.
//
// Se abre desde el botón "Ver las 13 semanas" de Hoy. Una CARD por
// semana, con sus dos objetivos y cuánto lleva de cada uno, y se pasa
// de una a otra deslizando de lado.
//
// ARRIBA, "Temporada 3" en grande y el saldo de monedas a la derecha.
// Tocar el saldo abre la temporada en tres datos: monedas ganadas en
// ella, semanas completas (los dos objetivos) y cuándo vencen.
//
// LA CARD OCUPA TODO EL ALTO (pedido de Daniel, 2 de octubre de 2026).
// Arriba, la cabecera en el azul de marca —el estado, la semana con su
// número grande de marca de agua y el logo si está vendida—; en blanco,
// los objetivos; y al pie, estirado hasta abajo, el carrusel del premio
// si hay marca, o lo que paga la semana si no. Ninguna card queda con un
// hueco blanco, y sin marca nunca se anuncia la ausencia: el pie habla
// de las monedas, no de que falte un patrocinador.
//
// QUE SE ENTIENDA QUE SE DESLIZA. Tres señales a la vez:
//   · las cards de los costados ASOMAN por el borde, más chicas y
//     apagadas;
//   · debajo, una fila de puntos con el de la semana que se mira
//     alargado;
//   · al abrir, la card se mueve sola un poquito, como invitando.
// ============================================================

/// Abre las semanas de [objetivos].
void abrirSemanasDeLaTemporada(
  BuildContext context,
  ObjetivosSemana objetivos,
) {
  Navigator.of(
    context,
  ).push(rutaPesada<void>(SemanasTemporadaScreen(objetivos: objetivos)));
}

/// Llave de la card de la semana [numero], para los tests.
Key llaveCardSemana(int numero) => ValueKey('card-semana-$numero');

/// Llave del carrusel, para los tests.
const Key llaveCarruselSemanas = ValueKey('carrusel-semanas');

class SemanasTemporadaScreen extends StatefulWidget {
  const SemanasTemporadaScreen({super.key, required this.objetivos});

  final ObjetivosSemana objetivos;

  @override
  State<SemanasTemporadaScreen> createState() => _SemanasTemporadaScreenState();
}

class _SemanasTemporadaScreenState extends State<SemanasTemporadaScreen> {
  late final PageController _paginas;
  late int _vista;

  /// La espera antes de la invitación a deslizar. Se cancela al salir.
  Timer? _espera;

  List<SemanaObjetivos> get _semanas => widget.objetivos.semanas;

  /// La semana en curso, o la última cerrada si la temporada terminó.
  int get _inicial {
    final enCurso = _semanas.indexWhere(
      (s) => s.estado == EstadoSemana.enCurso,
    );
    if (enCurso >= 0) return enCurso;
    final cerrada = _semanas.lastIndexWhere(
      (s) => s.estado == EstadoSemana.cerrada,
    );
    return cerrada >= 0 ? cerrada : 0;
  }

  @override
  void initState() {
    super.initState();
    _vista = _inicial;
    // Menos de 1: las cards de los costados asoman por el borde. Es lo
    // que dice "hay más para los lados" sin un cartel.
    _paginas = PageController(initialPage: _vista, viewportFraction: 0.86);
    WidgetsBinding.instance.addPostFrameCallback((_) => _invitarADeslizar());
  }

  /// La card se corre sola un poquito hacia la siguiente y vuelve: es la
  /// forma de enseñar el gesto sin escribirlo. Una sola vez, y nunca con
  /// "Reducir movimiento".
  void _invitarADeslizar() {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    if (!_paginas.hasClients || _vista >= _semanas.length - 1) return;
    _espera = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted || !_paginas.hasClients) return;
      final origen = _paginas.offset;
      await _paginas.animateTo(
        origen + 46,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
      if (!mounted || !_paginas.hasClients) return;
      await _paginas.animateTo(
        origen,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
      );
    });
  }

  @override
  void dispose() {
    _espera?.cancel();
    _paginas.dispose();
    super.dispose();
  }

  void _alCambiar(int i) {
    HapticFeedback.selectionClick();
    setState(() => _vista = i);
  }

  @override
  Widget build(BuildContext context) {
    final temporada = widget.objetivos.temporada;
    final total = _semanas.length;

    return Scaffold(
      body: _QuietaAlSalir(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: AppHeader(showBackButton: true),
              ),
              // EL TÍTULO, EN GRANDE, y el saldo a la derecha: tocarlo
              // cuenta la temporada en tres datos.
              Despliegue(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              temporada == null
                                  ? 'Tus semanas'
                                  : 'Temporada ${temporada.numero}',
                              style: AppTheme.display(30).copyWith(
                                color: AppColors.textPrimary,
                                height: 1.1,
                              ),
                            ),
                            if (temporada != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Hasta el ${diaYMes(temporada.cierra)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.dentro),
                      ChipMonedas(
                        key: llaveChipTemporada,
                        cantidad: saldoMonedas,
                        onTap: () =>
                            mostrarHojaTemporada(context, widget.objetivos),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // LA CARD OCUPA TODO EL ALTO (pedido de Daniel, 2 de octubre
              // de 2026): el resumen de abajo se fue a la hoja del saldo, y
              // el pie de cada card —el premio o lo que paga— se estira
              // hasta abajo.
              Expanded(
                child: Despliegue(
                  orden: 1,
                  child: PageView.builder(
                    key: llaveCarruselSemanas,
                    controller: _paginas,
                    itemCount: total,
                    onPageChanged: _alCambiar,
                    clipBehavior: Clip.none,
                    itemBuilder: (context, i) => AnimatedBuilder(
                      animation: _paginas,
                      builder: (context, child) {
                        // La card enfocada a tamaño pleno y las de al lado
                        // un poco encogidas y apagadas.
                        final pagina =
                            _paginas.hasClients &&
                                _paginas.position.haveDimensions
                            ? _paginas.page ?? _vista.toDouble()
                            : _vista.toDouble();
                        final distancia = (pagina - i).abs().clamp(0.0, 1.0);
                        return Transform.scale(
                          scale: 1 - distancia * 0.06,
                          child: Opacity(
                            opacity: 1 - distancia * 0.45,
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        // Abajo deja lugar para la sombra de la card.
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 14),
                        // Solo la card que se mira se anima. Cada moneda es un
                        // Lottie que gira sin parar, y con las vecinas
                        // girando también —y a media transparencia— la
                        // pantalla se repintaba entera en cada cuadro y se
                        // trababa.
                        child: TickerMode(
                          enabled: i == _vista,
                          child: RepaintBoundary(
                            // Arriba de su página, con su alto natural.
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: _CardSemana(
                                semana: _semanas[i],
                                total: total,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _Puntos(total: total, actual: _vista),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// Congela la pantalla mientras se va: al tocar la flecha de volver, la
/// transición mueve una imagen QUIETA y no una pantalla llena de
/// monedas girando y un carrusel en marcha. Con todo eso animándose
/// durante la salida la app se trababa y la pantalla se veía a medio
/// pintar, como transparente (pedido de Daniel, 2 de octubre de 2026).
class _QuietaAlSalir extends StatefulWidget {
  const _QuietaAlSalir({required this.child});

  final Widget child;

  @override
  State<_QuietaAlSalir> createState() => _QuietaAlSalirState();
}

class _QuietaAlSalirState extends State<_QuietaAlSalir> {
  Animation<double>? _ruta;
  bool _saliendo = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ruta = ModalRoute.of(context)?.animation;
    if (ruta == _ruta) return;
    _ruta?.removeStatusListener(_alCambiar);
    _ruta = ruta?..addStatusListener(_alCambiar);
  }

  void _alCambiar(AnimationStatus estado) {
    final saliendo = estado == AnimationStatus.reverse;
    if (saliendo != _saliendo && mounted) {
      setState(() => _saliendo = saliendo);
    }
  }

  @override
  void dispose() {
    _ruta?.removeStatusListener(_alCambiar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: !_saliendo,
    child: RepaintBoundary(child: widget.child),
  );
}

// ============================================================
// La hoja de la temporada, que abre el saldo.
// ============================================================

/// Las monedas ganadas en la temporada en curso: la suma de los lotes que
/// todavía no vencen. Todos vencen juntos al cerrar la temporada.
int monedasDeLaTemporada() =>
    Datos.i.resumen.monedas.lotes.fold(0, (suma, l) => suma + l.cantidad);

/// Llave del chip de monedas de la temporada, para los tests.
const Key llaveChipTemporada = ValueKey('chip-temporada');

/// Llave de la hoja de la temporada, para los tests.
const Key llaveHojaTemporada = ValueKey('hoja-temporada');

/// Abre la temporada en tres datos: cuántas monedas ganaste en ella,
/// cuántas semanas completaste (los dos objetivos) y cuándo vencen.
void mostrarHojaTemporada(BuildContext context, ObjetivosSemana objetivos) {
  mostrarHojaVida<void>(
    context,
    hoja: (_) => _HojaTemporada(objetivos: objetivos),
  );
}

class _HojaTemporada extends StatelessWidget {
  const _HojaTemporada({required this.objetivos});

  final ObjetivosSemana objetivos;

  @override
  Widget build(BuildContext context) {
    final semanas = objetivos.semanas;
    final completas = semanas
        .where((s) => s.estado == EstadoSemana.cerrada && s.cumplida)
        .length;
    final cerradas = semanas
        .where((s) => s.estado == EstadoSemana.cerrada)
        .length;
    final temporada = objetivos.temporada;
    final tema = Theme.of(context).textTheme;

    return HojaVida(
      key: llaveHojaTemporada,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            temporada == null
                ? 'Tu temporada'
                : 'Tu temporada ${temporada.numero}',
            style: AppTheme.display(
              24,
            ).copyWith(color: AppColors.textPrimary, height: 1.1),
          ),
          const SizedBox(height: 4),
          Text(
            'Lo que llevas en estas ${semanas.length} semanas.',
            style: tema.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _DatoTemporada(
            icono: const MonedaAnimada(size: 26),
            // Las de los lotes vivos: al empezar la temporada el saldo se
            // reinicia y DESPUÉS se paga la semana que cerró, así que esas
            // monedas también son de esta temporada (contrato, "Monedas y
            // seasons"). Sumar solo las semanas cerradas de acá las perdía.
            valor: '${monedasDeLaTemporada()}',
            etiqueta: 'monedas ganadas esta temporada',
          ),
          const SizedBox(height: 10),
          _DatoTemporada(
            icono: const Icon(
              Icons.check_rounded,
              size: 24,
              color: AppColors.accentSecondary,
            ),
            valor: '$completas',
            apoyo: cerradas == 0 ? null : 'de $cerradas',
            etiqueta: completas == 1
                ? 'semana completa, con los dos objetivos'
                : 'semanas completas, con los dos objetivos',
          ),
          if (temporada != null) ...[
            const SizedBox(height: 10),
            _DatoTemporada(
              icono: const Icon(
                CupertinoIcons.calendar,
                size: 24,
                color: AppColors.accent,
              ),
              valor: diaYMes(temporada.cierra),
              etiqueta:
                  'vencen tus monedas, el ${fechaConDia(temporada.cierra)} '
                  'a las $horaDeCierre. Úsalas antes en Premios',
            ),
          ],
          const SizedBox(height: 24),
          CupertinoButton.filled(
            borderRadius: BorderRadius.circular(AppRadios.pildora),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

/// Un dato de la temporada en su renglón: el ícono, el número en grande
/// y qué es, en una línea.
class _DatoTemporada extends StatelessWidget {
  const _DatoTemporada({
    required this.icono,
    required this.valor,
    required this.etiqueta,
    this.apoyo,
  });

  final Widget icono;
  final String valor;
  final String etiqueta;
  final String? apoyo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        gradient: const LinearGradient(
          colors: [AppColors.azulBruma, AppColors.azulNiebla],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadios.pildora),
            ),
            child: icono,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // Encoge si no entra: "13 de diciembre" es largo.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          valor,
                          style: AppTheme.display(
                            24,
                          ).copyWith(color: AppColors.textPrimary, height: 1.1),
                        ),
                      ),
                    ),
                    if (apoyo != null) ...[
                      const SizedBox(width: 5),
                      Text(
                        apoyo!,
                        style: tema.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  etiqueta,
                  style: tema.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una semana en su card: la cabecera azul y, en blanco, los objetivos.
class _CardSemana extends StatelessWidget {
  const _CardSemana({required this.semana, required this.total});

  final SemanaObjetivos semana;
  final int total;

  String get _estado => switch (semana.estado) {
    EstadoSemana.enCurso => 'ESTA SEMANA',
    EstadoSemana.cerrada when semana.cumplida => 'COMPLETADA',
    EstadoSemana.cerrada => 'CERRADA',
    EstadoSemana.futura => 'PRÓXIMAMENTE',
  };

  @override
  Widget build(BuildContext context) {
    final futura = semana.estado == EstadoSemana.futura;
    final completada = semana.estado == EstadoSemana.cerrada && semana.cumplida;
    final patrocinio = semana.patrocinio;

    return Container(
      key: llaveCardSemana(semana.numero),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        // Una sombra larga y suave del azul de marca: la card flota sobre
        // el fondo sin necesitar un borde.
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- LA CABECERA, EN EL AZUL DE MARCA ----
          Container(
            decoration: BoxDecoration(
              // Las que todavía no empiezan, en un azul más claro: se
              // ven, pero no se están jugando.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: futura
                    ? [AppColors.azulMedio, AppColors.nivel3]
                    : [AppColors.accent, AppColors.azulSombra],
              ),
            ),
            child: Stack(
              children: [
                // El número de la semana, enorme y casi transparente, de
                // marca de agua: le da carácter sin agregar información.
                Positioned(
                  right: -8,
                  bottom: -34,
                  child: Text(
                    '${semana.numero}',
                    style: AppTheme.display(140).copyWith(
                      color: Colors.white.withValues(alpha: 0.07),
                      height: 1,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _estado,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.75,
                                        ),
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.4,
                                      ),
                                ),
                                // El check naranja suelto sobre el azul:
                                // cuarto uso del naranja de CLAUDE.md.
                                if (completada) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: AppColors.accentSecondary,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                text: 'Semana ${semana.numero}',
                                children: [
                                  TextSpan(
                                    text: ' de $total',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              style: AppTheme.display(
                                26,
                              ).copyWith(color: Colors.white, height: 1.1),
                            ),
                          ],
                        ),
                      ),
                      // La marca, en grande: es lo que la alianza compró.
                      // Sin marca no se dibuja nada.
                      if (patrocinio != null) ...[
                        const SizedBox(width: 12),
                        LogoPatrocinio(patrocinio: patrocinio, tamano: 52),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ---- LOS OBJETIVOS Y, AL PIE, EL PREMIO O LO QUE PAGA ----
          // El pie es una franja BAJA (pedido de Daniel, 2 de octubre de
          // 2026: estirado hasta abajo, el carrusel pesaba más que la
          // semana). La card mide lo que tiene adentro; en un teléfono
          // chico lo que no entra se recorta abajo, nunca se scrollea.
          Flexible(
            child: CustomScrollView(
              shrinkWrap: true,
              // Nunca el scroll "primario": ese lo comparte el carrusel
              // de las semanas, y engancharse a él lo rompe.
              primary: false,
              // SIN SCROLL VERTICAL (pedido de Daniel, 2 de octubre de
              // 2026): la pantalla solo se mueve de lado. Lo que no
              // entra es el pie, y ese se esconde solo.
              physics: const NeverScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  sliver: SliverToBoxAdapter(
                    child: TarjetaSemana(semana: semana, conTitulo: false),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  sliver: SliverToBoxAdapter(
                    // El premio trae su propio alto: la foto y, debajo,
                    // lo que se gana.
                    child: patrocinio != null
                        ? PremioSemana(semana: semana)
                        : SizedBox(
                            height: altoPieDeSemana,
                            child: _LoQuePaga(semana: semana),
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
}

/// Alto del pie de cada card —el carrusel del premio o lo que paga—.
/// Bajo a propósito: acompaña a la semana, no compite con ella.
const double altoPieDeSemana = 118;

/// El pie de una semana SIN marca: las monedas que paga, en grande,
/// con tres monedas apiladas al costado. Mide lo mismo que el carrusel
/// del premio, para que todas las cards se vean hermanas.
class _LoQuePaga extends StatelessWidget {
  const _LoQuePaga({required this.semana});

  final SemanaObjetivos semana;

  @override
  Widget build(BuildContext context) {
    final cerrada = semana.estado == EstadoSemana.cerrada;
    final monedas = cerrada ? semana.monedasGanadas : semana.monedas;
    final rotulo = switch (semana.estado) {
      EstadoSemana.cerrada when monedas == 0 => 'ESTA VEZ NO SUMÓ',
      EstadoSemana.cerrada => 'GANASTE',
      EstadoSemana.enCurso => 'ESTA SEMANA PAGA',
      EstadoSemana.futura => 'VA A PAGAR',
    };

    return Semantics(
      label: '${rotulo.toLowerCase()} $monedas monedas',
      excludeSemantics: true,
      child: SizedBox.expand(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadios.tarjeta),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.azulBruma, AppColors.azulNiebla],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      rotulo,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.azulMedio,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$monedas',
                            style: AppTheme.display(
                              40,
                            ).copyWith(color: AppColors.accent, height: 1),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            monedas == 1 ? 'moneda' : 'monedas',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Tres monedas apiladas: el naranja que se permite, porque
              // son monedas.
              const SizedBox(
                width: 76,
                height: 64,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: MonedaAnimada(size: 34),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 6,
                      child: MonedaAnimada(size: 30),
                    ),
                    Positioned(
                      left: 20,
                      top: 0,
                      child: MonedaAnimada(size: 40),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La fila de puntos de abajo: uno por semana, el de la que se mira
/// alargado. Con trece semanas los puntos son chicos y juntos.
class _Puntos extends StatelessWidget {
  const _Puntos({required this.total, required this.actual});

  final int total;
  final int actual;

  @override
  Widget build(BuildContext context) {
    final quieto = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Estás viendo la semana ${actual + 1} de $total',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: quieto
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == actual ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == actual ? AppColors.accent : AppColors.azulSuave,
                borderRadius: BorderRadius.circular(AppRadios.pildora),
              ),
            ),
        ],
      ),
    );
  }
}
