import 'package:flutter/material.dart';
import '../datos/fuente_datos.dart';
import '../rachas_recompensas.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/boton_principal.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/calendario_actividad.dart';
import '../widgets/tarjeta_puntos.dart';

// ============================================================
// Pantalla de PROGRESO.
//
// No lee JSON ni calcula puntos: todo viene ya resuelto del backend, hoy
// por los datos de prueba.
//
// Esta pantalla adelgazó bastante. Se fueron cuatro tarjetas que
// duplicaban cosas que ya viven en otro lado:
//
//   - "Reto semanal": lo mismo que los objetivos de la semana de Hoy, y
//     encima llamaba Nivel a lo que es Rango.
//   - "Nivel Actual": ya está en Hoy, en la sección de cashback.
//   - Monedas del período: ya está en Premios, que es donde se gastan.
//     El aviso de vencimiento se mudó allá y ahora es permanente.
//   - "Ritmo Cardíaco": la barra apilada de zonas no agregaba nada que no
//     dijera ya el resto de la pantalla.
//
// El número del período y las barras de actividad, que eran dos tarjetas
// distintas diciendo lo mismo, ahora son una sola: `TarjetaPuntos`.
// ============================================================

int get rachaSemanas => Datos.i.resumen.rachaSemanas;

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Periodo _periodo = Periodo.semana;

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
                    _buildEncabezado(context),
                    const SizedBox(height: 20),

                    // Una sola tarjeta de Puntos, con el selector de
                    // período adentro.
                    TarjetaPuntos(
                      periodo: _periodo,
                      onCambiarPeriodo: (p) => setState(() => _periodo = p),
                    ),
                    const SizedBox(height: 20),

                    // El calendario de cuadritos solo en Año: es una
                    // vista de todo el período largo. En Semana y Mes las
                    // gráficas de arriba ya dicen lo mismo con más
                    // detalle.
                    if (_periodo == Periodo.anio) ...[
                      CalendarioActividad(dias: Datos.i.historial.dias),
                      const SizedBox(height: 20),
                    ],

                    _buildRecompensasConstancia(context),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const BottomNavBar(currentIndex: 1),
          ],
        ),
      ),
    );
  }

  /// Título de la pantalla y el atajo a récords.
  ///
  /// El título dice "Progreso" a secas: antes decía "Progreso Semanal"
  /// aunque el filtro estuviera en Mes o Año, así que además de repetir
  /// lo que ya dice el selector, mentía.
  ///
  /// El botón de récords se mudó acá arriba. Antes era un botón de ancho
  /// completo perdido al final del scroll: es un atajo, no el cierre de
  /// la pantalla.
  Widget _buildEncabezado(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('Progreso', style: AppTheme.sectionTitle)),
        // Mismo botón azul que "Ver mi cashback" en Hoy, en su versión
        // compacta para poder ir al lado del título.
        BotonPrincipal(
          texto: 'Récords',
          icono: Icons.military_tech_outlined,
          anchoCompleto: false,
          onPressed: () => Navigator.of(context).pushNamed('/records'),
        ),
      ],
    );
  }

  /// Los cinco hitos de racha, con su check y las monedas que pagan.
  Widget _buildRecompensasConstancia(BuildContext context) {
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
          Row(
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recompensas por constancia',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < hitosRacha.length; i++) ...[
            _buildFilaHito(context, hitosRacha[i]),
            if (i != hitosRacha.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildFilaHito(BuildContext context, HitoRacha hito) {
    final alcanzado = rachaSemanas >= hito.semanas;
    final color = alcanzado
        ? AppColors.accentSecondary
        : AppColors.textSecondary;

    return Row(
      children: [
        Icon(
          alcanzado ? Icons.check_circle : Icons.radio_button_unchecked,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${hito.semanas} semanas seguidas',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: alcanzado
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontWeight: alcanzado ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        Icon(Icons.monetization_on, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '+${hito.monedas}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
