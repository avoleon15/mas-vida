import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

// ============================================================
// LAS PIEZAS DEL INGRESO: EL CAMPO, EL BOTÓN, LOS ANILLOS Y EL ERROR.
//
// Las comparten el login, el registro y recuperar la contraseña. Si
// cada pantalla armara su propio campo, a la tercera ya habría dos
// alturas y dos bordes distintos.
// ============================================================

/// Un campo de texto de +Vida.
///
/// Es un [CupertinoTextField] (cursor, selección, lupa y autocompletar
/// de contraseñas de iOS gratis) con la ropa de la app encima: píldora
/// en azul niebla que al tocarla se vuelve blanca con el borde en azul
/// de marca. El cambio de superficie es lo que dice "estás escribiendo
/// acá" sin tener que leer nada.
class CampoVida extends StatefulWidget {
  const CampoVida({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.icono,
    this.teclado,
    this.accion = TextInputAction.next,
    this.alEnviar,
    this.esContrasena = false,
    this.autofill,
    this.capitalizacion = TextCapitalization.none,
    this.conError = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String placeholder;
  final IconData icono;
  final TextInputType? teclado;
  final TextInputAction accion;
  final ValueChanged<String>? alEnviar;
  final bool esContrasena;
  final Iterable<String>? autofill;
  final TextCapitalization capitalizacion;

  /// Borde en naranja: el dato que está mal. Es una alerta real, uno de
  /// los cuatro usos permitidos del naranja.
  final bool conError;

  final ValueChanged<String>? onChanged;

  @override
  State<CampoVida> createState() => _CampoVidaState();
}

class _CampoVidaState extends State<CampoVida> {
  final _foco = FocusNode();
  bool _oculta = true;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enfocado = _foco.hasFocus;
    final borde = widget.conError
        ? AppColors.accentSecondary
        : enfocado
        ? AppColors.accent
        : Colors.transparent;
    final texto = Theme.of(context).textTheme.bodyLarge!;

    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: enfocado ? AppColors.card : AppColors.azulNiebla,
        borderRadius: BorderRadius.circular(AppRadios.pildora),
        border: Border.all(color: borde, width: 1.5),
        boxShadow: enfocado
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [],
      ),
      child: CupertinoTextField(
        controller: widget.controller,
        focusNode: _foco,
        placeholder: widget.placeholder,
        placeholderStyle: texto.copyWith(color: AppColors.textSecondary),
        style: texto.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: AppColors.accent,
        keyboardType: widget.teclado,
        textInputAction: widget.accion,
        onSubmitted: widget.alEnviar,
        onChanged: widget.onChanged,
        obscureText: widget.esContrasena && _oculta,
        autocorrect:
            !widget.esContrasena &&
            widget.teclado != TextInputType.emailAddress,
        enableSuggestions: !widget.esContrasena,
        autofillHints: widget.autofill,
        textCapitalization: widget.capitalizacion,
        // Sin la caja gris de fábrica: la superficie la pone el
        // AnimatedContainer de afuera.
        decoration: null,
        padding: const EdgeInsets.symmetric(vertical: 16),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 18, right: 10),
          child: Icon(
            widget.icono,
            size: 19,
            color: enfocado ? AppColors.accent : AppColors.azulMedio,
          ),
        ),
        suffix: widget.esContrasena
            ? CupertinoButton(
                padding: const EdgeInsets.only(left: 8, right: 16),
                minimumSize: Size.zero,
                onPressed: () => setState(() => _oculta = !_oculta),
                child: Icon(
                  _oculta ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                  size: 20,
                  color: AppColors.azulMedio,
                  semanticLabel: _oculta
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                ),
              )
            : const SizedBox(width: 18),
      ),
    );
  }
}

/// El botón principal del ingreso: píldora azul a todo el ancho.
///
/// Lleva un degradado apenas perceptible y una sombra difusa, la misma
/// receta del botón del camino en Hoy: es lo que lo hace leerse como la
/// acción de la pantalla sin tener que gritar. Apagado, se vuelve plano
/// y gris — un botón que no se puede tocar no tiene por qué tener
/// volumen.
class BotonPildora extends StatelessWidget {
  const BotonPildora({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
    this.icono,
  });

  final String texto;

  /// Null lo apaga.
  final VoidCallback? onPressed;

  final bool cargando;

  /// Opcional, a la derecha del texto.
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null;
    final estilo = Theme.of(context).textTheme.titleSmall!.copyWith(
      color: activo ? Colors.white : AppColors.textSecondary,
      fontWeight: FontWeight.w700,
    );

