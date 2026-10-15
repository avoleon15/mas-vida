# Apple Design en Flutter

Traducción a Dart/Flutter de cada sección del `SKILL.md`. Los principios
cruzan enteros; solo cambia el código.

Todas las firmas de acá se verificaron contra el SDK de Flutter instalado
(`/c/flutter`), no de memoria. Lo que no tiene equivalente está declarado
como hueco, no forzado.

---

## Mapeo rápido

| Web (SKILL.md) | Flutter |
| --- | --- |
| Springs de Motion | `SpringDescription` + `SpringSimulation` + `AnimationController.animateWith()` |
| `bounce` + `duration` de Motion | `SpringDescription.withDurationAndBounce(duration:, bounce:)` |
| Damping ratio de Apple | `SpringDescription.withDampingRatio(mass:, stiffness:, ratio:)` |
| Entrega de velocidad | `DragEndDetails.velocity.pixelsPerSecond` → 4.º argumento de `SpringSimulation` |
| Valor de presentación | `controller.value` (se pasa como `start` de la simulación) |
| Arrastre 1:1 | `GestureDetector(onPanUpdate:)` o `Listener(onPointerMove:)` |
| `setPointerCapture` | El gesture arena de Flutter (automático) |
| Historial de velocidad | `VelocityTracker` |
| Proyección de momentum | `FrictionSimulation` · `ScrollPhysics.createBallisticSimulation` |
| Rubber-banding | `BouncingScrollPhysics` · `ScrollPhysics.applyBoundaryConditions` |
| `backdrop-filter` | `BackdropFilter(filter: ImageFilter.blur())` |
| `prefers-reduced-motion` | `MediaQuery.of(context).disableAnimations` |
| `prefers-contrast: more` | `MediaQuery.of(context).highContrast` |
| `prefers-reduced-transparency` | **No existe** (ver §14) |
| Haptics (Vibration API) | `HapticFeedback.lightImpact()` / `.selectionClick()` |
| `requestAnimationFrame` | `Ticker` · `AnimationController` · `SchedulerBinding` |
| `transform` / `opacity` | `Transform` · `FadeTransition` · `RepaintBoundary` |
| `transform-origin` | `alignment:` de `ScaleTransition` / `Transform` |
| tracking / leading | `TextStyle(letterSpacing:, height:)` |
| Dynamic Type | `MediaQuery.of(context).textScaler` |

---

## §1 Response — matar la latencia

El retardo de ~300ms del tap **no existe en Flutter**: no hay nada que
auditar ahí. El resto aplica igual.

- Feedback en el *press*, no en el release: `onTapDown`, no `onTap`.
- `GestureDetector(behavior: HitTestBehavior.opaque)` para que el área
  muerta alrededor del hijo también reciba el toque.

```dart
GestureDetector(
  onTapDown: (_) => setState(() => _presionado = true),   // instantáneo
  onTapUp: (_) => setState(() => _presionado = false),
  onTapCancel: () => setState(() => _presionado = false), // cancelar arrastrando
  child: AnimatedScale(
    scale: _presionado ? 0.97 : 1.0,
    duration: const Duration(milliseconds: 100),
    child: child,
  ),
)
```

`AnimatedScale` acá está bien porque es un tap, no un gesto continuo. Para
algo arrastrable, ver §3.

## §2 Manipulación directa — seguimiento 1:1

`setPointerCapture` no tiene equivalente porque **no hace falta**: cuando un
recognizer gana el gesture arena de Flutter, sigue recibiendo eventos aunque
el dedo salga del widget. Es automático.

- **Respetar el offset de agarre:** guardar la posición al `onPanStart` y
  trabajar con deltas. `DragUpdateDetails.delta` ya es incremental, así que
  sumarlo mantiene el offset solo.
- **Historial de velocidad:** `GestureDetector` ya lo lleva y lo entrega en
  `DragEndDetails.velocity`. Solo hace falta `VelocityTracker` a mano si se
  usa `Listener` crudo.

