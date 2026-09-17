import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../theme.dart';
import 'placeholder_imagen.dart';

// ============================================================
// LAS MARCAS ALIADAS EN PANTALLA.
//
// Una alianza patrocina dos cosas distintas —un ciclo de la liga y una
// semana del programa— y en las dos se ve lo mismo: la foto del local, el
// nombre y el cupón que paga. Por eso las piezas viven acá y no
// duplicadas en cada pantalla: si mañana la foto pasa a ser redonda,
// cambia en un solo lugar.
//
// De dónde salen los datos: SIEMPRE de `Patrocinio`, que llega del
// repositorio. Ninguna de estas piezas sabe qué marca es ni escribe un
// nombre, una ruta ni un color a mano — hoy los datos vienen del mock y
// mañana del endpoint de Luis, y ninguna pantalla se entera del cambio.
//
// PLACEHOLDER: las marcas del mock son Montanos y Ookii, y NO son
// definitivas. Diego las sustituye cuando cierre las alianzas reales.
//
// POR QUÉ SE USA `FotoComercio` Y NO UN `Image.asset` PELADO: ya resuelve
// las tres cosas que acá importan —SVG o mapa de bits, el color de fondo
// de la marca, y el placeholder rayado cuando el archivo todavía no
// está— y las resuelve IGUAL que el catálogo de Premios, que es donde el
// usuario ya vio esas mismas fotos.
//
// Y SIEMPRE con `contain`, nunca `cover`: son logos de local, no fotos de
// ambiente. Con `cover` en una caja ancha la marca se recorta y quedan
// medias palabras. `FotoComercio` ya usa `contain`; lo que hay que
// respetar acá es darle el `fondo` de la marca, porque un logo blanco
// sobre blanco desaparece.
// ============================================================

/// Un hex del catálogo ("#000000") convertido a color.
///
/// Un hex mal escrito en el JSON no puede tumbar la pantalla: se cae a
/// [porDefecto] y la marca se ve con el color de +Vida.
Color colorDesdeHex(String? hex, {required Color porDefecto}) {
  final limpio = hex?.replaceFirst('#', '');
  if (limpio == null || limpio.length != 6) return porDefecto;
  final valor = int.tryParse(limpio, radix: 16);
  return valor == null ? porDefecto : Color(0xFF000000 | valor);
}

/// El color de marca para los detalles, o el azul de +Vida si la marca no
/// trae uno.
///
/// Es la ÚNICA excepción a "los colores salen de AppColors": el acento de
/// un patrocinador es un dato, no una decisión de diseño. Sigue siendo un
/// solo lugar, así que ningún widget escribe un hex.
Color acentoDeMarca(Patrocinio patrocinio) =>
    colorDesdeHex(patrocinio.acento, porDefecto: AppColors.accent);

/// La foto del local, recortada a una caja con esquinas redondeadas.
///
/// Todas las piezas de acá la usan para que la marca se vea igual en el
/// cintillo, en el camino y en el carrusel.
class FotoPatrocinador extends StatelessWidget {
  const FotoPatrocinador({
    super.key,
    required this.patrocinio,
    this.alto,
    this.radio = 14,
    this.margen = 10,
  });

  final Patrocinio patrocinio;

  /// Alto fijo, o null para llenar lo que le den (dentro de un Expanded,
  /// por ejemplo).
  final double? alto;

  final double radio;

  /// Aire entre el logo y el borde de su caja. Sin esto los logos anchos
  /// tocan los bordes y se leen como un banner, no como una marca.
  final double margen;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radio),
    child: SizedBox(
      height: alto,
      width: double.infinity,
      child: FotoComercio(
        ruta: patrocinio.logo,
        texto: patrocinio.marca,
        fondo: patrocinio.fondo,
        margen: margen,
      ),
    ),
  );

  /// Igual que el de arriba pero sin alto propio: lo usa el carrusel,
  /// donde la foto se lleva lo que quede libre en la tarjeta.
  static Widget flexible(Patrocinio patrocinio) =>
      FotoPatrocinador(patrocinio: patrocinio, radio: 0, margen: 12);
}

/// El logo de la marca en chico, para una fila o un chip.
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
        child: FotoComercio(
          ruta: patrocinio.logo,
          texto: patrocinio.marca,
          fondo: patrocinio.fondo,
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
/// Es un boleto con la CARA de la marca y su color, no una moneda: tiene
/// que distinguirse de un vistazo de un premio cualquiera del catálogo,
/// porque son dos cosas distintas que se entregan juntas.
class ChipCuponMarca extends StatelessWidget {
  const ChipCuponMarca({super.key, required this.patrocinio, this.texto});

  final Patrocinio patrocinio;

  /// Qué dice al lado del logo. Sin texto queda solo el logo, para
  /// cuando el espacio no da (una fila de la tabla, por ejemplo).
  final String? texto;

  @override
  Widget build(BuildContext context) {
    final texto = this.texto;
    final acento = acentoDeMarca(patrocinio);

    return Semantics(
      label: 'Cupón de ${patrocinio.marca}: ${patrocinio.cupon}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(3, 3, texto == null ? 3 : 8, 3),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: acento.withValues(alpha: 0.55)),
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
                  color: acento,
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
