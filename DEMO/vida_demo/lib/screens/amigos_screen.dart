import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/boton_relieve.dart';
import '../widgets/contadores_amigos.dart';
import '../widgets/flujos_social.dart';

// ============================================================
// AMIGOS, SOLICITUDES Y ENVIADAS.
//
// Tres pestañas, como en Instagram: la lista, lo que te llegó y lo que
// mandaste. Antes "Amigos" era una lista suelta en Social sin contador y
// sin forma de ver quién te había pedido.
//
// REGLA DURA: de alguien que todavía NO es tu contacto solo se muestra
// nombre, usuario y amigos en común. Racha, nivel y monedas se ven recién
// cuando la amistad existe — no se le entrega el nivel de actividad de
// alguien a quien no lo aceptó.
//
// TODO: no hay backend de amistades. Aceptar, rechazar y cancelar solo
// mueven listas en memoria: al cerrar la app vuelve todo como estaba.
// ============================================================

enum _Pestania { amigos, recibidas, enviadas }

class AmigosScreen extends StatefulWidget {
  const AmigosScreen({super.key, this.pestaniaInicial = 0});

  /// Con qué pestaña abre. Social entra directo a Solicitudes cuando el
  /// usuario toca ese contador.
  final int pestaniaInicial;

  @override
  State<AmigosScreen> createState() => _AmigosScreenState();
}

class _AmigosScreenState extends State<AmigosScreen> {
  late _Pestania _tab = _Pestania.values[widget.pestaniaInicial];
  String _busqueda = '';

  DatosSociales get _social => Datos.i.social;

  void _aceptar(Solicitud s) {
    HapticFeedback.mediumImpact();
    setState(() {
      _social.solicitudesRecibidas.remove(s);
      // Entra como conexión nueva: sin racha ni monedas todavía, porque
      // eso lo trae el servidor, no la solicitud.
      _social.conexiones.add(
        Conexion(
          nombre: s.nombre,
          handle: s.handle,
          rachaSemanas: 0,
          nivel: 0,
          monedasTotales: 0,
        ),
      );
    });
    _avisar('${s.nombre} ya es tu amigo');
  }

  void _rechazar(Solicitud s) {
    HapticFeedback.selectionClick();
    setState(() => _social.solicitudesRecibidas.remove(s));
    _avisar('Solicitud rechazada');
  }

  void _cancelar(Solicitud s) {
    HapticFeedback.selectionClick();
    setState(() => _social.solicitudesEnviadas.remove(s));
    _avisar('Cancelaste tu solicitud a ${s.nombre}');
  }

  Future<void> _eliminar(Conexion c) async {
    final confirmado = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('¿Eliminar a ${c.nombre}?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Van a dejar de verse en tus grupos y duelos.'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;
    setState(() => _social.conexiones.remove(c));
    _avisar('Eliminaste a ${c.nombre}');
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: AppHeader(showBackButton: true),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amigos', style: AppTheme.sectionTitle),
                          const SizedBox(height: 18),
                          ContadoresAmigos(
                            seleccionado: _tab.index,
                            onTocar: (i) {
                              HapticFeedback.selectionClick();
                              setState(() => _tab = _Pestania.values[i]);
                            },
                          ),
                          const SizedBox(height: 18),
                          _Buscador(
                            onChanged: (t) => setState(() => _busqueda = t),
                          ),
                          const SizedBox(height: 10),
                          BotonRelieve(
                            label: 'Agregar un amigo',
                            icono: CupertinoIcons.person_add,
                            anchoCompleto: true,
                            onPressed: () => mostrarAgregarAmigo(context),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: _buildLista(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _coincide(String nombre, String handle) {
    final t = _busqueda.trim().toLowerCase();
    return t.isEmpty ||
        nombre.toLowerCase().contains(t) ||
        handle.toLowerCase().contains(t);
  }

  Widget _buildLista() {
    switch (_tab) {
      case _Pestania.amigos:
        final lista = _social.conexiones
            .where((c) => _coincide(c.nombre, c.handle))
            .toList();
        if (lista.isEmpty) {
          // Con búsqueda puesta el vacío es "no encontré", sin ella es
          // "todavía no tenés". Son dos cosas distintas y el botón de
          // agregar solo tiene sentido en la segunda.
          if (_busqueda.trim().isNotEmpty) {
            return _vacio(
              CupertinoIcons.search,
              'Ningún amigo tuyo se llama así.',
            );
          }
          return _vacio(
            CupertinoIcons.person_2,
            'Aún no tenés amigos. Agregá a alguien con su usuario y '
            'compará rachas.',
            accion: 'Agregar',
            onAccion: () => mostrarAgregarAmigo(context),
          );
        }
        return SliverList.separated(
          itemCount: lista.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _FilaAmigo(
            conexion: lista[i],
            onEliminar: () => _eliminar(lista[i]),
          ),
        );

      case _Pestania.recibidas:
        final lista = _social.solicitudesRecibidas
            .where((s) => _coincide(s.nombre, s.handle))
            .toList();
        if (lista.isEmpty) {
          return _vacio(
            CupertinoIcons.bell,
            'No tenés solicitudes pendientes.',
          );
        }
        return SliverList.separated(
          itemCount: lista.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _FilaSolicitud(
            solicitud: lista[i],
            recibida: true,
            onPrincipal: () => _aceptar(lista[i]),
            onSecundaria: () => _rechazar(lista[i]),
          ),
        );

      case _Pestania.enviadas:
        final lista = _social.solicitudesEnviadas
            .where((s) => _coincide(s.nombre, s.handle))
            .toList();
        if (lista.isEmpty) {
          return _vacio(
            CupertinoIcons.paperplane,
            'No tenés solicitudes esperando respuesta.',
          );
        }
        return SliverList.separated(
          itemCount: lista.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _FilaSolicitud(
            solicitud: lista[i],
            recibida: false,
            onSecundaria: () => _cancelar(lista[i]),
          ),
        );
    }
  }

  Widget _vacio(
    IconData icono,
    String texto, {
    String? accion,
    VoidCallback? onAccion,
  }) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      child: Column(
        children: [
          Icon(icono, size: 30, color: AppColors.textSecondary),
          const SizedBox(height: 14),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (accion != null && onAccion != null) ...[
            const SizedBox(height: 20),
            BotonRelieve(
              label: accion,
              icono: CupertinoIcons.person_add,
              onPressed: onAccion,
            ),
          ],
        ],
      ),
    ),
  );
}

// ============================================================
// Piezas
// ============================================================

class _Buscador extends StatelessWidget {
  const _Buscador({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => CupertinoSearchTextField(
    placeholder: 'Buscar por nombre o usuario',
    onChanged: onChanged,
    style: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
  );
}

/// Un amigo ya aceptado. Acá SÍ se ven racha, nivel y monedas.
class _FilaAmigo extends StatelessWidget {
  const _FilaAmigo({required this.conexion, required this.onEliminar});

  final Conexion conexion;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          _Avatar(nombre: conexion.nombre),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conexion.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  conexion.handle,
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
          if (conexion.rachaSemanas > 0)
            _ChipRacha(semanas: conexion.rachaSemanas),
          _MenuAmigo(nombre: conexion.nombre, onEliminar: onEliminar),
        ],
      ),
    );
  }
}

