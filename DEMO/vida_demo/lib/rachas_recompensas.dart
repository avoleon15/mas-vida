/// Recompensas por constancia (streaks): al alcanzar ciertos hitos de
/// semanas consecutivas cumpliendo la meta semanal, el usuario recibe
/// MONEDAS extra (nunca puntos — los puntos no se otorgan por rachas).
/// Compartido entre Home y Progress para que los hitos no se dupliquen.
class HitoRacha {
  const HitoRacha(this.semanas, this.monedas);

  final int semanas;
  final int monedas;
}

const List<HitoRacha> hitosRacha = [
  HitoRacha(4, 5),
  HitoRacha(8, 10),
  HitoRacha(12, 20),
  HitoRacha(24, 40),
  HitoRacha(52, 100),
];

/// El próximo hito todavía no alcanzado dada la racha actual, o null si
/// ya se alcanzaron todos los hitos definidos.
HitoRacha? proximoHito(int rachaActual) {
  for (final hito in hitosRacha) {
    if (rachaActual < hito.semanas) return hito;
  }
  return null;
}
