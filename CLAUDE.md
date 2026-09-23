# +Vida — Contexto del Proyecto

Este archivo se carga automáticamente en cada sesión de Claude Code dentro de
este proyecto. Contiene las reglas de negocio, el sistema de diseño y el estado
del proyecto que SIEMPRE deben respetarse al escribir o modificar código.

Si algo que se pide en el chat contradice una regla dura de este documento,
señalalo antes de proceder — no asumas que se quiere romper la regla sin
confirmarlo primero.

**Última actualización: 22 de septiembre de 2026.** Reemplaza por completo la
versión anterior. Si en el código encontrás algo de la lista "Modelo viejo — migrar"
(al final), es de antes y hay que corregirlo.

Fuente de verdad detallada (en el proyecto de Claude del equipo, no en este
repo): `contrato-tecnico-vivo.md`, `reglas-puntaje-vivo.md`,
`arquitectura-cuentas-vivo.md`, `modelo-de-negocio-vivo.md`,
`esquema-base-datos-vivo.md`. Si este archivo y esos documentos no coinciden,
mandan esos documentos.

## Qué es +Vida

App iOS (Flutter + capa nativa Swift para HealthKit) que lee pasos, ritmo
cardíaco y workouts de Apple Health, los convierte en puntos, y esos puntos dan
**cashback** sobre la póliza de gastos médicos del usuario, más premios
canjeables con comercios aliados. Referente de diseño: Discovery Vitality,
adaptado a Guatemala — pero **ningún número de Vitality aplica**; las reglas
numéricas son las de este archivo. Es a la vez entrega de tesis (UFM) y
producto comercial real. Empresa: Assures.

**Modelo de negocio:** B2B2C — el usuario final (asegurado) usa el producto,
la aseguradora paga. **Gratis para jugar, pago para los beneficios:**
cualquiera usa la app sin póliza; todo lo que implica dinero o premio requiere
póliza vinculada y verificada.

**3 vías de ingreso** (montos = cifras de trabajo, nada cerrado):
1. Cuota por asegurado cobrada a la aseguradora (mensual, incluye el reporte).
2. Cuota mensual a comercios aliados por publicar premios/cupones en la tienda,
   más extras opcionales: patrocinar La Liga, patrocinar una semana, y
   posicionamiento pagado en la búsqueda de premios.
3. Plan Empresarial — post-piloto, no se construye ahora.

**No existe ninguna membresía freemium ni multiplicador de pasos/puntos
pagado.** Si aparece en código viejo, se borra.

## Idioma y tono — regla dura

Toda la app en **español latinoamericano**, tono natural y humano (nunca
traducción literal ni robótica). Mercado guatemalteco.

**Regla regulatoria dura:** el cashback SIEMPRE se devuelve como dinero
DESPUÉS del pago de la prima. NUNCA se descuenta directamente (Superintendencia
de Bancos de Guatemala). Siempre "cashback", nunca "descuento en tu prima" ni
"ahorro en tu póliza".

## Las 2 monedas — regla dura, nunca mezclar

1. **PUNTOS** — nunca se gastan. Determinan el nivel anual y el % de cashback.
   Nunca aparecen en Premios.
2. **MONEDAS** — se gastan en Premios. Nunca aparecen en Mi Plan.
   - Se ganan por completar el objetivo semanal y por quedar top 3 en La Liga.
   - **Tope: 100 monedas acumuladas.** Si una ganancia pasa de 100, el
     excedente se pierde.
   - **Aviso al llegar a 80:** modal (un botón "OK"), tono lúdico. Se dispara
     con `saldo_resultante >= 80`, no `== 80`.
   - Caducan a los **90 días** sin gastar.
   - Un cupón ya canjeado caduca aparte, a los **60 días** de canjeado.
   - Sin póliza verificada se ganan igual, pero **no se pueden canjear**
     (catálogo visible, botón de compra bloqueado con candado).

