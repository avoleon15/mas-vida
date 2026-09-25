part of 'tarjeta_semana.dart';

// ============================================================
// EL DETALLE DE UN OBJETIVO.
//
// Se abre al tocar uno de los dos objetivos de la semana (pedido de
// Daniel, 24 de septiembre de 2026): un número grande invita a tocarlo,
// y lo que la persona quiere saber al tocarlo son tres cosas —cuánto
// lleva, cómo se cuenta y cuándo se cierra—.
//
// Es una hoja de INFORMACIÓN. No hay nada que marcar: el objetivo lo
// cierra el servidor el domingo 23:59 con los datos de Apple Health, y
// la hoja lo dice con todas las letras para que nadie busque la casilla.
// ============================================================

/// Llave de la hoja de detalle, para los tests.
const Key llaveDetalleObjetivo = ValueKey('detalle-objetivo');

/// Abre el detalle de [objetivo] en una hoja que sube desde abajo.
void mostrarDetalleObjetivo(
  BuildContext context, {
  required ObjetivoSemanal objetivo,
  required SemanaObjetivos semana,
}) {
  HapticFeedback.selectionClick();
  showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => _HojaObjetivo(objetivo: objetivo, semana: semana),
  );
}

/// Cómo se cuenta cada objetivo, en una frase. Uno que no se conoce no
/// dice nada: mejor callar que explicar una regla inventada.
String? _comoSeCuenta(ObjetivoSemanal o) => switch (o.id) {
  'pasos_semana' =>
    'Cuentan todos los pasos que registra la app Salud de lunes a '
        'domingo, del iPhone o del reloj. Si llevas los dos, se toma uno '
        'solo para no contarlos doble.',
  'minutos_entrenamiento' =>
    'Cuentan los minutos de los entrenamientos que registra la app Salud '
        'de lunes a domingo, con tu reloj o con una app de ejercicio.',
  _ => null,
};

class _HojaObjetivo extends StatelessWidget {
  const _HojaObjetivo({required this.objetivo, required this.semana});

  final ObjetivoSemanal objetivo;
  final SemanaObjetivos semana;

  bool get _futura => semana.estado == EstadoSemana.futura;

  /// Cómo va, en una frase. En cantidades, nunca en porcentaje.
  String _estado() {
    final meta = objetivo.meta;
    if (objetivo.completo) {
      return '¡Lo lograste! Este objetivo ya está cumplido.';
    }
    if (_futura) return 'Esta semana todavía no empieza.';
    if (semana.estado == EstadoSemana.cerrada) {
      return 'Esta vez no se llegó a la meta.';
    }
    if (meta == null) return 'Sigue sumando: cada día cuenta.';
    if (objetivo.progreso >= meta) {
      return 'Llegaste a la meta. Se confirma al cerrar la semana.';
    }
    final resta = meta - objetivo.progreso;
    return '${_conMiles(resta)} ${_unidadCorta(objetivo.unidad, resta)} más '
        'y lo cumples.';
  }

  @override
  Widget build(BuildContext context) {
    final meta = objetivo.meta;
    final tema = Theme.of(context).textTheme;
    final apoyo = tema.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );
    final subtitulo = tema.titleSmall?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    );
    final grande = _futura && meta != null ? meta : objetivo.progreso;
    final lleno = objetivo.completo
        ? 1.0
        : (_futura || meta == null || meta == 0)
        ? 0.0
        : (objetivo.progreso / meta).clamp(0.0, 1.0);
    final como = _comoSeCuenta(objetivo);
    final paga =
        semana.monedas > 0 &&
        !(semana.estado == EstadoSemana.cerrada && !semana.cumplida);

    return Container(
      key: llaveDetalleObjetivo,
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Barrita de arrastre: la hoja se cierra empujándola.
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.azulBruma,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconoDe(objetivo.id),
                        size: 22,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            objetivo.nombre,
                            style: AppTheme.display(22).copyWith(
                              color: AppColors.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Semana ${semana.numero} · ${plazoCorto(semana)}',
                            style: apoyo?.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // El avance, en grande.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _conMiles(grande),
                          style: AppTheme.display(48).copyWith(
                            color: _futura
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            height: 1,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    if (objetivo.completo) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_rounded,
                        size: 30,
                        color: AppColors.accentSecondary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(switch (meta) {
                  null => _unidadCorta(objetivo.unidad, objetivo.progreso),
                  _ when _futura =>
                    '${_unidadCorta(objetivo.unidad, meta)} de meta',
                  _ =>
                    'de ${_conMiles(meta)} '
                        '${_unidadCorta(objetivo.unidad, meta)}',
                }, style: apoyo),
                if (meta != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(height: 10, child: _Barra(lleno: lleno, alto: 10)),
                ],
                const SizedBox(height: 14),
                Text(
                  _estado(),
                  style: tema.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (como != null) ...[
                  const SizedBox(height: 28),
                  Text('Cómo se cuenta', style: subtitulo),
                  const SizedBox(height: 6),
                  Text(como, style: apoyo),
                ],
                const SizedBox(height: 22),
                Text('Cuándo se cierra', style: subtitulo),
                const SizedBox(height: 6),
                Text(
                  'El domingo a medianoche la semana se cierra sola con tus '
                  'datos de la app Salud. No tienes que marcar nada.',
                  style: apoyo,
                ),
                if (paga) ...[
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          semana.estado == EstadoSemana.cerrada
                              ? 'Cumpliste los dos objetivos'
                              : 'Si cumples los dos objetivos',
                          style: subtitulo,
                        ),
                      ),
                      _Premio(
                        monedas: semana.monedas,
                        cobrado: semana.estado == EstadoSemana.cerrada,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(AppRadios.pildora),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Entendido'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
