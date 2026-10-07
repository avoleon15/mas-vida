import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/theme.dart';

// ============================================================
// Cómo se monta una pantalla en un test.
//
// Ojo con `disableAnimations`: la app tiene animaciones que se repiten
// para siempre (la moneda de Lottie, el borde que gira de Hoy). Con
// ellas vivas, `pumpAndSettle` NUNCA termina de asentarse y el test se
// cuelga hasta el timeout.
//
// Encenderlo acá no es un truco para esquivar eso: es el mismo camino
// que toma la app cuando el usuario activa "Reducir movimiento" en iOS.
// Los tests corren por la rama que un usuario real puede pedir.
// ============================================================

/// Monta [pantalla] con el tema de +Vida y sin animaciones perpetuas.
///
/// [TemaVida] es obligatorio: los componentes de shadcn_ui revientan si
/// no encuentran un ShadTheme arriba en el árbol.
Future<void> montarPantalla(WidgetTester tester, Widget pantalla) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.temaClaro,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: TemaVida(child: pantalla),
        ),
      ),
    ),
  );
}

/// Deja el historial del mock como si hoy fuera el sábado 26 de
/// septiembre de 2026: un mes con varias semanas ya vividas.
///
/// Hace falta para probar las gráficas de "Mes". El hoy real del mock es
/// el viernes 2 de octubre, y octubre todavía no tiene ningún lunes: la
/// vista de Mes muestra solo la semana en curso, que es lo correcto ese
/// día pero no deja ver cómo se dibuja un mes. Se llama después de
/// `Datos.cargar()`.
///
/// Devuelve con qué volver al mock completo, para los tests que solo lo
/// necesitan un rato: `addTearDown(usarMesConVariasSemanas())`.
void Function() usarMesConVariasSemanas() {
  final d = Datos.i;
  final hasta = DateTime(2026, 9, 26);
  Datos.i = Datos(
    perfil: d.perfil,
    historial: Historial(
      zonaHoraria: d.historial.zonaHoraria,
      dias: d.historial.dias.where((x) => !x.fecha.isAfter(hasta)).toList(),
    ),
    resumen: d.resumen,
    catalogo: d.catalogo,
    social: d.social,
  );
  return () => Datos.i = d;
}
