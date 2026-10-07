import 'modelos.dart';
import 'vida_repository.dart';

/// Implementación contra el backend real de Luis.
///
/// Todavía no existe: el backend no está conectado. Cuando lo esté, se
/// implementan estos métodos con HTTP contra la API y se cambia la línea
/// de `fuente_datos.dart` — las pantallas no se tocan.
///
/// Endpoints previstos:
///   - `perfil()`        → GET /api/v1/perfil
///   - `historial()`     → GET /api/v1/historial      (forma sin congelar)
///   - `resumenAnual()`  → GET /api/v1/resumen        (forma sin congelar)
///   - `catalogo()`      → GET /api/v1/premios        (forma sin congelar)
///   - `social()`        → GET /api/v1/social         (forma sin congelar)
///
/// Lo único congelado en el contrato v1 es `POST /api/v1/sync` (JSON #1 y
/// JSON #2). El resto lo pide Flutter por HTTP directo y su forma
/// todavía no está acordada con Luis.
///
/// TODO: falta acordar y congelar la forma de todos los endpoints de
/// arriba salvo /api/v1/sync. Los mocks de `assets/mock/` son la
/// propuesta de partida.
class ApiVidaRepository implements VidaRepository {
  ApiVidaRepository({required this.baseUrl});

  final String baseUrl;

  @override
  Future<Perfil> perfil() => throw UnimplementedError(
    'ApiVidaRepository.perfil(): el backend todavía no está conectado.',
  );

  @override
  Future<Historial> historial() => throw UnimplementedError(
    'ApiVidaRepository.historial(): el backend todavía no está conectado.',
  );

  @override
  Future<ResumenAnual> resumenAnual() => throw UnimplementedError(
    'ApiVidaRepository.resumenAnual(): el backend todavía no está conectado.',
  );

  @override
  Future<Catalogo> catalogo() => throw UnimplementedError(
    'ApiVidaRepository.catalogo(): el backend todavía no está conectado.',
  );

  @override
  Future<DatosSociales> social() => throw UnimplementedError(
    'ApiVidaRepository.social(): el backend todavía no está conectado.',
  );
}
