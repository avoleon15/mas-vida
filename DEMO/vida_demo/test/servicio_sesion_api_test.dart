import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vida_demo/datos/cliente_api.dart';
import 'package:vida_demo/datos/sesion.dart';

// ============================================================
// LA SESIÓN CONTRA LA API (A35): el usuario_id llega a Swift, un 401
// cierra la sesión y avisa, y cerrar sesión pasa por el servidor.
// ============================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('com.assures.masvida/healthkit');

  /// Lo que Swift recibió en `actualizarSesion`, en orden.
  late List<Map<Object?, Object?>> swift;

  /// Las peticiones que llegaron al servidor falso.
  late List<http.Request> pedidos;

  /// Lo que contesta el servidor falso a cada ruta.
  late Map<String, FutureOr<http.Response> Function()> respuestas;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    swift = [];
    pedidos = [];
    respuestas = {
      '/api/v1/login': () => http.Response(
        jsonEncode({
          'token': 'tok-1',
          'expiry': '2026-11-04T10:15:00-06:00',
          'usuario_id': 'u-ana',
        }),
        200,
      ),
      '/api/v1/logout': () => http.Response('', 204),
      '/api/v1/historial': () =>
          http.Response(jsonEncode({'detail': 'Invalid token.'}), 401),
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (llamada) async {
          if (llamada.method == 'actualizarSesion') {
            swift.add(llamada.arguments as Map);
          }
          return {'estado': 'ok'};
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  ServicioSesionApi servicio() => ServicioSesionApi(
    cliente: ClienteApi(
      baseUrl: 'http://api',
      cliente: MockClient((r) async {
        pedidos.add(r);
        return respuestas[r.url.path]!();
      }),
    ),
  );

  group('qué ve la persona cuando algo sale mal', () {
    http.Response json(Object cuerpo, int codigo) => http.Response(
      jsonEncode(cuerpo),
      codigo,
      headers: {'content-type': 'application/json'},
    );
    const mensajeBloqueo = 'Demasiados intentos. Inténtalo de nuevo más tarde.';
    final bloqueado = json({
      'error': 'demasiados_intentos',
      'mensaje': mensajeBloqueo,
      'reintentar_en': 42,
    }, 429);
    final caido = http.Response('<html>Server Error</html>', 500);

    Future<String> alEntrar() async {
      try {
        await servicio().iniciarSesion('ana@correo.gt', 'clave');
        return 'entró';
      } on ErrorSesion catch (e) {
        return e.mensaje;
      }
    }

    Future<String> alRegistrarse() async {
      try {
        await servicio().registrar(
          DatosRegistro(
            nombre: 'Ana',
            correo: 'ana@correo.gt',
            contrasena: 'Clave-segura-2026',
            fechaNacimiento: DateTime(1990, 5, 17),
          ),
        );
        return 'entró';
      } on ErrorSesion catch (e) {
        return e.mensaje;
      }
    }

    test('login con la contraseña mal (400): no coinciden', () async {
      respuestas['/api/v1/login'] = () => json({
        'non_field_errors': ['Unable to log in with provided credentials.'],
      }, 400);
      expect(
        await alEntrar(),
        startsWith('El correo o la contraseña no coinciden'),
      );
    });

    test('login bloqueado (429): el mensaje del servidor', () async {
      respuestas['/api/v1/login'] = () => bloqueado;
      expect(await alEntrar(), mensajeBloqueo);
    });

    test('login con el servidor caído (500): algo salió mal', () async {
      respuestas['/api/v1/login'] = () => caido;
      expect(await alEntrar(), startsWith('Algo salió mal'));
    });

    test('login sin red: no pudimos conectarnos', () async {
      respuestas['/api/v1/login'] = () => throw http.ClientException('sin red');
      expect(await alEntrar(), startsWith('No pudimos conectarnos'));
    });

    test('registro con un campo mal (400): el mensaje del campo', () async {
      respuestas['/api/v1/registro'] = () => json({
        'username': ['Este nombre de usuario ya existe.'],
      }, 400);
      expect(await alRegistrarse(), 'Este nombre de usuario ya existe.');
    });

    test('registro bloqueado (429): el mensaje del servidor', () async {
      respuestas['/api/v1/registro'] = () => bloqueado;
      expect(await alRegistrarse(), mensajeBloqueo);
    });

    test('registro con el servidor caído (500): algo salió mal', () async {
      respuestas['/api/v1/registro'] = () => caido;
      expect(await alRegistrarse(), startsWith('Algo salió mal'));
    });
  });

  test('al entrar se guarda el usuario_id y Swift lo recibe', () async {
    final s = servicio();

    final sesion = await s.iniciarSesion('ana@correo.gt', 'clave');
    await pumpEventQueue();

    expect(sesion.usuarioId, 'u-ana');
    expect((await s.actual())?.usuarioId, 'u-ana');
    expect(swift.first, {'token': 'tok-1', 'usuario_id': 'u-ana'});
  });

  test('un 401 cierra la sesión, se lo dice a Swift y avisa', () async {
    final s = servicio();
    await s.iniciarSesion('ana@correo.gt', 'clave');
    final avisosAntes = sesionRechazada.value;

    await expectLater(s.cliente.historialDePuntos(), throwsA(isA<ErrorApi>()));
    await pumpEventQueue();

    expect(sesionRechazada.value, avisosAntes + 1);
    expect(s.cliente.token, isNull);
    expect(await AlmacenSesion().leer(), isNull);
    expect(swift.last['token'], isNull);
  });

  test('el 401 tardío de una sesión anterior no cierra la de ahora', () async {
    final s = servicio();
    await s.iniciarSesion('ana@correo.gt', 'clave');
    final avisosAntes = sesionRechazada.value;
    // Mientras volvía la respuesta, la persona entró de nuevo.
    s.cliente.token = 'tok-2';

    s.cliente.alRechazarToken!('tok-1');
    await pumpEventQueue();

    expect(sesionRechazada.value, avisosAntes);
    expect(s.cliente.token, 'tok-2');
  });

  test('cerrar sesión llama a /logout y borra las dos copias', () async {
    final s = servicio();
    await s.iniciarSesion('ana@correo.gt', 'clave');

    await s.cerrarSesion();
    await pumpEventQueue();

    final logout = pedidos.singleWhere((p) => p.url.path == '/api/v1/logout');
    expect(logout.headers['Authorization'], 'Token tok-1');
    expect(s.cliente.token, isNull);
    expect(await AlmacenSesion().leer(), isNull);
    expect(swift.last['token'], isNull);
  });

  test(
    'cerrar sesión no espera al servidor: borra todo en el momento',
    () async {
      // El servidor no contesta hasta que termina la prueba.
      final colgado = Completer<http.Response>();
      addTearDown(() => colgado.complete(http.Response('', 204)));
      respuestas['/api/v1/logout'] = () => colgado.future;
      final s = servicio();
      await s.iniciarSesion('ana@correo.gt', 'clave');

      // Si esperara la respuesta, tardaría los 5 s del límite.
      await s.cerrarSesion().timeout(const Duration(seconds: 1));
      await pumpEventQueue();

      expect(s.cliente.token, isNull);
      expect(await AlmacenSesion().leer(), isNull);
      expect(swift.last['token'], isNull);
      // Y el aviso salió igual, con el token de la sesión que se cerró.
      final logout = pedidos.singleWhere((p) => p.url.path == '/api/v1/logout');
      expect(logout.headers['Authorization'], 'Token tok-1');
    },
  );

  test('si el servidor no contesta, igual se cierra la sesión', () async {
    respuestas['/api/v1/logout'] = () => throw http.ClientException('sin red');
    final s = servicio();
    await s.iniciarSesion('ana@correo.gt', 'clave');

    await s.cerrarSesion();

    expect(s.cliente.token, isNull);
    expect(await AlmacenSesion().leer(), isNull);
  });
}
