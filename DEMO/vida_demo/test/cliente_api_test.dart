import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vida_demo/datos/cliente_api.dart';

// ============================================================
// El cliente de la API contra un servidor falso. Lo que se prueba es
// que Flutter pida lo mismo que espera Django (rutas, token, formato de
// fecha) y que lea bien lo que Django devuelve.
// ============================================================

const _historial = {
  'historial': [
    {
      'fecha': '2026-09-21',
      'puntos_pasos': 100,
      'puntos_intensidad': 150,
      'puntos_brutos': 250,
      'puntos_dia': 200,
      'tope_diario_aplicado': true,
      'version_regla': 1,
    },
  ],
};

void main() {
  test('el login manda usuario y contraseña y guarda el token', () async {
    late http.Request pedido;
    final api = ClienteApi(
      baseUrl: 'http://api',
      cliente: MockClient((r) async {
        pedido = r;
        return http.Response(
          jsonEncode({
            'token': 'abc123',
            'expiry': '2026-11-04T10:15:00-06:00',
            'usuario_id': 'u-1',
          }),
          200,
        );
      }),
    );

    final inicio = await api.iniciarSesion('prueba', 'masvida123');

    expect(pedido.method, 'POST');
    expect(pedido.url.toString(), 'http://api/api/v1/login');
    expect(jsonDecode(pedido.body), {
      'username': 'prueba',
      'password': 'masvida123',
    });
    expect(inicio.token, 'abc123');
    expect(inicio.usuarioId, 'u-1');
    expect(api.token, 'abc123');
  });

  test(
    'el registro no inventa el usuario_id: lo lee de la respuesta',
    () async {
      late http.Request pedido;
      final api = ClienteApi(
        baseUrl: 'http://api',
        cliente: MockClient((r) async {
          pedido = r;
          return http.Response(
            jsonEncode({
              'token': 'abc123',
              'expiry': '2026-11-04T10:15:00-06:00',
              'usuario_id': 'u-del-servidor',
              'username': 'ana@correo.gt',
            }),
            201,
          );
        }),
      );

      final inicio = await api.registrar(
        correo: 'ana@correo.gt',
        contrasena: 'Clave-segura-2026',
        fechaNacimiento: DateTime(1990, 5, 17),
      );

      expect(pedido.url.path, '/api/v1/registro');
      expect(jsonDecode(pedido.body), {
        'username': 'ana@correo.gt',
        'password': 'Clave-segura-2026',
        'birth_date': '1990-05-17',
      });
      expect(inicio.usuarioId, 'u-del-servidor');
      expect(api.token, 'abc123');
    },
  );

  group('401: la sesión venció o la cerraron', () {
    test('avisa con el token que se mandó', () async {
      final rechazados = <String>[];
      final api =
          ClienteApi(
              baseUrl: 'http://api',
              cliente: MockClient(
                (_) async => http.Response(
                  jsonEncode({'detail': 'Invalid token.'}),
                  401,
                ),
              ),
            )
            ..token = 'abc123'
            ..alRechazarToken = rechazados.add;

      await expectLater(
        api.historialDePuntos(),
        throwsA(isA<ErrorApi>().having((e) => e.codigo, 'codigo', 401)),
      );
      expect(rechazados, ['abc123']);
    });

    test('otro error no avisa', () async {
      final rechazados = <String>[];
      final api =
          ClienteApi(
              baseUrl: 'http://api',
              cliente: MockClient((_) async => http.Response('{}', 500)),
            )
            ..token = 'abc123'
            ..alRechazarToken = rechazados.add;

      await expectLater(api.historialDePuntos(), throwsA(isA<ErrorApi>()));
      expect(rechazados, isEmpty);
    });
  });

  group('cerrar sesión en el servidor', () {
    test('manda el token a /logout y dice si se cerró', () async {
      late http.Request pedido;
      final api = ClienteApi(
        baseUrl: 'http://api',
        cliente: MockClient((r) async {
          pedido = r;
          return http.Response('', 204);
        }),
      )..token = 'abc123';

      expect(await api.cerrarSesionEnServidor(), isTrue);
      expect(pedido.method, 'POST');
      expect(pedido.url.path, '/api/v1/logout');
      expect(pedido.headers['Authorization'], 'Token abc123');
    });

    test('sin red no falla hacia afuera', () async {
      final api = ClienteApi(
        baseUrl: 'http://api',
        cliente: MockClient((_) async => throw http.ClientException('sin red')),
      )..token = 'abc123';

      expect(await api.cerrarSesionEnServidor(), isFalse);
    });

    test('con el token ya vencido (401) tampoco', () async {
      final api = ClienteApi(
        baseUrl: 'http://api',
        cliente: MockClient((_) async => http.Response('{}', 401)),
      )..token = 'abc123';

      expect(await api.cerrarSesionEnServidor(), isFalse);
    });

    test('sin sesión no llama al servidor', () async {
      var llamadas = 0;
      final api = ClienteApi(
        baseUrl: 'http://api',
        cliente: MockClient((_) async {
          llamadas++;
          return http.Response('', 204);
        }),
      );

      expect(await api.cerrarSesionEnServidor(), isFalse);
      expect(llamadas, 0);
    });
  });

  test('un login rechazado tira ErrorApi', () async {
    final api = ClienteApi(
      baseUrl: 'http://api',
      cliente: MockClient((_) async => http.Response('{}', 400)),
    );

    expect(
      () => api.iniciarSesion('prueba', 'mal'),
      throwsA(isA<ErrorApi>().having((e) => e.codigo, 'codigo', 400)),
    );
  });

  test('el historial manda el token y las fechas sin hora', () async {
    late http.Request pedido;
    final api = ClienteApi(
      baseUrl: 'http://api',
      cliente: MockClient((r) async {
        pedido = r;
        return http.Response(jsonEncode(_historial), 200);
      }),
    )..token = 'abc123';

    final dias = await api.historialDePuntos(
      desde: DateTime(2026, 9, 1),
      hasta: DateTime(2026, 9, 21, 18, 30),
    );

    expect(pedido.url.path, '/api/v1/historial');
    expect(pedido.url.queryParameters, {
      'fecha_desde': '2026-09-01',
      'fecha_hasta': '2026-09-21',
    });
    expect(pedido.headers['Authorization'], 'Token abc123');

    final dia = dias.single;
    expect(dia.fecha, DateTime(2026, 9, 21));
    expect(dia.puntosPasos, 100);
    expect(dia.puntosIntensidad, 150);
    expect(dia.puntosBrutos, 250);
    expect(dia.puntosDia, 200);
    expect(dia.topeDiarioAplicado, isTrue);
    expect(dia.versionRegla, 1);
  });

  test('sin iniciar sesión no se pide el historial', () async {
    var llamadas = 0;
    final api = ClienteApi(
      baseUrl: 'http://api',
      cliente: MockClient((_) async {
        llamadas++;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(api.historialDePuntos(), throwsA(isA<ErrorApi>()));
    expect(llamadas, 0);
  });

  test('un error del servidor trae su mensaje', () async {
    final api = ClienteApi(
      baseUrl: 'http://api',
      cliente: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'mensaje': 'fecha_desde no puede ser mayor a fecha_hasta',
          }),
          400,
        ),
      ),
    )..token = 'abc123';

    expect(
      () => api.historialDePuntos(),
      throwsA(
        isA<ErrorApi>().having(
          (e) => e.mensaje,
          'mensaje',
          'fecha_desde no puede ser mayor a fecha_hasta',
        ),
      ),
    );
  });
}
