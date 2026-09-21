import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../datos/fuente_datos.dart';
import '../theme.dart';

// ============================================================
// AMIGOS · SOLICITUDES · ENVIADAS.
//
// Los tres números que resumen tu vida social en la app, como la fila de
// un perfil de Instagram. Vive acá y no dentro de una pantalla porque se
// usa en dos lugares con dos comportamientos distintos:
//
//   Social  -> cada número NAVEGA a esa lista
//   Amigos  -> cada número es una PESTAÑA de la pantalla
//
// Lo que cambia es a dónde va el toque; lo que se ve tiene que ser
// idéntico, o parecen dos componentes distintos que dicen lo mismo.
// ============================================================

class ContadoresAmigos extends StatelessWidget {
  const ContadoresAmigos({super.key, required this.onTocar, this.seleccionado});

  /// Recibe 0 (amigos), 1 (recibidas) o 2 (enviadas).
  final ValueChanged<int> onTocar;

  /// Cuál está abierto. Null cuando el componente solo navega y no
  /// representa un estado — que es el caso de Social.
  final int? seleccionado;

  @override
  Widget build(BuildContext context) {
    final social = Datos.i.social;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Contador(
                numero: social.conexiones.length,
                etiqueta: 'Amigos',
                activo: seleccionado == 0,
                onTap: () => onTocar(0),
              ),
            ),
            const VerticalDivider(width: 1, color: AppColors.cardBorder),
            Expanded(
              child: _Contador(
                numero: social.solicitudesRecibidas.length,
                etiqueta: 'Solicitudes',
                // El punto naranja es lo que hace que se note que hay
                // algo esperando: un número solo se pierde entre tres.
                conAviso: social.solicitudesRecibidas.isNotEmpty,
                activo: seleccionado == 1,
                onTap: () => onTocar(1),
              ),
            ),
            const VerticalDivider(width: 1, color: AppColors.cardBorder),
            Expanded(
              child: _Contador(
                numero: social.solicitudesEnviadas.length,
                etiqueta: 'Enviadas',
                activo: seleccionado == 2,
                onTap: () => onTocar(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({
    required this.numero,
    required this.etiqueta,
    required this.activo,
    required this.onTap,
    this.conAviso = false,
  });

  final int numero;
  final String etiqueta;
  final bool activo;
  final bool conAviso;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = activo ? AppColors.accent : AppColors.textPrimary;

    return CupertinoButton(
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(vertical: 10),
      minimumSize: Size.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                '$numero',
                style: AppTheme.display(24).copyWith(color: color),
              ),
              if (conAviso)
                Positioned(
                  right: -9,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accentSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: activo ? AppColors.accent : AppColors.textSecondary,
              fontWeight: activo ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          // El subrayado marca la pestaña abierta sin cambiar el fondo:
          // los tres tienen que verse comparables entre sí.
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: 3,
            width: activo ? 26 : 0,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
