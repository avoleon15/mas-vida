import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_demo/datos/fuente_datos.dart';
import 'package:vida_demo/datos/modelos.dart';
import 'package:vida_demo/screens/camino_semanas_screen.dart';
import 'package:vida_demo/widgets/carrusel_patrocinadores.dart';
import 'package:vida_demo/widgets/cintillo_patrocinador.dart';
import 'package:vida_demo/widgets/patrocinio.dart';

import 'ayudas.dart';

// ============================================================
// EL CAMINO DE LAS SEMANAS Y SUS MARCAS ALIADAS.
//
// Lo que hay que proteger son tres cosas que se rompen sin que nadie
// mire:
//
//   · LA FORMA DEL CAMINO. Va y vuelve por FILAS, como un tablero de
//     mesa: tres nodos por fila, la siguiente al revés, y el giro
//     siempre vertical. Así no mide 1.520 px de alto y, sobre todo, no
//     quedan huecos en la grilla ni tramos en diagonal.
//   · QUE EL NODO NO SE MUEVA POR TENER MARCA. La curva se dibuja aparte,
//     contra los centros ya calculados: un nodo que crece o se corre se
//     despega de su propia curva.
//   · QUE NADA ANUNCIE UNA AUSENCIA. Sin patrocinador no hay tarjeta ni
//     botón: la pantalla se ve como si la sección nunca hubiera existido.
// ============================================================

ObjetivosSemana get objetivos => Datos.i.resumen.objetivosSemana;

Future<void> montarCamino(WidgetTester t, {ObjetivosSemana? conEstos}) async {
  // Tamaño de iPhone y no el 800x600 apaisado que trae flutter_test por
  // defecto: en una ventana ancha la tarjeta del patrocinador —que es
  // apaisada, 2.2:1— se come la pantalla y empuja el camino fuera de
  // cuadro, así que los toques no llegan a los nodos.
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  await montarPantalla(
    t,
    CaminoSemanasScreen(objetivos: conEstos ?? objetivos),
  );
  await t.pump();
}

/// Los mismos objetivos pero con la semana EN CURSO sin marca.
///
/// En el mock la que corre SÍ está vendida —es la que sale en el título y
/// en la tarjeta—, así que el caso contrario hay que armarlo.
ObjetivosSemana sinMarcaEnLaSemanaEnCurso() => ObjetivosSemana(
  rangoActual: objetivos.rangoActual,
  semanas: [
    for (final s in objetivos.semanas)
      if (s.estado == EstadoSemana.enCurso)
        SemanaObjetivos(
          numero: s.numero,
          cierra: s.cierra,
          estado: s.estado,
          objetivos: s.objetivos,
        )
      else
        s,
  ],
);

