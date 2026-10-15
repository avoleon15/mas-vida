import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/healthkit_bridge.dart';
import 'package:vida_demo/datos/sesion.dart';

/// El tercer método del MethodChannel: `actualizarSesion` (contrato,
/// "MethodChannel"). Swift necesita su propia copia del token para firmar
/// el `sync`, y las dos copias se mueven juntas: al entrar, al salir y al
/// abrir la app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('com.assures.masvida/healthkit');

  /// Lo que Swift recibió, en orden (solo el token).
  late List<Object?> recibidos;

  /// Lo mismo, con el `usuario_id`.
  late List<Map<Object?, Object?>> argumentos;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    recibidos = [];
    argumentos = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (llamada) async {
          if (llamada.method != 'actualizarSesion') return null;
          recibidos.add((llamada.arguments as Map)['token']);
          argumentos.add(llamada.arguments as Map);
          return {'estado': 'ok'};
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  const sesion = Sesion(token: 'abc', correo: 'ana@correo.gt', nombre: 'Ana');

  test('al entrar, Swift recibe el token', () async {
    await AlmacenSesion().guardar(sesion);
    await pumpEventQueue();
    expect(recibidos, ['abc']);
  });

  test('al salir, Swift recibe null: se borran las dos copias', () async {
    final almacen = AlmacenSesion();
    await almacen.guardar(sesion);
    await almacen.borrar();
    await pumpEventQueue();
    expect(recibidos, ['abc', null]);
    expect(await almacen.leer(), isNull);
  });

  test('al abrir la app se le vuelve a mandar lo que haya', () async {
    final almacen = AlmacenSesion();
    await almacen.guardar(sesion);
    await pumpEventQueue();
    recibidos.clear();
    await almacen.leer();
    await pumpEventQueue();
    expect(recibidos, ['abc']);
  });

  test(
    'Swift recibe también el usuario_id, al entrar y al abrir la app',
    () async {
      final almacen = AlmacenSesion();
      await almacen.guardar(
        const Sesion(
          token: 'abc',
          usuarioId: 'u-ana',
          correo: 'ana@correo.gt',
          nombre: 'Ana',
        ),
      );
      await almacen.leer();
      await pumpEventQueue();
      expect(argumentos, [
        {'token': 'abc', 'usuario_id': 'u-ana'},
        {'token': 'abc', 'usuario_id': 'u-ana'},
      ]);
    },
  );

  test(
    'una sesión guardada antes de A35 (sin usuario_id) se sigue leyendo',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'sesion': '{"token":"abc","correo":"ana@correo.gt","nombre":"Ana"}',
      });
      final sesion = await AlmacenSesion().leer();
      await pumpEventQueue();
      expect(sesion?.token, 'abc');
      expect(sesion?.usuarioId, isNull);
      expect(argumentos.single, {'token': 'abc', 'usuario_id': null});
    },
  );

  test('sin lado nativo (Web, tests) no falla', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
    expect(
      await HealthKitBridge().actualizarSesion('abc'),
      EstadoSesionNativa.noDisponible,
    );
  });
}
