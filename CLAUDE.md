# +Vida — Contexto del Proyecto

Este archivo se carga automáticamente en cada sesión de Claude Code dentro de
este proyecto. Contiene las reglas de negocio, sistema de diseño, y estado
del proyecto que SIEMPRE deben respetarse al escribir o modificar código.

Si algo que se pide en el chat contradice una regla dura de este documento,
señalalo antes de proceder — no asumas que se quiere romper la regla sin
confirmarlo primero.

## Qué es +Vida

App iOS (construida en Flutter) que lee pasos/actividad de Apple Health, los
convierte en puntos, y esos puntos dan cashback sobre la póliza de gastos
médicos del usuario + premios canjeables con comercios aliados. Referente:
Discovery Vitality, adaptado a Guatemala. Es a la vez entrega de tesis (UFM)
y producto comercial real.

**Modelo de negocio:** B2B2C — el usuario final (asegurado) usa el producto,
pero el cliente que paga es la aseguradora.

**3 vías de ingreso:**
1. Cuota por usuario cobrada a la aseguradora
2. Membresía freemium: la versión premium multiplica los PASOS contados (no
   los puntos). El multiplicador debe aplicarse DESPUÉS de las validaciones
   anti-fraude, nunca antes.
3. Alianzas: comercios pagan por aparecer con cupones en Premios

## Idioma — regla dura

Toda la app en **español latinoamericano**, tono natural y humano (nunca
traducción literal ni robótica). Es para el mercado guatemalteco. Excepción:
los niveles de cashback se nombran por número ("Nivel 3"), nunca con los
nombres en inglés Bronze/Silver/Gold/Platinum, que el contrato v1 prohíbe
expresamente por ser de Vitality.

## Las 2 monedas — regla dura, nunca mezclar

1. **PUNTOS** — nunca se gastan. Determinan categoría anual y % de cashback.
   Nunca aparecen en Premios.
2. **MONEDAS** (antes "medallas" — si ves ese término en código viejo,
   migralo) — se gastan en Premios, caducan a los **90 días**. Nunca
   aparecen en Mi Plan.

   Los 90 días los confirmó Daniel en la revisión de UI del 9 de
   septiembre de 2026 y reemplazan a los 6 meses que decía la versión
   anterior de este documento. Si encontrás "6 meses" en código,
   comentarios o mocks, es del plazo viejo y hay que migrarlo.

Los **duelos** (Social) NO dan ninguna moneda ni premio por ahora — son
puramente competitivos/sociales.

Existe además una **liga de duelos cosmética** (Bronce → Plata → Oro →
Diamante, en español) separada de las categorías de cashback — solo estado
social, sin beneficio real.

## Niveles anuales de cashback — regla dura, numéricos

Fuente de verdad: `contrato-v1-corregido.md`, congelado.

**El naming Bronze/Silver/Gold/Platinum está PROHIBIDO en el proyecto.** Es de
Vitality, no de +Vida. El nivel es un entero de 0 a 4 y en la UI se dice
"Nivel 3", nunca un nombre en inglés. (Esto reemplaza a la regla anterior de
este documento, que pedía lo contrario.)

| Nivel | Puntos anuales | % Cashback |
|---|---|---|
| 0 | 0 – 2,499 | 0% |
| 1 | 2,500 – 4,999 | 5% |
| 2 | 5,000 – 9,999 | 7,5% |
| 3 | 10,000 – 11,999 | 10% |
| 4 | 12,000+ | 20% |

Tabla **confirmada** (Daniel, 1 de septiembre de 2026; los pisos de los niveles
3 y 4 corregidos el 17 de septiembre de 2026). Reemplaza a la versión anterior
de este documento, que dejaba los niveles 0, 1 y 2 sin definir y ponía el nivel
4 en 15.000+. Vive en `niveles`, dentro de `lib/reglas_puntos.dart`: ese es el
único lugar donde se escriben estos números, y **el código es la fuente de
verdad** — si este documento y esa tabla se contradicen, manda el código.

**Techo anual de actividad física: 12.000 puntos.** Topa los puntos por pasos
e intensidad, y NO es un techo de los puntos del año: **los chequeos médicos
dan puntos aparte, que se suman POR ENCIMA de ese techo.**

Consecuencia: **el nivel 4 SÍ es alcanzable.** Su piso son 12.000 puntos, que
es exactamente lo máximo que da la actividad física sola: se llega caminando,
pero justo. Los chequeos médicos son los que dejan MOVERSE dentro del nivel 4,
porque suman por encima de ese techo. Esto reemplaza a la versión anterior de
este documento, que decía que el nivel 4 quedaba fuera de alcance en el piloto.

