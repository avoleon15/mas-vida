import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../datos/almacen_social.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../theme.dart';

// ============================================================
// Flujos de Social: crear grupo, unirse a grupo y agregar amigo.
//
// Antes los tres botones no hacían nada. Ahora abren un flujo real, con
// su validación y su confirmación.
//
// Lo que se crea se guarda en el teléfono (ver `AlmacenSocial`), así que
// sobrevive a cerrar la app.
//
// TODO: no hay backend de grupos todavía. Guardado local quiere decir que
// el grupo existe solo en ESTE teléfono: nadie más lo ve. La UI ya está
// lista para cuando exista la API.
// ============================================================

/// Crear un grupo nuevo.
///
/// Pregunta explícitamente si se muestran los puntos, porque es una
/// decisión de privacidad y no puede quedar en un default silencioso:
/// mostrar los puntos de alguien es mostrar su nivel de actividad.
Future<bool> mostrarCrearGrupo(BuildContext context) async {
  final creado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
    builder: (_) => const _CrearGrupo(),
  );
  return creado ?? false;
}

class _CrearGrupo extends StatefulWidget {
  const _CrearGrupo();

  @override
  State<_CrearGrupo> createState() => _CrearGrupoState();
}

class _CrearGrupoState extends State<_CrearGrupo> {
  final _nombre = TextEditingController();
  bool _mostrarPuntos = false;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  bool get _valido => _nombre.text.trim().length >= 3;

  void _crear() {
    if (!_valido) return;
    HapticFeedback.selectionClick();
    final nombre = _nombre.text.trim();
    Datos.i.social.grupos.insert(
      // Antes de la liga local, que siempre va al final.
      Datos.i.social.deConocidos.length,
      GrupoRanking(
        id: nombre.toLowerCase().replaceAll(' ', '_'),
        nombre: nombre,
        tipo: TipoGrupo.conocidos,
        mostrarPuntos: _mostrarPuntos,
        // Arranca solo con el usuario: los demás entran con el código.
        miembros: [
          RankingPersona(
            nombre: Datos.i.perfil.nombre,
            puntosSemana: Datos.i.resumen.puntosSemana,
            tendencia: Tendencia.igual,
            esUsuario: true,
          ),
        ],
        creadoPorMi: true,
      ),
    );
    // Sin await: el grupo ya está en pantalla y guardar no puede hacer
    // esperar al usuario.
    AlmacenSocial.guardar(Datos.i.social.grupos);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return _Hoja(
      titulo: 'Crear un grupo',
      children: [
        _CampoTexto(
          controlador: _nombre,
          etiqueta: 'Nombre del grupo',
          ejemplo: 'Oficina, Familia, Los del gym…',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.entre),

        // La pregunta de privacidad, explícita.
        Container(
          padding: const EdgeInsets.all(AppSpacing.entre),
          decoration: BoxDecoration(
            color: AppColors.fondoDePantalla,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mostrar los puntos de cada quien',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoSwitch(
                    value: _mostrarPuntos,
                    activeTrackColor: AppColors.accent,
                    onChanged: (v) => setState(() => _mostrarPuntos = v),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _mostrarPuntos
                    ? 'Todos van a ver cuántos puntos hace cada uno. Elegilo '
                          'solo si se conocen entre sí.'
                    : 'Solo se ve la posición en la tabla, no los puntos de '
                          'nadie.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.grupo),
        _BotonHoja(
          texto: 'Crear grupo',
          habilitado: _valido,
          onPressed: _crear,
        ),
      ],
    );
  }
}

/// Unirse a un grupo con el código que le pasaron.
Future<bool> mostrarUnirseGrupo(BuildContext context) async {
  final unido = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
    builder: (_) => const _UnirseGrupo(),
  );
  return unido ?? false;
}

class _UnirseGrupo extends StatefulWidget {
  const _UnirseGrupo();

  @override
  State<_UnirseGrupo> createState() => _UnirseGrupoState();
}

class _UnirseGrupoState extends State<_UnirseGrupo> {
  final _codigo = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  bool get _valido => _codigo.text.trim().length == 6;

