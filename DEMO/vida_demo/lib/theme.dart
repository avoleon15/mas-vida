import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
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

  // ============================================================
  // LA ESCALA DE AZULES.
  //
  // Toda la app se pinta con estos cinco tonos del MISMO azul de marca.
  // Lo que cambia entre uno y otro es la luminosidad, nunca el matiz: así
  // se leen como una sola familia y no como cinco colores distintos.
  //
  // Cuanto más grande la superficie, más pálido el tono. El azul entero
  // (`accent`) es solo para lo chico y decidido: un botón, un número, un
  // ícono.
  //
  //   azulNiebla  -> fondos de tarjeta enteros
  //   azulBruma   -> tintes y rellenos de estado
  //   azulSuave   -> bordes, separadores con color
  //   azulMedio   -> texto secundario con color, íconos de apoyo
  //   accent      -> botones, números grandes, lo que decide
  // ============================================================

  /// Casi blanco con azul adentro. Para el fondo de una tarjeta entera.
  static const Color azulNiebla = Color(0xFFF2F4FB);

  /// Un paso más presente. Relleno de un estado activo o seleccionado.
  static const Color azulBruma = Color(0xFFE4E9F8);

  /// Bordes y separadores que necesitan color en vez de gris.
  static const Color azulSuave = Color(0xFFB9C4E8);

  /// Íconos y texto de apoyo que tienen que leerse sin gritar.
  static const Color azulMedio = Color(0xFF5468BC);

  /// Un paso INTERMEDIO entre [azulBruma] y [azulSuave].
  ///
  /// Existe para las sombras sólidas de las piezas apagadas: sobre
  /// azulBruma, una sombra en azulSuave se ve como un borde y no como
  /// volumen. No es un sexto color: es el mismo azul, derivado de dos
  /// tonos que ya existen, así que si el azul de marca cambia este lo
  /// sigue solo.
  static final Color azulTenue = Color.lerp(azulBruma, azulSuave, 0.4)!;

  /// El azul de marca oscurecido, para las sombras sólidas.
  ///
  /// Derivado y no escrito a mano por lo mismo que en `boton_relieve.dart`:
  /// un hex suelto se despega del resto de la paleta en cuanto alguien
  /// toca el azul.
  static final Color azulSombra = Color.lerp(accent, Colors.black, 0.28)!;

  /// El separador de una lista: el azul de los bordes, diluido.
  ///
  /// Es lo que reemplaza a una tarjeta cuando lo que hay que mostrar es
  /// una LISTA. Una lista de personas, de entrenamientos o de grupos en
  /// iOS se separa con una línea de un pelo, no metiendo cada renglón en
  /// su propia caja con borde.
  static final Color separador = azulSuave.withValues(alpha: 0.45);

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

  /// Rojo de acción destructiva: cerrar sesión, borrar la cuenta.
  ///
  /// Es la ÚNICA excepción a la paleta azul/naranja/blanco, y no es una
  /// decisión estética: en iOS el rojo significa "esto deshace algo" y
  /// el usuario ya lo lee así antes de leer el texto. Pintar de azul un
  /// botón de cerrar sesión lo haría ver como una acción más.
  ///
  /// No usarlo para nada que no destruya o revierta algo.
  static const Color peligro = Color(0xFFB3261E);

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
  // cashback: son solo la lectura visual de en qué
  // escalón de la tabla de pasos va el usuario HOY, y se reinician cada
  // día.
  //
  // El gris es deliberado: ese tramo (0 a 7.000) no paga ni un punto, y
  // tiene que verse apagado para que el salto a plata se sienta como que
  // algo se prendió.
  //
  // Oro en su valor estándar (`gold` del estándar CSS). Bronce y plata
  // NO: los dos van bajados a mano respecto del canónico, y cada uno por
  // su motivo (ver abajo).
  //
  // ACCESIBILIDAD — no "corregir" estos tres valores por gusto estético
  // sin volver a revisar la luminosidad. Se usan con un usuario daltónico,
  // así que lo que los separa NO puede ser el matiz. Por suerte los
  // metales estándar ya vienen bien escalonados: L* ≈ 60, 78 y 87. Además
  // bronce y oro nunca se tocan (siempre hay plata completa en medio), que
  // es el par que más se podría confundir por ser los dos cálidos.
  //
  // La plata está BAJADA respecto del `silver` de CSS (#C0C0C0, L* ≈ 78):
  // ese valor se pensó contra el bronce que tiene debajo, pero la plata es
  // el aro que más superficie ocupa y el que se dibuja contra el fondo casi
  // blanco de la app. A L* 78 contra un fondo #F5F6FA el aro se desvanecía.
  // Bajada a L* ≈ 70 se despega del fondo sin dejar de leerse como metal
  // claro, y sigue bien separada del bronce (L* ≈ 55) y del oro (L* ≈ 87).
  // El bronce va apagado a propósito (el estándar #CD7F32 es bastante más
  // naranja y saturado): es el tramo que no paga puntos, tiene que verse
  // mate al lado del brillo de la plata.
  static const Color aroBronce = Color(0xFFA0764A);
  static const Color aroPlata = Color(0xFFAAAAAA);
  static const Color aroOro = Color(0xFFFFD700);

  // Reflejos metálicos de los tres aros. Cada uno es un degradado que le
  // da la vuelta al trazo: dos brillos por vuelta, como un metal pulido.
  // El primer y el último color de cada lista son el mismo para que el
  // degradado circular cierre sin costura.
  //
  // ACCESIBILIDAD — el brillo se hace así, con contraste INTERNO, y no
  // subiéndole la luminosidad al color plano. Cada rampa está armada para
  // que la luminosidad PROMEDIO del metal se mantenga en su lugar
  // (bronce L* ≈ 55, plata ≈ 70, oro ≈ 86) y los tres sigan separados.
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

  // La plata es la rampa MÁS ABIERTA de las tres, a propósito: va de
  // casi blanco a un gris bien plantado. El brillo de un metal es el
  // salto entre su reflejo y su sombra, no lo claro que sea el promedio
  // — una plata pareja se ve como cartulina gris. Las sombras hacen que
  // el aro no se pierda contra el fondo casi blanco, y los reflejos son
  // los que lo hacen ver pulido.
  static const List<Color> brilloPlata = [
    Color(0xFF6F7B84),
    Color(0xFFFBFCFD),
    Color(0xFF8C99A2),
    Color(0xFFFBFCFD),
    Color(0xFF6F7B84),
  ];

  // Los tres metales en versión TINTA: texto, íconos, y cualquier
  // círculo o pastilla rellena que tenga contenido blanco adentro.
  //
  // Por qué no se usa el metal del aro para eso: el color del aro está
  // pensado para un TRAZO sobre fondo claro. El oro #FFD700 con una
  // check blanca encima no se lee, y la plata tampoco. Estos tres pasan
  // 4,5:1 contra blanco, así que sirven de texto.
  //
  // Siguen siendo reconociblemente bronce, plata y oro: lo que baja es
  // la luminosidad, nunca el matiz — la misma regla que separa los
  // niveles de cashback.
  //
  // Los tres pasan 4,5:1 sobre blanco, que es el fondo de la tarjeta
  // donde se usan, y de sobra sobre el gris apagado de una tarjeta
  // bloqueada.
  //
  // Esta terna NO tiene que separarse en escala de grises, a diferencia
  // de la de los aros. Un aro es uno de tres arcos del mismo anillo y
  // ahí el color es lo único que los distingue; una tinta siempre va
  // adentro de una tarjeta que ya se identifica por su lavado, su
  // número y su ícono.
  static const Color tintaBronce = Color(0xFF6A4A2C);
  static const Color tintaPlata = Color(0xFF5A646B);
  static const Color tintaOro = Color(0xFF765D00);

  /// El metal de un tramo del anillo, en sus dos versiones.
  ///
  /// [i] es el índice del tramo: 0 bronce, 1 plata, 2 oro. Se pide por
  /// índice y no por color para que nadie tenga que mapear un hex a
  /// mano y se le escape uno.
  ///
  /// NO hay una tercera versión para rellenar superficies: el metal se
  /// usa en el trazo del anillo y en lo chico de una tarjeta (borde,
  /// círculo, pastilla), nunca de fondo.
  static ({Color aro, Color tinta}) metal(int i) => switch (i) {
    0 => (aro: aroBronce, tinta: tintaBronce),
    1 => (aro: aroPlata, tinta: tintaPlata),
    _ => (aro: aroOro, tinta: tintaOro),
  };

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
  // Los dos salen del accent #012096, así que combinan con los azules del
  // resto de la app. OJO: los dos son OPACOS a propósito. Un fondo con
  // alpha deja pasar lo que hay detrás y la tarjeta se ensucia.
  //
  // Relleno: el accent mezclado con blanco, para que dé color sin pelearse
  // con el texto oscuro que va encima.
  static const Color tarjetaAzulClaro = Color(0xFFDDE3F7);

  // La franja que gira por el borde. Es el accent tal cual: sólida, un
  // solo tono, sin degradado.
  static const Color tarjetaBordeAzul = accent;

  /// Fondo de la pantalla, con las tarjetas de contenido en blanco puro.
  /// El contraste entre los dos es lo que da profundidad; antes fondo y
  /// tarjetas eran casi el mismo blanco y la pantalla se veía plana.
  ///
  /// UNA SOLA TEMPERATURA (decisión de Daniel, 21 de septiembre de 2026).
  /// Era #F3F1ED, un beige cálido, mientras que el borde de tarjeta
  /// [cardBorder] es azulado. Esas dos son las superficies que más lugar
  /// ocupan en la app, y mezclarles la temperatura es lo que daba la
  /// sensación de que nada terminaba de verse fino: el ojo no lo nombra,
  /// pero lo registra como suciedad.
  ///
  /// Ahora es el mismo valor que [background], o sea el azul de la
  /// familia diluido hasta casi blanco. Toda la app —fondo, bordes,
  /// tintes, tinta— es el mismo azul en distintas luminosidades.
  static const Color fondoDePantalla = background;

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

