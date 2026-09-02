import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../rachas_recompensas.dart';
import '../reglas_puntos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/desglose_puntos_hoy.dart';
import '../widgets/escalera_cashback.dart';
import '../widgets/panel_objetivo_semana.dart';
import '../widgets/progress_ring.dart';
import '../widgets/semanas_objetivos.dart';
import '../widgets/stepper_etapas.dart';
import '../widgets/tarjeta_borde_animado.dart';

// ============================================================
// Esta pantalla no lee JSON ni calcula puntos: todo sale ya resuelto de
// `Datos.i`, que se hidrata al arrancar desde el repositorio elegido en
// `lib/datos/fuente_datos.dart`.
// ============================================================

/// Racha activa del usuario, en semanas seguidas cumpliendo la meta.
int get rachaSemanas => Datos.i.resumen.rachaSemanas;

// ============================================================
// OBJETIVOS DE LA SEMANA. Acá se pagan MONEDAS — la moneda que se gasta
// en Premios y caduca a 90 días. Nunca puntos: los puntos mueven el
// cashback anual y las dos monedas del producto no se mezclan.
//
// Reemplazan por completo a las viejas "Metas Mensuales", que ya no
// existen. Las reglas del rango viven en `reglas_rango.dart`.
// ============================================================

ObjetivosSemana get _semana => Datos.i.resumen.objetivosSemana;

