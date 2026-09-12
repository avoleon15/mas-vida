import 'package:flutter/foundation.dart';

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

    // La carga de arranque también cuenta como "recién recargado". Sin
    // esto, minimizar la app apenas abrió y volver dispararía una
    // recarga automática con los datos todavía tibios.
    _ultimaRecarga = DateTime.now();
  }
}

// ============================================================
// UN REFRESCO, TODAS LAS PANTALLAS ESCUCHAN.
//
// Los datos son UNO solo ([Datos.i]), así que refrescarlos también tiene
// que ser uno solo. Si cada pantalla recargara lo suyo, jalar en Progreso
// dejaría a Hoy con los números viejos — y cuando las cinco pantallas
// estén vivas a la vez, eso se ve.
//
// Por eso acá hay un contador que sube en cada recarga y allá cada
// pantalla se cuelga de él con un ValueListenableBuilder. De paso, eso
// evita convertir a Stateful las pantallas que hoy son Stateless.
// ============================================================

/// Sube en uno cada vez que [Datos.i] se reemplazó por datos frescos.
///
/// El número en sí no significa nada: lo único que importa es que cambió,
/// que es lo que despierta a los ValueListenableBuilder de las pantallas.
final ValueNotifier<int> datosRecargados = ValueNotifier<int>(0);

/// Cuándo terminó la última recarga con éxito. La usa
/// [refrescarDatosSiHaceFalta] para no recargar de más.
DateTime? _ultimaRecarga;

/// Vuelve a leer todo y avisa a las pantallas.
///
/// NUNCA tira: si la carga falla, se traga el error a propósito. Quien
/// llama a esto es un gesto del usuario, y dejar propagar la excepción
/// colgaría el indicador de refresco girando para siempre.
///
/// Que falle no rompe nada de lo que ya se ve: [Datos.cargar] arma el
/// objeto nuevo y recién al final lo asigna a `i`, así que si revienta a
/// mitad de camino la pantalla se queda con los datos viejos, completos y
/// coherentes. Se pierde el refresco, no la sesión.
///
/// Devuelve si pudo o no, por si algún día se quiere avisar en pantalla.
Future<bool> refrescarDatos() async {
  try {
    await Datos.cargar();
    datosRecargados.value++;
    return true;
  } catch (e, s) {
    debugPrint('No se pudieron refrescar los datos: $e\n$s');
    return false;
  }
}

/// Cada cuánto, como mucho, se recarga sola la app al volver del segundo
/// plano.
///
/// Volver a la app es algo que pasa todo el tiempo — cambiar de app y
/// regresar dispara `resumed` igual que abrirla después de una caminata.
/// Sin esta guarda, cada vuelta sería una recarga completa.
const Duration _esperaEntreRecargasAutomaticas = Duration(seconds: 30);

/// Refresco silencioso: el que corre solo al volver del segundo plano.
///
/// No muestra indicador. La idea es que los pasos que el reloj sincronizó
/// mientras la app estaba atrás ya estén cuando el usuario mira la
/// pantalla, sin que tenga que pedirlo.
Future<void> refrescarDatosSiHaceFalta() async {
  final ultima = _ultimaRecarga;
  if (ultima != null &&
      DateTime.now().difference(ultima) < _esperaEntreRecargasAutomaticas) {
    return;
  }
  await refrescarDatos();
}

// Se importa ApiVidaRepository aunque hoy no se use, para que la línea
// comentada de arriba funcione con solo descomentarla.
// ignore: unused_element
ApiVidaRepository? _referenciaApi;
