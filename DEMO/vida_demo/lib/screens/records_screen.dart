import 'package:flutter/material.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../rachas_recompensas.dart';
import '../reglas_puntos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';

// ============================================================
// RÉCORDS PERSONALES.
//
// Todo lo que la app tiene registrado del usuario, en un solo lugar.
//
// Los récords se calculan acá sobre el historial que ya está en memoria:
// son lecturas de datos existentes, no reglas de negocio nuevas. Si
// algún día el backend los manda resueltos, esta pantalla los muestra sin
// cambiar de forma.
//
// Regla dura respetada: los PUNTOS y las MONEDAS nunca se mezclan. Van en
// bloques distintos y cada uno dice cuál es cuál.
// ============================================================

/// Un récord: un titular grande con su contexto.
class _Record {
  const _Record({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.unidad,
    required this.detalle,
  });

  final IconData icono;
  final String titulo;
  final String valor;
  final String unidad;

  /// Cuándo se logró, o por qué todavía no hay nada.
  final String detalle;
}

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  static String _miles(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );

  static String _fecha(DateTime f) => '${f.day} de ${_meses[f.month - 1]}';

  /// Días con dato real. Un día sin permiso de HealthKit no es un día de
  /// cero pasos: no puede competir por un récord ni ensuciar un promedio.
  static List<DiaActividad> get _conDatos =>
      Datos.i.historial.dias.where((d) => d.pasos != null).toList();

  @override
  Widget build(BuildContext context) {
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
                    Text('Tus récords', style: AppTheme.sectionTitle),
                    const SizedBox(height: 20),
                    _buildDestacado(context),
                    const SizedBox(height: AppSpacing.seccion),

                    _Etiqueta('TUS MEJORES MARCAS'),
                    const SizedBox(height: AppSpacing.dentro),
                    _GrillaRecords(records: _mejoresMarcas()),
                    const SizedBox(height: AppSpacing.seccion),

                    _Etiqueta('CONSTANCIA'),
                    const SizedBox(height: AppSpacing.dentro),
                    _GrillaRecords(records: _constancia()),
                    const SizedBox(height: AppSpacing.seccion),

                    _Etiqueta('TOTALES DE SIEMPRE'),
                    const SizedBox(height: AppSpacing.dentro),
                    _TarjetaTotales(),
                    const SizedBox(height: AppSpacing.seccion),

                    _Etiqueta('DE DÓNDE SALEN TUS DATOS'),
                    const SizedBox(height: AppSpacing.dentro),
                    _TarjetaFuentes(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// El récord más grande de todos, arriba y en grande: el mejor día de
  /// pasos.
  Widget _buildDestacado(BuildContext context) {
    final dias = _conDatos;
    if (dias.isEmpty) {
      return _TarjetaVacia(
        mensaje:
            'Todavía no hay actividad registrada. Cuando empieces a '
            'caminar, acá van a aparecer tus mejores marcas.',
      );
    }

    final mejor = dias.reduce(
      (a, b) => (a.pasos ?? 0) >= (b.pasos ?? 0) ? a : b,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card,
            Color.lerp(AppColors.accent, AppColors.card, 0.93)!,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentSecondary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: AppColors.accentSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.dentro),
              Expanded(
                child: Text(
                  'Tu mejor día',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.entre),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_miles(mejor.pasos!), style: AppTheme.display(64)),
          ),
          Text(
            'pasos · ${_fecha(mejor.fecha)} · ${mejor.puntosDia} pts',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  List<_Record> _mejoresMarcas() {
    final dias = _conDatos;
    if (dias.isEmpty) return const [];

    final mejorPuntos = dias.reduce(
      (a, b) => a.puntosDia >= b.puntosDia ? a : b,
    );

    // Sesiones de intensidad que efectivamente acreditaron.
    final sesiones = dias
        .where((d) => d.sesion != null && d.sesion!.cuentaParaPuntos)
        .toList();

    final records = <_Record>[
      _Record(
        icono: Icons.bolt,
        titulo: 'Más puntos en un día',
        valor: '${mejorPuntos.puntosDia}',
        unidad: 'pts',
        detalle: _fecha(mejorPuntos.fecha),
      ),
    ];

    if (sesiones.isNotEmpty) {
      final masLarga = sesiones.reduce(
        (a, b) => a.sesion!.duracionMin >= b.sesion!.duracionMin ? a : b,
      );
      final masIntensa = sesiones.reduce(
        (a, b) => a.sesion!.porcentajeFcm >= b.sesion!.porcentajeFcm ? a : b,
      );
      records.addAll([
        _Record(
          icono: Icons.timer_outlined,
          titulo: 'Sesión más larga',
          valor: '${masLarga.sesion!.duracionMin}',
          unidad: 'min',
          detalle:
              '${masLarga.sesion!.tipoActividad} · ${_fecha(masLarga.fecha)}',
        ),
        _Record(
          icono: Icons.favorite_border,
          titulo: 'Sesión más intensa',
          valor: '${masIntensa.sesion!.porcentajeFcm}',
          unidad: '% FCM',
          detalle:
              '${masIntensa.sesion!.tipoActividad} · '
              '${_fecha(masIntensa.fecha)}',
        ),
      ]);
    }

    // Mejor semana del año, del resumen anual por mes.
    final porMes = Datos.i.resumen.actividadPorMes;
    if (porMes.any((p) => p > 0)) {
      final mejorMes = porMes.reduce((a, b) => a > b ? a : b);
      records.add(
        _Record(
          icono: Icons.calendar_month_outlined,
          titulo: 'Tu mejor mes',
          valor: _miles(mejorMes),
          unidad: 'pts',
          detalle: _meses[porMes.indexOf(mejorMes)],
        ),
      );
    }

    return records;
  }

  List<_Record> _constancia() {
    final resumen = Datos.i.resumen;
    final historial = resumen.rachaHistorial;

    // Racha más larga que se ve en el historial de semanas.
    var mejorRacha = 0;
    var corriendo = 0;
    for (final cumplida in historial) {
      corriendo = cumplida ? corriendo + 1 : 0;
      if (corriendo > mejorRacha) mejorRacha = corriendo;
    }
    if (resumen.rachaSemanas > mejorRacha) mejorRacha = resumen.rachaSemanas;

    final dias = _conDatos;
    final diasActivos = dias.where((d) => d.puntosDia > 0).length;
    final proximo = proximoHito(resumen.rachaSemanas);

    return [
      _Record(
        icono: Icons.local_fire_department,
        titulo: 'Racha actual',
        valor: '${resumen.rachaSemanas}',
        unidad: 'semanas',
        detalle: proximo == null
            ? 'Alcanzaste todos los hitos'
            : 'Faltan ${proximo.semanas - resumen.rachaSemanas} para '
                  '+${proximo.monedas} monedas',
      ),
      _Record(
        icono: Icons.trending_up,
        titulo: 'Racha más larga',
        valor: '$mejorRacha',
        unidad: 'semanas',
        detalle: 'Tu mejor seguidilla',
      ),
      _Record(
        icono: Icons.check_circle_outline,
        titulo: 'Días con puntos',
        valor: '$diasActivos',
        unidad: 'de ${dias.length}',
        detalle: 'En el historial que guarda la app',
      ),
    ];
  }
}

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

class _GrillaRecords extends StatelessWidget {
  const _GrillaRecords({required this.records});

  final List<_Record> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _TarjetaVacia(mensaje: 'Todavía no hay nada que mostrar.');
    }
    return Column(
      children: [
        for (var i = 0; i < records.length; i++) ...[
          _TarjetaRecord(record: records[i]),
          if (i != records.length - 1)
            const SizedBox(height: AppSpacing.dentro),
        ],
      ],
    );
  }
}

