# +Vida — Contexto del Proyecto

Este archivo se carga automáticamente en cada sesión de Claude Code dentro de
este proyecto. Contiene las reglas de negocio, sistema de diseño, y estado
del proyecto que SIEMPRE deben respetarse al escribir o modificar código.

Si algo que se pide en el chat contradice una regla dura de este documento,
señalalo antes de proceder — no asumas que se quiere romper la regla sin
confirmarlo primero.

**Actualizado 22 de septiembre de 2026.** Esta versión parte de la de Daniel
(rama `D7-correcion-2-ui`, 21 sep) y corrige las reglas de negocio que chocaban
con los documentos vivos del proyecto. Todo lo de UI y diseño de Daniel quedó
igual. Fuente de verdad de reglas de negocio (en el proyecto de Claude del
equipo, no en este repo): `contrato-tecnico-vivo.md`, `reglas-puntaje-vivo.md`,
`arquitectura-cuentas-vivo.md`, `modelo-de-negocio-vivo.md`,
`esquema-base-datos-vivo.md`. Si este archivo y esos documentos no coinciden en
una regla de negocio, mandan esos documentos.

## Qué es +Vida

App iOS (construida en Flutter) que lee pasos/actividad de Apple Health, los
convierte en puntos, y esos puntos dan cashback sobre la póliza de gastos
médicos del usuario + premios canjeables con comercios aliados. Referente:
Discovery Vitality, adaptado a Guatemala. Es a la vez entrega de tesis (UFM)
y producto comercial real.

**Modelo de negocio:** B2B2C — el usuario final (asegurado) usa el producto,
pero el cliente que paga es la aseguradora. **Gratis para jugar, pago para los
beneficios:** cualquiera usa la app sin póliza; todo lo que implica dinero o
premio requiere póliza vinculada y verificada.

**3 vías de ingreso** (montos = cifras de trabajo, nada cerrado):
1. Cuota por asegurado cobrada a la aseguradora (mensual, incluye el reporte).
2. Cuota mensual a comercios aliados por publicar premios/cupones en la
   tienda, más extras opcionales: patrocinar La Liga, patrocinar una semana, y
   posicionamiento pagado en la búsqueda de premios.
3. Plan Empresarial — post-piloto, no se construye ahora.

**No existe ninguna membresía freemium ni multiplicador de pasos o puntos
pagado.** Si aparece en código viejo, se borra.

## Idioma — regla dura

Toda la app en **español latinoamericano**, tono natural y humano (nunca
traducción literal ni robótica). Es para el mercado guatemalteco.

**Siempre de TÚ, nunca de vos** (decisión de Daniel, 24 de septiembre de
2026): "tienes", "puedes", "toca", "elige", "cumple los dos", "a ti".
Nunca "tenés", "podés", "tocá", "elegí", "cumplí", "vos". Aplica a todo
texto que vea el usuario —pantallas, etiquetas de VoiceOver, textos de
los mocks—; los comentarios del código no cuentan. "Estás" y "acá" son
correctos en tuteo. Excepción:
los niveles de cashback se nombran por número ("Nivel 3"), nunca con los
nombres en inglés Bronze/Silver/Gold/Platinum, que el contrato v1 prohíbe
expresamente por ser de Vitality.

## Las 2 monedas — regla dura, nunca mezclar

1. **PUNTOS** — nunca se gastan. Determinan el nivel anual y el % de cashback.
   Nunca aparecen en Premios.
2. **MONEDAS** (antes "medallas" — si ves ese término en código viejo,
   migralo) — se gastan en Premios, caducan a los **90 días**. Nunca
   aparecen en Mi Plan.

   Los 90 días los confirmó Daniel en la revisión de UI del 9 de
   septiembre de 2026 y reemplazan a los 6 meses que decía la versión
   anterior de este documento. Si encontrás "6 meses" en código,
   comentarios o mocks, es del plazo viejo y hay que migrarlo.

   - Se ganan por cumplir el objetivo semanal y por quedar top 3 en La Liga.
   - **Tope: 100 monedas acumuladas.** Si una ganancia pasa de 100, el
     excedente se pierde.
   - **Aviso al llegar a 80:** modal con un solo botón "OK", tono lúdico. Se
     dispara con `saldo_resultante >= 80`, no `== 80`.
   - Un cupón ya canjeado caduca aparte, a los **60 días** de canjeado.
   - Sin póliza verificada se ganan igual, pero **no se pueden canjear**:
     catálogo visible, botón de compra bloqueado con candado.

## Niveles anuales de cashback — regla dura, numéricos

Fuente de verdad: `reglas-puntaje-vivo.md`, sección 6.

**El naming Bronze/Silver/Gold/Platinum está PROHIBIDO en el proyecto.** Es de
Vitality, no de +Vida. El nivel es un entero de 0 a 4 y en la UI se dice
"Nivel 3", nunca un nombre en inglés.

| Nivel | Puntos anuales | % Cashback |
|---|---|---|
| 0 | 0 – 2,499 | 0% |
| 1 | 2,500 – 4,999 | 5% |
| 2 | 5,000 – 9,999 | 7,5% |
| 3 | 10,000 – 14,999 | 10% |
| 4 | 15,000+ | 20% |

**El piso del nivel 4 es 15.000, no 12.000** (confirmado por Alvaro el 19 de
septiembre de 2026). Esto reemplaza a la versión anterior de este documento,
que lo había bajado a 12.000 el 17 de septiembre. La tabla `niveles` de
`lib/reglas_puntos.dart` tiene que quedar así:

```dart
Nivel(3, 10000, 14999, 10),
Nivel(4, 15000, 15000, 20),
```

(En el nivel 4, el tercer número es el tope de la tabla para dibujar la
escalera, no un límite de lo que el usuario puede acumular.)

**Techo anual: 12.000 puntos**, sumando solo actividad (pasos + intensidad).
**El chequeo médico está fuera de v1**: no suma puntos en el piloto (se simula
con acreditación manual en el panel admin, si hace falta para una demo).

Consecuencia: **el nivel 4 queda fuera de alcance en el piloto.** Con
actividad sola se llega como máximo a 12.000, o sea nivel 3 (10%). Es una
consecuencia aceptada y documentada, no un bug: no "arreglarla" subiendo el
tope ni bajando el piso. Cashback máximo real del piloto: **10%**.

