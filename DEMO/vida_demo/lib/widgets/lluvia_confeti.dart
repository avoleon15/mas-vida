import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// ============================================================
// EL CONFETI DEL CANJE.
//
// Cae una sola vez, encima de todo y sin tapar nada: es una felicitación,
// no un paso más del flujo. El usuario tiene que poder tocar "Volver al
// Inicio" mientras todavía cae.
// ============================================================

const String _rutaConfeti = 'assets/lottie/confetti.lottie';

/// Cuánto dura la caída.
///
/// El archivo trae 300 cuadros a 30 fps (10 s), pero el confeti ya se
/// despejó al 75% de la línea de tiempo: los últimos 2,5 s son un cuadro
/// vacío. A 7 s la caída se ve entera y termina cuando de verdad terminó.
const Duration _duracionCaida = Duration(seconds: 7);

/// Confeti cayendo sobre toda la pantalla, una sola vez.
///
/// Va como último hijo de un [Stack] que ocupe la pantalla completa.
class LluviaConfeti extends StatefulWidget {
  const LluviaConfeti({super.key});

  @override
  State<LluviaConfeti> createState() => _LluviaConfetiState();
}

class _LluviaConfetiState extends State<LluviaConfeti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(vsync: this, duration: _duracionCaida);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con "Reducir movimiento" no cae nada. Es puro adorno: quitarlo no
    // le saca información a nadie.
    if (!MediaQuery.disableAnimationsOf(context) &&
        _controlador.status == AnimationStatus.dismissed) {
      _controlador.forward();
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      // No se toca: los botones de abajo tienen que seguir respondiendo
      // mientras el confeti cae.
      child: IgnorePointer(
        // Y no lo lee el lector de pantalla: no dice nada que el título
        // "¡Canje Exitoso!" no diga ya.
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: Lottie.asset(
              _rutaConfeti,
              controller: _controlador,
              fit: BoxFit.cover,
              animate: false,
              // Si el archivo falta, no cae confeti y ya. La pantalla
              // funciona igual.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
