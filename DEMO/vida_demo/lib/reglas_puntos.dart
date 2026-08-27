// ============================================================
// Motor de cálculo de puntos de +Vida. Reglas oficiales del proyecto:
// los puntos diarios se ganan por dos vías independientes (pasos y
// ritmo cardíaco) y cada una tiene su propio tope — no se puede ganar
// más que el máximo de su tabla.
//
// Esto es solo el motor de cálculo: no arma ninguna pantalla, solo
// expone funciones puras para que las pantallas las usen sobre datos
// de ejemplo (o, más adelante, sobre datos reales del backend).
// ============================================================

/// Tope real de puntos que se pueden ganar EN UN DÍA: 200 de la vía
/// pasos + 300 de la vía ritmo cardíaco (se suman, cada vía con su
/// propio tope). Es la base para calcular los techos de semana, mes y
/// año.
const int puntosMaximosPorDia = 500;

/// Un escalón de la tabla de puntos por pasos: a partir de
/// [pasosMinimos] pasos en el día se ganan [puntos] puntos.
class EscalonPasos {
  const EscalonPasos(this.pasosMinimos, this.puntos);

  final int pasosMinimos;
  final int puntos;
}

/// Tabla general (población menor de 65 años). Tope de esta vía: 200 pts.
const List<EscalonPasos> _tablaPasosGeneral = [
  EscalonPasos(15000, 200),
  EscalonPasos(10000, 100),
  EscalonPasos(7500, 50),
];

/// Tabla para usuarios de 65 años o más. Umbrales más bajos que la tabla
/// general porque a esa edad la misma cantidad de pasos representa un
/// esfuerzo relativo mayor. Mismo tope de 200 pts.
///
/// Estos umbrales son un punto de partida basado en literatura de
/// actividad física en adultos mayores y REQUIEREN validación médica/
/// actuarial antes de salir a piloto. No son definitivos.
const List<EscalonPasos> _tablaPasos65Mas = [
  EscalonPasos(10000, 200),
  EscalonPasos(7000, 100),
  EscalonPasos(5000, 50),
];

/// Devuelve la tabla de puntos por pasos que le corresponde a un usuario
/// de [edad] años. Centraliza la decisión general/65+ en un solo lugar
/// en vez de repartir condicionales de edad por varios archivos.
///
/// IMPORTANTE — [edad] DEBE venir de los datos de la póliza que provee
/// la aseguradora, NUNCA autodeclarada por el usuario: autodeclararla es
/// un vector de fraude obvio (cualquiera se pondría 66 años para tener
/// umbrales más fáciles).
List<EscalonPasos> tablaPuntosPorPasos(int edad) {
  return edad >= 65 ? _tablaPasos65Mas : _tablaPasosGeneral;
}

/// Puntos por pasos diarios, según la tabla que le corresponde a
/// [edad] (ver [tablaPuntosPorPasos]). Tope de esta vía: 200 pts para
/// cualquier edad.
int puntosPorPasos(int pasos, {required int edad}) {
  for (final escalon in tablaPuntosPorPasos(edad)) {
    if (pasos >= escalon.pasosMinimos) return escalon.puntos;
  }
  return 0;
}

/// Puntos por una sesión de ejercicio con ritmo cardíaco, según su
/// duración y el % promedio de tu RCM (ritmo cardíaco máximo) alcanzado.
/// Tope de esta vía: 300 pts. Por debajo de 30 minutos o de 60% de RCM
/// no se gana nada por esta vía.
int puntosPorRitmoCardiaco({
  required int minutos,
  required int porcentajeRcmPromedio,
}) {
  if (minutos < 30 || porcentajeRcmPromedio < 60) return 0;

  final alcanza70 = porcentajeRcmPromedio >= 70;

  if (minutos >= 90) return 300; // 1h30 o más: tope de la tabla.
  if (minutos >= 60) return alcanza70 ? 300 : 200; // 1h o más.
  return alcanza70 ? 200 : 100; // 30 min a 1h.
}

/// Total de puntos que gana un usuario en un día, sumando pasos + ritmo
/// cardíaco. REGLA DURA: no se puede ganar más de [puntosMaximosPorDia]
/// (200 + 300 = 500 pts) en un mismo día, sin importar cuánto sume cada
/// vía.
int puntosTotalesDelDia({
  required int pasos,
  required int edad,
  int minutosCardio = 0,
  int porcentajeRcmPromedio = 0,
}) {
  final crudo =
      puntosPorPasos(pasos, edad: edad) +
      puntosPorRitmoCardiaco(
        minutos: minutosCardio,
        porcentajeRcmPromedio: porcentajeRcmPromedio,
      );
  return crudo > puntosMaximosPorDia ? puntosMaximosPorDia : crudo;
}

// ============================================================
// Techos por período: cuántos puntos podría ganar como máximo un
// usuario que llega al tope diario TODOS los días del período. Se
// calculan a partir de los días reales del calendario (28/29/30/31
// según el mes, 365/366 según el año), no de promedios fijos.
// ============================================================

/// Días reales de [mes] (1 a 12) en el año [anio]. Usa el calendario de
/// Dart, así que ya contempla los años bisiestos para febrero.
int diasEnMes(int anio, int mes) => DateTime(anio, mes + 1, 0).day;

/// Días reales del año [anio] (365, o 366 si es bisiesto), sumando los
/// 12 meses reales uno por uno.
int diasEnAnio(int anio) {
  var total = 0;
  for (var mes = 1; mes <= 12; mes++) {
    total += diasEnMes(anio, mes);
  }
  return total;
}

/// Techo de puntos de una semana: 500 pts/día × 7 días.
int techoSemanal() => puntosMaximosPorDia * 7;

/// Techo de puntos de un mes calendario real (ej. julio = 31 días).
int techoMensual(int anio, int mes) =>
    puntosMaximosPorDia * diasEnMes(anio, mes);

/// Techo de puntos de un año calendario real (365 o 366 días).
int techoAnual(int anio) => puntosMaximosPorDia * diasEnAnio(anio);
