import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/fuente_datos.dart';
import '../theme.dart';
import '../validaciones_acceso.dart';
import '../widgets/acceso_widgets.dart';
import '../widgets/hoja_terminos.dart';
import '../widgets/logo_vida.dart';
import 'recuperar_contrasena_screen.dart';
import 'registro_screen.dart';

// ============================================================
// EL INGRESO: CORREO Y CONTRASEÑA, O APPLE Y GOOGLE (que todavía no
// entran, ver [_AccesoConProveedores]).
//
// Es la puerta de la app para quien no tiene sesión guardada. Desde acá
// se crea la cuenta, se recupera la contraseña y —mientras dure la etapa
// de pruebas— se entra sin cuenta con "Acceder por prueba".
//
// UNA SOLA COSA LEVANTADA: la tarjeta con el formulario. Los anillos de
// la esquina son ambiente, casi del color del fondo; el título y los
// enlaces se apoyan directo sobre la pantalla.
// ============================================================

/// Muestra el botón "Acceder por prueba", que entra sin cuenta.
///
/// Es para las pruebas del equipo y NO puede salir al piloto: un usuario
/// real que entra por ahí no tiene fecha de nacimiento ni términos
/// aceptados. Poner en false antes del build de TestFlight para
/// usuarios.
const bool mostrarAccesoDePrueba = true;

/// Llaves para los tests.
const Key llaveCorreoAcceso = ValueKey('acceso-correo');
const Key llaveContrasenaAcceso = ValueKey('acceso-contrasena');
const Key llaveEntrar = ValueKey('acceso-entrar');
const Key llaveAccesoPrueba = ValueKey('acceso-prueba');
const Key llaveCrearCuenta = ValueKey('acceso-crear-cuenta');

class AccesoScreen extends StatefulWidget {
  const AccesoScreen({super.key, required this.alEntrar, this.servicio});

  /// Qué hacer cuando hay sesión: la trae el login, el registro o el
  /// acceso de prueba.
  final ValueChanged<Sesion> alEntrar;

  /// Por defecto el de `fuente_datos.dart`; los tests pasan otro.
  final ServicioSesion? servicio;

  @override
  State<AccesoScreen> createState() => _AccesoScreenState();
}

class _AccesoScreenState extends State<AccesoScreen> {
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();

  bool _cargando = false;
  String? _error;
  bool _errorEnCorreo = false;

  ServicioSesion get _servicio => widget.servicio ?? servicioSesion;

