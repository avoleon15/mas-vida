import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'datos/fuente_datos.dart';
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
      // Rutas nombradas: BottomNavBar navega por nombre de ruta.
      // '/premio-detalle' y '/canje-exitoso' reciben los datos del
      // premio como argumento (Navigator.pushNamed(..., arguments:)), no
      // como parte de la ruta.
      routes: {
        // La app entra por acá, no por '/home': hasta que los datos no
        // estén cargados no se puede construir ninguna pantalla.
        '/': (context) => const _Arranque(),
        '/home': (context) => const HomeScreen(),
        '/progress': (context) => const ProgressScreen(),
        '/records': (context) => const RecordsScreen(),
        '/perfil': (context) => const PerfilScreen(),
        '/social': (context) => const SocialScreen(),
        '/premios': (context) => const PremiosScreen(),
        '/mi-plan': (context) => const MiPlanScreen(),
        '/premio-detalle': (context) => const PremioDetalleScreen(),
        '/canje-exitoso': (context) => const CanjeExitosoScreen(),
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

    if (!mounted) return;
    setState(() => _listo = true);
  }

  @override
  Widget build(BuildContext context) {
    // `Datos.i` es `late` y las pantallas lo leen de forma síncrona: si
    // Hoy se construyera antes de que la carga termine, reventaría al
    // leerlo. Por eso el cambio es seco, sin transición cruzada que
    // deje las dos pantallas vivas al mismo tiempo.
    return _listo ? const HomeScreen() : const PantallaCargando();
  }
}
