import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/chip_monedas.dart';
import '../widgets/moneda_animada.dart';
import '../widgets/placeholder_imagen.dart';
import '../widgets/refresco_vida.dart';

// ============================================================
// Datos de ejemplo. Todo hardcodeado por ahora (sin backend) y
// organizado en una lista simple de mapas, para que sea fácil de
// reemplazar después con datos reales.
//
// REGLA DURA DEL PROYECTO: acá se gastan MONEDAS, nunca puntos. Los
// puntos solo definen categoría anual y % de cashback y no aparecen en
// ninguna pantalla de Premios.
// ============================================================

/// Saldo de monedas del usuario. Se comparte con las pantallas de
/// detalle y canje exitoso para que el flujo sea consistente.
// ============================================================
// Esta pantalla no lee JSON: el catálogo y el saldo salen de `Datos.i`.
//
// REGLA DURA: acá solo hay MONEDAS. Los PUNTOS nunca aparecen en
// Premios, y canjear monedas nunca descuenta puntos.
// ============================================================

/// Saldo de monedas del usuario.
int get monedasUsuario => Datos.i.resumen.monedas.saldo;

List<Premio> get _premios => Datos.i.catalogo.premios;

List<String> get _categorias => Datos.i.catalogo.categorias;

// ============================================================
// LA CUADRÍCULA.
//
// Todas las tarjetas son IGUALES: dos columnas, misma forma, misma
// proporción. Se probó un mosaico con una tarjeta apaisada cada cinco
// para el comercio destacado y no funcionó: mezclar tarjetas
// horizontales y verticales en la misma grilla se lee como dos
// catálogos pegados, no como uno.
//
// Así que lo que el comercio destacado compra es el PRIMER LUGAR, no un
// tamaño ni un sello distinto. El sello "Destacado" existió y se sacó:
// no le decía nada al usuario —"destacado" no es un beneficio suyo, es
// un acuerdo comercial— y ensuciaba la esquina del logo. La alianza
// sigue teniendo qué vender —es una de las tres vías de ingreso del
// producto— sin romper la grilla.
// ============================================================

/// Columnas del catálogo.
const int premiosPorFila = 2;

/// Proporción de la tarjeta (ancho ÷ alto). Vertical: el logo manda
/// arriba y los datos van debajo.
const double proporcionTarjeta = 0.7;

/// Cada cuántas tarjetas vuelve a arrancar el escalonado de entrada de
/// los logos. Son dos filas: con las 29 del catálogo, escalonar de
/// punta a punta dejaría la última entrando dos segundos después.
const int logosPorTanda = 4;

/// Pone los comercios destacados al principio del catálogo.
///
/// Es lo único que les da la alianza: aparecer primero. El tamaño de la
/// tarjeta no cambia.
///
/// El resto conserva su orden original: el catálogo viene mezclado a
/// propósito para que en "Todos" las categorías queden intercaladas, y
/// esto no puede reagruparlas.
///
/// Con cero destacados —que es el caso normal— devuelve la lista igual.
/// Un catálogo sin nadie destacado se ve exactamente como éste, sin
/// huecos ni cartel que anuncie la ausencia.
List<Premio> destacadosPrimero(List<Premio> premios) {
  final destacados = premios.where((p) => p.destacado).toList();
  if (destacados.isEmpty) return premios;

  return [...destacados, ...premios.where((p) => !p.destacado)];
}

class PremiosScreen extends StatefulWidget {
  const PremiosScreen({super.key});

  @override
  State<PremiosScreen> createState() => _PremiosScreenState();
}

class _PremiosScreenState extends State<PremiosScreen> {
  String _categoriaSeleccionada = 'Todos';
  String _busqueda = '';

