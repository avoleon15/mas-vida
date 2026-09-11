import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../theme.dart';
import 'placeholder_imagen.dart';

// ============================================================
// LAS MARCAS ALIADAS EN PANTALLA.
//
// Una alianza patrocina dos cosas distintas —un ciclo de la liga y una
// semana del camino— y en las dos se ve lo mismo: el logo de la marca y
// el cupón que paga. Por eso las piezas viven acá y no duplicadas en
// cada pantalla: si mañana el logo pasa a ser redondo, cambia en un solo
// lugar.
//
// De dónde salen los datos: SIEMPRE de `Patrocinio`, que llega del
// repositorio. Ninguna de estas piezas sabe qué marca es ni escribe un
// nombre a mano — hoy los datos vienen del mock y mañana del endpoint de
// Luis, y ninguna pantalla se entera del cambio.
//
// PLACEHOLDER: la marca del mock es Ookii y NO es definitiva. Diego la
// sustituye cuando cierre la alianza real. Nadie debería tomar ese
// nombre como un acuerdo cerrado.
// ============================================================

/// El logo de la marca aliada, en su cajita.
///
/// Cuadrado y de tamaño fijo: los logos vienen con proporciones
/// distintas y sin una caja pareja cada marca movería el layout a su
/// gusto. El fondo va blanco porque casi todos los logos vienen sobre
/// blanco o transparente.
class LogoPatrocinio extends StatelessWidget {
  const LogoPatrocinio({
    super.key,
    required this.patrocinio,
    this.tamano = 34,
  });

  final Patrocinio patrocinio;
  final double tamano;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Patrocina ${patrocinio.marca}',
    excludeSemantics: true,
    child: Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(tamano * 0.28),
        border: Border.all(color: AppColors.cardBorder),
      ),
      // ClipRRect y no solo el borderRadius del Container: la imagen se
      // pinta encima del fondo y sin recorte las esquinas del logo se
      // salen de la cajita.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tamano * 0.28 - 1),
        // `FotoComercio` ya resuelve WebP/PNG/SVG y cae en el
        // placeholder rayado si el archivo todavía no está. Un logo que
        // falta no puede dejar un hueco gris ni tumbar la pantalla.
        child: FotoComercio(
          ruta: patrocinio.logo,
          texto: patrocinio.marca,
          margen: tamano * 0.14,
        ),
      ),
    ),
  );
}

/// La cinta que anuncia quién patrocina y qué se lleva quien cumpla.
///
/// Va en azul, no en naranja: el naranja está reservado a monedas,
/// racha, alertas y checks (ver CLAUDE.md). Lo que hace distinto a este
/// premio de un cupón cualquiera del catálogo es que lleva la CARA de la
/// marca, no un color de más.
class CintaPatrocinio extends StatelessWidget {
  const CintaPatrocinio({
    super.key,
    required this.patrocinio,
    required this.texto,
    this.compacta = false,
  });

  final Patrocinio patrocinio;

  /// Qué gana el usuario, dicho por la pantalla que la usa: la liga
  /// premia a tres puestos y una semana premia a quien la cumple.
  final String texto;

  /// Versión angosta, para cuando la cinta va adentro de una tarjeta que
  /// ya está apretada.
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.textPrimary,
      height: 1.3,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compacta ? 8 : 10),
      decoration: BoxDecoration(
        color: AppColors.azulNiebla,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.azulSuave),
      ),
      child: Row(
        children: [
          LogoPatrocinio(patrocinio: patrocinio, tamano: compacta ? 30 : 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PATROCINA ${patrocinio.marca.toUpperCase()}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.azulMedio,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(texto, style: estilo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El cupón de la marca como marca chiquita, para una fila o un nodo.
///
/// Es un boleto, no una moneda: tienen que distinguirse de un vistazo
/// porque son dos premios distintos que se entregan juntos.
class ChipCuponMarca extends StatelessWidget {
  const ChipCuponMarca({super.key, required this.patrocinio, this.texto});

  final Patrocinio patrocinio;

  /// Qué dice al lado del logo. Sin texto queda solo el logo, para
  /// cuando el espacio no da (una fila de la tabla, por ejemplo).
  final String? texto;

  @override
  Widget build(BuildContext context) {
    final texto = this.texto;

    return Semantics(
      label: 'Cupón de ${patrocinio.marca}: ${patrocinio.cupon}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(3, 3, texto == null ? 3 : 8, 3),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.azulSuave),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoPatrocinio(patrocinio: patrocinio, tamano: 20),
            if (texto != null) ...[
              const SizedBox(width: 5),
              Text(
                texto,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.azulMedio,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
