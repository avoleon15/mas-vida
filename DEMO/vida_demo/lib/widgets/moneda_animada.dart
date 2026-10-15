import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme.dart';

// ============================================================
// LA MONEDA, UNA SOLA PARA TODA LA APP.
//
// Antes cada lugar dibujaba `Icons.monetization_on`. Ahora es una
// animación de LottieFiles ("coin rotation"), y vive acá para que no
// vuelva a haber diez monedas distintas girando a diez velocidades.
//
// El archivo es un .lottie (un zip con el JSON adentro): el paquete
// `lottie` lo abre sin ayuda, `decodeZip` es su decodificador por
// defecto.
//
// Regla dura del proyecto: esto es una MONEDA, la que se gasta en
// Premios. Nunca se usa para puntos.
// ============================================================

/// Ruta del .lottie. En un solo lugar para no repetirla en cada pantalla.
const String _rutaMoneda = 'assets/lottie/moneda.lottie';

/// Cuánto tarda la moneda en dar una vuelta completa.
///
/// De fábrica la animación dura 2,55 s (153 cuadros a 60 fps) y gira
/// demasiado rápido para un ícono que está en pantalla todo el tiempo:
/// a esa velocidad se lee como una alerta.
///
/// Ojo: el giro NO es parejo. La vuelta entera pasa en el primer tercio
/// de la línea de tiempo y los otros dos tercios la moneda queda casi
/// quieta de frente. Por eso 7,5 s todavía se sentían rápidos: el volteo
/// real duraba 2,5. A 12 s el volteo tarda unos 4 s y después hay una
/// pausa larga de descanso, que es lo que se quería.
const Duration _duracionGiro = Duration(seconds: 12);

/// Cuánto hay que acercar el dibujo para que la moneda llene su caja.
///
/// El .lottie viene con mucho aire: dentro de su lienzo de 480×480 la
/// moneda ocupa cerca de un tercio. Dejándolo tal cual, a 16 px se ve un
/// puntito.
///
/// 2,35× es el tope: la moneda llena la caja y sigue siendo un círculo.
/// Más que eso y el ClipRect le corta los cuatro lados, y la moneda pasa
/// a leerse como un cuadrado redondeado. El valor se midió con la
/// animación de frente, que es cuando la moneda está más ancha.
const double _acercamiento = 2.35;

/// La moneda de +Vida, girando.
///
/// Ocupa exactamente [size] siempre — también mientras el archivo
/// carga — así que ninguna fila se mueve cuando la animación aparece.
class MonedaAnimada extends StatefulWidget {
  const MonedaAnimada({super.key, this.size = 16, this.apagado = false});

  /// Lado de la caja donde entra la moneda. Se mantuvo el mismo número
  /// que tenía el ícono que reemplazó en cada lugar, para no cambiar de
  /// paso el espaciado de las filas.
  final double size;

  /// Para una moneda que ya no está en juego (una semana cerrada, un
  /// objetivo vencido). Se pinta en gris en vez de desaparecer: el
  /// usuario tiene que poder ver que ahí HABÍA monedas.
  final bool apagado;

  /// Deja la animación lista en memoria antes de que se pinte la primera
  /// pantalla. Sin esto, la primera moneda de la sesión aparece un
  /// instante después que el número que tiene al lado.
  static Future<void> precargar() async {
    try {
      await AssetLottie(_rutaMoneda).load();
    } catch (_) {
      // Si el asset no está, la app arranca igual: cada moneda cae sola
      // en su ícono de reserva.
    }
  }

  @override
  State<MonedaAnimada> createState() => _MonedaAnimadaState();
}

class _MonedaAnimadaState extends State<MonedaAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(vsync: this, duration: _duracionGiro);
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con "Reducir movimiento" activado en iOS la moneda se queda
    // quieta. Girar sin parar es exactamente lo que esa opción está
    // pidiendo que no pasemos por alto.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controlador.stop();
      _controlador.value = 0;
    } else if (!_controlador.isAnimating) {
      _controlador.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lado = widget.size * _acercamiento;

    Widget moneda = Lottie.asset(
      _rutaMoneda,
      controller: _controlador,
      width: lado,
      height: lado,
      fit: BoxFit.contain,
      // El controlador manda la duración, no la del archivo.
      animate: false,
      // Si el archivo faltara, la app no se rompe: vuelve al ícono de
      // siempre y nadie ve un cuadro vacío.
      errorBuilder: (context, error, stack) =>
          _MonedaDeReserva(size: widget.size, apagado: widget.apagado),
    );

    // Se dibuja grande y se recorta a la caja pedida: así la moneda llena
    // el espacio en vez de quedar flotando chiquita en medio del aire que
    // trae el archivo.
    moneda = ClipRect(
      child: OverflowBox(
        minWidth: lado,
        maxWidth: lado,
        minHeight: lado,
        maxHeight: lado,
        child: moneda,
      ),
    );

    if (widget.apagado) {
      moneda = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_grises),
        child: Opacity(opacity: 0.55, child: moneda),
      );
    }

    return RepaintBoundary(
      // La caja se reserva SIEMPRE, cargue o no: sin esto la fila se
      // corre unos píxeles cuando entra la animación.
      child: SizedBox(width: widget.size, height: widget.size, child: moneda),
    );
  }
}

/// Matriz que pasa cualquier color a gris conservando el brillo.
const List<double> _grises = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// El ícono de antes. Solo se ve si el .lottie no se pudo leer.
class _MonedaDeReserva extends StatelessWidget {
  const _MonedaDeReserva({required this.size, required this.apagado});

  final double size;
  final bool apagado;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.monetization_on,
    size: size,
    color: apagado ? AppColors.textSecondary : AppColors.accentSecondary,
  );
}