## Niveles anuales de cashback — numéricos, nunca con nombre

| Nivel | Puntos anuales | Cashback |
|---|---|---|
| Nivel 0 | 0 – 2.500 | 0% |
| Nivel 1 | 2.500 – 5.000 | 5% |
| Nivel 2 | 5.000 – 10.000 | 7,5% |
| Nivel 3 | 10.000 – 15.000 | 10% |
| Nivel 4 | 15.000+ | 20% |

**Nunca** Bronze/Silver/Gold/Platinum ni ningún otro nombre. **Tope anual:
12.000 pts** por actividad — Nivel 4 queda fuera de alcance en el piloto. Es
consecuencia aceptada, no un bug: no "arreglarla" subiendo el tope. Cashback
máximo real del piloto: 10%.

El nivel anual (0–4) **no es** el objetivo semanal — nunca comparten nombre de
campo ni la palabra "nivel".

## Cálculo de puntos diarios

Lo calcula **siempre el servidor** (Django). El teléfono manda datos crudos de
HealthKit, nunca puntos, edad, FCM ni conclusiones.

**Por pasos** — escalones, piso 7.000:

| Pasos del día | Puntos |
|---|---|
| menos de 7.000 | 0 |
| 7.000 – 10.000 | 25 |
| 10.000 – 15.000 | 50 |
| 15.000+ | 100 |

**Por intensidad (ritmo cardíaco)** — FCM = **219 − edad**, sesión continua:

| Duración continua | Intensidad | Puntos |
|---|---|---|
| 30 min | 60% FCM | 50 |
| 30 min | 70% FCM | 100 |
| 60 min | 60% FCM | 100 |
| 90 min | 60% FCM | 150 |

Se compara por rango, no por valor exacto. Varias sesiones el mismo día: se
acredita el escalón **más alto**, no se suman.

**Bono 60+:** **+25 pts fijos** sobre pasos y **+25 pts fijos** sobre
intensidad — independientes, acumulables el mismo día. **Nunca multiplicador.**

**Tope diario: 200 pts** (pasos + intensidad + bonos), igual para todas las
edades.

**Edad:** la fecha de nacimiento se pide en el registro (autoreportada) y se usa
de inmediato. Cuando el usuario vincula su póliza, la aseguradora la confirma.
Si no coincide, no hay retroactividad de puntos. En la UI, cualquier mención al
ajuste por edad va con tono cálido, nunca clínico ni condescendiente.

## Objetivo semanal (antes "retos semanales")

- **Una sola meta por semana, en pasos acumulados.**
- Todos arrancan en **objetivo 1**. Cumplir → sube al siguiente. No cumplir →
  **se congela** (misma meta). **Nunca baja.** Techo real ~13.
- Ciclo **lunes 00:00 a domingo 23:59**, hora de Guatemala. El objetivo nuevo
  se fija a las 00:00 del lunes; no hay estado de "evaluando".
- **Seasons trimestrales** en fechas fijas (1 ene, 1 abr, 1 jul, 1 oct): todos
  vuelven a objetivo 1 ese día exacto, sin esperar al lunes. Se guarda el
  objetivo máximo de cada season.
- Nunca usar "nivel", "rango" ni "reto" para esto. No hay rachas diarias.
- Endpoint: `GET /api/v1/retos/estado`.

## Social — La Liga, Tus Ligas y Duelos

Las tres viven en la pestaña **Social**.

| | La Liga | Tus Ligas | Duelos |
|---|---|---|---|
| Quién la arma | El sistema, automático | El usuario (crea o se une) | El usuario |
| Con quién | Gente random de tu franja de edad | Amigos, familia, colegas | 1 contra 1 |
| Ciclo | Mensual (día 1 al último del mes) | Mensual | — |
| Compite por | Pasos del mes | Pasos del mes | Más pasos |
| Premio | **Sí** — monedas al top 3 | **No** | **No** |
| Requiere póliza | Sí | Sí | Sí |

