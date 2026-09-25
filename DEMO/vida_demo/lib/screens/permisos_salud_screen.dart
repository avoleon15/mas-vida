import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/almacen_permisos.dart';
import '../datos/healthkit_bridge.dart';
import '../theme.dart';
import '../widgets/app_header.dart';

// ============================================================
// EL PERMISO DE APPLE SALUD.
//
// Antes de que iOS muestre su diálogo —que es seco y en inglés técnico—
// esta pantalla le cuenta al usuario, con palabras de todos los días, qué
// vamos a leer y para qué sirve cada cosa. Después del diálogo le dice
// qué vemos DE VERDAD, tipo por tipo, con lo que devuelve
// `solicitarPermisos` del puente nativo de Alvaro (desde el 6 de
// septiembre de 2026 trae los tipos visibles).
//
// Vive en dos lugares:
//   · al abrir la app por primera vez, antes de Hoy (ver `_Arranque` en
//     main.dart): sin pasos no hay puntos, así que es el paso uno;
//   · en Perfil, tocando la fila "Apple Salud", para volver a revisarlo.
//
// Lo que NO puede hacer: acusar. HealthKit nunca dice si el usuario negó
// un permiso de lectura; devuelve vacío y listo. Y el ritmo cardíaco y los
// entrenamientos salen casi siempre de un reloj, que la mayoría del piloto
// no tiene. Por eso "no vemos ritmo cardíaco" se dice como algo normal,
// con el camino a Ajustes solo para el que SÍ usa reloj.
// ============================================================

/// Llave del botón principal, para los tests.
const Key llaveBotonPermisos = ValueKey('permisos-boton-principal');

/// Dónde se revisa el permiso en iOS. Una sola vez acá para que los tres
/// avisos digan exactamente lo mismo.
const String _rutaAjustes =
    'Ajustes › Salud › Acceso a datos y dispositivos › +Vida';

class PermisosSaludScreen extends StatefulWidget {
  const PermisosSaludScreen({super.key, this.alTerminar, this.solicitar});

  /// Qué hacer al terminar cuando la pantalla es parte del ARRANQUE (ir a
  /// Hoy). Null cuando se abre desde Perfil: ahí se cierra con volver.
  final VoidCallback? alTerminar;

  /// Cómo se piden los permisos. Por defecto, el puente nativo; los tests
  /// pasan uno falso.
  final Future<ResultadoPermisos> Function()? solicitar;

  @override
  State<PermisosSaludScreen> createState() => _PermisosSaludScreenState();
}

class _PermisosSaludScreenState extends State<PermisosSaludScreen> {
  ResultadoPermisos? _resultado;
  bool _pidiendo = false;

  /// Falló la llamada al nativo: no hay HealthKit en esta plataforma
  /// (Windows, Android, los tests) o el nativo devolvió un error.
  bool _fallo = false;

  bool get _enArranque => widget.alTerminar != null;

  Future<void> _pedir() async {
    HapticFeedback.selectionClick();
    setState(() {
      _pidiendo = true;
      _fallo = false;
    });
    ResultadoPermisos? resultado;
    try {
      resultado =
          await (widget.solicitar ?? HealthKitBridge().solicitarPermisos)();
    } on PlatformException {
      resultado = null;
    } on MissingPluginException {
      resultado = null;
    }
    await AlmacenPermisos.marcarPedidos();
    if (!mounted) return;
    setState(() {
      _pidiendo = false;
      _resultado = resultado;
      _fallo = resultado == null;
    });
  }

