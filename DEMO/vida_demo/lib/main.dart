import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'datos/almacen_permisos.dart';
import 'datos/fuente_datos.dart';
import 'navegacion.dart';
import 'screens/permisos_salud_screen.dart';
import 'screens/canje_exitoso_screen.dart';
import 'screens/home_screen.dart';
import 'screens/mi_plan_screen.dart';
import 'screens/premio_detalle_screen.dart';
import 'screens/perfil_screen.dart';
import 'screens/premios_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/records_screen.dart';
import 'screens/social_screen.dart';
import 'theme.dart';
import 'widgets/fondo_estudio.dart';
import 'widgets/iphone_frame.dart';
import 'widgets/moneda_animada.dart';
import 'widgets/pantalla_cargando.dart';

/// Cuánto se queda la animación de carga en pantalla como MÍNIMO.
///
/// Hoy los datos salen de los JSON de `assets/mock/` y cargan en
/// milisegundos: sin este piso la animación aparecería y desaparecería
/// en un frame, que se lee como un parpadeo y no como una pantalla.
///
/// Es un ciclo completo de la animación (2,5 s), para que la cruz
/// alcance a recorrer el electro entero una vez.
///
/// OJO cuando entre el backend real: ahí la carga va a tardar de verdad
/// y este mínimo pasa a ser tiempo regalado. Se va a querer bajar o
/// sacar del todo.
const Duration _minimoEnPantalla = Duration(milliseconds: 2500);