/// Una solicitud, recibida o enviada.
class _FilaSolicitud extends StatelessWidget {
  const _FilaSolicitud({
    required this.solicitud,
    required this.recibida,
    required this.onSecundaria,
    this.onPrincipal,
  });

  final Solicitud solicitud;

  /// Recibida trae dos botones (Aceptar / Rechazar). Enviada trae uno
  /// solo (Cancelar): no hay nada que aceptar de tu propio pedido.
  final bool recibida;

  final VoidCallback? onPrincipal;
  final VoidCallback onSecundaria;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Avatar(nombre: solicitud.nombre),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      solicitud.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      // Los amigos en común son lo único que ayuda a
                      // decidir si aceptar a alguien que no reconocés.
                      solicitud.amigosEnComun == 0
                          ? solicitud.handle
                          : '${solicitud.handle} · '
                                '${solicitud.amigosEnComun} en común',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!recibida)
                ShadBadge.raw(
                  variant: ShadBadgeVariant.secondary,
                  backgroundColor: AppColors.cardBorder.withValues(alpha: 0.7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  child: Text(
                    'Pendiente',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (recibida) ...[
                Expanded(
                  child: BotonRelieve(
                    label: 'Aceptar',
                    compacto: true,
                    anchoCompleto: true,
                    onPressed: onPrincipal!,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: BotonRelieve(
                  label: recibida ? 'Rechazar' : 'Cancelar',
                  // Gris y no rojo: rechazar no es destructivo, la
                  // solicitud se puede volver a mandar.
                  color: AppColors.textSecondary,
                  compacto: true,
                  anchoCompleto: true,
                  onPressed: onSecundaria,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Inicial en círculo. El tono sale del nombre: el mismo amigo siempre se
/// ve igual, y dos amigos distintos casi nunca coinciden.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.nombre});

  final String nombre;

  static const _tonos = [
    AppColors.nivel4,
    AppColors.nivel3,
    AppColors.nivel2,
    AppColors.nivel1,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _tonos[nombre.hashCode.abs() % _tonos.length];

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        nombre.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ChipRacha extends StatelessWidget {
  const _ChipRacha({required this.semanas});

  final int semanas;

  @override
  Widget build(BuildContext context) => ShadBadge.raw(
    variant: ShadBadgeVariant.secondary,
    backgroundColor: AppColors.accentSecondary.withValues(alpha: 0.16),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_fire_department,
          size: 13,
          color: AppColors.accentSecondary,
        ),
        const SizedBox(width: 3),
        Text(
          '$semanas sem',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _MenuAmigo extends StatelessWidget {
  const _MenuAmigo({required this.nombre, required this.onEliminar});

  final String nombre;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    minimumSize: Size.zero,
    onPressed: () => showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(nombre),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              onEliminar();
            },
            child: const Text('Eliminar amigo'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    ),
    child: Semantics(
      button: true,
      label: 'Opciones de $nombre',
      child: const Icon(
        CupertinoIcons.ellipsis,
        size: 18,
        color: AppColors.textSecondary,
      ),
    ),
  );
}
