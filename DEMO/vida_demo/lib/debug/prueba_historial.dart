// Banco de pruebas de la conexión con el backend: login + historial.
//
// NO ES PARTE DEL PRODUCTO. Es un punto de entrada aparte, como
// demo_anillo.dart, así que no toca lib/main.dart ni ninguna pantalla.
//
// Cómo usarla:
//   1. En mas-vida_backend, con el entorno activado:
//        python manage.py migrate
//        python manage.py sembrar_prueba     (crea el usuario "prueba")
//        python manage.py runserver
//   2. En DEMO/vida_demo:
//        flutter run -d chrome -t lib/debug/prueba_historial.dart
//   3. Tocar "Traer historial". Tienen que aparecer 10 días de puntos.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../datos/cliente_api.dart';
import '../theme.dart';

void main() => runApp(const PruebaHistorialApp());

class PruebaHistorialApp extends StatelessWidget {
  const PruebaHistorialApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: const TemaVida(child: PantallaPruebaHistorial()),
  );
}

class PantallaPruebaHistorial extends StatefulWidget {
  const PantallaPruebaHistorial({super.key});

  @override
  State<PantallaPruebaHistorial> createState() =>
      _PantallaPruebaHistorialState();
}

class _PantallaPruebaHistorialState extends State<PantallaPruebaHistorial> {
  final _url = TextEditingController(text: 'http://127.0.0.1:8000');
  final _usuario = TextEditingController(text: 'prueba');
  final _contrasena = TextEditingController(text: 'masvida123');

  bool _cargando = false;
  String? _error;
  List<PuntosDelDia>? _dias;

  @override
  void dispose() {
    _url.dispose();
    _usuario.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _traer() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final api = ClienteApi(baseUrl: _url.text.trim());
    try {
      await api.iniciarSesion(_usuario.text.trim(), _contrasena.text);
      final dias = await api.historialDePuntos();
      setState(() => _dias = dias);
    } on ErrorApi catch (e) {
      setState(() => _error = '${e.codigo}: ${e.mensaje}');
    } catch (e) {
      // Casi siempre es que el servidor está apagado o la URL está mal.
      setState(() => _error = 'No se pudo conectar con ${_url.text}.\n$e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dias = _dias;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Prueba de conexión',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'POST /api/v1/login  →  GET /api/v1/historial',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            _Campo(etiqueta: 'Servidor', controlador: _url),
            _Campo(etiqueta: 'Usuario', controlador: _usuario),
            _Campo(
              etiqueta: 'Contraseña',
              controlador: _contrasena,
              oculto: true,
            ),
            const SizedBox(height: 12),
            CupertinoButton.filled(
              color: AppColors.accent,
              onPressed: _cargando ? null : _traer,
              child: _cargando
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Text('Traer historial'),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: AppColors.accentSecondary),
              ),
            if (dias != null && dias.isEmpty)
              const Text('Conectó, pero el usuario no tiene puntos todavía.'),
            if (dias != null)
              for (final d in dias) _FilaDia(dia: d),
          ],
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.etiqueta,
    required this.controlador,
    this.oculto = false,
  });

  final String etiqueta;
  final TextEditingController controlador;
  final bool oculto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: CupertinoTextField(
      controller: controlador,
      obscureText: oculto,
      prefix: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: SizedBox(
          width: 90,
          child: Text(
            etiqueta,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    ),
  );
}

class _FilaDia extends StatelessWidget {
  const _FilaDia({required this.dia});

  final PuntosDelDia dia;

  @override
  Widget build(BuildContext context) {
    final f = dia.fecha;
    final fecha = '${f.day}/${f.month}/${f.year}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.separador, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fecha,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Pasos ${dia.puntosPasos} · Intensidad ${dia.puntosIntensidad}'
                  '${dia.topeDiarioAplicado ? ' · tope aplicado (${dia.puntosBrutos} brutos)' : ''}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${dia.puntosDia} pts',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
