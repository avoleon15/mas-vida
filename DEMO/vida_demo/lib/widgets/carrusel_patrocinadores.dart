import 'dart:async';

import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../theme.dart';
import 'patrocinio.dart';

// ============================================================
// "LO QUE VIENE": LAS SEMANAS PATROCINADAS QUE TODAVÍA NO LLEGARON.
//
// Es un ADELANTO, no el protagonista: vive abajo del camino, ocupa poco
// alto y no compite con los nodos. Si no hay ninguna semana patrocinada
// por delante, la sección entera no se dibuja — una sección vacía con un
// título es peor que no tenerla.
//
// CADA TARJETA LLEVA EL NÚMERO DE SEMANA ENCIMA. Sin ese rótulo esto se
// lee como publicidad suelta metida en medio de la app; con él se lee
// como lo que es: qué marca acompaña qué semana del programa.
//
// LAS TRES COSAS QUE ACÁ SE HACEN CON CUIDADO:
//
// 1. EL TEMPORIZADOR NO EXISTE SI LAS ANIMACIONES ESTÁN APAGADAS. Con
//    "Reducir movimiento" —que es también como corren los tests, ver
//    `test/ayudas.dart`— el carrusel se queda quieto en la primera
//    tarjeta y NUNCA se crea un Timer. Una animación que se repite para
//    siempre cuelga `pumpAndSettle` hasta el timeout.
//
// 2. EL AVANCE AUTOMÁTICO SE CANCELA APENAS EL USUARIO TOCA. Y no vuelve
//    solo: que la app te arrebate la tarjeta que estás mirando enfurece,
//    y "vuelve a los 10 segundos" es el mismo problema con más espera.
//    Quien tocó ya está manejando el carrusel a mano.
//
// 3. EL DESLIZAMIENTO NO LLAMA A setState. Se dibuja con un
//    AnimatedBuilder colgado del PageController: así el único que se
//    repinta en cada cuadro es la fila de tarjetas, y no la pantalla
//    entera con sus diez nodos.
// ============================================================

/// Cada cuánto pasa a la siguiente tarjeta.
const Duration _cadaCuantoAvanza = Duration(seconds: 6);

/// Cuánto tarda el cambio de tarjeta.
const Duration _duracionDelCambio = Duration(milliseconds: 900);

/// Alto de la sección entera, rótulo incluido. Es un adelanto: más que
/// esto le robaría la pantalla al camino.
const double _altoSeccion = 196;

/// Alto de cada tarjeta.
const double _altoTarjeta = 150;

/// Cuánto se gira la tarjeta que no está al centro, en radianes.
const double _giroMaximo = 0.42;

/// Cuánto se achica la tarjeta que no está al centro.
const double _escalaMinima = 0.84;

/// Las semanas patrocinadas que todavía no llegaron, en un carrusel.
class CarruselLoQueViene extends StatefulWidget {
  const CarruselLoQueViene({super.key, required this.semanas});

  /// Ya vienen filtradas: patrocinadas y no empezadas. Si está vacía la
  /// sección no se dibuja.
  final List<SemanaObjetivos> semanas;

  @override
  State<CarruselLoQueViene> createState() => _CarruselLoQueVieneState();
}

class _CarruselLoQueVieneState extends State<CarruselLoQueViene> {
  // Menos de 1 para que se asomen las tarjetas de los costados: es lo que
  // dice "hay más", sin una flecha ni un punto.
  final _control = PageController(viewportFraction: 0.68);

  Timer? _avance;

  /// Se apaga para siempre en cuanto el usuario toca. Ver la nota 2 del
  /// encabezado.
  bool _automatico = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Acá y no en initState porque hace falta el MediaQuery. Con
    // "Reducir movimiento" no se crea ningún Timer.
    if (MediaQuery.disableAnimationsOf(context)) return;
    _arrancar();
  }

  void _arrancar() {
    if (!_automatico || widget.semanas.length < 2) return;
    _avance?.cancel();
    _avance = Timer.periodic(_cadaCuantoAvanza, (_) => _siguiente());
  }

  void _siguiente() {
    if (!mounted || !_control.hasClients) return;
    final actual = (_control.page ?? 0).round();
    _control.animateToPage(
      // Vuelve a la primera al terminar: son dos o tres tarjetas, y
      // frenar en la última dejaría el carrusel muerto.
      (actual + 1) % widget.semanas.length,
      duration: _duracionDelCambio,
      curve: Curves.easeInOutCubic,
    );
  }

  void _tomaElControlElUsuario() {
    if (!_automatico) return;
    _avance?.cancel();
    _avance = null;
    _automatico = false;
  }

  @override
  void dispose() {
    // Sin esto el Timer sigue vivo después de que la pantalla se fue, y
    // le pega a un controlador ya desechado.
    _avance?.cancel();
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.semanas.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: _altoSeccion,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'LO QUE VIENE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.4,
              ),
            ),
          ),
          Expanded(
            child: Listener(
              // `Listener` y no `GestureDetector`: el PageView se queda
              // con el gesto de arrastre, así que un onTap/onPanDown de
              // más arriba nunca se enteraría. El puntero crudo sí llega.
              onPointerDown: (_) => _tomaElControlElUsuario(),
              child: PageView.builder(
                controller: _control,
                itemCount: widget.semanas.length,
                // Con una sola tarjeta no hay nada que deslizar.
                physics: widget.semanas.length < 2
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemBuilder: (context, i) => AnimatedBuilder(
                  // Colgado del controlador, NO de un setState: lo único
                  // que se repinta al deslizar son estas tarjetas.
                  animation: _control,
                  builder: (context, child) {
                    // Antes del primer layout el controlador todavía no
                    // tiene página; sin esto la primera tarjeta aparece
                    // girada un cuadro y pega un salto.
                    final pagina = _control.hasClients
                        ? (_control.page ?? _control.initialPage.toDouble())
                        : _control.initialPage.toDouble();
                    final distancia = (pagina - i).clamp(-1.0, 1.0);
                    final escala =
                        _escalaMinima +
                        (1 - _escalaMinima) * (1 - distancia.abs());

                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        // La perspectiva va ANTES del giro: sin ella
                        // rotateY es un achatamiento plano y no se lee
                        // como profundidad.
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(distancia * _giroMaximo)
                        ..scaleByDouble(escala, escala, escala, 1),
                      child: child,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _TarjetaLoQueViene(semana: widget.semanas[i]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una tarjeta del carrusel: la foto del local y, encima, qué semana es.
class _TarjetaLoQueViene extends StatelessWidget {
  const _TarjetaLoQueViene({required this.semana});

  final SemanaObjetivos semana;

  @override
  Widget build(BuildContext context) {
    final patrocinio = semana.patrocinio!;
    final acento = acentoDeMarca(patrocinio);

    return Semantics(
      label:
          'Semana ${semana.numero}, patrocinada por ${patrocinio.marca}: '
          '${patrocinio.cupon}',
      excludeSemantics: true,
      child: Container(
        height: _altoTarjeta,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // La franja del número va ARRIBA y con la paleta de +Vida, no
            // encima de la foto: sobre el fondo de la marca —que puede
            // ser negro o blanco— un texto superpuesto necesitaría una
            // sombra que ensucia el logo.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: AppColors.azulNiebla,
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: acento,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'SEMANA ${semana.numero}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            // La foto se lleva lo que quede entre la franja y el cupón.
            Expanded(child: FotoPatrocinador.flexible(patrocinio)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Text(
                patrocinio.cupon,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

