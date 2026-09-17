import 'package:flutter/material.dart';

import 'patrocinio.dart' show colorDesdeHex;
import 'placeholder_imagen.dart';

/// Cintillo del patrocinador de la semana en curso.
///
/// Traducción de una tarjeta CSS de Uiverse. El `box-shadow: inset` del
/// original no existe en Flutter: sus dos sombras internas (oscura
/// arriba, blanca abajo) son en realidad un degradado vertical, así que
/// se dibujan como un LinearGradient encima de la foto. Se ve igual y
/// cuesta un widget en vez de un CustomPainter.
class CintilloPatrocinador extends StatefulWidget {
  const CintilloPatrocinador({
    super.key,
    required this.semana,
    required this.marca,
    required this.fotos,
    required this.fondoMarca,
  });

  final int semana;
  final String marca;

  /// Las fotos que rotan. Si viene una sola, el cintillo se queda quieto
  /// y no arranca ningún temporizador.
  final List<String> fotos;

  /// Color de fondo de la marca, para que el logo no flote sobre blanco.
  ///
  /// Es el HEX que trae el catálogo ("#000000"), no un `Color` ya
  /// resuelto: [FotoComercio] lo pide así, y convertirlo a `Color` acá
  /// solo para que allá lo vuelvan a convertir sería dar dos vueltas.
  /// Null quiere decir blanco.
  final String? fondoMarca;

  @override
  State<CintilloPatrocinador> createState() => _CintilloPatrocinadorState();
}

/// Lo que dura una vuelta completa por las fotos.
const Duration _ciclo = Duration(seconds: 6);

/// Proporción del cintillo, ancho : alto.
///
/// El CSS original era vertical (190x254). Acá va apaisado porque las
/// fotos de los comercios lo son —la tarjeta de Premios las dibuja a
/// 1.4— y en una caja vertical se recortarían por los lados.
const double _proporcion = 2.2;

class _CintilloPatrocinadorState extends State<CintilloPatrocinador>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  late final Animation<double> _panel;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(vsync: this, duration: _ciclo);
    _panel = _secuencia().animate(_controlador);
  }

  /// Los porcentajes del @keyframes original: se queda quieta, se
  /// desliza, se queda quieta, se desliza, se queda quieta. Con tres
  /// fotos los pesos salen exactamente 20/10/40/10/20, que es el CSS tal
  /// cual.
  ///
  /// Se arma según CUÁNTAS fotos hay y no con los cinco pasos fijos del
  /// original: con dos fotos, una secuencia que siempre termina en el
  /// panel 2 se deslizaría hasta un hueco vacío. Hoy siempre son tres
  /// —la misma repetida—, pero el día que Diego traiga las reales nadie
  /// se va a acordar de este detalle.
  TweenSequence<double> _secuencia() {
    final ultimo = widget.fotos.length - 1;
    final items = <TweenSequenceItem<double>>[];

    for (var i = 0; i <= ultimo; i++) {
      items.add(
        TweenSequenceItem(
          tween: ConstantTween<double>(i.toDouble()),
          // La primera y la última se muestran la mitad de tiempo: entre
          // las dos hacen el mismo descanso que una del medio, porque el
          // ciclo arranca en una y termina en la otra.
          weight: (i == 0 || i == ultimo) ? 20 : 40,
        ),
      );
      if (i < ultimo) {
        items.add(
          TweenSequenceItem(
            tween: Tween<double>(
              begin: i.toDouble(),
              end: i + 1.0,
            ).chain(CurveTween(curve: Curves.easeInOutBack)),
            weight: 10,
          ),
        );
      }
    }

    return TweenSequence<double>(items);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con "Reducir movimiento" activado en iOS se queda en la primera
    // foto. No es un atajo: es el mismo camino que ya toma la moneda, y
    // es lo que evita que los tests se cuelguen esperando que una
    // animación infinita se asiente.
    if (MediaQuery.disableAnimationsOf(context) || widget.fotos.length < 2) {
      _controlador.stop();
      _controlador.value = 0;
    } else if (!_controlador.isAnimating) {
      _controlador.repeat();
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sin rótulo propio: quién patrocina esta semana lo dice el TÍTULO de
    // la pantalla, que ahora es "SEMANA 3 · Patrocinada por Montanos".
    // Repetirlo acá sería decir dos veces lo mismo a dos centímetros.
    //
    // La etiqueta para VoiceOver sí se queda: alguien que no ve la
    // pantalla necesita saber de qué es esta foto.
    return Semantics(
      label: 'Semana ${widget.semana}, patrocinada por ${widget.marca}',
      excludeSemantics: true,
      child: DecoratedBox(
        // Las dos sombras EXTERNAS del CSS. Van acá afuera y no dentro
        // del ClipRRect, porque un clip se las comería.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            const BoxShadow(
              color: Colors.white,
              offset: Offset(1, 1),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.13),
              offset: const Offset(-1, -1),
              blurRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: _proporcion,
            child: LayoutBuilder(
              builder: (context, caja) => Stack(
                fit: StackFit.expand,
                children: [
                  // El fondo de la marca, DETRÁS de todo. No es
                  // redundante con el que ya pinta cada foto:
                  // `easeInOutBack` se pasa de largo a propósito en los
                  // dos extremos del deslizamiento, y en ese sobrepaso
                  // la tira de fotos deja ver lo que hay atrás. Sin
                  // esto, asoma un borde vacío en cada rebote.
                  ColoredBox(
                    color: colorDesdeHex(
                      widget.fondoMarca,
                      porDefecto: Colors.white,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _panel,
                    builder: (context, _) => Stack(
                      children: [
                        Positioned(
                          // Traducción directa del translateX del CSS.
                          left: -_panel.value * caja.maxWidth,
                          top: 0,
                          bottom: 0,
                          width: caja.maxWidth * widget.fotos.length,
                          child: Row(
                            children: [
                              for (final ruta in widget.fotos)
                                SizedBox(
                                  width: caja.maxWidth,
                                  // FotoComercio ya resuelve SVG vs PNG,
                                  // el fondo de la marca y el respaldo si
                                  // el archivo falta.
                                  child: FotoComercio(
                                    ruta: ruta,
                                    fondo: widget.fondoMarca,
                                    texto: widget.marca.toUpperCase(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // El `box-shadow: inset` del CSS, que en Flutter no
                  // existe: oscuro arriba, blanco abajo, nada en medio.
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.16),
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.55),
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
