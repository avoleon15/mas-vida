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
  mostrarHojaVida<void>(
    context,
    hoja: (_) => _HojaObjetivo(objetivo: objetivo, semana: semana),
  );
}

/// Cómo se cuenta cada objetivo, en una frase. Uno que no se conoce no
/// dice nada: mejor callar que explicar una regla inventada.
String? _comoSeCuenta(ObjetivoSemanal o) => switch (o.id) {
  'pasos_semana' =>
    'Todos tus pasos de lunes a domingo en la app Salud. Con iPhone y '
        'reloj se toma uno solo, nunca los dos.',
  'workouts_semana' =>
    'Cada entrenamiento que registra tu reloj en la app Salud, de lunes a '
        'domingo, dure lo que dure. Los que escribes a mano no cuentan.',
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
    // Cada objetivo paga lo suyo (reunión del 2 de octubre de 2026). Uno
    // que no se cumplió en una semana cerrada ya no paga nada.
    final paga =
        objetivo.monedas > 0 &&
        !(semana.estado == EstadoSemana.cerrada && !objetivo.completo);

    // SIN SCROLL (pedido de Daniel, 2 de octubre de 2026): todo entra
    // de una, también en un iPhone SE. Por eso el número va con su meta
    // en el mismo renglón y las dos explicaciones viven juntas en un
    // panel, con una frase cada una.
    return HojaVida(
      key: llaveDetalleObjetivo,
      relleno: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.azulBruma,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconoDeObjetivo(objetivo.id),
                  size: 20,
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
                      style: AppTheme.display(
                        20,
                      ).copyWith(color: AppColors.textPrimary, height: 1.1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Semana ${semana.numero} · ${plazoCorto(semana)}',
                      style: apoyo?.copyWith(fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // El avance en grande, con su meta al lado.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _conMiles(grande),
                        style: AppTheme.display(44).copyWith(
                          color: _futura
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          height: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
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
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(switch (meta) {
                  null => _unidadCorta(objetivo.unidad, objetivo.progreso),
                  _ when _futura =>
                    '${_unidadCorta(objetivo.unidad, meta)} de meta',
                  _ =>
                    'de ${_conMiles(meta)} '
                        '${_unidadCorta(objetivo.unidad, meta)}',
                }, style: apoyo),
              ),
            ],
          ),
          if (meta != null) ...[
            const SizedBox(height: 12),
            SizedBox(height: 10, child: _Barra(lleno: lleno, alto: 10)),
          ],
          const SizedBox(height: 12),
          Text(
            _estado(),
            style: tema.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          // Las dos explicaciones, juntas en un panel plano.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.azulNiebla,
              borderRadius: BorderRadius.circular(AppRadios.tarjeta),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (como != null) ...[
                  _Explicacion(
                    icono: CupertinoIcons.heart_fill,
                    titulo: 'Cómo se cuenta',
                    texto: como,
                  ),
                  const SizedBox(height: 12),
                ],
                const _Explicacion(
                  icono: CupertinoIcons.lock_fill,
                  titulo: 'Cuándo se cierra',
                  texto:
                      'El domingo a las $horaDeCierre se cierra sola con '
                      'tus datos de la app Salud. No tienes que marcar nada.',
                ),
              ],
            ),
          ),
          if (paga) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    semana.estado == EstadoSemana.cerrada
                        ? 'Cumpliste este objetivo'
                        : 'Si cumples este objetivo',
                    style: subtitulo,
                  ),
                ),
                _Premio(
                  monedas: objetivo.monedas,
                  cobrado: semana.estado == EstadoSemana.cerrada,
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
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
    );
  }
}

/// Una explicación del detalle: el ícono, el título y una frase.
class _Explicacion extends StatelessWidget {
  const _Explicacion({
    required this.icono,
    required this.titulo,
    required this.texto,
  });

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icono, size: 16, color: AppColors.azulMedio),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: tema.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                texto,
                style: tema.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
