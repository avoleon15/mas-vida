import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/modelos.dart';
import '../theme.dart';
import 'codigo_qr.dart';
import 'placeholder_imagen.dart';

// ============================================================
// PREMIOS › MIS CUPONES.
//
// Todos los códigos que el usuario ya tiene, en un solo lugar: los que
// compró con monedas y los que ganó por una semana o un podio
// patrocinado. Antes el QR se veía UNA vez, en el canje exitoso, y si se
// cerraba esa pantalla el cupón no se volvía a encontrar.
//
// Dos partes:
//   · los ACTIVOS, como boletos: son lo único levantado de la vista, lo
//     que se va a mostrar en caja. El que vence primero va arriba;
//   · los USADOS Y VENCIDOS, como una lista plana y apagada. Están para
//     consultar, no para usar.
//
// Tocar un boleto abre su código en grande, en una hoja.
// ============================================================

/// Llave de un cupón en la lista, para los tests.
Key llaveCupon(String id) => ValueKey('cupon-$id');

/// Llave de la hoja con el código en grande.
const Key llaveHojaCodigo = ValueKey('hoja-codigo-cupon');

const List<String> _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "2026-11-06" → "6 de noviembre". Si la fecha viene mal, se muestra
/// como llegó: mejor una fecha fea que una pantalla rota.
String fechaDeCupon(String iso) {
  final f = DateTime.tryParse(iso);
  if (f == null) return iso;
  return '${f.day} de ${_meses[f.month - 1]}';
}

/// Cuándo vence un cupón activo, en palabras.
String venceEn(CuponCanjeado c) => switch (c.diasParaVencer) {
  <= 0 => 'Vence hoy',
  1 => 'Vence mañana',
  final d => 'Vence en $d días',
};

/// Los activos, del que vence primero al último.
List<CuponCanjeado> cuponesActivos(List<CuponCanjeado> todos) =>
    todos.where((c) => c.activo).toList()
      ..sort((a, b) => a.diasParaVencer.compareTo(b.diasParaVencer));

class MisCupones extends StatelessWidget {
  const MisCupones({
    super.key,
    required this.cupones,
    required this.onIrALaTienda,
  });

  final List<CuponCanjeado> cupones;

  /// Del estado vacío a la tienda, sin salir de Premios.
  final VoidCallback onIrALaTienda;

  @override
  Widget build(BuildContext context) {
    final activos = cuponesActivos(cupones);
    final historial = cupones.where((c) => !c.activo).toList();

    if (cupones.isEmpty) return _Vacio(onIrALaTienda: onIrALaTienda);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activos.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No tienes cupones por usar. Los que ya usaste quedan abajo.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          )
        else ...[
          Text(
            'Toca un cupón para mostrar su código en caja.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          for (final c in activos) ...[
            _Boleto(cupon: c),
            const SizedBox(height: 14),
          ],
        ],
        if (historial.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('USADOS Y VENCIDOS', style: AppTheme.subsectionTitle),
          const SizedBox(height: 4),
          for (var i = 0; i < historial.length; i++) ...[
            if (i > 0) Container(height: 0.5, color: AppColors.separador),
            _FilaHistorial(cupon: historial[i]),
          ],
        ],
      ],
    );
  }
}

// ============================================================
// El boleto de un cupón activo.
// ============================================================

/// Dónde va el corte entre el talón (el logo) y el cuerpo.
const double _talon = 88;

/// Radio de las muescas del corte.
const double _muesca = 9;

class _Boleto extends StatelessWidget {
  const _Boleto({required this.cupon});

  final CuponCanjeado cupon;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;