Los 12.000 son el **piso** del nivel 4. La tabla de `reglas_puntos.dart` cierra
el nivel en 15.000 (`Nivel(4, 12000, 15000, 20)`) y ese número queda como está:
es el tope de la tabla, no un tope de lo que el usuario puede acumular.

[PENDIENTE: cuántos puntos da un chequeo médico. **No inventarlo**, y no
nombrar ninguna cifra de chequeos en la UI hasta que esté definido.]

La **liga de duelos cosmética** (Bronce → Plata → Oro → Diamante, en español)
sigue siendo algo aparte de los niveles de cashback — solo estado social.

**Regla regulatoria dura:** el cashback SIEMPRE se devuelve como dinero
DESPUÉS del pago de la prima. NUNCA se descuenta directamente (regulación de
la Superintendencia de Bancos de Guatemala). Siempre "cashback", nunca
"descuento en tu prima" ni "ahorro en tu póliza".

## Cálculo de puntos diarios

Fuente de verdad: el plan de proyecto del equipo (`TASKS.xlsx`, criterios de
aceptación de L6, L7, L8 y A15). Estas reglas **reemplazan** a las de la
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

**Por intensidad (ritmo cardíaco)** — matriz de duración × % de FCmáx:
- **FCmáx = 219 − edad.** El cálculo lo hace SIEMPRE el servidor a partir de
  la edad que viene en la póliza. El teléfono NUNCA manda la FCmáx ni la edad.
- Ancla conocida de la matriz: **42 min al 74% de FCmáx = 100 pts.**
- **Bonus 60+:** un usuario de 60 años o más recibe **×1.25** sobre los puntos
  de intensidad (esa misma sesión le da 125 pts a un usuario de 62 años).
- [PENDIENTE: la matriz completa de duración × % de FCmáx. El Excel fija un
  solo punto de la matriz. Luis la define en la tarea L7 — hasta entonces **no
  inventar escalones** ni reusar la tabla vieja de 60%/70% de este documento,
  que ya no aplica.]

**Techo diario absoluto: 200 pts**, igual para todas las edades, sumando ambas
vías. Un día que genere más puntos brutos acredita 200 y marca el registro con
`tope_diario_aplicado`. Llegar a exactamente 200 NO cuenta como recorte.
Ningún dato de ejemplo debe superar 200 pts en un solo día.

**Techo anual: 12.000 pts**, con su propia bandera `tope_anual_aplicado`.

Nota verificada: con la única celda definida de la matriz de intensidad (100
pts) más el escalón máximo de pasos (100 pts), un usuario menor de 60 llega
como mucho a 200 pts brutos — es decir, `tope_diario_aplicado` **no puede dar
true** para él. Solo se activa con el bonus 60+ (100 + 125 = 225). Hasta que la
matriz defina una celda mayor a 100, ese es el único camino.

Notas sobre la edad:
- La edad DEBE venir de los datos de la póliza que provee la aseguradora,
  NUNCA autodeclarada por el usuario (autodeclararla es un vector de fraude
  obvio).
- El bonus 60+ y la FCmáx REQUIEREN validación médica/actuarial antes de salir
  a piloto. No son definitivos.
- En la UI, cualquier mención al ajuste por edad debe tener tono cálido, nunca
  clínico ni condescendiente.

**Retos semanales — por nivel de dificultad progresiva, no por meta de puntos**
(confirmado en el contrato v1). Todos arrancan en nivel de reto 1. Completar la
meta de la semana SUBE un nivel; no completarla BAJA uno. El ciclo va de lunes
00:00 a domingo 23:59 en hora de Guatemala. Cumplir el reto acuña MONEDAS.

Los **tres objetivos de una semana cierran JUNTOS**, el domingo 23:59, y el
lunes 00:00 ya corre la semana siguiente con sus propios objetivos. Quién
releva la semana es el **servidor**: el teléfono nunca lo calcula, solo vuelve
a pedir los datos al pasar el cierre (`programarRelevoDeSemana`). Si lo
decidiera el teléfono, cambiar la zona horaria en Ajustes abriría una semana
nueva antes de tiempo. Por lo mismo, **ningún texto de un objetivo puede
sonar a plazo propio** ("Faltan 42 min" se leía como cuenta regresiva): la
columna derecha dice avance sobre la meta ("48 de 90 min") y el plazo se dice
una sola vez, abajo.

