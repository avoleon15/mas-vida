import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'modelos.dart';
import 'vida_repository.dart';

/// Implementación que lee los JSON de prueba de `assets/mock/`.
///
/// Es la única clase del proyecto que toca esos archivos. Las pantallas
/// no saben que existen.
class MockVidaRepository implements VidaRepository {
  MockVidaRepository();

  // Los assets se leen una sola vez y se cachean: las pantallas piden lo
  // mismo varias veces y no tiene sentido reparsear el JSON en cada
  // build.
  final Map<String, Map<String, dynamic>> _cache = {};

  Future<Map<String, dynamic>> _leer(String archivo) async {
    final yaLeido = _cache[archivo];
    if (yaLeido != null) return yaLeido;

    final crudo = await rootBundle.loadString('assets/mock/$archivo');
    final json = jsonDecode(crudo) as Map<String, dynamic>;
    _cache[archivo] = json;
    return json;
  }

  @override
  Future<Perfil> perfil() async => Perfil.desdeJson(await _leer('perfil.json'));

  @override
  Future<Historial> historial() async =>
      Historial.desdeJson(await _leer('dias.json'));

  @override
  Future<ResumenAnual> resumenAnual() async =>
      ResumenAnual.desdeJson(await _leer('resumen.json'));

  @override
  Future<Catalogo> catalogo() async =>
      Catalogo.desdeJson(await _leer('premios.json'));

  @override
  Future<DatosSociales> social() async =>
      DatosSociales.desdeJson(await _leer('social.json'));
}