**La Liga:** franjas de edad de 10 años (20–29, 30–39…), máximo 30 personas
por grupo, asignación aleatoria re-sorteada cada mes. Nunca se muestran los
puntos de otros miembros. Los **Duelos** tienen categorías cosméticas
Bronce/Plata/Oro/Diamante (en español), solo estado social — nada que ver con
el nivel de cashback.

Un ciclo ya cerrado (La Liga, objetivo semanal) es **inmutable** — un dato
tardío entra al historial pero no lo reabre.

## Cuentas

- **Cuenta base (gratis):** email + contraseña + fecha de nacimiento. Juega
  completo: pasos, puntos, intensidad, objetivo semanal, ganar monedas.
- **Póliza vinculada y verificada:** segundo paso, aparte del registro. Da
  acceso a cashback, canje de monedas, La Liga, Tus Ligas y Duelos.
- "Pendiente de verificación" se trata **exactamente igual** que "sin póliza"
  — no hay un tercer estado visual.
- Sin póliza, **Mi Plan** muestra un estado vacío con CTA para vincular póliza
  y un **cotizador express**.

## Anti-fraude y datos

- Cada muestra guarda la fuente (`fuente_bundle`, `fuente_nombre`,
  `fuente_version`) y el dispositivo (`dispositivo_nombre`,
  `dispositivo_modelo`, `dispositivo_fabricante`, nullable).
- **No hay lista blanca de marcas.** Todas las apps de terceros (Garmin, Whoop,
  Zepp, Fitbit…) tienen el mismo nivel de confianza.
- **Precedencia:** si hay un reloj con datos ese día, **gana el reloj** (pasos
  e intensidad) y el teléfono se descarta. Sin reloj, gana el teléfono. Dos
  relojes: el de más pasos. **Nunca se suman fuentes.**
- "¿Es reloj?" se decide con `tipo_dispositivo`, derivado en el servidor —
  nunca con `fuente_nombre`. `desconocido` se trata como teléfono (nunca se
  excluye).
- La precedencia se **re-evalúa en cada sync** de esa fecha: los relojes de
  terceros necesitan internet para escribir a Apple Health y pueden llegar tarde.
- **Ventana de datos rezagados: 14 días.** Más viejo → `422`
  `{"error": "fuera_de_ventana"}`.
- Idempotencia por `(usuario, external_id)`.
- Ledger de puntos **append-only**: nunca `UPDATE`, cada acreditación o
  corrección es una fila nueva con la versión de regla que la generó.
- `TIME_ZONE = 'America/Guatemala'`.
- **HealthKit nunca dice si el usuario negó el permiso de lectura** — solo se
  infiere consultando. `ritmo_cardiaco: false` casi siempre es "no tiene reloj".
- **Cero SDKs de terceros sobre datos de salud** (ej. Firebase) — Apple lo trata
  como filtración y remueve la app. Nunca loguear el payload de salud completo.

## Datos que se comparten con la aseguradora

[PENDIENTE — conflicto sin resolver, no construir nada nuevo sobre esto]
La regla original era: solo agregados de cohorte, nada a nivel de persona. El
reporte mensual definido con Diego (18 sep) manda por persona pasos,
ritmo cardíaco promedio y workouts diarios. Las dos cosas chocan, y el texto
de consentimiento de la app (D11) también. Hasta que Alvaro lo resuelva: **no
exponer datos individuales** en ningún endpoint nuevo y **no copiar** el texto
de consentimiento viejo si se toca esa pantalla.

Para septiembre el reporte es solo un Excel manual. Landing, login y dashboard
para la aseguradora son post-piloto y viven fuera de la app de Flutter.

## Pantallas — lo que el código tiene que respetar