class _TarjetaRecord extends StatelessWidget {
  const _TarjetaRecord({required this.record});

  final _Record record;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.entre),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(record.icono, size: 20, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.entre),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.titulo,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  record.detalle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.dentro),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                record.valor,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                record.unidad,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Totales acumulados. Puntos y monedas en bloques separados: son dos
/// monedas distintas del producto y no se mezclan nunca.
class _TarjetaTotales extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final resumen = Datos.i.resumen;
    final dias = RecordsScreen._conDatos;
    final pasosTotales = dias.fold(0, (t, d) => t + (d.pasos ?? 0));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          _Fila(
            titulo: 'Pasos registrados',
            valor: RecordsScreen._miles(pasosTotales),
            nota: 'En los ${dias.length} días que guarda la app',
          ),
          const _Separador(),
          _Fila(
            titulo: 'Puntos del año',
            valor: RecordsScreen._miles(resumen.puntosAno),
            nota: 'Los puntos nunca se gastan: definen tu nivel de cashback',
          ),
          const _Separador(),
          _Fila(
            titulo: 'Nivel de cashback',
            valor: 'Nivel ${resumen.nivel}',
            nota: nivelPorNumero(resumen.nivel)?.rangoTexto ?? '',
          ),
          const _Separador(),
          _Fila(
            titulo: 'Monedas ganadas este año',
            valor: '${resumen.monedasGanadasAnio}',
            nota: 'Las monedas se gastan en Premios y caducan a los 6 meses',
          ),
        ],
      ),
    );
  }
}

/// De dónde salen los datos. Es lo que la app tiene registrado sobre el
/// origen de cada muestra, y el usuario tiene derecho a verlo.
class _TarjetaFuentes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Cuántos días aportó cada fuente, mirando la que prevaleció.
    final conteo = <String, int>{};
    for (final d in Datos.i.historial.dias) {
      final f = d.fuentePrevalece;
      if (f == null) continue;
      conteo[f.nombre] = (conteo[f.nombre] ?? 0) + 1;
    }
    final manuales = Datos.i.historial.dias.where((d) => d.esManual).length;
    final revisados = Datos.i.historial.dias
        .where((d) => d.marcadoParaRevision)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          for (final e in conteo.entries) ...[
            _Fila(
              titulo: e.key,
              valor: '${e.value}',
              nota: e.value == 1 ? 'día' : 'días',
            ),
            const _Separador(),
          ],
          _Fila(
            titulo: 'Días ingresados a mano',
            valor: '$manuales',
            nota: 'No acreditan puntos',
          ),
          if (revisados > 0) ...[
            const _Separador(),
            _Fila(
              titulo: 'Días marcados para revisión',
              valor: '$revisados',
              nota: 'Se siguen mostrando, no se descartan',
            ),
          ],
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.titulo, required this.valor, required this.nota});

  final String titulo;
  final String valor;
  final String nota;

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
              if (nota.isNotEmpty)
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
        Text(
          valor,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
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

class _TarjetaVacia extends StatelessWidget {
  const _TarjetaVacia({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        mensaje,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
