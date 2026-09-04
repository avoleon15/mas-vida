import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import '../datos/fuente_datos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';

// ============================================================
// PERFIL Y CONFIGURACIÓN.
//
// Se llega tocando el avatar del encabezado, desde cualquier pantalla.
//
// REGLA DURA — los datos de la póliza son de SOLO LECTURA. La prima, la
// suma asegurada y la edad vienen de la aseguradora y no se editan desde
// acá:
//
//   - La PRIMA es la base del cashback. Si el usuario la pudiera cambiar,
//     estaría subiendo su propio reembolso.
//   - La EDAD mueve la FCmáx y el bonus 60+, o sea los puntos. CLAUDE.md
//     la marca explícitamente como vector de fraude si es autodeclarada.
//
// Lo que sí puede hacer el usuario es PEDIR una corrección, que la
// resuelve la aseguradora.
// ============================================================

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  // Preferencias locales. Hoy viven solo en memoria: no hay backend de
  // preferencias todavía y no se inventa persistencia.
  bool _recordatorioDiario = true;
  bool _avisoRacha = true;
  bool _compartirConAseguradora = true;

  @override
  Widget build(BuildContext context) {
    final perfil = Datos.i.perfil;
    final poliza = perfil.poliza;

    // Mismo encabezado que el resto de la app en vez de un SliverAppBar.
    //
    // El SliverAppBar arrancaba pegado al borde de arriba y la isla
    // dinámica del iPhone le tapaba el título y la flecha de volver.
    // AppHeader ya tiene resuelto ese espacio y trae el botón de volver.
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: AppHeader(showBackButton: true),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Perfil', style: AppTheme.sectionTitle),
                    const SizedBox(height: 20),
                    _Cabecera(
                      nombre: perfil.nombre,
                      usuario: perfil.usuarioId,
                      onCambiarFoto: () => _elegirFoto(context),
                    ),
                    const SizedBox(height: AppSpacing.seccion),

                    const _Etiqueta('TU PÓLIZA'),
                    const SizedBox(height: AppSpacing.dentro),
                    _Tarjeta(
                      children: [
                        _Fila(titulo: 'Número', valor: poliza.numero),
                        const _Separador(),
                        _Fila(titulo: 'Plan', valor: poliza.tipoPlan),
                        const _Separador(),
                        // La prima destacada: es de donde sale el cashback,
                        // así que es el dato que el usuario viene a buscar.
                        _Fila(
                          titulo: 'Prima anual',
                          valor: poliza.primaAnual,
                          destacado: true,
                        ),
                        const _Separador(),
                        _Fila(titulo: 'Forma de pago', valor: poliza.formaPago),
                        const _Separador(),
                        _Fila(titulo: 'Vigencia', valor: poliza.vigencia),
                        const _Separador(),
                        _Fila(
                          titulo: 'Renovación',
                          valor: poliza.fechaRenovacion,
                        ),
                        const _Separador(),
                        _Fila(titulo: 'Estado', valor: poliza.estado),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.dentro),
                    _NotaSoloLectura(
                      onPedirCorreccion: () => _pedirCorreccion(context),
                    ),
                    const SizedBox(height: AppSpacing.seccion),

                    const _Etiqueta('COBERTURA'),
                    const SizedBox(height: AppSpacing.dentro),
                    _Tarjeta(
                      children: [
                        _Fila(
                          titulo: 'Suma asegurada',
                          valor: poliza.sumaAsegurada,
                        ),
                        const _Separador(),
                        _Fila(titulo: 'Deducible', valor: poliza.deducible),
                        const _Separador(),
                        _Fila(titulo: 'Coaseguro', valor: poliza.coaseguro),
                        const _Separador(),
                        _Fila(titulo: 'Red', valor: poliza.redCobertura),
                        const _Separador(),
                        _Fila(
                          titulo: 'Titular y dependientes',
                          valor: poliza.titularYDependientes,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.seccion),

                    const _Etiqueta('TUS DATOS DE SALUD'),
                    const SizedBox(height: AppSpacing.dentro),
                    _Tarjeta(
                      children: [
                        _Fila(
                          titulo: 'Edad',
                          valor: '${perfil.edad} años',
                          // Viene de la póliza. Se dice para que no parezca
                          // un campo que el usuario olvidó llenar.
                          nota: 'La toma de tu póliza, no la podés cambiar acá',
                        ),
                        const _Separador(),
                        _Fila(
                          titulo: 'Apple Salud',
                          valor: _textoPermiso(perfil.permisoHealthkit),
                          nota: 'Pasos, ritmo cardíaco y entrenamientos',
                        ),
                        const _Separador(),
                        _Fila(
                          titulo: 'Zona horaria',
                          valor: perfil.zonaHoraria,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.seccion),

                    const _Etiqueta('AVISOS'),
                    const SizedBox(height: AppSpacing.dentro),
                    _Tarjeta(
                      children: [
                        _FilaSwitch(
                          titulo: 'Recordatorio diario',
                          nota:
                              'Un aviso si te falta poco para tus puntos '
                              'del día',
                          valor: _recordatorioDiario,
                          onChanged: (v) =>
                              setState(() => _recordatorioDiario = v),
                        ),
                        const _Separador(),
                        _FilaSwitch(
                          titulo: 'Racha en riesgo',
                          nota:
                              'Te avisamos el domingo si tu racha está por '
                              'cortarse',
                          valor: _avisoRacha,
                          onChanged: (v) => setState(() => _avisoRacha = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.seccion),

                    const _Etiqueta('PRIVACIDAD'),
                    const SizedBox(height: AppSpacing.dentro),
                    _ConsentimientoAseguradora(
                      valor: _compartirConAseguradora,
                      onChanged: (v) =>
                          setState(() => _compartirConAseguradora = v),
                    ),
                    const SizedBox(height: AppSpacing.seccion),

                    _BotonPeligro(
                      texto: 'Cerrar sesión',
                      onPressed: () => _cerrarSesion(context),
                    ),
                    const SizedBox(height: AppSpacing.entre),
                    Center(
                      child: Text(
                        '+Vida · versión de prueba',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _textoPermiso(String permiso) => switch (permiso) {
    'concedido' => 'Conectado',
    'denegado' => 'Sin permiso',
    _ => permiso,
  };

  /// Hoja de acciones nativa de iOS para cambiar la foto.
  void _elegirFoto(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Foto de perfil'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tomar una foto'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Elegir de la galería'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  /// Los datos de la póliza los corrige la aseguradora, no la app.
  void _pedirCorreccion(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Pedir una corrección'),
        content: const Text(
          '\nLos datos de tu póliza los administra tu aseguradora, así que '
          'no se editan desde la app.\n\n'
          'Si algo no coincide, escribinos y lo gestionamos con ellos.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Escribir'),
          ),
        ],
      ),
    );
  }

  void _cerrarSesion(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          '\nTus puntos y monedas quedan guardados. Al volver a entrar '
          'están donde los dejaste.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

/// Foto, nombre y usuario.
class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.nombre,
    required this.usuario,
    required this.onCambiarFoto,
  });

  final String nombre;
  final String usuario;
  final VoidCallback onCambiarFoto;

  @override
  Widget build(BuildContext context) {
    // SizedBox de ancho completo: la Column de la pantalla alinea a la
    // izquierda, así que sin esto la cabecera se encoge al ancho del
    // nombre y queda pegada al borde en vez de centrada.
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onCambiarFoto,
            child: Stack(
              children: [
                const GFAvatar(
                  size: 46,
                  shape: GFAvatarShape.circle,
                  backgroundColor: AppColors.cardBorder,
                  child: Icon(
                    Icons.person,
                    size: 46,
                    color: AppColors.textSecondary,
                  ),
                ),
                // La marca de cámara dice que la foto se puede cambiar sin
                // necesitar un texto que lo explique.
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.card, width: 2),
                    ),
                    child: const Icon(
                      Icons.photo_camera,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.entre),
          Text(
            nombre,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '@$usuario',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Aviso de que la póliza no se edita desde la app, con la salida para el
/// usuario que necesita corregir algo.
class _NotaSoloLectura extends StatelessWidget {
  const _NotaSoloLectura({required this.onPedirCorreccion});

  final VoidCallback onPedirCorreccion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.dentro),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estos datos los administra tu aseguradora y no se editan '
                  'desde la app.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: onPedirCorreccion,
                  child: Text(
                    'Pedir una corrección',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
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

/// Consentimiento para compartir datos con la aseguradora.
///
/// Dice exactamente qué se comparte y qué no. El límite duro del producto
/// es que a la aseguradora NUNCA le llega nada individual de HealthKit:
/// solo agregados de cohorte. Y es revocable.
class _ConsentimientoAseguradora extends StatelessWidget {
  const _ConsentimientoAseguradora({
    required this.valor,
    required this.onChanged,
  });

  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final estiloNota = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );

    return _Tarjeta(
      children: [
        _FilaSwitch(
          titulo: 'Compartir mi actividad con la aseguradora',
          nota: 'Podés desactivarlo cuando quieras',
          valor: valor,
          onChanged: onChanged,
        ),
        const _Separador(),
        Text(
          'Qué se comparte',
          style: estiloNota?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tu nivel de cashback y si tu actividad sube o baja, siempre '
          'mezclado con la de otros asegurados.',
          style: estiloNota,
        ),
        const SizedBox(height: AppSpacing.dentro),
        Text(
          'Qué NO se comparte nunca',
          style: estiloNota?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tus pasos de cada día, tu ritmo cardíaco, tu ubicación, ni nada '
          'que te identifique.',
          style: estiloNota,
        ),
      ],
    );
  }
}

// ============================================================
// Piezas compartidas
// ============================================================

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.4,
    ),
  );
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.titulo,
    required this.valor,
    this.nota,
    this.destacado = false,
  });

  final String titulo;
  final String valor;
  final String? nota;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (nota != null)
                Text(
                  nota!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.dentro),
        Flexible(
          child: Text(
            valor,
            textAlign: TextAlign.right,
            style:
                (destacado
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.bodyMedium)
                    ?.copyWith(
                      color: destacado
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontWeight: destacado ? FontWeight.w800 : FontWeight.w500,
                    ),
          ),
        ),
      ],
    );
  }
}

class _FilaSwitch extends StatelessWidget {
  const _FilaSwitch({
    required this.titulo,
    required this.nota,
    required this.valor,
    required this.onChanged,
  });

  final String titulo;
  final String nota;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                nota,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.dentro),
        // CupertinoSwitch: el interruptor del sistema, no una imitación.
        CupertinoSwitch(
          value: valor,
          activeTrackColor: AppColors.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: AppColors.cardBorder),
  );
}

/// Acción destructiva. Va en rojo y confirma antes de ejecutarse.
class _BotonPeligro extends StatelessWidget {
  const _BotonPeligro({required this.texto, required this.onPressed});

  final String texto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(vertical: 14),
        onPressed: onPressed,
        child: Text(
          texto,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: const Color(0xFFB3261E),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
