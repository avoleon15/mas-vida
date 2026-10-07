import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/healthkit_bridge.dart';

// ============================================================
// EL WRAPPER DEL CANAL NATIVO — `actualizarSesion`.
//
// Lo que se protege: que el token llegue a Swift con el nombre de método y
// la forma que espera AppDelegate.swift
// (`{ "token": String?, "usuario_id": String? }`), que el
// cierre de sesión viaje como `null`, y que cada respuesta posible se lea
// bien — incluida una que esta versión no conoce.
//
// El flujo (entrar, salir, abrir la app) lo cubre sesion_nativa_test.dart.
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
    test(
      'el token viaja en el método actualizarSesion, bajo la clave token',
      () async {
        responder((_) => {'estado': 'ok'});

        await HealthKitBridge().actualizarSesion('abc123');

        expect(llamadas, hasLength(1));
        expect(llamadas.single.method, 'actualizarSesion');
        expect(llamadas.single.arguments, {
          'token': 'abc123',
          'usuario_id': null,
        });
      },
    );

    test('el usuario_id viaja junto al token: Swift decide con él si cambió '
        'la persona', () async {
      responder((_) => {'estado': 'ok'});

      await HealthKitBridge().actualizarSesion('abc123', usuarioId: 'u-1');

      expect(llamadas.single.arguments, {
        'token': 'abc123',
        'usuario_id': 'u-1',
      });
    });

    test(
      'cerrar sesión manda la clave token con null, no un mapa vacío',
      () async {
        responder((_) => {'estado': 'ok'});

        await HealthKitBridge().actualizarSesion(null);

        final argumentos = llamadas.single.arguments as Map;
        expect(argumentos.containsKey('token'), isTrue);
        expect(argumentos['token'], isNull);
      },
    );

    test('el token se manda tal cual: recortar es trabajo de Swift', () async {
      responder((_) => {'estado': 'ok'});

      await HealthKitBridge().actualizarSesion('  abc123  ');

      expect(llamadas.single.arguments, {
        'token': '  abc123  ',
        'usuario_id': null,
      });
    });
  });

  group('lo que se lee', () {
    Future<EstadoSesionNativa> con(Object? respuesta) {
      responder((_) => respuesta);
      return HealthKitBridge().actualizarSesion('abc123');
    }

    test('ok', () async {
      expect(await con({'estado': 'ok'}), EstadoSesionNativa.ok);
    });

    test('error_almacenamiento', () async {
      expect(
        await con({
          'estado': 'error_almacenamiento',
          'detalle': 'No se pudo guardar la sesión en el Keychain.',
        }),
        EstadoSesionNativa.errorAlmacenamiento,
      );
    });

    test('un estado que esta versión no conoce es desconocido', () async {
      expect(
        await con({'estado': 'algo_nuevo'}),
        EstadoSesionNativa.desconocido,
      );
      expect(await con({'estado': 'OK'}), EstadoSesionNativa.desconocido);
    });

    test('una respuesta vacía es desconocido', () async {
      expect(await con(null), EstadoSesionNativa.desconocido);
    });

    // Swift solo responde con FlutterError si los argumentos llegan mal: es
    // un error de programación. Contarlo como falla del Keychain mandaría a
    // buscar el problema al lugar equivocado.
    test(
      'un FlutterError de Swift es desconocido, no error de almacenamiento',
      () async {
        responder(
          (_) => throw PlatformException(
            code: 'ARGUMENTOS_INVALIDOS',
            message:
                'actualizarSesion espera { "token": String?, "usuario_id": String? }',
          ),
        );

        expect(
          await HealthKitBridge().actualizarSesion('abc123'),
          EstadoSesionNativa.desconocido,
        );
      },
    );
  });
}
