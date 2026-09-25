import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/theme.dart';
import 'package:vida_demo/widgets/placeholder_imagen.dart';

/// Cuida las dos reglas del catálogo de Premios que se rompen solas
/// cuando alguien deja un logo nuevo en `assets/img/premios/`:
///
/// 1. Ningún comercio aparece dos veces.
/// 2. Todo logo que está en assets tiene su premio en la pantalla — un
///    archivo suelto que nadie ve es trabajo tirado, y no se nota
///    mirando la app.
///
/// Se lee la carpeta de verdad con `dart:io` en vez de una lista escrita
/// a mano: una lista a mano hay que acordarse de actualizarla, que es
/// justo lo que este test existe para no tener que hacer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Datos.cargar();
  });

  /// Nombre comparable: sin tildes, mayúsculas ni espacios. Así "12 Onzas"
  /// y "12onzas" cuentan como el mismo local.
  String normalizar(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  group('Catálogo de premios', () {
    test('ningún comercio se repite', () {
      final premios = Datos.i.catalogo.premios;

      for (final campo in {
        'id': premios.map((p) => p.id),
        'nombre': premios.map((p) => normalizar(p.nombre)),
        'foto': premios.map((p) => p.foto ?? ''),
      }.entries) {
        final vistos = <String>{};
        final repetidos = <String>{};
        for (final valor in campo.value) {
          if (!vistos.add(valor)) repetidos.add(valor);
        }
        expect(
          repetidos,
          isEmpty,
          reason: 'Hay premios con el mismo ${campo.key}: $repetidos',
        );
      }
    });

    test('todo logo de assets tiene su premio en la pantalla', () {
      final raiz = Directory('assets/img/premios');
      final enDisco = raiz
          .listSync()
          .whereType<Directory>()
          .expand((d) => d.listSync().whereType<File>())
          // Los LEEME.md están para que git no se coma la carpeta vacía.
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((ruta) => !ruta.endsWith('LEEME.md'))
          .toSet();

      final enCatalogo = Datos.i.catalogo.premios
          .map((p) => p.foto)
          .whereType<String>()
          .toSet();

      expect(
        enDisco.difference(enCatalogo),
        isEmpty,
        reason: 'Estos logos están en assets pero no salen en Premios',
      );
      expect(
        enCatalogo.difference(enDisco),
        isEmpty,
        reason: 'Estos premios apuntan a un archivo que no existe',
      );
    });

    test('cada premio vive en la carpeta de su filtro', () {
      // La carpeta ES la categoría: si no coinciden, el premio sale en un
      // filtro y su logo está guardado en otro, y el siguiente que ordene
      // assets lo va a mover mal.
      final carpetaDe = {
        'Restaurantes': 'restaurantes',
        'Ropa': 'ropa',
        'Cafecitos': 'cafecitos',
        'Conveniencia': 'conveniencia',
        'Deportes/ejercicio': 'deportes-ejercicio',
        'Farmacias': 'farmacias',
      };

      for (final p in Datos.i.catalogo.premios) {
        final foto = p.foto;
        if (foto == null) continue;
        expect(
          foto,
          contains('/${carpetaDe[p.categoria]}/'),
          reason: '${p.nombre} es de ${p.categoria} pero su logo está en $foto',
        );
      }
    });

    testWidgets('los logos en SVG se dibujan, no caen al placeholder', (
      tester,
    ) async {
      // `Image.asset` no sabe leer SVG: sin flutter_svg estas tarjetas se
      // veían rayadas y no había forma de notarlo salvo abriendo la app.
      final svgs = Datos.i.catalogo.premios
          .where((p) => p.foto?.toLowerCase().endsWith('.svg') ?? false)
          .toList();
      expect(svgs, isNotEmpty, reason: 'Nadie está ejercitando el caso SVG');

      for (final p in svgs) {
        await tester.pumpWidget(
          MaterialApp(
            home: TemaVida(
              child: SizedBox(
                width: 200,
                height: 140,
                child: FotoComercio(ruta: p.foto, texto: 'LOGO'),
              ),
            ),
          ),
        );
        // El SVG se parsea fuera del frame: hay que dejarlo terminar.
        await tester.pumpAndSettle();

        expect(
          find.byType(SvgPicture),
          findsOneWidget,
          reason: 'El logo de ${p.nombre} no se está dibujando como SVG',
        );
        expect(
          find.byType(PlaceholderImagen),
          findsNothing,
          reason: 'El logo de ${p.nombre} terminó en el placeholder rayado',
        );
      }
    });

    test('los filtros cubren todos los premios y ninguno queda vacío', () {
      final categorias = Datos.i.catalogo.categorias.toSet()..remove('Todos');
      final usadas = Datos.i.catalogo.premios.map((p) => p.categoria).toSet();

      expect(
        usadas.difference(categorias),
        isEmpty,
        reason: 'Hay premios en una categoría que no tiene chip de filtro',
      );
      expect(
        categorias.difference(usadas),
        isEmpty,
        reason: 'Hay un filtro que no muestra ningún premio',
      );
    });
  });
}
