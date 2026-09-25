import 'package:flutter/material.dart';
import '../datos/fuente_datos.dart';
import '../theme.dart';
import '../widgets/actividad_fisica.dart';
import '../widgets/app_header.dart';
import '../widgets/boton_principal.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/calendario_actividad.dart';
import '../widgets/refresco_vida.dart';
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
// "Recompensas por constancia" también se fue: se mudó a la hoja que se
// abre desde el chip de monedas de Hoy, al lado de los objetivos que las
// pagan. Suelta acá no se entendía con qué se relacionaba.
//
// El número del período y las barras de actividad, que eran dos tarjetas
// distintas diciendo lo mismo, ahora son una sola: `TarjetaPuntos`.
//
// Y con ellas se fue la racha (21 de septiembre de 2026), que se ve en
// Hoy y en Social. Lo que queda es UNA idea por pantalla: cuánto hiciste
// en el período que elegiste. Todo lo que hay debajo del selector —el
// número, la gráfica de pasos y tu actividad— cambia cuando cambia el
// filtro. Nada más se queda quieto ahí ocupando lugar.
// ============================================================

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
              // Se vuelve a dibujar cuando alguien refresca en CUALQUIER
              // pantalla, no solo acá: los datos son uno solo.
              child: ValueListenableBuilder<int>(
                valueListenable: datosRecargados,
                // Era un SingleChildScrollView. Pasa a CustomScrollView
                // porque el control de refresco de Cupertino es un
                // sliver y solo vive adentro de uno. El contenido y el
                // padding son los mismos de antes.
                builder: (context, _, _) => CustomScrollView(
                  physics: fisicaConRefresco,
                  slivers: [
                    const RefrescoVida(),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(
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
                              onCambiarPeriodo: (p) =>
                                  setState(() => _periodo = p),
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

                            // LA RACHA SE FUE DE ACÁ (decisión de Daniel,
                            // 21 de septiembre de 2026). Vive en Hoy —en
                            // el saludo— y en Social, con la alerta de
                            // racha en riesgo. Entera y con su historial
                            // de ocho semanas era la tarjeta más alta de
                            // la pantalla, y empujaba hasta abajo del
                            // todo lo que esta pantalla sí tiene que
                            // contar: el progreso del período que se
                            // está mirando.

                            // La actividad del período, que ahora SÍ
                            // cambia con el filtro: antes existía solo en
                            // Semana y contaba siempre los últimos siete
                            // días, así que en Mes y en Año la pantalla
                            // terminaba en la racha.
                            ActividadDelPeriodo(
                              tramo: switch (_periodo) {
                                Periodo.semana => TramoActividad.semana,
                                Periodo.mes => TramoActividad.mes,
                                Periodo.anio => TramoActividad.anio,
                              },
                              // El recorte sale del modelo y no de acá:
                              // dónde empieza una semana o un mes en hora
                              // de Guatemala es regla de negocio.
                              dias: switch (_periodo) {
                                Periodo.semana =>
                                  Datos.i.historial.semanaEnCurso,
                                // NO es el mes calendario: son los días
                                // de las semanas del mes (las que tienen
                                // su lunes adentro), para que esta lista
                                // cuente y numere las mismas semanas que
                                // la gráfica de arriba.
                                Periodo.mes =>
                                  Datos.i.historial.diasDeLasSemanasDelMes,
                                Periodo.anio => Datos.i.historial.anioEnCurso,
                              },
                              // Los meses salen del resumen anual y no
                              // de los días: lo que la app guarda día
                              // por día son las últimas semanas, así que
                              // contando esos días el año empezaría en
                              // julio.
                              puntosPorMes: Datos.i.resumen.actividadPorMes,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
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
        Expanded(child: Text('PROGRESO', style: AppTheme.sectionTitle)),
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
}
