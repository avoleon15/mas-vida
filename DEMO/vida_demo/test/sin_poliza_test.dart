import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/screens/mi_plan_screen.dart';
import 'package:vida_demo/screens/premio_detalle_screen.dart';
import 'package:vida_demo/screens/premios_screen.dart';
import 'package:vida_demo/screens/registro_screen.dart';
import 'package:vida_demo/screens/social_screen.dart';
import 'package:vida_demo/theme.dart';
import 'package:vida_demo/widgets/globo_sin_poliza.dart';

/// Quien entra con "Aún no tengo póliza" ve la app completa, pero sin
/// canje ni La Liga, y Mi Plan le ofrece agregar la póliza o buscar un
/// plan. Quien la vincula ve SU póliza en Mi Plan y Perfil.
void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  // Cada test deja la app como la encontró: con póliza.
  tearDown(() => tienePoliza.value = true);

  Future<void> montar(
    WidgetTester tester,
    Widget pantalla, {
    Object? argumentos,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.temaClaro,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: TemaVida(child: child!),
        ),
        onGenerateRoute: (ajustes) => MaterialPageRoute(
          settings: RouteSettings(arguments: argumentos),
          builder: (_) => pantalla,
        ),
      ),
    );
    await tester.pump();
  }

  group('La sesión', () {
    test('sin póliza no está verificada y lo recuerda', () {
      const sesion = Sesion(
        token: 't',
        correo: 'ana@gmail.com',
        nombre: 'Ana',
        sinPoliza: true,
      );
      expect(sesion.polizaVerificada, isFalse);
      final leida = Sesion.desdeJson(sesion.toJson());
      expect(leida.sinPoliza, isTrue);
      expect(leida.polizaVerificada, isFalse);
    });

    test('la póliza escrita llena Mi Plan y Perfil', () {
      final poliza = PolizaRegistro(
        aseguradora: 'Seguros Ejemplo',
        numero: 'AB-777',
        inicioVigencia: DateTime(2026, 3, 15),
      );
      final sesion = Sesion(
        token: 't',
        correo: 'ana@gmail.com',
        nombre: 'Ana',
        poliza: poliza,
      );
      expect(Sesion.desdeJson(sesion.toJson()).poliza?.numero, 'AB-777');

      final antes = Datos.i;
      addTearDown(() => Datos.i = antes);
      usarSesion(sesion);

      final perfil = Datos.i.perfil;
      expect(tienePoliza.value, isTrue);
      expect(perfil.nombre, 'Ana');
      expect(perfil.poliza.numero, 'AB-777');
      expect(perfil.aseguradora.nombre, 'Seguros Ejemplo');
      expect(perfil.poliza.vigencia, '15 mar 2026 – 14 mar 2027');
      expect(perfil.poliza.fechaRenovacion, '15 mar 2027');
    });
  });

  testWidgets('Premios: sin póliza, el botón de canjear lleva candado', (
    tester,
  ) async {
    tienePoliza.value = false;
    final premio = Datos.i.catalogo.premios.first;
    await montar(tester, const PremioDetalleScreen(), argumentos: premio);

    expect(find.text('CANJEAR PREMIO'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.lock_fill), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);

    // Al entrar todavía no está: sale un momento después, solo.
    expect(find.text(mensajeSinPoliza), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text(mensajeSinPoliza), findsOneWidget);

    // Se va solo a los 3 segundos...
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text(mensajeSinPoliza), findsNothing);

    // ...y vuelve al tocar el botón, otro rato.
    await tester.tap(find.byKey(llaveBotonCanjear));
    await tester.pumpAndSettle();
    expect(find.text(mensajeSinPoliza), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Social: sin póliza, La Liga con candado y Mis competencias '
      'igual', (tester) async {
    tienePoliza.value = false;
    await montar(tester, const SocialScreen());

    expect(find.byKey(llaveLigaConCandado), findsOneWidget);
    expect(find.byKey(llaveTarjetaLiga), findsNothing);
    expect(find.text('MIS COMPETENCIAS'), findsOneWidget);

    expect(find.text(mensajeSinPoliza), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text(mensajeSinPoliza), findsOneWidget);

    // Se va a los 3 segundos.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text(mensajeSinPoliza), findsNothing);

    // Con el mouse encima de la tarjeta vuelve, y al salir se va.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(llaveLigaConCandado)));
    await tester.pumpAndSettle();
    expect(find.text(mensajeSinPoliza), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text(mensajeSinPoliza), findsNothing);
  });

  testWidgets('Mis cupones: sin póliza, no hay cupones y lleva a Mi Plan', (
    tester,
  ) async {
    tienePoliza.value = false;
    await montar(
      tester,
      const PremiosScreen(vistaInicial: VistaPremios.cupones),
    );
    expect(find.byKey(llaveCuponesIrAMiPlan), findsOneWidget);
    expect(find.text('Sin póliza, sin cupones'), findsOneWidget);
  });

  testWidgets('Mi Plan: sin póliza, solo agregar póliza y buscar plan', (
    tester,
  ) async {
    tienePoliza.value = false;
    await montar(tester, const MiPlanScreen());

    expect(find.byKey(llaveAgregarPoliza), findsOneWidget);
    expect(find.byKey(llaveBuscarPlan), findsOneWidget);
    expect(find.text('TU CASHBACK DE ESTE AÑO DE PÓLIZA'), findsNothing);

    // El cotizador todavía no existe: buscar plan lo avisa.
    await tester.tap(find.byKey(llaveBuscarPlan));
    await tester.pumpAndSettle();
    expect(find.text('El cotizador viene pronto'), findsOneWidget);
  });

  testWidgets('Mi Plan: agregar póliza avisa antes que se empieza de cero', (
    tester,
  ) async {
    tienePoliza.value = false;
    await montar(tester, const MiPlanScreen());

    // Cancelar cierra el aviso y se queda en Mi Plan.
    await tester.tap(find.byKey(llaveAgregarPoliza));
    await tester.pumpAndSettle();
    expect(find.text('Empiezas de cero'), findsOneWidget);
    expect(find.textContaining('vuelven a cero'), findsOneWidget);
    expect(
      find.textContaining('Tus monedas se quedan como están'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Empiezas de cero'), findsNothing);
    expect(find.byType(AgregarPolizaScreen), findsNothing);

    // Siguiente lleva al formulario de la póliza.
    await tester.tap(find.byKey(llaveAgregarPoliza));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.byType(AgregarPolizaScreen), findsOneWidget);
  });

  test('quien agrega la póliza después arranca en 0 puntos y Nivel 0', () {
    const sinPoliza = Sesion(
      token: 't',
      correo: 'ana@gmail.com',
      nombre: 'Ana',
      sinPoliza: true,
    );
    final conPoliza = sinPoliza.conPoliza(
      PolizaRegistro(
        aseguradora: 'Seguros Ejemplo',
        numero: 'AB-777',
        inicioVigencia: DateTime(2026, 3, 15),
      ),
      pendiente: false,
      compartirConAseguradora: false,
    );
    expect(conPoliza.empiezaDeCero, isTrue);
    expect(Sesion.desdeJson(conPoliza.toJson()).empiezaDeCero, isTrue);

    final antes = Datos.i;
    addTearDown(() => Datos.i = antes);
    expect(antes.resumen.puntosAno, greaterThan(0));
    usarSesion(conPoliza);
    expect(Datos.i.resumen.puntosAno, 0);
    expect(Datos.i.resumen.nivel, 0);
    expect(Datos.i.resumen.cashback.proyectadoQ, 0);
  });

  testWidgets('Mi Plan: con póliza, la pantalla de siempre', (tester) async {
    await montar(tester, const MiPlanScreen());
    expect(find.byKey(llaveAgregarPoliza), findsNothing);
  });
}
