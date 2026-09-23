import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:share_plus/share_plus.dart';
import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../theme.dart';
import '../widgets/numero_animado.dart' show milesConComa;
import '../widgets/boton_relieve.dart';
import '../widgets/contadores_amigos.dart';
import '../widgets/flujos_social.dart';
import '../widgets/patrocinio.dart';
import '../widgets/ranking_widgets.dart';
import 'amigos_screen.dart';
import 'retar_screen.dart';
import 'ranking_grupo_screen.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/refresco_vida.dart';

// ============================================================
// Datos de ejemplo. Todo hardcodeado por ahora (sin backend) y
// organizado en constantes simples, para que sea fácil de
// reemplazar después con datos reales.
// ============================================================

String get nombreUsuario => Datos.i.perfil.nombre;

// ---- Duelos ----
// Los duelos NO otorgan monedas ni premios: son puramente competitivos.
bool get hayDueloActivo => Datos.i.social.duelo.activo;

/// El duelo en curso. Es un RETO con meta común: los dos van por el
/// mismo número de pasos y el mismo plazo.
Duelo get duelo => Datos.i.social.duelo;

/// Historial de duelos. Los duelos no dan monedas ni premios.
List<DueloHistorial> get _historialDuelos => Datos.i.social.historialDuelos;

// ---- Conexiones ----
// De otra persona solo se exponen racha, nivel y monedas — NUNCA sus
// pasos ni su historial crudo. La lista completa vive en AmigosScreen.

// ---- Ranking ----

/// Las dos pestañas internas de Social. Por default abre en Amigos.
enum _TabSocial { amigos, ranking }

