import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ============================================================
// CÓMO SE MUEVE LA APP: EL SCROLL Y LOS CAMBIOS DE PANTALLA.
//
// Las dos cosas viven acá y no repartidas por pantalla. Es a propósito:
// si cada pantalla elige su propia física y su propia transición, la app
// se mueve de cinco maneras distintas y eso se siente como que algo está
// trabado, aunque ninguna pantalla sola esté mal.
// ============================================================

/// El comportamiento de cualquier scroll de la app, sin excepción.
///
/// Resuelve dos cosas que se notaban como "va trabada":
///
/// 1. **La física.** Las cinco pantallas de la barra de abajo pasaban
///    `fisicaConRefresco` (rebote de iOS) a mano, pero las de adentro
///    —Récords, Perfil, las semanas de la temporada, el detalle de un
///    premio— no pasaban ninguna. Sin física explícita, Flutter usa la
///    del sistema, y fuera de iOS eso es `ClampingScrollPhysics`: el
///    scroll FRENA EN SECO contra el borde en vez de rebotar. Media app
///    rebotaba y media se clavaba, que es exactamente la sensación de
///    que algo se traba. Acá se fija el rebote para todas, en todas las
///    plataformas, y ninguna pantalla nueva tiene que acordarse.
///
/// 2. **El mouse.** En Web, Flutter NO deja arrastrar con el mouse por
///    defecto: solo rueda y barra. Probando la demo en Chrome eso se
///    siente como una app que no responde al gesto. `dragDevices` lo
///    habilita.
class ComportamientoVida extends MaterialScrollBehavior {
  const ComportamientoVida();

  /// `RangeMaintaining` adentro y no `AlwaysScrollable`: lo segundo haría
  /// scrollear listas más cortas que la pantalla en TODA la app. Eso lo
  /// necesitan solo las pantallas que llevan "jalar para refrescar", y
  /// esas ya lo piden ellas con `fisicaConRefresco`.
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: RangeMaintainingScrollPhysics());

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };
}

/// Cuánto tarda el cruce entre dos pestañas: NADA.
///
/// Antes era un fundido de 180 ms de la pantalla entera. Durante ese
/// cruce se veían las dos pantallas encimadas, una a media opacidad
/// sobre la otra, y eso se leía como una app transparente o trabada
/// (pedido de Daniel, 2 de octubre de 2026). Ahora la pestaña cambia de
/// una, como en iOS, y lo que se anima es el CONTENIDO de la que llega
/// (`despliegue.dart`): la barra de abajo y el encabezado no se mueven.
const Duration duracionCambioDePestana = Duration.zero;

/// Las cinco rutas de la barra de abajo.
///
/// Se listan acá porque son las únicas que cruzan con fundido en vez de
/// entrar deslizándose: son HERMANAS, no una adentro de la otra.
const Set<String> rutasDePestana = {
  '/home',
  '/progress',
  '/social',
  '/premios',
  '/mi-plan',
};

/// La ruta de una pestaña: cambia de una, sin cruce.
///
/// Las pestañas son HERMANAS, no una adentro de la otra: no entran
/// deslizándose como el detalle de un premio. Y no se funden: el fundido
/// dejaba ver dos pantallas encimadas. El movimiento lo pone el contenido
/// de cada pantalla al desplegarse.
Route<T> rutaDePestana<T>(Widget pantalla, RouteSettings ajustes) {
  return PageRouteBuilder<T>(
    settings: ajustes,
    transitionDuration: duracionCambioDePestana,
    reverseTransitionDuration: duracionCambioDePestana,
    opaque: true,
    pageBuilder: (context, entra, sale) => pantalla,
  );
}

/// La ruta de una pantalla de adentro: entra deslizándose, como iOS.
///
/// Récords, Perfil, el detalle de un premio y el canje SÍ son un nivel
/// más adentro, así que el deslizamiento dice la verdad — y trae gratis
/// el gesto de volver arrastrando desde el borde izquierdo, que un
/// usuario de iPhone ya tiene en el dedo.
Route<T> rutaInterna<T>(Widget pantalla, RouteSettings ajustes) {
  return CupertinoPageRoute<T>(
    settings: ajustes,
    builder: (context) => pantalla,
  );
}

/// La ruta de una pantalla PESADA de adentro (las semanas de la
/// temporada: fotos, un carrusel y monedas animadas).
///
/// Entra deslizándose desde la derecha, como iOS. Al VOLVER, la pantalla
/// se convierte en una imagen quieta y lo que se desliza es esa imagen:
/// con la `CupertinoPageRoute` cada cuadro repintaba las dos pantallas
/// enteras, la de atrás corrida y sombreada, y la vuelta se trababa y se
/// veía a medio pintar (pedido de Daniel, 2 de octubre de 2026). La de
/// atrás no se mueve ni se oscurece: no hay nada transparente.
Route<T> rutaPesada<T>(Widget pantalla) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    opaque: true,
    pageBuilder: (context, entra, sale) => pantalla,
    transitionsBuilder: (context, entra, sale, hijo) {
      if (MediaQuery.disableAnimationsOf(context)) return hijo;
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: entra,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            ),
        child: _FotoAlSalir(animacion: entra, child: hijo),
      );
    },
  );
}

/// Mientras la ruta se va, [child] se pinta como una imagen quieta.
class _FotoAlSalir extends StatefulWidget {
  const _FotoAlSalir({required this.animacion, required this.child});

  final Animation<double> animacion;
  final Widget child;

  @override
  State<_FotoAlSalir> createState() => _FotoAlSalirState();
}

class _FotoAlSalirState extends State<_FotoAlSalir> {
  final SnapshotController _foto = SnapshotController();

  @override
  void initState() {
    super.initState();
    widget.animacion.addStatusListener(_alCambiar);
  }

  void _alCambiar(AnimationStatus estado) {
    _foto.allowSnapshotting = estado == AnimationStatus.reverse;
  }

  @override
  void dispose() {
    widget.animacion.removeStatusListener(_alCambiar);
    _foto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SnapshotWidget(
    controller: _foto,
    // Si algo de adentro no se puede fotografiar, se pinta normal en vez
    // de fallar.
    mode: SnapshotMode.permissive,
    child: widget.child,
  );
}

/// Lleva a Mi Plan desde cualquier lado: una pestaña, Perfil o el
/// detalle de un premio. Es donde vive "Agregar póliza" (pedido de
/// Daniel, 8 de octubre de 2026): los demás botones que la ofrecían
/// mandan acá, y el usuario elige ahí.
///
/// Vacía la pila, igual que la barra de abajo: Mi Plan es una pestaña,
/// no una pantalla más adentro.
void irAMiPlan(BuildContext context) {
  Navigator.of(context).pushNamedAndRemoveUntil('/mi-plan', (_) => false);
}