  /// Los premios que pasan la categoría elegida y el buscador.
  ///
  /// Se calcula acá y no en `build` porque ahora se lee desde adentro del
  /// ValueListenableBuilder: al refrescar cambia el catálogo, y la lista
  /// tiene que volver a filtrarse sobre los premios nuevos.
  List<Premio> get _premiosFiltrados {
    final texto = _busqueda.trim().toLowerCase();
    return _premios.where((p) {
      final deLaCategoria =
          _categoriaSeleccionada == 'Todos' ||
          p.categoria == _categoriaSeleccionada;
      // Se busca por comercio y por lo que dan: alguien puede acordarse
      // de "almuerzo" y no del nombre del restaurante.
      final coincide =
          texto.isEmpty ||
          p.nombre.toLowerCase().contains(texto) ||
          p.descripcion.toLowerCase().contains(texto) ||
          p.categoria.toLowerCase().contains(texto);
      return deLaCategoria && coincide;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: const AppHeader(),
            ),
            Expanded(
              // Se vuelve a dibujar cuando alguien refresca en CUALQUIER
              // pantalla, no solo acá: los datos son uno solo.
              child: ValueListenableBuilder<int>(
                valueListenable: datosRecargados,
                builder: (context, _, _) {
                  final premiosFiltrados = _premiosFiltrados;
                  return CustomScrollView(
                    physics: fisicaConRefresco,
                    slivers: [
                      const RefrescoVida(),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTituloYSaldo(context),
                              const SizedBox(height: 18),
                              _Buscador(
                                texto: _busqueda,
                                onChanged: (t) => setState(() => _busqueda = t),
                              ),
                              const SizedBox(height: 16),
                              _buildChipsCategorias(context),
                            ],
                          ),
                        ),
                      ),
                      if (premiosFiltrados.isEmpty)
                        SliverToBoxAdapter(child: _buildSinResultados(context))
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          sliver: _buildCuadricula(context, premiosFiltrados),
                        ),
                    ],
                  );
                },
              ),
            ),
            const BottomNavBar(currentIndex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildTituloYSaldo(BuildContext context) {
    return Row(
      children: [
        // El MISMO `sectionTitle` que las otras cuatro pantallas. Era un
        // `headlineSmall` en gris, así que Premios titulaba distinto que
        // el resto y se leía como una pantalla de otra app.
        Text('PREMIOS', style: AppTheme.sectionTitle),
        const Spacer(),
        ChipMonedas(cantidad: monedasUsuario),
        // La "i" va PEGADA al chip de monedas: lo que explica es de qué
        // se trata ese saldo.
        BotonInfo(
          onPressed: () => _mostrarInfoMonedas(context),
          semantica: 'Cómo funcionan tus monedas',
        ),
      ],
    );
  }

  /// El vencimiento, en una alerta centrada.
  ///
  /// Antes era un renglón fijo debajo del título. Es información que se
  /// consulta una vez y después estorba todos los días: acá está cuando
  /// se busca y no ocupa la pantalla el resto del tiempo.
  void _mostrarInfoMonedas(BuildContext context) {
    HapticFeedback.selectionClick();
    final lote = Datos.i.resumen.monedas.proximoLoteACaducar;

    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Tus monedas'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              Text(
                'Tenés $monedasUsuario monedas para gastar en Premios.',
                style: const TextStyle(height: 1.35),
              ),
              const SizedBox(height: 10),
              Text(
                lote == null
                    ? 'Las monedas duran 90 días desde que las ganás.'
                    : '${lote.cantidad} de ellas vencen en '
                          '${lote.diasParaCaducar} días. Cada moneda dura 90 '
                          'días desde que la ganás.',
                style: const TextStyle(height: 1.35),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// Cuando el filtro no deja nada. Sin esto la cuadrícula queda en
  /// blanco y parece que la pantalla se rompió.
  Widget _buildSinResultados(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 48),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.search,
            size: 30,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 14),
          Text(
            _busqueda.trim().isEmpty
                ? 'Todavía no hay premios en esta categoría.'
                : 'No encontramos ningún comercio con '
                      '"${_busqueda.trim()}".',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipsCategorias(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < _categorias.length; i++) ...[
            _buildChip(context, _categorias[i]),
            if (i != _categorias.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  /// El chip activo NO se rellena de azul sólido.
  ///
  /// Relleno lleno más texto oscuro dejaba la palabra seleccionada casi
  /// ilegible — justo la que más hay que poder leer. Ahora el activo es
  /// un tinte muy claro con el texto en azul, y lo que lo separa de los
  /// demás es un halo suave por fuera.
  Widget _buildChip(BuildContext context, String categoria) {
    final activo = categoria == _categoriaSeleccionada;

    return GestureDetector(
      onTap: () => setState(() => _categoriaSeleccionada = categoria),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          // Azul: seleccionar algo es azul en toda la app. El chip de
          // monedas de arriba se queda naranja justamente porque NO es
          // una selección, es un saldo.
          color: activo ? AppColors.azulBruma : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: activo ? AppColors.accent : AppColors.cardBorder,
            width: activo ? 1.5 : 1,
          ),
          // NUNCA `spreadRadius` en una pastilla.
          //
          // Era el motivo de que la sombra se viera cuadrada: `spread`
          // agranda la caja de la sombra pero NO su radio, así que el
          // radio de 19 —que en la pastilla de 38 px de alto da una
          // punta redonda perfecta— quedaba aplicado a una caja de 42, y
          // ahí ya no alcanza para cerrar el arco. El resultado es un
          // rectángulo de esquinas redondeadas alrededor de una
          // pastilla.
          //
          // Sin spread, la sombra copia la forma exacta de la pastilla.
          // Y va DEBAJO, con offset, en vez de repartida alrededor: un
          // halo centrado es un glow, que CLAUDE.md descarta y que es
          // justo lo que se veía poco profesional. Dos sombras: la
          // difusa da la profundidad y la corta apoya la pastilla sobre
          // el fondo.
          boxShadow: activo
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.26),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          categoria,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: activo ? AppColors.accent : AppColors.textSecondary,
            fontWeight: activo ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// El catálogo: dos columnas, todas las tarjetas iguales.
  Widget _buildCuadricula(BuildContext context, List<Premio> premios) {
    final ordenados = destacadosPrimero(premios);

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: premiosPorFila,
        // El aire ENTRE FILAS es más grande que el que separa al nombre
        // de su logo (20 contra 6), y eso no es un número estético: es
        // lo que decide de quién es cada nombre. Con los dos parecidos,
        // la plaquita quedaba a media distancia de los dos logos y no
        // se sabía a cuál pertenecía. Si se tocan estos dos números,
        // hay que mantener la proporción.
        mainAxisSpacing: 20,
        crossAxisSpacing: 14,
        childAspectRatio: proporcionTarjeta,
      ),
      delegate: SliverChildBuilderDelegate((context, i) {
        final premio = ordenados[i];
        return _TarjetaPremio(
          // Por id y no por posición: al filtrar por categoría la misma
          // tarjeta cambia de índice, y sin esto Flutter reusaría el
          // estado de la tarjeta que estaba en ese lugar.
          key: ValueKey(premio.id),
          premio: premio,
          posicionEnTanda: i % logosPorTanda,
        );
      }, childCount: ordenados.length),
    );
  }
}

/// Una tarjeta del catálogo.
///
/// Todas se ven igual, alcance o no el saldo. Antes las que no
/// alcanzaban iban atenuadas y con un "te faltan N" encima. Se leía como
/// si el premio estuviera agotado o bloqueado, cuando en realidad es al
/// revés: son justo los que hay que querer. Cuánto falta se dice
/// adentro, al abrir el premio.
class _TarjetaPremio extends StatelessWidget {
  const _TarjetaPremio({
    super.key,
    required this.premio,
    required this.posicionEnTanda,
  });

  final Premio premio;

  /// Lugar que ocupa dentro de la tanda de cuatro, para escalonar la
  /// entrada del logo. No es el índice absoluto a propósito: con 29
  /// premios, el último arrancaría dos segundos después del primero.
  final int posicionEnTanda;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Abrir un premio es de lo poco que el usuario viene a hacer
        // acá: el golpecito confirma el toque antes de que la pantalla
        // termine de entrar.
        HapticFeedback.lightImpact();
        Navigator.of(context).pushNamed('/premio-detalle', arguments: premio);
      },
      child: _adentro(context),
    );
  }

  /// El logo arriba con su costo montado encima; abajo, SOLO el nombre.
  ///
  /// UNA SOLA TARJETA POR COMERCIO: el logo y el nombre adentro de la
  /// misma caja.
  ///
  /// El nombre estuvo suelto abajo y no funcionaba: quedaba a media
  /// distancia entre el logo de arriba y el de abajo, y el ojo no tenía
  /// cómo decidir a cuál pertenecía. Un texto flotando entre dos objetos
  /// es de los dos y de ninguno. Metido adentro de la misma caja, la
  /// pregunta no existe.
  ///
  /// LA TARJETA NO ES BLANCA. Va en `azulNiebla`, que es el gris claro
  /// de la app —un gris con una gota de azul adentro, no un gris
  /// neutro inventado para esta pantalla—. En blanco puro la tarjeta
  /// competía con el logo que lleva adentro: lo que tiene que resaltar
  /// acá es la marca del comercio, con sus propios colores, y la caja
  /// que la sostiene tiene que quedarse callada. Por eso tampoco lleva
  /// borde: lo único que la despega del fondo es la sombra.
  ///
  /// ADENTRO VA SOLO EL NOMBRE Y SU CATEGORÍA. La descripción
  /// ("Beneficio por definir") era la misma frase de relleno en las 29
  /// tarjetas: una columna entera de texto idéntico que no distinguía un
  /// comercio de otro y empujaba los logos a la mitad de su tamaño. Lo
  /// que hace falta para elegir es el logo, el nombre y el precio; el
  /// resto se lee al abrir el premio.
  ///
  /// El logo va en [Expanded] y no con proporción fija: así ocupa lo que
  /// sobra de la celda, y si el usuario agranda la letra del sistema es
  /// el logo el que cede lugar, no la celda la que desborda.
  Widget _adentro(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.azulNiebla,
        borderRadius: BorderRadius.circular(18),
        // Gris y no azul: una sombra azulada le tiñe los colores al
        // logo del comercio. Dos sombras —la difusa da la profundidad,
        // la corta apoya la tarjeta sobre el fondo— y ninguna es un
        // glow.
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.13),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      // El logo llena la parte de arriba, así que tiene que recortarse
      // contra el radio de la tarjeta.
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _logo()),
          _PieDeTarjeta(premio: premio),
        ],
      ),
    );
  }

  /// El logo, con el costo en monedas montado en la esquina.
  ///
  /// EL SELLO "DESTACADO" YA NO VA. Era la etiqueta del comercio que
  /// compró visibilidad, y no le decía nada al usuario: "destacado" no
  /// es un beneficio suyo, es un acuerdo comercial. Lo que el
  /// patrocinador compra sigue intacto —`destacadosPrimero` los ordena
  /// primero, así que aparecen arriba del catálogo—, solo desaparece el
  /// rótulo.
  ///
  /// EL COSTO YA NO VA ACÁ ARRIBA. Estuvo montado en la esquina del
  /// logo y no se leía bien: cada logo trae el fondo y los colores que
  /// quiere, así que la píldora caía a veces sobre blanco, a veces sobre
  /// negro y a veces encima del dibujo, y en la grilla los cuatro
  /// precios quedaban a alturas distintas según qué tan alto fuera cada
  /// logo. Ahora vive en el pie, al lado del nombre: fondo parejo,
  /// altura pareja, y el precio se lee en el mismo renglón que el
  /// comercio al que pertenece.
  ///
  /// Así el logo queda limpio, que es lo único que tiene que hacer la
  /// mitad de arriba de la tarjeta.
  Widget _logo() {
    return _LogoAnimado(
      posicionEnTanda: posicionEnTanda,
      child: FotoComercio(
        ruta: premio.foto,
        fondo: premio.fondo,
        texto: 'LOGO',
      ),
    );
  }
}