**Regla regulatoria dura:** el cashback SIEMPRE se devuelve como dinero
DESPUÉS del pago de la prima. NUNCA se descuenta directamente (regulación de
la Superintendencia de Bancos de Guatemala). Siempre "cashback", nunca
"descuento en tu prima" ni "ahorro en tu póliza".

## Cálculo de puntos diarios

Fuente de verdad: `reglas-puntaje-vivo.md`, secciones 2 y 3. Estas reglas **reemplazan** a las de la
versión anterior de este documento — si encontrás en el código escalones de
7,500 / 10,000 / 15,000 pasos, un techo diario de 500 pts, o FCmáx = 220 −
edad, son del modelo viejo y hay que migrarlos.

**Por pasos** — función escalonada con piso en 7,000 (contrato v1):
- Menos de 7,000 pasos = 0 pts
- 7,000 – 9,999 = 25 pts
- 10,000 – 14,999 = 50 pts
- 15,000+ = 100 pts

Los pasos por encima de 15,000 NO dan puntos adicionales. Cuentan tanto los del
teléfono como los de un reloj vinculado, pero la deduplicación y la precedencia
entre fuentes se resuelven ANTES de aplicar la tabla — nunca se suman crudo.

Los umbrales de pasos son **iguales para todas las edades**. Ya no existe una
tabla de pasos separada para adultos mayores: el ajuste por edad vive ahora en
la matriz de intensidad, no acá.

**Por intensidad (ritmo cardíaco)** — FCmáx = **219 − edad**, calculada
SIEMPRE en el servidor. El teléfono NUNCA manda la FCmáx ni la edad. Sesión
continua:

| Duración continua | Intensidad | Puntos |
|---|---|---|
| 30 min | 60% FCmáx | 50 |
| 30 min | 70% FCmáx | 100 |
| 60 min | 60% FCmáx | 100 |
| 90 min | 60% FCmáx | 150 |

Se compara por **rango**, no por valor exacto. Varias sesiones el mismo día no
se suman: se acredita el escalón **más alto**. (Esto reemplaza a la versión
anterior de este documento, que solo conocía una celda: 42 min al 74% = 100.)

**Bono 60+:** **+25 pts fijos** sobre los puntos de pasos y **+25 pts fijos**
sobre los de intensidad — independientes, acumulables el mismo día.
**Nunca multiplicador** (el ×1.25 de la versión anterior está deprecado).

**Techo diario absoluto: 200 pts**, igual para todas las edades, sumando ambas
vías y los bonos. Un día que genere más puntos brutos acredita 200 y marca el registro con
`tope_diario_aplicado`. Llegar a exactamente 200 NO cuenta como recorte.
Ningún dato de ejemplo debe superar 200 pts en un solo día.

**Techo anual: 12.000 pts**, con su propia bandera `tope_anual_aplicado`.

Los puntos acreditados se pueden revertir hasta **2 semanas** después; el
saldo nunca queda negativo tras una reversión.

Notas sobre la edad:
- La fecha de nacimiento se pide **en el registro** (autoreportada) y se usa
  de inmediato para la FCmáx, aunque todavía no haya póliza. Cuando el usuario
  vincula su póliza, la aseguradora la confirma. Si **coincide**, todo lo
  ganado en la cuenta base (puntos y monedas) se acredita. Si **no
  coincide**, no hay retroactividad: arranca en cero desde la vinculación.
- El bonus 60+ y la FCmáx REQUIEREN validación médica/actuarial antes de salir
  a piloto. No son definitivos.
- En la UI, cualquier mención al ajuste por edad debe tener tono cálido, nunca
  clínico ni condescendiente.

**Objetivos semanales** (antes "retos semanales") — decisión de Daniel, 24
de septiembre de 2026. Esto reemplaza a `reglas-puntaje-vivo.md`, sección 4,
hasta que ese documento se actualice.

- **Dos objetivos por semana:** pasos de la semana y minutos de
  entrenamiento. Ni uno ni tres.
- **Hay que cumplir LOS DOS** para que la semana pague. Cumplir uno solo no
  paga nada ni se arrastra a la semana siguiente.
- **Cuántas MONEDAS paga cada semana lo manda el servidor**, semana por
  semana (campo `monedas` de la semana). La app no tiene ninguna regla para
  calcularlo. Se acuñan bajo el tope de 100 acumuladas.
- **El programa avanza por calendario, igual para todos:** al cerrar la
  semana 1 todos pasan a los objetivos de la semana 2, la hayan cumplido o
  no, y así sucesivamente. No hay progresión propia de cada usuario.
- **No existe el rango.** No hay escalera, insignia, ni nada que suba o baje
  según cumplas. Si aparece `rango`, `reglas_rango.dart` o
  `insignia_rango.dart`, es del modelo viejo.
- Nunca usar la palabra "nivel" para esto: el nivel es el anual de cashback.

(Esto reemplaza a la versión anterior de este documento: una sola meta de
pasos con objetivo 1, 2, 3… que se congelaba si no se cumplía.)

La semana cierra el **domingo 23:59** y el lunes 00:00 ya corre la siguiente,
en hora de Guatemala. Quién releva la semana es el **servidor**: el teléfono
nunca lo calcula, solo vuelve a pedir los datos al pasar el cierre
(`programarRelevoDeSemana`). Si lo decidiera el teléfono, cambiar la zona
horaria en Ajustes abriría una semana nueva antes de tiempo. El objetivo nuevo
se fija a las 00:00 del lunes; no hay estado de "evaluando". El servidor
acepta datos atrasados de la semana cerrada hasta el **mediodía del lunes**,
pero eso ya no cambia la semana cerrada — solo el historial y el acumulado anual. Por lo mismo,
**ningún texto del objetivo puede sonar a plazo propio** ("Faltan 42 min" se
leía como cuenta regresiva): se dice el avance sobre la meta ("48.000 de 70.000 pasos")
y el plazo una sola vez, abajo.

[PENDIENTE: la tabla de metas de cada semana (pasos y minutos) y lo que
paga cada una. La define Luis (L11) — **no inventarla**.]

## Racha

**Las recompensas por constancia ya no existen** (decidido por Alvaro el 22
de septiembre de 2026): la racha **no da monedas ni puntos** ni tiene hitos.
Lo que sí queda es la **racha visible en Home, con un fueguito** 🔥 — solo
como motivación.

[PENDIENTE: qué cuenta exactamente la racha. No hay rachas diarias.]

