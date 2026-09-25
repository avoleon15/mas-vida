import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// La misma librería con la que entran los logos del catálogo de
// Premios: una capa de conveniencia sobre las animaciones de Flutter,
// sin motor propio.
import 'package:flutter_animate/flutter_animate.dart';

import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../reglas_puntos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/numero_animado.dart';
import '../widgets/hoja_niveles.dart';
import '../widgets/refresco_vida.dart';

// ============================================================
// MI PLAN — UNA ZONA FIJA ARRIBA Y UNA ZONA QUE CAMBIA ABAJO.
//
// Esta pantalla no lee JSON: todo sale de `Datos.i`.
//
// REGLA DURA DEL PROYECTO: acá NUNCA aparecen monedas — esa es la moneda
// que se gasta en Premios. Mi Plan es solo puntos/cashback/póliza.
//
// ARRIBA, FIJO, SIEMPRE A LA VISTA:
//   el título MI PLAN
//   el cabezal -> el cashback del año, el nivel y la nota regulatoria
//   el riel    -> Póliza · Cobertura · Pagos · Contacto
//
// ABAJO, LO ÚNICO QUE CAMBIA:
//   sin elegir     -> la proyección y el calendario
//   con categoría  -> ESA categoría y nada más
//
// POR QUÉ EL CABEZAL NO SCROLLEA. El monto del año es la respuesta a la
// pregunta con la que alguien entra a esta pantalla, y el riel es la
// única manera de moverse dentro de ella. Si los dos se van con el
// scroll, a media pantalla ya no se sabe ni cuánto se lleva ni cómo
// cambiar de sección. Fijos, el usuario siempre tiene el número y
// siempre tiene el control: lo único que se mueve es la respuesta.
//
// POR QUÉ UN RIEL A LA VISTA Y NO UN MENÚ. Esto pasó por un acordeón,
// por un selector de cuatro tiles y por una barra lateral que se abría
// deslizando. La barra se descartó por lo de siempre con los menús
// escondidos: había que explicarle al usuario que existía, y un control
// que necesita un cartel que lo anuncie ya perdió. Acá los cuatro
// botones SON el cartel.
//
// LA ETIQUETA DE CADA BOTÓN ES UNA PALABRA —"Póliza", "Cobertura",
// "Pagos", "Contacto"— y el nombre largo vive en la faja del panel que
// abre. Con las etiquetas completas ("IDENTIFICACIÓN") cuatro botones
// necesitan ~487 px y en un iPhone hay 280 (SE) a 390 (Pro Max).
//
// SELECCIONAR ES AZUL. El botón de la categoría abierta se rellena con
// el azul de marca y su ícono y su texto pasan a blanco. Es la misma
// regla que la píldora de la barra de abajo y los filtros de Premios —
// si dos pantallas marcan la selección con colores distintos, la app se
// lee como dos apps. El naranja NO entra acá.
//
// EL COLOR DEL PANEL SALE DE LA ESCALA DE AZULES, NO DE UN COLOR NUEVO.
// Cada categoría se abre con una faja de degradado `nivel3 → accent` y
// su ícono grande de marca de agua: es lo que hace que el cambio de
// categoría se vea desde lejos. Son DOS LUMINOSIDADES DEL MISMO AZUL,
// no dos colores — pintar cada categoría de un matiz distinto rompería
// la regla de reparto de CLAUDE.md, que reserva el color por tamaño de
// superficie y deja el naranja para cuatro cosas puntuales.
//
// UN SOLO NÚMERO GRANDE POR TARJETA. En el cabezal el monto es lo único
// en display(46); el nivel va en un medallón chico al costado y el
// porcentaje baja al renglón de apoyo.
//
// LA PRIMA VA COMPLETA Y SIN TACHAR, SIEMPRE. Tacharla diría "pagás
// menos", que es exactamente lo que la Superintendencia de Bancos no
// permite: el cashback se devuelve como dinero DESPUÉS de pagar la
// prima. La nota regulatoria vive DENTRO del cabezal, al pie y separada
// por un hairline, porque la regla pertenece a ese número — y como el
// cabezal es fijo, la nota nunca se va de la pantalla.
//
// POR QUÉ NO HAY SHIMMER DE CARGA. `Datos.i` se hidrata una sola vez
// antes de que exista cualquier pantalla (ver `main.dart`: hasta que la
// carga termina se muestra `PantallaCargando`), y las pantallas lo leen
// de forma síncrona. Esta pantalla NO PUEDE montarse sin datos, y en el
// refresco `Datos.cargar` recién asigna al final, así que nunca hay un
// cuadro con las filas vacías. Un shimmer acá tendría que inventar una
// espera que no existe.
// ============================================================

// La tabla completa de niveles no se muestra acá: Mi Plan enseña el
// nivel de HOY. La escalera con la foto del usuario vive en Home.

int get nivelActual => Datos.i.resumen.nivel;
int get puntosAnuales => Datos.i.resumen.puntosAno;

/// Cashback de fin de año: el % del nivel aplicado sobre la prima anual.
int get cashbackProyectado => Datos.i.resumen.cashback.proyectadoQ;

/// TODO: falta la fórmula de devengo del cashback a mitad de año. Lo
/// único fijado es que se devuelve como dinero DESPUÉS del pago de la
/// prima, nunca como descuento directo (Superintendencia de Bancos).
///
/// Mientras esto sea null, el hero dice lo que paga el nivel de HOY y no
/// "lo que llevás acumulado": lo segundo sería un número inventado.
int? get cashbackDevengado => Datos.i.resumen.cashback.devengadoQ;

// ---- Detalles de póliza ----
String get numeroPoliza => Datos.i.perfil.poliza.numero;
String get titularYDependientes => Datos.i.perfil.poliza.titularYDependientes;
String get tipoPlan => Datos.i.perfil.poliza.tipoPlan;
String get sumaAsegurada => Datos.i.perfil.poliza.sumaAsegurada;
String get deducible => Datos.i.perfil.poliza.deducible;
String get coaseguro => Datos.i.perfil.poliza.coaseguro;
String get vigencia => Datos.i.perfil.poliza.vigencia;
String get fechaRenovacion => Datos.i.perfil.poliza.fechaRenovacion;
String get primaAnual => Datos.i.perfil.poliza.primaAnual;
String get formaPago => Datos.i.perfil.poliza.formaPago;
String get redCobertura => Datos.i.perfil.poliza.redCobertura;
String get estadoPoliza => Datos.i.perfil.poliza.estado;

/// La prima como número, para la única cuenta de la pantalla: cuánto
/// pagaría el nivel siguiente. Puede ser null (ver [Poliza.primaAnualQ]).
int? get primaAnualNumero => Datos.i.perfil.poliza.primaAnualQ;

/// Cuándo cierra el año del programa. Se nombra una sola vez: lo dicen
/// la proyección y el calendario, y tienen que decir lo mismo.
const String cierreDelAno = '31 de diciembre';

// ============================================================
// TIEMPOS DE LA ANIMACIÓN
//
// Todo en `curvaNumeroAnimado` (easeOutCubic), la misma curva del anillo
// de Home y de los números. Una pantalla con su propia curva se siente
// de otra app.
// ============================================================

/// Cuánto tarda un botón del riel en prenderse o apagarse.
///
/// Más corto que una apertura (300 ms) a propósito: esto es un CAMBIO de
/// estado, no algo que se despliega. Un cambio que tarda lo mismo que
/// una apertura se siente pesado, como si la app estuviera pensando.
const Duration duracionCambioDeCategoria = Duration(milliseconds: 180);

/// Cuánto tarda el panel en aparecer.
///
/// La misma que la entrada de los logos de Premios: las dos son "algo
/// que llega", y si cada pantalla eligiera su propio tiempo la app se
/// movería a distintas velocidades según dónde estés parado.
const Duration duracionEntradaPanel = Duration(milliseconds: 420);

/// Cuánto tarda en entrar un botón del riel.
///
/// Igual que la entrada de los logos de Premios. Dos pantallas distintas
/// no pueden hacer aparecer una tarjeta a velocidades distintas.
const Duration duracionEntradaBoton = Duration(milliseconds: 420);

/// Cuánto espera cada botón respecto del anterior de la fila.
///
/// Corto: son cuatro, así que el último arranca 210 ms después del
/// primero. Con un escalón más largo, el cuarto entraría cuando el
/// usuario ya está mirando otra cosa.
const Duration escalonEntradaBoton = Duration(milliseconds: 70);

/// Cuánto sube el panel al entrar, como fracción de su propio alto.
///
/// Poco, y hacia ARRIBA: el panel viene de abajo, que es de donde
/// aparece. Un desplazamiento grande convierte una aparición en un
/// aterrizaje, y la app tiene que transmitir calma.
const double desplazamientoEntradaPanel = 0.06;

/// A partir de qué tamaño de texto del sistema la zona fija deja de
/// estar fija.
///
/// Arriba de esto, el cabezal y el riel juntos se comerían la pantalla y
/// el panel quedaría en una franja de 80 px. Entonces todo vuelve a
/// scrollear junto: es mejor perder el cabezal fijo que dejar el
/// contenido sin lugar.
const double escalaQueSueltaElCabezal = 1.3;

