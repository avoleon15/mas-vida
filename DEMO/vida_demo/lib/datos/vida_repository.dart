import 'modelos.dart';

/// Única puerta de entrada a los datos de +Vida.
///
/// Las pantallas nunca leen JSON ni hacen HTTP: piden por acá. Cambiar de
/// datos de prueba a backend real es cambiar qué implementación se
/// construye en `lib/datos/fuente_datos.dart` — una sola línea, sin tocar
/// ninguna pantalla.
abstract class VidaRepository {
  /// Perfil del asegurado, incluida la edad (que viene de la póliza) y
  /// los datos de la póliza que la aseguradora expone.
  Future<Perfil> perfil();

  /// Ventana reciente de días con sus puntos ya calculados.
  Future<Historial> historial();

  /// Acumulado anual, nivel, cashback, racha, retos y monedas.
  Future<ResumenAnual> resumenAnual();

  /// Catálogo de premios canjeables con monedas.
  Future<Catalogo> catalogo();

  /// Duelos, conexiones y ranking.
  Future<DatosSociales> social();
}
