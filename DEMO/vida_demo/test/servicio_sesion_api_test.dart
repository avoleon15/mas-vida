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
  late Map<String, http.Response Function()> respuestas;

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

  test('si el servidor no contesta, igual se cierra la sesión', () async {
    respuestas['/api/v1/logout'] = () => throw http.ClientException('sin red');
    final s = servicio();
    await s.iniciarSesion('ana@correo.gt', 'clave');

    await s.cerrarSesion();

    expect(s.cliente.token, isNull);
    expect(await AlmacenSesion().leer(), isNull);
  });
}
