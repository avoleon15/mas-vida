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
traducción literal ni robótica). Es para el mercado guatemalteco. Excepción:
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

Los **duelos** (Social, 1 contra 1 por pasos) NO dan ninguna moneda ni premio
— son puramente competitivos/sociales. Tienen categorías cosméticas (Bronce →
Plata → Oro → Diamante, en español) separadas de los niveles de cashback —
solo estado social, sin beneficio real.

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

La **liga de duelos cosmética** (Bronce → Plata → Oro → Diamante, en español)
sigue siendo algo aparte de los niveles de cashback — solo estado social.

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

**Objetivo semanal** (antes "retos semanales") — fuente de verdad:
`reglas-puntaje-vivo.md`, sección 4.

- **Una sola meta por semana, en pasos acumulados**, con dificultad
  progresiva (no es una meta de puntos). No hay tres objetivos por semana.
- Todos arrancan en **objetivo 1**. Cumplir la meta → sube al siguiente
  objetivo. **No cumplirla → el objetivo se congela** (misma meta la semana
  siguiente). **Nunca baja.**
- Techo real ~13 objetivos: una **season** dura 13 semanas.
- **Seasons trimestrales** en fechas fijas (1 ene, 1 abr, 1 jul, 1 oct): ese
  día exacto todos vuelven a objetivo 1, sin esperar al lunes. Se guarda el
  objetivo máximo alcanzado en cada season.
- Nunca usar la palabra "nivel" para esto: el nivel es el anual de cashback.
- Cumplir la meta acuña MONEDAS (bajo el tope de 100 acumuladas).
- Endpoint: `GET /api/v1/retos/estado` (objetivo actual, season, fecha de
  cierre, historial de seasons).

(Esto reemplaza a la versión anterior de este documento: tres objetivos por
semana, subir o **bajar** un nivel, y reinicio mensual.)

La semana cierra el **domingo 23:59** y el lunes 00:00 ya corre la siguiente,
en hora de Guatemala. Quién releva la semana es el **servidor**: el teléfono
nunca lo calcula, solo vuelve a pedir los datos al pasar el cierre
(`programarRelevoDeSemana`). Si lo decidiera el teléfono, cambiar la zona
horaria en Ajustes abriría una semana nueva antes de tiempo. El objetivo nuevo
se fija a las 00:00 del lunes; no hay estado de "evaluando". El servidor
acepta datos atrasados de la semana cerrada hasta el **mediodía del lunes**,
pero eso ya no cambia el objetivo — solo el historial y el acumulado anual. Por lo mismo,
**ningún texto del objetivo puede sonar a plazo propio** ("Faltan 42 min" se
leía como cuenta regresiva): se dice el avance sobre la meta ("48.000 de 70.000 pasos")
y el plazo una sola vez, abajo.

[PENDIENTE: la tabla de meta de pasos por objetivo (objetivo 1, 2, 3…). La
define Luis (L11) — **no inventarla**.]

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

- **background:** casi blanco con tinte azul mínimo `#F5F6FA`
- **card:** blanco puro `#FFFFFF` con borde sutil `#E3E6F0`
  (necesario para que las tarjetas no se pierdan contra el fondo claro)
- **accent (azul de marca):** `#012096` — botones principales, links,
  elementos interactivos
- **accentSecondary (naranja de marca):** `#F58700` — estados de éxito,
  checks completados, marcadores y detalles chicos
- **textPrimary:** azul muy oscuro `#101833` (NO negro puro, se ve muy
  duro sobre fondo claro)
- **textSecondary:** gris medio `#6B7280`
- **Tipografía:** SF Pro (o la más parecida disponible)

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
- **Header** (`lib/widgets/app_header.dart`, reutilizado en TODAS las
  pantallas): "+VIDA" pegado a la esquina superior IZQUIERDA, foto de
  perfil pegada a la DERECHA
- **La foto del usuario sale de `lib/widgets/avatar_usuario.dart`** y de
  ningún otro lado. Aparece en tres lugares —el header, la ficha de
  Perfil y el escalón de la escalera de cashback de **Home** donde el
  usuario está parado— y los tres tienen que mostrar la MISMA. Es el
  único archivo que nombra la ruta del asset; el día que la foto llegue
  del backend cambia ahí y nada más. En la escalera de cashback la foto
  REEMPLAZA al cartel "ESTÁS AQUÍ": una cara se reconoce sola y un
  cartel hay que leerlo.

  La escalera con la foto vive en **Home** (`escalera_cashback.dart`), no
  en Mi Plan (decisión de Daniel, 17 de septiembre de 2026). Esto
  reemplaza a la versión anterior de este documento, que la ubicaba en Mi
  Plan: esa pantalla muestra el nivel de HOY en su tarjeta hero y el
  camino completo de niveles no se repite ahí.
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
- "Tu Cashback": monto acumulado, camino de niveles, link a Mi Plan
- "Objetivo de la semana": **una sola meta de pasos** por semana, con su
  progreso, sus monedas y el check. Las metas mensuales y los tres objetivos
  por semana ya NO existen
