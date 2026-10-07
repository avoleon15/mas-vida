import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

// ============================================================
// UNA HOJA QUE SUBE DESDE ABAJO, Y SE CIERRA COMO EN iOS.
//
// La barrita de arriba promete que la hoja se baja con el dedo, y tiene
// que cumplirlo. Dos formas de cerrarla arrastrando:
//
//   · desde la barrita o cualquier parte que no sea el texto: la barrita
//     vive AFUERA del scroll, así el gesto lo recibe la hoja y no el
//     contenido. Antes estaba adentro y el scroll se lo robaba;
//   · desde el contenido, cuando ya está arriba del todo: un tirón hacia
//     abajo la cierra, como cualquier hoja del sistema.
//
// Además se cierra tocando afuera y con su botón de abajo.
// ============================================================

/// Abre [hoja] desde abajo.
Future<T?> mostrarHojaVida<T>(
  BuildContext context, {
  required WidgetBuilder hoja,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
    builder: hoja,
  );
}

/// El cuerpo de una hoja: la barrita fija arriba y el contenido debajo,
/// que scrollea solo si no entra.
class HojaVida extends StatefulWidget {
  const HojaVida({
    super.key,
    required this.child,
    this.relleno = const EdgeInsets.fromLTRB(24, 4, 24, 24),
  });

  final Widget child;
  final EdgeInsets relleno;

  @override
  State<HojaVida> createState() => _HojaVidaState();
}

class _HojaVidaState extends State<HojaVida> {
  /// Cuánto se tiró hacia abajo con el contenido ya arriba del todo.
  double _tiron = 0;
  bool _cerrando = false;

  /// Un tirón de este largo cierra la hoja.
  static const double _tironParaCerrar = 70;

  bool _alDesplazar(ScrollNotification n) {
    if (_cerrando) return false;
    if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0) {
      _tiron -= n.overscroll;
      if (_tiron > _tironParaCerrar) {
        _cerrando = true;
        Navigator.of(context).maybePop();
      }
    } else if (n is ScrollEndNotification || n is ScrollStartNotification) {
      _tiron = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // La barrita, con un área de toque a todo el ancho: es de
              // donde se agarra la hoja.
              Semantics(
                label: 'Desliza hacia abajo para cerrar',
                child: const SizedBox(
                  height: 28,
                  child: Center(
                    child: SizedBox(
                      width: 38,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.cardBorder,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _alDesplazar,
                  child: SingleChildScrollView(
                    // Sin rebote: el tirón hacia abajo con el contenido
                    // arriba no estira la hoja, la cierra.
                    physics: const ClampingScrollPhysics(),
                    padding: widget.relleno,
                    child: widget.child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
