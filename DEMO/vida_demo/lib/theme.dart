import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Design tokens para +Vida. Tema CLARO: la app debe transmitir paz,
/// tranquilidad y ambiente sano (ver CLAUDE.md).
class AppColors {
  AppColors._();

  // ----------------------------------------------------------
  // Paleta de marca: azul #012096, naranja #F58700 y blanco.
  //
  // La regla de reparto es por TAMAÑO de la superficie:
  //   blanco  -> lo grande (fondos, tarjetas, superficies)
  //   azul    -> lo mediano (botones, barras de progreso, íconos de
  //              sección, elementos de acción)
  //   naranja -> lo chico (marcas de estado, chips, puntos, checks,
  //              detalles que tienen que saltar a la vista)
  //
  // El naranja NUNCA se usa como relleno de una superficie grande: a
  // ese tamaño compite con todo y rompe la calma que la app tiene que
  // transmitir. Su trabajo es señalar, no vestir.
  // ----------------------------------------------------------

  /// Casi blanco con un tinte azul mínimo, para que las tarjetas blancas
  /// puras se despeguen del fondo.
  static const Color background = Color(0xFFF5F6FA);
  static const Color card = Color(0xFFFFFFFF);
  // Borde sutil de las tarjetas: sobre fondo claro, una tarjeta blanca
  // pura necesita este borde para no perderse contra el fondo (que
  // también es casi blanco).
  static const Color cardBorder = Color(0xFFE3E6F0);

  /// Azul de marca. Acciones y elementos medianos.
  static const Color accent = Color(0xFF012096);

  /// Naranja de marca. Detalles chicos: estados de éxito, checks,
  /// marcadores, chips. Antes acá vivía el verde de salud.
  static const Color accentSecondary = Color(0xFFF58700);

  /// Azul muy oscuro en vez de negro puro: sobre fondo claro el negro se
  /// ve duro, y este tono emparenta el texto con el azul de marca.
  static const Color textPrimary = Color(0xFF101833);

  /// Gris de apoyo. Se oscureció de #6B7280 a este tono porque sobre los
  /// fondos tintados de Home el original daba 4.29:1 y 4.20:1 — por
  /// debajo del 4.5:1 que pide WCAG AA para texto normal. Acá da 4.62:1
  /// sobre el fondo cálido, 4.53:1 sobre la tarjeta de grupo y 5.21:1
  /// sobre blanco.
  ///
  /// No aclararlo sin volver a medir: las etiquetas DIARIO / SEMANAL /
  /// ANUAL van en este color y en la variante A se apoyan directo sobre
  /// el fondo tintado, que es el caso más exigente.
  static const Color textSecondary = Color(0xFF666D7A);

  // Color de cada categoría/liga de cashback. Progresión del azul de
  // marca, de más claro a más profundo, terminando exactamente en
  // [accent].
  //
  // Lo que separa un nivel del siguiente es la LUMINOSIDAD, no el matiz:
  // se leen como escalones aunque no se distingan bien los colores. No
  // "corregir" estos valores acercándolos entre sí por gusto estético.
  //
  // Se evitan tonos demasiado pálidos porque estos colores también se
  // usan como texto e íconos sobre fondo claro, no solo como relleno.
  static const Color nivel1 = Color(0xFF7C90D4);
  static const Color nivel2 = Color(0xFF5468BC);
  static const Color nivel3 = Color(0xFF2C41A6);
  static const Color nivel4 = Color(0xFF012096);

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
  static const Color tarjetaAzulClaro = Color(0xFFDDE3F7);

  // La franja que gira por el borde. Es el accent tal cual: sólida, un
  // solo tono, sin degradado.
  static const Color tarjetaBordeAzul = accent;