/// Los radios de la app. Son DOS y no hay más.
///
/// Había diez mezclados —10, 12, 14, 16, 18, 24, 28— y esa es una de las
/// razones por las que la app se leía como armada de a pedazos: dos
/// tarjetas hermanas con 16 y 18 no se ven distintas, se ven mal hechas.
class AppRadios {
  AppRadios._();

  /// Cualquier superficie: tarjetas, hojas modales, tintes de bloque.
  static const double tarjeta = 18;

  /// Cualquier cosa con forma de pastilla: chips, badges, barras de
  /// progreso, botones redondeados.
  static const double pildora = 999;
}

/// Las sombras de la app.
///
/// UNA SOLA CAPA, muy abierta y casi invisible. Es lo que reemplaza al
/// `border: Border.all(color: cardBorder)` que llevaba cada tarjeta: un
/// borde dibujado en las cuatro esquinas hace que la pantalla se vea
/// trazada con lápiz, mientras que una sombra difusa se lee como papel
/// apoyado sobre el fondo.
///
/// Nunca un glow (ver CLAUDE.md): el color es el azul de marca con
/// muchísima transparencia, no un halo de color saturado.
class AppSombras {
  AppSombras._();

  /// Tarjeta común, apoyada sobre el fondo de la pantalla.
  static List<BoxShadow> get tarjeta => [
    BoxShadow(
      color: AppColors.accent.withValues(alpha: 0.05),
      blurRadius: 24,
      offset: const Offset(0, 6),
    ),
  ];
}

