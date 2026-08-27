import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'screens/canje_exitoso_screen.dart';
import 'screens/home_screen.dart';
import 'screens/mi_plan_screen.dart';
import 'screens/premio_detalle_screen.dart';
import 'screens/premios_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/social_screen.dart';
import 'theme.dart';
import 'widgets/fondo_estudio.dart';
import 'widgets/iphone_frame.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '+Vida',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/home',
      // Rutas nombradas: BottomNavBar navega por nombre de ruta.
      // '/premio-detalle' y '/canje-exitoso' reciben los datos del
      // premio como argumento (Navigator.pushNamed(..., arguments:)), no
      // como parte de la ruta.
      routes: {
        '/home': (context) => const HomeScreen(),
        '/progress': (context) => const ProgressScreen(),
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
        if (!kIsWeb) return child!;
        return FondoEstudio(
          child: Center(
            child: Padding(
              // Un margen chico arriba/abajo para que el marco no quede
              // pegado al borde de la ventana del navegador.
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.fitHeight,
                  child: IPhoneFrame(child: child!),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
