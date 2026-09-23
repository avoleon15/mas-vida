import 'package:flutter/material.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';

// ============================================================
// RÉCORDS PERSONALES.
//
// Lo que la app tiene registrado del usuario, en un solo lugar.
//
// CÓMO SE ADELGAZÓ (revisión de Daniel, 21 de septiembre de 2026). Eran
// cinco secciones y doce tarjetas idénticas, una debajo de la otra:
// cada récord con su ícono, su título, su renglón de contexto y su
// número a la derecha. Doce veces la misma forma se lee como una
// planilla, y lo que un récord tiene que provocar es lo contrario.
//
// Ahora hay tres cosas:
//
//   1. EL MEJOR DÍA, a pantalla ancha y con el número enorme. Es el
//      récord que a cualquiera le importa y es el que abre.
//   2. UNA GRILLA DE BALDOSAS. Número grande arriba, dos palabras
//      abajo. Sin íconos: doce íconos distintos son doce cosas que
//      mirar, y acá lo que se mira son los números.
//   3. LOS TOTALES, en renglones limpios. Sin las notas explicativas
//      que llevaba cada uno —"los puntos nunca se gastan", "las monedas
//      caducan a los 90 días"—: son reglas del producto y viven en Mi
//      Plan y en Premios, no debajo de un número.
//
// DE DÓNDE SALEN LOS DATOS se quedó, porque es lo que hace auditable el
// puntaje, pero pasó a un renglón por fuente, sin notas.
//
// Los récords se calculan acá sobre el historial que ya está en
// memoria: son lecturas de datos existentes, no reglas de negocio
// nuevas. Si algún día el backend los manda resueltos, esta pantalla los
// muestra sin cambiar de forma.
//
// Regla dura respetada: los PUNTOS y las MONEDAS nunca se mezclan.
// ============================================================

/// Una baldosa: un número y qué es.
class _Marca {
  const _Marca({
    required this.valor,
    required this.unidad,
    required this.titulo,
    required this.detalle,
  });

  final String valor;

  /// Lo que va pegado al número, chiquito: "pts", "min", "%".
  final String unidad;

  final String titulo;