/// El pie de la tarjeta: el nombre del comercio y su categoría.
///
/// Va ADENTRO de la misma caja que el logo, pegado abajo. Estuvo suelto
/// sobre el fondo y no funcionaba: quedaba a media distancia entre el
/// logo de arriba y el de abajo, y un texto flotando entre dos objetos
/// es de los dos y de ninguno.
///
/// LA BARRA VERTICAL en azul de marca le da el remate. Es el recurso de
/// una ficha editorial: un trazo corto al costado convierte un renglón
/// en un pie de foto. Mide 3 px —lo chico va en color, dice CLAUDE.md—.
class _PieDeTarjeta extends StatelessWidget {
  const _PieDeTarjeta({required this.premio});

  final Premio premio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      // `IntrinsicHeight` para que la barra sepa hasta dónde bajar. Sin
      // esto, el `stretch` del Row no tiene alto contra el que estirarse
      // —adentro de una Column el alto viene libre— y eso revienta en
      // layout, no se ve feo: revienta.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            // EL COSTO, a la derecha y en el mismo renglón.
            //
            // Sin píldora propia: acá el fondo es la tarjeta, que es
            // siempre el mismo gris, así que el número se lee solo. La
            // llevaba cuando iba montado sobre el logo, donde el fondo
            // podía ser cualquier cosa.
            //
            // Va DESPUÉS del nombre en el árbol pero se dibuja a la
            // derecha, y el nombre es el que se achica si no entra: el
            // precio son dos dígitos y nunca se corta, el nombre puede
            // terminar en puntos suspensivos sin perder nada.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    premio.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      // w800 y no w700: es el único texto de la tarjeta,
                      // así que puede permitirse ser el más firme de la
                      // grilla sin competirle a nada.
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // La CATEGORÍA, en chico y apagada.
                  //
                  // No es la descripción que se sacó: aquella era
                  // "Beneficio por definir" repetido en las 29 tarjetas.
                  // Ésta cambia en cada una —Restaurantes, Farmacias,
                  // Cafecitos— y es justo lo que le faltaba al bloque
                  // para tener dos niveles en vez de un renglón solo. Un
                  // dato que distingue no es relleno.
                  Text(
                    premio.categoria,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.azulMedio,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MonedaAnimada(size: 18),
                const SizedBox(width: 3),
                Text(
                  '${premio.costoMonedas}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    // El naranja del costo es el de las MONEDAS, que es
                    // uno de los cuatro lugares donde el naranja
                    // significa algo.
                    color: AppColors.accentSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuánto tarda en entrar un logo.
const Duration duracionEntradaLogo = Duration(milliseconds: 420);

/// Cuánto espera cada logo respecto del anterior de su ciclo.
const Duration escalonEntradaLogo = Duration(milliseconds: 70);

/// El logo de un comercio, apareciendo.
///
/// Los logos entran escalonados en vez de aparecer los cinco de golpe:
/// el ojo los recorre en el orden en que están puestos, que es el mismo
/// en el que se leen. Es un fundido con un acercamiento mínimo —de 94% a
/// 100%—, no un rebote: la app tiene que transmitir calma.
///
/// Se anima el LOGO y no la tarjeta entera a propósito. Moviendo la
/// tarjeta se movería también el borde, y una grilla donde las cajas
/// entran volando se lee como una web, no como iOS.
class _LogoAnimado extends StatelessWidget {
  const _LogoAnimado({required this.posicionEnTanda, required this.child});

  final int posicionEnTanda;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // "Reducir movimiento" del sistema: ahí el logo aparece y listo.
    if (MediaQuery.of(context).disableAnimations) return child;

    return child
        .animate()
        .fadeIn(
          duration: duracionEntradaLogo,
          delay: escalonEntradaLogo * posicionEnTanda,
          curve: Curves.easeOut,
        )
        .scale(
          begin: const Offset(0.94, 0.94),
          end: const Offset(1, 1),
          duration: duracionEntradaLogo,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Buscador de comercios.
///
/// Sigue el diseño que pidió Daniel (píldora, lupa a la izquierda, X a la
/// derecha, borde azul al enfocar, sombra suave), pero armado sobre
/// [CupertinoTextField]: así trae el teclado, la selección y el cursor de
/// iOS, que un `TextField` de Material no da.
class _Buscador extends StatefulWidget {
  const _Buscador({required this.texto, required this.onChanged});

  final String texto;
  final ValueChanged<String> onChanged;

  @override
  State<_Buscador> createState() => _BuscadorState();
}

class _BuscadorState extends State<_Buscador> {
  late final TextEditingController _control = TextEditingController(
    text: widget.texto,
  );
  final FocusNode _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    // El borde solo cambia con el foco: hay que repintar cuando cambia.
    _foco.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _control.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _limpiar() {
    _control.clear();
    widget.onChanged('');
    _foco.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final enfocado = _foco.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          // Dos píxeles siempre, transparente cuando no hay foco: así el
          // campo no cambia de tamaño al enfocarlo.
          color: enfocado ? AppColors.accent : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(
              alpha: enfocado ? 0.10 : 0.06,
            ),
            blurRadius: enfocado ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            CupertinoIcons.search,
            size: 19,
            color: enfocado ? AppColors.accent : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoTextField(
              controller: _control,
              focusNode: _foco,
              onChanged: widget.onChanged,
              placeholder: 'Buscar un comercio',
              // El fondo y el borde los pone el contenedor de afuera.
              decoration: const BoxDecoration(),
              padding: const EdgeInsets.symmetric(vertical: 14),
              placeholderStyle: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
              cursorColor: AppColors.accent,
              textInputAction: TextInputAction.search,
            ),
          ),
          // La X solo aparece cuando hay algo que borrar: un botón que no
          // hace nada enseña a ignorarlo.
          if (_control.text.isNotEmpty)
            CupertinoButton(
              onPressed: _limpiar,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              child: const Icon(
                CupertinoIcons.xmark,
                size: 17,
                color: AppColors.textSecondary,
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}
