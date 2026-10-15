import 'package:shared_preferences/shared_preferences.dart';

/// Recuerda si ya se le mostró al usuario la pantalla de permisos de
/// Apple Salud, para no ponérsela delante en cada arranque.
///
/// Guarda que se MOSTRÓ, no qué contestó: lo que el usuario concedió lo
/// sabe solo HealthKit, y cambia desde Ajustes sin avisarle a la app. Por
/// eso la pantalla vuelve a preguntarle al nativo cada vez que se abre
/// desde Perfil, en vez de leer una respuesta vieja de acá.
class AlmacenPermisos {
  static const _clave = 'permisos.salud_pedidos';

  /// True si ya pasó por la pantalla. Si el almacenamiento no está
  /// disponible, dice que sí: es preferible no volver a mostrarla que
  /// trabar el arranque en ella.
  static Future<bool> yaSePidieron() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_clave) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> marcarPedidos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_clave, true);
    } catch (_) {
      // Si no se pudo guardar, la pantalla vuelve a salir la próxima vez.
      // Molesta un poco, no rompe nada.
    }
  }
}