- **Home / Progress:** "objetivo semanal", nunca "reto" ni "nivel". Datos por
  período desde `GET /api/v1/dashboard/resumen?desde=&hasta=`. FC por workout
  (promedio y máximo), nunca un promedio de 24 h. Un workout con
  `tipo_actividad` vacío se muestra como "No registrado", no se oculta.
- **Social:** La Liga, Tus Ligas y Duelos (ver arriba). Sin puntos de otros
  miembros en La Liga.
- **Premios:** saldo y costo en monedas; sin póliza, catálogo visible y compra
  bloqueada con candado + CTA a vincular póliza.
- **Mi Plan:** con póliza: cashback, nivel, proyección, nota regulatoria,
  detalle de póliza. Sin póliza: estado vacío + CTA + cotizador express.
- **Registro / login / recuperar contraseña:** no existen todavía. El registro
  pide fecha de nacimiento. Token en almacenamiento seguro.

## Arquitectura técnica — decisiones cerradas

- **Frontend:** Flutter (decisión final).
- **Capa nativa:** Swift, solo para HealthKit.
- **MethodChannel:** 2 métodos, nada más — `solicitarPermisos` y
  `sincronizar`. Usar siempre `lib/datos/healthkit_bridge.dart`. Todo lo demás
  va por HTTP directo contra la API.
- **Backend:** Django + PostgreSQL (decisión final).
- **Sync:** `POST /api/v1/sync`, el día completo cada vez. La cola de
  reintentos corre del lado nativo — Flutter no implementa reintentos propios.
- **Autenticación:** `TokenAuthentication` de DRF, la identidad sale del token,
  nunca del body. Todavía no está implementada.
- **Fuente de datos:** Apple HealthKit únicamente (Apple Watch, Garmin, Whoop,
  etc. escriben ahí). Se leen pasos, ritmo cardíaco y workouts. Sin elevación.
  Sin sueño en v1.
- **Distribución del piloto:** TestFlight, cuenta Apple Developer de
  organización (Assures).
- **Builds de iOS:** Daniel no tiene Mac — los `.ipa` salen de CI con runner
  macOS en GitHub Actions.

## Decisiones pendientes

- Tabla de metas de pasos por objetivo semanal (objetivo 1, 2, 3…) — Luis (L11).
- Compartir datos por persona con la aseguradora vs. solo agregados (ver arriba).
- Plausibilidad fisiológica: descartar muestras fuera de rango vs. solo
  marcarlas para revisión.
- Cómo se registra en el ledger un cambio de puntos cuando un reloj sincroniza
  tarde.
- **Recompensas por constancia** (monedas extra por semanas seguidas cumpliendo
  la meta: 4/8/12/24/52 semanas) — venía de la versión anterior de este archivo
  y no aparece en ningún documento vigente. Sin confirmar si sigue existiendo.
  **No construir nada nuevo sobre esto** hasta que Alvaro lo confirme.
- Tus Ligas: cupo de miembros y cómo se invita.
- Validación médica/actuarial del bono 60+ y de FCM = 219 − edad.

## Modelo viejo — migrar si aparece en el código

- Membresía freemium / multiplicador de pasos.
- Categorías Bronze/Silver/Gold/Platinum y tabla 5.000/10.000/20.000/30.000.
- Escalones de pasos 7.500 / 12.000 / 20.000, o puntos 5/10/20.
- FCM = 220 − edad, techo diario de 500 pts, o una sola celda de intensidad
  (42 min al 74%).
- Bono 60+ ×1.25, o bono solo sobre intensidad.
- Retos que bajan de nivel, 3 sub-metas por semana, reinicio mensual, "metas
  mensuales".
- Monedas que caducan a 6 meses; tope de 100 monedas por semana.
- Lista blanca de fuentes; "gana la fuente con más pasos" entre todas.
- Ventana de datos rezagados de 3 o 6 días.
- "Liga local" por zona como liga aparte con opt-in.
- Término "medallas" (ahora son monedas).
