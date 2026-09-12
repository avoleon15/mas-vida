import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../reglas_puntos.dart';
import '../theme.dart';
import 'progress_ring.dart';

/// Carrusel de las etapas de pasos del día. Una tarjeta por etapa, que se
/// recorre deslizando.
///
/// Las etapas son los tramos de la tabla oficial de pasos (7.000 / 10.000
/// / 15.000+), los mismos que dibuja el anillo y con el mismo metal. Salen
/// de [cortesAros], así que no hay umbrales escritos a mano acá.
///
/// Arranca posicionado en la etapa en curso, y las tarjetas vecinas
/// asoman por el borde: es lo que le dice al usuario que hay más para
/// deslizar, sin necesitar una fila de puntitos debajo.
class StepperEtapas extends StatefulWidget {
  const StepperEtapas({super.key, required this.pasos});

  final int pasos;

  @override
  State<StepperEtapas> createState() => _StepperEtapasState();
}

class _StepperEtapasState extends State<StepperEtapas> {
  late final PageController _controlador;

  /// Página que se está mirando. Solo sirve para la háptica: no cambia
  /// cuál es la etapa real del usuario.
  late int _paginaVista;

  /// Cantidad de etapas. `cortesAros` incluye el 0, así que hay un tramo
  /// menos que cortes.
  int get _cantidad => cortesAros.length - 1;

  /// Índice del tramo en curso: 0 mientras va camino a los 7.000, 1
  /// camino a los 10.000, 2 camino a los 15.000. Al llegar al techo se
  /// queda en el último.
  int get _etapaActual {
    for (var i = 1; i < cortesAros.length; i++) {
      if (widget.pasos < cortesAros[i]) return i - 1;
    }
    return cortesAros.length - 2;
  }

  @override
  void initState() {
    super.initState();
    _paginaVista = _etapaActual;
    _controlador = PageController(
      initialPage: _etapaActual,
      // Menos de 1 para que las tarjetas de al lado asomen: eso es lo que
      // invita a deslizar.
      viewportFraction: 0.7,
    );
  }

