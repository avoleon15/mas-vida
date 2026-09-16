import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../datos/fuente_datos.dart';

// ============================================================
// JALAR PARA REFRESCAR, CON LA CRUZ DE LA MARCA.
//
// Es el CupertinoSliverRefreshControl de siempre — el gesto, el rebote y
// el momento en que dispara son los de iOS, no una imitación — pero con
// la cruz de +Vida en lugar del spinner del sistema.
//
// Sirve para las cinco pantallas: refresca los datos UNA vez y todas se
// redibujan solas, porque escuchan `datosRecargados`.
// ============================================================

/// Ruta del latido. Es la cruz sola, cuadrada y chica.
///
/// NO se usa acá `cargando.json`: ese mide 600×300 y a lo ancho de un
/// iPhone daría un indicador de casi 200 px de alto.
const String _rutaLatido = 'assets/lottie/latido.json';

/// Un latido completo. Es la duración real del archivo (72 cuadros a 60
/// fps), escrita acá porque el controlador la necesita.
const Duration _duracionLatido = Duration(milliseconds: 1200);

/// Cuánto dura como MÍNIMO un refresco.
///
/// Un latido entero. Hoy los datos salen de los JSON de assets/mock/ y
/// vuelven en milisegundos: sin este piso la cruz aparecería y se iría a
/// mitad del primer latido, que se lee como algo roto y no como algo que
/// terminó.
///
/// OJO cuando entre el backend real: ahí la recarga va a tardar sola y
/// esto pasa a ser tiempo regalado. Se va a querer bajar o sacar.
const Duration _minimoRefresco = Duration(milliseconds: 1200);

/// Lado de la cruz dentro del indicador.
const double _ladoCruz = 44;

/// Alto de la franja que queda abierta mientras refresca.
const double _altoIndicador = 64;

/// Cuánto hay que jalar para que dispare.
const double _distanciaGatillo = 100;

/// La física que necesita cualquier scroll que lleve un [RefrescoVida].
///
/// `AlwaysScrollable` no es opcional: sin eso, una lista más corta que la
/// pantalla no se puede jalar, y el gesto queda muerto justo en el caso
/// donde el usuario más sospecha que faltan datos (un filtro de Premios
/// que deja dos resultados).
const ScrollPhysics fisicaConRefresco = BouncingScrollPhysics(
  parent: AlwaysScrollableScrollPhysics(),
);

/// Jalar para refrescar. Va como primer sliver de un [CustomScrollView].
class RefrescoVida extends StatelessWidget {
  const RefrescoVida({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverRefreshControl(
      refreshTriggerPullDistance: _distanciaGatillo,
      refreshIndicatorExtent: _altoIndicador,
      onRefresh: () async {
        // Las dos cosas en paralelo, no una después de la otra: el
        // refresco dura lo que tarde la MÁS LENTA, así que hoy manda el
        // mínimo y el día que el backend tarde más, manda la recarga.
        await Future.wait([refrescarDatos(), Future.delayed(_minimoRefresco)]);
      },
      builder: (context, modo, jalado, distanciaGatillo, altoIndicador) =>
          _CruzLatiendo(
            modo: modo,
            jalado: jalado,
            distanciaGatillo: distanciaGatillo,
            altoIndicador: altoIndicador,
          ),
    );
  }
}

/// La cruz que reacciona al gesto.
///
/// Es Stateful por dos cosas que un builder suelto no puede: el
/// controlador del Lottie, y acordarse del modo anterior para no repetir
/// la vibración en cada cuadro del arrastre.
class _CruzLatiendo extends StatefulWidget {
  const _CruzLatiendo({
    required this.modo,
    required this.jalado,
    required this.distanciaGatillo,
    required this.altoIndicador,
  });

  final RefreshIndicatorMode modo;
  final double jalado;
  final double distanciaGatillo;
  final double altoIndicador;