## Anti-fraude

- Cada muestra guarda la fuente (`fuente_bundle`, `fuente_nombre`,
  `fuente_version`) y el dispositivo (`dispositivo_nombre`,
  `dispositivo_modelo`, `dispositivo_fabricante`, nullable).
- **No hay lista blanca de marcas.** Todas las apps de terceros (Garmin,
  Whoop, Zepp, Fitbit…) tienen el mismo nivel de confianza. Una fuente
  desconocida nunca se excluye: se trata como teléfono.
- **Precedencia:** si hay un reloj con datos ese día, **gana el reloj** (pasos
  e intensidad) y el teléfono se descarta. Sin reloj, gana el teléfono. Dos
  relojes: el de más pasos. **Nunca se suman fuentes.**
- "¿Es reloj?" se decide con `tipo_dispositivo`, derivado en el servidor —
  nunca con `fuente_nombre`.
- La precedencia se **re-evalúa en cada sync** de esa fecha: los relojes de
  terceros necesitan internet para escribir a Apple Health y pueden llegar
  tarde.
- **Ventana de datos rezagados: 14 días.** Más viejo → `422`
  `{"error": "fuera_de_ventana"}`. (Reemplaza a los 3 días de la versión
  anterior.) Un ciclo ya cerrado (objetivo semanal, La Liga) nunca se reabre.
- Una cuenta por persona.
- Idempotencia por `(usuario, external_id)`. Ledger de puntos
  **append-only**: nunca `UPDATE`.
- [PENDIENTE: plausibilidad fisiológica. No hay umbral numérico cerrado — en
  v1 un dato atípico se marca para revisión, no se rechaza. Los 60.000 pasos
  de la versión anterior no están confirmados.]
- Cero SDKs de terceros sobre datos de salud (ej. Firebase) — Apple lo trata
  como filtración y remueve la app. Nunca loguear el payload de salud completo.

## Sistema de diseño (lib/theme.dart)

Tema CLARO. La app debe transmitir paz, tranquilidad y ambiente sano.
(Nota: el proyecto arrancó con tema oscuro; si encontrás restos de negro
`#000000` o gris `#1A1A1A` en el código, son del tema viejo y hay que
migrarlos.)

**Paleta de marca: azul `#012096`, naranja `#F58700` y blanco.** El reparto
es por TAMAÑO de superficie:
- **blanco** → lo grande (fondos, tarjetas, superficies)
- **azul** → lo mediano (botones, barras de progreso, íconos de sección)
- **naranja** → lo chico (marcas de estado, chips, checks, detalles que
  tienen que saltar a la vista)

El naranja **nunca** rellena una superficie grande: a ese tamaño compite con
todo. Su trabajo es señalar, no vestir.

**Toda superficie se pinta con la escala de azules** (confirmado por Daniel,
4 de septiembre de 2026). Es un solo azul en cinco luminosidades, no cinco
colores: lo que cambia es qué tan claro, nunca el matiz. Cuanto más grande
la superficie, más pálido el tono.

| Token | Para qué |
|---|---|
| `azulNiebla` `#F2F4FB` | fondo de una tarjeta entera |
| `azulBruma` `#E4E9F8` | relleno de un estado activo o seleccionado |
| `azulSuave` `#B9C4E8` | bordes y separadores con color |
| `azulMedio` `#5468BC` | íconos y texto de apoyo |
| `accent` `#012096` | botones, números grandes, lo que decide |

**El naranja queda reservado a cuatro cosas, y a ninguna más:**

1. **Monedas** — el ícono, el chip de saldo y los premios del podio. Es el
   único lugar donde el naranja significa algo por sí solo.
2. **La llama de la racha** — el ícono, nunca el fondo que lo rodea.
3. **Alertas reales** — datos sin verificar, el teléfono de emergencias.
4. **El check de una etapa completada** — el ícono suelto sobre azul.

Todo lo demás que hoy esté en naranja es del modelo viejo y hay que
migrarlo. Seleccionar algo es **siempre** azul: si dos pantallas marcan la
selección con colores distintos, la app se lee como dos apps.

(Esto reemplaza a la paleta anterior de este documento — azul `#4A90D9` y
verde `#5FAE85`. Si encontrás esos dos hex o el verde de salud en el código,
son del tema viejo.)

- **background:** casi blanco con tinte azul mínimo `#F5F6FA`. Es también
  el fondo de pantalla (`fondoDePantalla`), que hasta el 21 de septiembre
  de 2026 era un beige cálido `#F3F1ED`. **Una sola temperatura en toda
  la app:** el fondo y el borde de tarjeta son las dos superficies que
  más lugar ocupan, y mezclarles la temperatura —beige cálido contra
  borde azulado— es lo que daba la sensación de que nada terminaba de
  verse fino. Si encontrás `#F3F1ED`, es del modelo viejo
- **card:** blanco puro `#FFFFFF`. **Ya no lleva borde:** las tarjetas se
  despegan del fondo con `AppSombras.tarjeta`, una sombra de UNA capa muy
  abierta y casi invisible. Un contorno dibujado en las cuatro esquinas
  hace que la pantalla se vea trazada con lápiz; una sombra difusa se lee
  como papel apoyado. `cardBorder` `#E3E6F0` sigue existiendo para
  separadores y rellenos apagados, no para contornear tarjetas
- **accent (azul de marca):** `#012096` — botones principales, links,
  elementos interactivos
- **accentSecondary (naranja de marca):** `#F58700` — estados de éxito,
  checks completados, marcadores y detalles chicos
- **textPrimary:** azul muy oscuro `#101833` (NO negro puro, se ve muy
  duro sobre fondo claro)
- **textSecondary:** gris medio `#6B7280`
- **Tipografía:** SF Pro (o la más parecida disponible)

**UNA SOLA COSA LEVANTADA POR PANTALLA** (decisión de Daniel, 21 de
septiembre de 2026). Es la regla que ordena todas las demás.

El problema que resuelve: Social llegó a tener **16 tarjetas blancas** con
el mismo radio y el mismo borde, y Progreso tres del mismo peso. Cuando
todo está dentro de una caja idéntica, nada es importante — el ojo no
encuentra dónde parar y la pantalla se lee como una lista de formularios.
Home y Premios nunca tuvieron ese problema: Home tiene un héroe (el
anillo) y cuatro tratamientos de superficie distintos, y en Premios las
fotos hacen el diseño solas.