```dart
// Con GestureDetector: la velocidad viene servida.
GestureDetector(
  onPanUpdate: (d) => _controller.value += d.delta.dy / _alto,
  onPanEnd: (d) => _soltar(d.velocity.pixelsPerSecond.dy),
)

// Con Listener crudo hay que llevar el historial uno mismo.
final _tracker = VelocityTracker.withKind(PointerDeviceKind.touch);
// en onPointerMove:  _tracker.addPosition(evento.timeStamp, evento.position);
// al soltar:         final v = _tracker.getVelocity().pixelsPerSecond;
```

## §3 Interrumpibilidad

**`controller.value` ES el valor de presentación.** No hay que leer ningún
transform de pantalla: el valor vivo ya está ahí.

Pero ojo con un detalle: `animateWith()` **no** arranca solo desde
`controller.value`. Quien define el arranque es el parámetro `start` de la
simulación. Hay que pasárselo a mano — es el equivalente exacto de "animar
desde el valor de presentación".

```dart
// Interrumpir y redirigir: se construye una simulación NUEVA desde donde
// está el controlador ahora mismo, con la velocidad que traía el gesto.
void _soltar(double velocidadPx) {
  final destino = velocidadPx > 0 ? 1.0 : 0.0;
  _controller.animateWith(
    SpringSimulation(
      _resorte,
      _controller.value,        // <- valor de presentación
      destino,
      velocidadPx / _alto,      // normalizado a las mismas unidades
    ),
  );
}
```

- **No usar animaciones implícitas para nada gestual.** `AnimatedContainer`,
  `AnimatedPositioned` y compañía son el equivalente de las CSS transitions:
  duración fija, no cargan velocidad, saltan al reinterrumpirse. Sirven para
  cambios de estado discretos, no para algo que el dedo puede agarrar.
- **Descomponer el movimiento 2D:** dos `AnimationController` independientes,
  uno para X y otro para Y, cada uno con su `SpringSimulation`.
- **Additive animations de iOS: no existen en Flutter.** No hay API para
  sumar animaciones. Lo más cerca es reconstruir la simulación pasándole la
  velocidad actual (`simulacion.dx(t)`) como velocidad inicial de la nueva,
  que evita el "muro de ladrillos" aunque no sea lo mismo.

## §4 Comportamiento sobre animación — resortes

Flutter trae el mapeo de Apple **de fábrica**:
`SpringDescription.withDurationAndBounce` está documentado en el SDK como
equivalente de `spring(duration:bounce:)` de SwiftUI. Es el camino directo
para los valores de la tabla del SKILL.md, y `bounce = 1 − dampingRatio`.

```dart
// Firma real:
// SpringDescription.withDurationAndBounce({
//   Duration duration = const Duration(milliseconds: 500),
//   double bounce = 0.0,
// })

// Default de UI: críticamente amortiguado, sin sobrepaso (damping 1.0)
final resorteUI = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 400),
  bounce: 0.0,
);

// Momentum: rebote leve, SOLO porque hubo un flick antes (damping ~0.8)
final resorteFlick = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 300),
  bounce: 0.2,
);
```

Tabla del SKILL.md traducida:

| Interacción | Damping | Response | En Flutter |
| --- | --- | --- | --- |
| Mover / reposicionar | `1.0` | `0.4` | `bounce: 0.0, duration: 400ms` |
| Rotación | `0.8` | `0.4` | `bounce: 0.2, duration: 400ms` |
| Cajón / sheet | `0.8` | `0.3` | `bounce: 0.2, duration: 300ms` |

La alternativa física, si se prefiere pensar en masa y rigidez:

```dart
// SpringDescription.withDampingRatio({
//   required double mass, required double stiffness, double ratio = 1.0,
// })
final resorte = SpringDescription.withDampingRatio(
  mass: 1.0, stiffness: 500.0, ratio: 1.0,
);
```

**Cuidado con `duration:` acá.** Igual que en el SKILL.md, no es una
duración real: el resorte no termina en ese tiempo, es un parámetro que
describe qué tan rápido converge.

## §5 Entrega de velocidad

`SpringSimulation` toma la velocidad como **cuarto argumento posicional**,
no como parámetro nombrado:

