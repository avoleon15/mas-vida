import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../datos/almacen_social.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../theme.dart';

// ============================================================
// Flujos de Social: crear una competencia y unirse a una.
//
// Antes los botones no hacían nada. Ahora abren un flujo real, con
// su validación y su confirmación.
//
// Lo que se crea se guarda en el teléfono (ver `AlmacenSocial`), así que
// sobrevive a cerrar la app.
//
// TODO: no hay backend de grupos todavía. Guardado local quiere decir que
// el grupo existe solo en ESTE teléfono: nadie más lo ve. La UI ya está
// lista para cuando exista la API.
// ============================================================

/// Cuánto dura una competencia entre conocidos: UN MES, siempre.
///
/// No es configurable a propósito (decisión de Daniel, revisión de UI del
/// 9 de septiembre de 2026). Antes el usuario elegía 1, 2 o 3 meses: era
/// una pregunta que nadie necesitaba contestar y dejaba competencias de
/// duraciones distintas conviviendo en la misma pantalla.
const int mesesDeCompetencia = 1;

/// La fecha en que cierra una competencia que arranca hoy.
///
/// Suma un mes al calendario, no 30 días: tiene que caer el mismo día del
/// mes siguiente. Si ese día no existe en el mes destino (31 de enero + 1
/// mes), se corta al último día de ese mes en vez de irse a marzo.
///
/// Cuenta desde el día en que se crea y NO del 1 al último del mes: una
/// competencia que alguien arma un día 28 duraría dos días. El ciclo del
/// mes calendario es el de la liga local, que la arma la app.
DateTime cierreDeCompetencia({DateTime? desde}) {
  final hoy = desde ?? DateTime.now();
  final ultimoDelMes = DateTime(
    hoy.year,
    hoy.month + mesesDeCompetencia + 1,
    0,
  ).day;
  return DateTime(
    hoy.year,
    hoy.month + mesesDeCompetencia,
    hoy.day < ultimoDelMes ? hoy.day : ultimoDelMes,
  );
}

/// Crear una competencia nueva. Devuelve la competencia creada, o null si
/// el usuario se arrepintió.
///
/// Devuelve la competencia y no un "sí": lo siguiente que hace Social es
/// abrir la hoja para compartir SU código, sin que el usuario tenga que ir
/// a buscarla.
///
/// Pregunta explícitamente si se muestran los puntos, porque es una
/// decisión de privacidad y no puede quedar en un default silencioso:
/// mostrar los puntos de alguien es mostrar su nivel de actividad.
Future<GrupoRanking?> mostrarCrearGrupo(BuildContext context) =>
    showModalBottomSheet<GrupoRanking>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
      builder: (_) => const _CrearGrupo(),
    );

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
    final grupo = GrupoRanking(
      id: nombre.toLowerCase().replaceAll(' ', '_'),
      nombre: nombre,
      tipo: TipoGrupo.conocidos,
      mostrarPuntos: _mostrarPuntos,
      // Todo lo que arma el usuario corre por mes: es el default del
      // modelo y no hay pantalla que lo cambie.
      ciclo: CicloRanking.mes,
      arranca: DateTime.now(),
      cierra: cierreDeCompetencia(),
      // Arranca solo con el usuario: los demás entran con el código.
      miembros: [
        RankingPersona(
          nombre: Datos.i.perfil.nombre,
          // Los puntos del mes del usuario. Antes se cargaban los de la
          // semana, que era el ciclo equivocado.
          puntosPeriodo: Datos.i.resumen.puntosMes,
          tendencia: Tendencia.igual,
          esUsuario: true,
        ),
      ],
      creadoPorMi: true,
    );
    // Antes de La Liga, que siempre va al final.
    Datos.i.social.grupos.insert(Datos.i.social.deConocidos.length, grupo);
    // Sin await: el grupo ya está en pantalla y guardar no puede hacer
    // esperar al usuario.
    AlmacenSocial.guardar(Datos.i.social.grupos);
    Navigator.of(context).pop(grupo);
  }

  @override
  Widget build(BuildContext context) {
    return _Hoja(
      titulo: 'Crear una competencia',
      children: [
        _CampoTexto(
          controlador: _nombre,
          etiqueta: 'Nombre de la competencia',
          ejemplo: 'Oficina, Familia, Los del gym…',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.entre),

        const _CuantoDura(),
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
                    ? 'Todos van a ver cuántos puntos hace cada uno. '
                          'Elígelo solo si se conocen entre sí.'
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
          texto: 'Crear competencia',
          habilitado: _valido,
          onPressed: _crear,
        ),
      ],
    );
  }
}

/// Cuánto dura la competencia. Un mes, y no se elige.
///
/// Antes era un selector de 1, 2 o 3 meses. Se borró: la duración no es
/// una decisión que el usuario necesite tomar para armar un grupo con su
/// oficina, y tener competencias de duraciones distintas en la misma
/// lista hacía imposible decir "termina el 4" sin explicar cuál termina
/// cuándo. La de tres meses es la liga local, que la arma la app.
///
/// Queda como texto y no como control: informa, no pregunta. La fecha
/// exacta va igual, porque "un mes" sin día es una abstracción — el
/// usuario tiene que ver cuándo se define quién ganó.
class _CuantoDura extends StatelessWidget {
  const _CuantoDura();

  @override
  Widget build(BuildContext context) {
    final cierre = cierreDeCompetencia();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.entre),
      decoration: BoxDecoration(
        color: AppColors.azulNiebla,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.calendar,
            size: 18,
            color: AppColors.azulMedio,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dura un mes: termina el ${_fechaLarga(cierre)}.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _meses = [
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

  static String _fechaLarga(DateTime d) => '${d.day} de ${_meses[d.month - 1]}';
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
      titulo: 'Unirse a una competencia',
      children: [
        Text(
          'Pídele el código de 6 letras a quien creó la competencia. '
          'No hace falta ser su amigo en la app: con el código entras.',
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
