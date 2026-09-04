import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/boton_relieve.dart';
import '../widgets/hoja_invitar_grupo.dart';
import '../widgets/ranking_widgets.dart';

// ============================================================
// LA TABLA DE UN GRUPO.
//
// Antes el ranking del grupo vivía dentro de Social, debajo de un
// carrusel: con muchos grupos había que scrollear a la derecha para
// encontrar el que uno quería. Ahora Social lista los grupos (buscables)
// y cada uno abre acá, como un chat.
// ============================================================

class RankingGrupoScreen extends StatelessWidget {
  const RankingGrupoScreen({super.key, required this.grupo});

  final GrupoRanking grupo;

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      grupo.nombre,
                      style: AppTheme.sectionTitle.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitulo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.seccion),
                    ResumenGrupo(grupo: grupo, mostrarNombre: false),
                    // Invitar vive acá y no en el menú general: el código
                    // es de ESTE grupo.
                    if (grupo.tipo == TipoGrupo.conocidos) ...[
                      const SizedBox(height: 12),
                      _BotonInvitar(grupo: grupo),
                    ],
                    const SizedBox(height: AppSpacing.seccion),
                    const EtiquetaSeccion('TABLA DE LA SEMANA'),
                    const SizedBox(height: 12),
                    // Un grupo recién creado tiene un solo integrante:
                    // una "tabla" de uno no es una tabla, es una espera.
                    if (grupo.miembros.length <= 1)
                      _SoloVos(grupo: grupo)
                    else
                      ListaRanking(grupo: grupo),
                    if (!grupo.mostrarPuntos) ...[
                      const SizedBox(height: AppSpacing.entre),
                      const _NotaPrivacidad(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _subtitulo {
    final n = grupo.miembros.length;
    return '$n ${n == 1 ? "integrante" : "integrantes"}';
  }
}

class _BotonInvitar extends StatelessWidget {
  const _BotonInvitar({required this.grupo});

  final GrupoRanking grupo;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: CupertinoButton(
      onPressed: () => mostrarInvitarAlGrupo(context, grupo),
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.person_add,
              size: 17,
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
            Text(
              'Invitar amigos',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Un grupo donde todavía no entró nadie más.
class _SoloVos extends StatelessWidget {
  const _SoloVos({required this.grupo});

  final GrupoRanking grupo;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      children: [
        const Icon(
          CupertinoIcons.person_2,
          size: 28,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 12),
        Text(
          'Por ahora estás solo acá',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pasales el código a tus amigos para que entren y arranque la '
          'tabla.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        BotonRelieve(
          label: 'Invitar amigos',
          icono: CupertinoIcons.person_add,
          onPressed: () => mostrarInvitarAlGrupo(context, grupo),
        ),
      ],
    ),
  );
}

/// Cuando el grupo eligió no mostrar puntos, hay que decirlo: si no, la
/// tabla parece incompleta o rota.
class _NotaPrivacidad extends StatelessWidget {
  const _NotaPrivacidad();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(
        CupertinoIcons.eye_slash,
        size: 14,
        color: AppColors.textSecondary,
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          'Este grupo eligió no mostrar los puntos de cada quien. Solo se '
          've la posición.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
      ),
    ],
  );
}