```dart
// SpringSimulation(SpringDescription spring, double start, double end,
//                  double velocity, {bool snapToEnd = false, Tolerance tolerance})
SpringSimulation(resorte, _controller.value, destino, velocidad)
```

La unidad tiene que ser coherente con `start`/`end`. Si el controlador va de
0 a 1 sobre un alto de `H` píxeles, hay que normalizar:

```dart
final velocidadNormalizada = detalles.velocity.pixelsPerSecond.dy / alto;
```

Si en cambio el controlador trabaja en píxeles (con
`AnimationController.unbounded`), se le pasa `pixelsPerSecond` crudo.

## §6 Proyección de momentum

La función de proyección de Apple es aritmética pura: **se porta tal cual a
Dart**, sin depender de ninguna API.

```dart
/// Proyecta dónde va a frenar algo lanzado a [velocidadInicial] px/s.
/// 0.998 para inercia tipo scroll; 0.99 para algo más corto.
double proyectar(double velocidadInicial, {double desaceleracion = 0.998}) {
  return (velocidadInicial / 1000) * desaceleracion / (1 - desaceleracion);
}

final proyectado = posicionActual + proyectar(velocidadAlSoltar);
final destino = puntoDeAnclajeMasCercano(proyectado);
// y recién ahí se entrega la velocidad al resorte (§5)
```

Alternativa con el SDK: `FrictionSimulation(drag, position, velocity)` tiene
un getter `finalX` que da el punto de reposo. Sirve, pero la constante `drag`
no es la misma que `decelerationRate` de Apple, así que **no reproduce los
mismos números**. Para respetar el feel de Apple, usar la fórmula de arriba.

Para listas y scroll, esto ya está resuelto: `ScrollPhysics` lo hace solo, y
`createBallisticSimulation(ScrollMetrics position, double velocity)` es el
punto de extensión.

## §7 Consistencia espacial

- **Entrada y salida por el mismo camino:** una sola `Animation` reversible
  (`forward()` / `reverse()`), no dos animaciones distintas.
- **`transform-origin` → `alignment:`.** Existe en `ScaleTransition`
  (`alignment: Alignment.center` por defecto) y en `Transform`. Para anclar
  un popover a su botón: calcular la `Alignment` relativa al disparador.
- **Espejar la curva:** `CurvedAnimation(parent:, curve:, reverseCurve:)`.
  `Curves.easeOut` con `reverseCurve: Curves.easeIn` es el equivalente de
  invertir los puntos de control del cubic-bézier.

```dart
ScaleTransition(
  scale: _animacion,
  alignment: Alignment.topRight,  // nace del botón, no del centro
  child: popover,
)
```

## §8 Anticipar la dirección del gesto

Sin API: es diseño. En Flutter se hace con `Tween`s intermedios o un
`TweenSequence` cuyos cuadros del medio apuntan al resultado, en vez de
interpolar recto al destino.

## §9 Rubber-banding

Dos caminos, ambos reales:

1. **Scroll:** `BouncingScrollPhysics` ya lo hace (es el comportamiento iOS).
2. **A mano:** sobrescribir
   `double applyBoundaryConditions(ScrollMetrics position, double value)` en
   un `ScrollPhysics` propio.

Para un gesto que no es scroll, la fórmula del SKILL.md se porta directo:

```dart
double rubberband(double excedente, double dimension, {double c = 0.55}) {
  return (excedente * dimension * c) / (dimension + c * excedente.abs());
}
```

## §10 Detalles de gestos

Flutter trae constantes propias, y **no coinciden con los ~10px del
SKILL.md** — conviene usar las del framework para no pelearse con los
recognizers nativos:

| Constante | Valor real | Para qué |
| --- | --- | --- |
| `kTouchSlop` | `18.0` px lógicos | Umbral antes de comprometerse a un arrastre |
| `kDoubleTapTimeout` | `300 ms` | El retardo que paga el doble tap |
| `kMinFlingVelocity` | `50.0` px/s | Piso para considerar que hubo un flick |

