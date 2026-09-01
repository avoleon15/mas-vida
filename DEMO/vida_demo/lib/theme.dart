import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens para +Vida. Tema CLARO: la app debe transmitir paz,
/// tranquilidad y ambiente sano (ver CLAUDE.md).
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF7FAF8);
  static const Color card = Color(0xFFFFFFFF);
  // Borde sutil de las tarjetas: sobre fondo claro, una tarjeta blanca
  // pura necesita este borde para no perderse contra el fondo (que
  // también es casi blanco).
  static const Color cardBorder = Color(0xFFE5E9E7);
  static const Color accent = Color(0xFF4A90D9);
  // Verde salud/vitalidad: progreso, estados de éxito, checks
  // completados. Nunca se usa para niveles (ver colorForNivel).
  static const Color accentSecondary = Color(0xFF5FAE85);
  static const Color textPrimary = Color(0xFF1A2E35);
  static const Color textSecondary = Color(0xFF6B7280);

  // Color de cada categoría/liga. El anillo de pasos usa el color de la
  // liga actual del usuario, no siempre el acento general de la app.
  // Progresión de verdes (más suave a más profundo): el azul queda
  // reservado para elementos de acción/interactivos, nunca categorías.
  // Nota: se evitan tonos demasiado pálidos (ej. un verde menta casi
  // blanco) aunque "Bronze" sea el más suave de los cuatro, porque este
  // color se usa como texto/ícono sobre fondo claro, no solo como
  // relleno — un verde casi blanco ahí sería ilegible.
  static const Color nivel1 = Color(0xFF4F9973);
  static const Color nivel2 = Color(0xFF3D8A63);
  static const Color nivel3 = Color(0xFF2E7A54);
  static const Color nivel4 = Color(0xFF1E5C3E);

  // Los tres tramos del anillo de pasos de Home. NO son niveles de
  // cashback ni la liga de duelos: son solo la lectura visual de en qué
  // escalón de la tabla de pasos va el usuario HOY, y se reinician cada
  // día.
  //
  // El gris es deliberado: ese tramo (0 a 7.000) no paga ni un punto, y
  // tiene que verse apagado para que el salto a plata se sienta como que
  // algo se prendió.
  //
  // Bronce, plata y oro en sus valores estándar. `silver` y `gold` son
  // colores con nombre del estándar CSS, así que esos dos hex son los
  // oficiales; el bronce no está en CSS y #CD7F32 es su valor canónico.
  //
  // ACCESIBILIDAD — no "corregir" estos tres valores por gusto estético
  // sin volver a revisar la luminosidad. Se usan con un usuario daltónico,
  // así que lo que los separa NO puede ser el matiz. Por suerte los
  // metales estándar ya vienen bien escalonados: L* ≈ 60, 78 y 87. Además
  // bronce y oro nunca se tocan (siempre hay plata completa en medio), que
  // es el par que más se podría confundir por ser los dos cálidos.
  //
  // La plata puede ser tan clara porque nunca se dibuja contra el track:
  // para cuando aparece, el aro de bronce ya está completo debajo.
  // El bronce va apagado a propósito (el estándar #CD7F32 es bastante más
  // naranja y saturado): es el tramo que no paga puntos, tiene que verse
  // mate al lado del brillo de la plata.
  static const Color aroBronce = Color(0xFFA0764A);
  static const Color aroPlata = Color(0xFFC0C0C0);
  static const Color aroOro = Color(0xFFFFD700);

  // Reflejos metálicos de los tres aros. Cada uno es un degradado que le
  // da la vuelta al trazo: dos brillos por vuelta, como un metal pulido.
  // El primer y el último color de cada lista son el mismo para que el
  // degradado circular cierre sin costura.
  //
  // ACCESIBILIDAD — el brillo se hace así, con contraste INTERNO, y no
  // subiéndole la luminosidad al color plano. Cada rampa está armada para
  // que la luminosidad PROMEDIO del metal se mantenga en su lugar
  // (bronce L* ≈ 55, plata ≈ 78, oro ≈ 86) y los tres sigan separados.
  // Al oro se lo mantiene alto a propósito, porque se dibuja pegado a la
  // plata. Si se tocan estas rampas, hay que volver a mirar el anillo en
  // escala de grises (lo hace lib/demo_anillo.dart).

  static const List<Color> brilloBronce = [
    Color(0xFF6E4E2E),
    Color(0xFFC89660),
    Color(0xFF8A6540),
    Color(0xFFC89660),
    Color(0xFF6E4E2E),
  ];

  static const List<Color> brilloPlata = [
    Color(0xFF8E9BA3),
    Color(0xFFF4F7F9),
    Color(0xFFA8B4BC),
    Color(0xFFF4F7F9),
    Color(0xFF8E9BA3),
  ];

  static const List<Color> brilloOro = [
    Color(0xFFE0AA00),
    Color(0xFFFFF8C8),
    Color(0xFFFFD700),
    Color(0xFFFFF8C8),
    Color(0xFFE0AA00),
  ];

  /// Paleta "galáctica" del aro completo (15.000 pasos o más): una nebulosa
  /// que gira. El primer y el último color son el mismo para que el
  /// degradado circular cierre sin costura.
  ///
  /// Acá SÍ se puede usar color libremente: es pura decoración de festejo,
  /// no comunica ningún dato. Lo que informa es que el aro está lleno, y
  /// eso se lee sin distinguir un solo matiz.
  static const List<Color> aroGalactico = [
    Color(0xFF2A1B5E), // morado profundo
    Color(0xFF6A2FA0),
    Color(0xFFC13BA6), // magenta
    Color(0xFFFF6B4A), // naranja
    Color(0xFFFFD700), // oro
    Color(0xFF3FA9F5), // celeste
    Color(0xFF2A1B5E), // cierra donde arrancó
  ];

  // Tarjeta con borde animado del saludo de Home. Existe para que la
  // pantalla no se sienta tan blanca.
  //
  // Los dos salen del accent #4A90D9, así que combinan con los azules del
  // resto de la app. OJO: los dos son OPACOS a propósito. Un fondo con
  // alpha deja pasar lo que hay detrás y la tarjeta se ensucia.
  //
  // Relleno: el accent mezclado con blanco, para que dé color sin pelearse
  // con el texto oscuro que va encima.
  static const Color tarjetaAzulClaro = Color(0xFFD7E7F7);

  // La franja que gira por el borde. Es el accent tal cual: sólida, un
  // solo tono, sin degradado.
  static const Color tarjetaBordeAzul = accent;

  /// Devuelve el color de un nivel anual (1 a 4).
  ///
  /// El contrato v1 prohíbe el naming Bronze/Silver/Gold/Platinum: los
  /// niveles son numéricos. La asignación de color a número es puramente
  /// visual, no codifica ninguna regla de negocio.
  ///
  /// Si el nivel no se reconoce (ej. `null` porque el acumulado cae en el
  /// rango sin definir de los niveles 1 y 2), cae al acento general.
  static Color colorForNivel(int? nivel) {
    switch (nivel) {
      case 1:
        return nivel1;
      case 2:
        return nivel2;
      case 3:
        return nivel3;
      case 4:
        return nivel4;
      default:
        return accent;
    }
  }
}

class AppTheme {
  AppTheme._();

  // SF Pro es propietaria de Apple: solo se puede usar en apps para
  // plataformas Apple. Como esta app también corre en Web, usamos Inter
  // (Google Fonts) como reemplazo visualmente muy cercano en todas las
  // plataformas.
  static final TextTheme _textTheme =
      GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      );

  /// Estilo para encabezados de sección tipo "HOY": una display font con
  /// más carácter que el resto de la tipografía (Inter), pensada para
  /// una app de actividad física. Se reutiliza en todas las pantallas.
  static TextStyle get sectionTitle => GoogleFonts.bebasNeue(
    color: AppColors.textPrimary,
    fontSize: 34,
    letterSpacing: 3,
    height: 1,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.accent,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.accentSecondary,
        surface: AppColors.card,
        onPrimary: Colors.black,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: _textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textSecondary,
      ),
      dividerColor: AppColors.cardBorder,
    );
  }
}
