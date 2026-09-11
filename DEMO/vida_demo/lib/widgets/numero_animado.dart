import 'package:flutter/material.dart';

import '../datos/fuente_datos.dart';

// ============================================================
// LOS NÚMEROS GRANDES SUBEN DESDE 0.
//
// Solo para CANTIDADES que el usuario acumula: pasos, puntos, cashback,
// monedas. Nunca para etiquetas — "Nivel 3", la posición del ranking, un
// porcentaje o una fecha no se acumulan, y verlas girar convierte la app
// en una tragamonedas.
//
// CUÁNDO se anima: una vez por cada tanda de datos, no cada vez que un
// widget se monta. Ver [animacionPendiente].
//
// Acá vive también la maquinaria que comparten los DEMÁS elementos que
// crecen con la tanda de datos —hoy las gráficas de Progreso, ver
// [CrecerAlRefrescar]—, porque la compuerta tiene que ser una sola: si
// las gráficas llevaran la suya, el número y su gráfica se animarían en
// momentos distintos y la pantalla se vería descoordinada.
// ============================================================

/// Cuánto tarda un número en llegar a su valor.
///
/// La misma que usa el llenado del aro de Home, para que el número del
/// centro y el aro terminen juntos. Si se cambia una, se cambian las dos.
const Duration duracionNumeroAnimado = Duration(milliseconds: 800);

/// Arranca rápido y frena al final.
///
/// Con `linear` el número sube a paso constante y se lee como un
/// contador de gasolinera. Frenando cerca del final parece que llega a
/// un valor, que es lo que es.
const Curve curvaNumeroAnimado = Curves.easeOutCubic;

/// Miles con separador de coma: 12480 -> "12,480".
///
/// ESTA es la única implementación en toda la app. Antes había tres
/// idénticas —`TextoCentroAnillo.formatearMiles`, `_HomeFormato.miles` y
/// `_milesGrafica` de la tarjeta de puntos—, cada una escrita distinto.
/// Daban lo mismo hoy, pero nada garantizaba que siguieran dando lo
/// mismo: alcanzaba con que alguien tocara una para que la app mostrara
/// "12,480" en una pantalla y "12480" en otra. Las tres siguen
/// existiendo con su nombre, pero ahora llaman acá.
///
/// Se llama distinto que las tres a propósito: `TextoCentroAnillo` tiene
/// un método estático `formatearMiles`, y con el mismo nombre la llamada
/// de adentro de esa clase se resolvería a sí misma y se colgaría en una
/// recursión infinita.
String milesConComa(int valor) => valor.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

// ============================================================
// LA COMPUERTA: UNA ANIMACIÓN POR TANDA DE DATOS.
// ============================================================

/// La última tanda de datos cuya animación ya se reprodujo.
///
/// Arranca en -1 —ninguna— para que la primera vez que la app pinta sus
/// números, después de la pantalla de carga, sí se animen.
int _generacionYaAnimada = -1;

/// ¿Le toca animar a un widget que se está montando o actualizando ahora?
///
/// Existe porque "animar al montarse" NO es lo que se quiere. La barra de
/// abajo navega con `pushReplacementNamed`, así que cambiar de pestaña
/// desmonta la pantalla entera y monta la siguiente de cero: si cada
/// widget animara al montarse, los números volverían a subir desde 0 en
/// CADA cambio de pestaña, y eso cansa a los tres toques.
///
/// La animación pertenece a la TANDA DE DATOS, no al widget. Se reproduce
/// una sola vez por tanda: al abrir la app y en cada refresco. Después de
/// eso, ir y volver entre pantallas muestra los números ya escritos.
///
/// La marca de "ya se animó" se pone en el post-frame y no en el acto,
/// porque en una pantalla hay varios números: si el primero en montarse
/// cerrara la compuerta, los demás se quedarían quietos. Todos los que se
/// monten en el mismo cuadro entran juntos.
bool animacionPendiente(int generacion) {
  if (generacion == _generacionYaAnimada) return false;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _generacionYaAnimada = generacion;
  });
  return true;
}

/// Solo para tests: borra la marca para que la próxima animación corra.
@visibleForTesting
void reiniciarCompuertaAnimacion() => _generacionYaAnimada = -1;

// ============================================================
// LO QUE NO ES UN NÚMERO Y TAMBIÉN CRECE.
// ============================================================

/// Entrega un avance de 0 a 1 cada vez que llega una tanda de datos.
///
/// Es [NumeroAnimado] sin el texto: la misma compuerta, la misma duración
/// y la misma curva, pero el que dibuja decide qué hacer con el avance.
/// Las gráficas de Progreso lo usan para levantar la línea y las barras
/// desde la base, así que terminan de crecer en el mismo instante en que
/// el número grande de arriba llega a su valor.
///
/// Por qué no alcanzaba la animación que ya trae fl_chart: esa es una
/// animación de CAMBIO —interpola de los datos viejos a los nuevos—, y
/// un refresco suele traer los mismos datos. Sin diferencia que
/// interpolar no se movía nada, que es justo lo que se veía: el número
/// subía y la gráfica se quedaba quieta.
///
/// Con "Reducir movimiento" el avance es 1 desde el primer cuadro y
/// [animando] es false: nada se mueve y los tests leen el valor final.
class CrecerAlRefrescar extends StatefulWidget {
  const CrecerAlRefrescar({super.key, required this.builder});

