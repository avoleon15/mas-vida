import 'package:flutter/widgets.dart';

// ============================================================
// CÓMO ENTRA EL CONTENIDO DE UNA PANTALLA.
//
// Cambiar de pestaña es INMEDIATO, como en iOS (ver `navegacion.dart`).
// Lo que se anima es el contenido de la pantalla que llega: cada bloque
// sube unos pocos píxeles y aparece, uno detrás del otro, de arriba
// abajo. Así la pantalla se "despliega" en vez de cruzarse con la de
// antes —el fundido de la pantalla entera dejaba ver las dos encimadas,
// y eso es lo que se veía transparente (pedido de Daniel, 2 de octubre
// de 2026)—.
//
// Una sola duración y una sola curva para toda la app: si cada pantalla
// elige la suya, la app se mueve de cinco maneras.
//
// Sin Timer: el retraso de cada bloque es un tramo vacío al principio
// de su propia animación. Un Timer pendiente al cerrar la pantalla deja
// trabajo colgado (y revienta los tests).
//
// Con "Reducir movimiento" todo aparece quieto y de una vez.
// ============================================================

/// Lo que tarda UN bloque en entrar.
const Duration _duracionBloque = Duration(milliseconds: 520);

/// Lo que espera cada bloque respecto del anterior.
const int _pasoMs = 65;

/// Más allá de este orden ya no se espera más: una pantalla larga no
/// puede tardar un segundo en terminar de aparecer.
const int _ordenMaximo = 7;

/// Cuánto sube cada bloque al entrar.
const double _subida = 18;

/// Un bloque que entra subiendo y apareciendo, después de [orden] pasos.
class Despliegue extends StatefulWidget {
  const Despliegue({super.key, required this.child, this.orden = 0});

  final Widget child;
  final int orden;

  @override
  State<Despliegue> createState() => _DespliegueState();
}

class _DespliegueState extends State<Despliegue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reloj;
  late final Animation<double> _avance;
  bool _arranco = false;

  @override
  void initState() {
    super.initState();
    final espera = widget.orden.clamp(0, _ordenMaximo) * _pasoMs;
    final total = espera + _duracionBloque.inMilliseconds;
    _reloj = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    _avance = CurvedAnimation(
      parent: _reloj,
      curve: Interval(espera / total, 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arranco) return;
    _arranco = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _reloj.value = 1;
    } else {
      _reloj.forward();
    }
  }

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  /// La MISMA forma de árbol de principio a fin. Quitar el fundido al
  /// terminar cambiaba la estructura y volvía a montar lo de adentro: un
  /// carrusel se reconstruía de cero y quedaba con dos scrolls pegados a
  /// su controlador.
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _avance,
    child: AnimatedBuilder(
      animation: _avance,
      child: widget.child,
      builder: (context, hijo) => Transform.translate(
        offset: Offset(0, (1 - _avance.value) * _subida),
        child: hijo,
      ),
    ),
  );
}

/// Envuelve cada bloque de [hijos] en un [Despliegue], en orden.
///
/// Los espaciadores (`SizedBox` sin hijo) pasan tal cual y no cuentan
/// como un paso: si contaran, el ritmo dependería de cuánto aire hay
/// entre los bloques.
List<Widget> desplegar(List<Widget> hijos, {int desde = 0}) {
  var orden = desde;
  return [
    for (final h in hijos)
      if (h is SizedBox && h.child == null)
        h
      else
        Despliegue(orden: orden++, child: h),
  ];
}