[PENDIENTE: la tabla de dificultad por nivel de reto. El contrato dice explícito
que no hay número documentado todavía; lo define Luis en el motor de reglas.
El tope de 100 monedas por semana que decía la versión anterior de este
documento tampoco calza con el techo mensual de 8 monedas que usa Home —
hay que reconciliarlos.]

[PENDIENTE: reconciliar los retos semanales con la "meta semanal adaptativa"
(arrancaba en 300 pts, oscilaba 200-800) y con las recompensas por constancia
de más abajo. Son dos modelos distintos de la misma mecánica y el Excel solo
describe el de retos. No mezclar los dos en la UI hasta que se decida.]

## Recompensas por constancia (streaks)

Al alcanzar hitos de semanas consecutivas cumpliendo la meta semanal, el
usuario recibe MONEDAS extra (nunca puntos — los puntos no se otorgan por
rachas):

| Semanas seguidas | Monedas |
|---|---|
| 4 | +5 |
| 8 | +10 |
| 12 | +20 |
| 24 | +40 |
| 52 | +100 |

La racha se muestra en Home (saludo), Progress (historial de 8 semanas +
progreso al próximo hito) y Social (alerta de racha en riesgo).

## Anti-fraude

- HealthKit registra qué app escribió cada muestra — guardar ese campo
  (`fuente_bundle`, `fuente_nombre`, `fuente_version` en cada muestra)
- Lista blanca de fuentes confiables (Apple, Garmin, Whoop). Una fuente que no
  esté en la lista blanca NO acredita puntos
- Una sola actividad cuenta por día (la de mayor puntaje)
- **Ventana de datos rezagados: 3 días.** Un dato de hace 2 días entra; uno de
  hace 5 no. (Antes este documento decía 6 días — el Excel lo baja a 3.)
- Una cuenta por persona
- Deduplicación: SIEMPRE consultar el total agregado, nunca sumar muestras
  crudas (ej. Apple Watch + Whoop a la vez)
- **Plausibilidad:** 60,000 pasos en un día se marcan para revisión
- La edad para el bonus 60+ y la FCmáx viene de la póliza, nunca del usuario

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
| **Social** | **el duelo activo** | amigos y ranking, listas planas |
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

**Una lista es una lista, no una pila de tarjetas.** Amigos, grupos,
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
- Header + saludo dinámico + racha activa (con aviso si está a 1 semana de
  un hito de monedas)
- Anillo de pasos (color según categoría, gradiente, marcadores 25%), meta
  diaria, tiempo restante del día
- Tarjeta de puntos totales (SIN botón de canje)
- **"Tu Cashback" quedó en tres datos y SIN gráfica** (decisión de
  Daniel, 22 de septiembre de 2026): los puntos del año, la pastilla del
  nivel con su %, cuánto falta para el siguiente y el botón que abre el
  monto en quetzales con su nota regulatoria. Va plano, sin tarjeta: el
  héroe de Hoy es el anillo de pasos y esto era una tarjeta blanca con
  borde compitiendo con él
- "Objetivos de la semana": las semanas del mes, cada una plegable, con
  sus 3 objetivos (progreso/monedas/check) y el rango. Las metas mensuales
  ya NO existen
- **Un objetivo NO se marca, y no puede parecer que se marca** (prueba
  con usuario, 22 de septiembre de 2026). Cada fila llevaba un círculo
  de 19 px con un check adentro —la forma exacta de un checkbox de
  iOS— y la primera persona que probó la app intentó tocarlo. No hay
  nada que tocar: los tres objetivos los cierra el SERVIDOR el domingo
  23:59 con los datos de Apple Health. El estado va ahora en un RIEL:
  una barra de 3,5 px pegada al borde izquierdo de la fila, azul de
  marca si está cumplido y azul pálido si no. El cumplido suma un check
  suelto en naranja al lado de la palabra "Completado" — sin círculo y
  sin relleno, que es el cuarto uso permitido del naranja. Sigue siendo
  binario: cuánto lleva lo dice la columna de la derecha en unidades
  reales ("48 de 90 min")
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
  esa pantalla conviven tres escaleras de números —semanas, rangos y
  monedas— y un número suelto adentro de un círculo puede ser cualquiera
  de las tres; lo que el usuario necesita saber al mirar adelante es a
  qué SEMANA va a entrar. El rótulo va adentro del círculo y no colgado
  del nodo: rotular los diez por fuera eran diez cajitas blancas
  flotando sobre el camino. La semana en curso no lo repite, porque
  arriba tiene la única etiqueta del camino —rellena de azul, la que
  reemplazó a la píldora "ESTA SEMANA"— que ya dice "Semana 3"
