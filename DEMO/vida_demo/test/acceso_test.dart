import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/sesion.dart';
import 'package:vida_demo/screens/acceso_screen.dart';
import 'package:vida_demo/screens/registro_screen.dart';
import 'package:vida_demo/validaciones_acceso.dart';
import 'package:vida_demo/widgets/hoja_terminos.dart';

import 'ayudas.dart';

ServicioSesion _servicio() => ServicioSesionLocal(demora: Duration.zero);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('Reglas del ingreso', () {
    test('un correo tiene que tener forma de correo', () {
      expect(correoValido('ana@gmail.com'), isTrue);
      expect(correoValido('  ana@gmail.com '), isTrue);
      expect(correoValido('ana@gmail'), isFalse);
      expect(correoValido('ana gmail.com'), isFalse);
      expect(correoValido(''), isFalse);
    });

    test('la contraseña pide 8 caracteres y al menos una letra', () {
      expect(contrasenaValida('caminar1'), isTrue);
      expect(contrasenaValida('corto1'), isFalse);
      // Django rechaza las contraseñas que son solo números.
      expect(contrasenaValida('12345678'), isFalse);
    });

    test('la edad cuenta el cumpleaños del mismo día', () {
      final hoy = DateTime(2026, 9, 30);
      expect(edadEn(DateTime(1996, 9, 30), hoy), 30);
      expect(edadEn(DateTime(1996, 10, 1), hoy), 29);
      expect(edadEn(DateTime(1966, 1, 1), hoy), 60);
    });

    test('nadie menor de la edad mínima puede elegir su fecha', () {
      final hoy = DateTime(2026, 9, 30);
      expect(edadEn(nacimientoMaximo(hoy), hoy), edadMinima);
    });
  });

  group('Sesión', () {
    test('se guarda y se lee igual del llavero', () async {
      final almacen = AlmacenSesion();
      final sesion = Sesion(
        token: 'abc',
        correo: 'ana@gmail.com',
        nombre: 'Ana',
        fechaNacimiento: DateTime(1990, 5, 4),
        polizaPendiente: true,
        compartirConAseguradora: true,
        terminosAceptados: versionTerminos,
      );
      await almacen.guardar(sesion);
      final leida = await almacen.leer();
      expect(leida!.token, 'abc');
      expect(leida.fechaNacimiento, DateTime(1990, 5, 4));
      expect(leida.polizaPendiente, isTrue);
      expect(leida.terminosAceptados, versionTerminos);

      await almacen.borrar();
      expect(await almacen.leer(), isNull);
    });

    test('el nombre se saca del correo mientras el servidor no lo manda', () {
      expect(nombreDesdeCorreo('ana.lopez@gmail.com'), 'Ana');
      expect(nombreDesdeCorreo('LUIS_22@x.com'), 'Luis');
    });
  });

  group('Términos', () {
    String todo() =>
        seccionesTerminos.expand((s) => [s.titulo, ...s.parrafos]).join(' ');

    test('dicen qué se lee de Salud y que solo se lee', () {
      expect(todo(), contains('HealthKit'));
      expect(
        todo(),
        contains('tus pasos, tu ritmo cardíaco y tus entrenamientos'),
      );
      expect(todo(), contains('Nunca escribe, cambia ni borra nada en Salud'));
    });

    test('dicen la verdad de lo que ve la aseguradora', () {
      // Resumen diario POR PERSONA, nunca el dato crudo (CLAUDE.md).
      expect(todo(), contains('un resumen de cada día'));
      expect(todo(), contains('Nunca le mandamos el detalle minuto a minuto'));
    });

    test('el cashback nunca se presenta como descuento', () {
      expect(todo(), contains('Nunca es un descuento'));
      expect(todo(), isNot(contains('descuento en tu prima')));
    });

    test('monedas: vencen por temporada, sin tope, cupones a 3 semanas', () {
      expect(todo(), contains('4 temporadas de 13 semanas'));
      expect(todo(), contains('la última tiene 14'));
      expect(todo(), contains('No hay límite'));
      expect(todo(), isNot(contains('90 días')));
      expect(todo(), isNot(contains('hasta 100')));
      expect(todo(), contains('3 semanas (21 días)'));
      // Hasta el 5 de octubre de 2026 eran 60 días.
      expect(todo(), isNot(contains('60 días')));
    });

    test('no prometen lo que ya no existe (revisión del 6 de octubre)', () {
      // La Liga es un solo grupo, sin franjas de edad (2 de octubre).
      expect(todo(), isNot(contains('grupos de edad')));
      // Los pasos se eligen por hora, no por prioridad del reloj (1 de octubre).
      expect(todo(), isNot(contains('tienen prioridad')));
      expect(todo(), contains('en cada hora cuenta el dispositivo'));
      // Los demás ven también los puntos (2 de octubre), nunca los pasos.
      expect(todo(), isNot(contains('tu nombre y tu posición')));
      expect(todo(), contains('tu posición en la tabla y tus puntos'));
      expect(todo(), contains('Nunca ven tus pasos'));
      // Solo mayores de 18 (6 de octubre).
      expect(todo(), contains('solo para mayores de 18 años'));
    });

    test('siempre de tú, nunca de vos', () {
      // Con límite de palabra: "dispositivos" no es voseo.
      final voseo = RegExp(r'\b(vos|tenés|podés|aceptás|querés|elegí)\b');
      expect(voseo.hasMatch(todo()), isFalse);
    });
  });

  group('Pantalla de ingreso', () {
    // Un iPhone 14 y no la ventana de 800 × 600 de los tests: es la
    // pantalla para la que está pensada.
    setUp(() {
      final vista =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      vista.physicalSize = const Size(1170, 2532);
      vista.devicePixelRatio = 3;
    });
    tearDown(
      () => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
          .reset(),
    );

    testWidgets('"Acceder por prueba" entra sin llenar nada', (tester) async {
      Sesion? entro;
      await montarPantalla(
        tester,
        AccesoScreen(servicio: _servicio(), alEntrar: (s) => entro = s),
      );
      expect(find.text('Acceder por prueba'), findsOneWidget);

      await tester.ensureVisible(find.byKey(llaveAccesoPrueba));
      await tester.tap(find.byKey(llaveAccesoPrueba));
      await tester.pumpAndSettle();

      expect(entro, isNotNull);
      expect(entro!.esPrueba, isTrue);
    });

    testWidgets('"Entrar" se apaga hasta tener correo y contraseña', (
      tester,
    ) async {
      Sesion? entro;
      await montarPantalla(
        tester,
        AccesoScreen(servicio: _servicio(), alEntrar: (s) => entro = s),
      );

      await tester.tap(find.byKey(llaveEntrar));
      await tester.pumpAndSettle();
      expect(entro, isNull);

      await tester.enterText(
        find.descendant(
          of: find.byKey(llaveCorreoAcceso),
          matching: find.byType(EditableText),
        ),
        'ana@gmail',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(llaveContrasenaAcceso),
          matching: find.byType(EditableText),
        ),
        'caminar1',
      );
      await tester.pump();
      await tester.tap(find.byKey(llaveEntrar));
      await tester.pumpAndSettle();

      // Correo mal escrito: avisa y no entra.
      expect(find.textContaining('Ese correo no se ve bien'), findsOneWidget);
      expect(entro, isNull);

      await tester.enterText(
        find.descendant(
          of: find.byKey(llaveCorreoAcceso),
          matching: find.byType(EditableText),
        ),
        'ana@gmail.com',
      );
      await tester.pump();
      await tester.tap(find.byKey(llaveEntrar));
      // Sin pumpAndSettle: al entrar el botón se queda cargando (en la
      // app la pantalla se va enseguida) y el indicador no se asienta.
      await tester.pump(const Duration(milliseconds: 100));

      expect(entro?.correo, 'ana@gmail.com');
    });
  });

  group('Registro', () {
    Future<void> escribir(WidgetTester tester, String placeholder, String t) =>
        tester.enterText(
          find.ancestor(
            of: find.text(placeholder),
            matching: find.byType(CupertinoTextField),
          ),
          t,
        );

    Future<void> siguiente(WidgetTester tester) async {
      await tester.tap(find.byKey(llaveSiguienteRegistro));
      await tester.pumpAndSettle();
    }

    testWidgets('sin póliza son 4 pasos y termina con la cuenta creada', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      Sesion? creada;
      await montarPantalla(
        tester,
        Builder(
          builder: (context) => CupertinoButton(
            child: const Text('abrir'),
            onPressed: () async {
              creada = await Navigator.of(context).push<Sesion>(
                CupertinoPageRoute(
                  // La ruta queda ARRIBA del MediaQuery de
                  // `montarPantalla`: hay que volver a apagarle las
                  // animaciones, o la moneda gira para siempre.
                  builder: (ruta) => MediaQuery(
                    data: MediaQuery.of(ruta).copyWith(disableAnimations: true),
                    child: RegistroScreen(
                      servicio: _servicio(),
                      hoy: DateTime(2026, 9, 30),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      // 1. Tu cuenta
      expect(find.text('Paso 1 de 4'), findsOneWidget);
      await escribir(tester, 'Tu nombre', 'Ana');
      await escribir(tester, 'Correo', 'ana@gmail.com');
      await escribir(tester, 'Contraseña', '1234');
      await tester.pump();
      await siguiente(tester);
      // Contraseña corta: no avanza y dice por qué.
      expect(find.text('Paso 1 de 4'), findsOneWidget);
      expect(find.textContaining('8 caracteres o más y'), findsOneWidget);

      await escribir(tester, 'Contraseña', 'caminar1');
      await tester.pump();
      await siguiente(tester);

      // 2. Tu edad: sin girar la rueda no se puede seguir.
      expect(find.text('Paso 2 de 4'), findsOneWidget);
      // La Liga ya no se arma por edad (2 de octubre): la edad solo ajusta la
      // intensidad y la meta de pasos.
      expect(
        find.textContaining('gente de tu edad', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text(
          'Tu meta semanal de pasos depende de tu edad.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      await siguiente(tester);
      expect(find.text('Paso 2 de 4'), findsOneWidget);

      await tester.drag(find.text('1996'), const Offset(0, 64));
      await tester.pumpAndSettle();
      expect(find.text('años'), findsOneWidget);
      await siguiente(tester);

      // 3. Tu póliza: se puede saltar.
      expect(find.text('Vincula tu póliza'), findsOneWidget);
      await tester.tap(find.byKey(llaveSaltarPoliza));
      await tester.pumpAndSettle();

      // Sin póliza no hay paso de la aseguradora: directo a términos.
      expect(find.text('Paso 4 de 4'), findsOneWidget);
      expect(find.text('Lo importante, en corto'), findsOneWidget);

      // Las dos casillas son obligatorias.
      await tester.ensureVisible(find.byKey(llaveAceptoTerminos));
      await tester.tap(find.byKey(llaveAceptoTerminos));
      await tester.pump();
      await siguiente(tester);
      expect(creada, isNull);

      await tester.ensureVisible(find.byKey(llaveAceptoSalud));
      await tester.tap(find.byKey(llaveAceptoSalud));
      await tester.pump();
      await siguiente(tester);

      expect(creada, isNotNull);
      expect(creada!.nombre, 'Ana');
      expect(creada!.fechaNacimiento, isNotNull);
      expect(creada!.polizaPendiente, isFalse);
      expect(creada!.compartirConAseguradora, isFalse);
      expect(creada!.terminosAceptados, versionTerminos);
    });
  });
}
