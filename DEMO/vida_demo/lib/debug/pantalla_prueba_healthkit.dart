// Banco de pruebas manual del MethodChannel de HealthKit (A10).
//
// NO ES PARTE DEL PRODUCTO y ninguna ruta apunta aca: el arbol de widgets no
// la alcanza, asi que el tree-shaking la saca del build. Queda en el repo
// para poder repetir la verificacion end-to-end cada vez que se toque el
// canal, sin volver a escribirla.
//
// Como usarla (hace falta un iPhone fisico, HealthKit no existe en el
// simulador, y el backend de Luis corriendo en la IP de baseURLTexto, en
// HealthKitManager.swift):
//
//   1. En lib/main.dart:
//        import 'debug/pantalla_prueba_healthkit.dart';
//        initialRoute: '/debug-healthkit',
//        routes: { '/debug-healthkit': (c) => const PantallaPruebaHealthKit(), ... }
//   2. flutter run  (en debug, NO release: el assertionFailure del registro
//      del canal en AppDelegate solo truena en debug)
//   3. Tarjeta 0 PRIMERO: pegar un token y "Entregar token" -> estado=ok.
//      Sin token el sync nunca firma y el boton 2 siempre da encolado.
//      Boton 1 -> espera estado=concedido, y hasta 7 POST (la primera vez)
//      Boton 2 -> espera estado=ok
//      Boton 2 con el backend apagado -> espera estado=encolado
//      App a background y de vuelta -> el dia encolado llega solo, y se manda
//      desde el ultimo dia enviado hasta hoy (SceneDelegate, ponerseAlDia)
//   4. git checkout lib/main.dart para dejarlo como estaba
//
// Verificado asi el 6 de septiembre de 2026 (todavia sin token, contra
// mock_luis_server.py): los cuatro casos pasaron.
//
// Tarjeta 0 (sesion, desde A31): el token es el que devuelve
// POST /api/v1/login. "Cerrar sesion" -> estado=ok, y el boton 2 vuelve a dar
// encolado (sin sesion). El token nunca se escribe en el log: solo cuantos
// caracteres tiene.
//
// usuario_id (opcional, desde A35): el que devuelve el login. Con el, Swift
// vacia la cola solo si entra OTRA persona. Para probarlo: entregar token A +
// usuario X, encolar un dia (boton 2 con el backend apagado), entregar otro
// token del MISMO usuario X -> el dia sigue en la cola; con un usuario Y -> se
// vacia. Vacio = no se manda (Swift compara el token, como antes de A35). El
// usuario_id no es secreto: si se escribe en el log.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/healthkit_bridge.dart';

class PantallaPruebaHealthKit extends StatefulWidget {
  const PantallaPruebaHealthKit({super.key});

  @override
  State<PantallaPruebaHealthKit> createState() =>
      _PantallaPruebaHealthKitState();
}

class _PantallaPruebaHealthKitState extends State<PantallaPruebaHealthKit> {
  final _bridge = HealthKitBridge();
  final _scroll = ScrollController();
  final _token = TextEditingController();
  final _usuarioId = TextEditingController();
  final List<String> _log = [];

  // Resultado mas reciente de cada boton, por separado. Un log unico se
  // presta a leer la linea del otro boton.
  final Map<String, String> _res = {};
  final Map<String, bool> _ok = {};

  bool _ocupado = false;

  String get _hora {
    final t = DateTime.now();
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }

