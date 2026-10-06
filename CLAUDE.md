# +Vida — Contexto del Proyecto

Este archivo se carga automáticamente en cada sesión de Claude Code dentro de
este proyecto. Contiene las reglas de negocio, sistema de diseño, y estado
del proyecto que SIEMPRE deben respetarse al escribir o modificar código.

Si algo que se pide en el chat contradice una regla dura de este documento,
señalalo antes de proceder — no asumas que se quiere romper la regla sin
confirmarlo primero.

**Reunión del 2 de octubre de 2026:** las decisiones de esa reunión (login
con Apple y Google, Hoy sin racha ni cajas de etapas, objetivos que pagan
por separado, pantalla de las 13 semanas, temporadas de 13 semanas,
monedas que vencen por temporada y sin tope, Mi Plan con la escalera
adentro de la tarjeta del cashback, La Liga
por puntos con desempate por pasos, usados y vencidos en un desplegable)
están aplicadas abajo y mandan sobre lo que digan los documentos vivos
hasta que se actualicen.

**Actualizado 22 de septiembre de 2026.** Esta versión parte de la de Daniel
(rama `D7-correcion-2-ui`, 21 sep) y corrige las reglas de negocio que chocaban
con los documentos vivos del proyecto. Todo lo de UI y diseño de Daniel quedó
igual. **Actualizado el 30 de septiembre de 2026 (autenticación por token):**
la identidad sale del token, el MethodChannel pasa a 3 métodos.
**Actualizado el 2 de octubre de 2026 (reunión del equipo):** sin racha;
objetivo semanal que paga por componente y meta de pasos por edad; seasons de
13 semanas ISO; monedas sin tope que se reinician al cerrar la season; La Liga
por puntos; puntos anuales, nivel y cashback por año de póliza, con prima
anual; login con Google y Apple; cambios de Hoy, Mi Plan, Social y Premios.
El detalle técnico está en `contrato-tecnico.md`.

**Contrato entre capas (iOS ↔ backend ↔ Flutter), en este repo:**
`contrato-tecnico.md`. Es el documento oficial: se actualiza ahí y no en copias.
Fuente de verdad de las demás reglas de negocio (en el proyecto de Claude del
equipo, no en este repo): `reglas-puntaje-vivo.md`,
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
   migralo) — se gastan en Premios y **caducan al final de cada season**: el
   saldo vuelve a 0 (decidido el 2 de octubre de 2026). Nunca aparecen en
   Mi Plan.

   Esto reemplaza la caducidad de **90 días** por ganancia (9 de septiembre)
   y la de 6 meses de antes. Si encontrás "90 días" o "6 meses" para las
   monedas en código, comentarios o mocks, es del plazo viejo.

   - Se ganan por cumplir el objetivo semanal (**cada componente paga por
     separado**) y por quedar top 3 en La Liga. **El podio de La Liga se paga
     el día 9** del mes siguiente (decidido el 4 de octubre de 2026; el mes
     se cierra el día 2): así las monedas y el cupón caen en la season
     siguiente y no vencen a los pocos días. La app dice "tus monedas
     llegan el día 9".
   - **Sin tope de acumulación** (decidido el 2 de octubre de 2026; antes
     el tope era 100 y el excedente se perdía).
   - Al empezar una season, primero se reinicia el saldo y después se paga
     la semana que cerró: las monedas de la última semana cuentan en la
     season nueva.
   - **Aviso de fin de season:** 7 días antes de que termine la season se
     avisa que las monedas se reinician. Reemplaza el aviso al llegar a 80,
     que existía por el tope.
   - Un cupón (canjeado o ganado) caduca aparte, a las **3 semanas** (21
     días). Hasta el 5 de octubre de 2026 eran 60 días.
   - Sin póliza verificada se ganan igual, pero **no se pueden canjear**:
     catálogo visible, botón de compra bloqueado con candado.

## Niveles anuales de cashback — regla dura, numéricos

Fuente de verdad: `reglas-puntaje-vivo.md`, sección 6.