- **Detección en paralelo:** es exactamente lo que hace el gesture arena de
  Flutter. Varios recognizers compiten desde el primer movimiento y los
  perdedores se cancelan solos. Con `RawGestureDetector` se controla a mano.
- **Evitar recognizers de estado final:** en Flutter el equivalente malo es
  usar solo `onHorizontalDragEnd` sin `onHorizontalDragUpdate`. El update es
  el que da el seguimiento continuo.
- `onTapCancel` es el "cancelar arrastrando afuera" que pide la sección.

## §11 Suavidad a nivel de cuadro

- `requestAnimationFrame` → `Ticker` (vía `SingleTickerProviderStateMixin`),
  que es lo que usa `AnimationController` por dentro. Para un cuadro suelto,
  `SchedulerBinding.instance.addPostFrameCallback`.
- **La regla de "solo `transform` y `opacity`" no se traduce igual.** En
  Flutter no hay propiedades de compositor privilegiadas: `Opacity` es caro
  porque puede forzar una capa intermedia. Los equivalentes útiles son usar
  `FadeTransition` / `SlideTransition` (que animan sin reconstruir el
  subárbol) en vez de `setState`, y aislar con `RepaintBoundary`.
- **`will-change` no tiene equivalente.** `RepaintBoundary` se le parece
  (aísla la capa) pero no es una pista de "va a moverse": es un límite de
  repintado real, y ponerlo de más cuesta memoria.
- **Motion blur / stretch: hueco declarado.** No hay API. Habría que
  escribirlo como `FragmentProgram` (shader propio); no existe nada listo.

## §12 Materiales y profundidad

```dart
ClipRRect(                      // BackdropFilter necesita un clip que lo acote
  borderRadius: BorderRadius.circular(20),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: Container(
      color: Colors.white.withValues(alpha: 0.6),
      child: contenido,
    ),
  ),
)
```

- **`saturate(180%)` sí se puede.** `ColorFilter implements ImageFilter`, y
  existe `ImageFilter.compose({required ImageFilter outer, required
  ImageFilter inner})`, así que se encadena una matriz de saturación con el
  blur.
- **Scroll edge effects:** `ShaderMask` con un `LinearGradient` de opaco a
  transparente donde el contenido se cruza con la barra flotante. Es el
  equivalente del gradient mask, y evita el divisor de 1px.
- **Materializar en vez de fundir:** animar `sigmaX`/`sigmaY` del
  `ImageFilter` junto con la escala. Como el `ImageFilter` se reconstruye
  cada cuadro, esto es caro — medirlo antes de dejarlo.
- **Scrim de modal:** `showModalBottomSheet(barrierColor:)` o un
  `ModalBarrier` propio.
- **Vibrancy: hueco parcial.** No hay materiales del sistema como los de
  iOS. Se aproxima a mano con lo que dice la sección (más contraste, peso un
  poco mayor, `letterSpacing` levemente arriba), pero no hay una API que
  adapte el texto al fondo automáticamente.

> Para este proyecto: `CLAUDE.md` prohíbe glows y pide sombras suaves sobre
> fondo claro. El material translúcido es compatible; el brillo no.

## §13 Feedback multimodal

```dart
HapticFeedback.selectionClick();   // cambio de selección, encastre
HapticFeedback.lightImpact();      // confirmación leve
HapticFeedback.mediumImpact();
HapticFeedback.heavyImpact();
HapticFeedback.vibrate();
```

- **Causalidad y utilidad** aplican igual.
- **Armonía (mismo cuadro): no se puede garantizar.** `HapticFeedback` cruza
  un platform channel y es `Future<void>`, o sea asincrónico respecto del
  pipeline de render. Se dispara lo más cerca posible del cuadro causal, pero
  Flutter no ofrece sincronía cuadro a cuadro entre visual y háptica.
- **Sonido: prácticamente un hueco.** Solo hay
  `SystemSound.play(SystemSoundType.click)`, que son sonidos del sistema, no
  audio propio. Para lo que describe la sección haría falta un paquete
  externo — y este proyecto tiene regla de no agregar dependencias.