- **El camino de las semanas** (`camino_semanas_screen.dart`) va y
  vuelve por FILAS, como un tablero de mesa: 3 nodos por fila, la fila
  siguiente al revés, y el giro siempre en la misma columna. Así ningún
  tramo sale en diagonal y no quedan huecos en la grilla (antes era una
  columna de un renglón por semana: 1.520 px de scroll con diez). **Cada nodo dice arriba qué semana es** ("Semana 7"), y la
  etiqueta de la semana en curso es la única rellena de azul: eso
  reemplaza a la píldora "ESTA SEMANA"
- **El titular nombra la PANTALLA, no una semana: "TU CAMINO".** Antes
  decía "SEMANA 3" y se leía como si la pantalla fuera de esa sola
  semana, con diez nodos debajo. En qué semana va y quién la patrocina
  bajaron al renglón de apoyo, que es su tamaño. (Esto reemplaza a la
  versión anterior de este documento, que pedía la semana en curso de
  titular.)
- **El objetivo semanal va en una insignia** (`insignia_rango.dart`): un medallón
  con el número adentro y un anillo de muescas alrededor (una por objetivo de la season, ~13), encendidas
  hasta el objetivo actual del usuario, de `azulMedio` al `accent` — lo que separa
  una muesca de la siguiente es la LUMINOSIDAD, igual que los niveles de
  cashback. Las muescas se encienden ENTERAS: media muesca sería el
  medidor de XP que `reglas_rango.dart` sacó a propósito, y el objetivo se
  mueve por cumplir la meta de la semana, no por juntar puntitos. Nunca baja:
  si no se cumple, la muesca se queda como está
- **Una season dura 13 semanas** (techo ~13 objetivos). Si el código del
  camino o de la insignia asume 10 semanas o 10 muescas, hay que ajustarlo
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
- Gráfico de actividad (nunca 30+ barras finitas sin etiqueta)
- Racha con historial de 8 semanas (cada casilla refleja si se cumplió),
  sin hitos de monedas
- "Nivel Actual", Monedas del período, Ritmo Cardíaco (obligatorio si se
  pide permiso `.heartRate`)
- CTA "Ver mis récords" (pantalla de Récords Personales — pendiente)

**Social** (`lib/screens/social_screen.dart`) — construida. Ahí viven La
Liga, Tus Ligas y Duelos (ver tabla abajo); la organización en pestañas es
decisión de Daniel
- Amigos: alerta de racha en riesgo, Duelo (activo/invitación), superación
  del propio baseline (nunca comparación directa), historial W/L, lista de
  conexiones y contadores de amigos / solicitudes recibidas / enviadas,
  con aceptar, rechazar, cancelar y eliminar
- **De otra persona SOLO se muestra la racha.** El nivel y las monedas
  quedaron prohibidos (decisión de Daniel, 4 de septiembre de 2026): el
  nivel se deriva del % de cashback sobre la prima, y las monedas son
  saldo. Juntos dejan estimar cuánta plata mueve alguien, y eso es
  exposición patrimonial — más en Guatemala. Esto reemplaza a la versión
  anterior de este documento, que pedía mostrar racha, categoría y
  monedas.
- De alguien que todavía NO aceptó la solicitud solo se ven nombre,
  usuario y amigos en común. Ni siquiera la racha.
- Ranking: selector de grupos, posición propia, cuánto falta para subir,
  lista completa

**Social: La Liga, Tus Ligas y Duelos** (nombres y reglas decididos por
Alvaro el 22 de septiembre de 2026 — reemplaza la tabla anterior de "liga
local trimestral"):

| | La Liga | Tus Ligas | Duelos |
|---|---|---|---|
| Quién la arma | La app, automático | El usuario (crea o se une) | El usuario |
| Con quién | Gente random de tu franja de edad | Amigos, familia, colegas | 1 contra 1 |
| Ciclo | Mensual (día 1 al último del mes) | Mensual, no configurable | — |
| Compite por | Pasos del mes | Pasos del mes | Más pasos |
| Premio | **Sí** — monedas al top 3 | **No** | **No** |
| Requiere póliza | Sí | Sí | Sí |

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

**Mi Plan** — diseñada, confirmar si está construida en Flutter
- Cashback acumulado, proyección de fin de año, calendario de cálculo,
  nota regulatoria, tabla de niveles
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
- Recompensas por constancia: hitos de 4/8/12/24/52 semanas que dan monedas.
