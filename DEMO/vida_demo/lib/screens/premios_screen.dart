import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/chip_monedas.dart';
import '../widgets/placeholder_imagen.dart';

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

class PremiosScreen extends StatefulWidget {
  const PremiosScreen({super.key});

  @override
  State<PremiosScreen> createState() => _PremiosScreenState();
}

class _PremiosScreenState extends State<PremiosScreen> {
  String _categoriaSeleccionada = 'Todos';
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final texto = _busqueda.trim().toLowerCase();
    final premiosFiltrados = _premios.where((p) {
      final deLaCategoria =
          _categoriaSeleccionada == 'Todos' ||
          p.categoria == _categoriaSeleccionada;
      // Se busca por comercio y por lo que dan: alguien puede acordarse
      // de "vitaminas" y no del nombre de la farmacia.
      final coincide =
          texto.isEmpty ||
          p.nombre.toLowerCase().contains(texto) ||
          p.descripcion.toLowerCase().contains(texto) ||
          p.categoria.toLowerCase().contains(texto);
      return deLaCategoria && coincide;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: const AppHeader(),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
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
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.7,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) =>
                              _buildTarjetaPremio(context, premiosFiltrados[i]),
                          childCount: premiosFiltrados.length,
                        ),
                      ),
                    ),
                ],
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
                    ? 'Las monedas duran 6 meses desde que las ganás.'
                    : '${lote.cantidad} de ellas vencen en '
                          '${lote.diasParaCaducar} días. Cada moneda dura 6 '
                          'meses desde que la ganás.',
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

  Widget _buildTarjetaPremio(BuildContext context, Premio premio) {
    final costo = premio.costoMonedas;
    final alcanza = monedasUsuario >= costo;
    final faltan = costo - monedasUsuario;

    return GestureDetector(
      onTap: () =>
          Navigator.of(context).pushNamed('/premio-detalle', arguments: premio),
      child: Opacity(
        opacity: alcanza ? 1 : 0.55,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AspectRatio(
                  aspectRatio: 1.4,
                  child: PlaceholderImagen(texto: 'LOGO'),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        premio.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        premio.descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: AppColors.accentSecondary,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$costo',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.accentSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (!alcanza) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'te faltan $faltan',
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