  Future<void> _terminar() async {
    await AlmacenPermisos.marcarPedidos();
    if (!mounted) return;
    final alTerminar = widget.alTerminar;
    if (alTerminar != null) {
      alTerminar();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultado;
    final tipos = r?.tipos;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: AppHeader(showBackButton: !_enArranque),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.azulBruma,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.heart_fill,
                        size: 30,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Conecta +Vida con Salud',
                      style: AppTheme.display(
                        28,
                      ).copyWith(color: AppColors.textPrimary, height: 1.1),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tus puntos salen de lo que te mueves. Para contarlo, '
                      'necesitamos leer tres cosas de la app Salud de tu '
                      'iPhone.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Una lista es una lista: renglones separados por una
                    // línea de un pelo, sin una caja por cada uno.
                    _Dato(
                      icono: Icons.directions_walk_rounded,
                      titulo: 'Pasos',
                      paraQue:
                          'Necesitamos ver tus pasos para calcular tus '
                          'puntos de cada día.',
                      visible: tipos?.pasos,
                    ),
                    const _Separador(),
                    _Dato(
                      icono: CupertinoIcons.heart,
                      titulo: 'Ritmo cardíaco',
                      paraQue:
                          'Con tu ritmo cardíaco sabemos cuándo entrenaste '
                          'fuerte, y eso te da más puntos.',
                      visible: tipos?.ritmoCardiaco,
                    ),
                    const _Separador(),
                    _Dato(
                      icono: Icons.timer_outlined,
                      titulo: 'Entrenamientos',
                      paraQue:
                          'Cuentan para los minutos de tus objetivos de la '
                          'semana.',
                      visible: tipos?.entrenamientos,
                    ),
                    const SizedBox(height: 24),
                    if (_fallo)
                      const _Aviso(
                        alerta: true,
                        titulo: 'No pudimos conectar con Salud',
                        texto: 'Intenta de nuevo en un momento.',
                      )
                    else if (r != null)
                      _avisoDe(r)
                    else
                      const _Privacidad(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: _botones(),
            ),
          ],
        ),
      ),
    );
  }

  /// Qué decir después del diálogo de iOS.
  Widget _avisoDe(ResultadoPermisos r) {
    final t = r.tipos;
    switch (r.estado) {
      case EstadoPermisos.concedido:
        final faltan = [
          if (!t.ritmoCardiaco) 'ritmo cardíaco',
          if (!t.entrenamientos) 'entrenamientos',
        ];
        if (faltan.isEmpty) {
          return const _Aviso(
            titulo: '¡Listo! Ya vemos tus datos',
            texto:
                'Desde hoy tus pasos y tus entrenamientos suman puntos '
                'solos. No tienes que hacer nada más.',
          );
        }
        // Sin reloj es lo normal, no un error: se dice así, y el camino a
        // Ajustes va solo para quien SÍ usa uno.
        return _Aviso(
          titulo: 'Ya vemos tus pasos',
          texto:
              'No vemos datos de ${faltan.join(' ni de ')}. Casi siempre es '
              'porque no usas reloj, y está bien: tus pasos suman puntos '
              'igual. Si sí usas un reloj, revisa que +Vida tenga permiso '
              'en $_rutaAjustes.',
        );
      case EstadoPermisos.sinDatosVisibles:
        return const _Aviso(
          alerta: true,
          titulo: 'Todavía no vemos tus pasos',
          texto:
              'Sin tus pasos no podemos darte puntos. Si no diste el '
              'acceso, actívalo en $_rutaAjustes y vuelve a revisar.',
        );
      case EstadoPermisos.noDisponible:
        return const _Aviso(
          alerta: true,
          titulo: 'Este dispositivo no tiene Salud',
          texto:
              '+Vida lee tu actividad de la app Salud del iPhone. Ábrela '
              'desde tu iPhone para empezar a sumar puntos.',
        );
      case EstadoPermisos.desconocido:
        return const _Aviso(
          alerta: true,
          titulo: 'No pudimos revisar tus datos',
          texto: 'Intenta de nuevo en un momento.',
        );
    }
  }

  Widget _botones() {
    final r = _resultado;

    // Antes de preguntar, o después de un fallo: el botón pide.
    if (r == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Principal(
            texto: _fallo ? 'Intentar de nuevo' : 'Permitir acceso a Salud',
            cargando: _pidiendo,
            onPressed: _pedir,
          ),
          if (_enArranque || _fallo)
            CupertinoButton(
              onPressed: _pidiendo ? null : _terminar,
              child: Text(_enArranque ? 'Ahora no' : 'Volver'),
            ),
        ],
      );
    }

    // Sin pasos vale la pena revisar otra vez: el usuario puede ir a
    // Ajustes, volver y tocar acá sin salir de la pantalla.
    if (r.estado == EstadoPermisos.sinDatosVisibles ||
        r.estado == EstadoPermisos.desconocido) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Principal(
            texto: 'Volver a revisar',
            cargando: _pidiendo,
            onPressed: _pedir,
          ),
          CupertinoButton(
            onPressed: _pidiendo ? null : _terminar,
            child: Text(_enArranque ? 'Seguir sin conectar' : 'Volver'),
          ),
        ],
      );
    }

    return _Principal(
      texto: _enArranque ? 'Empezar' : 'Listo',
      onPressed: _terminar,
    );
  }
}