La regla es al revés de lo que parece: **no se marca el héroe pintándolo,
se marca dejando plano todo lo demás.** En cada pantalla hay UNA pieza con
superficie y sombra; el resto se apoya directo sobre el fondo. Con una
sola cosa levantada, esa es la que se mira, y no hace falta que grite.

Qué es el héroe de cada pantalla:

| Pantalla | El héroe | Lo demás |
|---|---|---|
| Hoy | el anillo de pasos | plano |
| **Progreso** | **las gráficas** | el total y la actividad, planos |
| **Social** | [PENDIENTE: se rediseña ahora que es solo el ranking] | listas planas |
| Premios | la cuadrícula de fotos | plano |

En Progreso el héroe son **las gráficas y no el número**. Se probó al
revés —el total en una tarjeta oscura, a 64 px— y salió peor: lo que
llamaba la atención era el total y los dibujos quedaban de relleno debajo.
El total es CONTEXTO para poder leer las gráficas, no el protagonista.

**NO hay superficies oscuras.** Se probó un escalón oscuro de la escala de
azules para las tarjetas héroe y se descartó el mismo día: a tamaño de
tarjeta, una superficie de color llama demasiado la atención y le roba la
lectura al contenido que tiene adentro. Si aparece un `azulTinta` o una
`AppSombras.heroe` en el código, son de ese intento y hay que sacarlos.

**Una lista es una lista, no una pila de tarjetas.** Grupos,
entrenamientos, filas de ranking: van como renglones separados por una
línea de un pelo (`AppColors.separador`, 0,5 px), nunca metiendo cada uno
en su propia caja con borde. Es lo que hace iOS y es lo que deja recorrer
una lista sin leerla entera. En una tabla de ranking, **solo tu fila lleva
relleno** (`azulBruma`, de lado a lado): así te encontrás antes de leer un
nombre.

**Dos radios y no más** (`AppRadios`): `tarjeta` = 18 para cualquier
superficie, `pildora` = 999 para chips, badges y barras. Había diez
mezclados —10, 12, 14, 16, 18, 24, 28—: dos tarjetas hermanas con 16 y 18
no se ven distintas, se ven mal hechas.

**Las gráficas se dibujan para mirarse, no para consultarse.** Alto
generoso (210-215 px, no 150), línea de 3 px con degradado del `azulMedio`
al `accent`, área de abajo al 28% y **una sola marca**, la del tramo en
curso — un círculo en cada punto ensucia la curva, y lo que una curva
tiene que mostrar es la FORMA. Las barras van anchas, con la punta de
arriba redondeada a 8 y degradado vertical: un degradado es lo que hace
que una barra se vea como un volumen y no como un rectángulo de color.

Reglas visuales:
- **Nunca bordes punteados** en botones, tabs, o nav — corregir siempre a
  sólido o sin borde
- **Sin glows brillantes** — sobre fondo claro se ven mal. Usar sombras
  suaves grises/verdes en su lugar
- **Colores por nivel de cashback:** progresión del azul de marca (nivel 1
  = azul más claro → nivel 4 = `#012096`), vía
  `AppColors.colorForNivel(int)`. Lo que separa un nivel del siguiente es
  la LUMINOSIDAD, no el matiz: se leen como escalones aunque no se
  distingan bien los colores
- **Barras de progreso:** fondo vacío en `#E3E6F0`, relleno en azul
- **El anillo de pasos de Home se mide desde CERO, no desde el piso de su
  tramo** (bug que encontró Daniel el 21 de septiembre de 2026). El texto
  del centro dice "8.000 de 10.000" y el aro tiene que verse a cuatro
  quintos. Antes el aro de plata se llenaba de 7.000 a 10.000, así que
  con 8.000 pasos se pintaba un tercio debajo de un texto que decía otra
  cosa: dos escalas para el mismo dato. La fórmula vive en
  `fraccionDelAro()` de `progress_ring.dart` y tiene tres reglas — un
  tramo terminado queda completo debajo del siguiente, uno que no arrancó
  queda en cero, y el que está EN CURSO vale `pasos / su techo`
- **Header** (`lib/widgets/app_header.dart`, reutilizado en TODAS las
  pantallas): "+VIDA" pegado a la esquina superior IZQUIERDA, foto de
  perfil pegada a la DERECHA
- **La foto del usuario sale de `lib/widgets/avatar_usuario.dart`** y de
  ningún otro lado. Aparece en tres lugares —el header, la ficha de
  Perfil y el escalón de la escalera de cashback donde el
  usuario está parado, que ahora vive en la hoja de niveles de **Mi
  Plan**— y los tres tienen que mostrar la MISMA. Es el
  único archivo que nombra la ruta del asset; el día que la foto llegue
  del backend cambia ahí y nada más. En la escalera de cashback la foto
  REEMPLAZA al cartel "ESTÁS AQUÍ": una cara se reconoce sola y un
  cartel hay que leerlo.

  La escalera con la foto (`escalera_cashback.dart`) se abre **tocando el
  medallón del nivel en Mi Plan**, dentro de la hoja de niveles
  (`hoja_niveles.dart`), que trae los puntos del año, el nivel y la
  escalera completa. Esto reemplaza a la versión anterior de este
  documento, que la dejaba siempre abierta en Home (decisión de Daniel,
  22 de septiembre de 2026): son cinco barras que el usuario ya conoce a
  la segunda semana ocupando media pantalla todos los días para
  contestar una pregunta que se hace una vez por mes. Un disco con un
  número adentro es exactamente lo que se toca para saber qué significa
  ese número.
- **Barra inferior** (`lib/widgets/bottom_nav_bar.dart`, reutilizada en
  TODAS las pantallas): 5 ítems fijos en este orden: Hoy, Progreso,
  Social, Premios, Mi Plan. El ítem activo necesita fondo de píldora sutil
  (azul de marca muy pálido) — sobre fondo claro ya no basta el contraste
  solo

## Cómo se construye la UI — regla dura

**+Vida es una app iOS y tiene que sentirse nativa de iOS.** No es una
preferencia estética: es el criterio que gana cuando dos opciones se
contradicen.

Nada se escribe a mano si ya existe un componente que lo resuelva. El
orden de preferencia es **estricto** — se baja al siguiente escalón solo
cuando el anterior no tiene nada que sirva:

