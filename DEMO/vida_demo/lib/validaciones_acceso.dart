// ============================================================
// LAS REGLAS DEL INGRESO Y EL REGISTRO, SIN PANTALLA.
//
// Viven acá y no adentro de los widgets para poder probarlas solas y
// para que el login y el registro digan lo mismo: si el correo es
// válido en una pantalla, es válido en la otra.
// ============================================================

/// Edad mínima para abrir una cuenta.
///
/// Decidido el 6 de octubre de 2026: la app es solo para mayores de 18,
/// porque aceptar los términos y el consentimiento de datos de salud es un
/// contrato, y un menor no lo puede firmar solo. El servidor también lo
/// exige (`services/edad.py`).
///
/// [PENDIENTE: que legal y la aseguradora lo confirmen. No cambia el
/// código.]
const int edadMinima = 18;

/// Un correo con forma de correo. No verifica que exista: eso lo hace el
/// servidor mandándole algo.
bool correoValido(String correo) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(correo.trim());

/// Lo que le falta a una contraseña, en palabras del usuario. Vacía si
/// está bien.
///
/// Son las dos reglas de Django que se pueden revisar en el teléfono
/// (largo mínimo y no solo números). Las otras dos —que no sea una
/// contraseña común y que no se parezca al correo— las revisa el
/// servidor y su mensaje se muestra tal cual.
List<RequisitoContrasena> requisitosContrasena(String contrasena) => [
  RequisitoContrasena('8 caracteres o más', contrasena.length >= 8),
  RequisitoContrasena(
    'Con al menos una letra',
    RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]').hasMatch(contrasena),
  ),
];

class RequisitoContrasena {
  const RequisitoContrasena(this.texto, this.cumplido);

  final String texto;
  final bool cumplido;
}

bool contrasenaValida(String contrasena) =>
    requisitosContrasena(contrasena).every((r) => r.cumplido);

/// Los años cumplidos a [hoy]. Si hoy es el cumpleaños, ya cuenta.
int edadEn(DateTime nacimiento, DateTime hoy) {
  var edad = hoy.year - nacimiento.year;
  final yaCumplio =
      hoy.month > nacimiento.month ||
      (hoy.month == nacimiento.month && hoy.day >= nacimiento.day);
  if (!yaCumplio) edad--;
  return edad;
}

/// La fecha de nacimiento más reciente con la que se puede abrir cuenta.
///
/// Un 29 de febrero de hoy cae solo en 1 de marzo si el año de hace 18
/// no fue bisiesto (`DateTime` lo desborda al día siguiente), que es lo
/// que tiene que pasar.
DateTime nacimientoMaximo(DateTime hoy) =>
    DateTime(hoy.year - edadMinima, hoy.month, hoy.day);