/// Dónde quedó el círculo de una semana en la pantalla.
Offset centroDe(WidgetTester t, int numero) =>
    t.getCenter(find.byKey(llaveCirculoSemana(numero)));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Datos.cargar();
  });

  group('El título es la semana en curso', () {
    testWidgets('dice la semana y quién la patrocina', (t) async {
      await montarCamino(t);
      final enCurso = objetivos.enCurso!;

      expect(find.text('SEMANA ${enCurso.numero}'), findsOneWidget);
      expect(
        find.text('Patrocinada por ${enCurso.patrocinio!.marca}'),
        findsOneWidget,
      );
    });

    testWidgets('sin marca no menciona el patrocinio', (t) async {
      await montarCamino(t, conEstos: sinMarcaEnLaSemanaEnCurso());

      // Ni el cintillo ni un cartel que anuncie la ausencia: un aviso de
      // "esta semana no hay patrocinador" es peor que la ausencia.
      expect(find.byType(CintilloPatrocinador), findsNothing);
      expect(find.textContaining('Patrocinada por'), findsNothing);
      expect(find.textContaining('sin patrocinador'), findsNothing);
      // Y el titular sigue ubicando al usuario.
      expect(find.text('SEMANA ${objetivos.enCurso!.numero}'), findsOneWidget);
    });

    testWidgets('la tarjeta animada es la de la semana en curso', (t) async {
      await montarCamino(t);
      final enCurso = objetivos.enCurso!;

      final cintillo = t.widget<CintilloPatrocinador>(
        find.byType(CintilloPatrocinador),
      );
      expect(cintillo.semana, enCurso.numero);
      expect(cintillo.marca, enCurso.patrocinio!.marca);
      // Las fotos salen de los datos, no se arman en la pantalla.
      expect(cintillo.fotos, enCurso.patrocinio!.fotos);
    });
  });

  group('El camino va y vuelve como un tablero', () {
    testWidgets('la fila 1 va a la derecha y la 2 vuelve', (t) async {
      await montarCamino(t);

      final x = {
        for (final s in objetivos.semanas) s.numero: centroDe(t, s.numero).dx,
      };
      final y = {
        for (final s in objetivos.semanas) s.numero: centroDe(t, s.numero).dy,
      };

      // Fila 1: las semanas 1, 2 y 3 a la misma altura, hacia la derecha.
      for (final n in [2, 3]) {
        expect(y[n], closeTo(y[1]!, 0.01), reason: 'la semana $n cambió de fila');
        expect(x[n], greaterThan(x[n - 1]!), reason: 'la semana $n no fue a la derecha');
      }

      // Fila 2: la 4 arranca DEBAJO de la 3 —el giro es vertical— y la
      // fila vuelve hacia la izquierda.
      expect(x[4], closeTo(x[3]!, 0.01), reason: 'el giro de fila no es vertical');
      expect(y[4], greaterThan(y[3]!));
      for (final n in [5, 6]) {
        expect(y[n], closeTo(y[4]!, 0.01), reason: 'la semana $n cambió de fila');
        expect(x[n], lessThan(x[n - 1]!), reason: 'la semana $n no volvió');
      }

      // Fila 3: se gira otra vez hacia abajo y se vuelve a la derecha.
      expect(x[7], closeTo(x[6]!, 0.01));
      expect(y[7], greaterThan(y[6]!));
      for (final n in [8, 9]) {
        expect(y[n], closeTo(y[7]!, 0.01));
        expect(x[n], greaterThan(x[n - 1]!));
      }
    });

    testWidgets('ningún tramo es diagonal', (t) async {
      await montarCamino(t);

      // Es lo que hace que la pantalla se vea ordenada: dos semanas
      // seguidas comparten SIEMPRE fila o columna, así que cada tramo del
      // trazo es horizontal o vertical y el giro cae tapado por el
      // círculo del nodo.
      final centros = [
        for (final s in objetivos.semanas) centroDe(t, s.numero),
      ];

      for (var i = 0; i < centros.length - 1; i++) {
        final mismaFila = (centros[i].dy - centros[i + 1].dy).abs() < 0.01;
        final mismaColumna = (centros[i].dx - centros[i + 1].dx).abs() < 0.01;
        expect(
          mismaFila || mismaColumna,
          isTrue,
          reason: 'el tramo ${i + 1} → ${i + 2} salió en diagonal',
        );
      }
    });

    testWidgets('las filas están llenas y parejas', (t) async {
      await montarCamino(t);

      final porFila = <double, int>{};
      for (final s in objetivos.semanas) {
        porFila.update(centroDe(t, s.numero).dy, (n) => n + 1, ifAbsent: () => 1);
      }
      final filas = porFila.keys.toList()..sort();

      // Antes eran diez filas, una por semana: 1.520 px de scroll.
      expect(filas.length, lessThanOrEqualTo(4));
      // Y ninguna fila a medio llenar salvo la última: un hueco en el
      // medio de la grilla es lo que se leía desordenado.
      for (final fila in filas.take(filas.length - 1)) {
        expect(porFila[fila], 3, reason: 'la fila $fila quedó a medio llenar');
      }
    });

    testWidgets('no hay candados en ningún nodo', (t) async {
      await montarCamino(t);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.lock), findsNothing);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
    });
  });

  group('La marca en el nodo', () {
    test('el mock tiene semanas con marca y semanas sin marca', () {
      expect(objetivos.semanas.where((s) => s.tienePatrocinio), isNotEmpty);
      expect(objetivos.semanas.where((s) => !s.tienePatrocinio), isNotEmpty);
    });

    testWidgets('sale un logo por semana patrocinada, ni uno más', (t) async {
      await montarCamino(t);

      final patrocinadas = objetivos.semanas
          .where((s) => s.tienePatrocinio)
          .length;
      expect(find.byType(LogoPatrocinio), findsNWidgets(patrocinadas));
    });

    testWidgets('el círculo no cambia de tamaño por tener marca', (t) async {
      await montarCamino(t);

      final conMarca = objetivos.semanas.firstWhere(
        (s) => s.estado == EstadoSemana.futura && s.tienePatrocinio,
      );
      final sinMarca = objetivos.semanas.firstWhere(
        (s) => s.estado == EstadoSemana.futura && !s.tienePatrocinio,
      );

      expect(
        t.getSize(find.byKey(llaveCirculoSemana(conMarca.numero))),
        t.getSize(find.byKey(llaveCirculoSemana(sinMarca.numero))),
      );
    });

    testWidgets('el círculo queda centrado en su celda, tenga marca o no', (
      t,
    ) async {
      await montarCamino(t);

      // Si el logo o el anillo empujaran el círculo, se despegaría de la
      // curva, que se dibuja aparte contra los centros ya calculados.
      double sangria(int numero) =>
          centroDe(t, numero).dx -
          t.getTopLeft(find.byKey(llaveNodoSemana(numero))).dx;

      final primera = sangria(objetivos.semanas.first.numero);
      for (final s in objetivos.semanas) {
        expect(
          sangria(s.numero),
          closeTo(primera, 0.01),
          reason: 'el círculo de la semana ${s.numero} está corrido',
        );
      }
    });
  });

  group('El botón de los próximos patrocinadores', () {
    testWidgets('abre quiénes vienen, con su número de semana', (t) async {
      await montarCamino(t);

      expect(find.byKey(llaveBotonProximosPatrocinadores), findsOneWidget);
      await t.tap(find.byKey(llaveBotonProximosPatrocinadores));
      await t.pumpAndSettle();

      final porVenir = objetivos.semanas.where(
        (s) => s.tienePatrocinio && s.estado == EstadoSemana.futura,
      );
      expect(porVenir, isNotEmpty);
      expect(find.byType(CarruselLoQueViene), findsOneWidget);

      for (final s in porVenir) {
        expect(
          find.text('SEMANA ${s.numero}'),
          findsOneWidget,
          reason: 'falta la semana ${s.numero} en la hoja',
        );
      }
    });

    testWidgets('la semana EN CURSO no se repite adentro', (t) async {
      // Ya tiene su tarjeta arriba; decirla dos veces es ruido.
      await montarCamino(t);
      await t.tap(find.byKey(llaveBotonProximosPatrocinadores));
      await t.pumpAndSettle();

      // Se busca DENTRO del carrusel: el título de la pantalla también
      // dice "SEMANA 3" y se queda vivo detrás de la hoja.
      expect(
        find.descendant(
          of: find.byType(CarruselLoQueViene),
          matching: find.text('SEMANA ${objetivos.enCurso!.numero}'),
        ),
        findsNothing,
      );
    });

    testWidgets('sin semanas vendidas por delante no hay botón', (t) async {
      final sinFuturas = ObjetivosSemana(
        rangoActual: objetivos.rangoActual,
        semanas: [
          for (final s in objetivos.semanas)
            if (s.estado == EstadoSemana.futura)
              SemanaObjetivos(
                numero: s.numero,
                cierra: s.cierra,
                estado: s.estado,
                objetivos: s.objetivos,
              )
            else
              s,
        ],
      );

      await montarCamino(t, conEstos: sinFuturas);

      // Un botón que abre una hoja vacía es peor que no tener botón.
      expect(find.byKey(llaveBotonProximosPatrocinadores), findsNothing);
      expect(find.byType(CarruselLoQueViene), findsNothing);
    });
  });

  group('El premio de una semana patrocinada', () {
    testWidgets('el cupón NO reemplaza a las monedas de la semana', (t) async {
      await montarCamino(t);

      // Si alguien cambia el premio de rango por el cupón, esto se cae.
      final paso = objetivos.recorrido.firstWhere(
        (p) => p.semana.tienePatrocinio && p.monedas > 0,
      );
      expect(find.textContaining('+${paso.monedas}'), findsWidgets);
    });

    testWidgets('el cupón se ve al abrir esa semana', (t) async {
      await montarCamino(t);
      final s = objetivos.semanas.firstWhere((s) => s.tienePatrocinio);

      await t.tap(find.byKey(llaveNodoSemana(s.numero)));
      // Dos pumps y NO pumpAndSettle: la hoja trae la moneda de Lottie,
      // que se repite para siempre y nunca se asienta.
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      expect(find.textContaining(s.patrocinio!.cupon), findsWidgets);
    });
  });
}
