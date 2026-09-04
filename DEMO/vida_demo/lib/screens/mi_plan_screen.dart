import 'package:flutter/material.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../reglas_puntos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';

// ============================================================
// Esta pantalla no lee JSON: todo sale de `Datos.i`.
//
// REGLA DURA DEL PROYECTO: acá NUNCA aparecen monedas — esa es la
// moneda que se gasta en Premios. Mi Plan es solo puntos/cashback/
// datos de póliza.
// ============================================================

// La tabla completa de niveles ya no se muestra acá: Mi Plan enseña el
// nivel de HOY. El camino completo vive en Home.

int get nivelActual => Datos.i.resumen.nivel;
int get puntosAnuales => Datos.i.resumen.puntosAno;

/// Cashback proyectado de fin de año: el % del nivel aplicado sobre la
/// prima anual de la póliza.
int get cashbackProyectado => Datos.i.resumen.cashback.proyectadoQ;

/// TODO: falta la fórmula de devengo del cashback a mitad de año. Lo
/// único fijado es que se devuelve como dinero DESPUÉS del pago de la
/// prima, nunca como descuento directo (Superintendencia de Bancos).
int? get cashbackDevengado => Datos.i.resumen.cashback.devengadoQ;

/// El nivel proyectado a fin de año necesitaría una regresión sobre el
/// histórico real. Mientras no exista, se muestra el nivel actual sin
/// prometer una subida que nadie calculó.
///
/// TODO: falta la regla de proyección de nivel a fin de año.
int get nivelProyectado => nivelActual;

// ---- Detalles de póliza ----
String get numeroPoliza => Datos.i.perfil.poliza.numero;
String get titularYDependientes => Datos.i.perfil.poliza.titularYDependientes;
String get tipoPlan => Datos.i.perfil.poliza.tipoPlan;
String get sumaAsegurada => Datos.i.perfil.poliza.sumaAsegurada;
String get deducible => Datos.i.perfil.poliza.deducible;
String get coaseguro => Datos.i.perfil.poliza.coaseguro;
String get vigencia => Datos.i.perfil.poliza.vigencia;
String get fechaRenovacion => Datos.i.perfil.poliza.fechaRenovacion;
String get primaAnual => Datos.i.perfil.poliza.primaAnual;
String get formaPago => Datos.i.perfil.poliza.formaPago;
String get redCobertura => Datos.i.perfil.poliza.redCobertura;
String get estadoPoliza => Datos.i.perfil.poliza.estado;

