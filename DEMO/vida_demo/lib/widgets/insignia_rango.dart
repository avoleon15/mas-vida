import 'dart:math';

import 'package:flutter/material.dart';

import '../reglas_rango.dart';
import '../theme.dart';

// ============================================================
// LA INSIGNIA DE RANGO.
//
// Un medallón con el número adentro y un anillo de diez muescas
// alrededor, encendidas hasta el rango en el que va el usuario. Dice dos
// cosas de un vistazo: en cuál está y cuánto le queda de escalera.
//
// POR QUÉ UN CUSTOMPAINTER Y NO UNA LIBRERÍA. El orden de CLAUDE.md
// manda bajar hasta acá solo cuando lo de arriba no resuelve: Cupertino
// no tiene nada parecido, shadcn y GetWidget traen barras y anillos
// CONTINUOS, y `fl_chart` dibujaría diez porciones de torta iguales —que
// es lo que se ve— pero arrastrando ejes, tooltips y animación de datos
// para un dibujo que no es una gráfica. Diez muescas sueltas alrededor
// de un círculo es un dibujo propio del producto, como el anillo de
// pasos de Hoy.
//
// LO QUE ESTA PIEZA NO HACE. No muestra avance DENTRO de un rango, y no
// es un olvido: `reglas_rango.dart` sacó el XP a propósito y dice
// explícito "no volver a introducirlo". El rango se mueve por cumplir
// los tres objetivos de la semana, así que la muesca once no se llena
// "a medias" — se enciende entera el domingo o no se enciende.
//
// EL COLOR SALE DE LA ESCALA DE AZULES. Las muescas encendidas van de
// `azulMedio` al `accent`: lo que separa una de la siguiente es la
// LUMINOSIDAD, igual que los niveles de cashback, así que la escalera se
// lee como escalera aunque alguien no distinga bien los colores. El
// naranja no entra: está reservado a las monedas, la llama de la racha,
// las alertas y los checks.
// ============================================================

/// Grosor de una muesca del anillo.
const double _grosorMuesca = 4;

/// Cuánto del espacio de cada muesca es muesca y cuánto es aire.
///
/// Con 1.0 el anillo sería un círculo continuo y no se podrían contar los
/// escalones, que es justamente lo que esta pieza tiene que dejar hacer.
const double _llenoDeLaMuesca = 0.62;

/// El medallón de rango: el número adentro, la escalera alrededor.
class InsigniaRango extends StatelessWidget {
  const InsigniaRango({
    super.key,
    required this.rango,
    this.tamano = 56,
    this.maximo = rangoMaximo,
  });

  /// En qué escalón va el usuario. Lo manda el servidor.
  final int rango;

  /// Alto y ancho del medallón entero, anillo incluido.
  final double tamano;

  /// Cuántos escalones tiene la escalera. Sale de `reglas_rango.dart` y
  /// no de un 10 escrito acá: el día que el programa cambie de largo, el
  /// anillo lo sigue solo.
  final int maximo;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Rango $rango de $maximo',
    excludeSemantics: true,
    child: SizedBox(
      width: tamano,
      height: tamano,
      child: CustomPaint(
        painter: _AnilloRangoPainter(rango: rango, maximo: maximo),
        child: Center(
          child: Container(
            // El disco de adentro existe para que el número no flote
            // suelto en medio del anillo: le da un piso y separa las dos
            // lecturas —cuál es el rango, cuánta escalera queda—.
            width: tamano - _grosorMuesca * 2 - 10,
            height: tamano - _grosorMuesca * 2 - 10,
            decoration: const BoxDecoration(
              color: AppColors.azulNiebla,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            // Dos dígitos (el rango 10) tienen que entrar en el mismo
            // disco que uno solo, sin que el medallón crezca ni el
            // número se salga.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '$rango',
                  style: AppTheme.display(tamano * 0.42).copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AnilloRangoPainter extends CustomPainter {
  _AnilloRangoPainter({required this.rango, required this.maximo});

  final int rango;
  final int maximo;

  /// El anillo abre a las 12 en punto, igual que el de pasos de Hoy.
  static const double _arranque = -pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (maximo <= 0) return;

    final centro = size.center(Offset.zero);
    final radio = (size.shortestSide - _grosorMuesca) / 2;
    final caja = Rect.fromCircle(center: centro, radius: radio);

    final espacio = 2 * pi / maximo;
    final barrido = espacio * _llenoDeLaMuesca;
    // El aire sobrante se reparte a los dos lados de cada muesca, así
    // quedan centradas en su porción y el anillo se ve parejo.
    final sangria = (espacio - barrido) / 2;

    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _grosorMuesca
      ..strokeCap = StrokeCap.round;

    final encendidas = rango.clamp(0, maximo);

    for (var i = 0; i < maximo; i++) {
      pincel.color = i < encendidas
          ? _colorDelEscalon(i, encendidas)
          : AppColors.azulSuave;

      canvas.drawArc(
        caja,
        _arranque + espacio * i + sangria,
        barrido,
        false,
        pincel,
      );
    }
  }

  /// El azul de la muesca [i], de las [encendidas] que están prendidas.
  ///
  /// La primera arranca en `azulMedio` y la última llega al `accent`: el
  /// anillo se oscurece a medida que sube, así que se ve cuánto se
  /// avanzó incluso sin contar las muescas.
  Color _colorDelEscalon(int i, int encendidas) {
    if (encendidas <= 1) return AppColors.accent;
    return Color.lerp(
      AppColors.azulMedio,
      AppColors.accent,
      i / (encendidas - 1),
    )!;
  }

  @override
  bool shouldRepaint(covariant _AnilloRangoPainter anterior) =>
      anterior.rango != rango || anterior.maximo != maximo;
}
