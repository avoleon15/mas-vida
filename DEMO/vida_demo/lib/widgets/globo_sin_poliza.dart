import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../theme.dart';

// ============================================================
// EL GLOBITO DEL CANDADO.
//
// Para quien no tiene póliza, lo que está cerrado (el canje de un premio,
// La Liga) lleva un candado, y del candado SALE un globito que dice por
// qué. Es AZUL de marca, sale animado al entrar, se queda 3 segundos y se
// va;
// vuelve con el mouse encima de la tarjeta o tocándola (pedido de Daniel,
// 8 de octubre de 2026). El camino para agregar la póliza vive en Mi Plan.
//
// Tres piezas:
//   · [BurbujaSinPoliza] → el dibujo: el globo con su piquito.
//   · [GloboSinPoliza]   → la pega al candado con un `ShadPopover`.
//   · [ZonaSinPoliza]    → la tarjeta que lo contiene: decide cuándo se
//                          ve.
// ============================================================

/// El texto de siempre.
const String mensajeSinPoliza =
    'No tienes acceso a esta opción porque no tienes póliza.';

/// Llave del globito, para los tests.
const Key llaveGloboSinPoliza = ValueKey('globo-sin-poliza');

/// De qué lado del globo sale el piquito.
enum PicoGlobo {
  /// Abajo y al centro: el candado está debajo.
  abajo,

  /// Arriba, cerca de la esquina derecha: el candado está arriba a la
  /// derecha. Cuánto se corre lo dice `distanciaDerecha`.
  arribaDerecha,
}

/// Lo que mide el cuadradito que, girado 45°, hace de piquito.
const double _pico = 12;

/// El degradado del botón principal (`BotonPildora`): el mismo azul, con
/// un respiro más claro en la esquina de arriba.
final Color _azulClaro = Color.lerp(
  AppColors.accent,
  AppColors.azulMedio,
  0.22,
)!;

/// El globo azul con su piquito.
class BurbujaSinPoliza extends StatelessWidget {
  const BurbujaSinPoliza({
    super.key,
    this.mensaje = mensajeSinPoliza,
    this.pico = PicoGlobo.abajo,
    this.distanciaDerecha = 16,
  });

  final String mensaje;
  final PicoGlobo pico;

  /// Con [PicoGlobo.arribaDerecha]: desde el borde derecho del globo
  /// hasta el centro del piquito. Va al centro del candado.
  final double distanciaDerecha;

  @override
  Widget build(BuildContext context) {
    final abajo = pico == PicoGlobo.abajo;

    final piquito = Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: _pico,
        height: _pico,
        decoration: BoxDecoration(
          // Del color que tiene el globo justo en ese borde, para que el
          // piquito no se note pegado.
          color: abajo
              ? Color.lerp(_azulClaro, AppColors.accent, 0.6)
              : Color.lerp(_azulClaro, AppColors.accent, 0.45),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

    final globo = Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_azulClaro, AppColors.accent],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // El candado en un disquito blanco translúcido: repite, en
          // chico, el candado del que sale el globo.
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.lock_fill,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              mensaje,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );

    final burbuja = Semantics(
      key: llaveGloboSinPoliza,
      container: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          globo,
          Positioned(
            // El piquito asoma la mitad por fuera del globo.
            bottom: abajo ? -_pico / 2 + 1 : null,
            top: abajo ? null : -_pico / 2 + 1,
            left: abajo ? 0 : null,
            right: abajo ? 0 : distanciaDerecha - _pico / 2,
            child: abajo ? Center(child: piquito) : piquito,
          ),
        ],
      ),
    );

    return burbuja;
  }
}

// ============================================================
// CUÁNDO SE VE
// ============================================================

/// La tarjeta (o el botón) que lleva el candado: decide cuándo se ve el
/// globito de adentro.
///
/// NO está puesto desde antes: sale animado un momento después de entrar
/// a la pantalla —[retraso], lo que tarda la pantalla en terminar de
/// entrar—, se queda [duracion] y se va (pedido de Daniel, 8 de octubre
/// de 2026). Vuelve al pasar el mouse por encima (la vista previa en el
/// navegador) y al tocar la tarjeta, que es el "hover" de un iPhone.
class ZonaSinPoliza extends StatefulWidget {
  const ZonaSinPoliza({
    super.key,
    required this.child,
    this.duracion = const Duration(seconds: 3),
    this.retraso = const Duration(milliseconds: 600),
  });

  final Widget child;
  final Duration duracion;
  final Duration retraso;

  /// Si el globito de [context] se ve. Sin zona arriba, siempre.
  static bool visibleEn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GloboVisible>()?.visible ??
      true;

  @override
  State<ZonaSinPoliza> createState() => _ZonaSinPolizaState();
}

