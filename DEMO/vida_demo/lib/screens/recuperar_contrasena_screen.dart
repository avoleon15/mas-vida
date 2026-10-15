import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/fuente_datos.dart';
import '../theme.dart';
import '../validaciones_acceso.dart';
import '../widgets/acceso_widgets.dart';

// ============================================================
// RECUPERAR LA CONTRASEÑA.
//
// Pide el correo y manda un enlace. Después NO dice si ese correo tiene
// cuenta: "si hay una cuenta con este correo, te llega". Decir "no
// existe" le serviría a cualquiera para averiguar quién usa la app.
//
// [PENDIENTE: el endpoint no existe en el backend. Con el servicio
// local se simula el envío.]
// ============================================================

class RecuperarContrasenaScreen extends StatefulWidget {
  const RecuperarContrasenaScreen({
    super.key,
    this.correoInicial = '',
    this.servicio,
  });

  /// Lo que ya se había escrito en el login, para no pedirlo dos veces.
  final String correoInicial;

  final ServicioSesion? servicio;

  @override
  State<RecuperarContrasenaScreen> createState() =>
      _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState extends State<RecuperarContrasenaScreen> {
  late final _correo = TextEditingController(text: widget.correoInicial);
  bool _cargando = false;
  bool _enviado = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final correo = _correo.text.trim();
    if (!correoValido(correo)) {
      HapticFeedback.lightImpact();
      setState(() => _error = 'Ese correo no se ve bien. Revísalo, por favor.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await (widget.servicio ?? servicioSesion).recuperarContrasena(correo);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _cargando = false;
        _enviado = true;
      });
    } on ErrorSesion catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final quieto = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.fondoDePantalla,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Icon(
                  CupertinoIcons.chevron_back,
                  color: AppColors.accent,
                  semanticLabel: 'Volver',
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: AnimatedSwitcher(
                  duration: quieto
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  child: _enviado ? _listo(tema) : _pedir(tema),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pedir(TextTheme tema) => Column(
    key: const ValueKey('pedir'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const DiscoIcono(icono: CupertinoIcons.lock_rotation),
      const SizedBox(height: 20),
      Text('¿Olvidaste tu contraseña?', style: AppTheme.display(28)),
      const SizedBox(height: 10),
      Text(
        'Escribe tu correo y te mandamos un enlace para crear una nueva.',
        style: tema.bodyLarge?.copyWith(
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
          boxShadow: AppSombras.tarjeta,
        ),
        child: Column(
          children: [
            CampoVida(
              controller: _correo,
              placeholder: 'Correo',
              icono: CupertinoIcons.mail,
              teclado: TextInputType.emailAddress,
              accion: TextInputAction.send,
              autofill: const [AutofillHints.email],
              conError: _error != null,
              alEnviar: (_) => _enviar(),
              onChanged: (_) => setState(() => _error = null),
            ),
            AvisoError(mensaje: _error),
            const SizedBox(height: 18),
            BotonPildora(
              texto: 'Mandar enlace',
              cargando: _cargando,
              onPressed: _enviar,
            ),
          ],
        ),
      ),
    ],
  );

  Widget _listo(TextTheme tema) => Column(
    key: const ValueKey('listo'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const DiscoIcono(icono: CupertinoIcons.envelope_open),
      const SizedBox(height: 20),
      Text('Revisa tu correo', style: AppTheme.display(28)),
      const SizedBox(height: 10),
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Si hay una cuenta con '),
            TextSpan(
              text: _correo.text.trim(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const TextSpan(
              text:
                  ', te llega un enlace en unos minutos. Si no lo ves, '
                  'busca en la carpeta de correo no deseado.',
            ),
          ],
        ),
        style: tema.bodyLarge?.copyWith(
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 32),
      BotonPildora(
        texto: 'Volver a entrar',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ],
  );
}