1. **`package:flutter/cupertino.dart`** — SIEMPRE primero para cualquier
   cosa con la que el usuario interactúe: botones, selectores segmentados,
   switches, pickers, alertas, hojas modales, barras de navegación.
   `CupertinoButton`, `CupertinoSlidingSegmentedControl`,
   `CupertinoAlertDialog`, `CupertinoPicker`, `CupertinoSwitch`.
   Estos traen gratis el atenuado, el rebote y la sensación que un usuario
   de iPhone ya conoce. Una imitación hecha con `GestureDetector` +
   `AnimatedScale` NUNCA es preferible a un control de Cupertino.
2. **`shadcn_ui`** — para lo estructural que Cupertino no cubre: tarjetas,
   badges, menús flotantes, popovers, acordeones, campos de formulario.
3. **`getwidget`** — para piezas sueltas que las dos anteriores no traen:
   avatares, barras de progreso animadas, indicadores.
4. **`fl_chart`** — TODA gráfica. No se dibujan gráficas con
   `CustomPainter`: la librería ya trae animación al cambiar de datos,
   tooltips táctiles y ejes configurables.
5. **`CustomPainter` propio** — solo cuando ninguna de las anteriores lo
   resuelve. Hoy el único caso legítimo es el anillo de pasos de Home, que
   es un dibujo específico del producto.

**Todas se atan a los tokens de `lib/theme.dart`.** Ninguna librería
entra con su paleta por defecto: shadcn tiene sus grises, GetWidget su
azul, y si se dejan como vienen la app se ve hecha de tres apps
distintas. El `ShadThemeData` de +Vida vive en `theme.dart` y se arma
desde `AppColors`.

**`TemaVida` es obligatorio.** Los componentes de `shadcn_ui` fallan si no
encuentran un `ShadTheme` arriba en el árbol, así que toda pantalla que se
monte —la app real o un test— tiene que pasar por
`TemaVida(child: ...)`. Ponerlo solo en el `builder` del `MaterialApp` NO
alcanza: los tests montan pantallas sueltas y revientan.

Cuando lo nativo de iOS y el look de shadcn se contradigan, **gana iOS**.
shadcn y GetWidget son de estética web/Material: se usan por lo que
resuelven, no por cómo se ven de fábrica.

## Pantallas — estado y contenido

**Home** (`lib/screens/home_screen.dart`) — construida
- Header + saludo dinámico + racha activa con el fueguito (sin hitos ni
  monedas por racha)
- Anillo de pasos (color según nivel, gradiente, marcadores 25%), meta
  diaria, tiempo restante del día
- Tarjeta de puntos totales (SIN botón de canje)
- **"Tu Cashback" quedó en tres datos y SIN gráfica** (decisión de
  Daniel, 22 de septiembre de 2026): los puntos del año, la pastilla del
  nivel con su %, cuánto falta para el siguiente y el botón que abre el
  monto en quetzales con su nota regulatoria. Va plano, sin tarjeta: el
  héroe de Hoy es el anillo de pasos y esto era una tarjeta blanca con
  borde compitiendo con él
