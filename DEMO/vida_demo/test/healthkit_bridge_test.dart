import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/healthkit_bridge.dart';

// ============================================================
// EL WRAPPER DEL CANAL NATIVO — `actualizarSesion`.
//
// Lo que se protege: que el token llegue a Swift con el nombre de método y
// la forma que espera AppDelegate.swift (`{ "token": String? }`), que el
// cierre de sesión viaje como `null`, y que cada respuesta posible del
// contrato se lea bien — incluida una que esta versión no conoce.
// ============================================================

const _canal = MethodChannel('com.assures.masvida/healthkit');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final llamadas = <MethodCall>[];

  /// Simula el lado Swift: anota cada llamada y contesta [respuesta].
  void responder(Object? Function(MethodCall) respuesta) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, (call) async {
          llamadas.add(call);
          return respuesta(call);
        });
  }

  setUp(llamadas.clear);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, null),
  );

  group('lo que se manda', () {
    test('el token viaja en el método actualizarSesion, bajo la clave token',
        () async {
      responder((_) => {'estado': 'ok'});

      await HealthKitBridge().actualizarSesion('abc123');

      expect(llamadas, hasLength(1));
      expect(llamadas.single.method, 'actualizarSesion');
      expect(llamadas.single.arguments, {'token': 'abc123'});
    });

    test('cerrar sesión manda la clave token con null, no un mapa vacío',
        () async {
      responder((_) => {'estado': 'ok'});

      await HealthKitBridge().actualizarSesion(null);

      final argumentos = llamadas.single.arguments as Map;
      expect(argumentos.containsKey('token'), isTrue);
      expect(argumentos['token'], isNull);
    });

    test('el token se manda tal cual: recortar es trabajo de Swift', () async {
      responder((_) => {'estado': 'ok'});

      await HealthKitBridge().actualizarSesion('  abc123  ');

      expect(llamadas.single.arguments, {'token': '  abc123  '});
    });
  });

  group('lo que se lee', () {
    test('ok', () async {
      responder((_) => {'estado': 'ok'});

      final r = await HealthKitBridge().actualizarSesion('abc123');

      expect(r.estado, EstadoSesion.ok);
      expect(r.detalle, isNull);
    });

    test('error_almacenamiento trae su detalle', () async {
      responder(
        (_) => {
          'estado': 'error_almacenamiento',
          'detalle': 'No se pudo guardar la sesión en el Keychain (código -25308).',
        },
      );

      final r = await HealthKitBridge().actualizarSesion('abc123');

      expect(r.estado, EstadoSesion.errorAlmacenamiento);
      expect(r.detalle, contains('Keychain'));
    });

    test('un estado que esta versión no conoce es desconocido, no un crash',
        () async {
      responder((_) => {'estado': 'algo_nuevo'});

      final r = await HealthKitBridge().actualizarSesion('abc123');

      expect(r.estado, EstadoSesion.desconocido);
    });

    test('una respuesta vacía es desconocido', () async {
      responder((_) => null);

      final r = await HealthKitBridge().actualizarSesion('abc123');

      expect(r.estado, EstadoSesion.desconocido);
    });

    test('un FlutterError de Swift llega como PlatformException', () async {
      responder(
        (_) => throw PlatformException(
          code: 'ARGUMENTOS_INVALIDOS',
          message: 'actualizarSesion espera { "token": String? }',
        ),
      );

      await expectLater(
        HealthKitBridge().actualizarSesion('abc123'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'ARGUMENTOS_INVALIDOS',
          ),
        ),
      );
    });
  });

  test('los textos del contrato se traducen uno por uno', () {
    expect(EstadoSesion.desde('ok'), EstadoSesion.ok);
    expect(
      EstadoSesion.desde('error_almacenamiento'),
      EstadoSesion.errorAlmacenamiento,
    );
    expect(EstadoSesion.desde(null), EstadoSesion.desconocido);
    expect(EstadoSesion.desde('OK'), EstadoSesion.desconocido);
  });
}
