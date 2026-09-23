import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/fuente_datos.dart';
import '../datos/modelos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/boton_relieve.dart';
import '../widgets/numero_animado.dart' show milesConComa;

// ============================================================
// RETAR A ALGUIEN.
//
// Una lista de tus amigos y, en cada renglón, un botón que dice Retar.
// Nada más.
//
// POR QUÉ NO ES LA PANTALLA DE AMIGOS (decisión de Daniel, 22 de
// septiembre de 2026). "Retar a alguien" llevaba ahí, y esa pantalla
// tiene pestañas, buscador, solicitudes y un botón de agregar: el que
// entró a retar a un amigo se encontraba administrando su lista de
// contactos. Acá no hay nada que administrar — solo elegir contra quién.
//
// EL RETO ES EL MISMO PARA LOS DOS. Se confirma antes de mandarlo, con
// la meta y el plazo escritos: un duelo es un número al que los dos van,
// y mandarlo sin decir cuál sería retar a alguien a nada.
//
// [PENDIENTE: elegir la meta y el plazo al armar el duelo. Hoy sale el
// reto por defecto. Cuando el backend acepte duelos, acá van un par de
// metas para elegir — y tienen que ser alcanzables para los dos, porque
// un duelo de pasos crudos lo gana siempre el que camina más.]
// ============================================================

/// La meta del reto que se manda por defecto.
const int metaDelRetoPorDefecto = 70000;

/// En cuánto tiempo.
const String plazoDelRetoPorDefecto = 'en una semana';

/// Abre la pantalla para retar a alguien.
Future<void> abrirRetar(BuildContext context) => Navigator.of(
  context,
).push(CupertinoPageRoute<void>(builder: (_) => const RetarScreen()));

class RetarScreen extends StatefulWidget {
  const RetarScreen({super.key});

  @override
  State<RetarScreen> createState() => _RetarScreenState();
}

class _RetarScreenState extends State<RetarScreen> {
  List<Conexion> get _amigos => Datos.i.social.conexiones;

  /// Confirma antes de mandar: es un mensaje que le llega a otra
  /// persona, y esas no se mandan sin querer.
  Future<void> _retar(Conexion quien) async {
    HapticFeedback.selectionClick();

    final confirmado = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('¿Retar a ${quien.nombre}?'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Van los dos por ${milesConComa(metaDelRetoPorDefecto)} pasos '
            '$plazoDelRetoPorDefecto. Gana el primero que llegue.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Retar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    // Se vuelve a Social con el aviso puesto: quedarse en la lista
    // después de mandar el reto invita a mandar otro.
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Le mandamos el reto a ${quien.nombre}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amigos = _amigos;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: AppHeader(showBackButton: true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RETAR', style: AppTheme.sectionTitle),
                  const SizedBox(height: 2),
                  Text(
                    // El reto, dicho una sola vez y arriba: es igual para
                    // todos los renglones de abajo.
                    '${milesConComa(metaDelRetoPorDefecto)} pasos '
                    '$plazoDelRetoPorDefecto. Elegí contra quién.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: amigos.isEmpty
                  ? const _SinAmigos()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: amigos.length,
                      // Una lista es una lista: renglones separados por
                      // una línea de un pelo, no una caja por persona.
                      separatorBuilder: (_, _) =>
                          Container(height: 0.5, color: AppColors.separador),
                      itemBuilder: (_, i) => _FilaRetable(
                        conexion: amigos[i],
                        onRetar: () => _retar(amigos[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un amigo y su botón de retar.
class _FilaRetable extends StatelessWidget {
  const _FilaRetable({required this.conexion, required this.onRetar});

  final Conexion conexion;
  final VoidCallback onRetar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        _Inicial(nombre: conexion.nombre),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conexion.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                conexion.handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        BotonRelieve(label: 'Retar', compacto: true, onPressed: onRetar),
      ],
    ),
  );
}

/// La inicial en un círculo, igual que en el historial de duelos.
class _Inicial extends StatelessWidget {
  const _Inicial({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    final limpio = nombre.replaceFirst('@', '').trim();

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.azulBruma,
        shape: BoxShape.circle,
      ),
      child: Text(
        limpio.isEmpty ? '?' : limpio[0].toUpperCase(),
        style: AppTheme.display(17).copyWith(color: AppColors.azulMedio),
      ),
    );
  }
}

/// Sin amigos no hay a quién retar, y no hay nada que hacer en esta
/// pantalla: se dice y se manda para atrás.
class _SinAmigos extends StatelessWidget {
  const _SinAmigos();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.person_2,
            size: 38,
            color: AppColors.azulSuave,
          ),
          const SizedBox(height: 12),
          Text(
            'Todavía no tenés a quién retar',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Agregá a alguien desde Amigos y volvé.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}
