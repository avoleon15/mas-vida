import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/fuente_datos.dart';
import '../theme.dart';
import '../validaciones_acceso.dart';
import '../widgets/acceso_widgets.dart';
import '../widgets/hoja_terminos.dart';
import '../widgets/moneda_animada.dart';

// ============================================================
// CREAR LA CUENTA, EN PASOS.
//
//   1. Tu cuenta         nombre, correo y contraseña.
//   2. Tu edad           fecha de nacimiento (obligatoria, CLAUDE.md).
//   3. Tu póliza         opcional: "gratis para jugar, pago para los
//                        beneficios". Se puede saltar.
//   4. Tu aseguradora    SOLO si cargó póliza. El consentimiento de datos
//                        hacia la aseguradora es explícito y en pantalla
//                        propia (CLAUDE.md), no un renglón más de los
//                        términos.
//   5. Términos          el resumen de lo importante, los términos
//                        completos y las dos casillas que se aceptan.
//
// Al terminar, la pantalla se cierra devolviendo la [Sesion]. Quién la
// abrió (el login) decide a dónde se va: la primera vez, al permiso de
// Salud, que es donde iOS pregunta de verdad.
//
// Un paso por pantalla y no un formulario largo: cada pantalla contesta
// UNA pregunta y explica por qué se la hacemos.
// ============================================================

/// Llaves para los tests.
const Key llaveSiguienteRegistro = ValueKey('registro-siguiente');
const Key llaveSaltarPoliza = ValueKey('registro-saltar-poliza');
const Key llaveAceptoTerminos = ValueKey('registro-acepto-terminos');
const Key llaveAceptoSalud = ValueKey('registro-acepto-salud');
const Key llaveSelectorNacimiento = ValueKey('registro-nacimiento');

enum _Paso { cuenta, edad, poliza, aseguradora, terminos }

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

