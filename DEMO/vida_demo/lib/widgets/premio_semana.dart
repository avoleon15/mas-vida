import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../theme.dart';
import 'patrocinio.dart';
import 'placeholder_imagen.dart';

// ============================================================
// EL PREMIO DE UNA SEMANA PATROCINADA.
//
// Dos versiones (pedido de Daniel, 2 de octubre de 2026):
//
//   · en HOY, un renglón chico debajo de los objetivos: el logo, lo que
//     se gana y nada más. La foto grande pesaba más que los objetivos y
//     le quitaba lo tranquilo a la pantalla. [PremioSemanaChico]
//   · en la CARD DE LA SEMANA, el carrusel: una foto apaisada que va
//     cambiando sola, con lo que se gana abajo y la marca arriba en una
//     pastilla. Ahí sí tiene que notarse. [PremioSemana]
//
// Hoy las fotos son la misma repetida —no hay fotos de los premios
// todavía—, pero la animación corre igual: el día que lleguen las reales
// solo cambian los datos.
//
// Sin marca no se dibuja nada: una semana sin patrocinio es el caso
// normal y no se anuncia la ausencia.
// ============================================================

/// Lo que dura una vuelta completa por las fotos.
const Duration _ciclo = Duration(seconds: 7);

/// Llave del renglón del premio en Hoy, para los tests.
const Key llavePremioSemana = ValueKey('premio-semana');

/// Llave del carrusel de la card, para los tests.
const Key llaveCarruselPremio = ValueKey('carrusel-premio-semana');

/// Lo que se dice arriba del cupón, según cómo va la semana. El cupón
/// pide COMPLETAR la semana: los dos objetivos.
String rotuloPremio(SemanaObjetivos semana) => switch (semana.estado) {
  EstadoSemana.cerrada when semana.cumplida => 'Ganaste',
  EstadoSemana.cerrada => 'Esta semana se llevaba',
  _ => 'Cumple los dos y ganas',
};

/// El premio de la semana en HOY: un renglón chico, PEGADO al segundo
/// objetivo y con su misma forma (pedido de Daniel, 2 de octubre de
/// 2026: con aire en medio se veía como un aviso aparte). El logo en una
/// placa apaisada con el fondo de la marca —en un disco chico el de
/// Montanos no se leía—, lo que se gana y un regalo.
class PremioSemanaChico extends StatelessWidget {
  const PremioSemanaChico({super.key, required this.semana});

  final SemanaObjetivos semana;

