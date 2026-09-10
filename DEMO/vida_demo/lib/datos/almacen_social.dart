import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'modelos.dart';

// ============================================================
// DÓNDE SE GUARDAN LOS GRUPOS QUE CREA EL USUARIO.
//
// `assets/mock/social.json` NO se puede escribir: es un asset empaquetado
// dentro de la app, de solo lectura en el teléfono. Por eso lo que crea el
// usuario se guarda acá: el MISMO JSON, con la misma forma que la lista
// "grupos" de ese archivo, pero en el almacenamiento del teléfono.
//
// Al arrancar: se lee el mock y encima se pegan estos. Los del mock son el
// punto de partida; estos son lo que el usuario agregó.
//
// TODO: cuando exista el backend de Luis, crear y unirse pasan por la API
// y este archivo se borra. Un grupo es compartido: guardarlo solo en un
// teléfono es una muleta para la demo, no la solución.
// ============================================================

class AlmacenSocial {
  const AlmacenSocial._();

  static const _clave = 'social.grupos_del_usuario';

  /// Los grupos guardados. Devuelve vacío si no hay nada o si el
  /// almacenamiento no está disponible (por ejemplo en los tests, donde
  /// no hay plugin): la app tiene que arrancar igual.
  static Future<List<GrupoRanking>> leer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_clave);
      if (texto == null) return [];

      return (jsonDecode(texto) as List)
          .map((g) => GrupoRanking.desdeJson(g as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Un JSON viejo o corrupto no puede tumbar el arranque: se ignora
      // y el usuario ve solo los grupos del mock.
      return [];
    }
  }

  /// Guarda los grupos que creó el usuario. Los del mock se ignoran: ya
  /// vuelven solos en cada arranque, no hay para qué duplicarlos.
  static Future<void> guardar(List<GrupoRanking> grupos) async {
    try {
      final mios = grupos.where((g) => g.creadoPorMi).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _clave,
        jsonEncode(mios.map((g) => g.aJson()).toList()),
      );
    } catch (_) {
      // Si no se pudo guardar, el grupo sigue existiendo en memoria hasta
      // que se cierre la app. No vale la pena romper la pantalla por esto.
    }
  }
}
