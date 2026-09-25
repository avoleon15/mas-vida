/// La hora de Guatemala, que es la que manda en todos los ciclos de la
/// app: la semana de los objetivos y los ciclos de La Liga.
library;

/// Guatemala está en UTC−6 y no cambia de hora en todo el año.
const Duration desfaseDeGuatemala = Duration(hours: 6);

/// La misma fecha, leída como reloj de pared en Guatemala.
///
/// Hace falta porque `DateTime.parse` de una fecha con offset —como las
/// que manda el backend, `2026-09-20T23:59:59-06:00`— devuelve un
/// DateTime en UTC. Preguntarle el día directamente daba 21, no 20: el
/// domingo 23:59 de Guatemala ya es lunes en Londres.
///
/// No se usa `toLocal()` a propósito: eso daría la hora del teléfono, y
/// el ciclo de la semana está fijado en hora de Guatemala para todos los
/// usuarios. Alguien de viaje no tiene que ver otra fecha de cierre.
DateTime enHoraDeGuatemala(DateTime fecha) =>
    fecha.toUtc().subtract(desfaseDeGuatemala);