- **Hoy se divide en tres bloques por horizonte de tiempo: "Hoy", "Esta
  semana" y "Este año"** (decisión de Daniel, 24 de septiembre de 2026:
  "mucha info en un puño y cuesta saber dónde ver cada cosa"). Cada
  bloque tiene UN solo título en grande (`AppTheme.display(22)`) con su
  ícono en un disco `azulBruma`, una línea gris que dice qué hay adentro
  ("Dos objetivos que te dan monedas") y una raya de un pelo que lo separa
  del de arriba. Esto reemplaza al rótulo chico en mayúsculas (DIARIO,
  SEMANAL, ANUAL) con otro título debajo ("Objetivos de la semana", "Tu
  Cashback"): dos niveles de títulos peleando. "Ver mi plan" va a la
  derecha del título de "Este año"
- **El saldo de monedas NO va en Hoy.** Vive en el encabezado de **Tu
  camino**, al lado de lo que paga cada semana, y tocarlo abre la hoja
  de monedas. En Hoy competía con el "+10" de la semana
- "Esta semana" (minimalista, sin tarjetas, **el botón del camino
  primero**). De arriba abajo, en orden de importancia:
  - el **botón del camino**, que además **dice la semana**: "Semana 3
    de 10" en grande (el "de 10" atenuado), "Ver tu camino" debajo y una
    flecha en un círculo blanco. Azul de marca con un degradado apenas
    perceptible y sombra difusa: es lo único levantado del bloque. La
    semana va ahí para que no haga falta entrar al camino a verla, y por
    eso **no hay píldora "Semana 3" aparte**. Sin dibujos adentro (ni
    camino en miniatura ni línea de puntos)
  - la **marca, pegada debajo del botón**: logo y "Esta semana la
    patrocina **Montanos**", con el nombre en el color de la marca. Al
    pie de todo se leía como patrocinadora de la sección entera; pegada a
    la semana y con "Esta semana" en la frase, queda claro que es solo de
    esa semana
  - la **regla en un renglón**, en gris: "Cumple los dos para ganar" y a
    la derecha el **premio: solo "+10" y la moneda** en una pastilla
    naranja suave (nunca "ganas 10 monedas")
  - los **dos objetivos LADO A LADO**, en dos columnas separadas por una
    línea de un pelo, como las estadísticas de Fitness: nombre corto
    ("Pasos", "Entrenamiento") con su ícono y un chevron en `azulMedio`,
    el avance en grande, "de 40,000 pasos" en chico y una barra fina de
    6 px (`cardBorder` → degradado `azulMedio` → `accent`). El cumplido
    lleva el check naranja suelto al lado del número
  - al pie, en gris: el conteo y el plazo, una sola vez
  - en la hoja que se abre desde un nodo del camino no hay botón: la
    semana va de titular ("Semana 7") y el resto es igual
- **Tocar un objetivo abre su DETALLE** (`hoja_objetivo.dart`, pedido
  de Daniel, 24 de septiembre de 2026): el número en grande con su
  barra, cuánto falta dicho como cantidad ("42 min más y lo cumples"),
  cómo se cuenta, cuándo se cierra —"No tienes que marcar nada"— y lo
  que paga la semana. Es una hoja de INFORMACIÓN: tocar un objetivo
  nunca lo marca
- **Los títulos de sección de Hoy llevan el ícono en un disco
  `azulBruma`** con el ícono en `accent`: en negro suelto se perdían
  entre tanto blanco
- **Un objetivo NO se marca, y no puede parecer que se marca** (prueba
  con usuario, 22 de septiembre de 2026). Cada fila llevaba un círculo
  de 19 px con un check adentro —la forma exacta de un checkbox de
  iOS— y la primera persona que probó la app intentó tocarlo. No hay
  nada que marcar (tocarlo abre el detalle, nada más): el objetivo lo
  cierra el SERVIDOR el domingo
  23:59 con los datos de Apple Health. Nada con forma de casilla: el
  cumplido lleva un check suelto en naranja al final de la píldora — sin
  círculo y sin relleno, que es el cuarto uso permitido del naranja
- **El camino de las semanas** (`camino_semanas_screen.dart`) va y
  vuelve por FILAS, como un tablero de mesa: 3 nodos por fila, la fila
  siguiente al revés, y el giro siempre en la misma columna. No quedan
  huecos en la grilla y diez semanas entran en 4 filas (antes era una
  columna de diez renglones: 1.520 px de scroll)
- **La grilla ordena, la CINTA ondula** (decisión de Daniel, 22 de
  septiembre de 2026). Los CENTROS de los nodos no se tocan —todos a la
  misma altura dentro de su fila y a la misma distancia entre sí; un
  nodo fuera de la grilla se lee como un error de alineación—, pero el
  trazo que los une se comba: los tramos de una fila de a uno hacia
  arriba y de a uno hacia abajo (una onda larga, nunca un zigzag) y el
  giro de fila abriéndose hacia el borde de la pantalla. Con tramos
  rectos y esquinas de 90° lo que se veía era el contorno de una tabla.
  Es una CINTA de 9 px y no un cable de 5: es la única cosa levantada de
  la pantalla. Esto reemplaza a la versión anterior de este documento,
  que pedía que ningún tramo saliera en diagonal — lo que esa regla
  evitaba eran las diagonales largas de la versión por columnas, no que
  la línea se curve
- **Cada círculo dice qué semana es, con todas las letras: "SEM 7".** En
  esa pantalla conviven dos escaleras de números —semanas y monedas— y
  un número suelto adentro de un círculo puede ser cualquiera de las
  dos; lo que el usuario necesita saber al mirar adelante es a
  qué SEMANA va a entrar. El rótulo va adentro del círculo y no colgado
  del nodo: rotular los diez por fuera eran diez cajitas blancas
  flotando sobre el camino. La semana en curso no lo repite, porque
  arriba tiene la única etiqueta del camino —rellena de azul, la que
  reemplazó a la píldora "ESTA SEMANA"— que ya dice "Semana 3"
- **En el camino no hay ninguna tarjeta.** Lo que paga cada semana va
  sin pastilla blanca: el
  fondo que corta la cinta detrás del texto es del color del fondo de
  pantalla. Es la regla de UNA SOLA COSA LEVANTADA, y acá esa cosa es el
  camino
- **El camino se dibuja solo al entrar:** la cinta crece tramo por
  tramo y cada nodo aparece cuando llega hasta él, en vez de entrar los
  diez juntos. El halo de la semana en curso late muy despacio (3 s, 6%)
  y es el único movimiento perpetuo de la pantalla. Todo eso se apaga
  con "Reducir movimiento" de iOS
- **El titular nombra la PANTALLA, no una semana: "TU CAMINO".** Antes
  decía "SEMANA 3" y se leía como si la pantalla fuera de esa sola
  semana, con diez nodos debajo. En qué semana va y quién la patrocina
  bajaron al renglón de apoyo, que es su tamaño. (Esto reemplaza a la
  versión anterior de este documento, que pedía la semana en curso de
  titular.)
- **En el camino no hay rango** (decisión de Daniel, 24 de septiembre de
  2026): se sacaron el renglón con la insignia y la frase de cómo se
  sube. Debajo del título va directo el camino. El camino no asume
  cuántas semanas son: dibuja las que manda el servidor
- **Semanas patrocinadas:** una alianza puede comprar una semana. Esa
  semana paga un cupón de esa marca **además** de las monedas del objetivo semanal,
  nunca en lugar de ellas. Se ve en tres lugares: el logo del local
  montado en el borde del nodo, un anillo con el color de la marca
  alrededor del círculo, y —solo si la semana EN CURSO está vendida— la
  tarjeta animada con la foto, debajo del título. Las semanas vendidas
  que faltan viven detrás del botón "Patrocinadores de las próximas
  semanas", no a la vista: el protagonista es el camino
- **No todas las semanas tienen marca, y ese es el caso normal.** Sin
  patrocinador no se dibuja tarjeta, ni logo, ni botón, y el título no
  menciona el patrocinio: **nunca un hueco ni un cartel que anuncie la
  ausencia.** El nodo no cambia de tamaño ni de lugar por tener marca —
  la celda mide 160 px de alto clavados y la curva se dibuja aparte,
  contra los centros ya calculados, así que un nodo que crece se despega
  de su propia curva
- La marca trae dos colores y **no son lo mismo**: `fondo` es el color
  detrás de la foto (el de Montanos es negro, y sin él su logo blanco
  desaparece) y `acento` es el del anillo y el cupón. Un anillo negro no
  va con una app que tiene que transmitir calma

**Progress** (`lib/screens/progress_screen.dart`) — construida
- Selector Semana/Mes/Año con contenido real por pestaña
- Meta del período + comparación vs. período anterior
- **"Tu actividad" trae DOS cifras y cambian con el filtro.** En MES la
  segunda dice "20 de 30" con la etiqueta "días activos de septiembre":
  el denominador son los días que tiene ESE mes —se calcula de la fecha
  del dato, nunca escrito a mano, que febrero tiene 28— y el mes se
  nombra para que quede claro que la cuenta arranca de cero el día 1. En
  AÑO la segunda dice "promedio de puntos por mes" con todas las
  letras: "puntos por mes" al lado de un 1.405 se leía como si cada mes
  hubiera pagado eso
- Gráfico de actividad (nunca 30+ barras finitas sin etiqueta)
- **El mapa de calor del año dibuja UNA CASILLA POR DÍA VIVIDO, y ni una
  más** (decisión de Daniel, 22 de septiembre de 2026). Llegaba al 31 de
  diciembre, así que en septiembre había tres meses y medio de casillas
  vacías a la derecha esperando a existir y el año propio se veía a
  medio hacer. Cada día que pasa aparece su casilla y se va llenando,
  como el mismo mapa en Claude Code. Los meses ANTERIORES al primer dato
  sí se dibujan, vacíos: esos días existieron aunque la app no estuviera
  instalada, y son los que le dan al año su forma
- Racha con historial de 8 semanas (cada casilla refleja si se cumplió),
  sin hitos de monedas
- "Nivel Actual", Monedas del período, Ritmo Cardíaco (obligatorio si se
  pide permiso `.heartRate`)
- CTA "Ver mis récords" (pantalla de Récords Personales — pendiente)

**Social** (`lib/screens/social_screen.dart`) — **solo el ranking**
(decisión de Daniel, 25 de septiembre de 2026). Título "SOCIAL" y debajo lo
que antes era la pestaña Ranking: Mis competencias (Tus Ligas) y Liga local
(La Liga), con su selector.
- **Ya no existen los amigos, las solicitudes ni los duelos.** Se borró todo
  el código: la pestaña Amigos, `amigos_screen.dart`, `retar_screen.dart`,
  los contadores, el flujo de "Agregar amigo", los modelos (`Duelo`,
  `DueloHistorial`, `Conexion`, `Solicitud`) y sus datos del mock. Tampoco
  existe el selector Amigos / Ranking. **No reconstruirlos** sin que Daniel
  lo pida
- "Invitar amigos" en un grupo de Tus Ligas NO es el sistema de amigos: es
  compartir el código del grupo, y sigue siendo parte del ranking
- [PENDIENTE: rediseño de la estructura y el diseño del ranking — Daniel
  lo quiere cambiar]
- Ranking: selector de grupos, posición propia, cuánto falta para subir,
  lista completa

**Social: La Liga y Tus Ligas** (nombres y reglas decididos por Alvaro el
22 de septiembre de 2026; los duelos se sacaron el 25 de septiembre):

| | La Liga | Tus Ligas |
|---|---|---|
| Quién la arma | La app, automático | El usuario (crea o se une) |
| Con quién | Gente random de tu franja de edad | Amigos, familia, colegas |
| Ciclo | Mensual (día 1 al último del mes) | Mensual, no configurable |
| Compite por | Pasos del mes | Pasos del mes |
| Premio | **Sí** — monedas al top 3 | **No** |
| Requiere póliza | Sí | Sí |

**La Liga** (la de `tipo: desconocidos` en el código): franjas de edad de 10
años (20–29, 30–39…), máximo 30 personas por grupo, asignación **automática y
aleatoria** re-sorteada cada mes — sin botón de "unirme". Nunca se muestran los
puntos de otros miembros. Corre del día 1 al último día del mes, en hora de
Guatemala. (Antes este documento decía trimestral: eso queda reemplazado.)

**Tus Ligas** (competencias con conocidos): la duración **no se elige** — el
selector de 1/2/3 meses se borró.

El **objetivo semanal** corre aparte (lunes 00:00 a domingo 23:59) y no se
mezcla con ninguna liga.

Cada ciclo de La Liga puede tener una **marca patrocinadora**: los 3
primeros ganan un cupón de esa marca ADEMÁS de sus monedas, nunca en lugar
de ellas. Los datos de patrocinio salen del repositorio, nunca fijos en el
widget. [PENDIENTE: el endpoint de patrocinios lo debe Luis; hasta entonces
sale del mock y la marca de ejemplo (Ookii) es un placeholder de Diego.]

**Premios** — construida
- Catálogo (filtros, saldo de monedas, costo en monedas)
- Detalle (condiciones, vencimiento, canje)
- Canje exitoso (QR, resumen de monedas descontadas)
- **Sin póliza verificada:** el catálogo se ve completo, pero el botón de
  compra sale bloqueado (gris, con candado) con CTA a vincular póliza
- **Tienda / Mis cupones** (24 de septiembre de 2026): un
  `CupertinoSlidingSegmentedControl` debajo del título, con cuántos
  cupones hay por usar en una píldora azul. Antes el QR se veía UNA vez,
  en el canje exitoso, y si se cerraba esa pantalla el cupón no se
  volvía a encontrar. En "Mis cupones" (`mis_cupones.dart`):
  - los **activos como boletos** —talón con el logo, muescas arriba y
    abajo, corte sólido—, del que vence primero al último. Son lo único
    levantado de la vista. A 7 días de vencer, el "Vence en…" pasa a
    naranja (alerta real). Los que se ganaron llevan un regalo y
    "Semana 1"
  - los **usados y vencidos** abajo, como lista plana y apagada
  - tocar un boleto abre el **código en grande** en una hoja: el QR con
    las esquinas del visor en azul, el código escrito por si la caja no
    escanea, y cuándo vence
  - viven ahí también los cupones de semanas y podios patrocinados:
    todos los cupones en un solo lugar
- **El QR sale de `codigo_qr.dart`** y de ningún otro lado: el canje
  exitoso y Mis cupones muestran el MISMO dibujo. Todavía es un QR de
  muestra sacado del texto del código (`qr_flutter` no está en el
  proyecto y el formato lo define el backend)
- Al canjear, el cupón queda guardado ANTES de mostrar el éxito
  (`registrarCanje` en `fuente_datos.dart`, que hace de backend mientras
  no exista el de Luis), y el canje exitoso ofrece primero "Ver mis
  cupones"

**Mi Plan** — diseñada, confirmar si está construida en Flutter
- Cashback acumulado, proyección de fin de año, calendario de cálculo,
  nota regulatoria, tabla de niveles
- **Al cambiar de filtro se anima SOLO lo que cambia** (decisión de
  Daniel, 22 de septiembre de 2026): el contenido de abajo entra con su
  transición y el título, el medallón de nivel y la tarjeta del cashback
  se quedan quietos. Dicen lo mismo con cualquier filtro puesto, y una
  pieza que se desvanece y vuelve se lee como que cambió. En pantalla
  alta eso pasaba solo, porque el cabezal vive afuera del scroll; el
  caso que había que arreglar era el corto —o con la letra de iOS
  grande—, donde el cabezal baja adentro del scroll. El scroll vuelve
  arriba con un controlador, no con una llave: la llave reconstruía el
  scroll entero y era lo que obligaba a animar todo junto
- Sección "Detalles de tu Póliza" (datos que la aseguradora expone al
  asegurado, agrupados en 2-3 tarjetas por tema): número de póliza,
  titular y dependientes, tipo de plan, suma asegurada, deducible,
  coaseguro, vigencia, renovación, prima y forma de pago, red de
  hospitales/cobertura, estado de la póliza
- **Sin póliza (cuenta base):** estado vacío con CTA "Ingresa tu póliza para
  acceso completo" + **cotizador express**. "Póliza pendiente de verificación"
  se trata exactamente igual que "sin póliza" — no hay un tercer estado
  visual

**Perfil y Configuración + Consentimiento aseguradora** — diseñadas en
Stitch, pendiente pasar a Flutter

**Permiso de Apple Salud** (`lib/screens/permisos_salud_screen.dart`,
ruta `/permisos-salud`) — construida el 24 de septiembre de 2026. Antes
del diálogo de iOS explica con palabras de todos los días para qué sirve
cada dato ("Necesitamos ver tus pasos para calcular tus puntos"); después
dice qué se ve DE VERDAD, tipo por tipo, con los `TiposVisibles` que
devuelve `solicitarPermisos`. Sale **la primera vez que se abre la app**,
antes de Hoy (`_Arranque` en `main.dart`, recordado en
`AlmacenPermisos`), y desde **Perfil**, tocando la fila "Apple Salud".
Regla de tono: sin ritmo cardíaco ni entrenamientos casi siempre es "no
tiene reloj", no un permiso negado — se dice como algo normal, y el
camino a Ajustes va solo para quien SÍ usa reloj. En la UI la app se
llama "Salud", que es su nombre en un iPhone en español.

**Registro / login / recuperar contraseña** — no existen todavía. Cuenta base:
email + contraseña + **fecha de nacimiento** (obligatoria). Vincular póliza es
un segundo paso, aparte. Token en almacenamiento seguro, en cada request HTTP.

## Datos que se comparten con la aseguradora

El consentimiento del usuario para compartir datos con la aseguradora es
**explícito, en pantalla propia y revocable** — eso no cambia.

**Confirmado:** a la aseguradora sí le llegan datos por persona — pasos
totales del día, ritmo cardíaco promedio del día y workouts realizados. Lo
que **no** se manda es el dato crudo de HealthKit (minuto a minuto, samples
individuales) — todo va agregado a nivel de día. Esto es lo que define el
reporte mensual acordado con Diego (18 de septiembre de 2026).

[PENDIENTE] El texto de consentimiento actual de la app (D11) promete algo
más estricto que esto — solo agregados de cohorte, nada a nivel de persona —
y ya no refleja lo que realmente se comparte. Hay que reescribirlo para que
diga la verdad: se comparten agregados diarios por persona, no datos crudos.
No copiar el texto viejo si se toca esa pantalla.

Para septiembre el reporte es solo un Excel manual. Landing, login y dashboard
para la aseguradora son post-piloto y viven **fuera** de la app de Flutter.

## Decisiones técnicas cerradas

- Frontend: **Flutter** (decisión final, no solo demo). Capa nativa en Swift
  solo para HealthKit.
- **MethodChannel:** 2 métodos, nada más — `solicitarPermisos` y
  `sincronizar`. Usar siempre `lib/datos/healthkit_bridge.dart`. Todo lo demás
  va por HTTP directo contra la API.
- Backend: **Django + PostgreSQL** (decisión final). `TIME_ZONE =
  'America/Guatemala'`.
- Sync: `POST /api/v1/sync`, el día completo cada vez. Los reintentos corren
  del lado nativo — Flutter no implementa reintentos propios.
- Autenticación: `TokenAuthentication` de DRF; la identidad sale del token,
  nunca del body. Todavía no implementada.
- Fuente de datos: Apple HealthKit únicamente
- Datos leídos: pasos, ritmo cardíaco, workouts (NO elevación, NO sueño en v1)
- Distribución piloto: TestFlight, cuenta Apple Developer de organización
  (Assures)
- Builds de iOS: Daniel no tiene Mac — los `.ipa` salen de CI con runner
  macOS en GitHub Actions

## Decisiones pendientes

- El "twist propio" del proyecto
- Tabla de meta de pasos por objetivo semanal — Luis (L11)
- Validación médica/actuarial del bonus 60+ y de FCmáx = 219 − edad
- Qué cuenta la racha del fueguito
- Datos por persona vs. solo agregados hacia la aseguradora
- Plausibilidad fisiológica: descartar vs. marcar para revisión
- Tus Ligas: cupo de miembros y cómo se invita
- El endpoint de patrocinios (qué semana y qué ciclo de liga están
  vendidos, con qué marca y qué cupón) — lo debe Luis. Hasta entonces sale
  del mock; la marca de ejemplo (Ookii) es un placeholder de Diego
- Si el cupón de una semana patrocinada se SUMA al premio del catálogo o
  lo reemplaza. Hoy se construyó como premio adicional (las monedas del
  objetivo semanal se pagan igual), que es lo único que no contradice la
  mecánica del objetivo semanal

## Modelo viejo — migrar si aparece en el código

- Membresía freemium / multiplicador de pasos.
- Bronze/Silver/Gold/Platinum.
- **Nivel 4 con piso en 12.000**, o "el nivel 4 es alcanzable con chequeos".
- Escalones de pasos 7.500 / 12.000 / 20.000, o puntos 5/10/20.
- FCmáx = 220 − edad, techo diario de 500 pts, o una sola celda de intensidad
  (42 min al 74%).
- Bono 60+ ×1.25, o bono solo sobre intensidad.
- **Tres objetivos por semana**, retos que **bajan** de nivel, reinicio
  mensual, "metas mensuales".
- Monedas que caducan a 6 meses; tope de 100 monedas **por semana**.
- Lista blanca de fuentes; "gana la fuente con más pasos" entre todas.
- Ventana de datos rezagados de 3 o 6 días.
- Liga de desconocidos **trimestral**, por zona, u opt-in.
- Término "medallas" (ahora son monedas).
- **Rango** de los objetivos semanales: escalera, insignia con muescas,
  subir o bajar según cumplas, monedas por "subir al rango N". Una sola
  meta por semana, o tres.
- Recompensas por constancia: hitos de 4/8/12/24/52 semanas que dan monedas.
- **Amigos, solicitudes de amistad y duelos 1 contra 1** en Social, con sus
  categorías cosméticas Bronce → Plata → Oro → Diamante (sacados el 25 de
  septiembre de 2026).
