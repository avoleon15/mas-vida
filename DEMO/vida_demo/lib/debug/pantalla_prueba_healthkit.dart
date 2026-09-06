// Banco de pruebas manual del MethodChannel de HealthKit (A10).
//
// NO ES PARTE DEL PRODUCTO y ninguna ruta apunta aca: el arbol de widgets no
// la alcanza, asi que el tree-shaking la saca del build. Queda en el repo
// para poder repetir la verificacion end-to-end cada vez que se toque el
// canal, sin volver a escribirla.
//
// Como usarla (hace falta un iPhone fisico, HealthKit no existe en el
// simulador, y el mock_luis_server.py corriendo en la IP de baseURLTexto):
//
//   1. En lib/main.dart:
//        import 'debug/pantalla_prueba_healthkit.dart';
//        initialRoute: '/debug-healthkit',
//        routes: { '/debug-healthkit': (c) => const PantallaPruebaHealthKit(), ... }
//   2. flutter run  (en debug, NO release: el assertionFailure del registro
//      del canal en AppDelegate solo truena en debug)
//   3. Boton 1 -> espera estado=concedido, y hasta 7 POST de backfill al mock
//      Boton 2 -> espera estado=ok
//      Boton 2 con el mock apagado -> espera estado=encolado
//      App a background y de vuelta -> el dia encolado llega solo (SceneDelegate)
//   4. git checkout lib/main.dart para dejarlo como estaba
//
// Verificado asi el 6 de septiembre de 2026: los cuatro casos pasaron.

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
  final List<String> _log = [];

  // Resultado mas reciente de cada boton, por separado. Un log unico se
  // presta a leer la linea del otro boton.
  String? _resPermisos;
  String? _resSync;
  bool _okPermisos = false;
  bool _okSync = false;

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
      if (tag == 'PERMISOS') {
        _resPermisos = texto;
        _okPermisos = ok;
      } else {
        _resSync = texto;
        _okSync = ok;
      }
    });
  }

  Future<void> _pedirPermisos() => _correr('PERMISOS', (tag) async {
        final r = await _bridge.solicitarPermisos();
        final texto = 'estado=${r.estado.name}  concedido=${r.concedido}'
            '${r.detalle != null ? '\ndetalle=${r.detalle}' : ''}';
        _fijar(tag, texto, r.estado == EstadoPermisos.concedido);
        _anotar(tag, texto.replaceAll('\n', '  '));
        if (r.estado == EstadoPermisos.concedido) {
          _anotar(tag, 'backfill de 7 dias disparado, mira el mock server');
        }
      });

  Future<void> _sincronizar() => _correr('SYNC', (tag) async {
        final r = await _bridge.sincronizar();
        final texto = 'estado=${r.estado.name}  ok=${r.ok}'
            '${r.sincronizadoEn != null ? '\nsincronizado_en=${r.sincronizadoEn}' : ''}'
            '${r.detalle != null ? '\ndetalle=${r.detalle}' : ''}';
        _fijar(tag, texto, r.estado == EstadoSync.ok);
        _anotar(tag, texto.replaceAll('\n', '  '));
      });

  @override
  void dispose() {
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
              _tarjeta('1 - PERMISOS', _resPermisos, _okPermisos),
              FilledButton(
                onPressed: _ocupado ? null : _pedirPermisos,
                child: const Text('Solicitar permisos'),
              ),
              const SizedBox(height: 18),
              _tarjeta('2 - SYNC', _resSync, _okSync),
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
