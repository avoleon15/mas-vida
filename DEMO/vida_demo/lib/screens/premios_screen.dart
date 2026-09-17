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
// Así que lo que el comercio destacado compra es el SELLO y el primer
// lugar, no un tamaño distinto. La alianza sigue teniendo qué vender
// —es una de las tres vías de ingreso del producto— sin romper la
// grilla.
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
        Text(
          'Premios',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
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
          // Dos sombras: una amplia y difusa que hace el halo, y una
          // corta debajo que apoya la pastilla sobre el fondo. Con una
          // sola se ve o flotando o plana.
          boxShadow: activo
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.28),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
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
        mainAxisSpacing: 14,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: _adentro(context),
        ),
      ),
    );
  }

  /// Logo arriba, datos abajo. Una sola forma para todas.
  ///
  /// El logo va en [Expanded] y no con proporción fija: así ocupa lo que
  /// sobra de la celda, y si el usuario agranda la letra del sistema es
  /// el logo el que cede lugar, no la tarjeta la que desborda.
  Widget _adentro(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _logo()),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _nombre(context, maxLineas: 1),
              const SizedBox(height: 4),
              Text(
                premio.descripcion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              _costo(context),
            ],
          ),
        ),
      ],
    );
  }

  /// El logo, con el sello del destacado encima si corresponde.
  ///
  /// El sello va montado SOBRE el logo y no arriba del nombre a
  /// propósito: así el bloque de texto mide exactamente lo mismo en
  /// todas las tarjetas. Metido entre el nombre y el logo, la tarjeta
  /// del destacado terminaría con el logo más chico que las de al lado
  /// —justo lo contrario de lo que se compró— y la grilla volvería a
  /// verse despareja.
  Widget _logo() {
    final logo = _LogoAnimado(
      posicionEnTanda: posicionEnTanda,
      child: FotoComercio(ruta: premio.foto, fondo: premio.fondo, texto: 'LOGO'),
    );
    if (!premio.destacado) return logo;

    return Stack(
      children: [
        Positioned.fill(child: logo),
        const Positioned(top: 8, left: 8, child: _SelloDestacado()),
      ],
    );
  }

  Widget _nombre(BuildContext context, {required int maxLineas}) {
    return Text(
      premio.nombre,
      maxLines: maxLineas,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _costo(BuildContext context) {
    return Row(
      children: [
        const MonedaAnimada(size: 19),
        const SizedBox(width: 4),
        Text(
          '${premio.costoMonedas}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            // El naranja del costo es el de las MONEDAS, que es uno de
            // los cuatro lugares donde el naranja significa algo.
            color: AppColors.accentSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// El sello del comercio que compró visibilidad.
///
/// Azul y no naranja: el naranja está reservado a las monedas, la llama
/// de la racha, las alertas reales y el check de una etapa. Un sello
/// comercial no es ninguna de las cuatro.
///
/// Lleva relleno propio y no es texto suelto porque se monta sobre el
/// logo, y los logos traen el fondo que quieren: el de Montanos es
/// negro y el de El Cafecito verde oscuro. Sin su propia píldora, el
/// sello desaparecería en esas dos tarjetas.
class _SelloDestacado extends StatelessWidget {
  const _SelloDestacado();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.azulBruma,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Destacado',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
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