class MiPlanScreen extends StatelessWidget {
  const MiPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: const AppHeader(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text('Mi Plan', style: AppTheme.sectionTitle),
                    const SizedBox(height: 20),
                    _buildCashbackCard(context),
                    const SizedBox(height: 12),
                    _buildNotaRegulatoria(context),
                    const SizedBox(height: 20),
                    _buildNivelActualCard(context),
                    const SizedBox(height: 12),
                    _buildProyeccionCard(context),
                    const SizedBox(height: 28),
                    _buildCalendarioCard(context),
                    const SizedBox(height: 28),
                    _buildPoliza(context),
                    const SizedBox(height: 28),
                    _buildAseguradoraCard(context),
                    const SizedBox(height: 28),
                    _buildUsoDelSeguroCard(context),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const BottomNavBar(currentIndex: 4),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Cashback (puntos/categoría) — ya existente conceptualmente, ahora
  // implementado en Flutter.
  // ============================================================

  /// La cuenta del cashback, sin párrafo.
  ///
  /// Reemplaza al bloque de texto que explicaba el cálculo. La prima va
  /// COMPLETA y sin tachar, y el cashback aparece aparte, como algo que
  /// se suma. Tachar la prima diría "pagás menos", que es exactamente lo
  /// que la Superintendencia de Bancos no permite: el cashback se
  /// devuelve como dinero DESPUÉS de pagar la prima.
  Widget _buildCashbackCard(BuildContext context) {
    final nivelHoy = nivelPorNumero(nivelActual);
    final pct = nivelHoy?.porcentajeCashback;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TU CASHBACK DE ESTE AÑO',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _MontoCashback(
                  etiqueta: 'Tu prima anual',
                  monto: primaAnual,
                  color: AppColors.textPrimary,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.arrow_forward,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: _MontoCashback(
                  etiqueta: 'Te devolvemos',
                  monto: 'Q${_formatNumber(cashbackProyectado)}',
                  // Azul de marca: es el número más importante de la
                  // pantalla, y el azul entero es lo que se reserva para
                  // lo que decide.
                  color: AppColors.accent,
                  destacado: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            pct == null
                ? 'Vas en nivel $nivelActual. Su % de cashback todavía no '
                      'está definido.'
                : 'Es el ${_formatPercent(pct)}% de tu prima, por ir en '
                      'nivel $nivelActual.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// El nivel de HOY, solo.
  ///
  /// Antes acá estaba la tabla de los 5 niveles. Los otros cuatro no son
  /// tuyos: el camino completo ya vive en Home, y repetirlo acá hacía que
  /// tu propio nivel se perdiera entre cuatro que no te tocan.
  Widget _buildNivelActualCard(BuildContext context) {
    final nivelHoy = nivelPorNumero(nivelActual);
    final color = AppColors.colorForNivel(nivelActual);
    final pct = nivelHoy?.porcentajeCashback;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$nivelActual',
              style: AppTheme.display(26).copyWith(color: color),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nivel $nivelActual',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${_formatNumber(puntosAnuales)} pts acumulados este año',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                pct == null ? '—' : '${_formatPercent(pct)}%',
                style: AppTheme.display(28).copyWith(color: color),
              ),
              Text(
                'de cashback',
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

  Widget _buildProyeccionCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, color: AppColors.azulMedio),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'A tu ritmo actual, terminarías el '),
                  TextSpan(
                    text: 'año en nivel $nivelProyectado',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// El calendario, ahora en tres cuadros en fila.
  ///
  /// Es una secuencia de tres momentos, y como lista vertical se leía
  /// como tres avisos sueltos. En fila y numerados se ve que uno lleva al
  /// siguiente.
  Widget _buildCalendarioCard(BuildContext context) {
    const pasos = [
      (
        icono: Icons.event_outlined,
        cuando: '31 de diciembre',
        que: 'Se cierra tu nivel del año',
      ),
      (
        icono: Icons.calculate_outlined,
        cuando: 'Enero',
        que: 'Calculamos tu cashback',
      ),
      (
        icono: Icons.payments_outlined,
        cuando: '30 días después',
        que: 'Te lo depositamos',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Cuándo lo recibís',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // IntrinsicHeight para que los tres cuadros queden de la misma
        // altura aunque su texto ocupe distinto.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < pasos.length; i++) ...[
                Expanded(
                  child: _PasoCalendario(
                    numero: i + 1,
                    icono: pasos[i].icono,
                    cuando: pasos[i].cuando,
                    que: pasos[i].que,
                  ),
                ),
                if (i != pasos.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          // El depósito depende de que la prima esté pagada: decirlo acá
          // evita que alguien lo espere antes de tiempo.
          'El depósito sale después de que pagues tu siguiente prima.',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildNotaRegulatoria(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tu cashback siempre se devuelve como dinero, después del '
              'pago de tu prima. Nunca se descuenta directamente de tu '
              'póliza.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Detalles de tu Póliza — datos que la aseguradora expone al
  // asegurado. Agrupados por tema en vez de una sola lista larga.
  // ============================================================

  /// Los detalles de la póliza, en tres bloques con su propio subtítulo.
  ///
  /// Antes eran tres tarjetas idénticas, una tras otra, sin decir qué
  /// separaba una de la siguiente: se leía como una lista larga partida
  /// al azar. Ahora cada bloque dice de qué habla.
  Widget _buildPoliza(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTituloSeccion(
                context,
                Icons.shield_outlined,
                'Tu póliza',
              ),
            ),
            // El estado es lo primero que alguien quiere saber de su
            // póliza: sube al título en vez de esconderse en una fila.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.azulBruma,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                estadoPoliza,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildBloquePoliza(context, 'IDENTIFICACIÓN', [
          ('Número de póliza', numeroPoliza, null),
          ('Titular y dependientes', titularYDependientes, null),
          ('Tipo de plan', tipoPlan, null),
        ]),
        const SizedBox(height: 16),
        _buildBloquePoliza(context, 'COBERTURA', [
          ('Suma asegurada anual', sumaAsegurada, null),
          ('Deducible', deducible, null),
          ('Coaseguro', coaseguro, null),
          ('Red de cobertura', redCobertura, null),
        ]),
        const SizedBox(height: 16),
        _buildBloquePoliza(context, 'PAGOS Y VIGENCIA', [
          ('Prima anual', primaAnual, AppColors.accent),
          ('Forma de pago', formaPago, null),
          ('Vigencia', vigencia, null),
          ('Fecha de renovación', fechaRenovacion, null),
        ]),
      ],
    );
  }

  Widget _buildBloquePoliza(
    BuildContext context,
    String titulo,
    List<(String, String, Color?)> filas,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            titulo,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        _buildCardDatos(context, filas: filas),
      ],
    );
  }

  /// Tarjeta genérica de filas "etiqueta a la izquierda, valor a la
  /// derecha". Cada fila es (etiqueta, valor, color) — color es null
  /// salvo que el valor necesite un color especial (ej. estado "Al día"
  /// en verde).
  Widget _buildCardDatos(
    BuildContext context, {
    required List<(String, String, Color?)> filas,
  }) {
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
          for (var i = 0; i < filas.length; i++) ...[
            _buildFilaDato(context, filas[i]),
            if (i != filas.length - 1) ...[
              const SizedBox(height: 12),
              Divider(color: AppColors.cardBorder, height: 1),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFilaDato(BuildContext context, (String, String, Color?) fila) {
    final (etiqueta, valor, color) = fila;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            valor,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color ?? AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Tu aseguradora y cómo usar el seguro.
  //
  // ADVERTENCIA: mientras `verificado` sea false, los datos son de
  // relleno. La pantalla lo dice en voz alta en vez de mostrarlos como
  // buenos: un teléfono de emergencias equivocado se marca en el peor
  // momento posible.
  // ============================================================

  Widget _buildAseguradoraCard(BuildContext context) {
    final a = Datos.i.perfil.aseguradora;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTituloSeccion(
          context,
          Icons.apartment_outlined,
          'Tu aseguradora',
        ),
        const SizedBox(height: 14),
        if (!a.verificado) _AvisoSinVerificar(),
        if (!a.verificado) const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              _ContactoAseguradora(
                icono: Icons.emergency_outlined,
                etiqueta: 'Emergencias, 24/7',
                valor: a.telefonoEmergencias,
                urgente: true,
                habilitado: a.verificado,
              ),
              const _SeparadorFino(),
              _ContactoAseguradora(
                icono: Icons.support_agent_outlined,
                etiqueta: 'Servicio al cliente',
                valor: a.telefonoServicio,
                habilitado: a.verificado,
              ),
              const _SeparadorFino(),
              _ContactoAseguradora(
                icono: Icons.mail_outline,
                etiqueta: 'Correo',
                valor: a.correo,
                habilitado: a.verificado,
              ),
              const _SeparadorFino(),
              _ContactoAseguradora(
                icono: Icons.schedule_outlined,
                etiqueta: 'Horario de oficina',
                valor: a.horario,
                habilitado: a.verificado,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsoDelSeguroCard(BuildContext context) {
    final uso = Datos.i.perfil.usoDelSeguro;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTituloSeccion(
          context,
          Icons.medical_services_outlined,
          'Cómo usar tu seguro',
        ),
        const SizedBox(height: 14),
        if (!uso.verificado) _AvisoSinVerificar(),
        if (!uso.verificado) const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              for (var i = 0; i < uso.pasos.length; i++) ...[
                _PasoUsoFila(numero: i + 1, paso: uso.pasos[i]),
                if (i != uso.pasos.length - 1) const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTituloSeccion(
    BuildContext context,
    IconData icono,
    String texto,
  ) {
    return Row(
      children: [
        Icon(icono, color: AppColors.textPrimary, size: 20),
        const SizedBox(width: 8),
        Text(
          texto,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static String _formatPercent(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  static String _formatNumber(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buffer.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }
}

// ============================================================
// Piezas de la pantalla
// ============================================================

/// Un monto de la cuenta del cashback: etiqueta arriba, número abajo.
class _MontoCashback extends StatelessWidget {
  const _MontoCashback({
    required this.etiqueta,
    required this.monto,
    required this.color,
    this.destacado = false,
  });

  final String etiqueta;
  final String monto;
  final Color color;

  /// El lado del cashback lleva fondo y borde; la prima va limpia. Así el
  /// ojo cae en lo que se gana, sin tocar la prima.
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: destacado
          ? BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          // FittedBox: con textScaler grande el monto se achica en vez de
          // desbordar la tarjeta.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              monto,
              style: AppTheme.display(26).copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uno de los tres cuadros del calendario.
class _PasoCalendario extends StatelessWidget {
  const _PasoCalendario({
    required this.numero,
    required this.icono,
    required this.cuando,
    required this.que,
  });

  final int numero;
  final IconData icono;
  final String cuando;
  final String que;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$numero',
                  style: const TextStyle(
                    color: AppColors.card,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Icon(icono, size: 16, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            cuando,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            que,
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

/// Aviso de que un bloque todavía trae datos de relleno.
///
/// Va ARRIBA del bloque y no abajo: si va abajo, alguien ya marcó el
/// teléfono antes de leerlo.
class _AvisoSinVerificar extends StatelessWidget {
  const _AvisoSinVerificar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accentSecondary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.accentSecondary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Datos de ejemplo. La aseguradora todavía no confirmó esta '
              'información: no la uses en una emergencia real.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una fila de contacto de la aseguradora.
class _ContactoAseguradora extends StatelessWidget {
  const _ContactoAseguradora({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.habilitado,
    this.urgente = false,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  /// False mientras el dato no esté verificado: se muestra apagado para
  /// que nadie lo lea como un número bueno.
  final bool habilitado;

  /// Emergencias va en naranja: es el que hay que encontrar rápido.
  final bool urgente;

  @override
  Widget build(BuildContext context) {
    final color = !habilitado
        ? AppColors.textSecondary
        : urgente
        ? AppColors.accentSecondary
        : AppColors.accent;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icono, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                valor,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: habilitado
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: habilitado ? FontWeight.w700 : FontWeight.w500,
                  fontStyle: habilitado ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Un paso de "cómo usar tu seguro".
class _PasoUsoFila extends StatelessWidget {
  const _PasoUsoFila({required this.numero, required this.paso});

  final int numero;
  final PasoUso paso;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$numero',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paso.titulo,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                paso.detalle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeparadorFino extends StatelessWidget {
  const _SeparadorFino();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Divider(height: 1, color: AppColors.cardBorder),
  );
}
