import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../datos/modelos.dart';
import '../theme.dart';

// ============================================================
// INVITAR AMIGOS A UN GRUPO.
//
// Vive adentro del grupo y no en el menú general: el código es DE ESTE
// grupo, así que solo tiene sentido cuando ya estás parado en él. Antes
// "Invitar contactos" estaba en el menú global, donde no había forma de
// saber a cuál de tus grupos estabas invitando.
// ============================================================

void mostrarInvitarAlGrupo(BuildContext context, GrupoRanking grupo) {
  HapticFeedback.selectionClick();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
    builder: (_) => _HojaInvitar(grupo: grupo),
  );
}

class _HojaInvitar extends StatefulWidget {
  const _HojaInvitar({required this.grupo});

  final GrupoRanking grupo;

  @override
  State<_HojaInvitar> createState() => _HojaInvitarState();
}

class _HojaInvitarState extends State<_HojaInvitar> {
  /// El botón cambia a "Copiado" un rato y vuelve solo.
  ///
  /// Antes esto era un `SnackBar`, que se dibuja abajo de todo y quedaba
  /// TAPADO por la hoja: el código se copiaba pero no se veía ninguna
  /// confirmación, así que parecía que el botón no hacía nada.
  bool _copiado = false;

  /// True cuando el portapapeles no aceptó el texto. Sin esto, un fallo
  /// del sistema se ve igual que un éxito y el usuario se queda esperando
  /// un código que nunca llegó.
  bool _fallo = false;

  Timer? _volver;

  GrupoRanking get grupo => widget.grupo;

  @override
  void dispose() {
    _volver?.cancel();
    super.dispose();
  }

  String get _mensaje =>
      // Ya no dice "esta semana": una competencia puede durar hasta
      // tres meses, así que prometer una semana sería mentirle a quien
      // recibe la invitación.
      'Te invito a "${grupo.nombre}" en +Vida. Entrá con el código '
      '${grupo.codigoInvitacion} y competí conmigo.';

  /// Copia el código y COMPRUEBA que haya quedado.
  ///
  /// `Clipboard.setData` no avisa cuando falla: en web el navegador puede
  /// negar el permiso y el Future igual se completa bien. Por eso se lee
  /// de vuelta el portapapeles y se compara.
  Future<void> _copiar() async {
    final codigo = grupo.codigoInvitacion;
    var salioBien = false;

    try {
      await Clipboard.setData(ClipboardData(text: codigo));
      final leido = await Clipboard.getData(Clipboard.kTextPlain);
      // Si no se puede leer de vuelta (permiso de lectura negado, que es
      // aparte del de escritura) no se asume que falló: solo se descarta
      // cuando devuelve algo distinto.
      salioBien = leido?.text == null || leido!.text == codigo;
    } catch (_) {
      salioBien = false;
    }

    if (!mounted) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _copiado = salioBien;
      _fallo = !salioBien;
    });

    _volver?.cancel();
    _volver = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copiado = _fallo = false);
    });
  }

  Future<void> _compartir(BuildContext context) async {
    final caja = context.findRenderObject() as RenderBox?;

    await SharePlus.instance.share(
      ShareParams(
        text: _mensaje,
        subject: 'Unite a ${grupo.nombre} en +Vida',
        // En iPad la hoja de compartir necesita un ancla o revienta.
        sharePositionOrigin: caja == null
            ? null
            : caja.localToGlobal(Offset.zero) & caja.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                'Invitar amigos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pasales este código y entran directo a ${grupo.nombre}.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.seccion),
              // El código también copia al tocarlo: es lo primero que la
              // mano intenta.
              GestureDetector(
                onTap: _copiar,
                child: _Codigo(codigo: grupo.codigoInvitacion),
              ),
              if (_fallo) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      CupertinoIcons.exclamationmark_circle,
                      size: 15,
                      color: AppColors.accentSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tu sistema no nos dejó copiar. Mantené presionado '
                        'el código para seleccionarlo, o usá Compartir.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.seccion),
              Row(
                children: [
                  Expanded(
                    child: _BotonAccion(
                      icono: _copiado
                          ? CupertinoIcons.checkmark_alt
                          : CupertinoIcons.doc_on_doc,
                      label: _copiado ? 'Copiado' : 'Copiar',
                      relleno: false,
                      onPressed: _copiar,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BotonAccion(
                      icono: CupertinoIcons.share,
                      label: 'Compartir',
                      relleno: true,
                      onPressed: () => _compartir(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.entre),
              Text(
                // Que quede claro qué está pasando: invitar no es lo
                // mismo que mostrarle tus datos a alguien.
                grupo.mostrarPuntos
                    ? 'En esta competencia todos ven los puntos de cada quien.'
                    : 'En esta competencia solo se ve la posición, no los '
                          'puntos.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El código, grande y separado por letra para que se pueda dictar por
/// teléfono sin equivocarse.
class _Codigo extends StatelessWidget {
  const _Codigo({required this.codigo});

  final String codigo;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 22),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
    ),
    child: Center(
      // SelectableText y no Text: si el portapapeles del sistema falla,
      // siempre queda el camino de seleccionarlo a mano.
      child: SelectableText(
        codigo,
        style: AppTheme.display(32).copyWith(
          color: AppColors.accent,
          letterSpacing: 8,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ),
  );
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({
    required this.icono,
    required this.label,
    required this.relleno,
    required this.onPressed,
  });

  final IconData icono;
  final String label;

  /// El relleno azul marca la acción principal. Compartir lo es:
  /// copiar deja el código en el portapapeles y todavía hay que ir a
  /// pegarlo a algún lado.
  final bool relleno;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorTexto = relleno ? AppColors.card : AppColors.accent;

    return CupertinoButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: relleno ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: relleno ? AppColors.accent : AppColors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 16, color: colorTexto),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorTexto,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
