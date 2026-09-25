import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../reglas_puntos.dart';
import '../theme.dart';
import 'avatar_usuario.dart';

/// Qué tan grande va la foto del usuario adentro de un escalón de
/// [alturaEscalon] píxeles.
///
/// Vive afuera del `build` para poder fijar en un test lo que importa: la
/// foto entra ENTERA en el escalón más bajo de la escalera —con su aro y
/// con su flechita— que es el que menos lugar tiene. Si no entrara, el
/// nivel 0 —donde arranca cualquiera que abre la app por primera vez—
/// mostraría una foto recortada.
///
/// El techo de 30 no es capricho: el escalón más alto mide 116 px pero
/// sigue siendo angosto (un quinto del ancho de la tarjeta), así que lo
/// que limita la foto es el ancho, no el alto. Ahí la foto no tiene que
/// llenar el escalón: es una marca de posición, y una marca chica se lee
/// como que está PARADA en la barra, no como que es la barra.
double diametroFotoEnEscalon(double alturaEscalon) =>
    (alturaEscalon - 18).clamp(22.0, 30.0);

/// Cuánto sobresale la flechita por debajo del aro de la foto.
const double _altoFlecha = 6;

/// Ancho de la base de la flechita, donde se pega al aro.
const double _anchoFlecha = 12;

/// Escalera de niveles de cashback: un escalón por nivel, cada uno más
/// alto que el anterior, y un solo renglón de detalle abajo que cambia
/// según el escalón que se toque.
///
/// Es interactiva a propósito: en vez de escupir de una todas las reglas
/// de todos los niveles, muestra una línea a la vez y deja que el usuario
/// explore la escalera con el dedo.
///
/// Los escalones salen de [niveles] (`reglas_puntos.dart`), así que los
/// niveles 1 y 2 aparecen como "pendiente de definir" en vez de con un
/// porcentaje inventado — CLAUDE.md lo prohíbe expresamente.
class EscaleraCashback extends StatefulWidget {
  const EscaleraCashback({
    super.key,
    required this.nivelActual,
    required this.puntosTotal,
    required this.techoActividad,
  });

  /// Nivel anual del usuario.
  final int nivelActual;

  /// Puntos acumulados en el año, para decir cuánto falta al siguiente.
  final int puntosTotal;

  /// Techo anual de puntos POR ACTIVIDAD FÍSICA (pasos + intensidad).
  /// Los chequeos médicos dan puntos aparte, que se suman por encima de
  /// este techo: por eso no es un techo de puntos del año.
  final int techoActividad;

  @override
  State<EscaleraCashback> createState() => _EscaleraCashbackState();
}

class _EscaleraCashbackState extends State<EscaleraCashback>
    with SingleTickerProviderStateMixin {
  /// Escalón que se está mirando. Arranca en el del usuario.
  late int _seleccionado = widget.nivelActual;

  /// Un solo reloj para el brillo de TODOS los escalones ganados: así
  /// barren en sincronía y se leen como una sola cosa, no como cinco
  /// animaciones sueltas.
  late final AnimationController _brillo;

  @override
  void initState() {
    super.initState();
    _brillo = AnimationController(
      vsync: this,
      // Muy lento y con pausa larga: el barrido ocupa poco más de la mitad
      // del ciclo y el resto es descanso. Un brillo continuo sobre fondo
      // claro cansa, y la app tiene que transmitir calma.
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _brillo.dispose();
    super.dispose();
  }

  void _seleccionar(int nivel) {
    if (nivel == _seleccionado) return;
    HapticFeedback.selectionClick();
    setState(() => _seleccionado = nivel);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sin alto fijo a propósito: el alto lo pone el escalón más alto
        // más sus dos textos. Con un `SizedBox` de alto fijo, cualquier
        // aumento del tamaño de letra del sistema desbordaba la fila —
        // que es de dónde venía el "BOTTOM OVERFLOWED BY 2.0 PIXELS".
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < niveles.length; i++) ...[
              Expanded(
                child: _Escalon(
                  nivel: niveles[i],
                  // El alto crece con la posición, no con el número de
                  // nivel: así la escalera sube pareja aunque mañana
                  // cambie la tabla.
                  posicion: i,
                  total: niveles.length,
                  alcanzado: niveles[i].numero <= widget.nivelActual,
                  esActual: niveles[i].numero == widget.nivelActual,
                  seleccionado: niveles[i].numero == _seleccionado,
                  brillo: _brillo,
                  onTap: () => _seleccionar(niveles[i].numero),
                ),
              ),
              if (i != niveles.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.entre),
        _Detalle(
          nivel: nivelPorNumero(_seleccionado),
          nivelActual: widget.nivelActual,
          puntosTotal: widget.puntosTotal,
          techoActividad: widget.techoActividad,
        ),
      ],
    );
  }
}