  /// Cuándo se logró. Vacío cuando no aplica.
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
    final dias = _conDatos;

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
                    Text('TUS RÉCORDS', style: AppTheme.sectionTitle),
                    const SizedBox(height: 18),
                    _MejorDia(dias: dias),
                    if (dias.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.grupo),
                      _Grilla(marcas: _marcas()),
                    ],
                    const SizedBox(height: AppSpacing.grupo),
                    const _Totales(),
                    const SizedBox(height: AppSpacing.grupo),
                    const _Fuentes(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Las baldosas. Solo entran las que tienen dato: una baldosa con un
  /// guion adentro ocupa lo mismo que una con un récord.
  List<_Marca> _marcas() {
    final dias = _conDatos;
    if (dias.isEmpty) return const [];

    final marcas = <_Marca>[];

    final mejorPuntos = dias.reduce(
      (a, b) => a.puntosDia >= b.puntosDia ? a : b,
    );
    marcas.add(
      _Marca(
        valor: '${mejorPuntos.puntosDia}',
        unidad: 'pts',
        titulo: 'Tu mejor día en puntos',
        detalle: _fecha(mejorPuntos.fecha),
      ),
    );

    // Sesiones de intensidad que efectivamente acreditaron.
    final sesiones = dias
        .where((d) => d.sesion != null && d.sesion!.cuentaParaPuntos)
        .toList();

    if (sesiones.isNotEmpty) {
      final masLarga = sesiones.reduce(
        (a, b) => a.sesion!.duracionMin >= b.sesion!.duracionMin ? a : b,
      );
      final masIntensa = sesiones.reduce(
        (a, b) => a.sesion!.porcentajeFcm >= b.sesion!.porcentajeFcm ? a : b,
      );
      marcas.addAll([
        _Marca(
          valor: '${masLarga.sesion!.duracionMin}',
          unidad: 'min',
          titulo: 'Tu entreno más largo',
          detalle: _fecha(masLarga.fecha),
        ),
        _Marca(
          valor: '${masIntensa.sesion!.porcentajeFcm}',
          unidad: '%',
          titulo: 'Tu entreno más intenso',
          detalle: 'de tu ritmo máximo',
        ),
      ]);
    }

    final porMes = Datos.i.resumen.actividadPorMes;
    if (porMes.any((p) => p > 0)) {
      final mejorMes = porMes.reduce((a, b) => a > b ? a : b);
      marcas.add(
        _Marca(
          valor: _miles(mejorMes),
          unidad: 'pts',
          titulo: 'Tu mejor mes',
          detalle: _meses[porMes.indexOf(mejorMes)],
        ),
      );
    }

    // La racha más larga que se ve en el historial de semanas.
    final resumen = Datos.i.resumen;
    var mejorRacha = 0;
    var corriendo = 0;
    for (final cumplida in resumen.rachaHistorial) {
      corriendo = cumplida ? corriendo + 1 : 0;
      if (corriendo > mejorRacha) mejorRacha = corriendo;
    }
    if (resumen.rachaSemanas > mejorRacha) mejorRacha = resumen.rachaSemanas;

    marcas.add(
      _Marca(
        valor: '$mejorRacha',
        unidad: mejorRacha == 1 ? 'semana' : 'semanas',
        titulo: 'Tu racha más larga',
        detalle: resumen.rachaSemanas == mejorRacha
            ? 'la que llevás ahora'
            : 'hoy llevás ${resumen.rachaSemanas}',
      ),
    );

    final activos = dias.where((d) => d.puntosDia > 0).length;
    marcas.add(
      _Marca(
        valor: '$activos',
        unidad: 'de ${dias.length}',
        titulo: 'Días que sumaron',
        detalle: 'del historial guardado',
      ),
    );

    return marcas;
  }
}

/// El récord que abre la pantalla: el mejor día de pasos.
///
/// A pantalla ancha y con el número al tamaño de un titular. Es el
/// único que se lee de lejos, y por eso es el único con tarjeta propia.
class _MejorDia extends StatelessWidget {
  const _MejorDia({required this.dias});

  final List<DiaActividad> dias;

  @override
  Widget build(BuildContext context) {
    if (dias.isEmpty) {
      return _Caja(
        child: Text(
          'Todavía no hay actividad registrada. Cuando empieces a '
          'caminar, acá van a aparecer tus mejores marcas.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    final mejor = dias.reduce(
      (a, b) => (a.pasos ?? 0) >= (b.pasos ?? 0) ? a : b,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        // El mismo degradado apenas azul de la tarjeta de puntos: es el
        // dato principal de la pantalla y se marca igual que allá.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card,
            Color.lerp(AppColors.accent, AppColors.card, 0.92)!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TU MEJOR DÍA',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.azulMedio,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          // El número solo, sin ícono al lado: a 58 px ya es la imagen.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              RecordsScreen._miles(mejor.pasos!),
              maxLines: 1,
              style: AppTheme.display(58).copyWith(height: 1),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'pasos · ${RecordsScreen._fecha(mejor.fecha)} · '
            '${mejor.puntosDia} pts',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Las baldosas, de a dos por fila.
///
/// De a dos y no una lista: puestas en columna, seis récords son seis
/// renglones que se leen uno por uno. En grilla se ven todos juntos, que
/// es lo que hace que se sientan una colección.
class _Grilla extends StatelessWidget {
  const _Grilla({required this.marcas});

  final List<_Marca> marcas;

  @override
  Widget build(BuildContext context) {
    if (marcas.isEmpty) return const SizedBox.shrink();

    // De a dos, fila por fila, y no un `Wrap`: el Wrap deja que cada
    // baldosa mida lo que le pide su texto, así que una de dos renglones
    // al lado de una de uno dejaban la fila dispareja. Con
    // `IntrinsicHeight` las dos de cada fila miden lo mismo y la grilla
    // se ve grilla.
    const aire = 10.0;
    final filas = <Widget>[];
    for (var i = 0; i < marcas.length; i += 2) {
      final derecha = i + 1 < marcas.length ? marcas[i + 1] : null;
      filas.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _Baldosa(marca: marcas[i])),
              const SizedBox(width: aire),
              // Impares: la última fila lleva una sola baldosa y el
              // hueco del costado, para que no se estire al doble.
              Expanded(
                child: derecha == null
                    ? const SizedBox.shrink()
                    : _Baldosa(marca: derecha),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < filas.length; i++) ...[
          if (i > 0) const SizedBox(height: aire),
          filas[i],
        ],
      ],
    );
  }
}

class _Baldosa extends StatelessWidget {
  const _Baldosa({required this.marca});

  final _Marca marca;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El número y su unidad en la misma línea de base: "42" y
          // "min" son una sola cosa, no dos renglones.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  marca.valor,
                  maxLines: 1,
                  style: AppTheme.display(
                    30,
                  ).copyWith(color: AppColors.accent, height: 1),
                ),
                const SizedBox(width: 4),
                Text(
                  marca.unidad,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.azulMedio,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            marca.titulo,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          if (marca.detalle.isNotEmpty)
            Text(
              marca.detalle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
        ],
      ),
    );
  }
}