/// Cuánto alto hace falta para que valga la pena tener el cabezal fijo.
///
/// El cabezal mide unos 350 px, y entre el header de la marca y la barra
/// de abajo se van otros 160. En un iPhone SE (568 de alto) eso deja 60
/// px para el panel, que no es una zona de contenido: es una rendija.
/// Por debajo de este alto todo vuelve a scrollear junto.
///
/// 720 y no 700: deja fijo el cabezal del iPhone 12 para arriba (844) y
/// lo suelta en los SE (568 y 667), que es justo donde no entra.
const double altoMinimoParaCabezalFijo = 720;

// ============================================================
// EL ASPECTO DE UN BLOQUE
//
// ACÁ YA NO HAY TARJETAS BLANCAS (decisión de Daniel, 22 de septiembre
// de 2026). Había cuatro recetas del mismo rectángulo —la proyección, el
// calendario, la lista de datos y los contactos—, todas con el mismo
// radio, el mismo borde y la misma sombra, apiladas una debajo de la
// otra. Con todo adentro de una caja idéntica nada es importante: el ojo
// no encuentra dónde parar y la pantalla se lee como una pila de
// formularios. Es exactamente el problema que CLAUDE.md ya resolvió en
// Social y en Progreso con la regla de UNA SOLA COSA LEVANTADA.
//
// Acá la cosa levantada es el CASHBACK, que es la respuesta a la
// pregunta con la que alguien entra a esta pantalla. Todo lo demás se
// apoya directo sobre el fondo: un título de bloque arriba, las filas
// separadas por una línea de un pelo, y aire entre una sección y la
// siguiente. Es lo mismo que hace Progreso, donde `_Tarjeta` hace rato
// que es una Column sin superficie.
//
// Lo que se gana no es sutileza: son cuatro bordes, cuatro sombras y
// ocho esquinas menos, y el contenido gana los 40 px de ancho que se
// comían los padding internos.
// ============================================================

/// El degradado de TODA superficie azul de la pantalla.
///
/// Va del azul de marca a ese mismo azul OSCURECIDO, no de un azul claro
/// al de marca. La diferencia se nota: la versión anterior arrancaba en
/// `nivel3` —un azul bastante más claro— y aclarar hacia arriba le daba
/// a las superficies grandes un brillo de plástico, como de botón de
/// sitio web. Oscureciendo hacia abajo, la misma superficie se lee con
/// peso y profundidad, que es lo que tiene que transmitir la pantalla de
/// una póliza de gastos médicos.
///
/// `azulSombra` ya existía en `theme.dart` para las sombras sólidas, y
/// es el azul de marca mezclado con negro: NO es un color nuevo ni un
/// matiz distinto, es el mismo azul con menos luz. Si mañana cambia
/// `accent`, este degradado lo sigue solo.
///
/// Lo usan las tres superficies azules —el cabezal, la faja de una
/// categoría y el botón abierto del riel— y por eso vive acá arriba, una
/// sola vez: tres degradados escritos por separado se despegan entre sí
/// a la primera corrección.
LinearGradient get degradadoDeMarca => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.accent, AppColors.azulSombra],
);

/// La del cabezal: AZUL DE MARCA ENTERO, no blanco.
///
/// Era blanca con un degradado azul casi invisible, y el problema era
/// ese: la tarjeta del cashback es la respuesta a la pregunta con la que
/// alguien entra a esta pantalla, pero blanca sobre un fondo casi blanco
/// se leía como una tarjeta más de las cuatro que hay abajo. En azul
/// entero no hay forma de confundirla: es lo único oscuro de la
/// pantalla, así que el ojo va ahí primero.
///
/// Es el MISMO degradado de la faja de una categoría (`nivel3` →
/// `accent`), no uno nuevo: dos luminosidades del mismo azul. Que el
/// cabezal y la faja hablen el mismo idioma es lo que hace que la
/// pantalla se lea como una sola cosa.
///
/// OJO con CLAUDE.md: la regla de reparto por tamaño dice que lo grande
/// va en blanco y el azul entero queda para lo mediano. Esta tarjeta y
/// la faja de categoría son las dos excepciones, y son deliberadas
/// (Daniel, 18 de septiembre de 2026). Si se aprueban, la regla del
/// documento hay que reescribirla; si no, estas dos vuelven a blanco.
BoxDecoration _tarjetaHero() => BoxDecoration(
  gradient: degradadoDeMarca,
  borderRadius: BorderRadius.circular(22),
  // Sin borde: el borde existía para despegar una tarjeta blanca de un
  // fondo casi blanco. En azul entero no hace falta nada.
  //
  // La sombra va en `azulSombra` y no en `accent`, y bastante más
  // discreta que antes: una sombra del color de marca al 34% no se lee
  // como sombra sino como un resplandor alrededor de la tarjeta, que es
  // justo lo que le sacaba seriedad. Una sombra es la ausencia de luz,
  // no una segunda fuente.
  boxShadow: [
    BoxShadow(
      color: AppColors.azulSombra.withValues(alpha: 0.22),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: AppColors.azulSombra.withValues(alpha: 0.10),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ],
);

// ============================================================
// LA PANTALLA
// ============================================================

/// Stateful por una sola cosa: qué categoría se está mirando.
class MiPlanScreen extends StatefulWidget {
  const MiPlanScreen({super.key});

  @override
  State<MiPlanScreen> createState() => _MiPlanScreenState();
}

class _MiPlanScreenState extends State<MiPlanScreen> {
  /// La categoría abierta, o null cuando se está en la vista de la
  /// plata (proyección y calendario).
  _Categoria? _elegida;

  void _elegir(_Categoria categoria) {
    HapticFeedback.selectionClick();
    // Volver a tocar la que ya está abierta la CIERRA y devuelve a la
    // plata. Es la única forma de volver que no necesita un botón
    // "atrás" en una pantalla que no navegó a ningún lado.
    setState(() => _elegida = _elegida == categoria ? null : categoria);
  }

  void _cerrar() {
    HapticFeedback.selectionClick();
    setState(() => _elegida = null);
  }

  @override
  Widget build(BuildContext context) {
    final aseguradora = Datos.i.perfil.aseguradora;
    final uso = Datos.i.perfil.usoDelSeguro;
    // El marcador naranja se ve SIN tocar nada: alguien puede necesitar
    // el teléfono de emergencias antes de abrir la categoría, y un dato
    // de relleno presentado como bueno es peligroso de verdad.
    final sinVerificar = !aseguradora.verificado || !uso.verificado;

    // Dos motivos para soltar el cabezal: un texto del sistema muy
    // grande, o una pantalla corta. En los dos casos la zona fija no
    // cabe, y ahí todo vuelve a scrollear junto.
    final medidas = MediaQuery.of(context);
    final sueltoElCabezal =
        medidas.textScaler.scale(1) > escalaQueSueltaElCabezal ||
        medidas.size.height < altoMinimoParaCabezalFijo;

    // El margen de 20 va PIEZA POR PIEZA y no envolviendo al cabezal
    // entero: el riel de categorías tiene que llegar hasta los dos
    // bordes de la pantalla, y con el margen puesto arriba no habría
    // forma de que se saliera de él.
    final cabezal = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // EL NIVEL VA ACÁ ARRIBA, a la altura del título y pegado al
        // borde derecho.
        //
        // Vivía adentro de la tarjeta del cashback, al costado del
        // monto, y ahí competía con él: dos cosas azules a 20 px una
        // de la otra, y la que importa es el monto. Arriba tiene el
        // renglón para él solo, se ve antes de leer nada, y de paso le
        // devuelve a la tarjeta el ancho completo para el número.
        //
        // El título usa el `sectionTitle` de `AppTheme` tal cual, sin
        // retoques locales: las cinco pantallas titulan igual.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(child: Text('MI PLAN', style: AppTheme.sectionTitle)),
              const SizedBox(width: AppSpacing.entre),
              _MedallonNivel(nivel: nivelActual),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.entre),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _HeroCashback(),
        ),
        const SizedBox(height: AppSpacing.entre),
        // Sin margen: de borde a borde.
        _RielDeCategorias(
          elegida: _elegida,
          alElegir: _elegir,
          sinVerificar: sinVerificar,
        ),
      ],
    );

    // Se vuelve a dibujar cuando alguien refresca en CUALQUIER pantalla,
    // no solo acá: los datos son uno solo.
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: datosRecargados,
          builder: (context, _, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: const AppHeader(),
              ),
              const SizedBox(height: 16),
              // ---- LA ZONA FIJA ----
              //
              // El cabezal no scrollea: el monto del año y el riel de
              // categorías tienen que estar SIEMPRE a la vista, porque
              // son la pantalla. Lo único que cambia es lo de abajo, y
              // cambia solo cuando se toca un botón.
              //
              // `RepaintBoundary` porque abajo hay un scroll: sin esto,
              // cada cuadro del scroll vuelve a pintar también el
              // cabezal, que tiene degradado y sombras. Es una de las
              // cosas que hacían que se sintiera trabado.
              if (!sueltoElCabezal) RepaintBoundary(child: cabezal),
              if (!sueltoElCabezal) const SizedBox(height: AppSpacing.entre),
              Expanded(
                child: _ZonaQueCambia(
                  cabezal: sueltoElCabezal ? cabezal : null,
                  elegida: _elegida,
                  aseguradora: aseguradora,
                  uso: uso,
                  alCerrar: _cerrar,
                ),
              ),
              const BottomNavBar(currentIndex: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lo único que cambia de la pantalla: la plata, o UNA categoría.
///
/// SOLO SE ANIMA LO QUE CAMBIA (revisión de Daniel, 22 de septiembre de
/// 2026). El título, el medallón de nivel y la tarjeta del cashback
/// dicen lo mismo con cualquier filtro puesto, así que no tienen por qué
/// volver a entrar cada vez que se toca uno: una pieza que se desvanece
/// y vuelve se lee como que cambió, y ahí el usuario la vuelve a leer
/// para nada.
///
/// Con la pantalla alta eso ya pasaba solo, porque el cabezal vive
/// afuera del scroll. El que se animaba de más era el caso contrario
/// —pantalla corta o letra grande—, donde el cabezal baja adentro del
/// scroll para poder scrollear: ahí quedaba adentro del `AnimatedSwitcher`
/// y entraba con todo lo demás. Ahora el switcher envuelve SOLO al
/// contenido de abajo, en los dos casos.
///
/// El scroll vuelve arriba al cambiar de vista, que antes lo hacía una
/// llave en el `CustomScrollView`. La llave reconstruía el scroll
/// entero —cabezal incluido— y era justamente lo que obligaba a animar
/// todo junto; ahora el salto lo hace el controlador y no se toca nada
/// más. Sin esto, entrar a Contacto después de haber bajado en Cobertura
/// dejaría la pantalla a mitad de camino de un contenido que ya no
/// existe.
class _ZonaQueCambia extends StatefulWidget {
  const _ZonaQueCambia({
    required this.cabezal,
    required this.elegida,
    required this.aseguradora,
    required this.uso,
    required this.alCerrar,
  });

  /// Solo cuando el texto del sistema es tan grande que el cabezal dejó
  /// de estar fijo y viaja adentro del scroll.
  final Widget? cabezal;
  final _Categoria? elegida;
  final Aseguradora aseguradora;
  final UsoDelSeguro uso;
  final VoidCallback alCerrar;

  @override
  State<_ZonaQueCambia> createState() => _ZonaQueCambiaState();
}

class _ZonaQueCambiaState extends State<_ZonaQueCambia> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant _ZonaQueCambia anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.elegida != widget.elegida && _scroll.hasClients) {
      // De un salto y no animado: lo que se mira es la vista nueva
      // entrando, y un scroll viajando al mismo tiempo son dos
      // movimientos discutiendo por la misma pantalla.
      _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// La vista de abajo: la plata, o la categoría abierta.
  ///
  /// La LLAVE es la categoría: es lo que le dice al switcher que esto es
  /// otra vista y no la misma con otros datos. Dos categorías distintas
  /// son las dos un `_PanelCategoria`, así que sin llave el cambio
  /// pasaría sin transición.
  Widget _contenido() {
    final categoria = widget.elegida;
    if (categoria == null) return _VistaDeLaPlata(key: const ValueKey('plata'));
    return _PanelCategoria(
      key: ValueKey(categoria),
      categoria: categoria,
      aseguradora: widget.aseguradora,
      uso: widget.uso,
      alCerrar: widget.alCerrar,
    );
  }

