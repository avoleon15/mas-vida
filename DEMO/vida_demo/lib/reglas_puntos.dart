// ============================================================
// Motor de cálculo de puntos de +Vida.
//
// IMPORTANTE — este motor NO es la fuente de verdad. En producción los
// puntos los calcula el backend de Luis: el contrato v1 es explícito en
// que la app nunca manda puntos, edad ni FCM calculada, porque un iPhone
// jailbreakeado podría acreditarse lo que quiera.
//
// Esta clase existe para dos cosas:
//   1. Generar y validar los datos de prueba mientras no hay backend.
//   2. Poder verificar el motor de Luis contra las mismas reglas.
//
// Ninguna pantalla debe llamar a este motor para decidir qué mostrar:
// las pantallas leen los puntos ya calculados que devuelve el
// repositorio (campos `puntos_pasos`, `puntos_intensidad`, `puntos_dia`
// del JSON #2 del contrato).
//
// Fuente: contrato-v1-corregido.md, congelado.
// ============================================================

/// Techo diario absoluto, sumando TODAS las fuentes (pasos + intensidad).
/// Un día que genere más se acredita en 200 y se marca con la bandera
/// `tope_diario_aplicado`.
const int techoDiario = 200;

/// Techo anual. El contrato documenta que, con el chequeo médico fuera
/// de v1, el máximo alcanzable solo por actividad es 12.000 puntos — y
/// que por lo tanto el nivel 4 queda fuera de alcance en el piloto.
/// Es una consecuencia aceptada y documentada, no un bug.
const int techoAnual = 12000;

/// Piso mínimo de pasos para ganar cualquier punto.
const int pisoPasos = 7000;

// ------------------------------------------------------------
// Puntos por pasos — función escalonada, no lineal.
// ------------------------------------------------------------

/// Un escalón de la tabla de pasos: desde [pasosMinimos] pasos en el día
/// se ganan [puntos] puntos.
class EscalonPasos {
  const EscalonPasos(this.pasosMinimos, this.puntos);

  final int pasosMinimos;
  final int puntos;
}

/// Tabla oficial, igual para todas las edades. El ajuste por edad vive
/// en la matriz de intensidad (vía FCM = 219 − edad), no acá.
///
/// Los pasos por encima de 15.000 NO dan puntos adicionales.
const List<EscalonPasos> tablaPasos = [
  EscalonPasos(15000, 100),
  EscalonPasos(10000, 50),
  EscalonPasos(pisoPasos, 25),
];

/// Puntos por los pasos de un día. Por debajo de [pisoPasos]: 0.
///
/// Cuentan tanto los pasos del teléfono como los de un reloj vinculado,
/// pero la deduplicación y la precedencia entre fuentes ocurren ANTES de
/// llamar a esta función: acá ya llega un total del día resuelto.
int puntosPorPasos(int pasos) {
  for (final escalon in tablaPasos) {
    if (pasos >= escalon.pasosMinimos) return escalon.puntos;
  }
  return 0;
}

// ------------------------------------------------------------
// Puntos por intensidad (ritmo cardíaco).
// ------------------------------------------------------------

/// Duración mínima de una sesión para que cuente. Tiene que ser
/// CONTINUA: dos bloques de 20 minutos no son una sesión de 40.
const int minutosMinimosSesion = 30;

/// Frecuencia cardíaca máxima. Es 219 − edad, NO 220 − edad.
///
/// Se deja acá solo para simular el servidor: el teléfono nunca calcula
/// ni envía este valor, manda la edad y el servidor lo deriva.
int frecuenciaCardiacaMaxima(int edad) => 219 - edad;

/// Puntos de intensidad de una sesión.
///
/// Devuelve `null` cuando el par (duración, % de FCM) cae en una celda de
/// la matriz que todavía no está definida — quien llame decide qué hacer
/// con el hueco, pero nunca debe rellenarlo con un número inventado.
///
/// TODO: falta la matriz completa de duración × % de FCM. El contrato y
/// el Excel fijan un solo punto de la matriz (42 min al 74% = 100 pts).
/// La define Luis en la tarea L7. Hasta entonces no hay más escalones.
int? puntosPorIntensidad({
  required int minutos,
  required int porcentajeFcm,
  required bool continua,
}) {
  if (!continua || minutos < minutosMinimosSesion) return 0;

  // Única celda conocida de la matriz.
  if (minutos == 42 && porcentajeFcm == 74) return 100;

  return null; // celda sin definir
}