int get monedasEsteMes => Datos.i.resumen.monedas.ganadasEsteMes;
int get techoMonedasMensual => Datos.i.resumen.monedas.techoMensual;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// Pasos de hoy. `null` cuando no hay permiso de HealthKit — que NO es
  /// lo mismo que cero pasos.
  static int? get pasos => Datos.i.historial.hoy.pasos;

  /// Meta diaria de pasos. Es el piso a partir del cual se empiezan a
  /// ganar puntos (7.000), no una meta personalizada.
  static int get metaPasos => pisoPasos;

  /// PUNTOS acumulados del año. Nunca se gastan y nunca aparecen en
  /// Premios.
  static int get puntosTotal => Datos.i.resumen.puntosAno;

  /// Cashback proyectado a fin de año, en quetzales. Se devuelve como
  /// dinero DESPUÉS del pago de la prima — nunca como descuento.
  ///
  /// TODO: falta la fórmula de devengo a mitad de año, así que se muestra
  /// la proyección anual y no un acumulado parcial.
  static int get cashbackProyectado => Datos.i.resumen.cashback.proyectadoQ;

  /// Nivel anual numérico (contrato v1: nunca Bronze/Silver/Gold/Platinum).
  static int get nivelActual => Datos.i.resumen.nivel;

  static String get nombreUsuario => Datos.i.perfil.nombre;

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
                    // Home se agrupa en TRES bloques por horizonte de
                    // tiempo, y el orden es intencional: va de lo que el
                    // usuario puede cambiar hoy a lo que se acumula a lo
                    // largo del año.
                    //
                    //   DIARIO  -> anillo, etapas y puntos de hoy
                    //   SEMANAL -> objetivos de la semana
                    //   ANUAL   -> cashback
                    //
                    // El saludo y la racha quedan afuera de los tres.
                    const SizedBox(height: AppSpacing.grupo),
                    // El saludo va adentro de la tarjeta de borde animado:
                    // le da algo de color a la parte de arriba de Home,
                    // que estaba muy blanca. Adentro va SOLO el saludo.
                    SizedBox(
                      width: double.infinity,
                      child: TarjetaBordeAnimado(child: _buildSaludo(context)),
                    ),
                    // La racha queda afuera de la tarjeta pero pegada a
                    // ella: es parte del saludo, no una sección propia.
                    const SizedBox(height: AppSpacing.dentro),
                    _buildRachaLinea(context),

                    const SizedBox(height: AppSpacing.seccion),
                    _BloqueHorizonte(
                      titulo: 'DIARIO',
                      child: _buildSeccionHoy(context),
                    ),

                    const SizedBox(height: AppSpacing.seccion),
                    _BloqueHorizonte(
                      titulo: 'SEMANAL',
                      child: _buildObjetivosSemanaSection(context),
                    ),

                    const SizedBox(height: AppSpacing.seccion),
                    _BloqueHorizonte(
                      titulo: 'ANUAL',
                      child: _buildCashbackSection(context),
                    ),

                    const SizedBox(height: AppSpacing.grupo),
                  ],
                ),
              ),
            ),
            const BottomNavBar(currentIndex: 0),
          ],
        ),
      ),
    );
  }

  /// Encabezado de sección, igual para las tres secciones de Home.
  ///
  /// Existe para que "Tu Cashback" y "Objetivos de la semana" se vean
  /// exactamente iguales: cosas del mismo rango tienen que verse del
  /// mismo modo, si no la pantalla se lee como widgets sueltos.
  static Widget _encabezadoSeccion(
    BuildContext context,
    IconData icono,
    String titulo, {
    Widget? accion,
  }) {
    return Row(
      children: [
        Icon(icono, color: AppColors.textPrimary),
        const SizedBox(width: AppSpacing.dentro),
        // Expanded en vez de Text suelto + Spacer: con el texto del
        // sistema en grande, el título crecía y empujaba la acción fuera
        // de la fila.
        Expanded(
          child: Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (accion != null) ...[
          const SizedBox(width: AppSpacing.dentro),
          accion,
        ],
      ],
    );
  }

  /// Bloque de HOY: el anillo, cuánto queda del día y los puntos. Los
  /// tres son del MISMO horizonte temporal, por eso van pegados entre sí
  /// y separados del resto por un corte grande.
  Widget _buildSeccionHoy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // El anillo y el objetivo de la semana comparten el mismo lugar:
        // se pasa de uno al otro deslizando.
        const _CarruselAnillo(),
        // Pegado al anillo: el tiempo restante es un pie del anillo, no
        // un elemento aparte.
        const SizedBox(height: AppSpacing.dentro),
        _buildTiempoRestante(context),
        const SizedBox(height: AppSpacing.entre),
        StepperEtapas(pasos: pasos ?? 0),
        const SizedBox(height: AppSpacing.entre),
        DesglosePuntosHoy(dia: Datos.i.historial.hoy),
      ],
    );
  }

  /// Saludo dinámico según la hora del día, con el nombre del usuario.
  /// Reemplaza al antiguo título fijo "HOY". Sin fondo: solo una sombra
  /// suave detrás del texto para que no quede tan plano.
  Widget _buildSaludo(BuildContext context) {
    final sombra = [
      Shadow(
        color: AppColors.textPrimary.withValues(alpha: 0.10),
        blurRadius: 6,
      ),
    ];
    // Se sale de Bebas Neue (condensada y solo mayúsculas, que le daba un
    // tono de titular deportivo) y pasa a la tipografía de texto en caja
    // mixta. Un saludo con el nombre de la persona se lee mejor en caja
    // mixta que gritado en mayúsculas.
    //
    // La jerarquía la lleva el PESO, no el tamaño: el nombre resalta sin
    // ocupar más espacio.
    final base = Theme.of(context).textTheme.headlineSmall;

    return Text.rich(
      TextSpan(
        children: [
          // El saludo es el envoltorio: peso liviano y gris secundario.
          TextSpan(
            text: '${_saludoSegunHora()}, ',
            style: base?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
              letterSpacing: AppTheme.trackingPara(24),
            ),
          ),
          // El nombre es lo que hace que se sienta personalizado.
          TextSpan(
            text: nombreUsuario,
            style: base?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: AppTheme.trackingPara(24),
              shadows: sombra,
            ),
          ),
        ],
      ),
    );
  }

  /// Línea de racha activa bajo el saludo. Si al usuario le falta
  /// exactamente 1 semana para el próximo hito de monedas, se agrega un
  /// texto destacado en color de acento; si no, queda la línea simple.
  Widget _buildRachaLinea(BuildContext context) {
    final hito = proximoHito(rachaSemanas);
    final aUnaSemana = hito != null && hito.semanas - rachaSemanas == 1;

    // Alineada a la derecha: el saludo tira a la izquierda, así que la
    // racha equilibra la línea desde el otro lado.
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (aUnaSemana) ...[
          Flexible(
            child: Text(
              '¡1 semana más para +${hito.monedas} monedas!',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        const Icon(
          Icons.local_fire_department,
          color: AppColors.accentSecondary,
          size: 16,
        ),
        const SizedBox(width: 4),
        // Flexible: con la letra del sistema en grande, "Racha de N
        // semanas" no entra en el ancho que le queda al lado del aviso.
        Flexible(
          child: Text(
            'Racha de $rachaSemanas semanas',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  /// "Buenos días" antes de las 12pm, "Buenas tardes" entre 12pm y 7pm,
  /// "Buenas noches" después de las 7pm.
  static String _saludoSegunHora() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// Tiempo que falta del día para cumplir la meta de pasos. Va debajo
  /// del anillo (que adentro solo muestra pasos y meta).
  Widget _buildTiempoRestante(BuildContext context) {
    final base = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);

    return Center(
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Te quedan '),
            // Las horas van en el color del aro en curso. Es lo que
            // amarra el anillo con el resto de la pantalla: sin esto el
            // bronce/plata/oro no existe en ningún otro lado y el anillo
            // se lee como un objeto pegado en el medio.
            TextSpan(
              text: '${_horasRestantesDelDia()}h',
              style: base?.copyWith(
                color: colorDelAroActual(pasos ?? 0),
                fontWeight: FontWeight.w700,
              ),
            ),
            const TextSpan(text: ' del día'),
          ],
        ),
        style: base,
      ),
    );
  }

  /// Horas que quedan del día actual hasta la medianoche, redondeadas.
  static int _horasRestantesDelDia() {
    final ahora = DateTime.now();
    final medianoche = DateTime(ahora.year, ahora.month, ahora.day + 1);
    return (medianoche.difference(ahora).inMinutes / 60).round();
  }

  /// Sección "Tu Cashback": monto acumulado, categoría actual con su %
  /// protagonista, y qué tan cerca está del siguiente nivel. El cashback
  /// siempre se devuelve como dinero después del pago de la prima (regla
  /// regulatoria de Guatemala) — nunca se le llama "descuento" ni "ahorro
  /// en tu prima".
  Widget _buildCashbackSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _encabezadoSeccion(
          context,
          Icons.account_balance_wallet_outlined,
          'Tu Cashback',
          accion: _Presionable(
            onTap: () => Navigator.of(context).pushNamed('/mi-plan'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ver mi plan ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: AppColors.accent,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.grupo),
        Container(
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
              // 1. Los puntos del año. Es el número que la persona abre
              // la app para ver, así que es el más grande de la tarjeta.
              // El cashback sale del nivel, y el nivel sale de acá.
              Text(
                'PUNTOS ACUMULADOS ${Datos.i.resumen.anio}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatNumber(puntosTotal),
                        style: AppTheme.display(52),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.entre),
                  // 3. El nivel y su %, dicho con todas las letras. La
                  // escalera de abajo lo muestra en gráfico, pero el dato
                  // tiene que poder leerse sin interpretar el dibujo.
                  Expanded(child: _PastillaNivel(nivel: nivelActual)),
                ],
              ),

              // 2. Cuánto falta para el siguiente nivel.
              const SizedBox(height: AppSpacing.dentro),
              _AvanceAlSiguienteNivel(
                puntosTotal: puntosTotal,
                nivelActual: nivelActual,
              ),

              const SizedBox(height: AppSpacing.grupo),
              // 3. El nivel y su %. La escalera es interactiva: toda la
              // explicación de los niveles vive adentro, un renglón a la
              // vez, en vez de tres párrafos fijos.
              EscaleraCashback(
                nivelActual: nivelActual,
                puntosTotal: puntosTotal,
                techoActividad: Datos.i.resumen.techoAnual,
              ),

              const SizedBox(height: AppSpacing.entre),
              const Divider(height: 1, color: AppColors.cardBorder),
              const SizedBox(height: AppSpacing.entre),

              // 4 y 5. El monto en quetzales y CUÁNDO se cobra, detrás de
              // un botón. La nota regulatoria viaja pegada al monto: el
              // cashback se devuelve como dinero DESPUÉS del pago de la
              // prima, nunca como descuento (Superintendencia de Bancos).
              _BotonVerCashback(
                monto: cashbackProyectado,
                porcentaje: nivelPorNumero(nivelActual)?.porcentajeCashback,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Sección "Objetivos de la semana": el sistema de MONEDAS, aparte del
  /// de puntos/cashback de arriba. Las monedas se gastan en Premios y
  /// caducan a los 90 días; los puntos nunca se gastan.
  ///
  /// Son 3 objetivos, los tres de la MISMA semana. Se evalúan una sola
  /// vez, el domingo 23:59 (hora de Guatemala).
  Widget _buildObjetivosSemanaSection(BuildContext context) {
    final semana = _semana;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _encabezadoSeccion(
          context,
          Icons.flag_outlined,
          'Objetivos de la semana',
          // El saldo de MONEDAS vive acá arriba, no en una tarjeta aparte
          // al final: es el marcador de toda la sección y sube cada vez
          // que se completa un objetivo.
          accion: _SaldoMonedasChip(monedas: semana.monedasGanadas),
        ),
        const SizedBox(height: AppSpacing.grupo),
        SemanasObjetivos(semanas: semana.semanas),
      ],
    );
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

class _StepsRing extends StatelessWidget {
  const _StepsRing({required this.steps});

  /// `null` cuando HealthKit no devolvió nada y hay que asumir permiso
  /// negado. NO es lo mismo que cero pasos, y la UI no puede mostrarlo
  /// como tal.
  final int? steps;

  @override
  Widget build(BuildContext context) {
    final pasosHoy = steps;
    final sinPermiso = pasosHoy == null;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Sin permiso el anillo queda vacío (solo el track), que no es lo
        // mismo que mostrar cero pasos: eso lo aclara el texto de abajo.
        ProgressRing(pasos: sinPermiso ? 0 : pasosHoy, size: 260),
        // El anillo mide 260 y no cambia de tamano: su contenido tiene
        // que caber ahi adentro aunque la letra del sistema crezca.
        SizedBox(
          width: 260 * 0.72,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sinPermiso) ...[
                  const Icon(
                    Icons.lock_outline,
                    size: 44,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Sin permiso para leer tu actividad',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Activalo en Ajustes → Salud',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ] else
                  TextoCentroAnillo(pasos: pasosHoy),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AvanceAlSiguienteNivel extends StatelessWidget {
  const _AvanceAlSiguienteNivel({
    required this.puntosTotal,
    required this.nivelActual,
  });

  final int puntosTotal;
  final int nivelActual;

  @override
  Widget build(BuildContext context) {
    final siguiente = _siguienteNivel();
    final estiloApoyo = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    if (siguiente == null) {
      return Text('Estás en el nivel más alto de cashback', style: estiloApoyo);
    }
    if (!siguiente.definido) {
      return Text(
        'El nivel ${siguiente.numero} todavía no tiene rango definido',
        style: estiloApoyo,
      );
    }

    final piso = nivelPorNumero(nivelActual)?.puntosMinimos ?? 0;
    final techo = siguiente.puntosMinimos!;
    final avance = techo > piso
        ? ((puntosTotal - piso) / (techo - piso)).clamp(0.0, 1.0)
        : 1.0;
    final faltan = techo - puntosTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: avance,
            minHeight: 7,
            backgroundColor: AppColors.cardBorder,
            valueColor: AlwaysStoppedAnimation(
              AppColors.colorForNivel(siguiente.numero),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Te faltan ${_HomeFormato.miles(faltan)} pts',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: ' para el nivel ${siguiente.numero}'),
            ],
          ),
          style: estiloApoyo,
        ),
      ],
    );
  }

  /// El nivel que sigue al actual en la tabla, o null si ya es el último.
  Nivel? _siguienteNivel() {
    for (final n in niveles) {
      if (n.numero > nivelActual) return n;
    }
    return null;
  }
}

/// Formatos para los widgets sueltos de esta pantalla.
class _HomeFormato {
  /// 10.0 -> "10", 7.5 -> "7,5". Coma decimal, como se usa acá.
  static String pct(double v) => v == v.roundToDouble()
      ? '${v.round()}'
      : v.toString().replaceAll('.', ',');

  static String miles(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
}

/// Pastilla con el nivel actual y su porcentaje de cashback.
class _PastillaNivel extends StatelessWidget {
  const _PastillaNivel({required this.nivel});

  final int nivel;

  @override
  Widget build(BuildContext context) {
    final datos = nivelPorNumero(nivel);
    final color = AppColors.colorForNivel(nivel);
    final pct = datos?.porcentajeCashback;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        // Sin porcentaje definido no se inventa uno.
        pct == null
            ? 'Nivel $nivel'
            : 'Nivel $nivel · ${_HomeFormato.pct(pct)}% de cashback',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Botón que abre la hoja con el cashback del usuario.
///
/// El monto vive detrás de un toque a propósito: es la respuesta a la
/// pregunta "¿y esto cuánto me da a mí?", y llega mejor cuando la persona
/// la pide que cuando aparece como un renglón más de la tarjeta.
///
/// Abre una HOJA que sube desde abajo, no un desplegable: Home ya tiene
/// varios acordeones (los puntos de hoy, las cuatro semanas) y uno más
/// se perdía entre los demás. La hoja además deja Home visible detrás,
/// así el monto se lee sin perder de vista de dónde salió.
class _BotonVerCashback extends StatefulWidget {
  const _BotonVerCashback({required this.monto, required this.porcentaje});

  /// Quetzales proyectados para el cierre del año.
  final int monto;

  /// Porcentaje del nivel actual. Null si el nivel no lo tiene definido.
  final double? porcentaje;

  @override
  State<_BotonVerCashback> createState() => _BotonVerCashbackState();
}

class _BotonVerCashbackState extends State<_BotonVerCashback> {
  bool _presionado = false;

  void _abrirHoja() {
    // Háptica en el momento causal: cuando la hoja empieza a subir.
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      // Sin esto la hoja no puede pasar de la mitad de la pantalla.
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // El velo oscurece Home lo justo para que la hoja mande, sin
      // borrar el contexto de dónde salió el número.
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
      builder: (_) => _HojaCashback(
        monto: widget.monto,
        porcentaje: widget.porcentaje,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // El hundido responde en el press, no al soltar.
      onTapDown: (_) => setState(() => _presionado = true),
      onTapUp: (_) => setState(() => _presionado = false),
      onTapCancel: () => setState(() => _presionado = false),
      onTap: _abrirHoja,
      child: AnimatedScale(
        scale: _presionado ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            // Azul: es una acción, y el azul es el color de acción de la
            // app.
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 19,
                color: Colors.white,
              ),
              const SizedBox(width: AppSpacing.dentro),
              Flexible(
                child: Text(
                  'Ver mi cashback',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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

/// La hoja que sube desde abajo con el cashback.
///
/// Ocupa media pantalla y se cierra de tres formas: la X, arrastrándola
/// hacia abajo, o tocando afuera. Tres salidas para algo que solo
/// informa: quedarse encerrado en una hoja que solo muestra un número
/// sería absurdo.
class _HojaCashback extends StatelessWidget {
  const _HojaCashback({required this.monto, required this.porcentaje});

  final int monto;
  final double? porcentaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      // La hoja mide lo que mide su contenido, con un techo del 85% de la
      // pantalla por si el texto del sistema está en grande.
      //
      // Antes forzaba media pantalla fija y el contenido no llegaba ni a
      // la mitad: quedaba un blanco enorme abajo.
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barrita de arrastre: dice que la hoja se puede empujar
            // hacia abajo antes de que el usuario lo intente.
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
                      'Tu cashback',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
            // Flexible + shrinkWrap: si todo entra, la hoja queda del
            // alto del contenido; si no, ese pedazo se vuelve scrolleable
            // en vez de desbordar.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: _MontoRevelado(monto: monto, porcentaje: porcentaje),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MontoRevelado extends StatelessWidget {
  const _MontoRevelado({required this.monto, required this.porcentaje});

  final int monto;
  final double? porcentaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.entre),
      decoration: BoxDecoration(
        // Todo el bloque de cashback vive en azul: es plata, y la plata
        // es del color de acción de la app. El naranja no entra acá.
        color: AppColors.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TE REGRESAN',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Q${_HomeFormato.miles(monto)}',
            style: AppTheme.display(46).copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: 4),
          Text(
            porcentaje == null
                ? 'Proyección para el cierre del año'
                : 'Es el ${_HomeFormato.pct(porcentaje!)}% de tu prima anual, '
                      'proyectado al cierre del año',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.dentro),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  // Regla dura: se devuelve como dinero DESPUÉS del pago
                  // de la prima. Nunca "descuento en tu prima".
                  'Se te devuelve como dinero después de pagar tu prima',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// El anillo de pasos y el objetivo de la semana comparten el mismo lugar
/// de la pantalla: se pasa de uno al otro deslizando.
///
/// Es un [PageView] a propósito y no un gesto propio: trae gratis el
/// arrastre 1:1, el traspaso de velocidad al soltar, la proyección del
/// impulso y poder agarrarlo a mitad de camino para devolverlo.
class _CarruselAnillo extends StatefulWidget {
  const _CarruselAnillo();

  @override
  State<_CarruselAnillo> createState() => _CarruselAnilloState();
}

class _CarruselAnilloState extends State<_CarruselAnillo> {
  final _controlador = PageController();
  int _pagina = 0;

  static const double _lado = 260;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _alCambiar(int pagina) {
    if (pagina == _pagina) return;
    // Háptica en el momento causal: cuando la página cambia.
    HapticFeedback.selectionClick();
    setState(() => _pagina = pagina);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _lado,
      child: PageView(
        controller: _controlador,
        onPageChanged: _alCambiar,
        children: [
          Center(child: _StepsRing(steps: HomeScreen.pasos)),
          Center(
            child: PanelObjetivoSemana(
              retos: Datos.i.resumen.retos,
              size: _lado,
            ),
          ),
        ],
      ),
    );
  }
}

/// Envoltorio que hunde a su hijo mientras está presionado.
///
/// El hundido responde en el instante del press, no al soltar: esperar al
/// touch-up se siente muerto.
class _Presionable extends StatefulWidget {
  const _Presionable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<_Presionable> {
  bool _presionado = false;

  void _marcar(bool v) {
    if (_presionado != v) setState(() => _presionado = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _marcar(true),
      onTapUp: (_) => _marcar(false),
      onTapCancel: () => _marcar(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _presionado ? 0.96 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// MONEDAS ganadas con los objetivos, en la esquina superior derecha de
/// la sección.
///
/// Es el marcador de la sección: es la SUMA de lo que dieron las semanas
/// que se ven abajo, y sube cada vez que se completa un objetivo. No es
/// el saldo de la billetera —ese incluye meses anteriores y descuenta lo
/// gastado en Premios—, porque acá tiene que cuadrar con lo que el
/// usuario puede sumar a ojo en las tarjetas.
///
/// Son MONEDAS: se gastan en Premios y caducan a los 90 días. Nunca
/// puntos.
class _SaldoMonedasChip extends StatelessWidget {
  const _SaldoMonedasChip({required this.monedas});

  final int monedas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentSecondary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on,
            size: 16,
            color: AppColors.accentSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            '$monedas',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Uno de los tres bloques de Home, con su etiqueta de horizonte
/// temporal: DIARIO, SEMANAL, ANUAL.
///
/// La etiqueta es chica, en mayúsculas y con tracking amplio: tiene que
/// ordenar la pantalla sin competir con los números grandes. Es la misma
/// pauta de "PUNTOS ACUMULADOS 2026" y "PUNTOS HOY".
///
/// La etiqueta va suelta sobre el fondo tintado: no hace falta ningún
/// contenedor, porque el fondo ya separa los bloques de las tarjetas.
class _BloqueHorizonte extends StatelessWidget {
  const _BloqueHorizonte({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final etiqueta = Text(
      titulo,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        // Tracking amplio: es lo que hace que se lea como etiqueta de
        // sección y no como un título más.
        letterSpacing: 2.4,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        etiqueta,
        const SizedBox(height: AppSpacing.dentro),
        child,
      ],
    );
  }
}