**El naming Bronze/Silver/Gold/Platinum está PROHIBIDO en el proyecto.** Es de
Vitality, no de +Vida. El nivel es un entero de 0 a 4 y en la UI se dice
"Nivel 3", nunca un nombre en inglés.

**El año se cuenta por año de póliza** (decidido el 2 de octubre de 2026):
desde la fecha de inicio o la última renovación de la póliza hasta la
siguiente renovación, no del 1 de enero al 31 de diciembre. La póliza se renueva
cada año y su prima es anual.

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

**Techo anual: 12.000 puntos por año de póliza**, sumando solo actividad (pasos + intensidad).
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
teléfono como los de un reloj vinculado, pero la deduplicación y la elección
de fuente (por hora) se resuelven ANTES de aplicar la tabla — nunca se suma
crudo el mismo caminar de dos dispositivos.

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

**Techo anual: 12.000 pts por año de póliza**, con su propia bandera `tope_anual_aplicado`.

Los puntos acreditados se pueden revertir hasta **2 semanas** después; el
saldo nunca queda negativo tras una reversión.

Notas sobre la edad:
- La fecha de nacimiento se pide **en el registro** (autoreportada) y se usa
  de inmediato para la FCmáx, aunque todavía no haya póliza. Cuando el usuario
  vincula su póliza, la aseguradora la confirma. Si **coincide**, todo lo
  ganado en la cuenta base (puntos y monedas) se acredita. Si **no
  coincide**, no hay retroactividad: arranca en cero desde la verificación
  (que ocurre al vincular la póliza).
- El bonus 60+ y la FCmáx REQUIEREN validación médica/actuarial antes de salir
  a piloto. No son definitivos.
- En la UI, cualquier mención al ajuste por edad debe tener tono cálido, nunca
  clínico ni condescendiente.

**Objetivos semanales** (antes "retos semanales") — decisión de Daniel, 24
de septiembre de 2026. Esto reemplaza a `reglas-puntaje-vivo.md`, sección 4,
hasta que ese documento se actualice.

