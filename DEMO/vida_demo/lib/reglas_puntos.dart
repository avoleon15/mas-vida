// ============================================================
// Las tablas de puntos y niveles que la app DIBUJA.
//
// Esto NO calcula los puntos de nadie: los calcula el servidor, y la
// app nunca manda puntos, edad ni FCmáx (un iPhone modificado podría
// acreditarse lo que quiera). Las pantallas leen los puntos ya hechos
// del repositorio. Lo que vive acá son las tablas que se muestran: los
// tramos de pasos del anillo, los niveles de la escalera y los techos.
//
// Fuente: contrato-v1-corregido.md y CLAUDE.md.
// ============================================================

/// Techo diario absoluto, sumando TODAS las fuentes (pasos + intensidad).
/// Un día que genere más se acredita en 200 y se marca con la bandera
/// `tope_diario_aplicado`.
const int techoDiario = 200;

/// Techo anual de los puntos por ACTIVIDAD FÍSICA (pasos + intensidad).
///
/// El chequeo médico está fuera de v1, así que en el piloto este es
/// también el techo de los puntos del año. Consecuencia aceptada y
/// documentada (CLAUDE.md): el nivel 4 arranca en 15.000 y queda FUERA
/// DE ALCANCE en el piloto. No es un bug — no se arregla subiendo este
/// techo ni bajando el piso del nivel 4.
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
// Niveles anuales y cashback.
// ------------------------------------------------------------

/// Un nivel del esquema propio de +Vida.
///
/// El contrato v1 prohíbe explícitamente el naming Bronze/Silver/Gold/
/// Platinum: eso es de Vitality. Los niveles son numéricos (0–4).
class Nivel {
  const Nivel(
    this.numero,
    this.puntosMinimos,
    this.puntosMaximos,
    this.porcentajeCashback,
  );

  final int numero;
  final int? puntosMinimos;
  final int? puntosMaximos;
  final double? porcentajeCashback;

  /// False mientras el rango y el % de este nivel no estén definidos en
  /// la documentación fuente. La UI debe mostrar un estado explícito de
  /// "pendiente de definir", nunca un número inventado.
  ///
  /// Hoy los cinco niveles están definidos, pero el campo se queda: es la
  /// red de seguridad si mañana se agrega uno sin datos.
  bool get definido => porcentajeCashback != null && puntosMinimos != null;

  String get rangoTexto {
    if (!definido) return 'Pendiente de definir';
    final min = _miles(puntosMinimos!);
    // El último nivel no tiene techo real: el número que trae es el tope
    // para dibujar la escalera, no un límite de lo que se acumula.
    if (puntosMaximos == null || puntosMaximos == puntosMinimos) {
      return '$min+ pts';
    }
    return '$min – ${_miles(puntosMaximos!)} pts';
  }

  static String _miles(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
}

/// Tabla de niveles anuales de cashback. Los cinco niveles y sus rangos
/// están confirmados: ya no hay huecos pendientes acá.
///
/// OJO con el nivel 4: arranca en 15.000, por encima de [techoAnual]
/// (12.000), así que en el piloto no se alcanza. El cashback máximo real
/// es el 10% del nivel 3. En el nivel 4, el tercer número es el tope de
/// la tabla para dibujar la escalera, no un límite de lo acumulable
/// (piso confirmado por Alvaro el 19 de septiembre de 2026).
const List<Nivel> niveles = [
  Nivel(0, 0, 2499, 0),
  Nivel(1, 2500, 4999, 5),
  Nivel(2, 5000, 9999, 7.5),
  Nivel(3, 10000, 14999, 10),
  Nivel(4, 15000, 15000, 20),
];

/// Si [nivel] se puede alcanzar con la actividad del año, que topa en
/// [techoAnual]. El nivel 4 no: es la consecuencia aceptada del piloto.
bool nivelAlcanzable(Nivel nivel) =>
    nivel.puntosMinimos != null && nivel.puntosMinimos! <= techoAnual;

/// El nivel de arriba de [nivelActual], si existe y se puede alcanzar.
///
/// Null en el último nivel Y en el último alcanzable: a quien está en el
/// nivel 3 no se le dice "te faltan 3.760 pts" para un nivel al que
/// caminando no llega.
Nivel? siguienteNivelAlcanzable(int nivelActual) {
  final siguiente = nivelPorNumero(nivelActual + 1);
  if (siguiente == null || !nivelAlcanzable(siguiente)) return null;
  return siguiente;
}

/// Busca un nivel por número. Devuelve `null` si no está en la tabla.
Nivel? nivelPorNumero(int numero) {
  for (final n in niveles) {
    if (n.numero == numero) return n;
  }
  return null;
}
