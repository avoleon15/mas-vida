import 'almacen_social.dart';
import 'api_vida_repository.dart';
import 'mock_vida_repository.dart';
import 'modelos.dart';
import 'vida_repository.dart';

// ============================================================
// EL ÚNICO LUGAR QUE DECIDE DE DÓNDE SALEN LOS DATOS.
//
// Para pasar al backend real cuando esté listo: comentá la línea del
// mock, descomentá la del API, y poné la URL. Nada más. Ninguna pantalla
// cambia.
// ============================================================

final VidaRepository repositorio = MockVidaRepository();
// final VidaRepository repositorio = ApiVidaRepository(baseUrl: 'https://api.masvida.gt');

/// Fotografía de todos los datos, ya cargados.
///
/// Se hidrata una sola vez al arrancar la app (ver `main.dart`) y de ahí
/// en adelante las pantallas leen de acá de forma síncrona. Así ninguna
/// pantalla necesita `FutureBuilder` ni sabe si detrás hay un JSON de
/// prueba o una API.
class Datos {
  const Datos({
    required this.perfil,
    required this.historial,
    required this.resumen,
    required this.catalogo,
    required this.social,
  });

  final Perfil perfil;
  final Historial historial;
  final ResumenAnual resumen;
  final Catalogo catalogo;
  final DatosSociales social;

  static late Datos i;

  /// Carga todo desde [repositorio]. Se llama una vez, antes de
  /// `runApp`.
  static Future<void> cargar() async {
    final resultados = await Future.wait([
      repositorio.perfil(),
      repositorio.historial(),
      repositorio.resumenAnual(),
      repositorio.catalogo(),
      repositorio.social(),
    ]);

    final social = resultados[4] as DatosSociales;

    // Encima de los grupos del mock van los que creó el usuario en
    // arranques anteriores. Se filtran por id para que unirse dos veces al
    // mismo grupo no lo muestre duplicado.
    final ids = social.grupos.map((g) => g.id).toSet();
    for (final g in await AlmacenSocial.leer()) {
      if (ids.add(g.id)) social.grupos.add(g);
    }

    i = Datos(
      perfil: resultados[0] as Perfil,
      historial: resultados[1] as Historial,
      resumen: resultados[2] as ResumenAnual,
      catalogo: resultados[3] as Catalogo,
      social: social,
    );
  }
}

// Se importa ApiVidaRepository aunque hoy no se use, para que la línea
// comentada de arriba funcione con solo descomentarla.
// ignore: unused_element
ApiVidaRepository? _referenciaApi;
