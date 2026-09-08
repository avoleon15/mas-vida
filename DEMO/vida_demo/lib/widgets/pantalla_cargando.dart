import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme.dart';
import 'logo_vida.dart';

// ============================================================
// LA PANTALLA DE ARRANQUE.
//
// Es lo primero que ve el usuario: la cruz del logo recorriendo un
// electrocardiograma mientras los datos se cargan detrás.
//
// Antes acá no había nada. `main.dart` cargaba los datos ANTES de
// `runApp`, así que durante toda la carga la app todavía no existía y lo
// que se veía era el splash nativo en blanco. Esta pantalla existe para
// que ese rato tenga cara de +Vida.
// ============================================================

/// Ruta de la animación. En un solo lugar, igual que en
/// `moneda_animada.dart`, para no repetirla si algún día se usa en otro
/// lado (por ejemplo, un refresco de datos a mitad de sesión).
const String _rutaCargando = 'assets/lottie/cargando.json';

/// Ancho de la animación en pantalla.
///
/// Se fija el ANCHO y nunca el alto: el archivo tiene lienzo 600×300, o
/// sea 2:1, y dándole los dos la animación se deforma. Con solo el ancho
/// el alto lo saca Lottie de la proporción del archivo.
const double _anchoAnimacion = 300;

/// Lo que se ve mientras la app carga sus datos.
///
/// No recibe nada ni avisa nada: no sabe qué se está cargando ni cuánto
/// falta. Quién decide cuándo se va es `main.dart`.
class PantallaCargando extends StatelessWidget {
  const PantallaCargando({super.key});

  @override
  Widget build(BuildContext context) {
    // Con "Reducir movimiento" activado en iOS la cruz se queda quieta,
    // por el mismo motivo que la moneda: una animación que se repite
    // para siempre es exactamente lo que esa opción pide que no pasemos
    // por alto.
    //
    // Además es lo que mantiene los tests vivos. `test/ayudas.dart` monta
    // las pantallas con `disableAnimations: true`, y si esta animación
    // siguiera corriendo ahí, `pumpAndSettle` no terminaría de asentarse
    // nunca y el test se colgaría hasta el timeout.
    final quieta = MediaQuery.disableAnimationsOf(context);

    return ColoredBox(
      // El fondo se pinta acá y no se hereda: es lo que evita el
      // parpadeo en blanco entre el primer frame y el momento en que la
      // animación termina de leerse del disco.
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: Lottie.asset(
                _rutaCargando,
                width: _anchoAnimacion,
                // Sin controlador propio, al revés que la moneda. Allá
                // hacía falta uno para FRENAR el archivo, que giraba
                // demasiado rápido; acá el ciclo de 2,5 s del archivo es
                // justo el que se quiere, así que agregar un controlador
                // sería repetir a mano un dato que la animación ya trae.
                animate: !quieta,
                repeat: true,
                // Sin esto Flutter la corre a 30 fps y el trazo del
                // electro se ve escalonado.
                frameRate: FrameRate.max,
                // El archivo puede no estar: la app tiene que arrancar
                // igual y no quedarse con un hueco en el medio de la
                // pantalla.
                errorBuilder: (context, error, stack) =>
                    const _CargandoDeReserva(),
              ),
            ),
            const SizedBox(height: AppSpacing.grupo),
            // "Cargando" escrito y el nombre puesto con el logo, en vez
            // de escribir "+Vida" con letras. El logo es el nombre de la
            // marca dibujado como corresponde; tipearlo al lado de un
            // logo que existe es escribirlo dos veces distinto.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cargando',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                // Más chico que en el header: acá el logo acompaña a una
                // palabra, no encabeza una pantalla.
                const LogoVida(alto: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lo que se ve si la animación no se pudo leer.
///
/// Un indicador de iOS y no un dibujo propio: si el archivo de la marca
/// faltó, lo que corresponde es lo más neutro y nativo que haya, no una
/// segunda versión casera del logo.
class _CargandoDeReserva extends StatelessWidget {
  const _CargandoDeReserva();

  @override
  Widget build(BuildContext context) => const SizedBox(
    // La misma caja que ocuparía la animación, para que el texto de
    // abajo no salte de lugar según si el archivo estaba o no.
    width: _anchoAnimacion,
    height: _anchoAnimacion / 2,
    child: Center(
      child: CupertinoActivityIndicator(radius: 16, color: AppColors.accent),
    ),
  );
}