void main() {
  // Necesario para poder leer assets antes de que arranque la app.
  WidgetsFlutterBinding.ensureInitialized();

  // `runApp` PRIMERO y la carga después, al revés que antes. Antes se
  // esperaba a `Datos.cargar()` acá arriba, así que durante toda la
  // carga no había app todavía y el usuario miraba el splash nativo en
  // blanco. Ahora la app arranca de una y los datos entran detrás.
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado != AppLifecycleState.resumed) return;

    // Al volver a la app, los datos se actualizan solos. Es el momento
    // exacto en que más falta hace: el usuario terminó de caminar, el
    // reloj sincronizó mientras la app estaba atrás, y abre a ver cuánto
    // lleva. Si tuviera que jalar para enterarse, vería números viejos
    // primero.
    //
    // Este refresco es SILENCIOSO: no muestra el indicador. La guarda de
    // tiempo vive en `refrescarDatosSiHaceFalta`, porque `resumed` se
    // dispara también cada vez que se cambia de app y se vuelve.
    refrescarDatosSiHaceFalta();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '+Vida',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.temaClaro,
      initialRoute: '/',
      // El rebote de iOS y el arrastre con mouse, para TODA la app y no
      // solo para las pantallas que se acuerdan de pedirlo. Ver
      // `lib/navegacion.dart`.
      scrollBehavior: const ComportamientoVida(),
      // Las rutas se arman acá y no con el mapa `routes:` porque cada
      // una necesita su propia transición: las cinco pestañas cruzan
      // con un fundido y las pantallas de adentro entran deslizándose.
      // Con `routes:` todas usarían la misma.
      //
      // '/premio-detalle' y '/canje-exitoso' reciben los datos del
      // premio como argumento (Navigator.pushNamed(..., arguments:)), no
      // como parte de la ruta.
      onGenerateRoute: (ajustes) {
        final pantalla = _pantallaDe(ajustes.name);
        if (pantalla == null) return null;
        return rutasDePestana.contains(ajustes.name)
            ? rutaDePestana(pantalla, ajustes)
            : rutaInterna(pantalla, ajustes);
      },
      // En Web envolvemos la app en un marco de iPhone para previsualizarla
      // como celular. En el build real de iOS esto no aplica: ahí `child`
      // ya ocupa toda la pantalla del dispositivo.
      builder: (context, child) {
        // Los componentes de shadcn_ui necesitan un ShadTheme en el
        // árbol. Va acá adentro y no reemplazando al MaterialApp, así el
        // Material que ya usa la app queda intacto.
        //
        // El tema se arma desde NUESTROS tokens, no de la paleta por
        // defecto de shadcn: si no, sus componentes traerían sus propios
        // grises y la app se vería hecha de dos apps distintas.
        child = TemaVida(child: child!);
        if (!kIsWeb) return child;
        return FondoEstudio(
          child: Center(
            child: Padding(
              // Un margen chico arriba/abajo para que el marco no quede
              // pegado al borde de la ventana del navegador.
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.fitHeight,
                  child: IPhoneFrame(child: child),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Qué pantalla le toca a cada nombre de ruta.
///
/// Separado de la transición a propósito: acá se dice QUÉ se muestra y
/// en `navegacion.dart` CÓMO entra. Un nombre desconocido devuelve null
/// y el Navigator se encarga.
Widget? _pantallaDe(String? ruta) {
  switch (ruta) {
    // La app entra por acá, no por '/home': hasta que los datos no
    // estén cargados no se puede construir ninguna pantalla.
    case '/':
      return const _Arranque();
    case '/home':
      return const HomeScreen();
    case '/progress':
      return const ProgressScreen();
    case '/records':
      return const RecordsScreen();
    case '/perfil':
      return const PerfilScreen();
    case '/social':
      return const SocialScreen();
    case '/premios':
      return const PremiosScreen();
    case '/mi-plan':
      return const MiPlanScreen();
    case '/premio-detalle':
      return const PremioDetalleScreen();
    case '/canje-exitoso':
      return const CanjeExitosoScreen();
    case '/permisos-salud':
      return const PermisosSaludScreen();
    default:
      return null;
  }
}

/// La primera pantalla de la app: muestra la animación de carga y,
/// cuando los datos ya están, se convierte en Hoy.
///
/// Cambia de una a otra con un `setState` y no navegando: si empujara
/// una ruta nueva, la pantalla de carga quedaría en la pila y el gesto
/// de volver atrás de iOS traería de vuelta un loader ya cumplido.
class _Arranque extends StatefulWidget {
  const _Arranque();

  @override
  State<_Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<_Arranque> {
  bool _listo = false;

  /// Si toca mostrar el permiso de Apple Salud antes de Hoy: solo la
  /// primera vez que se abre la app. Sin pasos no hay puntos, así que es
  /// el paso uno; después vive en Perfil.
  bool _pedirPermisos = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    // Las dos cosas en paralelo: la carga real y la espera mínima. Con
    // `Future.wait` la pantalla dura lo que tarde la MÁS LENTA de las
    // dos, así que hoy manda el mínimo y el día que el backend tarde
    // más de 2,5 s manda la carga, sin sumar los dos tiempos.
    await Future.wait([
      Future(() async {
        // Se carga todo una sola vez desde el repositorio (hoy, los JSON
        // de prueba de assets/mock/). Cuál repositorio se usa lo decide
        // `lib/datos/fuente_datos.dart`, no esta línea.
        await Datos.cargar();

        // La moneda de Lottie se deja lista antes de que se pinte Hoy:
        // si no, la primera que se ve aparece un instante después que su
        // número.
        await MonedaAnimada.precargar();

        // Queda apuntado el relevo de semana: si la app se queda abierta
        // cruzando el domingo 23:59, el lunes 00:00 (hora de Guatemala)
        // vuelve a pedir los datos sola y aparece la semana nueva con sus
        // objetivos, sin que el usuario tenga que jalar para refrescar.
        programarRelevoDeSemana();
      }),
      Future.delayed(_minimoEnPantalla),
    ]);
    final yaSePidieron = await AlmacenPermisos.yaSePidieron();

    if (!mounted) return;
    setState(() {
      _listo = true;
      _pedirPermisos = !yaSePidieron;
    });
  }

  @override
  Widget build(BuildContext context) {
    // `Datos.i` es `late` y las pantallas lo leen de forma síncrona: si
    // Hoy se construyera antes de que la carga termine, reventaría al
    // leerlo. Por eso el cambio es seco, sin transición cruzada que
    // deje las dos pantallas vivas al mismo tiempo.
    if (!_listo) return const PantallaCargando();
    if (_pedirPermisos) {
      // Mismo cambio seco que el de la carga: sin ruta nueva, así el gesto
      // de volver no trae de vuelta la pantalla de permisos desde Hoy.
      return PermisosSaludScreen(
        alTerminar: () => setState(() => _pedirPermisos = false),
      );
    }
    return const HomeScreen();
  }
}