/// Los totales de siempre, en renglones.
class _Totales extends StatelessWidget {
  const _Totales();

  @override
  Widget build(BuildContext context) {
    final resumen = Datos.i.resumen;
    final dias = RecordsScreen._conDatos;
    final pasos = dias.fold(0, (t, d) => t + (d.pasos ?? 0));

    return _Bloque(
      titulo: 'TOTALES',
      filas: [
        ('Pasos registrados', RecordsScreen._miles(pasos)),
        ('Puntos del año', RecordsScreen._miles(resumen.puntosAno)),
        ('Nivel de cashback', 'Nivel ${resumen.nivel}'),
        ('Monedas ganadas este año', '${resumen.monedasGanadasAnio}'),
      ],
    );
  }
}

/// De dónde salen los datos.
///
/// Se queda porque es lo que vuelve auditable el puntaje: cuántos días
/// aportó cada reloj, cuántos se cargaron a mano y cuántos quedaron
/// marcados para revisión. Sin las notas que llevaba cada renglón.
class _Fuentes extends StatelessWidget {
  const _Fuentes();

  @override
  Widget build(BuildContext context) {
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

    return _Bloque(
      titulo: 'DE DÓNDE SALEN TUS DATOS',
      filas: [
        for (final e in conteo.entries)
          (e.key, '${e.value} ${e.value == 1 ? 'día' : 'días'}'),
        if (manuales > 0) ('Cargados a mano', '$manuales'),
        if (revisados > 0) ('Marcados para revisión', '$revisados'),
      ],
    );
  }
}

/// Un bloque de renglones con su rótulo arriba.
class _Bloque extends StatelessWidget {
  const _Bloque({required this.titulo, required this.filas});

  final String titulo;

  /// Cada fila es su nombre y su valor. Sin nota: las reglas del
  /// producto viven en Mi Plan y en Premios, no debajo de un número.
  final List<(String, String)> filas;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        titulo,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
      const SizedBox(height: AppSpacing.dentro),
      _Caja(
        child: Column(
          children: [
            for (var i = 0; i < filas.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 11),
                  child: Divider(height: 1, color: AppColors.cardBorder),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      filas[i].$1,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.dentro),
                  Text(
                    filas[i].$2,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

/// La caja blanca de siempre.
class _Caja extends StatelessWidget {
  const _Caja({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: child,
  );
}