/// Dentro de Ranking, dos mundos que NO se mezclan.
///
/// Un grupo privado lo armaste vos con gente que conocés y puede mostrar
/// puntos. La liga local es contra desconocidos, nunca muestra puntos y
/// reparte monedas. Mezclarlas en la misma lista hacía que la liga
/// pareciera un grupo más.
enum _VistaRanking { misGrupos, ligaLocal }

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  _TabSocial _tab = _TabSocial.amigos;
  _VistaRanking _vista = _VistaRanking.misGrupos;
  String _busqueda = '';

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
              // UN refresco para las dos pestañas, no uno por pestaña.
              // Amigos y Ranking comparten este scroll y además leen del
              // MISMO `Datos.i.social`, que `Datos.cargar()` recarga
              // entero: dos refrescos separados pedirían dos veces
              // exactamente lo mismo.
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
                            Text('SOCIAL', style: AppTheme.sectionTitle),
                            const SizedBox(height: 20),
                            _SelectorTab(
                              seleccionado: _tab,
                              onChanged: (tab) => setState(() => _tab = tab),
                            ),
                            const SizedBox(height: 20),
                            if (_tab == _TabSocial.amigos)
                              ..._buildAmigos(context)
                            else
                              ..._buildRanking(context),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const BottomNavBar(currentIndex: 2),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Pestaña Amigos
  // ============================================================

  /// LO PRIMERO SON LOS TRES NÚMEROS (revisión de Daniel, 22 de
  /// septiembre de 2026), como en un perfil de Instagram: cuántos te
  /// siguen, cuántas solicitudes están esperando y cuántos duelos tenés
  /// en juego. Antes la pestaña abría con el bloque de duelos y los
  /// números vivían al fondo, después del historial.
  ///
  /// Y NO HAY LISTA DE AMIGOS. Estaban los tres primeros con un "ver
  /// todos" al lado, que es la misma lista que abre el contador de
  /// arriba con un toque: la pantalla terminaba mostrando dos veces lo
  /// mismo y el duelo —lo único que está pasando AHORA— quedaba
  /// aplastado entre dos listas de gente. Para ver a alguien se entra a
  /// Seguidores o a Solicitudes.
  List<Widget> _buildAmigos(BuildContext context) {
    return [
      ContadoresAmigos(
        contadores: contadoresDeSocial(),
        onTocar: _tocarContador,
      ),
      const SizedBox(height: 18),
      // La línea de un pelo separa "quién sos en Social" de "qué está
      // pasando ahora". Es el único corte de la pestaña.
      Container(height: 0.5, color: AppColors.separador),
      const SizedBox(height: 24),
      _buildDuelosSection(context),
      const SizedBox(height: 26),
      _buildHistorialDuelos(context),
    ];
  }

  /// A dónde lleva cada número de la fila.
  ///
  /// El tercero —los duelos activos— NO navega: no es un destino sino un
  /// marcador de lo que está justo abajo, en esta misma pantalla.
  /// Mandarlo a otro lado sería abrir una pantalla para mostrar lo que
  /// ya se está viendo.
  void _tocarContador(int i) {
    if (i >= 2) return;
    _abrirAmigos(pestania: i);
  }

  // ------------------------------------------------------------
  // El duelo
  // ------------------------------------------------------------

  Widget _buildDuelosSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        hayDueloActivo
            ? _buildDueloActivoCard(context)
            : _buildSinDuelo(context),
        // El botón de retar dejó de ser un botón con relieve arriba a la
        // derecha, al lado del título (revisión de Daniel, 22 de
        // septiembre de 2026): ahí competía con el duelo que estaba
        // pasando y era lo más pesado de la pantalla. Ahora es el último
        // renglón del bloque —donde termina de leerse lo que hay y
        // empieza lo que se puede hacer—, en el mismo idioma con el que
        // iOS cierra una lista: un más, una frase y un galón.
        const SizedBox(height: 4),
        _FilaRetar(onPressed: () => abrirRetar(context)),
      ],
    );
  }

  /// El duelo en curso.
  ///
  /// ES LA PIEZA HÉROE DE SOCIAL (decisión de Daniel, 21 de septiembre
  /// de 2026). Un duelo activo es lo único de esta pantalla que está
  /// pasando AHORA y tiene reloj corriendo: si se ve igual que el resto,
  /// no se nota que hay uno.
  ///
  /// Se marca LEVANTÁNDOLA, no pintándola. Es la única pieza de la
  /// pantalla con superficie y sombra —todo lo demás va plano sobre el
  /// fondo—, y con una sola cosa levantada esa es la que se mira.
  ///
  /// LO PRIMERO ES EL RETO (decisión de Daniel, 22 de septiembre de
  /// 2026): "70,000 pasos en una semana", arriba y en grande. Un duelo
  /// es eso —un número al que los dos van—, y sin verlo el resto de la
  /// tarjeta no significa nada.
  ///
  /// Después, de cada uno: cuántos pasos lleva, qué parte de la meta es
  /// y cuántos le faltan. Antes decía "+18% sobre tu promedio" y
  /// "+12% sobre su promedio", que es información que no se puede usar:
  /// no dice cuánto falta, ni qué hay que hacer hoy, ni contra qué
  /// número se está yendo. Al tuyo se le agrega a qué RITMO tenés que ir
  /// para llegar, que es lo único que la tarjeta puede pedirte hoy.
  Widget _buildDueloActivoCard(BuildContext context) {
    final d = duelo;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        // Sombra y no borde: el contorno dibujado hacía ver la tarjeta
        // trazada con lápiz, y es justo la que tiene que despegarse.
        boxShadow: AppSombras.tarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Flexible y no suelto: con el texto del sistema en grande
              // el rótulo y el reloj se pisaban.
              Flexible(
                child: Text(
                  'DUELO ACTIVO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.subsectionTitle,
                ),
              ),
              const SizedBox(width: 10),
              _ChipTiempo(texto: d.tiempoDicho),
            ],
          ),
          const SizedBox(height: 14),
          // EL RETO, que es de lo que se trata todo lo demás.
          Text(
            '${milesConComa(d.metaPasos)} pasos',
            style: AppTheme.display(30).copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${d.plazo}, contra ${d.rivalDicho}',
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _MarcadorDuelo(
            nombre: 'Vos',
            pasos: d.pasosPropios,
            meta: d.metaPasos,
            avance: d.avancePropio,
            faltan: d.faltanPropios,
            ritmo: d.ritmoNecesario,
            propia: true,
          ),
          const SizedBox(height: 16),
          _MarcadorDuelo(
            nombre: _soloElNombre(d.rivalDicho),
            pasos: d.pasosRival,
            meta: d.metaPasos,
            avance: d.avanceRival,
            faltan: d.faltanRival,
            ritmo: null,
            propia: false,
          ),
          const SizedBox(height: 16),
          Container(height: 0.5, color: AppColors.separador),
          const SizedBox(height: 14),
          Text(
            _comoVas(d.ventaja),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            // Cómo se gana, en una oración. Sin esto, dos barras al lado
            // no dicen qué pasa si ninguno de los dos llega.
            'Gana el primero que llegue a la meta. Si el domingo no llegó '
            'ninguno, gana el que haya quedado más cerca.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// Cómo vas, en palabras y antes que los números.
  ///
  /// En PASOS, que es la unidad del reto: "vas arriba por 3,500 pasos"
  /// se entiende sin traducir nada, y además se puede comparar con lo
  /// que falta.
  String _comoVas(int ventaja) {
    if (ventaja == 0) return 'Van empatados';
    final pasos = milesConComa(ventaja.abs());
    return ventaja > 0
        ? 'Vas arriba por $pasos pasos'
        : 'Te lleva $pasos pasos';
  }

  /// "Maria Rodriguez" -> "Maria". En una barra al lado de "Vos", el
  /// apellido no agrega nada y empuja el porcentaje fuera de la fila.
  String _soloElNombre(String completo) {
    final partes = completo.trim().split(' ');
    return partes.isEmpty ? completo : partes.first;
  }

  /// Estado sin duelos activos.
  ///
  /// Si el usuario todavía no tiene amigos, ofrecerle "retar a un amigo"
  /// es mandarlo a una lista vacía: primero hay que conseguir a alguien
  /// a quien retar.
  Widget _buildSinDuelo(BuildContext context) {
    final sinAmigos = Datos.i.social.conexiones.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      // Un estado vacío SÍ necesita superficie —es un bloque, no una
      // lista—, pero va en azulNiebla y sin borde, no en blanco con
      // contorno. Así se lee como "acá todavía no hay nada" y no como
      // una tarjeta con contenido.
      decoration: BoxDecoration(
        color: AppColors.azulNiebla,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.accent.withValues(alpha: 0.12),
            child: const Icon(
              Icons.sports_kabaddi,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            sinAmigos ? 'Agregá a alguien para poder retarlo' : 'Sin duelos',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Un duelo es una meta de pasos que se ponen los dos y un '
            'plazo para llegar. No hay monedas en juego: es solo '
            'contra el otro.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          // El botón solo cuando no hay a quién retar: si hay amigos, el
          // renglón de abajo ya ofrece exactamente esa acción y dos
          // botones seguidos diciendo lo mismo se leen como un error.
          if (sinAmigos) ...[
            const SizedBox(height: 18),
            BotonRelieve(
              label: 'Agregar un amigo',
              icono: Icons.person_add_alt_1,
              anchoCompleto: true,
              onPressed: () => mostrarAgregarAmigo(context),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // El historial
  // ------------------------------------------------------------

  /// Los duelos jugados, UNA LISTA CON NOMBRES.
  ///
  /// Eran cinco avatares grises en fila, todos con el mismo ícono de
  /// persona y una W o una L en la esquina (revisión de Daniel, 22 de
  /// septiembre de 2026): no se podía saber contra quién habías jugado,
  /// que es lo único que un historial tiene para contar. Ahora es una
  /// lista con la inicial, el nombre, el usuario y cómo terminó.
  Widget _buildHistorialDuelos(BuildContext context) {
    final historial = _historialDuelos;
    // Sin duelos jugados no hay historial que mostrar: el título solo,
    // encima de una fila vacía, parece un error de carga.
    if (historial.isEmpty) return const SizedBox.shrink();

    final ganados = historial.where((d) => d.ganado).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                'HISTORIAL DE DUELOS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.subsectionTitle,
              ),
            ),
            const SizedBox(width: 10),
            const Spacer(),
            // El marcador, arriba a la derecha: es lo que un historial
            // contesta de un vistazo antes de leer fila por fila.
            Text(
              'Ganaste $ganados de ${historial.length}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < historial.length; i++) ...[
          if (i > 0) Container(height: 0.5, color: AppColors.separador),
          _FilaHistorialDuelo(duelo: historial[i]),
        ],
      ],
    );
  }

  Future<void> _abrirAmigos({int pestania = 0}) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => AmigosScreen(pestaniaInicial: pestania),
      ),
    );
    // Al volver puede haber amigos nuevos o menos solicitudes.
    if (mounted) setState(() {});
  }

  // ============================================================
  // Pestaña Ranking
  // ============================================================

  /// Ranking se parte en dos mundos que NO se mezclan: tus grupos
  /// privados, y la liga local con desconocidos. Antes convivían en la
  /// misma fila de chips, y "Liga local" parecía un grupo más — cuando en
  /// realidad se juega con otras reglas y con gente que no elegiste.
  List<Widget> _buildRanking(BuildContext context) {
    return [
      _SelectorVista(
        seleccionado: _vista,
        onChanged: (v) {
          HapticFeedback.selectionClick();
          setState(() => _vista = v);
        },
      ),
      const SizedBox(height: 24),
      if (_vista == _VistaRanking.misGrupos)
        ..._buildMisGrupos(context)
      else
        ..._buildLigaLocal(context),
    ];
  }

  // ---- Mis grupos ----

  /// Lista de grupos estilo chats: buscador arriba, una fila por grupo,
  /// y cada fila abre su tabla.
  ///
  /// Antes era un carrusel horizontal. Con tres grupos se veía bien; con
  /// doce, encontrar uno era scrollear a ciegas hacia la derecha. Una
  /// lista vertical con buscador escala sin que nada se esconda.
  List<Widget> _buildMisGrupos(BuildContext context) {
    final grupos = Datos.i.social.deConocidos;
    if (grupos.isEmpty) return [_buildSinGrupos(context)];

    final filtro = _busqueda.trim().toLowerCase();
    final visibles = filtro.isEmpty
        ? grupos
        : grupos.where((g) => g.nombre.toLowerCase().contains(filtro)).toList();

    return [
      _ResumenSocial(grupos: grupos),
      const SizedBox(height: 24),
      const EtiquetaSeccion('MIS COMPETENCIAS'),
      const SizedBox(height: 12),
      // El buscador aparece recién cuando hay suficientes grupos como
      // para necesitarlo. Con dos, solo ocupa lugar.
      if (grupos.length >= 5) ...[
        CupertinoSearchTextField(
          placeholder: 'Buscar competencia',
          onChanged: (t) => setState(() => _busqueda = t),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
      ],
      if (visibles.isEmpty)
        _buildSinResultados(context)
      else
        for (var i = 0; i < visibles.length; i++) ...[
          _FilaGrupo(grupo: visibles[i], onTap: () => _abrirGrupo(visibles[i])),
          // Igual que la lista de amigos: hairline entre renglones.
          if (i != visibles.length - 1)
            Divider(height: 0.5, thickness: 0.5, color: AppColors.separador),
        ],
      const SizedBox(height: 8),
      _FilaCrearGrupo(onPressed: _menuGrupos),
    ];
  }

  void _abrirGrupo(GrupoRanking grupo) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => RankingGrupoScreen(grupo: grupo),
      ),
    );
  }

  Widget _buildSinResultados(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Text(
        'Ninguna competencia se llama así.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    ),
  );

  Widget _buildSinGrupos(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      // Un estado vacío SÍ necesita superficie —es un bloque, no una
      // lista—, pero va en azulNiebla y sin borde, no en blanco con
      // contorno. Así se lee como "acá todavía no hay nada" y no como
      // una tarjeta con contenido.
      decoration: BoxDecoration(
        color: AppColors.azulNiebla,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
      ),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.person_2,
            size: 32,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Todavía no estás en ninguna competencia.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          BotonRelieve(
            label: 'Crear o unirme',
            icono: CupertinoIcons.plus_circle,
            onPressed: _menuGrupos,
          ),
        ],
      ),
    );
  }

  // ---- Liga local ----

  List<Widget> _buildLigaLocal(BuildContext context) {
    final liga = Datos.i.social.ligaLocal;
    if (liga == null) return [_buildSinLiga(context)];

    return [
      _buildTarjetaLiga(context, liga),
      const SizedBox(height: 16),
      _buildAccionesLiga(context, liga),
      const SizedBox(height: 24),
      const EtiquetaSeccion('TABLA DE LA ZONA'),
      const SizedBox(height: 12),
      ListaRanking(grupo: liga),
    ];
  }

  /// La tarjeta principal de la liga. Lleva naranja porque es lo distinto
  /// de la pantalla: dice de un vistazo "esto no es tu grupo privado".
  Widget _buildTarjetaLiga(BuildContext context, GrupoRanking liga) {
    final indice = liga.miembros.indexWhere((p) => p.esUsuario);
    final persona = indice < 0 ? null : liga.miembros[indice];
    final periodo = periodoDelCiclo(liga);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card,
            Color.lerp(AppColors.accent, AppColors.card, 0.93)!,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.location_solid,
                size: 16,
                color: AppColors.azulMedio,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  // La zona es el área de la liga, nunca la ubicación de
                  // nadie: la app no comparte ubicación de personas.
                  liga.zona ?? 'Tu zona',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (liga.nivelActividad != null)
                _EtiquetaNivel(nivel: liga.nivelActividad!),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            liga.nombre,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.entre),
          if (persona == null)
            Text(
              'Todavía no estás compitiendo en esta liga.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('#${indice + 1}', style: AppTheme.display(40)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'de ${liga.miembros.length} participantes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                ChipTendencia(tendencia: persona.tendencia),
              ],
            ),
          if (persona != null) ...[
            const SizedBox(height: 4),
            Text(
              '${persona.puntosPeriodo} pts ${liga.ciclo.cuando}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          // El rango de fechas, completo. Sin esto "este trimestre" es una
          // palabra: el usuario no sabe si arrancó ayer o hace dos meses,
          // y la liga se venía leyendo como si cerrara cada semana.
          if (periodo != null) ...[
            const SizedBox(height: 2),
            Text(
              periodo,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (liga.premiosMonedas.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.entre),
            Row(
              children: [
                for (var i = 0; i < liga.premiosMonedas.length; i++) ...[
                  PremioPodio(puesto: i + 1, monedas: liga.premiosMonedas[i]),
                  if (i != liga.premiosMonedas.length - 1)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ],
          // El patrocinio va DESPUÉS de las monedas y aparte: el cupón de
          // la marca se suma al premio de siempre, no lo reemplaza. Si
          // este ciclo no tiene marca vendida, no hay cinta y la tarjeta
          // se ve igual de terminada.
          if (liga.patrocinio != null) ...[
            const SizedBox(height: AppSpacing.entre),
            CintaPatrocinio(
              patrocinio: liga.patrocinio!,
              texto:
                  'Los 3 primeros se llevan además '
                  '${liga.patrocinio!.cupon}.',
            ),
          ],
        ],
      ),
    );
  }

  /// Si no estás unido, la única acción posible es unirte. Si ya estás,
  /// unirte no existe: quedan reglas y compartir.
  Widget _buildAccionesLiga(BuildContext context, GrupoRanking liga) {
    if (!liga.estoyUnido) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: () => _mostrarReglasLiga(liga),
          child: const Text('Unirme a la liga local'),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _BotonSecundario(
            icono: CupertinoIcons.doc_text,
            label: 'Ver reglas',
            onPressed: () => _mostrarReglasLiga(liga),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BotonSecundario(
            icono: CupertinoIcons.share,
            label: 'Compartir',
            onPressed: () => _compartirPosicion(liga),
          ),
        ),
      ],
    );
  }

  Widget _buildSinLiga(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      // Un estado vacío SÍ necesita superficie —es un bloque, no una
      // lista—, pero va en azulNiebla y sin borde, no en blanco con
      // contorno. Así se lee como "acá todavía no hay nada" y no como
      // una tarjeta con contenido.
      decoration: BoxDecoration(
        color: AppColors.azulNiebla,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
      ),
      child: Text(
        'Todavía no hay una liga abierta en tu zona. Te avisamos cuando '
        'haya suficiente gente cerca.',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  void _mostrarReglasLiga(GrupoRanking liga) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
      builder: (_) => _HojaReglasLiga(liga: liga),
    );
  }

  /// Abre la hoja de compartir de iOS con tu posición en la liga.
  ///
  /// Se comparte SOLO tu puesto, nunca los puntos ni los pasos de nadie
  /// más: el texto habla del usuario y no expone a los otros competidores.
  Future<void> _compartirPosicion(GrupoRanking liga) async {
    final indice = liga.miembros.indexWhere((p) => p.esUsuario);
    if (indice < 0) return;

    HapticFeedback.selectionClick();
    // En iPad la hoja de compartir necesita un ancla o revienta: se le
    // pasa el rectángulo de la pantalla desde donde salió.
    final caja = context.findRenderObject() as RenderBox?;

    await SharePlus.instance.share(
      ShareParams(
        text:
            'Voy #${indice + 1} de ${liga.miembros.length} en la '
            '${liga.nombre} de +Vida 💪',
        sharePositionOrigin: caja == null
            ? null
            : caja.localToGlobal(Offset.zero) & caja.size,
      ),
    );
  }

  // ---- Crear / unirse ----

  /// Las tres acciones sobre grupos, juntas en un action sheet de iOS.
  ///
  /// Antes "Crear grupo" era un chip más (parecía un grupo llamado "Crear
  /// grupo") y "Unirme" un botón hasta abajo de la tabla, que además no
  /// tenía nada que ver con el grupo que estabas viendo: estás adentro de
  /// Familia, no te sirve que te ofrezcan unirte a algo ahí.
  Future<void> _menuGrupos() async {
    HapticFeedback.selectionClick();

    final accion = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Competencias'),
        message: const Text(
          'Competí en tabla con gente que ya conocés: la oficina, la '
          'familia, tus amigos.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('crear'),
            child: const Text('Crear una competencia'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('unirse'),
            child: const Text('Unirme con un código'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );

    if (accion == null || !mounted) return;

    switch (accion) {
      case 'crear':
        final creado = await mostrarCrearGrupo(context);
        // Se limpia la búsqueda: si había un filtro puesto, el grupo
        // recién creado podría no coincidir y parecería que no se creó.
        if (creado && mounted) setState(() => _busqueda = '');
      case 'unirse':
        await mostrarUnirseGrupo(context);
    }
  }

  // ---- Tabla, compartida por las dos vistas ----
}

// ============================================================
// LAS PIEZAS DEL DUELO
// ============================================================

/// El reloj del duelo, como pastilla.
///
/// Pastilla y no texto suelto: es el único dato de la tarjeta que se
/// mueve solo —mañana dice un día menos— y tiene que poder leerse sin
/// buscarlo. En azul pálido, no en naranja: no es una alerta, es un
/// plazo normal.
class _ChipTiempo extends StatelessWidget {
  const _ChipTiempo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.azulNiebla,
      borderRadius: BorderRadius.circular(AppRadios.pildora),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(CupertinoIcons.clock, size: 12, color: AppColors.azulMedio),
        const SizedBox(width: 5),
        Text(
          texto,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.azulMedio,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// La inicial de una persona, en un círculo.
///
/// Reemplaza al ícono genérico de persona que llevaban todos los
/// avatares de esta pantalla: cinco círculos grises con la misma
/// silueta adentro no distinguen a nadie, y el historial de duelos
/// existe justamente para reconocer contra quién jugaste.
///
/// Sin foto: la de perfil sale de `avatar_usuario.dart` y es la del
/// usuario, no la de sus contactos. De un contacto el backend todavía
/// no manda ninguna.
class _AvatarPersona extends StatelessWidget {
  const _AvatarPersona({required this.nombre, this.tamano = 40});

  final String nombre;
  final double tamano;

  /// La primera letra del nombre. Si viene un usuario ("@mery_run") se
  /// saltea el arroba, que no dice nada.
  String get _inicial {
    final limpio = nombre.replaceFirst('@', '').trim();
    return limpio.isEmpty ? '?' : limpio[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: tamano,
    height: tamano,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.azulBruma,
      shape: BoxShape.circle,
    ),
    child: Text(
      _inicial,
      style: AppTheme.display(
        tamano * 0.42,
      ).copyWith(color: AppColors.azulMedio),
    ),
  );
}

/// Cómo va uno de los dos contra la meta del reto.
///
/// Tres datos y en este orden: cuántos pasos lleva, qué parte de la meta
/// es eso, y cuánto le falta. Es la información que se puede usar — el
/// porcentaje solo suena a informe y el total solo no dice si alcanza.
///
/// LA TUYA EN AZUL DE MARCA Y LA DEL RIVAL EN AZUL DE APOYO. No es un
/// color distinto: es el mismo azul con menos luz, igual que los niveles
/// de cashback y las muescas del rango. Quién va ganando no se dice con
/// otro color, se dice con cuánto se destaca.
class _MarcadorDuelo extends StatelessWidget {
  const _MarcadorDuelo({
    required this.nombre,
    required this.pasos,
    required this.meta,
    required this.avance,
    required this.faltan,
    required this.ritmo,
    required this.propia,
  });

  final String nombre;
  final int pasos;
  final int meta;
  final double avance;
  final int faltan;

  /// A cuántos pasos por día hay que ir para llegar. Solo se muestra el
  /// tuyo: el ritmo que le falta al rival no es algo que puedas hacer.
  final int? ritmo;

  final bool propia;

  @override
  Widget build(BuildContext context) {
    final color = propia ? AppColors.accent : AppColors.azulMedio;
    final ritmo = this.ritmo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: propia
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: propia ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              milesConComa(pasos),
              style: AppTheme.display(18).copyWith(color: color),
            ),
            Text(
              ' de ${milesConComa(meta)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadios.pildora),
          child: LinearProgressIndicator(
            value: avance,
            minHeight: 8,
            backgroundColor: AppColors.azulBruma,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          faltan <= 0
              ? '¡Llegó a la meta!'
              : ritmo == null
              ? '${propia ? 'Te faltan' : 'Le faltan'} '
                    '${milesConComa(faltan)}'
              : 'Te faltan ${milesConComa(faltan)} · '
                    '${milesConComa(ritmo)} por día',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: faltan <= 0 ? AppColors.accent : AppColors.textSecondary,
            fontWeight: faltan <= 0 ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Un duelo jugado: contra quién y cómo terminó.
class _FilaHistorialDuelo extends StatelessWidget {
  const _FilaHistorialDuelo({required this.duelo});

  final DueloHistorial duelo;

  @override
  Widget build(BuildContext context) {
    final ganado = duelo.ganado;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _AvatarPersona(nombre: duelo.dicho, tamano: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  duelo.dicho,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (duelo.nombre != null)
                  Text(
                    duelo.rival,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // La palabra entera y no una W: "W" hay que aprenderla, y en
          // español no la usa nadie. El que ganaste va en azul de marca
          // y el que perdiste apagado — sin rojo, que la app tiene que
          // transmitir calma y un duelo perdido no es un error.
          Text(
            ganado ? 'Ganaste' : 'Perdiste',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ganado ? AppColors.accent : AppColors.textSecondary,
              fontWeight: ganado ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// El renglón que cierra el bloque de duelos: retar a alguien.
///
/// Era un `BotonRelieve` arriba a la derecha, al lado del título, y a
/// ese tamaño y con ese peso competía con el duelo que estaba pasando.
/// Acá abajo es un renglón de lista de iOS —un más, una frase y un
/// galón—: se ve que es una acción, no le roba la pantalla a nada y
/// queda justo donde el ojo termina de leer lo que ya hay.
class _FilaRetar extends StatelessWidget {
  const _FilaRetar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.azulBruma,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.plus,
              size: 15,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Retar a alguien',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 15,
            color: AppColors.azulSuave,
          ),
        ],
      ),
    ),
  );
}

/// Selector de pestaña tipo "segmented control": Amigos / Ranking. Mismo
/// estilo que el selector de período de la pantalla Progress.
class _SelectorTab extends StatelessWidget {
  const _SelectorTab({required this.seleccionado, required this.onChanged});

  final _TabSocial seleccionado;
  final ValueChanged<_TabSocial> onChanged;

  static const _opciones = [
    (label: 'Amigos', valor: _TabSocial.amigos),
    (label: 'Ranking', valor: _TabSocial.ranking),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardBorder.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final opcion in _opciones)
            Expanded(
              child: _buildTab(
                context,
                opcion.label,
                opcion.valor == seleccionado,
                () => onChanged(opcion.valor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    String label,
    bool activo,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // Relleno azul sólido para el activo: es el interruptor
          // principal de la pantalla y tiene que pesar más que el
          // selector de abajo.
          color: activo ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: activo
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: activo ? AppColors.card : AppColors.textSecondary,
            fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Cómo venís en Social, arriba de todo.
///
/// Sin esto la pestaña abría con una lista de nombres y nada más: no
/// había un solo número tuyo en pantalla. Acá va lo que compite en todos
/// los grupos a la vez — tus puntos de la semana — y en cuántos vas
/// primero.
class _ResumenSocial extends StatelessWidget {
  const _ResumenSocial({required this.grupos});

  final List<GrupoRanking> grupos;

  @override
  Widget build(BuildContext context) {
    final resumen = Datos.i.resumen;
    final diferencia = resumen.puntosSemana - resumen.puntosSemanaAnterior;
    final primeros = grupos
        .where((g) => g.miembros.isNotEmpty && g.miembros.first.esUsuario)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      // Azul de marca diluido y SIN BORDE. No compite con la tarjeta
      // héroe de la otra pestaña porque nunca se ven juntas —son dos
      // pestañas—, pero tampoco se hace la protagonista: es un resumen.
      decoration: BoxDecoration(
        color: AppColors.azulNiebla,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        boxShadow: AppSombras.tarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const EtiquetaSeccion('TU SEMANA'),
              const Spacer(),
              if (resumen.rachaSemanas > 0)
                _ChipRacha(semanas: resumen.rachaSemanas),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${resumen.puntosSemana}', style: AppTheme.display(40)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(
                  'pts',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          Text(
            _comparacion(diferencia),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Divider(height: 0.5, thickness: 0.5, color: AppColors.separador),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.emoji_events,
                size: 18,
                color: AppColors.accentSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  primeros == 0
                      ? 'Todavía no vas primero en ninguna competencia'
                      : 'Vas primero en $primeros de ${grupos.length} '
                            '${grupos.length == 1 ? "competencia" : "competencias"}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _comparacion(int diferencia) {
    if (diferencia == 0) return 'Igual que la semana pasada';
    final signo = diferencia > 0 ? '+' : '−';
    final palabra = diferencia > 0 ? 'más' : 'menos';
    return '$signo${diferencia.abs()} pts $palabra que la semana pasada';
  }
}

/// La racha, como pastilla. Naranja: es un detalle chico que tiene que
/// saltar a la vista.
class _ChipRacha extends StatelessWidget {
  const _ChipRacha({required this.semanas});

  final int semanas;

  @override
  Widget build(BuildContext context) => ShadBadge.raw(
    variant: ShadBadgeVariant.secondary,
    backgroundColor: AppColors.accentSecondary.withValues(alpha: 0.18),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_fire_department,
          size: 14,
          color: AppColors.accentSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          '$semanas ${semanas == 1 ? "semana" : "semanas"}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

/// Selector de vista dentro de Ranking: Mis grupos / Liga local.
///
/// Deliberadamente NO es otra píldora. Apilado debajo del selector de
/// Amigos/Ranking se veían como dos controles del mismo peso, y no lo
/// son: arriba se cambia de sección, acá solo se cambia de tabla. El
/// subrayado dice "estás adentro de algo" en vez de "elegí una de dos".
class _SelectorVista extends StatelessWidget {
  const _SelectorVista({required this.seleccionado, required this.onChanged});

  final _VistaRanking seleccionado;
  final ValueChanged<_VistaRanking> onChanged;

  static const _opciones = [
    (
      label: 'Mis competencias',
      icono: CupertinoIcons.person_2_fill,
      valor: _VistaRanking.misGrupos,
    ),
    (
      label: 'Liga local',
      icono: CupertinoIcons.location_solid,
      valor: _VistaRanking.ligaLocal,
    ),
  ];

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final o in _opciones)
        _Pestania(
          label: o.label,
          icono: o.icono,
          activa: o.valor == seleccionado,
          onTap: () => onChanged(o.valor),
        ),
    ],
  );
}

class _Pestania extends StatelessWidget {
  const _Pestania({
    required this.label,
    required this.icono,
    required this.activa,
    required this.onTap,
  });

  final String label;
  final IconData icono;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = activa ? AppColors.accent : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icono, size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: activa ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            // El subrayado crece desde el centro al cambiar de pestaña,
            // en vez de aparecer de golpe.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 3,
              width: activa ? 28 : 0,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una fila de la lista de grupos. Se lee como un chat: inicial, nombre,
/// una línea de contexto, y el chevron que dice que abre algo.
class _FilaGrupo extends StatelessWidget {
  const _FilaGrupo({required this.grupo, required this.onTap});

  final GrupoRanking grupo;
  final VoidCallback onTap;

  /// Cuánta gente hay y cuánto le queda al ciclo.
  ///
  /// Ahora aplica también a la liga local: desde que corre por trimestre
  /// tiene una fecha de cierre real. Antes se la excluía porque se
  /// reiniciaba sola cada semana y decirle "quedan 3 días" era mentir.
  static String _subtituloGrupo(GrupoRanking g) {
    final n = g.miembros.length;
    final base = '$n ${n == 1 ? "integrante" : "integrantes"}';

    final cierra = g.cierra;
    if (cierra == null) return base;

    final dias = cierra.difference(DateTime.now()).inDays;
    if (dias < 0) return '$base · terminó';
    if (dias == 0) return '$base · termina hoy';
    if (dias == 1) return '$base · queda 1 día';
    if (dias < 30) return '$base · quedan $dias días';

    final meses = (dias / 30).round();
    return '$base · ${meses == 1 ? "queda 1 mes" : "quedan $meses meses"}';
  }

  @override
  Widget build(BuildContext context) {
    final posicion = grupo.miembros.indexWhere((m) => m.esUsuario) + 1;

    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      child: Container(
        // Igual que la fila de un amigo: sin caja. Una lista de grupos
        // es una lista, y meter cada renglón en su propia tarjeta hacía
        // que la pestaña Ranking se viera como un formulario.
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: Colors.transparent,
        child: Row(
          children: [
            _AvatarGrupo(grupo: grupo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grupo.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _subtituloGrupo(grupo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Sin abrir el grupo ya sabés cómo vas: eso es lo que hace
            // que la lista sirva y no sea solo un índice.
            if (posicion > 0) _BadgePosicion(posicion: posicion),
            const SizedBox(width: 4),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// La inicial del grupo en un círculo.
///
/// El color sale del nombre, no de una lista fija: así dos grupos
/// distintos casi nunca se ven iguales, y el mismo grupo siempre tiene el
/// mismo color. Todos son tonos del azul de marca, para que la pantalla
/// no se vuelva un arcoíris.
class _AvatarGrupo extends StatelessWidget {
  const _AvatarGrupo({required this.grupo});

  final GrupoRanking grupo;

  static const _tonos = [
    AppColors.nivel4,
    AppColors.nivel3,
    AppColors.nivel2,
    AppColors.nivel1,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _tonos[grupo.nombre.hashCode.abs() % _tonos.length];

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        grupo.nombre.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Tu puesto en el grupo. Naranja si estás en el podio: es un detalle
/// chico que tiene que saltar a la vista.
class _BadgePosicion extends StatelessWidget {
  const _BadgePosicion({required this.posicion});

  final int posicion;

  @override
  Widget build(BuildContext context) {
    final enPodio = posicion <= 3;
    final color = enPodio ? AppColors.accentSecondary : AppColors.accent;

    return ShadBadge.raw(
      variant: ShadBadgeVariant.secondary,
      backgroundColor: color.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (enPodio) ...[
            Icon(Icons.emoji_events, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            '#$posicion',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// La última fila de la lista: crear o unirse. Va al final, después de lo
/// que ya existe, para no competir con los grupos del usuario.
class _FilaCrearGrupo extends StatelessWidget {
  const _FilaCrearGrupo({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.plus_circle,
            size: 22,
            color: AppColors.accent,
          ),
          const SizedBox(width: 12),
          Text(
            'Crear o unirme a una competencia',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

/// El nivel de actividad de la liga, como etiqueta chica.
class _EtiquetaNivel extends StatelessWidget {
  const _EtiquetaNivel({required this.nivel});

  final String nivel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.accentSecondary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      nivel,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.accentSecondary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Botón secundario de la liga: ver reglas, compartir.
class _BotonSecundario extends StatelessWidget {
  const _BotonSecundario({
    required this.icono,
    required this.label,
    required this.onPressed,
  });

  final IconData icono;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Las reglas de la liga local, en una hoja aparte.
///
/// Antes este texto vivía siempre visible arriba de la tabla. Es
/// importante la primera vez y ruido a partir de la segunda: acá está
/// cuando se busca, y no estorba el resto del tiempo.
class _HojaReglasLiga extends StatelessWidget {
  const _HojaReglasLiga({required this.liga});

  final GrupoRanking liga;

  /// Cada cuánto cierra la liga, con las fechas del ciclo en curso.
  ///
  /// Sale de los datos y no de una frase fija: el texto viejo decía
  /// "cierra el domingo y arranca una nueva el lunes", que era el ciclo
  /// semanal que la revisión de UI marcó como bug.
  static String _reglaDelCiclo(GrupoRanking liga) {
    final base = 'La liga es ${liga.ciclo.adjetivo}';
    final periodo = periodoDelCiclo(liga);
    if (periodo == null) return '$base.';

    // "Del 1 de julio…" en minúscula, que va a mitad de la oración.
    final rango = periodo[0].toLowerCase() + periodo.substring(1);
    return '$base: el ciclo en curso va $rango, y al cerrar arranca uno '
        'nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Cómo funciona la liga local',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.entre),
              _Regla(
                icono: CupertinoIcons.location_solid,
                texto:
                    'Competís con gente de ${liga.zona ?? "tu zona"} que se '
                    'mueve parecido a vos.',
                estilo: estilo,
              ),
              _Regla(
                icono: CupertinoIcons.eye_slash,
                texto:
                    'Nadie ve los puntos de nadie, solo la posición. Vos sí '
                    'ves los tuyos.',
                estilo: estilo,
              ),
              _Regla(
                icono: CupertinoIcons.money_dollar_circle,
                texto:
                    'Los tres primeros se llevan MONEDAS, que se gastan en '
                    'Premios. Nunca puntos: los puntos son de tu cashback y '
                    'no se ganan compitiendo.',
                estilo: estilo,
              ),
              // La marca del ciclo, si hay: es un premio más, y quien
              // pregunta las reglas está preguntando justamente qué gana.
              if (liga.patrocinio != null)
                _Regla(
                  icono: CupertinoIcons.ticket,
                  texto:
                      'Este trimestre lo patrocina ${liga.patrocinio!.marca}: '
                      'los tres primeros se llevan además '
                      '${liga.patrocinio!.cupon}.',
                  estilo: estilo,
                ),
              _Regla(
                icono: CupertinoIcons.clock,
                texto: _reglaDelCiclo(liga),
                estilo: estilo,
              ),
              const SizedBox(height: AppSpacing.entre),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Regla extends StatelessWidget {
  const _Regla({required this.icono, required this.texto, this.estilo});

  final IconData icono;
  final String texto;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(child: Text(texto, style: estilo)),
      ],
    ),
  );
}