  /// El contenido, entrando. Es lo ÚNICO que se anima de la pantalla.
  Widget _contenidoAnimado() => AnimatedSwitcher(
    duration: duracionEntradaPanel,
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeIn,
    // El que sale se va en la MITAD de tiempo que el que entra: si los
    // dos duran lo mismo, durante medio cruce se ven las dos vistas
    // encimadas y se lee como un fantasma.
    reverseDuration: duracionEntradaPanel ~/ 2,
    layoutBuilder: (actual, anteriores) => Stack(
      alignment: Alignment.topCenter,
      children: [
        // El que se va queda anclado arriba y con su propio alto: una
        // vista larga forzada al alto de una corta se desborda, y el
        // alto de esta caja lo manda SIEMPRE la que entra.
        for (final anterior in anteriores)
          Positioned(top: 0, left: 0, right: 0, child: anterior),
        ?actual,
      ],
    ),
    transitionBuilder: (hijo, animacion) => FadeTransition(
      opacity: animacion,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, desplazamientoEntradaPanel),
          end: Offset.zero,
        ).animate(animacion),
        child: hijo,
      ),
    ),
    child: _contenido(),
  );

  @override
  Widget build(BuildContext context) {
    final quieto = MediaQuery.of(context).disableAnimations;
    final cabezal = widget.cabezal;

    // CustomScrollView y no SingleChildScrollView porque el control de
    // refresco de Cupertino es un sliver y solo vive adentro de uno.
    return CustomScrollView(
      controller: _scroll,
      physics: fisicaConRefresco,
      slivers: [
        const RefrescoVida(),
        // El cabezal va AFUERA del switcher aunque scrollee con lo
        // demás: no cambia con el filtro, así que no se mueve.
        if (cabezal != null)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cabezal,
                const SizedBox(height: AppSpacing.seccion),
              ],
            ),
          ),
        SliverPadding(
          // Sin margen lateral acá: el cabezal trae el suyo pieza por
          // pieza, porque el riel de categorías tiene que llegar hasta
          // los bordes. Lo que va debajo se lo pone solo.
          padding: const EdgeInsets.only(bottom: 24),
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: quieto ? _contenido() : _contenidoAnimado(),
            ),
          ),
        ),
      ],
    );
  }
}

/// La vista por defecto: lo que queda de la plata cuando el monto del
/// año ya está arriba, fijo.
class _VistaDeLaPlata extends StatelessWidget {
  const _VistaDeLaPlata({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SeccionProyeccion(),
        const SizedBox(height: AppSpacing.seccion),
        _SeccionCalendario(),
      ],
    );
  }
}

// ============================================================
// 1. HERO — EL CASHBACK QUE PAGA TU NIVEL DE HOY
// ============================================================

class _HeroCashback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pct = nivelPorNumero(nivelActual)?.porcentajeCashback;

    final tarjeta = Container(
      width: double.infinity,
      decoration: _tarjetaHero(),
      // La luz de la esquina y el hairline del pie llegan hasta los
      // bordes, así que la tarjeta tiene que recortar contra su radio.
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // UNA LUZ EN LA ESQUINA, no un ícono de marca de agua.
          //
          // La faja de una categoría lleva su ícono al fondo porque ahí
          // el ícono DICE algo: es el mismo del botón que se tocó. Acá
          // no hay ningún ícono que signifique "cashback" sin mentir —
          // una alcancía se lee como ahorro, que es justo la palabra que
          // la Superintendencia de Bancos no deja usar. Así que el fondo
          // lleva luz y nada más.
          Positioned(
            top: -70,
            right: -50,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // La etiqueta va en una PÍLDORA, no en texto suelto.
                    //
                    // Suelta se leía como una nota al pie de un número
                    // gigante. En la píldora el mismo renglón trae
                    // relleno propio, así que se ve como una etiqueta
                    // puesta a propósito y no como el sobrante de arriba
                    // del monto. Es la MISMA píldora de "Al día" y de
                    // "Destacado" en Premios; acá no se inventa un chip
                    // nuevo, solo cambia el relleno porque abajo hay
                    // azul en vez de blanco.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'TU CASHBACK DE ESTE AÑO',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.dentro),
                    // EL número de la pantalla, y ahora con la tarjeta
                    // entera para él: el medallón del nivel se fue
                    // arriba, al renglón del título.
                    //
                    // Sube desde 0 con `NumeroAnimado`, que ya trae los
                    // dígitos de ancho fijo (para que no tiemble al
                    // contar), la compuerta de una animación por tanda de
                    // datos —no una por montaje, que haría subir el
                    // número en cada cambio de pestaña— y el respeto por
                    // "Reducir movimiento".
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: NumeroAnimado(
                        valor: cashbackProyectado,
                        formato: (v) => 'Q${milesConComa(v)}',
                        alineacion: Alignment.centerLeft,
                        estilo: AppTheme.display(
                          54,
                        ).copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.dentro),
                    Text(
                      _renglonDeApoyo(pct),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              // El hairline y no un cambio de relleno: el degradado sigue
              // pasando por detrás del pie, así la tarjeta se lee como una
              // sola pieza con una nota al pie.
              Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
              const _PieRegulatorio(),
            ],
          ),
        ],
      ),
    );

    // "Reducir movimiento" del sistema: la tarjeta aparece y listo.
    if (MediaQuery.of(context).disableAnimations) return tarjeta;

    // La tarjeta ENTRA, no está puesta desde antes. Es `flutter_animate`
    // con los mismos gestos del resto de la app —fundido con un
    // acercamiento mínimo y unos píxeles de subida—, y corre una sola
    // vez al montarse. El conteo del monto arranca al mismo tiempo, así
    // que la tarjeta llega y el número sube adentro de ella.
    return tarjeta
        .animate()
        .fadeIn(duration: duracionEntradaPanel, curve: Curves.easeOut)
        .slideY(
          begin: 0.08,
          end: 0,
          duration: duracionEntradaPanel,
          curve: Curves.easeOutCubic,
        )
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          duration: duracionEntradaPanel,
          curve: Curves.easeOutCubic,
        );
  }

  /// El renglón que explica el número, con la prima COMPLETA adentro.
  String _renglonDeApoyo(double? pct) {
    if (pct == null) {
      return 'El % de cashback de tu nivel todavía no está definido.';
    }
    return 'Es el ${_porcentaje(pct)}% de tu prima anual de $primaAnual, '
        'por ir en Nivel $nivelActual';
  }
}

