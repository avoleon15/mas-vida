import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

// ============================================================
// BOTÓN CON RELIEVE.
//
// Es el botón de cssbuttons.io que pidió Daniel, traducido a Flutter y
// pintado con el azul de marca en vez del rojo del original.
//
// Tiene tres capas apiladas, igual que el CSS:
//
//   sombra  -> el bulto oscuro de abajo, que se corre al presionar
//   canto   -> el borde lateral en degradado, lo que le da el grosor
//   frente  -> la cara de arriba, que baja hasta tocar el canto
//
// En reposo el frente está levantado 4px sobre el canto. Al presionar
// baja a 2px: el botón se hunde de verdad en lugar de solo cambiar de
// color.
//
// Los tiempos salen del CSS original: 34ms para hundirse (instantáneo,
// tiene que sentirse pegado al dedo) y 250ms con rebote para volver.
// ============================================================

class BotonRelieve extends StatefulWidget {
  const BotonRelieve({
    super.key,
    required this.label,
    required this.onPressed,
    this.icono,
    this.color = AppColors.accent,
    this.anchoCompleto = false,
    this.compacto = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icono;

  /// El color de la cara. El canto y la sombra se derivan de él, para que
  /// el botón funcione en cualquier color de la paleta.
  final Color color;

  final bool anchoCompleto;

  /// Versión chica, para cuando va al lado de un título.
  final bool compacto;

  @override
  State<BotonRelieve> createState() => _BotonRelieveState();
}

class _BotonRelieveState extends State<BotonRelieve> {
  bool _presionado = false;

  /// Cuánto está levantada la cara sobre el canto.
  double get _altura => _presionado ? 2 : 4;

  /// Cuánto asoma la sombra por abajo.
  double get _sombra => _presionado ? 1 : 2;

  @override
  Widget build(BuildContext context) {
    // El canto es el mismo color pero más oscuro, y con un degradado
    // horizontal: los extremos más oscuros son los que hacen leer la
    // pieza como un volumen y no como dos rectángulos.
    final cantoOscuro = Color.lerp(widget.color, Colors.black, 0.55)!;
    final cantoClaro = Color.lerp(widget.color, Colors.black, 0.28)!;

    final alto = widget.compacto ? 34.0 : 46.0;
    final horizontal = widget.compacto ? 14.0 : 24.0;

    // La línea base donde se apoya el canto. El frente sube desde acá y
    // la sombra baja: por eso la caja mide un poco más que el botón.
    const base = 5.0;
    const colchon = 3.0;

    final duracion = Duration(milliseconds: _presionado ? 34 : 250);
    final curva = _presionado ? Curves.linear : Curves.easeOutBack;

    // La CARA va sin `Positioned`, y eso no es un detalle de estilo: un
    // Stack cuyos hijos son todos `Positioned` no tiene tamaño propio y
    // colapsa a cero de ancho. La cara es la que mide el botón; el canto
    // y la sombra se estiran detrás de ella.
    final cara = AnimatedPadding(
      duration: duracion,
      curve: curva,
      padding: EdgeInsets.only(
        top: base - _altura,
        // Lo que la cara sube por arriba lo devuelve por abajo, para que
        // la altura total no cambie al presionar y el botón no empuje a
        // lo que tiene al lado.
        bottom: _altura + colchon,
      ),
      child: Container(
        height: alto,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icono != null) ...[
              Icon(
                widget.icono,
                size: widget.compacto ? 14 : 18,
                color: AppColors.card,
              ),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (widget.compacto
                            ? Theme.of(context).textTheme.bodySmall
                            : Theme.of(context).textTheme.bodyLarge)
                        ?.copyWith(
                          color: AppColors.card,
                          fontWeight: FontWeight.w700,
                        ),
              ),
            ),
          ],
        ),
      ),
    );

    final boton = Stack(
      children: [
        // Sombra
        AnimatedPositioned(
          duration: duracion,
          curve: curva,
          left: 0,
          right: 0,
          top: base + _sombra,
          bottom: colchon - _sombra,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // Canto: el degradado horizontal, con los extremos más oscuros,
        // es lo que hace leer la pieza como un volumen.
        Positioned(
          left: 0,
          right: 0,
          top: base,
          bottom: colchon,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cantoOscuro, cantoClaro, cantoClaro, cantoOscuro],
                stops: const [0.0, 0.08, 0.92, 1.0],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cara,
      ],
    );

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // El hundido responde en el press, no al soltar: si esperara al
        // tap completo, el botón se sentiría con retraso.
        onTapDown: (_) => setState(() => _presionado = true),
        onTapUp: (_) => setState(() => _presionado = false),
        onTapCancel: () => setState(() => _presionado = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onPressed();
        },
        child: widget.anchoCompleto
            ? SizedBox(width: double.infinity, child: boton)
            : boton,
      ),
    );
  }
}
