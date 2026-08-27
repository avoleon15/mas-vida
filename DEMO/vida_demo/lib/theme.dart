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
