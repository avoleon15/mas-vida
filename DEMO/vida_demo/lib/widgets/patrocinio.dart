import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../theme.dart';
import 'placeholder_imagen.dart';

// ============================================================
// LAS MARCAS ALIADAS EN PANTALLA.
//
// Una alianza patrocina dos cosas —un ciclo de La Liga y una semana de
// la temporada— y en las dos se ve igual: su logo y su color. Las piezas
// viven acá para que no haya dos versiones de la misma marca.
//
// Los datos salen SIEMPRE de `Patrocinio`, que llega del repositorio:
// nada de acá escribe un nombre, una ruta ni un color a mano.
//
// PLACEHOLDER: las marcas del mock (Montanos, Ookii) no son definitivas.
// Diego las sustituye cuando cierre las alianzas reales.
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

/// El logo de la marca en chico, para una fila o un chip.
class LogoPatrocinio extends StatelessWidget {
  const LogoPatrocinio({super.key, required this.patrocinio, this.tamano = 34});

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