class AppTheme {
  AppTheme._();

  /// Tracking correcto para un tamaño dado.
  ///
  /// Un `letterSpacing` fijo está mal en algún tamaño sí o sí. La regla
  /// es la de Apple: cuanto MÁS grande el texto, MÁS pegadas van las
  /// letras. Al crecer, el espacio entre ellas crece solo y el título se
  /// desarma; al achicar, hace falta abrirlo para que se lea.
  ///
  /// Por eso los tamaños grandes dan negativo. Con Bebas Neue esta
  /// función devolvía siempre positivo, porque una condensada necesita
  /// que la separen; Archivo es de ancho normal y necesita lo contrario.
  static double trackingPara(double fontSize) {
    if (fontSize >= 48) return -1.5;
    if (fontSize >= 32) return -0.8;
    if (fontSize >= 20) return -0.2;
    return 0.2;
  }

  /// Display font (Archivo) con el tracking ya ajustado al tamaño.
  ///
  /// Es la que llevan los números grandes: los pasos del día, los puntos,
  /// la racha. Va en w700 porque Archivo en peso normal no aguanta el
  /// tamaño — al lado de Manrope se vería como texto agrandado y no como
  /// un número protagonista.
  static TextStyle display(double fontSize) => GoogleFonts.archivo(
    color: AppColors.textPrimary,
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    letterSpacing: trackingPara(fontSize),
    height: 1,
  );