/// El botón azul de abajo, a todo el ancho.
class _Principal extends StatelessWidget {
  const _Principal({
    required this.texto,
    required this.onPressed,
    this.cargando = false,
  });

  final String texto;
  final VoidCallback onPressed;
  final bool cargando;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: CupertinoButton.filled(
      key: llaveBotonPermisos,
      borderRadius: BorderRadius.circular(AppRadios.pildora),
      onPressed: cargando ? null : onPressed,
      child: cargando
          ? const CupertinoActivityIndicator(color: Colors.white)
          : Text(texto),
    ),
  );
}

/// Un dato que se lee, con para qué sirve. Después del diálogo lleva a la
/// derecha si lo vemos o no.
class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.titulo,
    required this.paraQue,
    required this.visible,
  });

  final IconData icono;
  final String titulo;
  final String paraQue;

  /// Null antes de preguntar: todavía no hay nada que decir.
  final bool? visible;

  @override
  Widget build(BuildContext context) {
    final v = visible;
    return Semantics(
      label:
          '$titulo. $paraQue'
          '${v == null
              ? ''
              : v
              ? ' Lo vemos.'
              : ' Sin datos todavía.'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.azulBruma,
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 19, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    paraQue,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (v != null) ...[
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: v
                    // El check suelto de una etapa cumplida: uno de los
                    // cuatro usos del naranja.
                    ? const Icon(
                        Icons.check_rounded,
                        size: 22,
                        color: AppColors.accentSecondary,
                      )
                    : Text(
                        'Sin datos',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => Container(
    height: 0.5,
    margin: const EdgeInsets.only(left: 52),
    color: AppColors.separador,
  );
}

/// Lo que se promete antes de pedir: que solo leemos, y qué le llega a
/// la aseguradora. Lo segundo tiene que decir la verdad (CLAUDE.md): le
/// llega un resumen por persona y por día, nunca el dato crudo, y solo
/// con el consentimiento aparte.
class _Privacidad extends StatelessWidget {
  const _Privacidad();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Icon(CupertinoIcons.lock, size: 16, color: AppColors.azulMedio),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'Solo leemos: +Vida nunca escribe ni borra nada en Salud. A tu '
          'aseguradora solo le llega un resumen de cada día, y solo si lo '
          'autorizas aparte. Nunca el detalle minuto a minuto.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ),
    ],
  );
}

/// El resultado, en dos renglones: qué pasó y qué hacer.
class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.titulo,
    required this.texto,
    this.alerta = false,
  });

  final String titulo;
  final String texto;

  /// Algo que el usuario tiene que atender: lleva el ícono en naranja,
  /// que es el color de las alertas reales.
  final bool alerta;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.azulNiebla,
      borderRadius: BorderRadius.circular(AppRadios.tarjeta),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          alerta
              ? CupertinoIcons.exclamationmark_circle
              : CupertinoIcons.checkmark_seal,
          size: 22,
          color: alerta ? AppColors.accentSecondary : AppColors.accent,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                texto,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