/// El medallón del nivel: disco con el número adentro.
///
/// SE ANIMA CUANDO EL NIVEL CAMBIA, no cuando la pantalla se monta.
/// Subir de nivel mientras estás mirando es raro pero puede pasar justo
/// después de jalar para refrescar, y ahí el número no puede cambiar en
/// seco. Animar al montarse sería lo contrario de lo que se quiere: la
/// barra de abajo navega con `pushReplacementNamed`, así que cada cambio
/// de pestaña monta la pantalla de cero y el medallón latiría cada vez.
///
/// El número NO cuenta hacia arriba. "Nivel 3" es una etiqueta, no una
/// cantidad, y `numero_animado.dart` es explícito: verla girar convierte
/// la app en una tragamonedas. Lo que se anima es el medallón entero —un
/// acercamiento con fundido—, no la cifra.
///
/// El color sale de `colorForNivel`, así que el medallón dice el nivel
/// dos veces: con el número y con la luminosidad del azul (nivel 1 el
/// más claro, nivel 4 el `accent` entero).
class _MedallonNivel extends StatefulWidget {
  const _MedallonNivel({required this.nivel});

  final int nivel;

  @override
  State<_MedallonNivel> createState() => _MedallonNivelState();
}

class _MedallonNivelState extends State<_MedallonNivel>
    with SingleTickerProviderStateMixin {
  /// 58 y no 52: ahora el medallón vive en la esquina de arriba, al lado
  /// del título, y tiene que competir con una tarjeta azul entera que
  /// está justo abajo. A 52 se leía como un adorno del título.
  static const double _lado = 58;

  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: duracionNumeroAnimado,
    // Quieto y terminado por defecto. Solo se rebobina si el nivel
    // cambió de verdad.
    value: 1,
  );

  @override
  void didUpdateWidget(_MedallonNivel anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.nivel == widget.nivel) return;
    if (MediaQuery.of(context).disableAnimations) return;
    _controlador.forward(from: 0);
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.colorForNivel(widget.nivel);

    // El disco CRECE un poco con el texto del sistema, pero no lo sigue
    // hasta el final: al 160% un medallón proporcional se comería el
    // monto. Crece hasta el 130% y de ahí el FittedBox acomoda el
    // contenido adentro, igual que hace `insignia_rango.dart` con el
    // rango de dos dígitos.
    final escala = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    final lado = _lado * escala;

    // RELLENO ENTERO, no un disco pálido con borde.
    //
    // Era el color del nivel al 12% con un aro al 35%: casi blanco, y en
    // la esquina de arriba desaparecía. Ahora el disco va con el color
    // del nivel de verdad y el texto en blanco, así que el nivel se ve
    // antes de leer nada — que es justamente lo que tiene que pasar con
    // el dato que decide cuánto cashback cobrás.
    //
    // El degradado OSCURECE hacia abajo, igual que el del cabezal y el
    // de la faja: es el mismo color con menos luz, nunca un matiz nuevo.
    // Aclarando hacia arriba el medallón se veía de plástico.
    final medallon = Container(
      width: lado,
      height: lado,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.3)!],
        ),
        shape: BoxShape.circle,
        // El aro blanco lo despega de lo que tenga detrás, igual que la
        // marca naranja de los botones del riel.
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.azulSombra.withValues(alpha: 0.26),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'NIVEL',
              style: TextStyle(
                // Blanco al 85% y no entero: así la palabra se lee pero
                // no le compite al número, que es el dato.
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.nivel}',
              style: AppTheme.display(24).copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'Nivel ${widget.nivel}, ver la escalera de niveles',
      excludeSemantics: true,
      // EL MEDALLÓN ABRE LA ESCALERA (decisión de Daniel, 22 de
      // septiembre de 2026). La gráfica de los cinco niveles vivía
      // siempre abierta en Hoy; ahora se abre acá, que es donde alguien
      // pregunta por su nivel. Un disco con un número adentro es
      // exactamente lo que se toca para saber qué significa ese número.
      child: GestureDetector(
        onTap: () => mostrarHojaNiveles(context),
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controlador,
          builder: (context, hijo) {
            // La MISMA curva que el resto de la app (easeOutCubic).
            final avance = curvaNumeroAnimado.transform(_controlador.value);
            return Opacity(
              opacity: 0.35 + 0.65 * avance,
              child: Transform.scale(scale: 0.82 + 0.18 * avance, child: hijo),
            );
          },
          child: medallon,
        ),
      ),
    );
  }
}

/// La nota regulatoria, al pie del hero y adentro de la misma tarjeta.
///
/// No dice "cashback aplicado": "aplicado" se lee como aplicado A la
/// prima, que es justo lo que la Superintendencia de Bancos no permite.
class _PieRegulatorio extends StatelessWidget {
  const _PieRegulatorio();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        'Tu cashback se devuelve como dinero, después del pago de tu '
        'prima. Nunca se descuenta de tu póliza.',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          // Blanco al 78% sobre el azul de marca: da 7,4:1, bastante
          // arriba del 4,5:1 que pide WCAG AA. No bajarlo sin volver a
          // medir — es una nota regulatoria, tiene que poder leerse.
          color: Colors.white.withValues(alpha: 0.78),
          height: 1.35,
        ),
      ),
    );
  }
}

// ============================================================
// 2. PROYECCIÓN — CUÁNTO FALTA PARA EL NIVEL SIGUIENTE
// ============================================================