- **Dos objetivos por semana:** pasos de la semana y **cantidad de workouts**
  (así lo definen el contrato y el código; esta línea decía "minutos de
  entrenamiento"). Ni uno ni tres.
- **Cada objetivo paga sus monedas por separado** (decidido el 2 de octubre
  de 2026): cumplir solo los pasos paga lo suyo. La semana se marca
  **completada** solo cuando se cumplen los dos. Montos provisionales: 5 + 5.
  (Esto reemplaza la regla de que había que cumplir los dos para cobrar.)
- **La meta de pasos depende del rango de edad**, de 10 en 10 años
  (decidido el 2 de octubre de 2026). La manda el servidor; la app nunca la
  calcula. Tabla **provisional** (2 de octubre de 2026), en pasos por
  semana: 18–29 y 30–39 → 49.000; 40–49 → 45.000; 50–59 → 42.000; 60–69 →
  35.000; 70 o más → 31.000. Sale de promedios publicados y se ajusta con
  datos del piloto (detalle y fuentes en el contrato, "Meta de pasos por
  edad")
- **Cuántas MONEDAS paga cada objetivo lo manda el servidor**, semana por
  semana. La app no tiene ninguna regla para calcularlo.
- **Seasons de 13 semanas** que siguen las semanas ISO (la season 1 empieza
  el lunes de la semana del 4 de enero; si el año tiene semana 53, se suma a
  la season 4). Detalle en el contrato, "Seasons".
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
se fija a las 00:00 del lunes; no hay estado de "evaluando". El **resultado**
de la semana que terminó (si se completó y sus monedas) se fija el **martes
00:00** (decidido el 3 de octubre de 2026): el lunes entero queda para los
datos atrasados del domingo. El lunes, esa semana se muestra "en revisión"
(el servidor la manda con `estado: "en_revision"`),
nunca "no cumplida". Lo que llegue después del martes ya no cambia la semana
cerrada — solo el historial y el acumulado anual. Por lo mismo,
**ningún texto del objetivo puede sonar a plazo propio** ("Faltan 42 min" se
leía como cuenta regresiva): se dice el avance sobre la meta ("48.000 de 70.000 pasos")
y el plazo una sola vez, abajo.

[PENDIENTE: la meta de workouts, los montos definitivos de cada objetivo y el
ajuste de la tabla de pasos con datos del piloto. Los define Luis (L11) —
**no inventarlos**.]

## Racha

**La racha sale de Hoy** (reunión del 2 de octubre de 2026): ya no va el
fueguito 🔥 bajo el saludo. Antes (22 de septiembre) se habían quitado las
recompensas por constancia y quedaba solo esa línea como motivación.

La tarjeta de racha con su historial de 8 semanas (una casilla por semana:
cumplido o no) ya había salido de Progreso el 21 de septiembre.

**Decidido el 6 de octubre de 2026: la racha sale de toda la app.** Se quitaron
el interruptor "Racha en riesgo" de Perfil, la tarjeta "Tu racha más larga" de
Récords, los campos `racha_semanas` y `racha_historial` del modelo
`ResumenAnual` y de los datos de ejemplo. El servidor nunca los mandó, así que con
la API real el modelo viejo no habría podido leer el resumen. Ya no hay ningún
aviso de "racha en riesgo": el único aviso de Perfil es el recordatorio diario.

## Anti-fraude

- Cada muestra guarda la fuente (`fuente_bundle`, `fuente_nombre`,
  `fuente_version`) y el dispositivo (`dispositivo_nombre`,
  `dispositivo_modelo`, `dispositivo_fabricante`, nullable).
- **No hay lista blanca de marcas.** Todas las apps de terceros (Garmin,
  Whoop, Zepp, Fitbit…) tienen el mismo nivel de confianza. Una fuente
  desconocida nunca se excluye: se trata como teléfono.
- **Elección de fuente (1 oct 2026):** los **pasos** se deciden **por hora**
  (en cada hora gana el dispositivo con más pasos; las horas se suman), así
  que un reloj usado solo para dormir o solo en el gym no deja en cero al
  teléfono. Los **workouts** que dos dispositivos registran a la vez cuentan
  una vez; los que no se cruzan cuentan todos. La **intensidad** la da el
  dispositivo con más puntos. **Nunca se suma la misma actividad dos veces.**
- **Un workout necesita ritmo cardíaco** (un reloj): con solo el teléfono no
  hay workouts. Los workouts ingresados a mano no cuentan (son fáciles de
  inventar). **Lo escrito a mano en Salud no cuenta**: tampoco los pasos ni el
  ritmo cardíaco ingresados a mano (los filtra Swift con
  `HKMetadataKeyWasUserEntered`). **Cualquier workout de cualquier duración
  cuenta** para el objetivo semanal (los 30 min mínimos son solo para los
  puntos de intensidad).
- Ya no se usa `tipo_dispositivo` para el puntaje; los dispositivos se
  comparan por `fuente_bundle` + `dispositivo_modelo` + `dispositivo_fabricante`.
- El día se **recalcula completo en cada sync** de esa fecha: los relojes de
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

**El naranja queda reservado a tres cosas, y a ninguna más:**

1. **Monedas** — el ícono, el chip de saldo y los premios del podio. Es el
   único lugar donde el naranja significa algo por sí solo.
2. **Alertas reales** — datos sin verificar, el teléfono de emergencias.
3. **El check de una etapa completada** — el ícono suelto sobre azul.

(La llama de la racha era el cuarto uso; salió el 2 de octubre de 2026 junto
con la racha.)

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
  usuario está parado, en la tarjeta del cashback de **Mi Plan**— y los
  tres tienen que mostrar la MISMA. Es el
  único archivo que nombra la ruta del asset; el día que la foto llegue
  del backend cambia ahí y nada más. En la escalera de cashback la foto
  REEMPLAZA al cartel "ESTÁS AQUÍ": una cara se reconoce sola y un
  cartel hay que leerlo.

  La escalera con la foto (`escalera_cashback.dart`) vive **adentro de
  la tarjeta azul del cashback de Mi Plan**, dibujada en blanco a
  distintas opacidades directo sobre el azul, sin panel propio (pedido
  de Daniel, 2 de octubre de 2026). Ya no hay medallón ni hoja de
  niveles. Su brillo se apaga con "Reducir movimiento". Esto reemplaza
  a la versión anterior de este documento, que la dejaba siempre
  abierta en Home (decisión de Daniel, 22 de septiembre de 2026): son
  cinco barras que el usuario ya conoce a la segunda semana ocupando
  media pantalla todos los días para contestar una pregunta que se hace
  una vez por mes. Un disco con un
  número adentro es exactamente lo que se toca para saber qué significa
  ese número.
- **Cambiar de pestaña es INMEDIATO** (`navegacion.dart`, pedido de
  Daniel, 2 de octubre de 2026): el fundido de la pantalla entera dejaba
  ver las dos encimadas y se leía como transparente. Lo que se anima es
  el contenido de la que llega: sus bloques suben y aparecen en cascada
  (`desplegar()` de `despliegue.dart`, quieto con "Reducir
  movimiento"). Premios (logos) y Mi Plan (tarjeta) ya traían su entrada
  con `flutter_animate`: no se les pone otra encima
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
- Header + saludo dinámico. **Sin racha ni fueguito** (reunión del 2 de
  octubre de 2026)
- **Las cajas de etapas (7.000 / 10.000 / 15.000) se quitan** (reunión del 2
  de octubre de 2026). Su contenido pasa a un **botón de información** que se
  expande al tocarlo
- **El desglose de puntos queda siempre visible**, sin desplegable (reunión
  del 2 de octubre de 2026)
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
  - **cada objetivo muestra sus propias monedas** (reunión del 2 de octubre
    de 2026): solo "+5" y la moneda, en una pastilla naranja suave (nunca
    "ganas 5 monedas"). Ya no va el renglón "Cumple los dos para ganar" con
    un premio único: cada objetivo paga aparte, y la semana se marca
    completada cuando se cumplen los dos
  - los **dos objetivos LADO A LADO**, en dos columnas separadas por una
    línea de un pelo, como las estadísticas de Fitness: nombre corto
    ("Pasos", "Entrenamiento") con su ícono y un chevron en `azulMedio`,
    el avance en grande, "de 40,000 pasos" en chico y una barra fina de
    6 px (`cardBorder` → degradado `azulMedio` → `accent`). El cumplido
    lleva el check naranja suelto al lado del número
  - al pie, en gris: el conteo y el plazo, una sola vez
  - si una marca compró la semana, **un renglón CHICO**
    (`PremioSemanaChico` en `premio_semana.dart`): el logo en una placa
    apaisada con el fondo de la marca (en un disco chico no se leía),
    "Cumple los dos y ganas" y el cupón en el color de la marca, sobre un
    lavado de ese color. **Sin foto** (pedido de Daniel, 2 de octubre de 2026):
    la foto grande pesaba más que los objetivos. El carrusel vive en la
    card de la semana
- **Las semanas de la temporada** (`semanas_temporada_screen.dart`, se
  abre con el botón; pedido de Daniel, 2 de octubre de 2026): arriba
  "Temporada 3" en grande y el **chip del saldo** a la derecha; tocarlo
  abre la temporada en tres datos (monedas ganadas en ella, semanas
  completas con los dos objetivos y cuándo vencen). **Ya no hay "Tu
  temporada" debajo.** Una card por semana que **mide lo que tiene
  adentro**, **sin scroll vertical**: la pantalla solo se mueve de lado.
  Solo la card que se mira se anima (las monedas son Lottie: con todas
  girando la pantalla se trababa). Se abre con `rutaPesada`
  (`navegacion.dart`): al volver, la pantalla se desliza como una imagen
  quieta (`SnapshotWidget`) y la de atrás no se mueve ni se oscurece; con
  la `CupertinoPageRoute` la vuelta se trababa y se veía transparente Arriba, una
  cabecera en el degradado de marca (`accent` → `azulSombra`; las
  futuras en `azulMedio` → `nivel3`) con el estado ("ESTA SEMANA",
  "COMPLETADA" con el check naranja, "CERRADA", "PRÓXIMAMENTE"),
  "Semana 7 de 13", el número de la semana enorme de marca de agua y el
  logo de la marca si está vendida (58 px: se tiene que notar). Abajo, en
  blanco, la MISMA tarjeta de la semana de Hoy, y al pie **el carrusel
  del premio** si hay marca (`PremioSemana`: fotos que se deslizan solas,
  la marca en una pastilla y el cupón abajo; quieta con "Reducir
  movimiento"). **Sin marca, el pie es un panel del mismo alto con las
  monedas que paga la semana** y tres monedas apiladas: así ninguna card
  queda con un hueco blanco, y no anuncia que falte un patrocinador. Se desliza de lado y **tiene que verse que se desliza**: las
  cards vecinas asoman por los bordes, más chicas y apagadas
  (`viewportFraction` 0,86); abajo una fila de puntos; y al abrir, la
  card se corre sola un poquito y vuelve (nunca con "Reducir
  movimiento"). El pie
  de cada card (premio o lo que paga) es una franja BAJA de 118 px
  (`altoPieDeSemana`): estirado hasta abajo, el carrusel pesaba más que
  la semana
- **Toda hoja que sube desde abajo usa `hoja_vida.dart`**: la barrita
  vive AFUERA del scroll y la hoja se cierra arrastrándola, o tirando del
  contenido hacia abajo cuando ya está arriba. Con la barrita adentro del
  scroll el gesto se lo llevaba el contenido y la hoja no se cerraba
- **Tocar un objetivo abre su DETALLE** (`hoja_objetivo.dart`, pedido
  de Daniel, 24 de septiembre de 2026), **que entra sin scroll** (2 de
  octubre de 2026): el número en grande con su
  barra, cuánto falta dicho como cantidad ("42 min más y lo cumples"),
  cómo se cuenta, cuándo se cierra —"No tienes que marcar nada"— y lo
  que paga ESE objetivo. Es una hoja de INFORMACIÓN: tocar un objetivo
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
- **Vista tipo battle pass** (reunión del 2 de octubre de 2026): el camino
  de nodos se reemplaza por **una caja por semana con scroll horizontal**,
  hacia las semanas pasadas y las que vienen. Muestra las semanas de la
  season en curso (13, o 14 cuando incluye la semana 53). Se pidió para
  mostrar mejor el logo del patrocinador. **Las viñetas de abajo sobre la
  grilla, la cinta y las curvas describen el camino anterior y quedan
  reemplazadas**; las de semanas patrocinadas (logo, colores `fondo` y
  `acento`, nunca un hueco donde no hay marca) siguen valiendo
- **El camino de las semanas** (vista anterior) (`camino_semanas_screen.dart`) va y
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
  semana paga un cupón de esa marca **además** de las monedas de los
  objetivos, nunca en lugar de ellas, y el cupón pide COMPLETAR la
  semana (los dos objetivos). Se ve en su card (logo y pie del premio)
  y, si es la semana en curso, en el carrusel del premio de Hoy
- **No todas las semanas tienen marca, y ese es el caso normal.** Sin
  patrocinador no se dibuja nada: **nunca un hueco ni un cartel que
  anuncie la ausencia**
- La marca trae dos colores y **no son lo mismo**: `fondo` es el color
  detrás de la foto (el de Montanos es negro, y sin él su logo blanco
  desaparece) y `acento` es el del nombre y el cupón

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
- (La tarjeta de racha con historial de 8 semanas salió de Progreso el 21 de
  septiembre de 2026, decisión de Daniel; ver "Racha".)
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
| Con quién | Todos los usuarios con póliza verificada, un solo grupo | Amigos, familia, colegas |
| Ciclo | Mensual (día 1 al último del mes) | Mensual, no configurable |
| Compite por | **Puntos del mes** (desempate: más pasos) | **Puntos del mes** (desempate: más pasos) |
| Premio | **Sí** — monedas al top 3 | **No** |
| Requiere póliza | Sí | No |

**La Liga** (la de `tipo: desconocidos` en el código): **un solo grupo** con
todos los usuarios con póliza verificada, sin botón de "unirme" (confirmado el
2 de octubre de 2026). Compite por **puntos del mes, tal cual** (con el tope
diario y el bono 60+); a igualdad de puntos gana quien tenga **más pasos**, y
un **botón de información** lo explica. **Se muestran los puntos de cada
participante, pero nunca la cantidad de pasos** (ni siquiera para explicar un
desempate). Esto reemplaza la regla anterior de no mostrar los puntos de otros
miembros (2 de octubre de 2026). Corre del día 1 al último día del mes, en hora
de Guatemala.
(Esto reemplaza a la versión anterior de este documento: franjas de edad de 10
años con grupos de 30 y competencia por pasos, que además contradecía al
contrato. Antes de eso decía trimestral.)

**Tus Ligas** no exige póliza (así lo dice el contrato desde el 23 de
septiembre; esta tabla decía lo contrario) y, desde el 2 de octubre de 2026,
también **compite por puntos** con el mismo desempate por pasos.

**La Liga compite por PUNTOS del mes** (reunión del 2 de octubre de 2026).
**Desempate:** con los mismos puntos queda arriba quien caminó más pasos
en el mes. El orden lo manda el SERVIDOR; los pasos de los demás nunca
llegan al teléfono ni se muestran — el usuario solo ve que alguien con sus
mismos puntos va arriba. Las reglas (puntaje, desempate, premios, ciclo)
están a un toque: una (i) en la tarjeta de La Liga en Social, otra junto a
"TABLA DEL MES" y el renglón "Cómo funciona". **El patrocinador va en una
pastilla al lado del nombre de la liga** (logo redondo y nombre en el
color de la marca, sobre un lavado de ese color), en la tarjeta y en la
tabla. Ya no hay cinta "Patrocina Ookii · los 3 primeros se llevan…": el
cupón lo cuentan las reglas.

**Tus Ligas** (competencias con conocidos): la duración **no se elige** — el
selector de 1/2/3 meses se borró.

El **objetivo semanal** corre aparte (lunes 00:00 a domingo 23:59) y no se
mezcla con ninguna liga.

Cada ciclo de La Liga puede tener una **marca patrocinadora**: es la misma
Liga, no una aparte. La marca se muestra **arriba, junto al nombre de la liga,
destacada** (reunión del 2 de octubre de 2026). Los 3 primeros ganan un cupón
de esa marca ADEMÁS de sus monedas, nunca en lugar de ellas. Los datos de patrocinio salen del repositorio, nunca fijos en el
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
  - los **usados y vencidos** abajo, en una **lista desplegable** (reunión
    del 2 de octubre de 2026), plana y apagada
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
- Cashback acumulado, proyección al cierre del año de póliza, calendario de
  cálculo, nota regulatoria, tabla de niveles
- **La gráfica de "en qué nivel vas" se une con la gráfica de barras**, y
  **debajo va el cashback**, para ver los dos datos juntos (reunión del 2 de
  octubre de 2026). Cashback en quetzales = **% del nivel × prima anual**,
  devuelto después del pago de la prima
- **Al cambiar de filtro se anima SOLO lo que cambia** (decisión de
  Daniel, 22 de septiembre de 2026): el título, la tarjeta y el riel
  van adentro del scroll pero afuera del `AnimatedSwitcher`. El scroll
  vuelve arriba con un controlador, no con una llave
- Sección "Detalles de tu Póliza" (datos que la aseguradora expone al
  asegurado, agrupados en 2-3 tarjetas por tema): número de póliza,
  titular y dependientes, tipo de plan, suma asegurada, deducible,
  coaseguro, vigencia, renovación, prima y forma de pago, red de
  hospitales/cobertura, estado de la póliza. La póliza es **anual**: la
  fecha que manda la aseguradora es la de su **renovación** anual; una
  póliza médica no vence, solo deja de valer si la cancelan o la suspenden
  (2 de octubre de 2026)
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

**Registro / login / recuperar contraseña** — el backend ya tiene `POST
/api/v1/registro` y `POST /api/v1/login`; las **pantallas de Flutter no existen
todavía** (recuperar contraseña tampoco: falta elegir un proveedor de correo).
Cuenta base: usuario + contraseña + **fecha de nacimiento** (obligatoria, no
puede ser futura); el email queda para más adelante. **Además, "Continuar con
Google" e "Iniciar sesión con Apple"** (reunión del 2 de octubre de 2026;
Apple es obligatorio si se ofrece Google). Ninguno de los dos entrega la fecha
de nacimiento: la primera vez se pide aparte. El servidor genera el
`usuario_id`, un nombre público que no identifica a quien manda datos. Vincular
póliza es un segundo paso, aparte. Flutter guarda el token en almacenamiento
seguro, lo manda en cada request HTTP y se lo entrega a Swift con
`actualizarSesion`.

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

**Datos que necesitamos que nos dé la aseguradora** (reunión del 2 de
octubre de 2026): nombre y apellido, prima, número de póliza, fecha de
nacimiento, plan y vencimiento. Es la lista para pedírsela; la pantalla de
Mi Plan no se cambió.

Para septiembre el reporte es solo un Excel manual. Landing, login y dashboard
para la aseguradora son post-piloto y viven **fuera** de la app de Flutter.

## Decisiones técnicas cerradas

- Frontend: **Flutter** (decisión final, no solo demo). Capa nativa en Swift
  solo para HealthKit.
- **MethodChannel:** 3 métodos, nada más — `solicitarPermisos`, `sincronizar`
  y `actualizarSesion` (le entrega a Swift el token de la sesión, o `null` al
  cerrarla). Usar siempre `lib/datos/healthkit_bridge.dart`. Todo lo demás va
  por HTTP directo contra la API.
- Backend: **Django + PostgreSQL** (decisión final). `TIME_ZONE =
  'America/Guatemala'`.
- Sync: `POST /api/v1/sync`, el día completo cada vez. Los reintentos corren
  del lado nativo — Flutter no implementa reintentos propios.
- Autenticación: tokens de **django-rest-knox** (A35, 4 oct 2026), con el
  encabezado `Authorization: Token <clave>` en todo `/api/v1/*` salvo registro y
  login. Un token por sesión, guardado como hash; vence a los 30 días sin uso, con
  tope de 90; `logout` cierra un teléfono y `logout/todos` todos. La identidad sale
  del token, nunca del body. Swift decide "cambió la cuenta" por el `usuario_id`,
  no por el token (ver `contrato-tecnico.md`, "Autenticación (token)").
- Fuente de datos: Apple HealthKit únicamente
- Datos leídos: pasos, ritmo cardíaco, workouts (NO elevación, NO sueño en v1)
- Distribución piloto: TestFlight, cuenta Apple Developer de organización
  (Assures)
- Builds de iOS: Daniel no tiene Mac — los `.ipa` salen de CI con runner
  macOS en GitHub Actions

## Decisiones pendientes

- El "twist propio" del proyecto
- Ajustar con datos del piloto la tabla provisional de metas de pasos por
  edad, y definir la meta de workouts — Luis (L11)
- Validación médica/actuarial del bonus 60+ y de FCmáx = 219 − edad
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
- Monedas que caducan a 6 meses o a 90 días por ganancia; tope de 100
  monedas (por semana o acumuladas). Hoy caducan al cerrar la season y no
  tienen tope.
- Racha con fueguito en Hoy.
- Seasons cortadas el 1 de enero, abril, julio y octubre (hoy: 13 semanas ISO).
- Lista blanca de fuentes; "gana la fuente con más pasos **del día**" entre
  todas. (No confundir con la regla vigente: los pasos se deciden **por hora**
  y las horas se suman; ver "Elección de fuente".)
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