## §14 Reduced motion y accesibilidad

```dart
final mq = MediaQuery.of(context);
if (mq.disableAnimations) {
  // cross-fade corto en vez de slide/spring; sin sobrepaso
}
if (mq.highContrast) {
  // fondo casi sólido, borde definido
}
```

Banderas reales de `MediaQueryData`, todas verificadas:
`disableAnimations`, `highContrast`, `boldText`, `invertColors`,
`accessibleNavigation`, `onOffSwitchLabels`, `textScaler`.

**`prefers-reduced-transparency` NO tiene equivalente.** Lo revisé en el
SDK: `MediaQueryData` no expone ninguna bandera de transparencia reducida.
Para leerla en iOS habría que escribir un platform channel propio contra
`UIAccessibility.isReduceTransparencyEnabled`. Hasta entonces, la opción
honesta es ofrecer un ajuste propio en la app o atarlo a `highContrast`,
dejando claro en el código que es una aproximación y no la preferencia real
del sistema.

`disableAnimations` cubre bien `prefers-reduced-motion` (en iOS sale de
Reduce Motion). El resto de la sección — nada de fondos que se mueven a
pantalla completa, sin oscilaciones lentas, sin saltos de brillo — es diseño
y aplica igual.

## §15 Tipografía

```dart
Text(
  'Título',
  style: TextStyle(
    fontSize: 34,
    height: 1.05,             // leading: MULTIPLICADOR de fontSize
    letterSpacing: 34 * -0.02, // tracking: PÍXELES LÓGICOS, no em
    fontWeight: FontWeight.w700,
  ),
)
```

**Dos trampas de unidades**, que son el error más fácil de cometer al portar
CSS:

| CSS | Flutter | Diferencia |
| --- | --- | --- |
| `letter-spacing: -0.02em` | `letterSpacing:` | Flutter usa **píxeles lógicos**, no em. Hay que multiplicar por el `fontSize` a mano. |
| `line-height: 1.05` | `height: 1.05` | Igual: multiplicador sin unidad. |

- **Dynamic Type:** `MediaQuery.of(context).textScaler` (un `TextScaler`;
  el viejo `textScaleFactor` está deprecado). Para escalar espaciados junto
  con el texto: `mq.textScaler.scale(16)`.
- **No hay `rem`.** El punto del SKILL.md de "espaciados en rem, no px" no
  se traduce: en Flutter todo es px lógicos. El equivalente es derivar los
  espaciados de `textScaler` o del `fontSize` del tema.
- **Optical sizing:** no existe `FontVariation.opticalSize` (lo verifiqué:
  las nombradas son `weight`, `width`, `slant`, `italic`). Se usa el eje
  genérico, y solo si la fuente es variable y trae el eje `opsz`:

```dart
TextStyle(fontVariations: [FontVariation('opsz', 34.0)])
```

- **Fuente del sistema:** si no se pone `fontFamily`, Flutter usa la del
  sistema (SF Pro en iOS), que es lo que pide la sección. Este proyecto usa
  Inter vía `google_fonts` a propósito, porque también corre en Web — está
  documentado en `theme.dart`.

## §16 y §17 — Fundamentos y proceso

**No hay nada que traducir: son principios, no código.** Aplican tal cual.
Anclajes útiles en Flutter, por si sirven:

| Concepto | Dónde vive en Flutter |
| --- | --- |
| Agency / deshacer | `SnackBar` con `SnackBarAction`, `Dismissible` |
| Feedback: status / completion / warning / error | `SnackBar`, diálogos, `TextFormField(validator:)` para validación en línea |
| Wayfinding | `Navigator`, rutas nombradas, `AppBar` con back automático |
| Familiaridad por plataforma | Widgets `Cupertino*` en iOS |
| Flexibilidad | `LayoutBuilder`, `MediaQuery`, `Semantics` |

Sobre §17: el consejo de "prototipar interactivamente" en Flutter se cobra
barato con hot reload y con puntos de entrada de demo aparte
(`flutter run -t lib/mi_demo.dart`).
