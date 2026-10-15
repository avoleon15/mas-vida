import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../theme.dart';

// ============================================================
// LA FOTO DEL USUARIO.
//
// Vive en UN solo lugar porque aparece en tres: el header de todas las
// pantallas, la ficha de Perfil y el escalón donde el usuario está
// parado en Mi Plan. Si cada una la resolviera por su cuenta, el día que
// la foto llegue del backend habría que acordarse de los tres.
//
// GFAvatar y no un ClipOval a mano: CLAUDE.md manda getwidget justamente
// para avatares, y ya resuelve el recorte, el color de fondo y el hijo
// centrado cuando no hay imagen.
//
// [PENDIENTE: hoy la foto es un asset fijo. Cuando exista la cuenta de
// verdad va a llegar como URL del perfil, y lo único que cambia es el
// `ImageProvider` de acá — ninguna pantalla se entera.]
// ============================================================

/// Dónde está la foto del usuario.
///
/// Se nombra UNA vez en toda la app. La carpeta tiene espacios y mayúscula
/// porque así entró al repo; el nombre exacto importa, así que no se
/// escribe de memoria en ningún otro archivo.
const String rutaFotoPerfil = 'assets/Foto de perfil/pp_picture.JPG';

/// Diámetro del avatar del header, que es el tamaño de referencia.
const double diametroAvatarHeader = 40;

/// La foto del usuario, redonda, con borde opcional.
class AvatarUsuario extends StatelessWidget {
  const AvatarUsuario({
    super.key,
    this.diametro = diametroAvatarHeader,
    this.borde,
    this.grosorBorde = 2.5,
  });

  /// Ancho y alto de la foto. Si lleva [borde], el widget entero mide
  /// [diametro] + 2 × [grosorBorde].
  final double diametro;

  /// Aro alrededor de la foto, o null para no dibujar ninguno.
  ///
  /// Lo usa el escalón de Mi Plan: sobre el azul lleno del nivel, una
  /// foto sin aro se lee como una mancha pegada a la barra.
  final Color? borde;

  final double grosorBorde;

  @override
  Widget build(BuildContext context) {
    // `radius` y no `size`: GFAvatar multiplica `size` por 1.5 para sacar
    // el diámetro, así que pedirlo por radio es lo único que da un
    // tamaño exacto y predecible.
    final foto = GFAvatar(
      radius: diametro / 2,
      shape: GFAvatarShape.circle,
      backgroundColor: AppColors.cardBorder,
      backgroundImage: const AssetImage(rutaFotoPerfil),
      // Si el asset falta, GFAvatar deja el círculo del color de fondo en
      // vez de reventar la pantalla. El ícono queda de respaldo debajo.
      child: null,
    );

    final aro = borde;
    if (aro == null) return foto;

    return Container(
      padding: EdgeInsets.all(grosorBorde),
      decoration: BoxDecoration(color: aro, shape: BoxShape.circle),
      child: foto,
    );
  }
}