  bool get _completo =>
      _correo.text.trim().isNotEmpty && _contrasena.text.isNotEmpty;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_cargando || !_completo) return;
    final correo = _correo.text.trim();
    if (!correoValido(correo)) {
      HapticFeedback.lightImpact();
      setState(() {
        _error = 'Ese correo no se ve bien. Revísalo, por favor.';
        _errorEnCorreo = true;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = null;
      _errorEnCorreo = false;
    });
    try {
      final sesion = await _servicio.iniciarSesion(correo, _contrasena.text);
      TextInput.finishAutofillContext();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      widget.alEntrar(sesion);
    } on ErrorSesion catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _cargando = false;
        _error = e.mensaje;
      });
    }
  }

  Future<void> _accederPorPrueba() async {
    HapticFeedback.selectionClick();
    final sesion = await _servicio.accederPorPrueba();
    if (!mounted) return;
    widget.alEntrar(sesion);
  }

  Future<void> _crearCuenta() async {
    HapticFeedback.selectionClick();
    final sesion = await Navigator.of(context).push<Sesion>(
      CupertinoPageRoute(builder: (_) => RegistroScreen(servicio: _servicio)),
    );
    if (sesion != null && mounted) widget.alEntrar(sesion);
  }

  void _olvideContrasena() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => RecuperarContrasenaScreen(
          correoInicial: _correo.text.trim(),
          servicio: _servicio,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.fondoDePantalla,
      body: Stack(
        children: [
          // Recortados en la esquina: se ve un cuarto de los anillos, y
          // el arco se llena justo en ese cuarto.
          // El arco se queda antes de salirse por arriba: la punta, con su
          // marcador, tiene que quedar a la vista.
          const Positioned(
            top: -50,
            right: -140,
            child: AnillosMarca(llenado: 0.34),
          ),
          SafeArea(
            // El formulario arriba y el acceso de prueba con el pie legal
            // pegados abajo, pero todo scrolleable: con el teclado abierto
            // en un iPhone SE no entra. `minHeight` + `spaceBetween` en
            // vez de un Spacer, porque un Spacer necesita alto fijo y
            // medirlo con alturas intrínsecas daba de menos y trababa el
            // scroll.
            child: LayoutBuilder(
              builder: (context, caja) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: caja.maxHeight - 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LogoVida(alto: 32),
                          const SizedBox(height: 56),
                          Semantics(
                            header: true,
                            label: 'Cada paso cuenta.',
                            excludeSemantics: true,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'Cada paso\n'),
                                  TextSpan(
                                    text: 'cuenta.',
                                    style: AppTheme.display(
                                      40,
                                    ).copyWith(color: AppColors.accent),
                                  ),
                                ],
                              ),
                              style: AppTheme.display(
                                40,
                              ).copyWith(height: 1.05),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Entra y mira cuánto te has movido hoy.',
                            style: tema.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _formulario(),
                          const SizedBox(height: 22),
                          const _AccesoConProveedores(),
                          const SizedBox(height: 18),
                          Center(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '¿Primera vez aquí?',
                                  style: tema.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                CupertinoButton(
                                  key: llaveCrearCuenta,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  onPressed: _crearCuenta,
                                  child: Text(
                                    'Crea tu cuenta',
                                    style: tema.bodyMedium?.copyWith(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          children: [
                            if (mostrarAccesoDePrueba) ...[
                              _AccesoDePrueba(onPressed: _accederPorPrueba),
                              const SizedBox(height: 14),
                            ],
                            const _PieLegal(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formulario() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        boxShadow: AppSombras.tarjeta,
      ),
      // AutofillGroup: iOS ofrece la contraseña guardada en el llavero
      // y la guarda al entrar.
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampoVida(
              key: llaveCorreoAcceso,
              controller: _correo,
              placeholder: 'Correo',
              icono: CupertinoIcons.mail,
              teclado: TextInputType.emailAddress,
              autofill: const [AutofillHints.email, AutofillHints.username],
              conError: _errorEnCorreo,
              onChanged: (_) => setState(() {
                _errorEnCorreo = false;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            CampoVida(
              key: llaveContrasenaAcceso,
              controller: _contrasena,
              placeholder: 'Contraseña',
              icono: CupertinoIcons.lock,
              esContrasena: true,
              accion: TextInputAction.done,
              autofill: const [AutofillHints.password],
              alEnviar: (_) => _entrar(),
              onChanged: (_) => setState(() => _error = null),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                padding: const EdgeInsets.only(top: 12, bottom: 4, left: 8),
                minimumSize: Size.zero,
                onPressed: _olvideContrasena,
                child: Text(
                  '¿Olvidaste tu contraseña?',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.azulMedio,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            AvisoError(mensaje: _error),
            const SizedBox(height: 18),
            BotonPildora(
              key: llaveEntrar,
              texto: 'Entrar',
              icono: CupertinoIcons.arrow_right,
              cargando: _cargando,
              onPressed: _completo ? _entrar : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// El atajo de las pruebas, separado del resto por su propio rótulo.
///
/// Se ve distinto a propósito —píldora de contorno, sin relleno— para
/// que nadie del equipo lo confunda con el ingreso de verdad cuando le
/// muestra la app a alguien.
class _AccesoDePrueba extends StatelessWidget {
  const _AccesoDePrueba({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    Widget raya() =>
        Expanded(child: Container(height: 0.5, color: AppColors.separador));

    return Column(
      children: [
        Row(
          children: [
            raya(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'SOLO PARA PRUEBAS',
                style: tema.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            raya(),
          ],
        ),
        const SizedBox(height: 12),
        CupertinoButton(
          key: llaveAccesoPrueba,
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadios.pildora),
              border: Border.all(color: AppColors.azulSuave),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.bolt_fill,
                  size: 16,
                  color: AppColors.azulMedio,
                ),
                const SizedBox(width: 8),
                Text(
                  'Acceder por prueba',
                  style: tema.labelLarge?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Entrar con Apple o con Google.
// ============================================================

/// Llaves de los dos botones, para los tests.
const Key llaveEntrarConApple = ValueKey('acceso-apple');
const Key llaveEntrarConGoogle = ValueKey('acceso-google');

/// "Continuar con Apple" y "Continuar con Google" (reunión del 2 de
/// octubre de 2026).
///
/// TODAVÍA NO ENTRAN: se ven para que el diseño quede completo, y al
/// tocarlos avisan que vienen pronto. Para que funcionen hace falta
/// configuración que no vive en el código —los client id de Google
/// Cloud, la capacidad "Sign in with Apple" en el App ID de Assures— y
/// un endpoint en el servidor que verifique el token del proveedor. El
/// token NUNCA se puede dar por bueno en el teléfono.
///
/// Van los dos o ninguno: Apple exige su botón en cualquier app de iOS
/// que ofrezca entrar con Google (guía 4.8 de la App Store). Y el de
/// Apple va primero y en negro, como lo pide su guía de estilo.
class _AccesoConProveedores extends StatelessWidget {
  const _AccesoConProveedores();

  void _avisarQueVienePronto(BuildContext context, String proveedor) {
    HapticFeedback.selectionClick();
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Muy pronto'),
        content: Text(
          'Entrar con $proveedor todavía no está disponible. Por ahora usa '
          'tu correo.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    Widget raya() =>
        Expanded(child: Container(height: 0.5, color: AppColors.separador));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            raya(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'o continúa con',
                style: tema.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            raya(),
          ],
        ),
        const SizedBox(height: 16),
        _BotonProveedor(
          key: llaveEntrarConApple,
          texto: 'Continuar con Apple',
          logo: const Icon(Icons.apple, size: 22, color: Colors.white),
          fondo: Colors.black,
          tinta: Colors.white,
          onPressed: () => _avisarQueVienePronto(context, 'Apple'),
        ),
        const SizedBox(height: 10),
        _BotonProveedor(
          key: llaveEntrarConGoogle,
          texto: 'Continuar con Google',
          logo: const _LetraGoogle(),
          fondo: AppColors.card,
          tinta: AppColors.textPrimary,
          borde: AppColors.cardBorder,
          onPressed: () => _avisarQueVienePronto(context, 'Google'),
        ),
      ],
    );
  }
}

/// Un botón de proveedor: píldora con el logo a la izquierda y el texto
/// centrado. Mismo alto que "Entrar" para que se lean como hermanos.
class _BotonProveedor extends StatelessWidget {
  const _BotonProveedor({
    super.key,
    required this.texto,
    required this.logo,
    required this.fondo,
    required this.tinta,
    required this.onPressed,
    this.borde,
  });

  final String texto;
  final Widget logo;
  final Color fondo;
  final Color tinta;
  final Color? borde;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: texto,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onPressed,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(AppRadios.pildora),
            border: borde == null ? null : Border.all(color: borde!),
          ),
          child: Row(
            children: [
              SizedBox(width: 24, child: Center(child: logo)),
              Expanded(
                child: Text(
                  texto,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: tinta,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // El mismo ancho que el logo, del otro lado: así el texto
              // queda centrado en el botón y no corrido a la derecha.
              const SizedBox(width: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// La "G" de Google, en su azul. Es un marcador hasta tener el logo
/// oficial como asset, que es el que pide su guía de marca.
class _LetraGoogle extends StatelessWidget {
  const _LetraGoogle();

  @override
  Widget build(BuildContext context) => Text(
    'G',
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: const Color(0xFF4285F4),
      fontWeight: FontWeight.w800,
      height: 1,
    ),
  );
}

/// "Al usar +Vida aceptas los Términos y condiciones", con el enlace a
/// la hoja completa.
class _PieLegal extends StatelessWidget {
  const _PieLegal();

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Al usar +Vida aceptas los ', style: estilo),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 6),
            minimumSize: Size.zero,
            onPressed: () => mostrarHojaTerminos(context),
            child: Text(
              'Términos y condiciones',
              style: estilo?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text('.', style: estilo),
        ],
      ),
    );
  }
}
