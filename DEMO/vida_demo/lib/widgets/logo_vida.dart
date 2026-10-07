import 'package:flutter/material.dart';

import '../theme.dart';

/// Ruta del logo de la marca. En un solo lugar: antes vivía dentro de
/// `app_header.dart`, y al necesitarlo también la pantalla de carga la
/// ruta y su plan B habrían quedado escritos dos veces.
const String _rutaLogo = 'assets/img/logo_vida.png';

/// El logo de +Vida: la cruz azul y la palabra "vida".
///
/// Se le pide el ALTO y nunca el ancho: el archivo es casi 3:1 y dándole
/// los dos el logo se deforma. Con solo el alto, el ancho lo saca
/// Flutter de la proporción del archivo.
class LogoVida extends StatelessWidget {
  const LogoVida({super.key, required this.alto});

  /// Cuánto mide el logo de arriba a abajo.
  ///
  /// Ojo al elegirlo: dentro del archivo la palabra "vida" ocupa bastante
  /// menos alto que la cruz, así que el logo se vuelve ilegible antes de
  /// lo que uno esperaría.
  final double alto;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _rutaLogo,
      height: alto,
      // El logo trae el azul de marca adentro: no se le aplica ningún
      // color encima, se pinta como lo entregó diseño.
      filterQuality: FilterQuality.medium,
      // Para el lector de pantalla el logo es el nombre de la app. Sin
      // esto, donde se ve el logo no se leería nada.
      semanticLabel: '+Vida',
      // Si el archivo faltara, no puede quedar un hueco: vuelve al
      // wordmark escrito, que es lo que había antes del logo real.
      errorBuilder: (context, error, stack) => Text(
        '+VIDA',
        style: TextStyle(
          color: AppColors.textPrimary,
          // Atado al alto pedido y no a un tamaño fijo: así el plan B
          // ocupa más o menos lo mismo que el logo en cada lugar donde
          // se use, y el renglón no se descuadra.
          fontSize: alto * 0.8,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