String _fechaLarga(DateTime d) =>
    '${d.day} de ${_meses[d.month - 1]} de ${d.year}';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key, this.servicio, this.hoy});

  final ServicioSesion? servicio;

  /// La fecha de hoy. Los tests la fijan para que la edad no cambie con
  /// el calendario.
  final DateTime? hoy;

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _paginas = PageController();

  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _aseguradora = TextEditingController();
  final _numeroPoliza = TextEditingController();

  int _actual = 0;
  DateTime? _nacimiento;
  DateTime? _inicioVigencia;
  bool _conPoliza = false;
  bool _compartir = false;
  bool _aceptoTerminos = false;
  bool _aceptoSalud = false;
  bool _cargando = false;
  String? _error;

  late final DateTime _hoy = widget.hoy ?? DateTime.now();

  ServicioSesion get _servicio => widget.servicio ?? servicioSesion;

  List<_Paso> get _pasos => [
    _Paso.cuenta,
    _Paso.edad,
    _Paso.poliza,
    if (_conPoliza) _Paso.aseguradora,
    _Paso.terminos,
  ];

  _Paso get _paso => _pasos[_actual];

  @override
  void initState() {
    super.initState();
    for (final c in [
      _nombre,
      _correo,
      _contrasena,
      _aseguradora,
      _numeroPoliza,
    ]) {
      c.addListener(_alEscribir);
    }
  }

  void _alEscribir() => setState(() => _error = null);

  @override
  void dispose() {
    _paginas.dispose();
    for (final c in [
      _nombre,
      _correo,
      _contrasena,
      _aseguradora,
      _numeroPoliza,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------
  // Moverse entre pasos
  // ------------------------------------------------------------

  void _irA(int i) {
    FocusScope.of(context).unfocus();
    setState(() {
      _actual = i;
      _error = null;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _paginas.jumpToPage(i);
    } else {
      _paginas.animateToPage(
        i,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _siguiente() {
    HapticFeedback.selectionClick();
    _irA(_actual + 1);
  }

  void _atras() {
    if (_actual == 0) {
      Navigator.of(context).maybePop();
    } else {
      _irA(_actual - 1);
    }
  }

  // ------------------------------------------------------------
  // Qué hace el botón de cada paso
  // ------------------------------------------------------------

  String? _errorDeCuenta() {
    if (_nombre.text.trim().length < 2) return 'Escribe tu nombre.';
    if (!correoValido(_correo.text)) {
      return 'Ese correo no se ve bien. Revísalo, por favor.';
    }
    if (!contrasenaValida(_contrasena.text)) {
      return 'Tu contraseña necesita 8 caracteres o más y al menos una letra.';
    }
    return null;
  }

  bool get _cuentaCompleta =>
      _nombre.text.trim().isNotEmpty &&
      _correo.text.trim().isNotEmpty &&
      _contrasena.text.isNotEmpty;

  bool get _polizaCompleta =>
      _aseguradora.text.trim().isNotEmpty &&
      _numeroPoliza.text.trim().isNotEmpty &&
      _inicioVigencia != null;

  void _continuarCuenta() {
    final error = _errorDeCuenta();
    if (error != null) {
      HapticFeedback.lightImpact();
      setState(() => _error = error);
      return;
    }
    _siguiente();
  }

  void _elegirPoliza(bool vincular) {
    setState(() {
      _conPoliza = vincular;
      if (!vincular) _compartir = false;
    });
    _siguiente();
  }

  void _elegirCompartir(bool autoriza) {
    setState(() => _compartir = autoriza);
    _siguiente();
  }

  Future<void> _crearCuenta() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final sesion = await _servicio.registrar(
        DatosRegistro(
          nombre: _nombre.text.trim(),
          correo: _correo.text.trim(),
          contrasena: _contrasena.text,
          fechaNacimiento: _nacimiento!,
          poliza: _conPoliza
              ? PolizaRegistro(
                  aseguradora: _aseguradora.text.trim(),
                  numero: _numeroPoliza.text.trim(),
                  inicioVigencia: _inicioVigencia!,
                )
              : null,
          compartirConAseguradora: _conPoliza && _compartir,
        ),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(sesion);
    } on ErrorSesion catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _cargando = false;
        _error = e.mensaje;
      });
    }
  }

  Future<void> _elegirInicioVigencia() async {
    FocusScope.of(context).unfocus();
    var elegida = _inicioVigencia ?? DateTime(_hoy.year, _hoy.month, 1);
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (hoja) => Container(
        height: 320,
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Inicio de vigencia',
                        style: Theme.of(hoja).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.of(hoja).pop(true),
                      child: const Text(
                        'Listo',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  dateOrder: DatePickerDateOrder.dmy,
                  initialDateTime: elegida,
                  minimumDate: DateTime(_hoy.year - 30),
                  maximumDate: DateTime(_hoy.year + 1, 12, 31),
                  onDateTimeChanged: (d) => elegida = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted) setState(() => _inicioVigencia = elegida);
  }

  // ------------------------------------------------------------
  // Pantalla
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pasos = _pasos;

    return PopScope(
      // El gesto de volver retrocede un paso, no cierra el registro
      // entero: perder lo escrito por un deslizón sería frustrante.
      canPop: _actual == 0,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _atras();
      },
      child: Scaffold(
        backgroundColor: AppColors.fondoDePantalla,
        body: SafeArea(
          // Al cerrar el registro con la cuenta creada, iOS ofrece
          // guardar la contraseña en el llavero.
          child: AutofillGroup(
            onDisposeAction: AutofillContextAction.commit,
            child: Column(
              children: [
                _Encabezado(
                  actual: _actual,
                  total: pasos.length,
                  onAtras: _atras,
                ),
                Expanded(
                  child: PageView(
                    controller: _paginas,
                    // Solo se avanza con el botón: deslizar dejaría
                    // saltarse un paso sin completarlo.
                    physics: const NeverScrollableScrollPhysics(),
                    children: [for (final p in pasos) _pagina(p)],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: _botones(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pagina(_Paso paso) => switch (paso) {
    _Paso.cuenta => _PasoCuenta(
      nombre: _nombre,
      correo: _correo,
      contrasena: _contrasena,
      error: _error,
      alEnviar: _continuarCuenta,
    ),
    _Paso.edad => _PasoEdad(
      hoy: _hoy,
      nacimiento: _nacimiento,
      alCambiar: (d) => setState(() => _nacimiento = d),
    ),
    _Paso.poliza => _PasoPoliza(
      aseguradora: _aseguradora,
      numero: _numeroPoliza,
      inicioVigencia: _inicioVigencia,
      alTocarInicio: _elegirInicioVigencia,
    ),
    _Paso.aseguradora => const _PasoAseguradora(),
    _Paso.terminos => _PasoTerminos(
      aceptoTerminos: _aceptoTerminos,
      aceptoSalud: _aceptoSalud,
      alCambiarTerminos: (v) => setState(() => _aceptoTerminos = v),
      alCambiarSalud: (v) => setState(() => _aceptoSalud = v),
      error: _error,
    ),
  };

  Widget _botones() {
    switch (_paso) {
      case _Paso.cuenta:
        return BotonPildora(
          key: llaveSiguienteRegistro,
          texto: 'Continuar',
          icono: CupertinoIcons.arrow_right,
          onPressed: _cuentaCompleta ? _continuarCuenta : null,
        );
      case _Paso.edad:
        return BotonPildora(
          key: llaveSiguienteRegistro,
          texto: 'Continuar',
          icono: CupertinoIcons.arrow_right,
          onPressed: _nacimiento != null ? _siguiente : null,
        );
      case _Paso.poliza:
        return _DosBotones(
          principal: BotonPildora(
            key: llaveSiguienteRegistro,
            texto: 'Vincular póliza',
            onPressed: _polizaCompleta ? () => _elegirPoliza(true) : null,
          ),
          secundario: 'Lo hago después',
          llaveSecundario: llaveSaltarPoliza,
          onSecundario: () => _elegirPoliza(false),
        );
      case _Paso.aseguradora:
        return _DosBotones(
          principal: BotonPildora(
            key: llaveSiguienteRegistro,
            texto: 'Autorizo',
            onPressed: () => _elegirCompartir(true),
          ),
          secundario: 'Ahora no',
          onSecundario: () => _elegirCompartir(false),
        );
      case _Paso.terminos:
        return BotonPildora(
          key: llaveSiguienteRegistro,
          texto: 'Crear mi cuenta',
          cargando: _cargando,
          onPressed: _aceptoTerminos && _aceptoSalud ? _crearCuenta : null,
        );
    }
  }
}

// ============================================================
// El encabezado: volver, en qué paso va y la barra de pasos.
// ============================================================

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.actual,
    required this.total,
    required this.onAtras,
  });

  final int actual;
  final int total;
  final VoidCallback onAtras;

  @override
  Widget build(BuildContext context) {
    final quieto = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 24, 8),
      child: Column(
        children: [
          Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: onAtras,
                child: Icon(
                  actual == 0
                      ? CupertinoIcons.xmark
                      : CupertinoIcons.chevron_back,
                  color: AppColors.accent,
                  semanticLabel: actual == 0 ? 'Cerrar' : 'Paso anterior',
                ),
              ),
              const Spacer(),
              Text(
                'Paso ${actual + 1} de $total',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Un segmento por paso. Los hechos y el actual en azul: se lee
          // cuánto falta sin contar.
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < total; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: AnimatedContainer(
                        duration: quieto
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= actual
                              ? AppColors.accent
                              : AppColors.cardBorder,
                          borderRadius: BorderRadius.circular(
                            AppRadios.pildora,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El botón principal y, debajo, la salida alternativa en texto.
class _DosBotones extends StatelessWidget {
  const _DosBotones({
    required this.principal,
    required this.secundario,
    required this.onSecundario,
    this.llaveSecundario,
  });

  final Widget principal;
  final String secundario;
  final VoidCallback onSecundario;
  final Key? llaveSecundario;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      principal,
      CupertinoButton(
        key: llaveSecundario,
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        onPressed: onSecundario,
        child: Text(
          secundario,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

// ============================================================
// La cáscara de cada paso: ícono, título, por qué, y el contenido.
// ============================================================

class _CuerpoPaso extends StatelessWidget {
  const _CuerpoPaso({
    required this.icono,
    required this.titulo,
    required this.bajada,
    required this.children,
  });

  final Widget icono;
  final String titulo;
  final String bajada;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icono,
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            titulo,
            style: AppTheme.display(28).copyWith(height: 1.1),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          bajada,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        ...children,
      ],
    ),
  );
}

/// La única superficie levantada de cada paso.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child, this.padding = 18});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadios.tarjeta),
      boxShadow: AppSombras.tarjeta,
    ),
    child: child,
  );
}

/// Un renglón de una lista plana: ícono en disco, título y detalle.
class _Renglon extends StatelessWidget {
  const _Renglon({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final Widget icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.azulBruma,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: icono,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: tema.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: tema.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
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

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => Container(
    height: 0.5,
    margin: const EdgeInsets.only(left: 50),
    color: AppColors.separador,
  );
}

Icon _icono(IconData i) => Icon(i, size: 18, color: AppColors.accent);

// ============================================================
// 1. Tu cuenta
// ============================================================

class _PasoCuenta extends StatelessWidget {
  const _PasoCuenta({
    required this.nombre,
    required this.correo,
    required this.contrasena,
    required this.error,
    required this.alEnviar,
  });

  final TextEditingController nombre;
  final TextEditingController correo;
  final TextEditingController contrasena;
  final String? error;
  final VoidCallback alEnviar;

  @override
  Widget build(BuildContext context) {
    return _CuerpoPaso(
      icono: const DiscoIcono(
        icono: CupertinoIcons.person_crop_circle_badge_plus,
      ),
      titulo: 'Crea tu cuenta',
      bajada:
          'Es gratis y te toma un minuto. Sin póliza ya puedes sumar puntos.',
      children: [
        _Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CampoVida(
                controller: nombre,
                placeholder: 'Tu nombre',
                icono: CupertinoIcons.person,
                capitalizacion: TextCapitalization.words,
                autofill: const [AutofillHints.name],
              ),
              const SizedBox(height: 12),
              CampoVida(
                controller: correo,
                placeholder: 'Correo',
                icono: CupertinoIcons.mail,
                teclado: TextInputType.emailAddress,
                autofill: const [AutofillHints.email],
              ),
              const SizedBox(height: 12),
              CampoVida(
                controller: contrasena,
                placeholder: 'Contraseña',
                icono: CupertinoIcons.lock,
                esContrasena: true,
                accion: TextInputAction.done,
                autofill: const [AutofillHints.newPassword],
                alEnviar: (_) => alEnviar(),
              ),
              const SizedBox(height: 14),
              // Los requisitos a la vista mientras se escribe: se cumplen
              // de a uno, sin tener que adivinar qué pide el servidor.
              ValueListenableBuilder(
                valueListenable: contrasena,
                builder: (context, valor, _) => Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    for (final r in requisitosContrasena(valor.text))
                      _Requisito(texto: r.texto, cumplido: r.cumplido),
                  ],
                ),
              ),
              AvisoError(mensaje: error),
            ],
          ),
        ),
      ],
    );
  }
}

class _Requisito extends StatelessWidget {
  const _Requisito({required this.texto, required this.cumplido});

  final String texto;
  final bool cumplido;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$texto${cumplido ? ', cumplido' : ''}',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          cumplido
              ? CupertinoIcons.checkmark_circle_fill
              : CupertinoIcons.circle,
          size: 15,
          color: cumplido ? AppColors.accent : AppColors.azulSuave,
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cumplido ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: cumplido ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

// ============================================================
// 2. Tu edad
// ============================================================

class _PasoEdad extends StatelessWidget {
  const _PasoEdad({
    required this.hoy,
    required this.nacimiento,
    required this.alCambiar,
  });

  final DateTime hoy;
  final DateTime? nacimiento;
  final ValueChanged<DateTime> alCambiar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final n = nacimiento;
    final maximo = nacimientoMaximo(hoy);
    // La rueda arranca en 30 años atrás: el medio del piloto. Si arrancara
    // en hoy − 18, casi todos tendrían que girar décadas.
    final inicial = DateTime(hoy.year - 30, 1, 1);

    return _CuerpoPaso(
      icono: const DiscoIcono(icono: CupertinoIcons.gift),
      titulo: '¿Cuándo naciste?',
      bajada:
          'Con tu edad ajustamos cómo se mide tu esfuerzo. Así cada '
          'entrenamiento cuenta lo justo para ti.',
      children: [
        _Tarjeta(
          padding: 0,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Semantics(
                  liveRegion: true,
                  child: n == null
                      ? Text(
                          'Gira la rueda para elegir tu fecha',
                          style: tema.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${edadEn(n, hoy)}',
                              style: AppTheme.display(
                                44,
                              ).copyWith(color: AppColors.accent),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'años',
                              style: tema.titleMedium?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(
                height: 190,
                child: CupertinoDatePicker(
                  key: llaveSelectorNacimiento,
                  mode: CupertinoDatePickerMode.date,
                  dateOrder: DatePickerDateOrder.dmy,
                  initialDateTime: n ?? inicial,
                  minimumDate: DateTime(1920),
                  maximumDate: maximo,
                  onDateTimeChanged: alCambiar,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.grupo),
        _Renglon(
          icono: _icono(CupertinoIcons.heart),
          titulo: 'Tu zona de esfuerzo',
          detalle:
              'Un entrenamiento cuenta según lo que es intenso para '
              'alguien de tu edad.',
        ),
        const _Separador(),
        _Renglon(
          icono: _icono(CupertinoIcons.person_3),
          titulo: 'Tu liga',
          detalle: 'En La Liga compites con gente de tu edad.',
        ),
        const _Separador(),
        _Renglon(
          icono: _icono(CupertinoIcons.checkmark_shield),
          titulo: 'Se confirma con tu póliza',
          detalle:
              'Tu aseguradora confirma la fecha. Si coincide, conservas '
              'todo lo que hayas ganado.',
        ),
        const SizedBox(height: 8),
        Text(
          'Necesitas tener $edadMinima años o más para abrir tu cuenta.',
          style: tema.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ============================================================
// 3. Tu póliza
// ============================================================

class _PasoPoliza extends StatelessWidget {
  const _PasoPoliza({
    required this.aseguradora,
    required this.numero,
    required this.inicioVigencia,
    required this.alTocarInicio,
  });

  final TextEditingController aseguradora;
  final TextEditingController numero;
  final DateTime? inicioVigencia;
  final VoidCallback alTocarInicio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final inicio = inicioVigencia;

    return _CuerpoPaso(
      icono: const DiscoIcono(icono: CupertinoIcons.doc_text),
      titulo: 'Vincula tu póliza',
      bajada: 'Con ella cobras tu cashback y canjeas tus premios.',
      children: [
        _Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CampoVida(
                controller: aseguradora,
                placeholder: 'Aseguradora',
                icono: CupertinoIcons.building_2_fill,
                capitalizacion: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              CampoVida(
                controller: numero,
                placeholder: 'Número de póliza',
                icono: CupertinoIcons.number,
                capitalizacion: TextCapitalization.characters,
                accion: TextInputAction.done,
              ),
              const SizedBox(height: 12),
              // Se ve como un campo más, pero abre la rueda de fechas:
              // escribir una fecha a mano es la forma más fácil de
              // equivocarse.
              Semantics(
                button: true,
                label: inicio == null
                    ? 'Inicio de vigencia, sin elegir'
                    : 'Inicio de vigencia, ${_fechaLarga(inicio)}',
                excludeSemantics: true,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: alTocarInicio,
                  child: Container(
                    height: 55,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: AppColors.azulNiebla,
                      borderRadius: BorderRadius.circular(AppRadios.pildora),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.calendar,
                          size: 19,
                          color: AppColors.azulMedio,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            inicio == null
                                ? 'Inicio de vigencia'
                                : _fechaLarga(inicio),
                            style: tema.bodyLarge?.copyWith(
                              color: inicio == null
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontWeight: inicio == null
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          CupertinoIcons.chevron_down,
                          size: 15,
                          color: AppColors.azulMedio,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.grupo),
        _Renglon(
          icono: _icono(CupertinoIcons.hourglass),
          titulo: 'Tu aseguradora la revisa',
          detalle:
              'Te avisamos cuando esté verificada. Mientras tanto usas '
              'la app igual.',
        ),
        const _Separador(),
        _Renglon(
          icono: _icono(CupertinoIcons.arrow_right_circle),
          titulo: '¿No la tienes a mano?',
          detalle:
              'Hazlo después desde Mi Plan. Sin póliza sumas puntos y '
              'monedas igual; la necesitas para canjear premios y recibir '
              'tu cashback.',
        ),
      ],
    );
  }
}

// ============================================================
// 4. Tu aseguradora (solo si cargó póliza)
// ============================================================

class _PasoAseguradora extends StatelessWidget {
  const _PasoAseguradora();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;

    Widget fila(IconData icono, Color color, String texto) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: tema.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    Widget rotulo(String texto) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        texto,
        style: tema.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return _CuerpoPaso(
      icono: const DiscoIcono(icono: CupertinoIcons.shield_lefthalf_fill),
      titulo: '¿Compartimos tu actividad con tu aseguradora?',
      bajada: 'Solo con tu permiso. Esto es exactamente lo que le llegaría.',
      children: [
        _Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              rotulo('LE LLEGA, UNA VEZ AL DÍA'),
              fila(
                CupertinoIcons.checkmark,
                AppColors.accent,
                'Tus pasos totales del día',
              ),
              fila(
                CupertinoIcons.checkmark,
                AppColors.accent,
                'Tu ritmo cardíaco promedio del día',
              ),
              fila(
                CupertinoIcons.checkmark,
                AppColors.accent,
                'Los entrenamientos que hiciste',
              ),
              const SizedBox(height: 10),
              Container(height: 0.5, color: AppColors.separador),
              const SizedBox(height: 14),
              rotulo('NUNCA LE LLEGA'),
              fila(
                CupertinoIcons.xmark,
                AppColors.textSecondary,
                'El detalle minuto a minuto',
              ),
              fila(
                CupertinoIcons.xmark,
                AppColors.textSecondary,
                'Los registros sueltos de Salud',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.entre),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                CupertinoIcons.arrow_2_circlepath,
                size: 16,
                color: AppColors.azulMedio,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Puedes cambiarlo cuando quieras desde Perfil.',
                style: tema.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// 5. Términos
// ============================================================

class _PasoTerminos extends StatelessWidget {
  const _PasoTerminos({
    required this.aceptoTerminos,
    required this.aceptoSalud,
    required this.alCambiarTerminos,
    required this.alCambiarSalud,
    required this.error,
  });

  final bool aceptoTerminos;
  final bool aceptoSalud;
  final ValueChanged<bool> alCambiarTerminos;
  final ValueChanged<bool> alCambiarSalud;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;

    return _CuerpoPaso(
      icono: const DiscoIcono(icono: CupertinoIcons.doc_checkmark),
      titulo: 'Lo importante, en corto',
      bajada: 'Léelo con calma: es lo que aceptas al crear tu cuenta.',
      children: [
        _Renglon(
          icono: _icono(CupertinoIcons.heart_fill),
          titulo: 'Leemos tus datos de Salud',
          detalle:
              'Tus pasos, tu ritmo cardíaco y tus entrenamientos. Solo '
              'leemos: nunca escribimos ni borramos nada.',
        ),
        const _Separador(),
        _Renglon(
          icono: _icono(CupertinoIcons.chart_bar_alt_fill),
          titulo: 'Tus puntos son tu nivel',
          detalle:
              'Nunca se gastan. Definen tu nivel del año de póliza y tu '
              'porcentaje de cashback.',
        ),
        const _Separador(),
        const _Renglon(
          // El ícono de las monedas es el único naranja que significa
          // algo solo (CLAUDE.md).
          icono: MonedaAnimada(size: 20),
          titulo: 'Tus monedas duran una temporada',
          detalle:
              'Se canjean por premios. El año tiene 4 temporadas y lo que '
              'ganas en una vence cuando esa temporada cierra.',
        ),
        const _Separador(),
        _Renglon(
          icono: _icono(CupertinoIcons.arrow_uturn_left),
          titulo: 'El cashback es dinero de vuelta',
          detalle:
              'Se te devuelve después de pagar tu prima. Nunca es un '
              'descuento.',
        ),
        const _Separador(),
        _Renglon(
          icono: _icono(CupertinoIcons.eye_slash),
          titulo: 'Tu aseguradora ve solo lo que autorices',
          detalle: 'Un resumen de cada día, nunca el detalle minuto a minuto.',
        ),
        CupertinoButton(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          onPressed: () => mostrarHojaTerminos(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'Leer los términos completos',
                  style: tema.titleSmall?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 15,
                color: AppColors.accent,
              ),
            ],
          ),
        ),
        _Tarjeta(
          padding: 6,
          child: Column(
            children: [
              _Casilla(
                key: llaveAceptoTerminos,
                valor: aceptoTerminos,
                alCambiar: alCambiarTerminos,
                texto:
                    'Acepto los Términos y condiciones y el Aviso de '
                    'privacidad de +Vida.',
              ),
              Container(
                height: 0.5,
                margin: const EdgeInsets.only(left: 52),
                color: AppColors.separador,
              ),
              _Casilla(
                key: llaveAceptoSalud,
                valor: aceptoSalud,
                alCambiar: alCambiarSalud,
                texto:
                    'Autorizo a +Vida a leer mis pasos, ritmo cardíaco y '
                    'entrenamientos de la app Salud para calcular mis puntos.',
              ),
            ],
          ),
        ),
        AvisoError(mensaje: error),
        const SizedBox(height: 12),
        Text(
          'Después iOS te va a preguntar por cada dato de Salud. Puedes '
          'quitar el permiso cuando quieras en Ajustes › Salud.',
          style: tema.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Una casilla que se acepta. Todo el renglón se toca, no solo el
/// cuadrito: el texto es lo que se está aceptando.
///
/// Acá SÍ va la forma de una casilla, porque sí se marca. (En los
/// objetivos de la semana está prohibida justamente porque ahí no hay
/// nada que marcar.)
class _Casilla extends StatelessWidget {
  const _Casilla({
    super.key,
    required this.valor,
    required this.alCambiar,
    required this.texto,
  });

  final bool valor;
  final ValueChanged<bool> alCambiar;
  final String texto;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: CupertinoButton(
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
      minimumSize: Size.zero,
      pressedOpacity: 0.7,
      onPressed: () {
        HapticFeedback.selectionClick();
        alCambiar(!valor);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoCheckbox(
            value: valor,
            activeColor: AppColors.accent,
            onChanged: (v) => alCambiar(v ?? false),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