    return Semantics(
      key: llaveCupon(cupon.id),
      button: true,
      label:
          '${cupon.comercio}: ${cupon.beneficio}. '
          '${cupon.ganadoEn == null ? '' : 'Ganado en ${cupon.ganadoEn}. '}'
          '${venceEn(cupon)}. Toca para mostrar el código.',
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: () => mostrarCodigoCupon(context, cupon),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: AppColors.card,
            shape: const _FormaBoleto(),
            shadows: AppSombras.tarjeta,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // El talón: la cara del comercio.
                SizedBox(
                  width: _talon,
                  child: Center(child: _Logo(cupon: cupon, tamano: 52)),
                ),
                // El corte, de muesca a muesca. Sólido: nada punteado.
                Container(
                  width: 0.5,
                  margin: const EdgeInsets.symmetric(vertical: _muesca + 4),
                  color: AppColors.separador,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                cupon.comercio.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tema.labelSmall?.copyWith(
                                  color: AppColors.azulMedio,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            if (cupon.ganadoEn case final g?) ...[
                              const SizedBox(width: 8),
                              Flexible(child: _Etiqueta(texto: g)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cupon.beneficio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tema.titleSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _Vencimiento(cupon: cupon),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.azulBruma,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.qrcode,
                        size: 20,
                        color: AppColors.accent,
                      ),
                    ),
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

/// "Vence en 12 días". A una semana de vencer pasa a naranja con un
/// reloj: es una alerta real, uno de los cuatro usos del naranja.
class _Vencimiento extends StatelessWidget {
  const _Vencimiento({required this.cupon});

  final CuponCanjeado cupon;

  @override
  Widget build(BuildContext context) {
    final urgente = cupon.porVencer;
    final color = urgente ? AppColors.accentSecondary : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.clock, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            venceEn(cupon),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: urgente ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// La forma del boleto: un rectángulo de esquinas de tarjeta con una
/// muesca arriba y otra abajo, justo donde se corta el talón.
class _FormaBoleto extends ShapeBorder {
  const _FormaBoleto();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final cuerpo = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(AppRadios.tarjeta)),
      );
    final x = rect.left + _talon;
    final muescas = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, rect.top), radius: _muesca))
      ..addOval(
        Rect.fromCircle(center: Offset(x, rect.bottom), radius: _muesca),
      );
    return Path.combine(PathOperation.difference, cuerpo, muescas);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

// ============================================================
// Un cupón usado o vencido.
// ============================================================

class _FilaHistorial extends StatelessWidget {
  const _FilaHistorial({required this.cupon});

  final CuponCanjeado cupon;

  String get _cuando => switch (cupon.estado) {
    EstadoCupon.usado =>
      cupon.usadoEl == null
          ? 'Usado'
          : 'Usado el ${fechaDeCupon(cupon.usadoEl!)}',
    _ => 'Venció el ${fechaDeCupon(cupon.vence)}',
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Semantics(
      key: llaveCupon(cupon.id),
      label: '${cupon.comercio}: ${cupon.beneficio}. $_cuando.',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Apagado: se ve de quién era, pero no invita a usarlo.
            Opacity(opacity: 0.45, child: _Logo(cupon: cupon, tamano: 36)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cupon.comercio,
                    style: tema.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    cupon.beneficio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tema.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  // Debajo y no a la derecha: con la letra grande, la
                  // fecha a la derecha empujaba la fila fuera de la
                  // pantalla.
                  const SizedBox(height: 2),
                  Text(
                    _cuando,
                    style: tema.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Piezas chicas.
// ============================================================

/// El logo del comercio en un círculo, con su color de fondo.
class _Logo extends StatelessWidget {
  const _Logo({required this.cupon, required this.tamano});

  final CuponCanjeado cupon;
  final double tamano;

  @override
  Widget build(BuildContext context) => Container(
    width: tamano,
    height: tamano,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: ClipOval(
      child: FotoComercio(
        ruta: cupon.foto,
        texto: cupon.comercio,
        fondo: cupon.fondo,
        margen: tamano * 0.16,
      ),
    ),
  );
}

/// De dónde salió un cupón que no se compró: un regalo y "Semana 1". El
/// regalo dice "ganado" sin gastar la palabra, que no cabía al lado del
/// nombre del comercio.
class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.azulBruma,
      borderRadius: BorderRadius.circular(AppRadios.pildora),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(CupertinoIcons.gift_fill, size: 11, color: AppColors.accent),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.onIrALaTienda});

  final VoidCallback onIrALaTienda;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppColors.azulBruma,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.ticket,
            size: 32,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Todavía no tienes cupones',
          textAlign: TextAlign.center,
          style: AppTheme.display(20).copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Cuando canjees un premio, su código queda guardado aquí para '
          'mostrarlo en caja.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        CupertinoButton(
          onPressed: onIrALaTienda,
          child: const Text('Explorar la tienda'),
        ),
      ],
    ),
  );
}

// ============================================================
// El código en grande, para la caja.
// ============================================================

/// Abre el código de [cupon] en una hoja, listo para mostrar en caja.
void mostrarCodigoCupon(BuildContext context, CuponCanjeado cupon) {
  HapticFeedback.selectionClick();
  showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => _HojaCodigo(cupon: cupon),
  );
}

class _HojaCodigo extends StatelessWidget {
  const _HojaCodigo({required this.cupon});

  final CuponCanjeado cupon;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;

    return Container(
      key: llaveHojaCodigo,
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 22),
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _Logo(cupon: cupon, tamano: 60),
                const SizedBox(height: 12),
                Text(
                  cupon.comercio.toUpperCase(),
                  style: tema.labelMedium?.copyWith(
                    color: AppColors.azulMedio,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cupon.beneficio,
                  textAlign: TextAlign.center,
                  style: AppTheme.display(
                    22,
                  ).copyWith(color: AppColors.textPrimary, height: 1.15),
                ),
                const SizedBox(height: 24),
                CodigoQr(codigo: cupon.codigo, tamano: 210),
                const SizedBox(height: 18),
                // El código escrito, por si la caja no puede escanear.
                SelectableText(
                  cupon.codigo,
                  style: tema.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Muéstralo en caja. Vence el ${fechaDeCupon(cupon.vence)}.',
                  textAlign: TextAlign.center,
                  style: tema.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (cupon.porVencer) ...[
                  const SizedBox(height: 10),
                  _Vencimiento(cupon: cupon),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(AppRadios.pildora),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Listo'),
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