  /// Fondo de la pantalla: gris cálido muy suave, con las tarjetas de
  /// contenido en blanco puro. El contraste entre los dos es lo que da
  /// profundidad; antes fondo y tarjetas eran casi el mismo blanco y la
  /// pantalla se veía plana.
  ///
  /// El tinte cálido emparenta el fondo con el naranja de marca sin traer
  /// nada de saturación.
  ///
  /// [PENDIENTE DE APROBACIÓN] Este tono es PROPUESTA: no salió de
  /// ninguna constante previa del proyecto porque no había ninguna que
  /// sirviera.
  static const Color fondoDePantalla = Color(0xFFF3F1ED);

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

/// Escala de espaciado. Son CUATRO valores y no hay más: el ritmo
/// constante es lo que hace que una pantalla se lea como una sola cosa y
/// no como widgets sueltos.
///
/// Antes Home usaba 10, 12, 16, 20, 24 y 28 mezclados. La diferencia
/// entre 24 y 28 no se percibe, pero rompe el ritmo igual.
class AppSpacing {
  AppSpacing._();

  /// Entre cosas que son la misma idea (un dato y su etiqueta).
  static const double dentro = 8;

  /// Entre elementos hermanos de un mismo grupo.
  static const double entre = 16;

  /// Entre el encabezado de una sección y su contenido.
  static const double grupo = 24;

  /// Entre una sección y la siguiente. Es el corte grande.
  static const double seccion = 40;
}

class AppTheme {
  AppTheme._();

  /// Tracking correcto para un tamaño dado.
  ///
  /// Un `letterSpacing` fijo está mal en algún tamaño sí o sí: el texto
  /// grande se ve desarmado con las letras separadas, y el chico se
  /// vuelve ilegible si se le pega demasiado. Achica a medida que crece.
  static double trackingPara(double fontSize) {
    if (fontSize >= 48) return 0;
    if (fontSize >= 32) return 1;
    if (fontSize >= 20) return 2;
    return 2.5;
  }

  /// Display font (Bebas Neue) con el tracking ya ajustado al tamaño.
  static TextStyle display(double fontSize) => GoogleFonts.bebasNeue(
    color: AppColors.textPrimary,
    fontSize: fontSize,
    letterSpacing: trackingPara(fontSize),
    height: 1,
  );

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
      scaffoldBackgroundColor: AppColors.fondoDePantalla,
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

/// Tema de shadcn_ui armado desde los tokens de +Vida.
///
/// No se usa su paleta por defecto a propósito: los componentes de
/// shadcn tienen que verse como el resto de la app, no como shadcn.
final ShadThemeData temaShad = ShadThemeData(
  brightness: Brightness.light,
  colorScheme: const ShadColorScheme(
    background: AppColors.fondoDePantalla,
    foreground: AppColors.textPrimary,
    card: AppColors.card,
    cardForeground: AppColors.textPrimary,
    popover: AppColors.card,
    popoverForeground: AppColors.textPrimary,
    primary: AppColors.accent,
    primaryForeground: Colors.white,
    secondary: AppColors.cardBorder,
    secondaryForeground: AppColors.textPrimary,
    muted: AppColors.cardBorder,
    mutedForeground: AppColors.textSecondary,
    accent: AppColors.accentSecondary,
    accentForeground: Colors.white,
    destructive: Color(0xFFB3261E),
    destructiveForeground: Colors.white,
    border: AppColors.cardBorder,
    input: AppColors.cardBorder,
    ring: AppColors.accent,
    selection: AppColors.accent,
  ),
);

/// Envoltorio que pone el [temaShad] en el árbol.
///
/// Los componentes de shadcn_ui fallan si no encuentran un `ShadTheme`
/// arriba, así que TODA pantalla que se monte —la app real o un test—
/// tiene que pasar por acá. Ponerlo solo en el `builder` del MaterialApp
/// no alcanza: los tests montan pantallas sueltas y se quedaban sin tema.
class TemaVida extends StatelessWidget {
  const TemaVida({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ShadTheme(data: temaShad, child: child);
}
