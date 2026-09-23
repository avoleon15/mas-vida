import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../datos/fuente_datos.dart';
import '../theme.dart';

// ============================================================
// LA FILA DE TRES NÚMEROS.
//
// Lo primero que se ve al entrar a Social, como la fila de un perfil de
// Instagram: tres cifras grandes, su palabra debajo, y dos líneas de un
// pelo que las separan. Nada más — ni caja, ni borde, ni sombra.
//
// VIVE ACÁ y no adentro de una pantalla porque se usa en dos lugares con
// dos comportamientos distintos:
//
//   Social  -> cada número NAVEGA a esa lista
//   Amigos  -> cada número es una PESTAÑA de la pantalla
//
// Lo que cambia es a dónde va el toque y qué cuenta cada uno; lo que se
// ve tiene que ser idéntico, o parecen dos componentes distintos que
// dicen lo mismo.
//
// QUÉ CUENTA CADA FILA. Los números tienen que decir COSAS DISTINTAS:
// amigos, solicitudes esperando respuesta y —solo en Social— duelos en
// juego. No hay "seguidores" y "seguidos" por separado: en +Vida la
// amistad es mutua —se manda solicitud y el otro acepta—, así que
// serían el mismo número escrito dos veces.
// ============================================================

/// Un número de la fila.
class ContadorSocial {
  const ContadorSocial({
    required this.numero,
    required this.etiqueta,
    this.conAviso = false,
  });

  final int numero;
  final String etiqueta;

  /// Marca naranja de "hay algo esperándote". Solo para lo que pide una
  /// acción del usuario, nunca para un total.
  final bool conAviso;
}

/// Los tres de SOCIAL: con cuántos contás, quién está esperando
/// respuesta y qué tenés en juego ahora mismo.
List<ContadorSocial> contadoresDeSocial() {
  final social = Datos.i.social;

  return [
    ContadorSocial(numero: social.conexiones.length, etiqueta: 'Amigos'),
    ContadorSocial(
      numero: social.solicitudesRecibidas.length,
      etiqueta: 'Solicitudes',
      // El punto naranja es lo que hace que se note que hay algo
      // esperando: un número solo se pierde entre tres.
      conAviso: social.solicitudesRecibidas.isNotEmpty,
    ),
    ContadorSocial(
      numero: social.duelo.activo ? 1 : 0,
      // "Activos" y no "Duelos" a secas: el número cuenta los que están
      // corriendo, no los que jugaste en tu vida. El historial completo
      // está abajo, en la misma pantalla.
      etiqueta: 'Duelos activos',
    ),
  ];
}

/// Los DOS de la pantalla de Amigos, que son sus pestañas.
///
/// Dos y no tres: la pestaña de enviadas se fue. Ver la lista de lo que
/// mandaste no lleva a ninguna parte —no hay nada que hacer ahí— y
/// ocupaba un tercio de la fila de arriba. Que ya la mandaste se dice
/// donde se preguntaría de nuevo: el botón de agregar, que pasa a decir
/// "Solicitud enviada".
List<ContadorSocial> contadoresDeAmigos() {
  final social = Datos.i.social;

  return [
    ContadorSocial(numero: social.conexiones.length, etiqueta: 'Amigos'),
    ContadorSocial(
      numero: social.solicitudesRecibidas.length,
      etiqueta: 'Solicitudes',
      conAviso: social.solicitudesRecibidas.isNotEmpty,
    ),
  ];
}

class ContadoresAmigos extends StatelessWidget {
  const ContadoresAmigos({
    super.key,
    required this.contadores,
    required this.onTocar,
    this.seleccionado,
  });

  /// Los tres números, en orden.
  final List<ContadorSocial> contadores;

  /// Recibe la posición del que se tocó.
  final ValueChanged<int> onTocar;

  /// Cuál está abierto. Null cuando el componente solo navega y no
  /// representa un estado — que es el caso de Social.
  final int? seleccionado;

  @override
  Widget build(BuildContext context) {
    // SIN CAJA (decisión de Daniel, 21 de septiembre de 2026). Era una
    // tarjeta blanca con borde, una más entre las dieciséis que tenía
    // Social. Los tres números se leen igual de bien apoyados sobre el
    // fondo: lo que los agrupa son los dos separadores del medio, no un
    // contorno alrededor.
    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < contadores.length; i++) ...[
            if (i > 0) _separadorVertical,
            Expanded(
              child: _Contador(
                contador: contadores[i],
                activo: seleccionado == i,
                onTap: () => onTocar(i),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// La línea de un pelo entre dos contadores. Es lo único que los
  /// agrupa desde que no hay caja alrededor.
  static final Widget _separadorVertical = VerticalDivider(
    width: 1,
    thickness: 0.5,
    indent: 6,
    endIndent: 6,
    color: AppColors.separador,
  );
}

class _Contador extends StatelessWidget {
  const _Contador({
    required this.contador,
    required this.activo,
    required this.onTap,
  });

  final ContadorSocial contador;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = activo ? AppColors.accent : AppColors.textPrimary;

    return CupertinoButton(
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      minimumSize: Size.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                '${contador.numero}',
                style: AppTheme.display(24).copyWith(color: color),
              ),
              if (contador.conAviso)
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
            contador.etiqueta,
            maxLines: 1,
            textAlign: TextAlign.center,
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
