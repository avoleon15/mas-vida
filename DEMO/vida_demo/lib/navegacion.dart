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
///    —Récords, Perfil, el camino de las semanas, el detalle de un
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

/// Cuánto tarda el cruce entre dos pestañas de la barra de abajo.
///
/// Corto: es un cambio de pestaña, no un viaje. Pasado un cuarto de
/// segundo se siente como que la app está pensando.
const Duration duracionCambioDePestana = Duration(milliseconds: 180);

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

/// La ruta de una pestaña: cruza con un fundido, sin deslizarse.
///
/// POR QUÉ FUNDIDO Y NO EL DESLIZAMIENTO DE SIEMPRE. Con rutas nombradas
/// a secas, cada toque en la barra de abajo empujaba una
/// `MaterialPageRoute`, que entra deslizándose DESDE LA DERECHA como
/// entra el detalle de un premio. O sea: cambiar de pestaña se veía
/// igual que entrar a una pantalla más adentro, y además había que
/// animar el deslizamiento de una pantalla entera recién construida —
/// que es el cuadro más caro que existe— así que el tirón caía justo
/// ahí. Un fundido no mueve píxeles de lugar: se nota mucho menos si el
/// primer cuadro tarda.
///
/// En iOS una barra de pestañas cambia SIN animación. Acá hay un
/// fundido corto y no un corte seco porque la app se ve sobre todo en
/// Web durante la demo, y ahí el corte se lee como un parpadeo.
Route<T> rutaDePestana<T>(Widget pantalla, RouteSettings ajustes) {
  return PageRouteBuilder<T>(
    settings: ajustes,
    transitionDuration: duracionCambioDePestana,
    reverseTransitionDuration: duracionCambioDePestana,
    // Opaca: sin esto Flutter mantiene pintada la pantalla de abajo
    // durante todo el cruce, y se pagan dos pantallas por cuadro.
    opaque: true,
    pageBuilder: (context, entra, sale) => pantalla,
    transitionsBuilder: (context, entra, sale, hijo) {
      // Con "Reducir movimiento" el cambio es seco: ahí el fundido es
      // justo lo que esa opción pide que no hagamos.
      if (MediaQuery.disableAnimationsOf(context)) return hijo;
      return FadeTransition(
        opacity: CurvedAnimation(parent: entra, curve: Curves.easeOut),
        child: hijo,
      );
    },
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
