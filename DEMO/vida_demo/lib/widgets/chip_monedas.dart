import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../datos/fuente_datos.dart';
import '../theme.dart';
import 'moneda_animada.dart';

// ============================================================
// EL CHIP DE MONEDAS, UNO SOLO PARA TODA LA APP.
//
// Antes cada pantalla dibujaba el suyo y cada una mostraba un número
// distinto: Premios el saldo, Objetivos lo ganado en el mes. Para el
// usuario son la misma billetera, así que ver 40 en una pantalla y 3 en
// otra se lee como un error de la app.
//
// [saldoMonedas] es la única fuente: lo que se puede gastar hoy.
// ============================================================

/// Lo que el usuario tiene disponible para gastar en Premios.
int get saldoMonedas => Datos.i.resumen.monedas.saldo;

/// La "i" que abre la explicación de las monedas.
///
/// Chico y gris a propósito: es una ayuda que se busca, no un aviso que
/// tenga que interrumpir. Sale del área táctil mínima de iOS (44pt)
/// gracias al padding, aunque el ícono se vea de 18.
class BotonInfo extends StatelessWidget {
  const BotonInfo({super.key, required this.onPressed, this.semantica});

  final VoidCallback onPressed;
  final String? semantica;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    onPressed: onPressed,
    padding: const EdgeInsets.all(10),
    minimumSize: Size.zero,
    child: Semantics(
      button: true,
      label: semantica ?? 'Más información',
      child: const Icon(
        CupertinoIcons.info_circle_fill,
        size: 19,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

class ChipMonedas extends StatelessWidget {
  const ChipMonedas({super.key, required this.cantidad, this.onTap});

  final int cantidad;

  /// Si se pasa, el chip se vuelve tocable y muestra un chevron para que
  /// se note que abre algo.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Fondo PÁLIDO, no naranja sólido. La moneda ahora es dorada y sobre
    // el naranja de marca desaparecía: quedaban dos amarillos pegados.
    // Con el chip claro, lo único saturado del bloque es la moneda — que
    // es justo lo que el naranja tiene que hacer en esta app: señalar,
    // no vestir.
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.accentSecondary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.accentSecondary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MonedaAnimada(size: 22),
          const SizedBox(width: 6),
          Text(
            '$cantidad',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 13,
              color: AppColors.textPrimary,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return chip;

    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      child: chip,
    );
  }
}