/// Bonus para usuarios de 60 años o más: ×1.25 sobre los puntos de
/// intensidad (nunca sobre los de pasos).
///
/// REQUIERE validación médica/actuarial antes de salir a piloto.
int aplicarBonus60Mas(int puntosIntensidad, int edad) {
  if (edad < 60) return puntosIntensidad;
  return (puntosIntensidad * 1.25).round();
}

// ------------------------------------------------------------
// Total del día.
// ------------------------------------------------------------

/// Resultado del cálculo de un día, con la misma forma que los campos
/// relevantes del JSON #2 del contrato.
class PuntosDelDia {
  const PuntosDelDia({
    required this.puntosPasos,
    required this.puntosIntensidad,
    required this.puntosBrutos,
    required this.puntosAcreditados,
    required this.topeAplicado,
  });

  final int puntosPasos;
  final int puntosIntensidad;

  /// Lo que sumaron las dos vías antes de aplicar el techo.
  final int puntosBrutos;

  /// Lo que efectivamente se acredita, ya con el techo aplicado.
  final int puntosAcreditados;

  /// True solo si el techo recortó el resultado. Llegar a exactamente
  /// 200 no cuenta como recorte.
  final bool topeAplicado;
}

/// Suma las dos vías del día y aplica el techo diario.
///
/// [manual] marca los datos ingresados a mano en la app de Salud: no
/// acreditan ningún punto en v1.
PuntosDelDia calcularDia({
  required int pasos,
  required int edad,
  int minutosSesion = 0,
  int porcentajeFcm = 0,
  bool sesionContinua = true,
  bool manual = false,
}) {
  final pPasos = manual ? 0 : puntosPorPasos(pasos);

  var pIntensidad = 0;
  if (!manual && minutosSesion > 0) {
    final crudo = puntosPorIntensidad(
      minutos: minutosSesion,
      porcentajeFcm: porcentajeFcm,
      continua: sesionContinua,
    );
    // Celda sin definir: se cuenta como 0 y el hueco queda visible en la
    // UI, en vez de inventar un valor.
    pIntensidad = aplicarBonus60Mas(crudo ?? 0, edad);
  }

  final brutos = pPasos + pIntensidad;
  return PuntosDelDia(
    puntosPasos: pPasos,
    puntosIntensidad: pIntensidad,
    puntosBrutos: brutos,
    puntosAcreditados: brutos > techoDiario ? techoDiario : brutos,
    topeAplicado: brutos > techoDiario,
  );
}

// ------------------------------------------------------------
// Niveles anuales y cashback.
// ------------------------------------------------------------

/// Un nivel del esquema propio de +Vida.
///
/// El contrato v1 prohíbe explícitamente el naming Bronze/Silver/Gold/
/// Platinum: eso es de Vitality. Los niveles son numéricos (0–4).
class Nivel {
  const Nivel(this.numero, this.puntosMinimos, this.puntosMaximos, this.porcentajeCashback);

  final int numero;
  final int? puntosMinimos;
  final int? puntosMaximos;
  final double? porcentajeCashback;

  /// False mientras el rango y el % de este nivel no estén definidos en
  /// la documentación fuente. La UI debe mostrar un estado explícito de
  /// "pendiente de definir", nunca un número inventado.
  bool get definido => porcentajeCashback != null;

  String get rangoTexto {
    if (!definido) return 'Pendiente de definir';
    final min = _miles(puntosMinimos!);
    if (puntosMaximos == null) return '$min+ pts';
    return '$min – ${_miles(puntosMaximos!)} pts';
  }

  static String _miles(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}

/// Tabla de niveles.
///
/// TODO: falta definir los niveles 1 y 2 — ni su rango de puntos ni su %
/// de cashback existen en la documentación fuente. El contrato v1 deja
/// anotado "confirmar con Alvaro/Diego el mapeo exacto de rango → nivel →
/// % de cashback". No inventarlos.
const List<Nivel> niveles = [
  Nivel(1, null, null, null), // TODO: falta
  Nivel(2, null, null, null), // TODO: falta
  Nivel(3, 10000, 15000, 10),
  Nivel(4, 15000, null, 20),
];

/// Nivel que corresponde a un acumulado anual.
///
/// Devuelve `null` por debajo de 10.000 puntos: ahí caen los niveles 1 y
/// 2, cuyos rangos no están definidos.
int? nivelParaPuntos(int puntosAnuales) {
  if (puntosAnuales >= 15000) return 4;
  if (puntosAnuales >= 10000) return 3;
  return null; // TODO: falta el rango de los niveles 1 y 2
}

/// Busca un nivel por número. Devuelve `null` si no está en la tabla.
Nivel? nivelPorNumero(int numero) {
  for (final n in niveles) {
    if (n.numero == numero) return n;
  }
  return null;
}