- **En el camino no hay ninguna tarjeta.** El rango es un renglón
  apoyado sobre el fondo con una línea de un pelo debajo (era un bloque
  de `azulNiebla`) y lo que paga cada semana va sin pastilla blanca: el
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
- **El rango va en una insignia** (`insignia_rango.dart`): un medallón
  con el número adentro y un anillo de 10 muescas alrededor, encendidas
  hasta el rango del usuario, de `azulMedio` al `accent` — lo que separa
  una muesca de la siguiente es la LUMINOSIDAD, igual que los niveles de
  cashback. Las muescas se encienden ENTERAS: media muesca sería el
  medidor de XP que `reglas_rango.dart` sacó a propósito, y el rango se
  mueve por cumplir los tres objetivos, no por juntar puntitos
- **Semanas patrocinadas:** una alianza puede comprar una semana. Esa
  semana paga un cupón de esa marca **además** de las monedas del rango,
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
- Racha con historial de 8 semanas (cada casilla refleja si se cumplió) +
  progreso al próximo hito de monedas
- Sección "Recompensas por constancia": los 5 hitos con check en los
  alcanzados
- "Nivel Actual", Monedas del período, Ritmo Cardíaco (obligatorio si se
  pide permiso `.heartRate`)
- CTA "Ver mis récords" (pantalla de Récords Personales — pendiente)

**Social** (`lib/screens/social_screen.dart`) — construida, dos pestañas
- **La pestaña Amigos abre con los TRES NÚMEROS**, como un perfil de
  Instagram: **Amigos · Solicitudes · Duelos activos**. Tienen que decir
  cosas DISTINTAS — no hay "seguidores" y "seguidos" por separado,
  porque la amistad en +Vida es mutua (se manda solicitud y el otro
  acepta) y serían el mismo número dos veces. El de solicitudes lleva el
  punto naranja cuando hay algo esperando; el de duelos no navega, es un
  marcador de lo que está justo abajo
- **No hay lista de amigos en Social** (decisión de Daniel, 22 de
  septiembre de 2026). Estaban los tres primeros con un "ver todos" al
  lado, que abre la misma lista que el contador de arriba: la pantalla
  mostraba dos veces lo mismo y el duelo —lo único que está pasando
  AHORA— quedaba aplastado entre dos listas de gente
- **UN DUELO ES UN RETO CON META COMÚN** (decisión de Daniel, 22 de
  septiembre de 2026): los dos van por el mismo número de pasos y el
  mismo plazo ("70.000 pasos en una semana"), y gana el primero que
  llega; si el domingo no llegó ninguno, gana el que quedó más cerca. La
  tarjeta lo dice en este orden: el RETO arriba y en grande, después de
  cada uno cuántos pasos lleva, qué parte de la meta es y cuánto le
  falta, y al tuyo además a qué ritmo diario tenés que ir. Cierra con
  cómo vas en palabras ("Vas arriba por 3.500 pasos") y la regla de cómo
  se gana.

  **Esto reemplaza a la regla anterior de este documento**, que pedía
  medir la superación del propio baseline y prohibía la comparación
  directa. El motivo de la regla vieja sigue siendo cierto —quien camina
  3.000 al día no le gana nunca a quien camina 12.000— pero "+18% sobre
  tu promedio" no dice cuánto falta ni qué hacer hoy. El duelo NO paga
  monedas ni toca el cashback, así que la asimetría no cuesta plata; lo
  que hay que cuidar es que la meta se elija entre los dos y sea
  alcanzable. [PENDIENTE: elegir meta y plazo al armar el duelo — hoy
  sale el reto por defecto.]
- **El historial de duelos dice contra QUIÉN fue.** Eran cinco avatares
  grises en fila con una W o una L en la esquina: no se reconocía a
  nadie, que es lo único que un historial tiene para contar. Ahora es
  una lista con la inicial, el nombre, el usuario y "Ganaste"/"Perdiste"
  —la palabra entera, no una W— más el marcador arriba a la derecha
- **"Retar a alguien" es un renglón, no un botón con relieve**, y cierra
  el bloque de duelos en vez de flotar arriba a la derecha compitiendo
  con el duelo en curso. Lleva a una pantalla PROPIA
  (`retar_screen.dart`) que solo lista a tus amigos con un botón Retar
  por renglón: antes llevaba a la pantalla de Amigos, y el que entró a
  retar se encontraba administrando su lista de contactos
- Alerta de racha en riesgo y, en la pantalla de Amigos, aceptar,
  rechazar y eliminar