  @override
  State<_CruzLatiendo> createState() => _CruzLatiendoState();
}

class _CruzLatiendoState extends State<_CruzLatiendo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(vsync: this, duration: _duracionLatido);
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_CruzLatiendo anterior) {
    super.didUpdateWidget(anterior);

    // La vibración va en el CAMBIO a `armed`, no mientras el modo es
    // `armed`. Este builder corre en cada cuadro del arrastre: sin
    // comparar contra el modo anterior, el teléfono vibraría sesenta
    // veces por segundo mientras el dedo sigue abajo.
    if (widget.modo == RefreshIndicatorMode.armed &&
        anterior.modo != RefreshIndicatorMode.armed) {
      HapticFeedback.lightImpact();
    }

    _acomodarAnimacion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _acomodarAnimacion();
  }

  void _acomodarAnimacion() {
    // Con "Reducir movimiento" activo la cruz se muestra quieta, igual
    // que la moneda: latir sin parar es justo lo que esa opción pide que
    // no hagamos.
    final quieta = MediaQuery.disableAnimationsOf(context);

    // El latido y el giro arrancan al SOLTAR, no mientras se jala. Que
    // la cruz esté quieta hasta ese momento es lo que hace sentir que el
    // gesto respondió: si ya venía moviéndose, soltar no cambia nada.
    //
    // `done` también sigue en movimiento: la franja se está cerrando y
    // frenar el giro justo ahí se ve como un tirón.
    final enMovimiento =
        widget.modo == RefreshIndicatorMode.refresh ||
        widget.modo == RefreshIndicatorMode.done;

    if (enMovimiento && !quieta) {
      if (!_controlador.isAnimating) _controlador.repeat();
    } else {
      _controlador.stop();
      _controlador.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cuánto se avanzó hacia el disparo, de 0 a 1.
    final avance = widget.distanciaGatillo == 0
        ? 0.0
        : (widget.jalado / widget.distanciaGatillo).clamp(0.0, 1.0);

    final double opacidad;
    final double escala;
    switch (widget.modo) {
      case RefreshIndicatorMode.drag:
        // Todavía no dispara: la cruz asoma y crece con el dedo. Nunca
        // desde cero, porque una cruz de 0 px no se ve venir.
        opacidad = avance;
        escala = 0.6 + 0.4 * avance;
      case RefreshIndicatorMode.armed:
      case RefreshIndicatorMode.refresh:
        opacidad = 1;
        escala = 1;
      case RefreshIndicatorMode.done:
        // La franja se está cerrando y la cruz se va con ella.
        opacidad = widget.altoIndicador == 0
            ? 0.0
            : (widget.jalado / widget.altoIndicador).clamp(0.0, 1.0);
        escala = 1;
      case RefreshIndicatorMode.inactive:
        opacidad = 0;
        escala = 1;
    }

    if (opacidad == 0) return const SizedBox.shrink();

    return Center(
      child: Opacity(
        opacity: opacidad,
        child: Transform.scale(
          scale: escala,
          // La cruz GIRA mientras recarga, además de latir.
          //
          // Con solo el latido no se leía como "está cargando": un pulso
          // en el lugar puede ser cualquier cosa, mientras que algo que
          // da vueltas es lo que todo el mundo ya asocia con esperar.
          //
          // Va atado al MISMO controlador que el latido, así que da una
          // vuelta entera por cada latido y los dos movimientos quedan
          // sincronizados en vez de pelearse. Y como el controlador está
          // en 0 mientras se jala, la cruz no gira hasta que se suelta.
          child: RotationTransition(
            turns: _controlador,
            child: RepaintBoundary(
              child: Lottie.asset(
                _rutaLatido,
                controller: _controlador,
                width: _ladoCruz,
                height: _ladoCruz,
                // El controlador manda, no la duración que trae el archivo.
                animate: false,
                // Si el archivo faltara, el refresco no puede quedarse sin
                // indicador: cae al spinner de iOS de siempre.
                errorBuilder: (context, error, stack) =>
                    const CupertinoActivityIndicator(radius: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
