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
   migralo) — se gastan en Premios, caducan a los 90 días. Nunca aparecen
   en Mi Plan.

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
| 3 | 10,000 – 14,999 | 10% |
| 4 | 15,000+ | 20% |

Tabla **confirmada** (Daniel, 1 de septiembre de 2026). Reemplaza a la versión
anterior de este documento, que dejaba los niveles 0, 1 y 2 sin definir. Vive
en `niveles`, dentro de `lib/reglas_puntos.dart`: ese es el único lugar donde
se escriben estos números.

**Techo anual de actividad física: 12.000 puntos.** Topa los puntos por pasos
e intensidad, y NO es un techo de los puntos del año: **los chequeos médicos
dan puntos aparte, que se suman POR ENCIMA de ese techo.**

Consecuencia: **el nivel 4 (15.000+) SÍ es alcanzable**, pero solo si el
afiliado además se hace los chequeos — con pura actividad física no llega.
Esto reemplaza a la versión anterior de este documento, que decía que el nivel
4 quedaba fuera de alcance en el piloto.

Los 15.000 son el **piso** del nivel 4, no un techo. Nunca poner un tope duro
ahí.

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
- **Barra inferior** (`lib/widgets/bottom_nav_bar.dart`, reutilizada en
  TODAS las pantallas): 5 ítems fijos en este orden: Home, Progress,
  Social, Premios, Mi Plan. El ítem activo necesita fondo de píldora sutil
  (verde muy pálido) — sobre fondo claro ya no basta el contraste solo

## Pantallas — estado y contenido

**Home** (`lib/screens/home_screen.dart`) — construida
- Header + saludo dinámico + racha activa (con aviso si está a 1 semana de
  un hito de monedas)
- Anillo de pasos (color según categoría, gradiente, marcadores 25%), meta
  diaria, tiempo restante del día
- Tarjeta de puntos totales (SIN botón de canje)
- "Tu Cashback": monto acumulado, camino de categorías, link a Mi Plan
- "Objetivos de la semana": las semanas del mes, cada una plegable, con
  sus 3 objetivos (progreso/monedas/check) y el rango. Las metas mensuales
  ya NO existen

**Progress** (`lib/screens/progress_screen.dart`) — construida
- Selector Semana/Mes/Año con contenido real por pestaña
- Meta del período + comparación vs. período anterior
- Gráfico de actividad (nunca 30+ barras finitas sin etiqueta)
- Racha con historial de 8 semanas (cada casilla refleja si se cumplió) +
  progreso al próximo hito de monedas
- Sección "Recompensas por constancia": los 5 hitos con check en los
  alcanzados
- "Nivel Actual", Monedas del período, Ritmo Cardíaco (obligatorio si se
  pide permiso `.heartRate`)
- CTA "Ver mis récords" (pantalla de Récords Personales — pendiente)

**Social** (`lib/screens/social_screen.dart`) — construida, dos pestañas
- Amigos: alerta de racha en riesgo, Duelo (activo/invitación), superación
  del propio baseline (nunca comparación directa), historial W/L, lista de
  conexiones (racha, categoría, monedas — NUNCA pasos ni historial crudo),
  bloquear/eliminar
- Ranking: selector de grupos, posición propia, cuánto falta para subir,
  lista completa

**Premios** — construida
- Catálogo (filtros, saldo de monedas, costo en monedas)
- Detalle (condiciones, vencimiento, canje)
- Canje exitoso (QR, resumen de monedas descontadas)

**Mi Plan** — diseñada, confirmar si está construida en Flutter
- Cashback acumulado, proyección de fin de año, calendario de cálculo,
  nota regulatoria, tabla de categorías
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