class _ZonaSinPolizaState extends State<ZonaSinPoliza> {
  bool _visible = false;
  bool _encima = false;
  Timer? _entrada;
  Timer? _cierre;

  @override
  void initState() {
    super.initState();
    _entrada = Timer(widget.retraso, () {
      if (!mounted) return;
      _mostrar();
      _cerrarEn(widget.duracion);
    });
  }

  void _cerrarEn(Duration espera) {
    _cierre?.cancel();
    _cierre = Timer(espera, () {
      if (mounted && !_encima) setState(() => _visible = false);
    });
  }

  void _mostrar() {
    if (!_visible) setState(() => _visible = true);
  }

  @override
  void dispose() {
    _entrada?.cancel();
    _cierre?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      // Con el mouse encima se queda; al salir, se va enseguida.
      onEnter: (_) {
        _encima = true;
        _entrada?.cancel();
        _cierre?.cancel();
        _mostrar();
      },
      onExit: (_) {
        _encima = false;
        _cerrarEn(const Duration(milliseconds: 500));
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Tocarla lo vuelve a mostrar el mismo rato que al entrar.
        onTap: () {
          if (!_visible) HapticFeedback.selectionClick();
          _mostrar();
          _cerrarEn(widget.duracion);
        },
        child: _GloboVisible(visible: _visible, child: widget.child),
      ),
    );
  }
}

class _GloboVisible extends InheritedWidget {
  const _GloboVisible({required this.visible, required super.child});

  final bool visible;

  @override
  bool updateShouldNotify(_GloboVisible anterior) =>
      anterior.visible != visible;
}

/// Pega [BurbujaSinPoliza] al candado ([child]), con el piquito
/// apuntándole. Flota sobre la pantalla y no empuja nada: como se va a
/// los pocos segundos, no deja hueco.
///
/// Cuándo se ve lo decide la [ZonaSinPoliza] de arriba.
class GloboSinPoliza extends StatelessWidget {
  const GloboSinPoliza({
    super.key,
    required this.child,
    this.mensaje = mensajeSinPoliza,
    this.lado = LadoGlobo.arriba,
    this.anchoCandado = 32,
  });

  final Widget child;
  final String mensaje;
  final LadoGlobo lado;

  /// Con [LadoGlobo.abajoDerecha]: el ancho del candado, para que el
  /// piquito apunte a su centro.
  final double anchoCandado;

  @override
  Widget build(BuildContext context) {
    final arriba = lado == LadoGlobo.arriba;
    final quieto = MediaQuery.disableAnimationsOf(context);

    return ShadPopover(
      visible: ZonaSinPoliza.visibleEn(context),
      closeOnTapOutside: false,
      decoration: ShadDecoration.none,
      shadows: const [],
      padding: EdgeInsets.zero,
      // Entra CRECIENDO DESDE EL CANDADO, con un rebote chico al llegar:
      // se lee como algo que sale de ahí y no como un cartel que aparece.
      // Sale con un fundido corto. Con "Reducir movimiento", aparece y se
      // va sin moverse.
      effects: quieto
          ? const []
          : [
              const FadeEffect(duration: Duration(milliseconds: 220)),
              ScaleEffect(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                alignment: arriba
                    ? Alignment.bottomCenter
                    : Alignment(1 - anchoCandado / 260, -1),
                duration: const Duration(milliseconds: 460),
                curve: Curves.easeOutBack,
              ),
              MoveEffect(
                begin: Offset(0, arriba ? 8 : -8),
                end: Offset.zero,
                duration: const Duration(milliseconds: 460),
                curve: Curves.easeOutCubic,
              ),
            ],
      reverseDuration: const Duration(milliseconds: 200),
      // OJO con los nombres de shadcn: `childAlignment` es el punto del
      // GLOBO y `overlayAlignment` el del candado.
      anchor: arriba
          ? const ShadAnchor(
              childAlignment: Alignment.bottomCenter,
              overlayAlignment: Alignment.topCenter,
              offset: Offset(0, -10),
            )
          : const ShadAnchor(
              childAlignment: Alignment.topRight,
              overlayAlignment: Alignment.bottomRight,
              offset: Offset(0, 10),
            ),
      popover: (context) => BurbujaSinPoliza(
        mensaje: mensaje,
        pico: arriba ? PicoGlobo.abajo : PicoGlobo.arribaDerecha,
        distanciaDerecha: anchoCandado / 2,
      ),
      child: child,
    );
  }
}

/// Para qué lado del candado sale el globo.
enum LadoGlobo {
  /// Arriba y centrado.
  arriba,

  /// Abajo, con el borde derecho alineado al del candado: para un
  /// candado pegado a la derecha de una tarjeta.
  abajoDerecha,
}