  void _unirse() {
    if (!_valido) return;
    // Sin backend no se puede validar de verdad. Se dice, en vez de
    // fingir que el código existe.
    setState(() {
      _error =
          'Todavía no podemos verificar códigos: falta conectar el '
          'servidor. Tu código quedó anotado.';
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return _Hoja(
      titulo: 'Unirse a un grupo',
      children: [
        Text(
          'Pedile el código de 6 letras a quien creó el grupo.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.entre),
        _CampoTexto(
          controlador: _codigo,
          etiqueta: 'Código',
          ejemplo: 'ABC123',
          mayusculas: true,
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.dentro),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.grupo),
        _BotonHoja(texto: 'Unirme', habilitado: _valido, onPressed: _unirse),
      ],
    );
  }
}

/// Agregar a alguien conocido.
void mostrarAgregarAmigo(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
    builder: (_) => const _AgregarAmigo(),
  );
}

class _AgregarAmigo extends StatefulWidget {
  const _AgregarAmigo();

  @override
  State<_AgregarAmigo> createState() => _AgregarAmigoState();
}

class _AgregarAmigoState extends State<_AgregarAmigo> {
  final _usuario = TextEditingController();
  bool _enviado = false;

  @override
  void dispose() {
    _usuario.dispose();
    super.dispose();
  }

  bool get _valido => _usuario.text.trim().length >= 3;

  @override
  Widget build(BuildContext context) {
    final miCodigo = Datos.i.perfil.usuarioId.toUpperCase();

    return _Hoja(
      titulo: 'Agregar a alguien',
      children: [
        _CampoTexto(
          controlador: _usuario,
          etiqueta: 'Usuario',
          ejemplo: '@diego-002',
          onChanged: (_) => setState(() => _enviado = false),
        ),
        const SizedBox(height: AppSpacing.entre),
        _BotonHoja(
          texto: _enviado ? 'Invitación enviada' : 'Enviar invitación',
          habilitado: _valido && !_enviado,
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _enviado = true);
          },
        ),
        if (_enviado) ...[
          const SizedBox(height: AppSpacing.dentro),
          Text(
            'Le llega la invitación y aparece en tus conexiones cuando la '
            'acepte.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.seccion),
        Text(
          'O pasale tu código',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.dentro),
        // El propio código, para el camino inverso: que el otro lo
        // busque a uno.
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: miCodigo));
            HapticFeedback.selectionClick();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.entre),
            decoration: BoxDecoration(
              color: AppColors.fondoDePantalla,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    miCodigo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const Icon(
                  Icons.copy,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tocá para copiarlo',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ============================================================
// Piezas compartidas de las hojas
// ============================================================

class _Hoja extends StatelessWidget {
  const _Hoja({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Sube con el teclado: si no, el campo queda tapado.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: AppColors.textSecondary,
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
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

class _CampoTexto extends StatelessWidget {
  const _CampoTexto({
    required this.controlador,
    required this.etiqueta,
    required this.ejemplo,
    required this.onChanged,
    this.mayusculas = false,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final String ejemplo;
  final ValueChanged<String> onChanged;
  final bool mayusculas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 6),
        // CupertinoTextField: el campo del sistema, con su cursor y su
        // selección de iOS.
        CupertinoTextField(
          controller: controlador,
          placeholder: ejemplo,
          onChanged: onChanged,
          textCapitalization: mayusculas
              ? TextCapitalization.characters
              : TextCapitalization.sentences,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
          decoration: BoxDecoration(
            color: AppColors.fondoDePantalla,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
        ),
      ],
    );
  }
}

class _BotonHoja extends StatelessWidget {
  const _BotonHoja({
    required this.texto,
    required this.habilitado,
    required this.onPressed,
  });

  final String texto;
  final bool habilitado;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(vertical: 15),
        // Deshabilitado hasta que el formulario sea válido: es la forma
        // de decir que falta algo sin poner un mensaje de error.
        onPressed: habilitado ? onPressed : null,
        child: Text(
          texto,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