- **No hay pestaña de "Enviadas"** (decisión de Daniel, 22 de septiembre
  de 2026). Ver la lista de lo que mandaste no lleva a ninguna parte.
  Que ya la mandaste se dice donde alguien lo preguntaría de nuevo: al
  buscar a esa persona para agregarla, el botón dice **"Solicitud
  enviada"** y no deja mandarla otra vez (y "Ya son amigos" si ya lo es).
  Es el funcionamiento de Instagram, y la solicitud queda guardada, así
  que cerrar la hoja y volver a buscar sigue diciendo lo mismo
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

**Los ciclos de competencia son tres y no se mezclan** (confirmado por
Daniel, 9 de septiembre de 2026):

| Qué | Ciclo | Quién lo arma |
|---|---|---|
| Liga local (`tipo: desconocidos`) | trimestre calendario | la app |
| Competencia con conocidos (oficina, familia, amigos) | 1 mes, no configurable | el usuario |
| Retos | semana (lunes 00:00 a domingo 23:59) | la app |

La liga local corre del día 1 del primer mes al último día del tercero, en
hora de Guatemala. Antes cerraba un domingo — corría semanal — y eso era un
bug del build, no una regla. La duración de las competencias personales
**no se elige**: el selector de 1/2/3 meses se borró.

Cada ciclo de la liga puede tener una **marca patrocinadora**: los 3
primeros ganan un cupón de esa marca ADEMÁS de sus monedas, nunca en lugar
de ellas. Los datos de patrocinio salen del repositorio, nunca fijos en el
widget. [PENDIENTE: el endpoint de patrocinios lo debe Luis; hasta entonces
sale del mock y la marca de ejemplo (Ookii) es un placeholder de Diego.]

**Premios** — construida
- Catálogo (filtros, saldo de monedas, costo en monedas)
- Detalle (condiciones, vencimiento, canje)
- Canje exitoso (QR, resumen de monedas descontadas)

**Mi Plan** — diseñada, confirmar si está construida en Flutter
- Cashback acumulado, proyección de fin de año, calendario de cálculo,
  nota regulatoria, tabla de categorías
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

**Perfil y Configuración + Consentimiento aseguradora** — diseñadas en
Stitch, pendiente pasar a Flutter

## Datos que se comparten con la aseguradora

Límite duro: nada de HealthKit crudo a terceros. Solo datos agregados, con
consentimiento explícito del usuario en pantalla propia y revocable.

Lo que SÍ se comparte (agregado, nivel de cohorte):
- % de asegurados en cada categoría y tendencia de actividad del pool
- Tasa de adherencia: % con rachas activas, % que sube vs. baja de categoría
- Segmentación por edad/categoría para proyección de siniestralidad

Lo que NUNCA se comparte:
- Pasos diarios individuales, ritmo cardíaco crudo, ubicación, ni nada a
  nivel de persona identificable más allá de categoría/cashback (que ya es
  parte del contrato con el asegurado)

Esto NO es una pantalla de la app del asegurado — sería un dashboard B2B
separado o un reporte periódico. [PENDIENTE: definir si se construye como
producto o queda solo como material de pitch comercial]

## Decisiones técnicas cerradas

- Frontend: **Flutter** (decisión final, no solo demo)
- Backend: Python / **Django** (confirmado por el código en `mas-vida_backend/`
  y el `compose.yaml` de la rama dev)
- Fuente de datos: Apple HealthKit únicamente
- Datos leídos: pasos, ritmo cardíaco, workouts (NO elevación)
- Distribución piloto: TestFlight
- [COMPLETAR: quién del equipo tiene Mac para builds de iOS]

## Decisiones pendientes

- El "twist propio" del proyecto
- La matriz completa de intensidad (duración × % de FCmáx) — tarea L7
- Validación médica/actuarial del bonus 60+ y de FCmáx = 219 − edad
- Redefinir la tabla de categorías anuales de cashback contra el techo diario
  de 200 pts y el umbral de 2,500 puntos que menciona el Excel
- Reconciliar retos semanales vs. meta semanal adaptativa vs. recompensas por
  constancia
- Si el dashboard para la aseguradora se construye o queda como pitch
- El endpoint de patrocinios (qué semana y qué ciclo de liga están
  vendidos, con qué marca y qué cupón) — lo debe Luis. Hasta entonces sale
  del mock; la marca de ejemplo (Ookii) es un placeholder de Diego
- Si el cupón de una semana patrocinada se SUMA al premio del catálogo o
  lo reemplaza. Hoy se construyó como premio adicional (las monedas del
  rango se pagan igual), que es lo único que no contradice la mecánica de
  rangos