/// El nivel de arriba y qué falta para llegar.
///
/// NO dice "a tu ritmo terminarías el año en nivel X": eso necesitaría
/// una regresión sobre el histórico real que nadie calculó todavía, y
/// prometer un nivel por una cuenta que no existe es peor que no decir
/// nada. Lo que sí se puede afirmar es condicional y exacto: cuántos
/// puntos faltan y cuánto pagaría ese nivel.
class _SeccionProyeccion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final siguiente = nivelPorNumero(nivelActual + 1);

    // Sin superficie: el título de bloque y el aire de abajo alcanzan
    // para separarla de lo que sigue. El mismo encabezado que el
    // calendario, para que las dos secciones se lean como hermanas y no
    // como dos piezas de distinto origen.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TituloDeBloque(
          icono: Icons.trending_up_rounded,
          texto: siguiente == null
              ? 'Tu nivel del año'
              : 'Tu proyección al siguiente nivel',
        ),
        const SizedBox(height: AppSpacing.entre),
        if (siguiente == null)
          _sinNivelSiguiente(context)
        else
          ..._conNivelSiguiente(context, siguiente),
      ],
    );
  }

  /// Ya está en el nivel más alto de la tabla: no hay barra que llenar.
  Widget _sinNivelSiguiente(BuildContext context) {
    final pct = nivelPorNumero(nivelActual)?.porcentajeCashback;
    return Text(
      pct == null
          ? 'Estás en el nivel más alto del programa. El año cierra el '
                '$cierreDelAno.'
          : 'Estás en el nivel más alto del programa, con el '
                '${_porcentaje(pct)}% de cashback. Ya no hay nivel que '
                'subir: el año cierra el $cierreDelAno.',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
        height: 1.4,
      ),
    );
  }

  List<Widget> _conNivelSiguiente(BuildContext context, Nivel siguiente) {
    final piso = nivelPorNumero(nivelActual)?.puntosMinimos ?? 0;
    final techo = siguiente.puntosMinimos!;
    final avance = techo > piso
        ? ((puntosAnuales - piso) / (techo - piso)).clamp(0.0, 1.0)
        : 1.0;
    final faltan = techo - puntosAnuales;

    final pct = siguiente.porcentajeCashback;
    final prima = primaAnualNumero;
    // El monto solo si hay con qué calcularlo. Si la aseguradora no
    // mandó la prima como número, la tarjeta dice los puntos y se calla
    // el monto — nunca lo deriva dividiendo el cashback por el
    // porcentaje, que reventaría en el nivel 0.
    final montoSiguiente = (pct != null && prima != null)
        ? (prima * pct / 100).round()
        : null;

    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: avance,
          minHeight: 8,
          backgroundColor: AppColors.cardBorder,
          valueColor: AlwaysStoppedAnimation(
            AppColors.colorForNivel(siguiente.numero),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.entre),
      if (montoSiguiente != null) ...[
        Text.rich(
          TextSpan(
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              height: 1.35,
            ),
            children: [
              TextSpan(
                text: 'Q${milesConComa(montoSiguiente)}',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const TextSpan(text: ' — lo que pagaría el nivel siguiente'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.dentro),
      ],
      Text.rich(
        TextSpan(
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          children: [
            const TextSpan(text: 'Te faltan '),
            TextSpan(
              text: '${milesConComa(faltan)} pts',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: ' para Nivel ${siguiente.numero}'),
          ],
        ),
      ),
    ];
  }
}

// ============================================================
// 3. EL CALENDARIO
// ============================================================

/// Los tres momentos del cashback, en una línea de tiempo vertical.
///
/// En vertical, encadenados por un riel, se ve que uno lleva al
/// siguiente; en fila se leían como tres avisos sueltos.
///
/// Ninguno lleva check naranja: el naranja de una etapa completada es
/// para lo que YA pasó, y acá los tres pasos son futuros.
class _SeccionCalendario extends StatelessWidget {
  static const List<({IconData icono, String cuando, String que})> _pasos = [
    (
      icono: Icons.event_outlined,
      cuando: cierreDelAno,
      que: 'Se cierra tu nivel del año',
    ),
    (
      icono: Icons.calculate_outlined,
      cuando: 'Enero',
      que: 'Calculamos tu cashback',
    ),
    (
      icono: Icons.payments_outlined,
      cuando: '30 días después',
      que: 'Te lo depositamos',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TituloDeBloque(
          icono: Icons.calendar_month_outlined,
          texto: 'Calendario de pagos',
        ),
        const SizedBox(height: AppSpacing.entre),
        for (var i = 0; i < _pasos.length; i++)
          _PasoDelCalendario(
            numero: i + 1,
            icono: _pasos[i].icono,
            cuando: _pasos[i].cuando,
            que: _pasos[i].que,
            ultimo: i == _pasos.length - 1,
          ),
        const SizedBox(height: AppSpacing.dentro),
        Text(
          // El depósito depende de que la prima esté pagada: decirlo
          // acá evita que alguien lo espere antes de tiempo.
          'El depósito sale después de que pagues tu siguiente prima.',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _PasoDelCalendario extends StatelessWidget {
  const _PasoDelCalendario({
    required this.numero,
    required this.icono,
    required this.cuando,
    required this.que,
    required this.ultimo,
  });

  final int numero;
  final IconData icono;
  final String cuando;
  final String que;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight para que el riel sepa hasta dónde bajar: sin esto
    // el Expanded de abajo no tiene alto contra el que crecer.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.azulBruma,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$numero',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!ultimo)
                  Expanded(
                    child: Container(width: 2, color: AppColors.azulSuave),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              // El último no deja aire abajo: el riel ya terminó.
              padding: EdgeInsets.only(bottom: ultimo ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          cuando,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.dentro),
                      Icon(icono, size: 15, color: AppColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    que,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 4. LOS CUATRO BLOQUES DE LA PÓLIZA
// ============================================================

/// Las cuatro categorías de detalle de la póliza.
///
/// Cada una tiene DOS nombres y no es redundancia:
///   - [etiqueta] es la del filtro: una palabra corta, porque los cuatro
///     filtros van en una fila y tienen que medir lo mismo. Con
///     "IDENTIFICACIÓN" adentro, cuatro tiles no entran en ningún
///     iPhone.
///   - [titulo] es el del bloque: ahí sí hay ancho de sobra y el nombre
///     puede decir de qué se trata sin abreviar.
enum _Categoria {
  identificacion('Póliza', 'Tu póliza', Icons.badge_outlined),
  cobertura('Cobertura', 'Tu cobertura', Icons.health_and_safety_outlined),
  pagos('Pagos', 'Pagos y prima', Icons.credit_card_outlined),
  aseguradora('Contacto', 'Tu aseguradora', Icons.apartment_outlined);

  const _Categoria(this.etiqueta, this.titulo, this.icono);

  /// La del filtro. Una palabra, en capitalización normal y no en
  /// mayúsculas: las versales son más anchas y acá el ancho es el que
  /// manda.
  final String etiqueta;

  /// El del bloque al que lleva el filtro.
  final String titulo;

  /// El ícono del filtro es EL MISMO del bloque al que lleva, así la
  /// relación entre lo que se toca y adónde se llega se ve sin leer.
  ///
  /// Ninguno se repite con otro ícono visible en la pantalla:
  ///   - `badge_outlined` (credencial) y no `person_outline`, que se
  ///     leería como "andá a tu Perfil" — hay un Perfil en la app.
  ///   - `health_and_safety_outlined` (escudo con cruz, que le hace eco
  ///     a la cruz de la marca) y no `shield_outlined`.
  ///   - `credit_card_outlined` y no `payments_outlined`, que el
  ///     calendario ya usa para "Te lo depositamos". Son plata en
  ///     direcciones opuestas: lo que pagás contra lo que te devuelven,
  ///     y es el peor lugar para compartir un ícono.
  ///   - `apartment_outlined` (el edificio) y no un teléfono: adentro de
  ///     ese bloque las filas de contacto ya tienen cada una su ícono
  ///     —auricular, agente, sobre, reloj— y un teléfono en el filtro
  ///     competiría con los de adentro.
  final IconData icono;
}

/// Los datos de una categoría, sin encabezado.
///
/// El nombre de la categoría NO se repite acá: ya lo dice la faja de
/// color que va arriba, y decirlo dos veces en 60 px se lee como un
/// error. Este bloque es solo el contenido.
class _BloqueCategoria extends StatelessWidget {
  const _BloqueCategoria({
    required this.categoria,
    required this.aseguradora,
    required this.uso,
  });

  final _Categoria categoria;
  final Aseguradora aseguradora;
  final UsoDelSeguro uso;

  @override
  Widget build(BuildContext context) => _contenido();

  Widget _contenido() {
    switch (categoria) {
      case _Categoria.identificacion:
        return _SeccionPoliza(
          filas: [
            // El número de póliza se copia: es el dato que hay que
            // dictar o pegar cada vez que se llama a la aseguradora.
            _FilaDato('Número de póliza', numeroPoliza, copiable: true),
            _FilaDato('Titular y dependientes', titularYDependientes),
            _FilaDato('Tipo de plan', tipoPlan),
            _FilaDato('Vigencia', vigencia),
            _FilaDato('Renovación', fechaRenovacion),
          ],
        );
      case _Categoria.cobertura:
        return _SeccionPoliza(
          filas: [
            _FilaDato('Suma asegurada anual', sumaAsegurada),
            _FilaDato('Deducible', deducible),
            _FilaDato('Coaseguro', coaseguro),
            _FilaDato('Red de cobertura', redCobertura),
          ],
        );
      case _Categoria.pagos:
        // Sin vigencia ni renovación: viven en el bloque de Póliza. Si
        // estuvieran en los dos lugares, el mismo dato aparecería dos
        // veces en una pantalla.
        return _SeccionPoliza(
          filas: [
            // En azul de marca, y SIN TACHAR NUNCA. La prima se paga
            // completa: el cashback vuelve como dinero aparte, después.
            _FilaDato('Prima anual', primaAnual, color: AppColors.accent),
            _FilaDato('Forma de pago', formaPago),
          ],
        );
      case _Categoria.aseguradora:
        return _PanelAseguradora(aseguradora: aseguradora, uso: uso);
    }
  }
}

// ============================================================
// 5. EL RIEL DE CATEGORÍAS
//
// UNA SOLA TIRA, DE BORDE A BORDE. Eran cuatro tarjetas sueltas con
// aire entre ellas y margen a los costados, y esos huecos blancos eran
// lo primero que se veía: el ojo leía los espacios antes que los
// íconos. Ahora es una tira continua que toca los dos bordes de la
// pantalla, sin margen y sin separación, y adentro cuatro segmentos
// iguales. No hay un solo pedazo de fondo a la vista.
//
// EL SELECCIONADO NO SE PRENDE: SE DESLIZA HASTA AHÍ. La píldora azul
// viaja del segmento que dejás al que tocás, con la misma curva y casi
// el mismo tiempo que el indicador de la barra de abajo. Es lo que hace
// que la tira se sienta un control y no cuatro botones que se
// encienden y se apagan: el movimiento dice que los cuatro son partes
// de lo mismo.
//
// Y cuando no hay ninguna categoría abierta, la píldora NO se esconde
// de golpe ni se queda en un segmento mintiendo: se apaga donde está.
//
// POR QUÉ SIGUE SIN SER UN `CupertinoSlidingSegmentedControl`. Sería lo
// primero en el orden de CLAUDE.md y ahora se le parece mucho más, pero
// sigue sin poder llevar el marcador naranja de "sin verificar" ni
// apilar ícono sobre etiqueta, y su selección nunca puede quedar vacía
// —acá sí, que es el estado en el que se entra a la pantalla—. De
// Cupertino se toma lo que importa igual: el atenuado al tocar de
// `CupertinoButton`.
// ============================================================

/// Cuánto tarda la píldora en viajar de un segmento al otro.
///
/// El mismo tiempo que el indicador de la barra de abajo. Dos
/// indicadores que se deslizan en la misma app no pueden tardar
/// distinto.
const Duration duracionDeslizarRiel = Duration(milliseconds: 320);

/// El riel: una tira con cuatro segmentos iguales.
class _RielDeCategorias extends StatelessWidget {
  const _RielDeCategorias({
    required this.elegida,
    required this.alElegir,
    required this.sinVerificar,
  });

  final _Categoria? elegida;
  final void Function(_Categoria) alElegir;
  final bool sinVerificar;

  /// Alto de la tira.
  static const double _alto = 88;

  /// Cuánto se mete la píldora para adentro de su segmento.
  ///
  /// Sin este aire la píldora tocaría el borde de arriba y el de abajo
  /// de la tira y ya no se leería como algo que se posó encima, sino
  /// como que la tira cambió de color en ese tramo.
  static const double _aire = 6;

  @override
  Widget build(BuildContext context) {
    final categorias = _Categoria.values;
    final quieto = MediaQuery.of(context).disableAnimations;
    final indice = elegida == null ? 0 : categorias.indexOf(elegida!);

    return SizedBox(
      height: _alto,
      // `LayoutBuilder` porque la píldora necesita saber cuánto mide un
      // segmento para poder viajar: es el ancho de la pantalla dividido
      // cuatro, y eso solo se sabe en layout. Escrito a mano habría que
      // corregirlo en cada tamaño de iPhone.
      child: LayoutBuilder(
        builder: (context, medidas) {
          final anchoSegmento = medidas.maxWidth / categorias.length;

          return Stack(
            children: [
              // El fondo de la tira, con sus dos hairlines.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.azulNiebla,
                    border: Border.symmetric(
                      horizontal: BorderSide(color: AppColors.cardBorder),
                    ),
                  ),
                ),
              ),

              // Los separadores, muy tenues y sin llegar a los bordes:
              // dividen sin cortar la tira en cuatro cajas.
              for (var i = 1; i < categorias.length; i++)
                Positioned(
                  left: anchoSegmento * i,
                  top: 22,
                  bottom: 22,
                  width: 1,
                  child: ColoredBox(
                    color: AppColors.azulSuave.withValues(alpha: 0.5),
                  ),
                ),

              // La píldora que viaja.
              AnimatedPositioned(
                duration: quieto ? Duration.zero : duracionDeslizarRiel,
                // easeOutCubic: arranca rápido y frena al llegar, que es
                // como se mueven las cosas en iOS. Sin rebote: la
                // píldora no es un elemento con el que se juega.
                curve: Curves.easeOutCubic,
                left: anchoSegmento * indice + _aire,
                width: anchoSegmento - _aire * 2,
                top: _aire,
                bottom: _aire,
                child: AnimatedOpacity(
                  duration: quieto ? Duration.zero : duracionDeslizarRiel,
                  // Sin categoría abierta la píldora se apaga DONDE
                  // ESTÁ, no salta al primer segmento: un indicador que
                  // se teletransporta al desaparecer se ve como un error.
                  opacity: elegida == null ? 0 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: degradadoDeMarca,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.azulSombra.withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Los cuatro segmentos, encima de la píldora: el contenido
              // tiene que poder pintarse en blanco sobre ella.
              Row(
                children: [
                  for (var i = 0; i < categorias.length; i++)
                    SizedBox(
                      width: anchoSegmento,
                      child: _SegmentoCategoria(
                        categoria: categorias[i],
                        abierta: categorias[i] == elegida,
                        alToque: () => alElegir(categorias[i]),
                        sinVerificar:
                            sinVerificar &&
                            categorias[i] == _Categoria.aseguradora,
                        posicion: i,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Un segmento del riel: el ícono en su disco, y una palabra abajo.
///
/// NO TIENE FONDO PROPIO. El relleno de la selección es la píldora que
/// viaja por detrás; si además cada segmento se pintara a sí mismo,
/// habría dos cosas azules cambiando a la vez y el deslizamiento se
/// perdería debajo de un encendido instantáneo.
///
/// LO QUE LO HACE VERSE SIMÉTRICO ES EL DISCO, no el ancho. Los cuatro
/// segmentos siempre midieron lo mismo y aun así la fila se veía
/// despareja: cada ícono de Material tiene su propia silueta (la
/// credencial es ancha y chata, el escudo alto y puntiagudo, el
/// edificio cuadrado), así que a la misma caja le llenaban áreas
/// distintas. Metiéndolos a todos adentro de un disco del mismo
/// diámetro, lo que el ojo compara pasa a ser el disco y no el dibujo.
class _SegmentoCategoria extends StatelessWidget {
  const _SegmentoCategoria({
    required this.categoria,
    required this.abierta,
    required this.alToque,
    required this.sinVerificar,
    required this.posicion,
  });

  final _Categoria categoria;

  /// True cuando su panel es el que está abierto abajo.
  final bool abierta;
  final VoidCallback alToque;
  final bool sinVerificar;

  /// Qué lugar ocupa en la tira, de 0 a 3. Solo para escalonar la
  /// entrada.
  final int posicion;

  /// El diámetro del disco del ícono. El mismo para los cuatro.
  static const double _disco = 40;

  @override
  Widget build(BuildContext context) {
    final quieto = MediaQuery.of(context).disableAnimations;
    final duracion = quieto ? Duration.zero : duracionDeslizarRiel;

    // Abierta: el ícono y el texto en blanco, sobre la píldora. Cerrada:
    // el azul de apoyo. Seleccionar es SIEMPRE azul — la misma regla
    // que la píldora de la barra de abajo y los filtros de Premios.
    final colorContenido = abierta ? Colors.white : AppColors.azulMedio;

    final contenido = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // El disco: lo que iguala a los cuatro íconos.
        AnimatedContainer(
          duration: duracion,
          curve: Curves.easeOutCubic,
          width: _disco,
          height: _disco,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Blanco translúcido sobre la píldora y no blanco sólido:
            // sólido sería una mancha, translúcido deja pasar el
            // degradado y el disco se lee como parte del segmento.
            color: abierta
                ? Colors.white.withValues(alpha: 0.22)
                : AppColors.azulBruma,
            shape: BoxShape.circle,
          ),
          child: Icon(categoria.icono, size: 21, color: colorContenido),
        ),
        const SizedBox(height: 7),
        // FittedBox y no una tipografía más chica: en un iPhone SE hay
        // 80 px de ancho por segmento y "Cobertura" entra justo.
        // Encoger solo la que lo necesita es mejor que achicar las
        // cuatro para el caso más angosto.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: AnimatedDefaultTextStyle(
            duration: duracion,
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: abierta ? Colors.white : AppColors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
              height: 1.2,
            ),
            child: Text(categoria.etiqueta, maxLines: 1),
          ),
        ),
      ],
    );

    // El marcador de "sin verificar" va arriba a la derecha, adentro del
    // segmento. Es solo el triángulo, sin texto: en un cuarto de
    // pantalla "Sin verificar" no entra, y el naranja sólido en chico es
    // exactamente el uso que CLAUDE.md le reserva a las alertas reales.
    final conMarca = sinVerificar
        ? Stack(
            children: [
              Positioned.fill(child: contenido),
              const Positioned(top: 10, right: 10, child: _MarcaSinVerificar()),
            ],
          )
        : contenido;

    final conEntrada = quieto ? conMarca : _entrando(conMarca);

    return Semantics(
      button: true,
      selected: abierta,
      label: sinVerificar
          ? '${categoria.etiqueta}, datos sin verificar'
          : categoria.etiqueta,
      hint: abierta ? 'Tocá para cerrarla' : 'Abre ${categoria.titulo}',
      excludeSemantics: true,
      // `CupertinoButton` y no un GestureDetector: trae el atenuado al
      // tocar que un usuario de iPhone ya conoce, y CLAUDE.md pide bajar
      // a lo hecho a mano solo cuando Cupertino no resuelve.
      child: CupertinoButton(
        onPressed: alToque,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        // El blanco de toque es el segmento ENTERO, no el contenido: un
        // cuarto de pantalla por 88 px de alto.
        child: SizedBox.expand(child: conEntrada),
      ),
    );
  }

  /// La entrada del segmento: los cuatro aparecen escalonados, de
  /// izquierda a derecha.
  ///
  /// Es `flutter_animate`, la misma librería con la que entran los logos
  /// del catálogo de Premios, y con los mismos gestos: un fundido con un
  /// acercamiento mínimo más unos píxeles de subida. NO es un rebote: la
  /// app tiene que transmitir calma, y cuatro segmentos rebotando arriba
  /// de la pantalla son cuatro cosas moviéndose al mismo tiempo.
  ///
  /// Se anima el CONTENIDO y no el segmento entero: la tira ya está
  /// puesta desde el primer cuadro, y lo que llega son los íconos. Una
  /// tira que entra a pedazos se vería rota.
  Widget _entrando(Widget pieza) {
    final espera = escalonEntradaBoton * posicion;
    return pieza
        .animate()
        .fadeIn(
          duration: duracionEntradaBoton,
          delay: espera,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.14,
          end: 0,
          duration: duracionEntradaBoton,
          delay: espera,
          curve: Curves.easeOutCubic,
        )
        .scale(
          begin: const Offset(0.94, 0.94),
          end: const Offset(1, 1),
          duration: duracionEntradaBoton,
          delay: espera,
          curve: Curves.easeOutCubic,
        );
  }
}

/// El panel de una categoría: una faja de color con su nombre, y abajo
/// los datos.
///
/// LA FAJA ES EL COLOR DE LA PANTALLA. El panel ocupa todo lo que no es
/// cabezal, así que sin ella la mitad de abajo quedaba blanca sobre
/// blanco y el cambio de categoría casi no se notaba. Con la faja, cada
/// categoría se abre con un bloque de azul de marca, su ícono grande al
/// fondo y su nombre completo en blanco: se ve desde lejos QUÉ se abrió.
///
/// El ícono de marca de agua va recortado contra el radio de la faja y
/// a baja opacidad. No es decoración sola: es el MISMO ícono del botón
/// que se acaba de tocar, así que dice de dónde vino este panel.
class _PanelCategoria extends StatelessWidget {
  const _PanelCategoria({
    super.key,
    required this.categoria,
    required this.aseguradora,
    required this.uso,
    required this.alCerrar,
  });

  final _Categoria categoria;
  final Aseguradora aseguradora;
  final UsoDelSeguro uso;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context) {
    final faja = _FajaDeCategoria(categoria: categoria, alCerrar: alCerrar);
    final datos = _BloqueCategoria(
      categoria: categoria,
      aseguradora: aseguradora,
      uso: uso,
    );

    // "Reducir movimiento" del sistema: acá el panel aparece y listo.
    final quieto = MediaQuery.of(context).disableAnimations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        quieto ? faja : _entrando(faja, 0),
        const SizedBox(height: AppSpacing.entre),
        quieto ? datos : _entrando(datos, 1),
      ],
    );
  }

  /// Las dos piezas del panel entran ESCALONADAS, no juntas.
  ///
  /// Primero la faja y 90 ms después los datos. El ojo las recorre en el
  /// orden en que se leen —qué abriste, y recién después qué dice— en
  /// vez de encontrarse el bloque entero puesto de golpe.
  ///
  /// Se usa `flutter_animate`, la misma librería con la que entran los
  /// logos del catálogo de Premios, y con los mismos gestos: fundido con
  /// un acercamiento mínimo. NO es un rebote: la app tiene que
  /// transmitir calma.
  Widget _entrando(Widget pieza, int posicion) {
    final espera = duracionEntradaPanel ~/ 5 * posicion;
    return pieza
        .animate()
        .fadeIn(
          duration: duracionEntradaPanel,
          delay: espera,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: desplazamientoEntradaPanel,
          end: 0,
          duration: duracionEntradaPanel,
          delay: espera,
          curve: Curves.easeOutCubic,
        )
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          duration: duracionEntradaPanel,
          delay: espera,
          curve: Curves.easeOutCubic,
        );
  }
}

/// La faja de color que encabeza un panel.
class _FajaDeCategoria extends StatelessWidget {
  const _FajaDeCategoria({required this.categoria, required this.alCerrar});

  final _Categoria categoria;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: degradadoDeMarca,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.azulSombra.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // La marca de agua se sale de la caja por diseño: sin recortar, el
      // ícono gigante invadiría la tarjeta de abajo.
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -26,
            child: Icon(
              categoria.icono,
              size: 116,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ESTÁS VIENDO',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        categoria.titulo,
                        style: AppTheme.display(
                          26,
                        ).copyWith(color: Colors.white),
                      ),
                      // El estado de la póliza va acá y no en una
                      // tarjeta propia: "Al día" es una etiqueta de la
                      // póliza, no un dato más que leer. Va SOLO en la
                      // faja de Póliza.
                      if (categoria == _Categoria.identificacion) ...[
                        const SizedBox(height: AppSpacing.dentro),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            estadoPoliza,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // La X y no un "Volver": no se volvió de ningún lado, se
                // abrió algo acá mismo. Cerrarla devuelve a la plata.
                Semantics(
                  button: true,
                  label: 'Cerrar ${categoria.titulo}',
                  excludeSemantics: true,
                  child: CupertinoButton(
                    onPressed: alCerrar,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El triángulo naranja de "datos sin verificar".
class _MarcaSinVerificar extends StatelessWidget {
  const _MarcaSinVerificar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentSecondary,
        shape: BoxShape.circle,
        // El aro blanco lo despega del borde del tile, esté el tile
        // pálido o en azul entero.
        border: Border.all(color: AppColors.card, width: 2),
      ),
      child: const Icon(
        Icons.warning_amber_rounded,
        size: 12,
        color: Colors.white,
      ),
    );
  }
}

// ============================================================
// LOS PANELES
//
// Los tres primeros son `CupertinoListSection.insetGrouped`, el bloque
// agrupado de iOS: esquinas redondeadas y separadores hairline
// sangrados. Es material de CONSULTA —se busca un dato, no se lee de
// corrido—, así que acá no se anima ni cuenta ningún número.
// ============================================================

/// Lo que hace falta para dibujar una fila de la póliza.
class _FilaDato {
  const _FilaDato(
    this.etiqueta,
    this.valor, {
    this.color,
    this.copiable = false,
  });

  final String etiqueta;
  final String valor;

  /// Solo para el valor que tiene que resaltar (la prima).
  final Color? color;

  /// Si toca la fila se copia el valor al portapapeles.
  final bool copiable;
}

/// Los datos de la póliza: UNA LISTA, no una tarjeta.
///
/// Sigue siendo la lista agrupada de iOS —de ahí salen el alto mínimo de
/// fila, el gris de pulsado y los separadores— pero sin la superficie
/// blanca: `decoration` vacía, así que las filas se apoyan directo sobre
/// el fondo y lo único que las separa es la línea de un pelo. Es lo que
/// CLAUDE.md ya pide en Social y en Progreso: una lista es una lista, no
/// una pila de cajas.
///
/// `backgroundColor` transparente además de la decoración: sin eso el
/// bloque llega con el gris agrupado del sistema y la pantalla se vería
/// hecha de dos apps.
class _SeccionPoliza extends StatelessWidget {
  const _SeccionPoliza({required this.filas});

  final List<_FilaDato> filas;

  @override
  Widget build(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      // Los márgenes los maneja la pantalla, no la sección: así el ritmo
      // vertical sale de `AppSpacing` y no de las constantes de iOS.
      margin: EdgeInsets.zero,
      topMargin: 0,
      backgroundColor: Colors.transparent,
      // Vacía a propósito: sin color, sin borde y sin sombra.
      decoration: const BoxDecoration(),
      separatorColor: AppColors.cardBorder,
      // Los separadores llegan de punta a punta: sangrados se leían como
      // el interior de una caja que ya no está.
      dividerMargin: 0,
      additionalDividerMargin: 0,
      // Ninguna fila lleva ícono a la izquierda: sin esto los
      // separadores quedan sangrados como si lo llevaran.
      hasLeading: false,
      children: [for (final fila in filas) _FilaPoliza(fila: fila)],
    );
  }
}

/// Una fila de la póliza: etiqueta y valor.
///
/// El valor va A LA DERECHA cuando es corto y DEBAJO de la etiqueta
/// cuando es largo. No es un capricho: "Red nacional + emergencias
/// internacionales" a la derecha de su etiqueta se corta en un iPhone
/// angosto, y un dato de póliza truncado no sirve para nada. El umbral
/// se mide sobre el texto y no se declara fila por fila, así que el día
/// que la aseguradora mande un plan con nombre largo, la fila se acomoda
/// sola.
class _FilaPoliza extends StatefulWidget {
  const _FilaPoliza({required this.fila});

  final _FilaDato fila;

  /// A partir de acá el valor se va abajo.
  static const int _maxCaracteresEnLinea = 20;

  @override
  State<_FilaPoliza> createState() => _FilaPolizaState();
}

class _FilaPolizaState extends State<_FilaPoliza> {
  /// Cuánto dura el "Copiado" antes de volver al valor.
  static const Duration _avisoCopiado = Duration(milliseconds: 1600);

  Timer? _reloj;
  bool _copiado = false;

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  void _copiar() {
    // Tocar un dato es un toque sobre algo concreto: `lightImpact`.
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.fila.valor));
    setState(() => _copiado = true);
    _reloj?.cancel();
    _reloj = Timer(_avisoCopiado, () {
      if (mounted) setState(() => _copiado = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fila = widget.fila;
    final estiloEtiqueta = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    final estiloValor = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: fila.color ?? AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );

    // Con el texto del sistema en grande, TODOS los valores se van
    // abajo: a ese tamaño ni los cortos entran al lado de su etiqueta.
    // Es lo mismo que hace Ajustes de iOS.
    final textoEnGrande = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final largo =
        textoEnGrande || fila.valor.length > _FilaPoliza._maxCaracteresEnLinea;

    // OJO CON `maxLines`. Va explícito en los dos textos porque
    // `CupertinoListTile` envuelve su `title` en un DefaultTextStyle con
    // `maxLines: 1` y ellipsis: sin pisarlo, "Red nacional + emergencias
    // internacionales" se mostraría como "Red nacional + emerg…", y un
    // dato de póliza truncado no sirve para nada.
    final etiqueta = Text(
      fila.etiqueta,
      style: estiloEtiqueta,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    final valor = _copiado
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, size: 15, color: AppColors.accent),
              const SizedBox(width: 4),
              Text(
                'Copiado',
                style: estiloValor?.copyWith(color: AppColors.accent),
                maxLines: 1,
              ),
            ],
          )
        : Text(
            fila.valor,
            style: estiloValor,
            textAlign: largo ? TextAlign.start : TextAlign.end,
            maxLines: largo ? 4 : 1,
            overflow: TextOverflow.ellipsis,
          );

    // Las dos columnas van adentro de `title`, que es lo único que
    // `CupertinoListTile` mete en un Expanded. `additionalInfo` viaja
    // suelto en su Row, sin flex, así que un valor apenas largo desborda
    // la fila en un iPhone angosto en vez de encogerse. Del ListTile se
    // aprovechan el alto mínimo, el gris de pulsado y los separadores
    // sangrados de la sección; el reparto de las dos columnas es nuestro.
    return CupertinoListTile(
      onTap: fila.copiable ? _copiar : null,
      // Transparente: la fila ya no vive adentro de una tarjeta blanca,
      // así que el blanco que trae `CupertinoListTile` de fábrica se
      // vería como un renglón pintado sobre el fondo.
      backgroundColor: Colors.transparent,
      // El gris de pulsado de iOS, solo donde hay algo que pulsar.
      backgroundColorActivated: AppColors.azulBruma,
      // Sin el sangrado horizontal de iOS: el margen de la pantalla ya
      // lo pone la pantalla, y con los dos la lista quedaba metida 20 px
      // adentro de su propio título.
      padding: const EdgeInsets.symmetric(vertical: 12),
      title: largo
          // Valor largo: debajo de la etiqueta, a la izquierda.
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [etiqueta, const SizedBox(height: 3), valor],
            )
          // Valor corto: a la derecha, como cualquier fila de Ajustes.
          : Row(
              children: [
                Expanded(child: etiqueta),
                const SizedBox(width: 12),
                Flexible(child: valor),
              ],
            ),
      trailing: fila.copiable
          ? const Icon(
              Icons.copy_rounded,
              size: 15,
              color: AppColors.textSecondary,
            )
          : null,
    );
  }
}

/// El panel de la aseguradora: los contactos y cómo usar el seguro.
///
/// ADVERTENCIA: mientras `verificado` sea false, los datos son de
/// relleno. El aviso va ARRIBA de los teléfonos, y además el tile de
/// esta categoría lleva el triángulo naranja: un teléfono de
/// emergencias equivocado se marca en el peor momento posible.
class _PanelAseguradora extends StatelessWidget {
  const _PanelAseguradora({required this.aseguradora, required this.uso});

  final Aseguradora aseguradora;
  final UsoDelSeguro uso;

  @override
  Widget build(BuildContext context) {
    final a = aseguradora;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Los cuatro contactos, en lista y sin caja. El título de
        // bloque es el que los junta, igual que junta a los pasos de
        // "Cómo usar tu seguro" acá abajo: dos secciones con el mismo
        // encabezado se leen como dos partes de una misma pantalla, y
        // dos tarjetas con el mismo borde se leen como dos formularios.
        //
        // El aviso va DEBAJO del título y arriba de los teléfonos, que
        // es el mismo orden del bloque de abajo: si fuera al revés, el
        // primer renglón de la categoría sería una advertencia sobre
        // algo que todavía no se nombró.
        _TituloDeBloque(
          icono: Icons.contact_phone_outlined,
          texto: 'Cómo contactarlos',
        ),
        const SizedBox(height: AppSpacing.entre),
        if (!a.verificado) ...[
          const _AvisoSinVerificar(),
          const SizedBox(height: AppSpacing.entre),
        ],
        _ContactoAseguradora(
          icono: Icons.emergency_outlined,
          etiqueta: 'Emergencias, 24/7',
          valor: a.telefonoEmergencias,
          urgente: true,
          habilitado: a.verificado,
        ),
        const _SeparadorFino(),
        _ContactoAseguradora(
          icono: Icons.support_agent_outlined,
          etiqueta: 'Servicio al cliente',
          valor: a.telefonoServicio,
          habilitado: a.verificado,
        ),
        const _SeparadorFino(),
        _ContactoAseguradora(
          icono: Icons.mail_outline,
          etiqueta: 'Correo',
          valor: a.correo,
          habilitado: a.verificado,
        ),
        const _SeparadorFino(),
        _ContactoAseguradora(
          icono: Icons.schedule_outlined,
          etiqueta: 'Horario de oficina',
          valor: a.horario,
          habilitado: a.verificado,
        ),
        const SizedBox(height: AppSpacing.grupo),
        _TituloDeBloque(
          icono: Icons.medical_services_outlined,
          texto: 'Cómo usar tu seguro',
        ),
        const SizedBox(height: AppSpacing.entre),
        if (!uso.verificado) ...[
          const _AvisoSinVerificar(),
          const SizedBox(height: AppSpacing.entre),
        ],
        for (var i = 0; i < uso.pasos.length; i++) ...[
          _PasoUsoFila(numero: i + 1, paso: uso.pasos[i]),
          if (i != uso.pasos.length - 1) const SizedBox(height: 18),
        ],
      ],
    );
  }
}

// ============================================================
// Piezas sueltas
// ============================================================

/// Título de un bloque: ícono chico y texto.
class _TituloDeBloque extends StatelessWidget {
  const _TituloDeBloque({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, color: AppColors.azulMedio, size: 18),
        const SizedBox(width: AppSpacing.dentro),
        Expanded(
          child: Text(
            texto,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// Aviso de que un bloque todavía trae datos de relleno.
///
/// Va ARRIBA del contenido y no abajo: si va abajo, alguien ya marcó el
/// teléfono antes de leerlo.
class _AvisoSinVerificar extends StatelessWidget {
  const _AvisoSinVerificar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accentSecondary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.accentSecondary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Datos de ejemplo. La aseguradora todavía no confirmó esta '
              'información: no la uses en una emergencia real.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una fila de contacto de la aseguradora.
///
/// Cuando el dato está verificado, tocarla lo copia al portapapeles. No
/// marca ni abre el correo a propósito: para eso haría falta una
/// librería nueva, y copiar resuelve el caso sin agregar ninguna.
class _ContactoAseguradora extends StatefulWidget {
  const _ContactoAseguradora({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.habilitado,
    this.urgente = false,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  /// False mientras el dato no esté verificado: se muestra apagado para
  /// que nadie lo lea como un número bueno, y no se puede copiar.
  final bool habilitado;

  /// Emergencias va en naranja: es el que hay que encontrar rápido.
  final bool urgente;

  @override
  State<_ContactoAseguradora> createState() => _ContactoAseguradoraState();
}

class _ContactoAseguradoraState extends State<_ContactoAseguradora> {
  static const Duration _avisoCopiado = Duration(milliseconds: 1600);

  Timer? _reloj;
  bool _copiado = false;

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  void _copiar() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.valor));
    setState(() => _copiado = true);
    _reloj?.cancel();
    _reloj = Timer(_avisoCopiado, () {
      if (mounted) setState(() => _copiado = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = !widget.habilitado
        ? AppColors.textSecondary
        : widget.urgente
        ? AppColors.accentSecondary
        : AppColors.accent;

    final fila = Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icono, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.etiqueta,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                _copiado ? 'Copiado' : widget.valor,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _copiado
                      ? AppColors.accent
                      : widget.habilitado
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: widget.habilitado
                      ? FontWeight.w700
                      : FontWeight.w500,
                  fontStyle: widget.habilitado
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        if (widget.habilitado)
          Icon(
            _copiado ? Icons.check : Icons.copy_rounded,
            size: 15,
            color: _copiado ? AppColors.accent : AppColors.textSecondary,
          ),
      ],
    );

    if (!widget.habilitado) return fila;

    // `CupertinoButton` y no un GestureDetector: trae el atenuado al
    // tocar que un usuario de iPhone ya conoce.
    return CupertinoButton(
      onPressed: _copiar,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      child: fila,
    );
  }
}

/// Un paso de "cómo usar tu seguro".
class _PasoUsoFila extends StatelessWidget {
  const _PasoUsoFila({required this.numero, required this.paso});

  final int numero;
  final PasoUso paso;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.azulBruma,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$numero',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paso.titulo,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                paso.detalle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeparadorFino extends StatelessWidget {
  const _SeparadorFino();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Divider(height: 1, color: AppColors.cardBorder),
  );
}

/// "7,5" y no "7.5000000001"; "10" y no "10.0".
String _porcentaje(double valor) =>
    valor % 1 == 0 ? valor.toInt().toString() : valor.toString();