  @override
  void didUpdateWidget(StepperEtapas anterior) {
    super.didUpdateWidget(anterior);
    // Si los pasos cambian de tramo, el carrusel se mueve solo a la etapa
    // nueva.
    if (anterior.pasos != widget.pasos && _controlador.hasClients) {
      _controlador.animateToPage(
        _etapaActual,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _alCambiarPagina(int pagina) {
    if (pagina == _paginaVista) return;
    HapticFeedback.selectionClick();
    setState(() => _paginaVista = pagina);
  }

  @override
  Widget build(BuildContext context) {
    // El alto acompaña al tamaño de letra del sistema. Con un alto fijo,
    // subir la letra desbordaba la tarjeta por abajo.
    final escala = MediaQuery.textScalerOf(context).scale(1);

    return SizedBox(
      // Compacta: toda la info entra en tres renglones, así que la
      // tarjeta no necesita más alto que esto.
      // Crece con la letra del sistema, pero sin depender de acertar el
      // número: si aun así no alcanza, el contenido se achica solo (ver
      // el FittedBox de _TarjetaEtapa).
      height: 130 * escala.clamp(1.0, 1.8),
      child: PageView.builder(
        controller: _controlador,
        itemCount: _cantidad,
        onPageChanged: _alCambiarPagina,
        padEnds: false,
        itemBuilder: (context, i) {
          final desde = cortesAros[i];
          final hasta = cortesAros[i + 1];
          final tarjeta = _TarjetaEtapa(
            numero: i + 1,
            desde: desde,
            hasta: hasta,
            // La última no tiene techo hacia arriba: son 15.000 o más.
            ultima: i == _cantidad - 1,
            pasos: widget.pasos,
            // Mismo metal que el aro de ese tramo, para que el carrusel y
            // el anillo se lean como una sola cosa.
            color: colorDelAroActual(desde),
            alcanzada: widget.pasos >= hasta,
            activa: i == _etapaActual && widget.pasos < techoAros,
          );

          // La tarjeta enfocada se ve a tamaño pleno y las de al lado un
          // poco encogidas: la jerarquía se lee antes que el color.
          return AnimatedBuilder(
            animation: _controlador,
            builder: (context, child) {
              // `page` es null hasta que el PageView mide: mientras tanto
              // se usa la página inicial.
              final pagina =
                  _controlador.hasClients && _controlador.page != null
                  ? _controlador.page!
                  : _controlador.initialPage.toDouble();
              final distancia = (pagina - i).abs().clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Transform.scale(
                  scale: 1 - distancia * 0.08,
                  child: Opacity(opacity: 1 - distancia * 0.35, child: child),
                ),
              );
            },
            child: tarjeta,
          );
        },
      ),
    );
  }
}

class _TarjetaEtapa extends StatelessWidget {
  const _TarjetaEtapa({
    required this.numero,
    required this.desde,
    required this.hasta,
    required this.ultima,
    required this.pasos,
    required this.color,
    required this.alcanzada,
    required this.activa,
  });

  final int numero;
  final int desde;
  final int hasta;
  final bool ultima;
  final int pasos;
  final Color color;
  final bool alcanzada;
  final bool activa;

  static String _miles(int valor) => TextoCentroAnillo.formatearMiles(valor);

  /// Qué tan lleno va el tramo, de 0 a 1. Solo tiene sentido en la etapa
  /// en curso.
  double get _avance {
    final largo = hasta - desde;
    if (largo <= 0) return 1;
    return ((pasos - desde) / largo).clamp(0.0, 1.0);
  }

  /// Color que manda en la tarjeta. La etapa completada va en el AZUL de
  /// marca, y la etapa en curso en el metal de su aro, para que se lea
  /// junto con el anillo.
  ///
  /// Lo único naranja que queda es el check: el naranja marca, no viste.
  Color get _acento => alcanzada ? AppColors.accent : color;

  @override
  Widget build(BuildContext context) {
    // Tres estados que se distinguen por cuatro cosas a la vez (ícono,
    // fondo, borde y texto), no solo por color: así también funcionan en
    // blanco y negro y con daltonismo.
    final fondo = alcanzada
        // Tinte de fondo, no relleno pleno: a esta escala el relleno
        // pleno tapaba el texto de puntos.
        ? AppColors.azulBruma
        : activa
        ? AppColors.card
        : AppColors.cardBorder.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: alcanzada
              ? AppColors.azulSuave
              : activa
              ? color
              : AppColors.cardBorder,
          // El borde grueso es la marca de "acá estás".
          width: activa ? 2.5 : 1.5,
        ),
        boxShadow: activa
            ? [
                // Sombra suave del metal, nunca un glow (ver CLAUDE.md).
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      // El contenido se achica hasta caber en vez de desbordar.
      //
      // Antes el alto de la tarjeta era un número tanteado y cualquier
      // combinación de pantalla angosta y letra grande lo pasaba. Así el
      // alto deja de ser una apuesta: la tarjeta mide lo que mide y lo de
      // adentro se ajusta.
      child: LayoutBuilder(
        builder: (context, restricciones) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: restricciones.maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Renglón 1: quién es esta etapa y cuánto paga.
                Row(
                  children: [
                    _Insignia(
                      numero: numero,
                      color: _acento,
                      alcanzada: alcanzada,
                      activa: activa,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ETAPA $numero',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    _Chip(
                      texto: '+${puntosPorPasos(hasta)} pts',
                      color: _acento,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Renglón 2: la meta. El número manda y la unidad lo acompaña
                // chiquita al lado, en vez de robarle un renglón entero.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        // La última etapa no tiene techo: son 15.000 o más.
                        ultima ? '${_miles(hasta)}+' : _miles(hasta),
                        maxLines: 1,
                        style: _estiloNumero(context),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'pasos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Renglón 3: el estado. Solo la etapa en curso muestra barra;
                // en las otras alcanza con una línea de texto.
                if (activa)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: _avance,
                          minHeight: 5,
                          backgroundColor: AppColors.cardBorder,
                          // Naranja, no el metal del aro: el metal es gris
                          // en la primera etapa y ahí la barra no se leía
                          // como progreso.
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Te faltan ${_miles(hasta - pasos)} pasos',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(
                        alcanzada
                            ? Icons.check_circle_rounded
                            : Icons.lock_outline_rounded,
                        size: 14,
                        // El check sí va naranja: es el detalle chico
                        // que tiene que saltar sobre el azul.
                        color: alcanzada
                            ? AppColors.accentSecondary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          alcanzada ? 'Completada' : 'Todavía no llegás acá',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: alcanzada
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Los números van en la tipografía del cuerpo (Inter) y no en la
  /// display condensada: a este tamaño, dentro de una tarjeta, se lee
  /// mucho mejor. Cifras tabulares para que "7,000" y "15,000+" ocupen lo
  /// mismo y no bailen al deslizar.
  TextStyle _estiloNumero(BuildContext context) {
    return (Theme.of(context).textTheme.headlineSmall ?? const TextStyle())
        .copyWith(
          color: alcanzada || activa
              ? AppColors.textPrimary
              : AppColors.textSecondary,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
  }
}

/// Pastilla chiquita de los puntos que paga la etapa.
class _Chip extends StatelessWidget {
  const _Chip({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// El círculo de arriba a la izquierda. Es lo primero que se mira, así
/// que carga el estado de la etapa en el ícono, no solo en el color.
class _Insignia extends StatelessWidget {
  const _Insignia({
    required this.numero,
    required this.color,
    required this.alcanzada,
    required this.activa,
  });

  final int numero;
  final Color color;
  final bool alcanzada;
  final bool activa;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        // La completada y la actual van con el círculo relleno; la
        // pendiente, apagado.
        color: alcanzada || activa
            ? color
            : AppColors.cardBorder.withValues(alpha: 0.8),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: alcanzada
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : activa
          ? Text(
              '$numero',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            )
          // Pendiente: candado. Dice "esto todavía no lo abriste" sin
          // depender de que se note la diferencia de color.
          : const Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
    );
  }
}