    return Semantics(
      button: true,
      enabled: activo && !cargando,
      label: cargando ? '$texto, cargando' : texto,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: cargando ? null : onPressed,
        // Mientras carga, el botón queda apagado pero NO cambia de
        // color: si se volviera gris parecería que algo salió mal.
        disabledColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadios.pildora),
            color: activo ? null : AppColors.cardBorder,
            gradient: activo
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(AppColors.accent, AppColors.azulMedio, 0.22)!,
                      AppColors.accent,
                    ],
                  )
                : null,
            boxShadow: activo
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          alignment: Alignment.center,
          child: cargando
              ? const CupertinoActivityIndicator(color: Colors.white)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(texto, style: estilo),
                    if (icono != null) ...[
                      const SizedBox(width: 8),
                      Icon(icono, size: 18, color: estilo.color),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// El dato que está mal, en un renglón y con el ícono en naranja.
///
/// Entra y sale con un cambio de alto suave: si apareciera de golpe, el
/// botón de abajo saltaría justo debajo del dedo.
class AvisoError extends StatelessWidget {
  const AvisoError({super.key, required this.mensaje});

  /// Null no muestra nada.
  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    final m = mensaje;
    final contenido = m == null
        ? const SizedBox(width: double.infinity)
        : Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      CupertinoIcons.exclamationmark_circle_fill,
                      size: 17,
                      color: AppColors.accentSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

    // Con "Reducir movimiento" aparece de golpe. No alcanza con darle
    // duración cero a AnimatedSize: con cero, Flutter lo re-ensucia
    // adentro de su propio layout y revienta.
    if (MediaQuery.disableAnimationsOf(context)) return contenido;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: contenido,
    );
  }
}

/// Un ícono en un disco azul bruma: la misma marca que llevan los
/// títulos de sección de Hoy, para que el registro se lea como la misma
/// app.
class DiscoIcono extends StatelessWidget {
  const DiscoIcono({super.key, required this.icono, this.tamano = 52});

  final IconData icono;
  final double tamano;

  @override
  Widget build(BuildContext context) => Container(
    width: tamano,
    height: tamano,
    decoration: const BoxDecoration(
      color: AppColors.azulBruma,
      shape: BoxShape.circle,
    ),
    child: Icon(icono, size: tamano * 0.46, color: AppColors.accent),
  );
}

/// Tres anillos concéntricos con un arco que se llena al entrar.
///
/// Es el anillo de pasos de Hoy dicho en voz baja: la primera pantalla
/// de la app ya habla de avanzar, antes de tener un solo dato. Va
/// recortado en la esquina y en azul bruma, casi del color del fondo —
/// es ambiente, no contenido. El único trazo con color es el arco, y se
/// dibuja una sola vez: nada se mueve para siempre en el ingreso.
///
/// Sin `CustomPainter`: los anillos son círculos con borde y el arco es
/// un indicador circular con valor fijo.
class AnillosMarca extends StatelessWidget {
  const AnillosMarca({super.key, this.tamano = 340, this.llenado = 0.42});

  final double tamano;

  /// Hasta dónde llega el arco, de 0 a 1.
  final double llenado;

  @override
  Widget build(BuildContext context) {
    final quieto = MediaQuery.disableAnimationsOf(context);
    final medio = tamano * 0.68;

    Widget anillo(double d, Color color) => Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.2),
      ),
    );

    return ExcludeSemantics(
      child: SizedBox(
        width: tamano,
        height: tamano,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: quieto ? llenado : 0, end: llenado),
          duration: quieto ? Duration.zero : const Duration(milliseconds: 1600),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => Stack(
            alignment: Alignment.center,
            children: [
              anillo(tamano, AppColors.azulBruma),
              anillo(medio, AppColors.azulBruma),
              anillo(tamano * 0.36, AppColors.azulNiebla),
              // Arranca abajo (las 6) y avanza en el sentido del reloj
              // hacia la izquierda: con los anillos recortados en la
              // esquina de arriba a la derecha, ese es el cuarto que se ve.
              Transform.rotate(
                angle: math.pi,
                child: SizedBox(
                  width: medio,
                  height: medio,
                  child: CircularProgressIndicator(
                    value: t,
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                    color: AppColors.accent,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
              // La punta del arco: el mismo marcador que lleva el anillo
              // de Hoy donde va el día.
              Transform.rotate(
                angle: math.pi + t * 2 * math.pi,
                child: SizedBox(
                  width: medio,
                  height: medio,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Transform.translate(
                      // El arco va por el medio de su trazo de 3 px, así
                      // que el centro del punto baja 1,5 px del borde.
                      offset: const Offset(0, -4),
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.card, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La barrita de arrastre de una hoja, igual que en las demás hojas de
/// la app.
class BarritaHoja extends StatelessWidget {
  const BarritaHoja({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 4,
    margin: const EdgeInsets.only(top: 10, bottom: 14),
    decoration: BoxDecoration(
      color: AppColors.cardBorder,
      borderRadius: BorderRadius.circular(AppRadios.pildora),
    ),
  );
}