  // SF Pro es propietaria de Apple: solo se puede usar en apps para
  // plataformas Apple, y esta también corre en Web.
  //
  // El reemplazo es Manrope, no Inter. Inter es el clon más parecido a SF
  // Pro, pero es también la fuente por defecto de medio internet: una app
  // en Inter no se lee como diseñada, se lee como sin terminar. Manrope
  // tiene las mismas virtudes que hacían falta —contadores abiertos y
  // buena lectura en 11-13 pt, que es donde vive casi todo el texto de
  // +Vida— con terminaciones más suaves. Le queda mejor a una app que
  // tiene que transmitir calma.
  static final TextTheme _textTheme =
      GoogleFonts.manropeTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      );

  /// Título de pantalla: "SOCIAL", "PROGRESO", "MI PLAN".
  ///
  /// Va en Archivo, la misma display font de los números, para que la
  /// app hable con dos voces y no con tres.
  ///
  /// EN EL AZUL DE MARCA, no en el gris oscuro del texto. Era
  /// `textPrimary` y se leía como un encabezado más de la pantalla, no
  /// como su nombre — sobre todo en las pantallas que arrancan con una
  /// tarjeta grande a pocos píxeles debajo, donde el título quedaba
  /// tapado por lo que venía después. En azul de marca el nombre de la
  /// pantalla se lee de una y hace juego con los números grandes, que
  /// son el otro azul entero de la app.
  ///
  /// El tamaño bajó de 34 a 26 al cambiar de fuente, y no es un capricho:
  /// Bebas Neue es condensada y a 34 ocupaba lo que Archivo ocupa a 26.
  /// Manteniendo el 34 los títulos largos ("TUS RÉCORDS") se salían de
  /// pantalla en un iPhone angosto. De 26 subió a 30, que es lo que
  /// aguanta "TUS RÉCORDS" en un iPhone SE sin cortarse.
  static TextStyle get sectionTitle => GoogleFonts.archivo(
    color: AppColors.accent,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.6,
    height: 1.05,
  );

  /// Subtítulo de sección: "DIARIO", "SEMANAL", "ANUAL" en Home.
  ///
  /// Es el [sectionTitle] en chico: la MISMA fuente, el mismo peso y el
  /// mismo azul de marca, a 12 px en vez de 30. Así un subtítulo se lee
  /// como pariente del título de la pantalla —la app habla con una sola
  /// voz— pero sin pelearle la atención: lo que tiene que resaltar en
  /// Home son los números, no los rótulos que los ordenan.
  ///
  /// El tracking va amplio (2,4) porque a 12 px y en mayúsculas las
  /// letras se apelmazan. Es la regla de Apple al revés: cuanto más
  /// chico el texto, más hay que abrirlo.
  ///
  /// Era `labelSmall` en `textSecondary`, o sea gris y en Manrope: se
  /// leía como una nota al margen y no como el encabezado de un bloque.
  static TextStyle get subsectionTitle => GoogleFonts.archivo(
    color: AppColors.accent,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.4,
    height: 1.1,
  );

  static ThemeData get temaClaro {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.fondoDePantalla,
      primaryColor: AppColors.accent,
      // TODAS las plataformas entran deslizándose como iOS, no solo
      // iOS. Sin esto, la demo en Chrome usa el zoom de Android: una
      // pantalla que entra creciendo desde el centro es de Material, y
      // +Vida tiene que sentirse nativa de iOS (ver CLAUDE.md). De paso
      // es más barato de animar que el zoom, que escala la pantalla
      // entera cuadro por cuadro.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final plataforma in TargetPlatform.values)
            plataforma: const CupertinoPageTransitionsBuilder(),
        },
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.accentSecondary,
        surface: AppColors.card,
        // BLANCO, no negro. `accent` es #012096, un azul casi noche:
        // encima de él el texto negro no se lee. Decía negro desde
        // cuando el azul de marca era claro; al oscurecerlo quedó así y
        // los botones de Premios se volvieron ilegibles.
        onPrimary: Colors.white,
        // El naranja es claro, así que ahí manda el texto oscuro.
        onSecondary: AppColors.textPrimary,
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
      // Un botón azul de +Vida se ve igual en toda la app y su texto
      // SIEMPRE es blanco. Definido acá y no en cada pantalla: así nadie
      // vuelve a escribir un botón con texto negro sobre azul.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.cardBorder,
          disabledForegroundColor: AppColors.textSecondary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
    destructive: AppColors.peligro,
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