  /// [avance] va de 0 a 1 ya pasado por la curva. [animando] dice si en
  /// este cuadro el crecimiento está en curso, para que quien dibuja
  /// pueda apagar mientras tanto cualquier OTRA animación que le pise la
  /// suya.
  final Widget Function(BuildContext context, double avance, bool animando)
  builder;

  @override
  State<CrecerAlRefrescar> createState() => _CrecerAlRefrescarState();
}

class _CrecerAlRefrescarState extends State<CrecerAlRefrescar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: duracionNumeroAnimado,
    );
    // Terminado por defecto: solo se rebobina si a esta tanda de datos
    // todavía se le debe la animación.
    _controlador.value = 1;
    datosRecargados.addListener(_alRefrescar);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Acá y no en initState porque hace falta el MediaQuery.
    if (!MediaQuery.disableAnimationsOf(context) &&
        animacionPendiente(datosRecargados.value)) {
      _controlador.forward(from: 0);
    }
  }

  void _alRefrescar() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (!animacionPendiente(datosRecargados.value)) return;
    _controlador.forward(from: 0);
  }

  @override
  void dispose() {
    datosRecargados.removeListener(_alRefrescar);
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.builder(context, 1, false);
    }

    return AnimatedBuilder(
      animation: _controlador,
      builder: (context, _) => widget.builder(
        context,
        curvaNumeroAnimado.transform(_controlador.value),
        _controlador.isAnimating,
      ),
    );
  }
}

/// Un número que sube desde 0 hasta [valor].
///
/// Es un reemplazo directo de un `Text`: ocupa exactamente lo mismo que
/// ocuparía el texto final, así que se puede meter donde había uno sin
/// mover nada de la pantalla.
class NumeroAnimado extends StatefulWidget {
  const NumeroAnimado({
    super.key,
    required this.valor,
    required this.formato,
    required this.estilo,
    this.alineacion = Alignment.centerLeft,
  });

  /// El valor al que tiene que llegar.
  final int valor;

  /// Cómo se escribe. Se recibe de afuera y no se formatea acá adentro
  /// para que cada lugar siga usando el formato que ya tenía —incluido
  /// el prefijo, como la "Q" del cashback.
  final String Function(int) formato;

  final TextStyle estilo;

  /// Hacia dónde queda pegado el número mientras es más corto que su
  /// valor final. Centrado adentro del aro, a la izquierda en todo lo
  /// que vive en un renglón.
  final Alignment alineacion;

  @override
  State<NumeroAnimado> createState() => _NumeroAnimadoState();
}

class _NumeroAnimadoState extends State<NumeroAnimado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: duracionNumeroAnimado,
    );
    // Por defecto el número se muestra terminado. Solo se rebobina si a
    // esta tanda de datos todavía le debemos la animación.
    _controlador.value = 1;

    // Cada refresco es una tanda nueva: el número vuelve a subir desde 0.
    datosRecargados.addListener(_alRefrescar);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Acá y no en initState porque hace falta el MediaQuery.
    if (!MediaQuery.disableAnimationsOf(context) &&
        animacionPendiente(datosRecargados.value)) {
      _controlador.forward(from: 0);
    }
  }

  void _alRefrescar() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (!animacionPendiente(datosRecargados.value)) return;
    _controlador.forward(from: 0);
  }

  @override
  void dispose() {
    datosRecargados.removeListener(_alRefrescar);
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Todos los dígitos del MISMO ancho. Sin esto, subiendo de 0 a
    // 12,480 cada cifra cambia de ancho al pasar (un 1 es más angosto
    // que un 8) y el número tiembla mientras cuenta.
    final estiloFirme = widget.estilo.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // Con "Reducir movimiento" activo el número aparece ya escrito, sin
    // ningún andamio alrededor. Es lo que además mantiene sanos a los
    // tests: `test/ayudas.dart` monta TODAS las pantallas con las
    // animaciones apagadas, y un test que hace un solo `pump` tiene que
    // leer el valor final, no un 0.
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(widget.formato(widget.valor), style: estiloFirme);
    }

    return Stack(
      children: [
        // Fantasma invisible: es el que le da el tamaño al conjunto.
        //
        // El ancho tiene que ser SIEMPRE el del valor final, porque de 0
        // a 12,480 el número pasa por 1, 2, 3, 4 y 5 dígitos y va
        // sumando comas. Sin esta reserva, cada dígito nuevo empuja lo
        // que tenga al lado ("de 12,000 pts" saltando en cada cifra).
        Opacity(
          opacity: 0,
          child: Text(widget.formato(widget.valor), style: estiloFirme),
        ),
        // El que cuenta va encima y NO opina sobre el tamaño: lo dibuja
        // el fantasma.
        Positioned.fill(
          child: Align(
            alignment: widget.alineacion,
            child: AnimatedBuilder(
              animation: _controlador,
              builder: (context, _) {
                final avance = curvaNumeroAnimado.transform(_controlador.value);
                return Text(
                  widget.formato((widget.valor * avance).round()),
                  style: estiloFirme,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