  void _anotar(String tag, String linea) {
    if (!mounted) return;
    setState(() => _log.add('[$_hora] $tag $linea'));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _correr(String tag, Future<void> Function(String) accion) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    _anotar(tag, 'llamando...');
    try {
      await accion(tag);
    } on MissingPluginException catch (e) {
      // La senal de que el canal NO quedo registrado del lado nativo: nombre
      // distinto, o el registro en AppDelegate no llego a correr.
      _fijar(tag, 'CANAL NO REGISTRADO (MissingPluginException)', false);
      _anotar(tag, 'MissingPluginException ${e.message}');
    } on PlatformException catch (e) {
      // Swift respondio con FlutterError(...).
      _fijar(tag, 'FlutterError code=${e.code}', false);
      _anotar(tag, 'PlatformException ${e.code} ${e.message}');
    } catch (e) {
      _fijar(tag, 'EXCEPCION ${e.runtimeType}', false);
      _anotar(tag, '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _fijar(String tag, String texto, bool ok) {
    if (!mounted) return;
    setState(() {
      _res[tag] = texto;
      _ok[tag] = ok;
    });
  }

  Future<void> _actualizarSesion(
    String? token, {
    String? usuarioId,
  }) => _correr('SESION', (tag) async {
    // Solo el largo: el token es una contrasena. El usuario_id no es
    // secreto.
    _anotar(
      tag,
      '${token == null ? 'token=null' : 'token (${token.length} caracteres)'}'
      '  usuario_id=${usuarioId ?? '(no se manda)'}',
    );
    // El wrapper nunca lanza: un canal sin registrar llega como
    // `noDisponible`, no como MissingPluginException.
    final estado = await _bridge.actualizarSesion(token, usuarioId: usuarioId);
    final texto = 'estado=${estado.name}';
    _fijar(tag, texto, estado == EstadoSesionNativa.ok);
    _anotar(tag, texto);
  });

  Future<void> _pedirPermisos() => _correr('PERMISOS', (tag) async {
    final r = await _bridge.solicitarPermisos();
    final texto =
        'estado=${r.estado.name}'
        '\npasos=${r.tipos.pasos}  ritmo=${r.tipos.ritmoCardiaco}'
        '  entren=${r.tipos.entrenamientos}'
        '${r.detalle != null ? '\ndetalle=${r.detalle}' : ''}';
    _fijar(tag, texto, r.estado == EstadoPermisos.concedido);
    _anotar(tag, texto.replaceAll('\n', '  '));
    if (r.estado == EstadoPermisos.concedido) {
      _anotar(
        tag,
        'ponerse al dia disparado (la primera vez, 7 dias), mira el backend',
      );
    }
  });

  Future<void> _sincronizar() => _correr('SYNC', (tag) async {
    final r = await _bridge.sincronizar();
    final texto =
        'estado=${r.estado.name}'
        '${r.sincronizadoEn != null ? '\nsincronizado_en=${r.sincronizadoEn}' : ''}'
        '${r.detalle != null ? '\ndetalle=${r.detalle}' : ''}';
    _fijar(tag, texto, r.estado == EstadoSync.ok);
    _anotar(tag, texto.replaceAll('\n', '  '));
  });

  @override
  void dispose() {
    _token.dispose();
    _usuarioId.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _tarjeta(String titulo, String? resultado, bool ok) {
    final Color borde;
    if (resultado == null) {
      borde = Colors.white24;
    } else if (ok) {
      borde = Colors.greenAccent;
    } else {
      borde = Colors.orangeAccent;
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: borde, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: borde,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            resultado ?? 'sin correr todavia',
            style: TextStyle(
              color: resultado == null ? Colors.white38 : Colors.white,
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El teclado (para pegar el token) tapa el log de abajo en vez de
      // achicar la columna: en un iPhone chico no cabian los botones.
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF101418),
      appBar: AppBar(
        title: const Text('TEMP - Prueba A10'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cada boton tiene su propia tarjeta: no hay forma de confundir
              // el resultado de uno con el del otro.
              _tarjeta('0 - SESION', _res['SESION'], _ok['SESION'] ?? false),
              TextField(
                controller: _token,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Token del backend',
                  hintStyle: TextStyle(color: Colors.white38),
                  isDense: true,
                ),
              ),
              TextField(
                controller: _usuarioId,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'usuario_id (opcional)',
                  hintStyle: TextStyle(color: Colors.white38),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    // Vacio no se puede mandar: Swift lo tomaria como cerrar
                    // sesion y diria ok, y parece que se entrego un token.
                    // Para cerrar sesion esta el otro boton.
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _token,
                      builder: (_, valor, _) => FilledButton(
                        onPressed: _ocupado || valor.text.trim().isEmpty
                            ? null
                            : () => _actualizarSesion(
                                _token.text,
                                usuarioId: _usuarioId.text.trim().isEmpty
                                    ? null
                                    : _usuarioId.text.trim(),
                              ),
                        child: const Text('Entregar token'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _ocupado
                          ? null
                          : () => _actualizarSesion(null),
                      child: const Text('Cerrar sesion'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _tarjeta(
                '1 - PERMISOS',
                _res['PERMISOS'],
                _ok['PERMISOS'] ?? false,
              ),
              FilledButton(
                onPressed: _ocupado ? null : _pedirPermisos,
                child: const Text('Solicitar permisos'),
              ),
              const SizedBox(height: 18),
              _tarjeta('2 - SYNC', _res['SYNC'], _ok['SYNC'] ?? false),
              FilledButton(
                onPressed: _ocupado ? null : _sincronizar,
                child: const Text('Sincronizar'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'Log (mas viejo arriba)',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _log.isEmpty ? null : () => setState(_log.clear),
                    child: const Text('Limpiar'),
                  ),
                ],
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: ListView.builder(
                    controller: _scroll,
                    itemCount: _log.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: SelectableText(
                        _log[i],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
