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
        return http.Response(jsonEncode({'token': 'abc123'}), 200);
      }),
    );

    final token = await api.iniciarSesion('prueba', 'masvida123');

    expect(pedido.method, 'POST');
    expect(pedido.url.toString(), 'http://api/api/v1/login');
    expect(jsonDecode(pedido.body), {
      'username': 'prueba',
      'password': 'masvida123',
    });
    expect(token, 'abc123');
    expect(api.token, 'abc123');
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