  @override
  Widget build(BuildContext context) {
    final p = semana.patrocinio;
    if (p == null) return const SizedBox.shrink();
    final acento = acentoDeMarca(p);
    final tema = Theme.of(context).textTheme;

    return Semantics(
      key: llavePremioSemana,
      label: '${rotuloPremio(semana)} ${p.cupon}, de ${p.marca}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
        decoration: BoxDecoration(
          color: acento.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        ),
        child: Row(
          children: [
            // El regalo y no el logo: la marca ya va a la derecha del
            // título "Esta semana", y dos logos de la misma marca en el
            // mismo bloque es uno de más.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: acento.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadios.pildora),
              ),
              child: Icon(CupertinoIcons.gift_fill, size: 19, color: acento),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rotuloPremio(semana),
                    style: tema.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.cupon,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.display(
                      16,
                    ).copyWith(color: acento, height: 1.2),
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

/// El carrusel del premio, para la card de la semana.
class PremioSemana extends StatefulWidget {
  /// Una semana CON patrocinio: sin marca este carrusel no se dibuja.
  const PremioSemana({super.key, required this.semana});

  final SemanaObjetivos semana;

  Patrocinio get patrocinio => semana.patrocinio!;

  @override
  State<PremioSemana> createState() => _PremioSemanaState();
}

class _PremioSemanaState extends State<PremioSemana>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reloj;
  late final Animation<double> _foto;

  List<String> get _fotos => widget.patrocinio.fotos.isEmpty
      ? [widget.patrocinio.logo]
      : widget.patrocinio.fotos;

  @override
  void initState() {
    super.initState();
    _reloj = AnimationController(vsync: this, duration: _ciclo);
    _foto = _secuencia().animate(_reloj);
  }

  /// Quieta, se desliza, quieta, se desliza… y vuelve a la primera. Se
  /// arma según cuántas fotos hay: con dos, una secuencia fija de tres se
  /// deslizaría hasta un hueco vacío.
  TweenSequence<double> _secuencia() {
    final ultima = _fotos.length - 1;
    if (ultima == 0) {
      return TweenSequence([
        TweenSequenceItem(tween: ConstantTween(0), weight: 1),
      ]);
    }
    final pasos = <TweenSequenceItem<double>>[];
    for (var i = 0; i <= ultima; i++) {
      pasos.add(
        TweenSequenceItem(
          tween: ConstantTween<double>(i.toDouble()),
          weight: 30,
        ),
      );
      // De la última vuelve a la primera, deslizándose hacia atrás.
      pasos.add(
        TweenSequenceItem(
          tween: Tween<double>(
            begin: i.toDouble(),
            end: i == ultima ? 0 : i + 1.0,
          ).chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 8,
        ),
      );
    }
    return TweenSequence(pasos);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con "Reducir movimiento" se queda en la primera foto.
    if (MediaQuery.disableAnimationsOf(context) || _fotos.length < 2) {
      _reloj.stop();
      _reloj.value = 0;
    } else if (!_reloj.isAnimating) {
      _reloj.repeat();
    }
  }

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patrocinio;
    final fotos = _fotos;

    final rotulo = rotuloPremio(widget.semana);
    return Semantics(
      key: llaveCarruselPremio,
      label: 'Esta semana la patrocina ${p.marca}. $rotulo ${p.cupon}',
      excludeSemantics: true,
      // LA FOTO LIMPIA, sin nada encima (pedido de Daniel, 2 de octubre
      // de 2026: con el texto y la sombra encima la imagen no se veía).
      // Lo que se gana va en un renglón debajo.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: altoFotoPremio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadios.tarjeta),
              child: SizedBox.expand(
                child: LayoutBuilder(
                  builder: (context, caja) => Stack(
                    fit: StackFit.expand,
                    children: [
                      // El fondo de la marca detrás de todo: en el
                      // deslizamiento asoma entre foto y foto.
                      ColoredBox(
                        color: colorDesdeHex(p.fondo, porDefecto: Colors.white),
                      ),
                      AnimatedBuilder(
                        animation: _foto,
                        builder: (context, _) => Stack(
                          children: [
                            Positioned(
                              left: -_foto.value * caja.maxWidth,
                              top: 0,
                              bottom: 0,
                              width: caja.maxWidth * fotos.length,
                              child: Row(
                                children: [
                                  for (final ruta in fotos)
                                    SizedBox(
                                      width: caja.maxWidth,
                                      child: FotoComercio(
                                        ruta: ruta,
                                        fondo: p.fondo,
                                        texto: p.marca.toUpperCase(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _LoQueSeGana(rotulo: rotulo, patrocinio: p),
        ],
      ),
    );
  }
}

/// Alto de la foto del premio en la card de la semana.
const double altoFotoPremio = 132;

/// "Cumple los dos y ganas · 2x1 en Puyazo 8 oz", debajo de la foto: un
/// regalo en el color de la marca, lo que hay que hacer en gris y el
/// premio en grande.
class _LoQueSeGana extends StatelessWidget {
  const _LoQueSeGana({required this.rotulo, required this.patrocinio});

  final String rotulo;
  final Patrocinio patrocinio;

  @override
  Widget build(BuildContext context) {
    final acento = acentoDeMarca(patrocinio);
    final tema = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(CupertinoIcons.gift_fill, size: 20, color: acento),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$rotulo en ${patrocinio.marca}',
                style: tema.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.2,
                ),
              ),
              Text(
                patrocinio.cupon,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.display(
                  16,
                ).copyWith(color: acento, height: 1.25),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Llave de la marca junto al título "Esta semana", para los tests.
const Key llaveMarcaDeLaSemana = ValueKey('marca-de-la-semana');

/// "Patrocinada por" y el logo de la marca, a la derecha del título "Esta
/// semana" en Hoy (pedido de Daniel, 2 de octubre de 2026). El logo va en
/// una placa apaisada con el fondo de la marca: en un disco chico el de
/// Montanos no se leía. Sin marca no se dibuja nada.
class MarcaDeLaSemana extends StatelessWidget {
  const MarcaDeLaSemana({super.key, required this.semana});

  final SemanaObjetivos? semana;

  @override
  Widget build(BuildContext context) {
    final p = semana?.patrocinio;
    if (p == null) return const SizedBox.shrink();
    return Semantics(
      key: llaveMarcaDeLaSemana,
      label: 'Patrocinada por ${p.marca}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Patrocinada por',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 76,
              height: 42,
              child: FotoComercio(
                ruta: p.logo,
                fondo: p.fondo,
                texto: p.marca,
                margen: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