class _Escalon extends StatelessWidget {
  const _Escalon({
    required this.nivel,
    required this.posicion,
    required this.total,
    required this.alcanzado,
    required this.esActual,
    required this.seleccionado,
    required this.brillo,
    required this.onTap,
  });

  final Nivel nivel;
  final int posicion;
  final int total;
  final bool alcanzado;
  final bool esActual;
  final bool seleccionado;

  /// Reloj compartido del barrido de brillo.
  final Animation<double> brillo;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Cada escalón es más alto que el anterior: la escalera se lee como
    // progresión sin necesitar ninguna etiqueta que lo explique.
    //
    // El piso de 44 no es estético: es lo que hace que la foto del
    // usuario entre entera adentro del escalón más bajo, que es donde
    // arranca cualquiera que abre la app por primera vez.
    final altura = 44.0 + posicion * 18.0;
    // Verdes del sistema para el logro. El azul queda para la selección,
    // que es una acción del usuario.
    //
    // El nivel 0 nunca se pinta de verde aunque se haya "alcanzado":
    // paga 0% de cashback, y rellenarlo diría que ganaste algo.
    final premia = nivel.numero > 0;
    final lleno = alcanzado && premia;
    final verde = AppColors.colorForNivel(nivel.numero);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        // `min` es lo que deja que la fila se mida sola. Con `max` la
        // columna pide todo el alto disponible y la fila revienta apenas
        // el texto crece.
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            // Sin porcentaje definido no se inventa uno: se marca el hueco.
            nivel.definido ? '${_formatoPct(nivel.porcentajeCashback!)}%' : '—',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: alcanzado
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontWeight: seleccionado ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: altura,
            decoration: BoxDecoration(
              color: lleno
                  ? verde
                  : AppColors.cardBorder.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              // El azul marca lo que el usuario está tocando; el verde,
              // lo que ya ganó. Nunca al revés.
              border: seleccionado
                  ? Border.all(color: AppColors.accent, width: 2.5)
                  : null,
            ),
            // El contenido se recorta al escalón: el brillo no puede
            // asomarse por fuera de la barra.
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Brillo: solo en los escalones que el usuario ya ganó.
                if (lleno) _BarridoBrillo(brillo: brillo, alto: altura),
                // La FOTO del usuario parada en su escalón, en vez del
                // cartel "ESTÁS AQUÍ" que había antes.
                //
                // Un cartel hay que leerlo; una cara se reconoce sola, y
                // es la misma que el usuario ya tiene arriba a la derecha
                // en todas las pantallas. Lo que antes era una etiqueta
                // pasa a ser él parado en la escalera.
                //
                // El aro es lo que la separa de la barra: sobre el azul
                // lleno va blanco, y sobre el escalón vacío del nivel 0
                // —que es gris clarito— el blanco desaparecería, así que
                // ahí va el azul de marca.
                if (esActual)
                  Center(
                    child: Semantics(
                      label: 'Estás en el nivel ${nivel.numero}',
                      child: _FotoParadaEnElEscalon(
                        diametro: diametroFotoEnEscalon(altura),
                        color: lleno ? Colors.white : AppColors.accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${nivel.numero}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: seleccionado ? AppColors.accent : AppColors.textSecondary,
              fontWeight: seleccionado ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// La foto del usuario con una flechita abajo, parada en su escalón.
///
/// El aro solo despega la foto de la barra; lo que dice DÓNDE está parado
/// es la punta. Sin ella la foto flota en el medio del escalón y se lee
/// como un adorno de la barra; con ella apunta a un lugar, que es
/// exactamente lo que hacía el cartel "ESTÁS AQUÍ" que reemplazó.
///
/// La punta se dibuja como la mitad de abajo de un cuadrado girado 45°, no
/// con un `CustomPainter`: es un recorte de una caja, y CLAUDE.md deja el
/// pincel propio para cuando ninguna otra cosa alcanza.
class _FotoParadaEnElEscalon extends StatelessWidget {
  const _FotoParadaEnElEscalon({required this.diametro, required this.color});

  final double diametro;

  /// Color del aro y de la flecha: los dos tienen que ser el MISMO, o la
  /// punta se lee como una pieza suelta pegada abajo.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarUsuario(diametro: diametro, borde: color, grosorBorde: 2),
        // Medio píxel de solape: el aro es redondo y la base de la flecha
        // es recta, así que pegados al ras queda una hendidura blanca.
        Transform.translate(
          offset: const Offset(0, -0.5),
          child: ClipRect(
            child: Align(
              alignment: Alignment.bottomCenter,
              // Solo la mitad de abajo del rombo: eso es un triángulo que
              // apunta hacia el escalón.
              heightFactor: 0.5,
              child: SizedBox(
                width: _anchoFlecha,
                height: _altoFlecha * 2,
                child: Center(
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    // Un cuadrado de lado d/√2 girado mide d de diagonal:
                    // así la punta cae justo en el borde de la caja.
                    child: Container(
                      width: _anchoFlecha / math.sqrt2,
                      height: _anchoFlecha / math.sqrt2,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Alto de la franja de luz del barrido. Generosa a propósito: una franja
/// ancha y muy tenue se lee como luz; una angosta y fuerte, como una barra
/// que pasa.
const double bandaAltoBrillo = 56;

/// Qué parte del ciclo del brillo ocupa el barrido. El resto es pausa.
const double _tramoBarrido = 0.55;

/// Dónde va la franja de brillo para un valor del reloj (0 a 1), dentro de
/// un escalón de [alto] píxeles.
///
/// Vive afuera del `build` para poder testear el invariante que importa:
/// al terminar el barrido la franja tiene que quedar COMPLETAMENTE fuera
/// del escalón. Si termina adentro, se queda clavada ahí durante la pausa
/// y después salta — que es exactamente como se ve un tirón.
double desplazamientoBrillo(double reloj, double alto) {
  final t = (reloj / _tramoBarrido).clamp(0.0, 1.0);
  return alto - t * (alto + bandaAltoBrillo);
}

/// Banda de luz que sube por un escalón ganado.
///
/// Es un BARRIDO, no un glow: una franja blanca translúcida que viaja por
/// dentro del escalón y sale. CLAUDE.md prohíbe los glows sobre fondo
/// claro porque florecen hacia afuera; esto queda recortado adentro de la
/// barra y no ilumina nada alrededor.
class _BarridoBrillo extends StatelessWidget {
  const _BarridoBrillo({required this.brillo, required this.alto});

  final Animation<double> brillo;
  final double alto;

  @override
  Widget build(BuildContext context) {
    // Respeta "reducir movimiento" del sistema: ahí el escalón se queda
    // quieto en vez de barrer.
    if (MediaQuery.of(context).disableAnimations) {
      return const SizedBox.shrink();
    }

    // Aislado del resto del escalón: sin esto, cada frame del barrido
    // manda a repintar toda la escalera, y ahí es donde se siente trabado.
    return RepaintBoundary(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: brillo,
          builder: (context, child) {
            // Avance LINEAL, a propósito. Antes había una curva
            // easeInOutSine acá: frenaba la franja justo al final del
            // recorrido, que es donde más se notaba el tirón. Como la
            // franja entra y sale fuera de la barra, no hay arranque ni
            // frenada que disimular — la velocidad constante es lo que se
            // lee como luz que pasa.
            final y = desplazamientoBrillo(brillo.value, alto);
            return Transform.translate(offset: Offset(0, y), child: child);
          },
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: bandaAltoBrillo,
              // Sin esto la franja no tiene ancho: el Align la deja
              // encogerse a cero.
              width: double.infinity,
              // Se difumina en los dos extremos: una franja de bordes
              // duros se leería como una barra, no como luz.
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    // Apenas perceptible: el brillo tiene que notarse de
                    // reojo, no pedir atención.
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 10.0 -> "10", 7.5 -> "7,5". Coma decimal, que es lo que se usa acá.
String _formatoPct(double v) =>
    v == v.roundToDouble() ? '${v.round()}' : v.toString().replaceAll('.', ',');

/// El único renglón de texto de la escalera. Cambia con el escalón que se
/// toca, en vez de mostrar todas las reglas de todos los niveles a la vez.
class _Detalle extends StatelessWidget {
  const _Detalle({
    required this.nivel,
    required this.nivelActual,
    required this.puntosTotal,
    required this.techoActividad,
  });

  final Nivel? nivel;
  final int nivelActual;
  final int puntosTotal;
  final int techoActividad;

  static String _miles(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );

  /// Título corto y línea de apoyo, según en qué estado cae el nivel.
  (String, String) get _texto {
    final n = nivel;
    if (n == null) return ('Nivel', '');

    if (!n.definido) {
      return (
        'Nivel ${n.numero} · pendiente',
        'Todavía no está fijado cuántos puntos pide ni qué cashback da',
      );
    }
    // El nivel 0 no paga nada, así que se dice qué hacer para salir de
    // ahí en vez de anunciarle a alguien un "0% de cashback".
    if (n.numero == 0) {
      final siguiente = nivelPorNumero(1);
      return (
        n.numero == nivelActual
            ? 'Todavía sin cashback'
            : 'El punto de partida',
        'Llegá a ${_miles(siguiente!.puntosMinimos!)} pts en el año para '
            'empezar a ganar el ${_formatoPct(siguiente.porcentajeCashback!)}%',
      );
    }
    if (n.numero == nivelActual) {
      // El aviso regulatorio (se devuelve DESPUÉS de pagar la prima) ya
      // no vive acá: es permanente y va al pie de la tarjeta, para que no
      // dependa de qué escalón esté tocando el usuario.
      return (
        'Acá estás',
        '${n.rangoTexto} · te devuelve el '
            '${_formatoPct(n.porcentajeCashback!)}% de tu prima',
      );
    }
    if (n.numero < nivelActual) {
      return ('Nivel alcanzado', n.rangoTexto);
    }
    final faltan = 'Te faltan ${_miles(n.puntosMinimos! - puntosTotal)} pts';

    // Arriba del techo de actividad NO es "fuera de alcance": los puntos
    // de los chequeos médicos se suman POR ENCIMA de ese techo, así que
    // el nivel sí se alcanza — pero no caminando más.
    //
    // Cuánto paga un chequeo todavía no está definido, así que el texto
    // no nombra ninguna cifra de chequeos. Solo señala el camino.
    // El nivel 4 arranca justo donde topa la actividad física, así que la
    // comparación es >=, no >. Con > el mensaje se apagaba solo.
    if (n.puntosMinimos! >= techoActividad) {
      return (
        faltan,
        'La actividad física llega hasta ${_miles(techoActividad)} pts al '
            'año. Los chequeos médicos suman aparte y son los que te '
            'llevan hasta acá.',
      );
    }
    return (faltan, n.rangoTexto);
  }

  @override
  Widget build(BuildContext context) {
    final (titulo, apoyo) = _texto;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        // Cruza el texto viejo con el nuevo para que se lea como que el
        // mismo renglón cambió, no como que apareció otro.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Column(
            key: ValueKey(titulo),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (apoyo.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  apoyo,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
